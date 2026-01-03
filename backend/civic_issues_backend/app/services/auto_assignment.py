from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_
from sqlalchemy.orm import selectinload
from .. import models
from .notifications import send_notification_to_user
from ..config import settings
import logging

logger = logging.getLogger(__name__)

async def trigger_auto_assignment(db: AsyncSession):
    """
    Production-ready auto-assignment system.
    
    Workflow:
    1. Finds all PENDING problems ordered by priority
    2. For each problem, maps problem type to department
    3. Finds available worker in same district and department
    4. Assigns problem and sends notifications
    
    Features:
    - Load balancing: assigns to worker with lowest task count
    - District matching: worker must be in same district
    - Capacity check: respects MAX_DAILY_TASKS_PER_WORKER limit
    - Processes multiple problems in one run
    """
    try:
        logger.info("🔄 Starting auto-assignment process...")
        
        # 1. Find pending problems ordered by priority (process up to 10 at a time)
        problems_query = select(models.Problem).options(
            selectinload(models.Problem.submitted_by)  # Eager load user relationship
        ).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING
        ).order_by(models.Problem.priority.desc()).limit(10)  # Process up to 10 problems
        
        pending_problems = (await db.execute(problems_query)).scalars().all()

        if not pending_problems:
            logger.info("📋 No pending problems found for auto-assignment")
            return  # No pending problems
        
        logger.info(f"📋 Found {len(pending_problems)} pending problems to process")
        
        assigned_count = 0
        
        # Process each problem
        for problem_to_assign in pending_problems:
            try:
                logger.info(
                    f"📋 Processing problem #{problem_to_assign.id} - {problem_to_assign.title} "
                    f"(Type: {problem_to_assign.problem_type}, District: {problem_to_assign.district}, "
                    f"Priority: {problem_to_assign.priority})"
                )
                
                # Check if problem is still pending (might have been assigned by previous iteration)
                current_status_query = select(models.Problem.status).where(models.Problem.id == problem_to_assign.id)
                current_status = (await db.execute(current_status_query)).scalar_one()
                
                if current_status != models.ProblemStatusEnum.PENDING:
                    logger.info(f"⏭️ Problem #{problem_to_assign.id} already processed, skipping")
                    continue

                # Try to assign this problem
                success = await assign_single_problem(db, problem_to_assign)
                if success:
                    assigned_count += 1
                    logger.info(f"✅ Successfully assigned problem #{problem_to_assign.id}")
                else:
                    logger.info(f"⏭️ Could not assign problem #{problem_to_assign.id}, will try again later")
                    
            except Exception as e:
                logger.error(f"❌ Error processing problem #{problem_to_assign.id}: {str(e)}")
                continue  # Continue with next problem
        
        logger.info(f"🎯 Auto-assignment completed: {assigned_count}/{len(pending_problems)} problems assigned")
        
    except Exception as e:
        logger.error(f"Auto-assignment error: {str(e)}")
        await db.rollback()


