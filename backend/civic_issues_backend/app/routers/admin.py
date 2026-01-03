# in app/routers/admin.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, case, extract
from sqlalchemy.orm import selectinload
from typing import List
from datetime import datetime, timedelta
import logging

from .. import database, schemas, models, utils

logger = logging.getLogger(__name__)

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
    """
    Deactivate a worker and reassign their pending/assigned tasks back to PENDING status.
    """
    user_query = select(models.User).where(models.User.id == worker_user_id, models.User.role == models.RoleEnum.WORKER, models.User.district == admin_user.district)
    worker_user = (await db.execute(user_query)).scalar_one_or_none()
    if not worker_user:
        raise HTTPException(status_code=404, detail="Worker not found in your district.")
    
    # Get the worker's profile to find assigned tasks
    worker_profile_query = select(models.WorkerProfile).where(models.WorkerProfile.user_id == worker_user_id)
    worker_profile = (await db.execute(worker_profile_query)).scalar_one_or_none()
    
    if worker_profile:
        # Reassign all PENDING and ASSIGNED tasks back to PENDING status with no worker
        assigned_tasks_query = select(models.Problem).where(
            models.Problem.assigned_worker_id == worker_profile.id,
            models.Problem.status.in_([models.ProblemStatusEnum.PENDING, models.ProblemStatusEnum.ASSIGNED])
        )
        assigned_tasks = (await db.execute(assigned_tasks_query)).scalars().all()
        
        for task in assigned_tasks:
            task.assigned_worker_id = None
            task.status = models.ProblemStatusEnum.PENDING
        
        # Reset worker's task count
        worker_profile.daily_task_count = 0
    
    worker_user.is_active = False
    await db.commit()
    return

