from sqlalchemy import update
from .database import AsyncSessionLocal
from .models import WorkerProfile
from .services import auto_assignment
import logging

logger = logging.getLogger(__name__)

async def reset_daily_task_counts():
    """
    Resets the daily_task_count for all workers to 0.
    This job is scheduled to run once every day at midnight.
    """
    logger.info("SCHEDULER: Running job to reset daily task counts...")
    async with AsyncSessionLocal() as session:
        async with session.begin():
            await session.execute(
                update(WorkerProfile).values(daily_task_count=0)
            )
    logger.info("SCHEDULER: Daily task counts have been reset.")


async def run_auto_assignment_job():
    """
    Periodically triggers the auto-assignment logic to assign a pending task.
    """
    logger.info("SCHEDULER: Running auto-assignment job...")
    async with AsyncSessionLocal() as session:
        async with session.begin():
            await auto_assignment.trigger_auto_assignment(session)