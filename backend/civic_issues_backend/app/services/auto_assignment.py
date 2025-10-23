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
        worker_query = select(models.WorkerProfile).join(models.User).where(
            and_(
                models.WorkerProfile.department_id == department.id,
                models.WorkerProfile.daily_task_count < settings.MAX_DAILY_TASKS_PER_WORKER,
                models.User.district == problem_to_assign.district,
                models.User.is_active == True
            )
        ).order_by(models.WorkerProfile.daily_task_count.asc()).limit(1)
        
        available_worker = (await db.execute(worker_query)).scalar_one_or_none()

        if not available_worker:
            logger.info(
                f"No available workers in {department.name} for {problem_to_assign.district}. "
                f"All workers at capacity or no workers exist."
            )
            return

        # 4. Assign problem to worker
        problem_to_assign.assigned_worker_id = available_worker.id
        problem_to_assign.status = models.ProblemStatusEnum.ASSIGNED
        available_worker.daily_task_count += 1
        
        await db.commit()
        
        logger.info(
            f"✅ Problem #{problem_to_assign.id} assigned to worker #{available_worker.id} "
            f"({available_worker.user.full_name}) - Priority: {problem_to_assign.priority}"
        )

        # 5. Send notifications
        try:
            await send_notification_to_user(
                user_id=available_worker.user_id,
                message=f"New task assigned: '{problem_to_assign.title}' in {problem_to_assign.district}"
            )
            await send_notification_to_user(
                user_id=problem_to_assign.user_id,
                message=f"Your issue '{problem_to_assign.title}' has been assigned to a worker."
            )
        except Exception as e:
            logger.warning(f"Notification failed: {str(e)}")
            
    except Exception as e:
        logger.error(f"Auto-assignment error: {str(e)}")
        await db.rollback()