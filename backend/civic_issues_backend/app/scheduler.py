from sqlalchemy import update
from .database import AsyncSessionLocal
from .models import WorkerProfile
from .services import auto_assignment
import logging

logger = logging.getLogger(__name__)


async def reset_daily_task_counts():
    """
    Resets daily_task_count for all workers to 0.
    Runs once per day at midnight.
    """
    logger.info("SCHEDULER: Running job to reset daily task counts...")

    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(
                update(WorkerProfile).values(daily_task_count=0)
            )
            await session.commit()

            logger.info(
                f"SCHEDULER: Reset daily task count for {result.rowcount} workers."
            )

    except Exception as e:
        logger.error(f"SCHEDULER: Error resetting task counts: {str(e)}")


async def run_auto_assignment_job():
    """
    Runs every minute to auto-assign tasks.
    """
    logger.info("🔄 SCHEDULER: Running auto-assignment job...")

    try:
        async with AsyncSessionLocal() as session:
            # Check if there are pending problems first
            from sqlalchemy.future import select
            from .models import Problem, ProblemStatusEnum
            
            pending_query = select(Problem).where(Problem.status == ProblemStatusEnum.PENDING)
            pending_problems = (await session.execute(pending_query)).scalars().all()
            
            if not pending_problems:
                logger.info("📋 SCHEDULER: No pending problems found")
                return
            
            logger.info(f"📋 SCHEDULER: Found {len(pending_problems)} pending problems")
            
            await auto_assignment.trigger_auto_assignment(session)
            # Don't commit here - the function handles its own commit

    except Exception as e:
        logger.error(f"❌ SCHEDULER: Auto-assignment error: {str(e)}", exc_info=True)