@router.put("/workers/{worker_user_id}/activate", status_code=status.HTTP_204_NO_CONTENT)
async def activate_worker(worker_user_id: int, db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    """
    Activate a previously deactivated worker.
    """
    user_query = select(models.User).where(
        models.User.id == worker_user_id, 
        models.User.role == models.RoleEnum.WORKER, 
        models.User.district == admin_user.district
    )
    worker_user = (await db.execute(user_query)).scalar_one_or_none()
    
    if not worker_user:
        raise HTTPException(status_code=404, detail="Worker not found in your district.")
    
    worker_user.is_active = True
    await db.commit()
    return

@router.get("/problems", response_model=List[schemas.Problem])
async def get_problems_for_my_district(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(models.Problem).options(
        selectinload(models.Problem.submitted_by),
        selectinload(models.Problem.media_files),
        selectinload(models.Problem.feedback),
        selectinload(models.Problem.assigned_to).options(
            selectinload(models.WorkerProfile.user),
            selectinload(models.WorkerProfile.department)
        )
    ).where(models.Problem.district == admin_user.district).order_by(models.Problem.created_at.desc())
    result = await db.execute(query)
    problems = result.scalars().all()
    
    # Process problems to ensure location is properly formatted
    return utils.process_problems_location(problems)

@router.get("/analytics/stats", response_model=schemas.AdminStats)
async def get_analytics_stats(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    district_filter = (models.Problem.district == admin_user.district)
    status_counts_query = select(func.count(models.Problem.id).label("total"), func.count(case((models.Problem.status == 'PENDING', 1))).label("pending"), func.count(case((models.Problem.status == 'ASSIGNED', 1))).label("assigned"), func.count(case((models.Problem.status == 'COMPLETED', 1))).label("completed"), func.count(case((models.Problem.status == 'VERIFIED', 1))).label("verified")).where(district_filter)
    status_counts = (await db.execute(status_counts_query)).first()
    res_time_query = select(func.avg(extract('epoch', models.Problem.updated_at) - extract('epoch', models.Problem.created_at))).where(models.Problem.status.in_(['COMPLETED', 'VERIFIED']), district_filter)
    avg_seconds = (await db.execute(res_time_query)).scalar_one_or_none()
    avg_hours = round(avg_seconds / 3600, 2) if avg_seconds else None
    
    # Get total workers in district
    workers_query = select(func.count(models.User.id)).where(
        models.User.role == models.RoleEnum.WORKER,
        models.User.district == admin_user.district,
        models.User.is_active == True
    )
    total_workers = (await db.execute(workers_query)).scalar_one_or_none() or 0
    
    return {"total_problems": status_counts.total, "pending_problems": status_counts.pending, "assigned_problems": status_counts.assigned, "completed_problems": status_counts.completed, "verified_problems": status_counts.verified, "average_resolution_time_hours": avg_hours, "total_workers": total_workers}

@router.get("/analytics/heatmap", response_model=List[schemas.HeatmapPoint])
async def get_heatmap_data(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    query = select(func.ST_Y(models.Problem.location).label("latitude"), func.ST_X(models.Problem.location).label("longitude")).where(models.Problem.created_at >= datetime.utcnow() - timedelta(days=90), models.Problem.district == admin_user.district)
    result = await db.execute(query)
    return result.all()

@router.get("/analytics/department-activity", response_model=List[schemas.DepartmentActivity])
async def get_department_activity(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    try:
        # Fixed query with proper joins and filtering
        query = select(
            models.Department.name,
            func.count(models.Problem.id).label("total_assigned")
        ).select_from(
            models.Department
        ).join(
            models.WorkerProfile, models.WorkerProfile.department_id == models.Department.id
        ).join(
            models.Problem, models.Problem.assigned_worker_id == models.WorkerProfile.id
        ).join(
            models.User, models.User.id == models.WorkerProfile.user_id
        ).where(
            models.User.district == admin_user.district
        ).group_by(
            models.Department.name
        ).order_by(
            func.count(models.Problem.id).desc()
        )
        
        result = await db.execute(query)
        return [{"department_name": name, "total_assigned": count} for name, count in result.all()]
        
    except Exception as e:
        logger.error(f"Department activity query error: {str(e)}")
        # Return empty list if query fails
        return []

@router.get("/analytics/worker-performance", response_model=List[schemas.WorkerPerformanceStats])
async def get_worker_performance(db: AsyncSession = Depends(database.get_db), admin_user: models.User = Depends(get_current_admin_user)):
    # Get all workers with their assigned and completed task counts
    query = (
        select(
            models.WorkerProfile.id,
            models.User.full_name,
            models.Department.name,
            func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.ASSIGNED, models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).label("tasks_assigned"),
            func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).label("tasks_completed"),
            func.avg(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), models.Feedback.rating))).label("average_rating")
        )
        .select_from(models.WorkerProfile)
        .join(models.User)
        .join(models.Department)
        .outerjoin(models.Problem, models.WorkerProfile.id == models.Problem.assigned_worker_id)
        .outerjoin(models.Feedback, models.Problem.id == models.Feedback.problem_id)
        .where(models.User.district == admin_user.district)
        .group_by(models.WorkerProfile.id, models.User.full_name, models.Department.name)
        .order_by(models.User.full_name)
    )
    result = await db.execute(query)
    return [
        {
            "worker_id": row.id,
            "worker_name": row.full_name,
            "department_name": row.name,
            "tasks_assigned": row.tasks_assigned or 0,
            "tasks_completed": row.tasks_completed or 0,
            "average_rating": round(row.average_rating, 2) if row.average_rating else None
        }
        for row in result.all()
    ]

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

