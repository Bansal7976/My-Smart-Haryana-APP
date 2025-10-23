"""
Production-ready admin seeding module
Automatically creates super admin and district admins on first startup
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from passlib.context import CryptContext
from .models import User, RoleEnum
import logging

logger = logging.getLogger(__name__)

# Password hashing without validation for initial seed
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Haryana Districts
HARYANA_DISTRICTS = [
    'Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad',
    'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal',
    'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal', 'Panchkula',
    'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar'
]

async def seed_admins(db: AsyncSession) -> None:
    """
    Seeds super admin and district admins if they don't exist.
    Safe to run multiple times - checks for existing users.
    """
    
    try:
        # Check if super admin exists
        super_admin_email = "haryana@gov.in"
        query = select(User).where(User.email == super_admin_email)
        existing_super_admin = (await db.execute(query)).scalar_one_or_none()
        
        if not existing_super_admin:
            # Create super admin
            super_admin = User(
                full_name="Haryana State Administrator",
                email=super_admin_email,
                hashed_password=pwd_context.hash("Haryana@4321"),
                role=RoleEnum.SUPER_ADMIN,
                district="Haryana",
                pincode="000000",
                is_active=True
            )
            db.add(super_admin)
            await db.flush()
            logger.info(f"✅ Super Admin created: {super_admin_email}")
        else:
            logger.info(f"ℹ️  Super Admin already exists: {super_admin_email}")
        
        # Create district admins
        created_count = 0
        for district in HARYANA_DISTRICTS:
            admin_email = f"{district.lower().replace(' ', '')}@gov.in"
            
            # Check if district admin exists
            query = select(User).where(User.email == admin_email)
            existing_admin = (await db.execute(query)).scalar_one_or_none()
            
            if not existing_admin:
                admin = User(
                    full_name=f"{district} District Administrator",
                    email=admin_email,
                    hashed_password=pwd_context.hash(f"{district.replace(' ', '')}@4321"),
                    role=RoleEnum.ADMIN,
                    district=district,
                    pincode="000000",
                    is_active=True
                )
                db.add(admin)
                created_count += 1
        
        if created_count > 0:
            await db.commit()
            logger.info(f"✅ Created {created_count} district admin(s)")
        else:
            logger.info("ℹ️  All district admins already exist")
        
        # Log credentials only in development
        from .config import settings
        if settings.ENVIRONMENT == "development":
            logger.info("🔐 Admin Credentials:")
            logger.info(f"   Super Admin: haryana@gov.in / Haryana@4321")
            logger.info(f"   District Admins: [district]@gov.in / [District]@4321")
            logger.info(f"   Example: sirsa@gov.in / Sirsa@4321")
        
    except Exception as e:
        logger.error(f"❌ Error seeding admins: {str(e)}")
        await db.rollback()
        raise

