# in app/services/notifications.py
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

logger = logging.getLogger(__name__)

async def send_notification_to_user(
    user_id: int, 
    message: str,
    db: Optional[AsyncSession] = None,
    title: str = "Smart Haryana",
    notification_type: str = "general",
    data: dict = None
):
    """
    Send notification to user via Firebase Push Notification (notification tray only).
    
    Args:
        user_id: Target user ID
        message: Notification message
        db: Database session (required for push notifications)
        title: Notification title
        notification_type: Type of notification
        data: Additional data payload (optional)
    """
    # Console log (for debugging)
    logger.info(f"📲 Sending notification to User {user_id}: {title}")
    
    # Send Firebase push notification (notification tray)
    if db is not None:
        try:
            from .push_notifications import send_push_notification
            await send_push_notification(
                db=db,
                user_id=user_id,
                title=title,
                body=message,
                notification_type=notification_type,
                data=data
            )
            logger.info(f"✅ Push notification sent to user {user_id}")
        except Exception as e:
            logger.warning(f"Push notification failed: {str(e)}")
    else:
        logger.warning(f"Cannot send notification to user {user_id}: No database session provided")
    
    return True
