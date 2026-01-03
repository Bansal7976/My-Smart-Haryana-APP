"""
Notifications Router - Firebase Push Notifications Only
WebSocket support has been removed - all notifications go to notification tray via Firebase
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
import logging

from .. import database, models, utils

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("/test/{user_id}")
async def test_notification(
    user_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Test endpoint to send a Firebase push notification to a user.
    Only admins can use this endpoint.
    """
    if current_user.role not in [models.RoleEnum.ADMIN, models.RoleEnum.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can send test notifications"
        )
    
    # Send Firebase push notification
    from ..services.notifications import send_notification_to_user
    
    await send_notification_to_user(
        user_id=user_id,
        message=f"This is a test notification sent by {current_user.full_name}",
        db=db,
        title="Test Notification 🔔",
        notification_type="test",
        data={"sender": current_user.full_name}
    )
    
    return {
        "status": "sent",
        "message": "Firebase push notification sent to notification tray",
        "user_id": user_id
    }

