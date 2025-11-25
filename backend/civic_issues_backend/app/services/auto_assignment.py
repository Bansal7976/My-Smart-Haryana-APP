from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_
from .. import models
from .notifications import send_notification_to_user
from ..config import settings
import logging

logger = logging.getLogger(__name__)

async def trigger_auto_assignment(db: AsyncSession):
    """
    Production-ready auto-assignment system.
    
    Workflow:
    1. Finds highest priority PENDING problem
    2. Maps problem type to department
    3. Finds available worker in same district and department
    4. Assigns problem and sends notifications
    
    Features:
    - Load balancing: assigns to worker with lowest task count
    - District matching: worker must be in same district
    - Capacity check: respects MAX_DAILY_TASKS_PER_WORKER limit
    """
    try:
        # 1. Find highest priority pending problem
        problem_query = select(models.Problem).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING
        ).order_by(models.Problem.priority.desc()).limit(1)
        problem_to_assign = (await db.execute(problem_query)).scalar_one_or_none()

        if not problem_to_assign:
            return  # No pending problems

        # 2. Map problem type to department
        PROBLEM_TYPE_TO_DEPARTMENT = {
            "pothole": "Roads",
            "road repair": "Roads",
            "street light": "Electrical",
            "electrical": "Electrical",
            "water supply": "Water",
            "sewage": "Sanitation",
            "drainage": "Sanitation",
            "cleaning": "Sanitation",
            "public transport": "Transport",
        }
        
        dept_name = PROBLEM_TYPE_TO_DEPARTMENT.get(
            problem_to_assign.problem_type.lower(), 
            problem_to_assign.problem_type
        )
        
        dept_query = select(models.Department).where(
            models.Department.name.ilike(f"%{dept_name}%")
        )
        department = (await db.execute(dept_query)).scalar_one_or_none()

        if not department:
            logger.warning(
                f"No department found for problem type '{problem_to_assign.problem_type}'. "
                f"Admin should create '{dept_name}' department."
            )
            return

        # 3. Find available worker with capacity in same district and department
        # Count actual ASSIGNED tasks from database, not the daily_task_count column
        from sqlalchemy import func as sql_func
        
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
        
        # Find workers with less than max capacity
        worker_query = (
            select(models.WorkerProfile)
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

        if not available_worker:
            # Check if there are workers but they're all at capacity
            # Count their ACTUAL assigned tasks from database
            all_workers_query = select(models.WorkerProfile).join(models.User).where(
                and_(
                    models.WorkerProfile.department_id == department.id,
                    models.User.district == problem_to_assign.district,
                    models.User.is_active == True
                )
            )
            all_workers = (await db.execute(all_workers_query)).scalars().all()
            if all_workers:
                # Get actual counts from database
                worker_counts = []
                for w in all_workers:
                    count_query = select(sql_func.count(models.Problem.id)).where(
                        models.Problem.assigned_worker_id == w.id,
                        models.Problem.status == models.ProblemStatusEnum.ASSIGNED
                    )
                    actual_count = (await db.execute(count_query)).scalar_one()
                    worker_counts.append(f"Worker #{w.id}: {actual_count}/{settings.MAX_DAILY_TASKS_PER_WORKER}")
                
                logger.info(
                    f"No available workers in {department.name} for {problem_to_assign.district}. "
                    f"All workers at capacity: {', '.join(worker_counts)}"
                )
            else:
                logger.info(
                    f"No workers found in {department.name} for {problem_to_assign.district}."
                )
            return

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
        
        await db.commit()
        
        logger.info(
            f"✅ Problem #{problem_to_assign.id} assigned to worker #{available_worker.id} "
            f"({available_worker.user.full_name}) - Priority: {problem_to_assign.priority}. "
            f"Worker now has {new_count} active tasks."
        )

        # 5. Send notifications (WebSocket + Push)
        try:
            # Real-time WebSocket notifications
            from ..routers.notifications import send_real_time_notification
            
            # Notify worker
            await send_real_time_notification(
                user_id=available_worker.user_id,
                notification_type="issue_assigned",
                title="New Task Assigned",
                message=f"New task assigned: '{problem_to_assign.title}' in {problem_to_assign.district}",
                data={
                    "problem_id": problem_to_assign.id,
                    "title": problem_to_assign.title,
                    "district": problem_to_assign.district,
                    "priority": float(problem_to_assign.priority)
                }
            )
            
            # Notify citizen
            await send_real_time_notification(
                user_id=problem_to_assign.user_id,
                notification_type="issue_assigned",
                title="Issue Assigned",
                message=f"Your issue '{problem_to_assign.title}' has been assigned to a worker.",
                data={
                    "problem_id": problem_to_assign.id,
                    "title": problem_to_assign.title,
                    "worker_name": available_worker.user.full_name
                }
            )
        except Exception as e:
            logger.warning(f"Real-time notification failed: {str(e)}")
        
        # Send push notifications (separate try-catch, independent of WebSocket)
        try:
            from .push_notifications import notify_issue_assigned
            await notify_issue_assigned(
                db=db,
                worker_id=available_worker.user_id,
                issue_id=problem_to_assign.id,
                issue_title=problem_to_assign.title
            )
        except Exception as e:
            logger.warning(f"Push notification failed: {str(e)}")
            
    except Exception as e:
        logger.error(f"Auto-assignment error: {str(e)}")
        await db.rollback()