@router.put("/issues/{issue_id}/reassign", status_code=status.HTTP_200_OK)
async def reassign_issue_to_worker(
    issue_id: int,
    new_worker_id: int,
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    (Admin) Reassign an issue to another worker in the same department and district.
    """
    from ..services.notifications import send_notification_to_user
    
    # Get the issue
    issue_query = select(models.Problem).where(models.Problem.id == issue_id)
    issue = (await db.execute(issue_query)).scalar_one_or_none()
    
    if not issue:
        raise HTTPException(status_code=404, detail="Issue not found")
    
    # Check if issue is in admin's district
    if issue.district != admin_user.district:
        raise HTTPException(status_code=403, detail="You can only reassign issues in your district")
    
    # Check if issue status is ASSIGNED (not completed or verified)
    if issue.status != models.ProblemStatusEnum.ASSIGNED:
        raise HTTPException(
            status_code=400, 
            detail=f"Can only reassign issues with 'assigned' status. Current status: {issue.status.value}"
        )
    
    # Get current worker profile if assigned
    if issue.assigned_worker_id:
        current_worker_query = select(models.WorkerProfile).options(
            selectinload(models.WorkerProfile.department),
            selectinload(models.WorkerProfile.user)
        ).where(models.WorkerProfile.id == issue.assigned_worker_id)
        current_worker = (await db.execute(current_worker_query)).scalar_one_or_none()
    else:
        raise HTTPException(status_code=400, detail="Issue is not currently assigned to any worker")
    
    # Get new worker profile
    new_worker_query = select(models.WorkerProfile).options(
        selectinload(models.WorkerProfile.department),
        selectinload(models.WorkerProfile.user)
    ).where(models.WorkerProfile.id == new_worker_id)
    new_worker = (await db.execute(new_worker_query)).scalar_one_or_none()
    
    if not new_worker:
        raise HTTPException(status_code=404, detail="New worker not found")
    
    # Check if new worker is in the same district
    if new_worker.user.district != admin_user.district:
        raise HTTPException(status_code=403, detail="New worker must be in your district")
    
    # Check if new worker is in the same department
    if current_worker and new_worker.department_id != current_worker.department_id:
        raise HTTPException(status_code=400, detail="New worker must be in the same department")
    
    # Check if new worker is active
    if not new_worker.user.is_active:
        raise HTTPException(status_code=400, detail="New worker is not active")
    
    # Check if trying to reassign to the same worker
    if new_worker_id == issue.assigned_worker_id:
        raise HTTPException(
            status_code=400, 
            detail=f"Issue is already assigned to {new_worker.user.full_name}. Please select a different worker."
        )
    
    # Store data before commit to avoid lazy loading
    new_worker_user_id = new_worker.user_id
    new_worker_name = new_worker.user.full_name
    old_worker_user_id = current_worker.user_id if current_worker else None
    old_worker_name = current_worker.user.full_name if current_worker else None
    reporter_user_id = issue.user_id
    issue_title = issue.title
    issue_id = issue.id
    
    # Reassign the issue
    issue.assigned_worker_id = new_worker_id
    issue.updated_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(issue)
    
    # Send notifications to all parties
    try:
        # 1. Notify new worker
        await send_notification_to_user(
            user_id=new_worker_user_id,
            message=f"A task has been reassigned to you: {issue_title}",
            db=db,
            title="Task Reassigned to You 📋",
            notification_type="task_reassigned",
            data={
                "issue_id": str(issue_id),
                "action": "view_task"
            }
        )
        
        # 2. Notify previous worker
        if old_worker_user_id:
            await send_notification_to_user(
                user_id=old_worker_user_id,
                message=f"Task '{issue_title}' has been reassigned to {new_worker_name}",
                db=db,
                title="Task Removed ⚠️",
                notification_type="task_removed",
                data={
                    "issue_id": str(issue_id),
                    "new_worker": new_worker_name
                }
            )
        
        # 3. Notify reporter (citizen)
        await send_notification_to_user(
            user_id=reporter_user_id,
            message=f"Your issue '{issue_title}' has been reassigned to {new_worker_name}",
            db=db,
            title="Issue Reassigned 🔄",
            notification_type="issue_reassigned",
            data={
                "issue_id": str(issue_id),
                "new_worker": new_worker_name,
                "old_worker": old_worker_name
            }
        )
    except Exception as e:
        logger.warning(f"Reassignment notification failed: {str(e)}")
    
    return {
        "message": "Issue reassigned successfully",
        "issue_id": issue_id,
        "new_worker_id": new_worker_id,
        "new_worker_name": new_worker_name,
        "old_worker_name": old_worker_name
    }

# --- Fraud Detection Endpoints ---
@router.get("/fraud/statistics")
async def get_fraud_statistics(
    days: int = 7,
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Get fraud detection statistics for the admin's district.
    """
    from ..services.fraud_detection import get_fraud_statistics
    
    stats = await get_fraud_statistics(db, days)
    return {
        "district": admin_user.district,
        "period_days": days,
        **stats
    }

@router.get("/fraud/user/{user_id}")
async def get_user_fraud_history(
    user_id: int,
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Get fraud detection history for a specific user.
    Only shows users from admin's district.
    """
    # Verify user is in admin's district
    user_query = select(models.User).where(
        models.User.id == user_id,
        models.User.district == admin_user.district
    )
    user = (await db.execute(user_query)).scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in your district"
        )
    
    from ..services.fraud_detection import get_user_fraud_history
    
    history = await get_user_fraud_history(db, user_id)
    return {
        "user_id": user_id,
        "user_name": user.full_name,
        "district": user.district,
        "fraud_history": history
    }

@router.post("/trigger-auto-assignment")
async def trigger_manual_auto_assignment(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Manually trigger auto-assignment for testing purposes.
    """
    try:
        from ..services.auto_assignment import trigger_auto_assignment
        
        # Check pending problems first
        pending_query = select(models.Problem).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING,
            models.Problem.district == admin_user.district
        )
        pending_problems = (await db.execute(pending_query)).scalars().all()
        
        if not pending_problems:
            return {
                "message": f"No pending problems found in {admin_user.district}",
                "pending_count": 0
            }
        
        logger.info(f"Manual auto-assignment triggered by admin {admin_user.id} for {len(pending_problems)} problems")
        
        # Run auto-assignment
        await trigger_auto_assignment(db)
        
        return {
            "message": f"Auto-assignment triggered successfully for {len(pending_problems)} pending problems",
            "pending_count": len(pending_problems)
        }
        
    except Exception as e:
        logger.error(f"Manual auto-assignment failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Auto-assignment failed: {str(e)}"
        )

@router.get("/debug/database-status")
async def get_database_status(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Debug endpoint to check database status for auto-assignment troubleshooting.
    """
    try:
        # Count pending problems
        pending_query = select(func.count(models.Problem.id)).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING
        )
        pending_count = (await db.execute(pending_query)).scalar_one()
        
        # Count workers by district
        workers_query = select(
            models.User.district,
            func.count(models.WorkerProfile.id).label('worker_count')
        ).join(models.WorkerProfile).where(
            models.User.role == models.RoleEnum.WORKER,
            models.User.is_active == True
        ).group_by(models.User.district)
        
        workers_result = (await db.execute(workers_query)).all()
        workers_by_district = {row.district: row.worker_count for row in workers_result}
        
        # Count departments
        dept_query = select(func.count(models.Department.id))
        dept_count = (await db.execute(dept_query)).scalar_one()
        
        # Get pending problems by district and type
        pending_details_query = select(
            models.Problem.district,
            models.Problem.problem_type,
            func.count(models.Problem.id).label('count')
        ).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING
        ).group_by(models.Problem.district, models.Problem.problem_type)
        
        pending_details = (await db.execute(pending_details_query)).all()
        
        return {
            "pending_problems": pending_count,
            "departments": dept_count,
            "workers_by_district": workers_by_district,
            "pending_by_district_type": [
                {
                    "district": row.district,
                    "problem_type": row.problem_type,
                    "count": row.count
                }
                for row in pending_details
            ],
            "message": "Database status retrieved successfully"
        }
        
    except Exception as e:
        logger.error(f"Database status check error: {str(e)}")
        return {
            "error": str(e),
            "message": "Failed to retrieve database status"
        }

@router.post("/debug/create-test-workers")
async def create_test_workers(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Create test workers for debugging auto-assignment.
    Creates one worker for each department in the admin's district.
    """
    try:
        # Get all departments
        dept_query = select(models.Department)
        departments = (await db.execute(dept_query)).scalars().all()
        
        created_workers = []
        
        for dept in departments:
            # Check if worker already exists for this department and district
            existing_query = select(models.WorkerProfile).join(models.User).where(
                models.WorkerProfile.department_id == dept.id,
                models.User.district == admin_user.district,
                models.User.role == models.RoleEnum.WORKER
            )
            existing_worker = (await db.execute(existing_query)).scalar_one_or_none()
            
            if not existing_worker:
                # Create test worker
                worker_email = f"worker.{dept.name.lower().replace(' ', '')}.{admin_user.district.lower()}@test.com"
                
                # Check if email already exists
                email_query = select(models.User).where(models.User.email == worker_email)
                if (await db.execute(email_query)).scalar_one_or_none():
                    continue  # Skip if email exists
                
                # Create user
                hashed_password = utils.get_password_hash("worker123")
                new_user = models.User(
                    full_name=f"{dept.name} Worker - {admin_user.district}",
                    email=worker_email,
                    hashed_password=hashed_password,
                    role=models.RoleEnum.WORKER,
                    district=admin_user.district,
                    pincode="000000",
                    is_active=True
                )
                db.add(new_user)
                await db.flush()  # Get the ID
                
                # Create worker profile
                worker_profile = models.WorkerProfile(
                    user_id=new_user.id,
                    department_id=dept.id,
                    daily_task_count=0
                )
                db.add(worker_profile)
                
                created_workers.append({
                    "name": new_user.full_name,
                    "email": worker_email,
                    "department": dept.name,
                    "district": admin_user.district
                })
        
        await db.commit()
        
        return {
            "message": f"Created {len(created_workers)} test workers",
            "workers": created_workers,
            "note": "Password for all test workers: worker123"
        }
        
    except Exception as e:
        logger.error(f"Test worker creation error: {str(e)}")
        await db.rollback()
        return {
            "error": str(e),
            "message": "Failed to create test workers"
        }

@router.get("/debug/problem-types")
async def get_problem_types_analysis(
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Debug endpoint to analyze problem types and their mapping to departments.
    """
    try:
        # Get all unique problem types from the database
        problem_types_query = select(
            models.Problem.problem_type,
            func.count(models.Problem.id).label('count'),
            models.Problem.status
        ).group_by(models.Problem.problem_type, models.Problem.status).order_by(
            models.Problem.problem_type, models.Problem.status
        )
        
        problem_types_result = (await db.execute(problem_types_query)).all()
        
        # Analyze mapping
        PROBLEM_TYPE_TO_DEPARTMENT = {
            "pothole": "Roads",
            "road repair": "Roads", 
            "road_repair": "Roads",
            "roads": "Roads",
            "street light": "Electrical",
            "streetlight": "Electrical",
            "electrical": "Electrical",
            "electricity": "Electrical",
            "power": "Electrical",
            "water supply": "Water",
            "water": "Water",
            "sewage": "Sanitation",
            "drainage": "Sanitation",
            "cleaning": "Sanitation",
            "sanitation": "Sanitation",
            "garbage": "Sanitation",
            "waste": "Sanitation",
            "public transport": "Transport",
            "transport": "Transport",
            "traffic": "Transport",
            "parks": "Parks and Gardens",
            "garden": "Parks and Gardens",
            "health": "Health",
            "hospital": "Health",
            "public works": "Public Works",
        }
        
        analysis = {}
        for row in problem_types_result:
            problem_type = row.problem_type
            if problem_type not in analysis:
                analysis[problem_type] = {
                    "total_count": 0,
                    "status_breakdown": {},
                    "mapped_department": PROBLEM_TYPE_TO_DEPARTMENT.get(problem_type.lower(), "UNMAPPED"),
                    "exact_match": problem_type.lower() in PROBLEM_TYPE_TO_DEPARTMENT
                }
            
            analysis[problem_type]["total_count"] += row.count
            analysis[problem_type]["status_breakdown"][row.status.value] = row.count
        
        # Check which departments exist
        dept_query = select(models.Department.name)
        departments = (await db.execute(dept_query)).scalars().all()
        
        return {
            "problem_types_analysis": analysis,
            "available_departments": list(departments),
            "mapping_rules": dict(PROBLEM_TYPE_TO_DEPARTMENT),
            "message": "Problem types analysis completed"
        }
        
    except Exception as e:
        logger.error(f"Problem types analysis error: {str(e)}")
        return {
            "error": str(e),
            "message": "Failed to analyze problem types"
        }
@router.post("/debug/test-assignment/{problem_id}")
async def test_problem_assignment(
    problem_id: int,
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Debug endpoint to test auto-assignment for a specific problem.
    """
    try:
        # Get the problem
        problem_query = select(models.Problem).where(models.Problem.id == problem_id)
        problem = (await db.execute(problem_query)).scalar_one_or_none()
        
        if not problem:
            return {"error": f"Problem {problem_id} not found"}
        
        if problem.district != admin_user.district:
            return {"error": f"Problem is not in your district ({admin_user.district})"}
        
        # Test the mapping
        PROBLEM_TYPE_TO_DEPARTMENT = {
            "pothole": "Roads",
            "road repair": "Roads", 
            "road_repair": "Roads",
            "roads": "Roads",
            "street light": "Electrical",
            "streetlight": "Electrical",
            "electrical": "Electrical",
            "electricity": "Electrical",
            "power": "Electrical",
            "water supply": "Water",
            "water": "Water",
            "sewage": "Sanitation",
            "drainage": "Sanitation",
            "cleaning": "Sanitation",
            "sanitation": "Sanitation",
            "garbage": "Sanitation",
            "waste": "Sanitation",
            "public transport": "Transport",
            "transport": "Transport",
            "traffic": "Transport",
            "parks": "Parks and Gardens",
            "garden": "Parks and Gardens",
            "health": "Health",
            "hospital": "Health",
            "public works": "Public Works",
        }
        
        dept_name = PROBLEM_TYPE_TO_DEPARTMENT.get(problem.problem_type.lower(), problem.problem_type)
        
        # Find department
        dept_query = select(models.Department).where(models.Department.name == dept_name)
        department = (await db.execute(dept_query)).scalar_one_or_none()
        
        if not department:
            dept_query = select(models.Department).where(models.Department.name.ilike(f"%{dept_name}%"))
            department = (await db.execute(dept_query)).scalar_one_or_none()
        
        # Find workers in that department and district
        if department:
            workers_query = select(models.WorkerProfile).join(models.User).where(
                models.WorkerProfile.department_id == department.id,
                models.User.district == problem.district,
                models.User.is_active == True
            ).options(selectinload(models.WorkerProfile.user))
            
            workers = (await db.execute(workers_query)).scalars().all()
            
            # Check their current task counts
            worker_info = []
            for worker in workers:
                count_query = select(func.count(models.Problem.id)).where(
                    models.Problem.assigned_worker_id == worker.id,
                    models.Problem.status == models.ProblemStatusEnum.ASSIGNED
                )
                current_assigned = (await db.execute(count_query)).scalar_one()
                worker_info.append({
                    "worker_id": worker.id,
                    "name": worker.user.full_name,
                    "email": worker.user.email,
                    "current_assigned_tasks": current_assigned,
                    "max_tasks": settings.MAX_DAILY_TASKS_PER_WORKER,
                    "available": current_assigned < settings.MAX_DAILY_TASKS_PER_WORKER
                })
        else:
            worker_info = []
        
        return {
            "problem": {
                "id": problem.id,
                "title": problem.title,
                "problem_type": problem.problem_type,
                "district": problem.district,
                "status": problem.status.value,
                "priority": problem.priority
            },
            "mapping": {
                "problem_type": problem.problem_type,
                "mapped_to": dept_name,
                "department_found": department.name if department else None,
                "department_id": department.id if department else None
            },
            "workers": worker_info,
            "summary": {
                "can_assign": len([w for w in worker_info if w["available"]]) > 0,
                "available_workers": len([w for w in worker_info if w["available"]]),
                "total_workers": len(worker_info)
            }
        }
        
    except Exception as e:
        logger.error(f"Test assignment error: {str(e)}")
        return {
            "error": str(e),
            "message": "Failed to test assignment"
        }
@router.delete("/issues/{issue_id}")
async def delete_fake_issue(
    issue_id: int,
    reason: str,
    db: AsyncSession = Depends(database.get_db),
    admin_user: models.User = Depends(get_current_admin_user)
):
    """
    Delete a fake/inappropriate issue reported by users.
    Only PENDING and ASSIGNED issues can be deleted.
    Reduces user's civic points and sends notification with reason.
    """
    try:
        # Get the issue
        issue_query = select(models.Problem).options(
            selectinload(models.Problem.submitted_by)
        ).where(models.Problem.id == issue_id)
        issue = (await db.execute(issue_query)).scalar_one_or_none()
        
        if not issue:
            raise HTTPException(status_code=404, detail="Issue not found")
        
        # Check if issue is in admin's district
        if issue.district != admin_user.district:
            raise HTTPException(status_code=403, detail="You can only delete issues in your district")
        
        # Check if issue status allows deletion (only PENDING and ASSIGNED can be deleted)
        if issue.status not in [models.ProblemStatusEnum.PENDING, models.ProblemStatusEnum.ASSIGNED]:
            raise HTTPException(
                status_code=400, 
                detail=f"Cannot delete {issue.status.value} issues. Only pending or assigned issues can be deleted."
            )
        
        # Get the reporter user
        reporter_query = select(models.User).where(models.User.id == issue.user_id)
        reporter_user = (await db.execute(reporter_query)).scalar_one_or_none()
        
        if not reporter_user:
            raise HTTPException(status_code=404, detail="Reporter user not found")
        
        # Store data before deletion
        reporter_user_id = reporter_user.id
        reporter_fcm_token = reporter_user.fcm_token
        issue_title = issue.title
        issue_id_stored = issue.id
        current_points = reporter_user.civic_points
        
        # Reduce user's civic points (deduct 10 points for fake report)
        points_deduction = 10
        new_points = max(0, current_points - points_deduction)  # Don't go below 0
        reporter_user.civic_points = new_points
        
        # Also reduce issues_reported count
        reporter_user.issues_reported = max(0, reporter_user.issues_reported - 1)
        
        # Delete associated media files first (due to foreign key constraints)
        media_query = select(models.Media).where(models.Media.problem_id == issue_id)
        media_files = (await db.execute(media_query)).scalars().all()
        
        for media in media_files:
            await db.delete(media)
        
        # Delete associated feedback
        feedback_query = select(models.Feedback).where(models.Feedback.problem_id == issue_id)
        feedback_records = (await db.execute(feedback_query)).scalars().all()
        
        for feedback in feedback_records:
            await db.delete(feedback)
        
        # Delete the issue
        await db.delete(issue)
        
        await db.commit()
        
        logger.info(
            f"Admin {admin_user.id} deleted fake issue #{issue_id_stored} by user {reporter_user_id}. "
            f"User points reduced from {current_points} to {new_points}. Reason: {reason}"
        )
        
        # Send notification to user
        try:
            from ..services.push_notifications import send_push_to_token
            
            if reporter_fcm_token:
                await send_push_to_token(
                    fcm_token=reporter_fcm_token,
                    title="Issue Deleted by Admin ⚠️",
                    body=f"Your issue '{issue_title}' has been deleted. Reason: {reason}",
                    notification_type="issue_deleted",
                    data={
                        "issue_id": str(issue_id_stored),
                        "reason": reason,
                        "points_deducted": str(points_deduction),
                        "new_points": str(new_points),
                        "action": "view_profile"
                    }
                )
                logger.info(f"✅ Deletion notification sent to user {reporter_user_id}")
        except Exception as e:
            logger.warning(f"Failed to send deletion notification: {str(e)}")
        
        return {
            "message": "Issue deleted successfully",
            "issue_id": issue_id_stored,
            "reason": reason,
            "points_deducted": points_deduction,
            "user_new_points": new_points
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Delete issue error: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete issue: {str(e)}"
        )