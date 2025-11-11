from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from .. import database, schemas, models, utils

router = APIRouter(prefix="/super-admin", tags=["Super Admin"])


async def get_current_super_admin_user(current_user: models.User = Depends(utils.get_current_user)):
    if current_user.role != models.RoleEnum.SUPER_ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied: Super Admin role required.")
    return current_user

@router.post("/create-admin", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
async def create_district_admin(
    admin_data: schemas.SuperAdminCreateAdmin,
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Create a new District Admin account.
    """
    query = select(models.User).where(models.User.email == admin_data.email)
    if (await db.execute(query)).scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A user with this email already exists.")

    hashed_password = utils.get_password_hash(admin_data.password)
    new_admin_user = models.User(
        **admin_data.model_dump(exclude={"password"}),
        hashed_password=hashed_password,
        role=models.RoleEnum.ADMIN
    )
    db.add(new_admin_user)
    await db.commit()
    await db.refresh(new_admin_user)
    
    return new_admin_user

@router.get("/admins", response_model=List[schemas.User])
async def get_all_admins(
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Get a list of all District Admins.
    """
    query = select(models.User).where(models.User.role == models.RoleEnum.ADMIN).order_by(models.User.district)
    result = await db.execute(query)
    return result.scalars().all()

@router.delete("/admins/{admin_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_admin(
    admin_id: int,
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Deactivate/remove a district admin.
    """
    query = select(models.User).where(
        models.User.id == admin_id,
        models.User.role == models.RoleEnum.ADMIN
    )
    admin_user = (await db.execute(query)).scalar_one_or_none()
    
    if not admin_user:
        raise HTTPException(status_code=404, detail="Admin not found.")
    
    admin_user.is_active = False
    await db.commit()
    return

@router.put("/admins/{admin_id}/activate", status_code=status.HTTP_204_NO_CONTENT)
async def activate_admin(
    admin_id: int,
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Activate a district admin.
    """
    query = select(models.User).where(
        models.User.id == admin_id,
        models.User.role == models.RoleEnum.ADMIN
    )
    admin_user = (await db.execute(query)).scalar_one_or_none()
    
    if not admin_user:
        raise HTTPException(status_code=404, detail="Admin not found.")
    
    admin_user.is_active = True
    await db.commit()
    return

@router.get("/analytics/districts", response_model=List[schemas.DistrictStats])
async def get_all_districts_analytics(
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Get statistics for all districts - shows best performing districts.
    """
    from sqlalchemy import func, case
    
    # Get problem stats per district
    query = select(
        models.Problem.district,
        func.count(models.Problem.id).label("total_problems"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label("pending"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label("assigned"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label("completed"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label("verified")
    ).group_by(models.Problem.district).order_by(func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).desc())
    
    result = await db.execute(query)
    districts = result.all()
    
    # Get workers count per district
    workers_query = select(
        models.User.district,
        func.count(models.User.id).label("workers_count")
    ).where(
        models.User.role == models.RoleEnum.WORKER,
        models.User.is_active == True
    ).group_by(models.User.district)
    
    workers_result = await db.execute(workers_query)
    workers_by_district = {row.district: row.workers_count for row in workers_result.all()}
    
    return [
        {
            "district_name": row.district,
            "total_problems": row.total_problems,
            "pending_problems": row.pending,
            "assigned_problems": row.assigned,
            "completed_problems": row.completed,
            "verified_problems": row.verified,
            "total_workers": workers_by_district.get(row.district, 0),
            "resolution_rate": round((row.completed + row.verified) / row.total_problems * 100, 1) if row.total_problems > 0 else 0.0
        }
        for row in districts
    ]

@router.get("/analytics/overview", response_model=schemas.SuperAdminOverview)
async def get_haryana_overview(
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Get overall Haryana statistics and metrics.
    """
    from sqlalchemy import func, case, distinct
    
    # Overall stats
    stats_query = select(
        func.count(models.Problem.id).label("total"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label("pending"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label("assigned"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label("completed"),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label("verified")
    )
    stats = (await db.execute(stats_query)).first()
    
    # Districts count
    districts_query = select(func.count(distinct(models.Problem.district)))
    active_districts = (await db.execute(districts_query)).scalar()
    
    # Total users by role
    users_query = select(
        func.count(case((models.User.role == models.RoleEnum.CLIENT, 1))).label("clients"),
        func.count(case((models.User.role == models.RoleEnum.WORKER, 1))).label("workers"),
        func.count(case((models.User.role == models.RoleEnum.ADMIN, 1))).label("admins")
    )
    users = (await db.execute(users_query)).first()
    
    return {
        "total_problems": stats.total,
        "pending_problems": stats.pending,
        "assigned_problems": stats.assigned,
        "completed_problems": stats.completed,
        "verified_problems": stats.verified,
        "rejected_problems": 0,  # Not implemented in the current schema
        "active_districts": active_districts,
        "total_clients": users.clients,
        "total_workers": users.workers,
        "total_admins": users.admins,
        "resolution_rate": round((stats.completed + stats.verified) / stats.total * 100, 1) if stats.total > 0 else 0.0
    }

@router.get("/reports/department-stats")
async def get_department_statistics(
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user)
):
    """
    (Super Admin) Get problem statistics by department across all Haryana.
    """
    from sqlalchemy import func, case
    
    query = (
        select(
            models.Department.name.label("department_name"),
            func.count(models.Problem.id).label("total_problems"),
            func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label("pending"),
            func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label("assigned"),
            func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label("completed"),
            func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label("verified")
        )
        .select_from(models.WorkerProfile)
        .join(models.Department)
        .join(models.Problem, models.WorkerProfile.id == models.Problem.assigned_worker_id, isouter=True)
        .group_by(models.Department.name)
        .order_by(func.count(models.Problem.id).desc())
    )
    
    result = await db.execute(query)
    return [
        {
            "department_name": row.department_name,
            "total_problems": row.total_problems or 0,
            "pending_problems": row.pending or 0,
            "assigned_problems": row.assigned or 0,
            "completed_problems": row.completed or 0,
            "verified_problems": row.verified or 0,
            "resolution_rate": round((row.completed + row.verified) / row.total_problems * 100, 1) if row.total_problems and row.total_problems > 0 else 0.0
        }
        for row in result.all()
    ]

@router.get("/reports/top-workers")
async def get_top_workers(
    db: AsyncSession = Depends(database.get_db),
    super_admin: models.User = Depends(get_current_super_admin_user),
    limit: int = 10
):
    """
    (Super Admin) Get top performing workers across all Haryana.
    Returns workers sorted by completion count.
    """
    from sqlalchemy import func, case
    
    query = (
        select(
            models.WorkerProfile.id,
            models.User.full_name,
            models.User.district,
            models.Department.name.label("department_name"),
            func.count(models.Problem.id).label("total_assigned"),
            func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).label("completed"),
            func.avg(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), models.Feedback.rating))).label("avg_rating")
        )
        .select_from(models.WorkerProfile)
        .join(models.User)
        .join(models.Department)
        .outerjoin(models.Problem, models.WorkerProfile.id == models.Problem.assigned_worker_id)
        .outerjoin(models.Feedback, models.Problem.id == models.Feedback.problem_id)
        .where(models.User.is_active == True)
        .group_by(models.WorkerProfile.id, models.User.full_name, models.User.district, models.Department.name)
        .order_by(func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).desc())
        .limit(limit)
    )
    
    result = await db.execute(query)
    return [
        {
            "worker_id": row.id,
            "worker_name": row.full_name,
            "district": row.district,
            "department": row.department_name,
            "total_tasks": row.total_assigned or 0,
            "completed_tasks": row.completed or 0,
            "average_rating": round(row.avg_rating, 2) if row.avg_rating else None,
            "completion_rate": round(row.completed / row.total_assigned * 100, 1) if row.total_assigned and row.total_assigned > 0 else 0.0
        }
        for row in result.all()
    ]