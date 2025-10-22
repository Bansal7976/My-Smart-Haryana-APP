# in app/services/notifications.py

async def send_notification_to_user(user_id: int, message: str):
    """
    Placeholder for sending notifications. In a real-world application, this
    function would integrate with an SMS gateway, an email service (like SendGrid),
    or a push notification service (like Firebase Cloud Messaging).
    """
    print("---" * 15)
    print(f"SENDING NOTIFICATION to User ID: {user_id}")
    print(f"MESSAGE: {message}")
    print("---" * 15)
    
    return True