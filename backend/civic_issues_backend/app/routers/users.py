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

    # Check for duplicate image BEFORE saving
    from ..services.duplicate_detection import check_duplicate_image, get_existing_problem_details
    
    # Read file content for duplicate check
    file_content = await file.read()
    file.file.seek(0)  # Reset file pointer for save_file
    
    # Check for duplicate images
    is_duplicate, existing_problem_id = await check_duplicate_image(db, file_content, current_user.id)
    
    if is_duplicate and existing_problem_id:
        # Get details of existing problem
        existing_problem = await get_existing_problem_details(db, existing_problem_id)
        
        if existing_problem:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"This problem already exists. Issue #{existing_problem_id}: '{existing_problem.get('title', 'N/A')}' was already submitted."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This problem already exists. A similar image was found in the system."
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
    
    await db.commit()
    await db.refresh(new_problem)
    
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
    return result.scalars().all()

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
        
    return problem

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

    sentiment_result = sentiment.analyze_sentiment(feedback_data.comment)

    new_feedback = models.Feedback(
        **feedback_data.model_dump(),
        problem_id=problem_id,
        user_id=current_user.id,
        sentiment=sentiment_result
    )
    db.add(new_feedback)
    await db.commit()
    await db.refresh(new_feedback)
    
    # Send push notification to worker
    if problem.assigned_worker_id:
        try:
            from ..services.push_notifications import notify_feedback_received
            await notify_feedback_received(
                db=db,
                worker_id=problem.assigned_to.user_id,
                issue_id=problem.id,
                issue_title=problem.title,
                rating=feedback_data.rating
            )
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
    sentiment_result = sentiment.analyze_sentiment(feedback_data.comment)
    
    feedback.comment = feedback_data.comment
    feedback.rating = feedback_data.rating
    feedback.sentiment = sentiment_result
    
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
    await db.commit()
    
    # Send push notifications to both reporter and worker
    if problem.assigned_worker_id:
        try:
            from ..services.push_notifications import notify_issue_verified
            await notify_issue_verified(
                db=db,
                reporter_id=problem.user_id,
                worker_id=problem.assigned_to.user_id,
                issue_id=problem.id,
                issue_title=problem.title
            )
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