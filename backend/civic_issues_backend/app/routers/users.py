from fastapi import (
    APIRouter, Depends, Form, UploadFile, File, 
    HTTPException, status
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, select, case
from sqlalchemy.orm import selectinload
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from pathlib import Path
import logging

from .. import database, schemas, models, utils, storage
from ..services import priority, sentiment
from ..services.voice_to_text import convert_audio_to_text, get_supported_languages

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["Client & Issues"])

@router.get("/me", response_model=schemas.User)
async def read_current_user(current_user: models.User = Depends(utils.get_current_user)):
    """
    Get the profile of the currently logged-in user.
    """
    return current_user

@router.get("/leaderboard/district/{district}")
async def get_district_leaderboard(
    district: str,
    limit: int = 10,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get leaderboard for a specific district showing top civic contributors.
    """
    query = select(
        models.User.id,
        models.User.full_name,
        models.User.civic_points,
        models.User.issues_reported,
        models.User.issues_verified,
        models.User.district
    ).where(
        models.User.district == district,
        models.User.role == models.RoleEnum.CLIENT,
        models.User.is_active == True
    ).order_by(
        models.User.civic_points.desc()
    ).limit(limit)
    
    result = await db.execute(query)
    leaderboard = result.all()
    
    # Get current user's rank in this district
    user_rank_query = select(func.count(models.User.id)).where(
        models.User.district == district,
        models.User.role == models.RoleEnum.CLIENT,
        models.User.is_active == True,
        models.User.civic_points > current_user.civic_points
    )
    user_rank_result = await db.execute(user_rank_query)
    user_rank = user_rank_result.scalar() + 1
    
    return {
        "district": district,
        "leaderboard": [
            {
                "rank": idx + 1,
                "user_id": user.id,
                "name": user.full_name,
                "points": user.civic_points,
                "issues_reported": user.issues_reported,
                "issues_verified": user.issues_verified,
                "is_current_user": user.id == current_user.id
            }
            for idx, user in enumerate(leaderboard)
        ],
        "current_user_rank": user_rank,
        "current_user_points": current_user.civic_points
    }

@router.get("/leaderboard/state")
async def get_state_leaderboard(
    limit: int = 50,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get state-wide leaderboard showing top civic contributors across all districts.
    """
    query = select(
        models.User.id,
        models.User.full_name,
        models.User.civic_points,
        models.User.issues_reported,
        models.User.issues_verified,
        models.User.district
    ).where(
        models.User.role == models.RoleEnum.CLIENT,
        models.User.is_active == True
    ).order_by(
        models.User.civic_points.desc()
    ).limit(limit)
    
    result = await db.execute(query)
    leaderboard = result.all()
    
    # Get current user's state rank
    user_rank_query = select(func.count(models.User.id)).where(
        models.User.role == models.RoleEnum.CLIENT,
        models.User.is_active == True,
        models.User.civic_points > current_user.civic_points
    )
    user_rank_result = await db.execute(user_rank_query)
    user_rank = user_rank_result.scalar() + 1
    
    return {
        "leaderboard": [
            {
                "rank": idx + 1,
                "user_id": user.id,
                "name": user.full_name,
                "points": user.civic_points,
                "issues_reported": user.issues_reported,
                "issues_verified": user.issues_verified,
                "district": user.district,
                "is_current_user": user.id == current_user.id
            }
            for idx, user in enumerate(leaderboard)
        ],
        "current_user_rank": user_rank,
        "current_user_points": current_user.civic_points
    }

@router.post("/me/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_user_password(
    password_data: schemas.UserChangePassword,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Allows a logged-in user to change their own password.
    """
    if not utils.verify_password(password_data.old_password, current_user.hashed_password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect old password.")
    
    current_user.hashed_password = utils.get_password_hash(password_data.new_password)
    await db.commit()
    
    return

@router.post("/issues", response_model=schemas.Problem, status_code=status.HTTP_201_CREATED)
async def create_issue(
    title: str = Form(...),
    description: str = Form(...),
    problem_type: str = Form(...),
    district: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Submit a new civic issue. The auto-assignment is now handled by a scheduled job.
    """
    if current_user.role != models.RoleEnum.CLIENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only clients can create issues.")

    # Enhanced Fraud Detection (includes AI detection, duplicate detection, and behavioral analysis)
    from ..services.fraud_detection import detect_fraud, log_fraud_attempt, get_existing_problem_details
    
    # Read file content for fraud detection
    file_content = await file.read()
    file.file.seek(0)  # Reset file pointer for save_file
    
    # Run comprehensive fraud detection
    fraud_result = await detect_fraud(
        db=db,
        user_id=current_user.id,
        image_bytes=file_content,
        latitude=latitude,
        longitude=longitude,
        problem_type=problem_type,
        title=title,
        description=description
    )
    
    # Log fraud detection result
    await log_fraud_attempt(
        db=db,
        user_id=current_user.id,
        fraud_result=fraud_result,
        additional_data={
            "problem_type": problem_type,
            "district": district,
            "title": title[:100]  # First 100 chars
        }
    )
    
    # Handle fraud detection results with user-friendly messages
    if fraud_result.action == "block":
        # Determine the primary reason for blocking
        primary_reason = fraud_result.reasons[0] if fraud_result.reasons else "suspicious activity"
        
        if "AI-generated" in primary_reason:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please upload a real photo taken with your camera. AI-generated or heavily edited images are not allowed for civic issue reports."
            )
        elif "Duplicate image" in primary_reason:
            existing_problem = await get_existing_problem_details(db, fraud_result.existing_problem_id)
            if existing_problem:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"This issue has already been reported. Please check existing issue #{fraud_result.existing_problem_id}: '{existing_problem.get('title', 'N/A')}'"
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This image has already been used to report a similar issue. Please take a new photo if this is a different problem."
                )
        elif "Too many reports" in primary_reason:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="You have submitted too many reports recently. Please wait before submitting another report to prevent spam."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your report could not be submitted due to suspicious activity. Please contact support if you believe this is an error."
            )
    
    elif fraud_result.action == "warn" and fraud_result.existing_problem_id:
        # For duplicate images with warning level, still block but with gentler message
        existing_problem = await get_existing_problem_details(db, fraud_result.existing_problem_id)
        if existing_problem:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"This issue appears to be similar to an existing report. Please check issue #{fraud_result.existing_problem_id}: '{existing_problem.get('title', 'N/A')}'. If this is a different problem, please take a new photo."
            )
    
    elif fraud_result.action == "warn":
        # Log warning but allow the report
        logger.warning(
            f"Suspicious report allowed with warning - User {current_user.id}: "
            f"Score {fraud_result.fraud_score}, Reasons: {fraud_result.reasons}"
        )

    file_url = await storage.save_file(file)
    if not file_url:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not save file.")

    wkt_location = f'POINT({longitude} {latitude})'
    new_problem = models.Problem(
        title=title, description=description, problem_type=problem_type.capitalize(),
        district=district, location=wkt_location, user_id=current_user.id
    )
    db.add(new_problem)
    await db.commit()
    await db.refresh(new_problem)
    
    new_media = models.Media(
        problem_id=new_problem.id, file_url=file_url, media_type=models.MediaTypeEnum.PHOTO_INITIAL
    )
    db.add(new_media)
    
    # Pass coordinates directly to avoid GeoAlchemy2 parsing issues
    try:
        new_problem.priority = await priority.calculate_priority_score(db, new_problem, longitude, latitude)
    except Exception as e:
        logger.warning(f"Priority calculation failed, using default: {str(e)}")
        new_problem.priority = 5.0  # Default medium priority
    
    # Award points for reporting an issue (10 points)
    current_user.civic_points += 10
    current_user.issues_reported += 1
    
    await db.commit()
    await db.refresh(new_problem)
    
    logger.info(f"User {current_user.id} awarded 10 points for reporting issue {new_problem.id}. Total points: {current_user.civic_points}")
    
    # Send confirmation notification to user
    try:
        from ..services.notifications import send_notification_to_user
        await send_notification_to_user(
            user_id=current_user.id,
            message=f"Your issue '{new_problem.title}' has been submitted successfully. You earned 10 civic points! 🎉",
            db=db,
            title="Issue Reported Successfully ✅",
            notification_type="issue_created",
            data={
                "issue_id": str(new_problem.id),
                "points_earned": "10"
            }
        )
    except Exception as e:
        logger.warning(f"Failed to send issue creation notification: {str(e)}")
    
    query = select(models.Problem).where(models.Problem.id == new_problem.id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.user),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.department)
    )
    final_problem = (await db.execute(query)).scalar_one()
    
    return final_problem

