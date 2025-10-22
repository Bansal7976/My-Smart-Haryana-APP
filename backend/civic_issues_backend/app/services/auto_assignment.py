from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_
from .. import models
from .notifications import send_notification_to_user
from ..config import settings
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def trigger_auto_assignment(db: AsyncSession):
    """
    Finds the highest priority pending problem and assigns it to an eligible worker
    in the same district and department.
    """
    problem_query = select(models.Problem).where(
        models.Problem.status == models.ProblemStatusEnum.PENDING
    ).order_by(models.Problem.priority.desc()).limit(1)
    problem_to_assign = (await db.execute(problem_query)).scalar_one_or_none()

    if not problem_to_assign:
        # This is not an error, just means no work to do right now.
        logger.info("Auto-Assignment Job: No pending problems to assign.")
        return

    # 2. Find the department related to the problem type with mapping
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
    
    dept_name = PROBLEM_TYPE_TO_DEPARTMENT.get(problem_to_assign.problem_type.lower(), problem_to_assign.problem_type)
    dept_query = select(models.Department).where(
        models.Department.name.ilike(f"%{dept_name}%")
    )
    department = (await db.execute(dept_query)).scalar_one_or_none()

    if not department:
        logger.warning(f"Auto-Assignment: No department found for problem type '{problem_to_assign.problem_type}'.")
        return

    # 3. Find an available worker in the correct department AND DISTRICT
    worker_query = select(models.WorkerProfile).join(models.User).where(
        and_(
            models.WorkerProfile.department_id == department.id,
            # Use the setting from config.py
            models.WorkerProfile.daily_task_count < settings.MAX_DAILY_TASKS_PER_WORKER,
            models.User.district == problem_to_assign.district
        )
    ).order_by(models.WorkerProfile.daily_task_count.asc()).limit(1)
    
    available_worker = (await db.execute(worker_query)).scalar_one_or_none()

    if not available_worker:
        logger.info(f"Auto-Assignment: No available workers in department '{department.name}' for district '{problem_to_assign.district}'.")
        return

    # 4. Assign the problem and update records
    problem_to_assign.assigned_worker_id = available_worker.id
    problem_to_assign.status = models.ProblemStatusEnum.ASSIGNED
    available_worker.daily_task_count += 1
    
    await db.commit()
    logger.info(f"Auto-Assignment: Problem ID {problem_to_assign.id} assigned to WorkerProfile ID {available_worker.id}")

    # 5. Send notifications to the worker and the client
    await send_notification_to_user(
        user_id=available_worker.user_id,
        message=f"New task assigned: '{problem_to_assign.title}' in {problem_to_assign.district}"
    )
    await send_notification_to_user(
        user_id=problem_to_assign.user_id,
        message=f"Your issue '{problem_to_assign.title}' has been assigned to a worker."
    )