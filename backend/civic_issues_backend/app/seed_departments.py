"""
Seed Departments for Smart Haryana Platform
Creates default departments for civic issue categorization
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from . import models
import logging

logger = logging.getLogger(__name__)

DEFAULT_DEPARTMENTS = [
    "Roads",
    "Electrical",
    "Water",
    "Sanitation",
    "Transport",
    "Public Works",
    "Health",
    "Parks and Gardens"
]

async def seed_departments(db: AsyncSession):
    """
    Seed default departments if they don't exist.
    Safe to run multiple times - only creates missing departments.
    """
    try:
        for dept_name in DEFAULT_DEPARTMENTS:
            # Check if department exists
            query = select(models.Department).where(models.Department.name == dept_name)
            existing_dept = (await db.execute(query)).scalar_one_or_none()
            
            if not existing_dept:
                # Create new department
                new_dept = models.Department(name=dept_name)
                db.add(new_dept)
                logger.info(f"✅ Created department: {dept_name}")
            else:
                logger.debug(f"Department already exists: {dept_name}")
        
        await db.commit()
        logger.info(f"✅ Department seeding complete - {len(DEFAULT_DEPARTMENTS)} departments ready")
        
    except Exception as e:
        logger.error(f"Department seeding error: {str(e)}")
        await db.rollback()
        raise