@router.get("/issues", response_model=List[schemas.Problem])
async def get_my_issues(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get a list of all issues submitted by the currently logged-in user.
    """
    query = select(models.Problem).where(models.Problem.user_id == current_user.id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).options(
            selectinload(models.WorkerProfile.user),
            selectinload(models.WorkerProfile.department)
        )
    ).order_by(models.Problem.created_at.desc())
    
    result = await db.execute(query)
    problems = result.scalars().all()
    
    # Process problems to ensure location is properly formatted
    return utils.process_problems_location(problems)

@router.get("/issues/{problem_id}", response_model=schemas.Problem)
async def get_issue_by_id(
    problem_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get details of a specific issue by its ID.
    - Clients can only view their own issues
    - Admins can view any issue in their district
    - Super Admins can view any issue
    - Workers can view any issue assigned to them
    """
    # Build query based on user role
    if current_user.role == models.RoleEnum.CLIENT:
        # Clients can only see their own issues
        query = select(models.Problem).where(
            models.Problem.id == problem_id,
            models.Problem.user_id == current_user.id
        )
    elif current_user.role == models.RoleEnum.ADMIN:
        # Admins can see any issue in their district
        query = select(models.Problem).where(
            models.Problem.id == problem_id,
            models.Problem.district == current_user.district
        )
    elif current_user.role == models.RoleEnum.SUPER_ADMIN:
        # Super admins can see any issue
        query = select(models.Problem).where(
            models.Problem.id == problem_id
        )
    elif current_user.role == models.RoleEnum.WORKER:
        # Workers can see issues assigned to them or in their district
        worker_profile_query = select(models.WorkerProfile).where(
            models.WorkerProfile.user_id == current_user.id
        )
        worker_profile = (await db.execute(worker_profile_query)).scalar_one_or_none()
        
        if worker_profile:
            query = select(models.Problem).where(
                models.Problem.id == problem_id,
                models.Problem.district == current_user.district
            )
        else:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker profile not found.")
    else:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    
    # Add relationships to query
    query = query.options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).options(
            selectinload(models.WorkerProfile.user),
            selectinload(models.WorkerProfile.department)
        )
    )
    
    problem = (await db.execute(query)).scalar_one_or_none()
    if not problem:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Problem not found or you don't have access.")
    
    # Process problem to ensure location is properly formatted
    return utils.process_single_problem_location(problem)

