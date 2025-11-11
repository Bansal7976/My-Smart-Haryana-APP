"""
WebSocket Router for Real-Time Notifications
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Set
import json
import logging
from datetime import datetime

from .. import database, models, utils
from ..services.notifications import send_notification_to_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/notifications", tags=["Notifications"])

# Store active WebSocket connections per user
# Format: {user_id: Set[WebSocket]}
active_connections: Dict[int, Set[WebSocket]] = {}


class ConnectionManager:
    """Manages WebSocket connections for real-time notifications"""
    
    def __init__(self):
        self.active_connections: Dict[int, Set[WebSocket]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: int):
        """Connect a user's WebSocket"""
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        logger.info(f"User {user_id} connected. Total connections: {len(self.active_connections.get(user_id, set()))}")
    
    def disconnect(self, websocket: WebSocket, user_id: int):
        """Disconnect a user's WebSocket"""
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info(f"User {user_id} disconnected")
    
    async def send_personal_message(self, message: dict, user_id: int):
        """Send a notification to a specific user"""
        if user_id in self.active_connections:
            disconnected = set()
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.warning(f"Error sending message to user {user_id}: {str(e)}")
                    disconnected.add(connection)
            
            # Clean up disconnected connections
            for conn in disconnected:
                self.active_connections[user_id].discard(conn)
            
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
    
    async def broadcast(self, message: dict, exclude_user_id: int = None):
        """Broadcast a message to all connected users"""
        for user_id, connections in self.active_connections.items():
            if exclude_user_id and user_id == exclude_user_id:
                continue
            await self.send_personal_message(message, user_id)


manager = ConnectionManager()


async def get_user_from_token(token: str, db: AsyncSession):
    """Verify JWT token and get user"""
    try:
        from ..utils import decode_access_token
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        if not user_id:
            return None
        
        query = select(models.User).where(models.User.id == int(user_id))
        result = await db.execute(query)
        user = result.scalar_one_or_none()
        return user
    except Exception as e:
        logger.error(f"Error verifying token: {str(e)}")
        return None


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for real-time notifications.
    
    Client should connect with: ws://host:port/notifications/ws?token=<JWT_TOKEN>
    """
    # Get token from query parameters
    token = websocket.query_params.get("token")
    
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return
    
    # Get database session
    async for db in database.get_db():
        # Verify user token
        user = await get_user_from_token(token, db)
        if not user:
            await websocket.close(code=4003, reason="Invalid authentication token")
            return
        
        # Connect user
        await manager.connect(websocket, user.id)
        
        try:
            # Send welcome message
            await websocket.send_json({
                "type": "connection",
                "message": "Connected to Smart Haryana notifications",
                "user_id": user.id,
                "timestamp": datetime.utcnow().isoformat()
            })
            
            # Keep connection alive and handle incoming messages
            while True:
                # Wait for any message from client (ping/pong or commands)
                try:
                    data = await websocket.receive_json()
                    
                    # Handle ping/pong
                    if data.get("type") == "ping":
                        await websocket.send_json({
                            "type": "pong",
                            "timestamp": datetime.utcnow().isoformat()
                        })
                    # Handle other commands here if needed
                    
                except WebSocketDisconnect:
                    break
                except Exception as e:
                    logger.error(f"Error processing WebSocket message: {str(e)}")
                    break
                    
        except WebSocketDisconnect:
            manager.disconnect(websocket, user.id)
            logger.info(f"User {user.id} disconnected")
        except Exception as e:
            logger.error(f"WebSocket error for user {user.id}: {str(e)}")
            manager.disconnect(websocket, user.id)
            await websocket.close()
        
        break  # Exit database session loop


@router.get("/test/{user_id}")
async def test_notification(
    user_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Test endpoint to send a notification to a user (for testing).
    """
    if current_user.role not in [models.RoleEnum.ADMIN, models.RoleEnum.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can send test notifications"
        )
    
    # Create test notification
    notification = {
        "type": "test",
        "title": "Test Notification",
        "message": f"This is a test notification sent by {current_user.full_name}",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {}
    }
    
    # Send via WebSocket if user is connected
    await manager.send_personal_message(notification, user_id)
    
    # Also log it
    await send_notification_to_user(
        user_id=user_id,
        message=notification["message"]
    )
    
    return {"status": "sent", "notification": notification}


# Function to send notifications (called from other services)
async def send_real_time_notification(
    user_id: int,
    notification_type: str,
    title: str,
    message: str,
    data: dict = None
):
    """
    Helper function to send real-time notifications.
    Call this from anywhere in the application.
    
    Args:
        user_id: Target user ID
        notification_type: Type of notification (issue_assigned, issue_completed, etc.)
        title: Notification title
        message: Notification message
        data: Additional data (optional)
    """
    notification = {
        "type": notification_type,
        "title": title,
        "message": message,
        "timestamp": datetime.utcnow().isoformat(),
        "data": data or {}
    }
    
    # Send via WebSocket
    await manager.send_personal_message(notification, user_id)
    
    # Also send via traditional notification service (for logging/fallback)
    await send_notification_to_user(user_id, message)
    
    logger.info(f"Real-time notification sent to user {user_id}: {notification_type}")

