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
    notification_type: str = "general"
):
    """
    Send notification to user via multiple channels:
    1. WebSocket (real-time, if connected)
    2. Push Notification (Firebase FCM, if token available)
    3. Console log (fallback/debugging)
    
    Args:
        user_id: Target user ID
        message: Notification message
        db: Database session (optional, for push notifications)
        title: Notification title (for push notifications)
        notification_type: Type of notification
    """
    # Console log (always)
    print("---" * 15)
    print(f"SENDING NOTIFICATION to User ID: {user_id}")
    print(f"TITLE: {title}")
    print(f"MESSAGE: {message}")
    print(f"TYPE: {notification_type}")
    print("---" * 15)
    
    # Send push notification if database session provided
    if db is not None:
        try:
            from .push_notifications import send_push_notification
            await send_push_notification(
                db=db,
                user_id=user_id,
                title=title,
                body=message,
                notification_type=notification_type
            )
        except Exception as e:
            logger.error(f"Failed to send push notification: {str(e)}")
    
    return True
