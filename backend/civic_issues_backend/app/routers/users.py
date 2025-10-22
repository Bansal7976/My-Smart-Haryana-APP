from fastapi import (
    APIRouter, Depends, Form, UploadFile, File, 
    HTTPException, status
)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, select, case
from sqlalchemy.orm import selectinload
from typing import List, Dict
from datetime import datetime, timedelta

from .. import database, schemas, models, utils, storage
from ..services import priority, sentiment

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
    new_problem.priority = await priority.calculate_priority_score(db, new_problem, longitude, latitude)
    await db.commit()
    await db.refresh(new_problem)
    
    query = select(models.Problem).where(models.Problem.id == new_problem.id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files)
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
    """
    query = select(models.Problem).where(
        models.Problem.id == problem_id,
        models.Problem.user_id == current_user.id
    ).options(
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
    return new_feedback

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
        selectinload(models.Problem.media_files)
    )
    problem = (await db.execute(query)).scalar_one_or_none()

    if not problem:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Problem not found or you don't have access.")
    
    if problem.status != models.ProblemStatusEnum.COMPLETED:
         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot verify. Problem status is '{problem.status.value}', not 'COMPLETED'.")
    
    problem.status = models.ProblemStatusEnum.VERIFIED
    await db.commit()
    await db.refresh(problem)
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