async def assign_single_problem(db: AsyncSession, problem_to_assign: models.Problem) -> bool:
    """
    Assign a single problem to an available worker.
    Returns True if successfully assigned, False otherwise.
    """
    try:
        # 2. Map problem type to department
        PROBLEM_TYPE_TO_DEPARTMENT = {
            "pothole": "Roads",
            "road repair": "Roads", 
            "road_repair": "Roads",
            "roads": "Roads",
            "street light": "Electrical",
            "streetlight": "Electrical",
            "electrical": "Electrical",
            "electricity": "Electrical",
            "power": "Electrical",
            "water supply": "Water",
            "water": "Water",
            "sewage": "Sanitation",
            "drainage": "Sanitation",
            "cleaning": "Sanitation",
            "sanitation": "Sanitation",
            "garbage": "Sanitation",
            "waste": "Sanitation",
            "public transport": "Transport",
            "transport": "Transport",
            "traffic": "Transport",
            "parks": "Parks and Gardens",
            "garden": "Parks and Gardens",
            "health": "Health",
            "hospital": "Health",
            "public works": "Public Works",
        }
        
        dept_name = PROBLEM_TYPE_TO_DEPARTMENT.get(
            problem_to_assign.problem_type.lower(), 
            problem_to_assign.problem_type
        )
        
        logger.info(f"🏢 Mapping problem type '{problem_to_assign.problem_type}' to department '{dept_name}'")
        
        # Try exact match first, then ILIKE
        dept_query = select(models.Department).where(models.Department.name == dept_name)
        department = (await db.execute(dept_query)).scalar_one_or_none()
        
        if not department:
            # Try case-insensitive partial match
            dept_query = select(models.Department).where(
                models.Department.name.ilike(f"%{dept_name}%")
            )
            department = (await db.execute(dept_query)).scalar_one_or_none()
        
        if not department:
            # List all available departments for debugging
            all_depts_query = select(models.Department)
            all_departments = (await db.execute(all_depts_query)).scalars().all()
            dept_names = [d.name for d in all_departments]
            
            logger.warning(
                f"❌ No department found for problem type '{problem_to_assign.problem_type}' → '{dept_name}'. "
                f"Available departments: {dept_names}. "
                f"Admin should create '{dept_name}' department or check mapping."
            )
            return False
        
        logger.info(f"✅ Found department: {department.name} (ID: {department.id})")

        # 3. Find available worker with capacity in same district and department
        # Count actual ASSIGNED tasks from database, not the daily_task_count column
        from sqlalchemy import func as sql_func
        
        logger.info(f"🔍 Looking for workers in {department.name} department, {problem_to_assign.district} district...")
        
        # Subquery to count ASSIGNED tasks for each worker
        assigned_count_subquery = (
            select(
                models.Problem.assigned_worker_id,
                sql_func.count(models.Problem.id).label('active_count')
            )
            .where(models.Problem.status == models.ProblemStatusEnum.ASSIGNED)
            .group_by(models.Problem.assigned_worker_id)
            .subquery()
        )
        
        # Find workers with less than max capacity (with eager loading)
        worker_query = (
            select(models.WorkerProfile)
            .options(selectinload(models.WorkerProfile.user))  # Eager load user relationship
            .join(models.User)
            .outerjoin(assigned_count_subquery, models.WorkerProfile.id == assigned_count_subquery.c.assigned_worker_id)
            .where(
                and_(
                    models.WorkerProfile.department_id == department.id,
                    models.User.district == problem_to_assign.district,
                    models.User.is_active == True,
                    sql_func.coalesce(assigned_count_subquery.c.active_count, 0) < settings.MAX_DAILY_TASKS_PER_WORKER
                )
            )
            .order_by(sql_func.coalesce(assigned_count_subquery.c.active_count, 0).asc())
            .limit(1)
        )
        
        available_worker = (await db.execute(worker_query)).scalar_one_or_none()
        
        # Debug: Show all workers in this department and district
        debug_query = select(models.WorkerProfile).join(models.User).where(
            and_(
                models.WorkerProfile.department_id == department.id,
                models.User.district == problem_to_assign.district,
                models.User.is_active == True
            )
        ).options(selectinload(models.WorkerProfile.user))
        
        all_dept_workers = (await db.execute(debug_query)).scalars().all()
        logger.info(f"📊 Found {len(all_dept_workers)} total workers in {department.name} - {problem_to_assign.district}")
        
        for worker in all_dept_workers:
            # Count their current ASSIGNED tasks
            count_query = select(sql_func.count(models.Problem.id)).where(
                models.Problem.assigned_worker_id == worker.id,
                models.Problem.status == models.ProblemStatusEnum.ASSIGNED
            )
            current_assigned = (await db.execute(count_query)).scalar_one()
            logger.info(f"   👷 {worker.user.full_name}: {current_assigned}/{settings.MAX_DAILY_TASKS_PER_WORKER} assigned tasks")

        if not available_worker:
            # Check if there are workers but they're all at capacity
            if all_dept_workers:
                logger.info(
                    f"No available workers in {department.name} for {problem_to_assign.district}. "
                    f"All workers at capacity."
                )
            else:
                logger.warning(
                    f"❌ No workers found in {department.name} department for {problem_to_assign.district} district. "
                    f"Admin needs to create workers for this department and district."
                )
            return False

        # 4. Assign problem to worker
        problem_to_assign.assigned_worker_id = available_worker.id
        problem_to_assign.status = models.ProblemStatusEnum.ASSIGNED
        
        # Update counter for backward compatibility (actual count is from database query)
        available_worker.daily_task_count += 1
        
        # Get count BEFORE commit (will be current count + 1 after this assignment)
        current_count_query = select(sql_func.count(models.Problem.id)).where(
            models.Problem.assigned_worker_id == available_worker.id,
            models.Problem.status == models.ProblemStatusEnum.ASSIGNED
        )
        current_count = (await db.execute(current_count_query)).scalar_one()
        new_count = current_count + 1  # This assignment will add 1
        
        # Fetch user data explicitly to avoid lazy loading issues
        worker_user_query = select(models.User).where(models.User.id == available_worker.user_id)
        worker_user = (await db.execute(worker_user_query)).scalar_one()
        
        reporter_user_query = select(models.User).where(models.User.id == problem_to_assign.user_id)
        reporter_user = (await db.execute(reporter_user_query)).scalar_one()
        
        # Store data before commit (needed for notifications)
        worker_user_id = worker_user.id
        worker_name = worker_user.full_name
        worker_fcm_token = worker_user.fcm_token
        problem_id = problem_to_assign.id
        problem_title = problem_to_assign.title
        problem_district = problem_to_assign.district
        problem_priority = problem_to_assign.priority
        reporter_user_id = reporter_user.id
        reporter_fcm_token = reporter_user.fcm_token
        
        await db.commit()
        
        logger.info(
            f"✅ Problem #{problem_id} assigned to worker #{available_worker.id} "
            f"({worker_name}) - Priority: {problem_priority}. "
            f"Worker now has {new_count} active tasks."
        )

        # 5. Send Firebase push notifications (using FCM tokens fetched before commit)
        try:
            from .push_notifications import send_push_to_token
            
            # Notify worker via Firebase push
            if worker_fcm_token:
                await send_push_to_token(
                    fcm_token=worker_fcm_token,
                    title="New Task Assigned 📋",
                    body=f"You have been assigned to work on: {problem_title} in {problem_district}",
                    notification_type="task_assigned",
                    data={
                        "problem_id": str(problem_id),
                        "title": problem_title,
                        "district": problem_district,
                        "priority": str(problem_priority),
                        "action": "view_task"
                    }
                )
                logger.info(f"✅ Push notification sent to worker {worker_user_id}")
            
            # Notify citizen via Firebase push
            if reporter_fcm_token:
                await send_push_to_token(
                    fcm_token=reporter_fcm_token,
                    title="Issue Assigned to Worker 👷",
                    body=f"Your issue '{problem_title}' has been assigned to {worker_name}. Work will begin soon!",
                    notification_type="issue_assigned",
                    data={
                        "problem_id": str(problem_id),
                        "title": problem_title,
                        "worker_name": worker_name,
                        "action": "view_issue"
                    }
                )
                logger.info(f"✅ Push notification sent to reporter {reporter_user_id}")
                
        except Exception as e:
            logger.warning(f"Push notification failed: {str(e)}")
            
        return True
            
    except Exception as e:
        logger.error(f"Single problem assignment error: {str(e)}")
        await db.rollback()
        return False