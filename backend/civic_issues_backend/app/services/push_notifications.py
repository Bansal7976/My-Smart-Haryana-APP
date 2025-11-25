"""
Push Notification Service using Firebase Cloud Messaging (FCM)
"""

import logging
from typing import Optional, List, Dict, Any
import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .. import models
from ..config import settings

logger = logging.getLogger(__name__)

# Global Firebase app instance
firebase_app = None


def initialize_firebase():
    """
    Initialize Firebase Admin SDK.
    Call this once during application startup.
    """
    global firebase_app
    
    if firebase_app is not None:
        logger.info("Firebase already initialized")
        return firebase_app
    
    try:
        # Check if Firebase credentials are configured
        if not hasattr(settings, 'FIREBASE_CREDENTIALS_PATH') or not settings.FIREBASE_CREDENTIALS_PATH:
            logger.warning("Firebase credentials not configured. Push notifications will be disabled.")
            return None
        
        # Initialize Firebase with service account
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        firebase_app = firebase_admin.initialize_app(cred)
        logger.info("✅ Firebase Admin SDK initialized successfully")
        return firebase_app
        
    except Exception as e:
        logger.error(f"❌ Failed to initialize Firebase: {str(e)}")
        logger.warning("Push notifications will be disabled")
        return None


async def send_push_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "general"
) -> bool:
    """
    Send push notification to a specific user.
    
    Args:
        db: Database session
        user_id: Target user ID
        title: Notification title
        body: Notification body/message
        data: Additional data payload (optional)
        notification_type: Type of notification (for routing in app)
    
    Returns:
        bool: True if sent successfully, False otherwise
    """
    try:
        # Check if Firebase is initialized
        if firebase_app is None:
            logger.debug("Firebase not initialized, skipping push notification")
            return False
        
        # Get user's FCM token
        query = select(models.User).where(models.User.id == user_id)
        result = await db.execute(query)
        user = result.scalar_one_or_none()
        
        if not user or not user.fcm_token:
            logger.debug(f"User {user_id} has no FCM token, skipping push notification")
            return False
        
        # Prepare notification data
        notification_data = data or {}
        notification_data['type'] = notification_type
        notification_data['user_id'] = str(user_id)
        
        # Create FCM message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=notification_data,
            token=user.fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    channel_id='smart_haryana_notifications',
                ),
            ),
        )
        
        # Send message
        response = messaging.send(message)
        logger.info(f"✅ Push notification sent to user {user_id}: {response}")
        return True
        
    except messaging.UnregisteredError:
        # Token is invalid, remove it from database
        logger.warning(f"Invalid FCM token for user {user_id}, removing from database")
        user.fcm_token = None
        await db.commit()
        return False
        
    except Exception as e:
        logger.error(f"❌ Failed to send push notification to user {user_id}: {str(e)}")
        return False


async def send_push_to_multiple(
    db: AsyncSession,
    user_ids: List[int],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "general"
) -> Dict[str, int]:
    """
    Send push notification to multiple users.
    
    Args:
        db: Database session
        user_ids: List of target user IDs
        title: Notification title
        body: Notification body/message
        data: Additional data payload (optional)
        notification_type: Type of notification
    
    Returns:
        dict: Statistics (success_count, failure_count)
    """
    success_count = 0
    failure_count = 0
    
    for user_id in user_ids:
        success = await send_push_notification(
            db, user_id, title, body, data, notification_type
        )
        if success:
            success_count += 1
        else:
            failure_count += 1
    
    logger.info(f"Batch notification sent: {success_count} success, {failure_count} failed")
    return {
        "success_count": success_count,
        "failure_count": failure_count,
        "total": len(user_ids)
    }


async def send_push_to_token(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "general"
) -> bool:
    """
    Send push notification directly to an FCM token.
    
    Args:
        fcm_token: Firebase Cloud Messaging token
        title: Notification title
        body: Notification body/message
        data: Additional data payload (optional)
        notification_type: Type of notification
    
    Returns:
        bool: True if sent successfully, False otherwise
    """
    try:
        # Check if Firebase is initialized
        if firebase_app is None:
            logger.debug("Firebase not initialized, skipping push notification")
            return False
        
        # Prepare notification data
        notification_data = data or {}
        notification_data['type'] = notification_type
        
        # Create FCM message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=notification_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    channel_id='smart_haryana_notifications',
                ),
            ),
        )
        
        # Send message
        response = messaging.send(message)
        logger.info(f"✅ Push notification sent to token: {response}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to send push notification to token: {str(e)}")
        return False


# Notification type constants
class NotificationType:
    """Notification type constants for consistent routing"""
    ISSUE_CREATED = "issue_created"
    ISSUE_ASSIGNED = "issue_assigned"
    ISSUE_COMPLETED = "issue_completed"
    ISSUE_VERIFIED = "issue_verified"
    FEEDBACK_RECEIVED = "feedback_received"
    TASK_ASSIGNED = "task_assigned"
    GENERAL = "general"


# Helper functions for specific notification types

async def notify_issue_assigned(
    db: AsyncSession,
    worker_id: int,
    issue_id: int,
    issue_title: str
):
    """Notify worker when an issue is assigned to them"""
    await send_push_notification(
        db=db,
        user_id=worker_id,
        title="New Task Assigned",
        body=f"You have been assigned: {issue_title}",
        data={
            "issue_id": str(issue_id),
            "action": "view_task"
        },
        notification_type=NotificationType.ISSUE_ASSIGNED
    )


async def notify_issue_completed(
    db: AsyncSession,
    reporter_id: int,
    issue_id: int,
    issue_title: str
):
    """Notify reporter when their issue is completed"""
    await send_push_notification(
        db=db,
        user_id=reporter_id,
        title="Issue Completed",
        body=f"Your issue has been completed: {issue_title}",
        data={
            "issue_id": str(issue_id),
            "action": "view_issue"
        },
        notification_type=NotificationType.ISSUE_COMPLETED
    )


async def notify_issue_verified(
    db: AsyncSession,
    reporter_id: int,
    worker_id: int,
    issue_id: int,
    issue_title: str
):
    """Notify both reporter and worker when issue is verified"""
    # Notify reporter
    await send_push_notification(
        db=db,
        user_id=reporter_id,
        title="Issue Verified",
        body=f"Your issue has been verified: {issue_title}. Please provide feedback!",
        data={
            "issue_id": str(issue_id),
            "action": "provide_feedback"
        },
        notification_type=NotificationType.ISSUE_VERIFIED
    )
    
    # Notify worker
    await send_push_notification(
        db=db,
        user_id=worker_id,
        title="Task Verified",
        body=f"Your completed task has been verified: {issue_title}",
        data={
            "issue_id": str(issue_id),
            "action": "view_task"
        },
        notification_type=NotificationType.ISSUE_VERIFIED
    )


async def notify_feedback_received(
    db: AsyncSession,
    worker_id: int,
    issue_id: int,
    issue_title: str,
    rating: int
):
    """Notify worker when they receive feedback"""
    stars = "⭐" * rating
    await send_push_notification(
        db=db,
        user_id=worker_id,
        title="Feedback Received",
        body=f"You received {stars} for: {issue_title}",
        data={
            "issue_id": str(issue_id),
            "rating": str(rating),
            "action": "view_feedback"
        },
        notification_type=NotificationType.FEEDBACK_RECEIVED
    )
