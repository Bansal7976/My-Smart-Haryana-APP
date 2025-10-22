# in app/routers/admin.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, case, extract
from sqlalchemy.orm import selectinload
from typing import List
from datetime import datetime, timedelta

from .. import database, schemas, models, utils

router = APIRouter(prefix="/admin", tags=["District Admin"])

async def get_current_admin_user(current_user: models.User = Depends(utils.get_current_user)):
    if current_user.role != models.RoleEnum.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Admin role required.")
    return current_user

@router.post("/departments", response_model=schemas.Department, status_code=status.HTTP_201_CREATED)
async def create_department(department: schemas.DepartmentCreate, db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(models.Department).where(models.Department.name.ilike(department.name))
    if (await db.execute(query)).scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Department already exists.")
    new_dept = models.Department(name=department.name.capitalize())
    db.add(new_dept)
    await db.commit()
    await db.refresh(new_dept)
    return new_dept

@router.post("/workers", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
async def create_worker(worker_data: schemas.AdminCreateWorker, db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    if worker_data.district != admin_user.district:
        raise HTTPException(status_code=403, detail="Admin can only create workers in their own district.")
    user_query = select(models.User).where(models.User.email == worker_data.email)
    if (await db.execute(user_query)).scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A user with this email already exists.")
    dept_query = select(models.Department).where(models.Department.id == worker_data.department_id)
    if not (await db.execute(dept_query)).scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Department not found.")
    hashed_password = utils.get_password_hash(worker_data.password)
    new_user = models.User(**worker_data.model_dump(exclude={"password", "department_id"}), hashed_password=hashed_password, role=models.RoleEnum.WORKER)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    new_worker_profile = models.WorkerProfile(user_id=new_user.id, department_id=worker_data.department_id)
    db.add(new_worker_profile)
    await db.commit()
    return new_user

@router.delete("/workers/{worker_user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_worker(worker_user_id: int, db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    user_query = select(models.User).where(models.User.id == worker_user_id, models.User.role == models.RoleEnum.WORKER, models.User.district == admin_user.district)
    worker_user = (await db.execute(user_query)).scalar_one_or_none()
    if not worker_user:
        raise HTTPException(status_code=404, detail="Worker not found in your district.")
    worker_user.is_active = False
    await db.commit()
    return

@router.get("/problems", response_model=List[schemas.Problem])
async def get_problems_for_my_district(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(models.Problem).options(selectinload(models.Problem.submitted_by), selectinload(models.Problem.media_files)).where(models.Problem.district == admin_user.district).order_by(models.Problem.created_at.desc())
    result = await db.execute(query)
    return result.scalars().all()

@router.get("/analytics/stats", response_model=schemas.AdminStats)
async def get_analytics_stats(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    district_filter = (models.Problem.district == admin_user.district)
    status_counts_query = select(func.count(models.Problem.id).label("total"), func.count(case((models.Problem.status == 'PENDING', 1))).label("pending"), func.count(case((models.Problem.status == 'ASSIGNED', 1))).label("assigned"), func.count(case((models.Problem.status == 'COMPLETED', 1))).label("completed"), func.count(case((models.Problem.status == 'VERIFIED', 1))).label("verified")).where(district_filter)
    status_counts = (await db.execute(status_counts_query)).first()
    res_time_query = select(func.avg(extract('epoch', models.Problem.updated_at) - extract('epoch', models.Problem.created_at))).where(models.Problem.status.in_(['COMPLETED', 'VERIFIED']), district_filter)
    avg_seconds = (await db.execute(res_time_query)).scalar_one_or_none()
    avg_hours = round(avg_seconds / 3600, 2) if avg_seconds else None
    return {"total_problems": status_counts.total, "pending_problems": status_counts.pending, "assigned_problems": status_counts.assigned, "completed_problems": status_counts.completed, "verified_problems": status_counts.verified, "average_resolution_time_hours": avg_hours}

@router.get("/analytics/heatmap", response_model=List[schemas.HeatmapPoint])
async def get_heatmap_data(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(func.ST_Y(models.Problem.location).label("latitude"), func.ST_X(models.Problem.location).label("longitude")).where(models.Problem.created_at >= datetime.utcnow() - timedelta(days=90), models.Problem.district == admin_user.district)
    result = await db.execute(query)
    return result.all()

@router.get("/analytics/department-activity", response_model=List[schemas.DepartmentActivity])
async def get_department_activity(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(models.Department.name, func.count(models.Problem.id).label("total_assigned")).join(models.WorkerProfile).join(models.Problem).where(models.Problem.district == admin_user.district).group_by(models.Department.name).order_by(func.count(models.Problem.id).desc())
    result = await db.execute(query)
    return [{"department_name": name, "total_assigned": count} for name, count in result.all()]

@router.get("/analytics/worker-performance", response_model=List[schemas.WorkerPerformanceStats])
async def get_worker_performance(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = (select(models.WorkerProfile.id, models.User.full_name, models.Department.name, func.count(models.Problem.id).label("tasks_completed"), func.avg(models.Feedback.rating).label("average_rating"))
             .select_from(models.WorkerProfile).join(models.User).join(models.Department)
             .outerjoin(models.Problem, models.WorkerProfile.id == models.Problem.assigned_worker_id)
             .outerjoin(models.Feedback, models.Problem.id == models.Feedback.problem_id)
             .where(models.User.district == admin_user.district, models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]))
             .group_by(models.WorkerProfile.id, models.User.full_name, models.Department.name).order_by(models.User.full_name))
    result = await db.execute(query)
    return [{"worker_id": row.id, "worker_name": row.full_name, "department_name": row.name, "tasks_completed": row.tasks_completed, "average_rating": round(row.average_rating, 2) if row.average_rating else None} for row in result.all()]

@router.get("/workers", response_model=List[schemas.WorkerWithProfile])
async def get_all_workers_in_district(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Get all workers in admin's district with their department info.
    """
    query = select(models.WorkerProfile).join(models.User).join(models.Department).where(
        models.User.district == admin_user.district
    ).options(
        selectinload(models.WorkerProfile.user),
        selectinload(models.WorkerProfile.department)
    ).order_by(models.User.full_name)
    
    result = await db.execute(query)
    workers = result.scalars().all()
    
    return [
        {
            "id": w.id,
            "user": w.user,
            "department": w.department,
            "daily_task_count": w.daily_task_count
        }
        for w in workers
    ]

@router.get("/departments", response_model=List[schemas.Department])
async def get_all_departments(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Get all departments (for creating workers).
    """
    query = select(models.Department).order_by(models.Department.name)
    result = await db.execute(query)
    return result.scalars().all()