@router.post("/issues/{problem_id}/feedback", response_model=schemas.Feedback, status_code=status.HTTP_201_CREATED)
async def create_feedback_for_issue(
    problem_id: int,
    feedback_data: schemas.FeedbackCreate,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Allows a client to submit feedback for their completed issue.
    """
    query = select(models.Problem).where(models.Problem.id == problem_id, models.Problem.user_id == current_user.id)
    problem = (await db.execute(query)).scalar_one_or_none()

    if not problem:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Problem not found or you don't have access.")
    
    if problem.status not in [models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You can only give feedback on a completed or verified issue.")

    sentiment_analysis = sentiment.analyze_sentiment_with_confidence(feedback_data.comment)

    new_feedback = models.Feedback(
        **feedback_data.model_dump(),
        problem_id=problem_id,
        user_id=current_user.id,
        sentiment=sentiment_analysis['sentiment'],
        sentiment_confidence=sentiment_analysis['confidence']
    )
    db.add(new_feedback)
    
    # Update problem status to VERIFIED and award points (5 points for verification)
    problem.status = models.ProblemStatusEnum.VERIFIED
    current_user.civic_points += 5
    current_user.issues_verified += 1
    
    # Fetch worker data and FCM token BEFORE commit
    worker_user_id = None
    worker_fcm_token = None
    if problem.assigned_worker_id:
        worker_query = select(models.WorkerProfile).options(
            selectinload(models.WorkerProfile.user)
        ).where(models.WorkerProfile.id == problem.assigned_worker_id)
        worker_profile = (await db.execute(worker_query)).scalar_one_or_none()
        if worker_profile:
            worker_user_id = worker_profile.user_id
            worker_fcm_token = worker_profile.user.fcm_token
    
    # Store data for notification
    problem_id_stored = problem.id
    problem_title = problem.title
    rating = feedback_data.rating
    
    await db.commit()
    await db.refresh(new_feedback)
    
    logger.info(f"User {current_user.id} awarded 5 points for verifying issue {problem_id}. Total points: {current_user.civic_points}")
    
    # Send push notification to worker using FCM token
    if worker_user_id and worker_fcm_token:
        try:
            from ..services.push_notifications import send_push_to_token
            stars = "⭐" * rating
            await send_push_to_token(
                fcm_token=worker_fcm_token,
                title="Feedback Received 🎉",
                body=f"You received {stars} for: {problem_title}",
                notification_type="feedback_received",
                data={
                    "issue_id": str(problem_id_stored),
                    "rating": str(rating),
                    "action": "view_feedback"
                }
            )
            logger.info(f"✅ Feedback notification sent to worker {worker_user_id}")
        except Exception as e:
            logger.warning(f"Push notification failed: {str(e)}")
    
    return new_feedback

@router.put("/feedback/{feedback_id}", response_model=schemas.Feedback)
async def update_feedback(
    feedback_id: int,
    feedback_data: schemas.FeedbackCreate,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Allows a client to update their feedback.
    """
    query = select(models.Feedback).where(
        models.Feedback.id == feedback_id,
        models.Feedback.user_id == current_user.id
    )
    feedback = (await db.execute(query)).scalar_one_or_none()

    if not feedback:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Feedback not found or you don't have access.")

    # Update sentiment based on new comment
    sentiment_analysis = sentiment.analyze_sentiment_with_confidence(feedback_data.comment)
    
    feedback.comment = feedback_data.comment
    feedback.rating = feedback_data.rating
    feedback.sentiment = sentiment_analysis['sentiment']
    feedback.sentiment_confidence = sentiment_analysis['confidence']
    
    await db.commit()
    await db.refresh(feedback)
    return feedback

@router.delete("/feedback/{feedback_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_feedback(
    feedback_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Allows a client to delete their feedback.
    """
    query = select(models.Feedback).where(
        models.Feedback.id == feedback_id,
        models.Feedback.user_id == current_user.id
    )
    feedback = (await db.execute(query)).scalar_one_or_none()

    if not feedback:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Feedback not found or you don't have access.")

    await db.delete(feedback)
    await db.commit()
    return

@router.post("/issues/{problem_id}/verify", response_model=schemas.Problem)
async def verify_issue_completion(
    problem_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Allows a client to verify that a completed task has been done satisfactorily.
    """
    query = select(models.Problem).where(models.Problem.id == problem_id, models.Problem.user_id == current_user.id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.user),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.department)
    )
    problem = (await db.execute(query)).scalar_one_or_none()

    if not problem:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Problem not found or you don't have access.")
    
    if problem.status != models.ProblemStatusEnum.COMPLETED:
         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot verify. Problem status is '{problem.status.value}', not 'COMPLETED'.")
    
    problem.status = models.ProblemStatusEnum.VERIFIED
    
    # Fetch all data including FCM tokens BEFORE commit to avoid lazy loading
    worker_user_id = None
    worker_fcm_token = None
    if problem.assigned_worker_id:
        worker_query = select(models.WorkerProfile).options(
            selectinload(models.WorkerProfile.user)
        ).where(models.WorkerProfile.id == problem.assigned_worker_id)
        worker_profile = (await db.execute(worker_query)).scalar_one_or_none()
        if worker_profile:
            worker_user_id = worker_profile.user_id
            worker_fcm_token = worker_profile.user.fcm_token
    
    # Get reporter FCM token
    reporter_query = select(models.User).where(models.User.id == problem.user_id)
    reporter_user = (await db.execute(reporter_query)).scalar_one_or_none()
    reporter_fcm_token = reporter_user.fcm_token if reporter_user else None
    
    # Store data for notifications
    problem_id = problem.id
    problem_title = problem.title
    reporter_id = problem.user_id
    
    await db.commit()
    
    # Send push notifications using FCM tokens (no db queries needed)
    if worker_user_id and (worker_fcm_token or reporter_fcm_token):
        try:
            from ..services.push_notifications import send_push_to_token
            
            # Notify reporter
            if reporter_fcm_token:
                await send_push_to_token(
                    fcm_token=reporter_fcm_token,
                    title="Issue Verified ✅",
                    body=f"Your issue has been verified: {problem_title}. Please provide feedback!",
                    notification_type="issue_verified",
                    data={
                        "issue_id": str(problem_id),
                        "action": "provide_feedback"
                    }
                )
                logger.info(f"✅ Verification notification sent to reporter {reporter_id}")
            
            # Notify worker
            if worker_fcm_token:
                await send_push_to_token(
                    fcm_token=worker_fcm_token,
                    title="Task Verified ⭐",
                    body=f"Your completed task has been verified: {problem_title}",
                    notification_type="issue_verified",
                    data={
                        "issue_id": str(problem_id),
                        "action": "view_task"
                    }
                )
                logger.info(f"✅ Verification notification sent to worker {worker_user_id}")
                
        except Exception as e:
            logger.warning(f"Push notification failed: {str(e)}")
    
    # Refresh with eager loading
    query = select(models.Problem).where(models.Problem.id == problem_id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.user),
        selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.department)
    )
    problem = (await db.execute(query)).scalar_one()
    return problem
    
