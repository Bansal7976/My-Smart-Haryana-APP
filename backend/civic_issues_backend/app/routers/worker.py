from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select  
from sqlalchemy import func, text          
from sqlalchemy.orm import selectinload
from typing import List
from .. import database, schemas, models, utils, storage
import math

router = APIRouter(prefix="/worker", tags=["Worker"])
async def get_current_worker_profile(
    current_user: models.User = Depends(utils.get_current_user),
    db: AsyncSession = Depends(database.get_db)
):
    if current_user.role != models.RoleEnum.WORKER:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Worker role required.")
    
    query = select(models.WorkerProfile).where(models.WorkerProfile.user_id == current_user.id)
    worker_profile = (await db.execute(query)).scalar_one_or_none()
    
    if not worker_profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is not registered as a worker profile.")
        
    return worker_profile

@router.get("/me/stats", response_model=schemas.WorkerSelfStats)
async def get_my_worker_stats(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user),
    current_worker: models.WorkerProfile = Depends(get_current_worker_profile)
):
    """
    Get performance statistics for the currently logged-in worker.
    """
    query = (
        select(
            func.count(models.Problem.id).label("tasks_completed"),
            func.avg(models.Feedback.rating).label("average_rating")
        )
        .select_from(models.Problem)
        .outerjoin(models.Feedback, models.Problem.id == models.Feedback.problem_id)
        .where(
            models.Problem.assigned_worker_id == current_worker.id,
            models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED])
        )
    )
    
    result = (await db.execute(query)).first()
    
    avg_rating = round(result.average_rating, 2) if result.average_rating else None
    
    return schemas.WorkerSelfStats(
        worker_name=current_user.full_name,
        tasks_completed=result.tasks_completed or 0,
        average_rating=avg_rating
    )

@router.get("/tasks", response_model=List[schemas.Problem])
async def get_my_assigned_tasks(
    db: AsyncSession = Depends(database.get_db),
    current_worker: models.WorkerProfile = Depends(get_current_worker_profile)
):
    query = select(models.Problem).where(
        models.Problem.assigned_worker_id == current_worker.id,
        models.Problem.status == models.ProblemStatusEnum.ASSIGNED
    ).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files)
    ).order_by(models.Problem.priority.desc())
    
    result = await db.execute(query)
    return result.scalars().all()

@router.post("/tasks/{problem_id}/complete", response_model=schemas.Problem)
async def complete_task(
    problem_id: int,
    proof_file: UploadFile = File(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    db: AsyncSession = Depends(database.get_db),
    current_worker: models.WorkerProfile = Depends(get_current_worker_profile)
):
    """
    Complete a task with proof photo and GPS verification.
    Worker's GPS location must be within 500 meters of the original problem location.
    """
    query = select(models.Problem).where(models.Problem.id == problem_id).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files)
    )
    problem = (await db.execute(query)).scalar_one_or_none()

    if not problem:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Problem not found.")
    
    if problem.assigned_worker_id != current_worker.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This task is not assigned to you.")
        
    if problem.status != models.ProblemStatusEnum.ASSIGNED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Task is not in ASSIGNED state, it is currently {problem.status.value}.")

    # 🔒 GPS VERIFICATION - Critical Security Feature
    # Verify worker is within 500 meters of the problem location
    verification_query = text("""
        SELECT ST_Distance(
            location::geography,
            ST_SetSRID(ST_MakePoint(:worker_lon, :worker_lat), 4326)::geography
        ) as distance_meters
        FROM problems
        WHERE id = :problem_id
    """)
    
    distance_result = await db.execute(
        verification_query,
        {"worker_lon": longitude, "worker_lat": latitude, "problem_id": problem_id}
    )
    distance_meters = distance_result.scalar_one()
    
    # Must be within 500 meters (0.5 km)
    MAX_DISTANCE_METERS = 500
    
    if distance_meters > MAX_DISTANCE_METERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"GPS verification failed! You must be at the problem location to mark it complete. "
                   f"You are {distance_meters:.0f} meters away (max allowed: {MAX_DISTANCE_METERS} meters)."
        )

    # Save proof photo
    file_url = await storage.save_file(proof_file)
    if not file_url:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not save proof file.")
        
    new_media = models.Media(
        problem_id=problem.id, file_url=file_url, media_type=models.MediaTypeEnum.PHOTO_PROOF
    )
    db.add(new_media)
    
    # Mark as completed
    problem.status = models.ProblemStatusEnum.COMPLETED
    await db.commit()
    await db.refresh(problem)
    
    return problem