"""
Email Notification Service
"""
import logging
from typing import Optional
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from ..config import settings

logger = logging.getLogger(__name__)


async def send_email_notification(
    to_email: str,
    subject: str,
    body: str,
    html_body: Optional[str] = None
) -> bool:
    """
    Send email notification to user.
    
    Args:
        to_email: Recipient email address
        subject: Email subject
        body: Plain text email body
        html_body: HTML email body (optional)
    
    Returns:
        bool: True if sent successfully, False otherwise
    """
    try:
        # Check if email is configured
        if not hasattr(settings, 'SMTP_HOST') or not settings.SMTP_HOST:
            logger.warning("Email not configured. Skipping email notification.")
            return False
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = settings.SMTP_FROM_EMAIL
        msg['To'] = to_email
        
        # Add plain text part
        text_part = MIMEText(body, 'plain')
        msg.attach(text_part)
        
        # Add HTML part if provided
        if html_body:
            html_part = MIMEText(html_body, 'html')
            msg.attach(html_part)
        
        # Send email
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            if settings.SMTP_USE_TLS:
                server.starttls()
            if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
                server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            server.send_message(msg)
        
        logger.info(f"✅ Email sent to {to_email}: {subject}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to send email to {to_email}: {str(e)}")
        return False


def create_task_assigned_email(worker_name: str, task_title: str, task_id: int) -> tuple:
    """Create email content for task assignment"""
    subject = "New Task Assigned - Smart Haryana"
    
    body = f"""
Hello {worker_name},

A new task has been assigned to you:

Task: {task_title}
Task ID: #{task_id}

Please log in to the Smart Haryana portal to view details and complete the task.

Thank you,
Smart Haryana Team
"""
    
    html_body = f"""
<html>
<body style="font-family: Arial, sans-serif; padding: 20px;">
    <h2 style="color: #2196F3;">New Task Assigned</h2>
    <p>Hello <strong>{worker_name}</strong>,</p>
    <p>A new task has been assigned to you:</p>
    <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p><strong>Task:</strong> {task_title}</p>
        <p><strong>Task ID:</strong> #{task_id}</p>
    </div>
    <p>Please log in to the Smart Haryana portal to view details and complete the task.</p>
    <p style="margin-top: 30px;">Thank you,<br><strong>Smart Haryana Team</strong></p>
</body>
</html>
"""
    
    return subject, body, html_body


def create_task_completed_email(user_name: str, task_title: str, task_id: int) -> tuple:
    """Create email content for task completion"""
    subject = "Task Completed - Smart Haryana"
    
    body = f"""
Hello {user_name},

Your reported issue has been completed:

Task: {task_title}
Task ID: #{task_id}

Please log in to the Smart Haryana portal to verify the completion and provide feedback.

Thank you,
Smart Haryana Team
"""
    
    html_body = f"""
<html>
<body style="font-family: Arial, sans-serif; padding: 20px;">
    <h2 style="color: #4CAF50;">Task Completed</h2>
    <p>Hello <strong>{user_name}</strong>,</p>
    <p>Your reported issue has been completed:</p>
    <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p><strong>Task:</strong> {task_title}</p>
        <p><strong>Task ID:</strong> #{task_id}</p>
    </div>
    <p>Please log in to the Smart Haryana portal to verify the completion and provide feedback.</p>
    <p style="margin-top: 30px;">Thank you,<br><strong>Smart Haryana Team</strong></p>
</body>
</html>
"""
    
    return subject, body, html_body