@router.get("/dashboard/my-district", response_model=schemas.UserDashboardStats)
async def get_my_district_stats(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    
    base_query = select(func.count(models.Problem.id)).where(
        models.Problem.district == current_user.district,
        models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED])
    )
    
    total_resolved_query = base_query
    recent_resolved_query = base_query.where(models.Problem.updated_at >= thirty_days_ago)

    total_resolved_count = (await db.execute(total_resolved_query)).scalar_one()
    recent_resolved_count = (await db.execute(recent_resolved_query)).scalar_one()

    return {
        "scope": f"{current_user.district} District",
        "total_problems_resolved": total_resolved_count,
        "problems_resolved_last_30_days": recent_resolved_count,
    }

@router.get("/dashboard/my-district/details", response_model=schemas.ClientDistrictStats)
async def get_my_district_detailed_stats(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get detailed statistics for the current user's district, including status and type breakdowns.
    """
    district_filter = (models.Problem.district == current_user.district)
    
    status_query = select(
        models.Problem.status,
        func.count(models.Problem.id)
    ).where(district_filter).group_by(models.Problem.status)
    
    status_results = await db.execute(status_query)
    status_breakdown = {status.value: count for status, count in status_results}
    
    type_query = select(
        models.Problem.problem_type,
        func.count(models.Problem.id)
    ).where(district_filter).group_by(models.Problem.problem_type)
    
    type_results = await db.execute(type_query)
    type_breakdown = {ptype: count for ptype, count in type_results}
    
    total_problems = sum(status_breakdown.values())

    return schemas.ClientDistrictStats(
        district_name=current_user.district,
        total_problems=total_problems,
        status_breakdown=status_breakdown,
        type_breakdown=type_breakdown
    )

@router.get("/dashboard/haryana-overview", response_model=schemas.UserDashboardStats)
async def get_haryana_overview_stats(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get overall Haryana statistics (state-wide resolved problems).
    """
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    
    base_query = select(func.count(models.Problem.id)).where(
        models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED])
    )
    
    total_resolved_query = base_query
    recent_resolved_query = base_query.where(models.Problem.updated_at >= thirty_days_ago)

    total_resolved_count = (await db.execute(total_resolved_query)).scalar_one()
    recent_resolved_count = (await db.execute(recent_resolved_query)).scalar_one()

    return {
        "scope": "Haryana State",
        "total_problems_resolved": total_resolved_count,
        "problems_resolved_last_30_days": recent_resolved_count,
    }

# ===== VOICE-TO-TEXT ENDPOINTS =====

@router.post("/voice-to-text", response_model=schemas.VoiceToTextResponse)
async def convert_voice_to_text(
    audio_file: UploadFile = File(...),
    language: str = Form(default="en-IN"),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Convert voice recording to text.
    
    Supports:
    - English (en-IN, en-US, en-GB)
    - Hindi (hi-IN)
    - Punjabi (pa-IN)
    
    The audio will be automatically transcribed to text that can be used
    for issue descriptions, feedback, or any text field.
    """
    # Validate audio file - check both content type and filename extension
    valid_audio_extensions = {'.webm', '.ogg', '.mp3', '.wav', '.m4a', '.aac', '.opus', '.flac'}
    file_extension = Path(audio_file.filename or '').suffix.lower()
    
    is_valid_content_type = audio_file.content_type and audio_file.content_type.startswith('audio/')
    is_valid_extension = file_extension in valid_audio_extensions
    
    if not is_valid_content_type and not is_valid_extension:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File must be an audio file. Got: {audio_file.content_type or 'unknown type'}, extension: {file_extension or 'no extension'}"
        )
    
    # Read audio bytes
    audio_bytes = await audio_file.read()
    
    if len(audio_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file is empty"
        )
    
    # Check file size (max 10MB for audio)
    max_audio_size = 10 * 1024 * 1024  # 10MB
    if len(audio_bytes) > max_audio_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file too large. Maximum size is 10MB"
        )
    
    # Convert audio to text
    text = await convert_audio_to_text(audio_bytes, language)
    
    return schemas.VoiceToTextResponse(
        text=text,
        language=language,
        confidence=1.0
    )

@router.get("/voice-to-text/languages", response_model=schemas.SupportedLanguagesResponse)
async def get_supported_voice_languages(
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get list of supported languages for voice-to-text conversion.
    """
    return schemas.SupportedLanguagesResponse(
        languages=get_supported_languages()
    )

@router.put("/issues/{issue_id}", response_model=schemas.Problem)
async def update_issue(
    issue_id: int,
    title: str = Form(...),
    description: str = Form(...),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Update issue title and description (only for PENDING or ASSIGNED status).
    User can only update their own issues.
    """
    # Get the issue
    issue_query = select(models.Problem).where(models.Problem.id == issue_id)
    issue = (await db.execute(issue_query)).scalar_one_or_none()
    
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    
    # Check if user owns this issue
    if issue.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only update your own issues")
    
    # Check if issue status allows editing
    if issue.status not in [models.ProblemStatusEnum.PENDING, models.ProblemStatusEnum.ASSIGNED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot edit issue with status '{issue.status.value}'. Only PENDING or ASSIGNED issues can be edited."
        )
    
    # Update the issue
    issue.title = title.strip()
    issue.description = description.strip()
    issue.updated_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(issue)
    
    logger.info(f"User {current_user.id} updated issue {issue_id}")
    
    # Reload with relationships
    final_query = select(models.Problem).where(models.Problem.id == issue_id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).options(
            selectinload(models.WorkerProfile.user),
            selectinload(models.WorkerProfile.department)
        )
    )
    updated_issue = (await db.execute(final_query)).scalar_one()
    
    return updated_issue

@router.delete("/issues/{issue_id}", status_code=status.HTTP_200_OK)
async def delete_issue(
    issue_id: int,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Delete an issue (only for PENDING or ASSIGNED status).
    User can only delete their own issues.
    """
    # Get the issue
    issue_query = select(models.Problem).where(models.Problem.id == issue_id)
    issue = (await db.execute(issue_query)).scalar_one_or_none()
    
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    
    # Check if user owns this issue
    if issue.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own issues")
    
    # Check if issue status allows deletion
    if issue.status not in [models.ProblemStatusEnum.PENDING, models.ProblemStatusEnum.ASSIGNED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete issue with status '{issue.status.value}'. Only PENDING or ASSIGNED issues can be deleted."
        )
    
    # If assigned, decrement worker's task count
    if issue.assigned_worker_id:
        worker_query = select(models.WorkerProfile).where(models.WorkerProfile.id == issue.assigned_worker_id)
        worker = (await db.execute(worker_query)).scalar_one_or_none()
        if worker and worker.daily_task_count > 0:
            worker.daily_task_count -= 1
    
    # Deduct civic points from user (10 points for reporting issue)
    # This prevents users from gaming the system by repeatedly reporting and deleting issues
    if current_user.civic_points >= 10:
        current_user.civic_points -= 10
    else:
        current_user.civic_points = 0  # Don't go negative
    
    # Decrement issues_reported count
    if current_user.issues_reported > 0:
        current_user.issues_reported -= 1
    
    logger.info(
        f"User {current_user.id} deleted issue {issue_id}. "
        f"Deducted 10 civic points. New total: {current_user.civic_points}"
    )
    
    # Delete associated media files
    media_query = select(models.Media).where(models.Media.problem_id == issue_id)
    media_files = (await db.execute(media_query)).scalars().all()
    for media in media_files:
        await db.delete(media)
    
    # Delete the issue
    await db.delete(issue)
    await db.commit()
    
    return {
        "message": "Issue deleted successfully",
        "issue_id": issue_id,
        "points_deducted": 10,
        "new_civic_points": current_user.civic_points
    }
