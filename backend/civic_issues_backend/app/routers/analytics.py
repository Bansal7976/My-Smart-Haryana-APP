"""
Analytics Router - Time-series queries, export functionality, and advanced analytics
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case, text, and_, or_
from sqlalchemy.orm import selectinload
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import pandas as pd
import io
import logging

from .. import database, models, utils

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["Analytics"])

# Helper function to get date range
def get_date_range(start_date: Optional[str] = None, end_date: Optional[str] = None):
    """Parse date strings and return datetime objects"""
    try:
        start = datetime.fromisoformat(start_date) if start_date else datetime.utcnow() - timedelta(days=30)
        end = datetime.fromisoformat(end_date) if end_date else datetime.utcnow()
        return start, end
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use ISO format (YYYY-MM-DDTHH:MM:SS)")

@router.get("/trends/daily", response_model=Dict[str, Any])
async def get_daily_trends(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get daily issue trends over time period.
    Returns: issues created, assigned, completed, verified per day
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Daily trends query
    daily_query = select(
        func.date(models.Problem.created_at).label('date'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label('created'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label('assigned'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label('completed'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label('verified')
    ).where(and_(*base_conditions)).group_by(func.date(models.Problem.created_at)).order_by(func.date(models.Problem.created_at))

    result = await db.execute(daily_query)
    daily_data = result.all()

    # Convert to list of dicts
    trends = []
    for row in daily_data:
        trends.append({
            "date": row.date.isoformat() if row.date else None,
            "created": row.created or 0,
            "assigned": row.assigned or 0,
            "completed": row.completed or 0,
            "verified": row.verified or 0
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "daily_trends": trends
    }

@router.get("/trends/weekly", response_model=Dict[str, Any])
async def get_weekly_trends(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get weekly issue trends over time period.
    Returns: issues created, assigned, completed, verified per week
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Weekly trends query
    weekly_query = select(
        func.date_trunc('week', models.Problem.created_at).label('week'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label('created'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label('assigned'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label('completed'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label('verified')
    ).where(and_(*base_conditions)).group_by(func.date_trunc('week', models.Problem.created_at)).order_by(func.date_trunc('week', models.Problem.created_at))

    result = await db.execute(weekly_query)
    weekly_data = result.all()

    # Convert to list of dicts
    trends = []
    for row in weekly_data:
        trends.append({
            "week_start": row.week.isoformat() if row.week else None,
            "created": row.created or 0,
            "assigned": row.assigned or 0,
            "completed": row.completed or 0,
            "verified": row.verified or 0
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "weekly_trends": trends
    }

@router.get("/trends/monthly", response_model=Dict[str, Any])
async def get_monthly_trends(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get monthly issue trends over time period.
    Returns: issues created, assigned, completed, verified per month
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Monthly trends query
    monthly_query = select(
        func.date_trunc('month', models.Problem.created_at).label('month'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.PENDING, 1))).label('created'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.ASSIGNED, 1))).label('assigned'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.COMPLETED, 1))).label('completed'),
        func.count(case((models.Problem.status == models.ProblemStatusEnum.VERIFIED, 1))).label('verified')
    ).where(and_(*base_conditions)).group_by(func.date_trunc('month', models.Problem.created_at)).order_by(func.date_trunc('month', models.Problem.created_at))

    result = await db.execute(monthly_query)
    monthly_data = result.all()

    # Convert to list of dicts
    trends = []
    for row in monthly_data:
        trends.append({
            "month_start": row.month.isoformat() if row.month else None,
            "created": row.created or 0,
            "assigned": row.assigned or 0,
            "completed": row.completed or 0,
            "verified": row.verified or 0
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "monthly_trends": trends
    }

@router.get("/department-performance", response_model=Dict[str, Any])
async def get_department_performance(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get department performance metrics over time period.
    Returns: issues by department, completion rates, average resolution time
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Department performance query
    dept_query = select(
        models.Department.name.label('department'),
        func.count(models.Problem.id).label('total_issues'),
        func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).label('completed_issues'),
        func.avg(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]),
                      func.extract('epoch', models.Problem.updated_at - models.Problem.created_at)))).label('avg_resolution_hours')
    ).select_from(models.Problem).join(
        models.WorkerProfile, models.Problem.assigned_worker_id == models.WorkerProfile.id
    ).join(
        models.Department, models.WorkerProfile.department_id == models.Department.id
    ).where(and_(*base_conditions)).group_by(models.Department.name).order_by(func.count(models.Problem.id).desc())

    result = await db.execute(dept_query)
    dept_data = result.all()

    # Convert to list of dicts
    departments = []
    for row in dept_data:
        completion_rate = (row.completed_issues / row.total_issues * 100) if row.total_issues > 0 else 0
        avg_hours = (row.avg_resolution_hours / 3600) if row.avg_resolution_hours else None  # Convert seconds to hours

        departments.append({
            "department": row.department,
            "total_issues": row.total_issues or 0,
            "completed_issues": row.completed_issues or 0,
            "completion_rate": round(completion_rate, 2),
            "avg_resolution_hours": round(avg_hours, 2) if avg_hours else None
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "departments": departments
    }

@router.get("/worker-performance", response_model=Dict[str, Any])
async def get_worker_performance(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get worker performance metrics over time period.
    Returns: tasks completed, average rating, completion rate per worker
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Worker performance query
    worker_query = select(
        models.User.full_name.label('worker_name'),
        models.Department.name.label('department'),
        func.count(models.Problem.id).label('total_assigned'),
        func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).label('completed_tasks'),
        func.avg(models.Feedback.rating).label('avg_rating')
    ).select_from(models.Problem).join(
        models.WorkerProfile, models.Problem.assigned_worker_id == models.WorkerProfile.id
    ).join(
        models.User, models.WorkerProfile.user_id == models.User.id
    ).join(
        models.Department, models.WorkerProfile.department_id == models.Department.id
    ).outerjoin(
        models.Feedback, models.Problem.id == models.Feedback.problem_id
    ).where(and_(*base_conditions)).group_by(
        models.User.full_name, models.Department.name
    ).order_by(func.count(case((models.Problem.status.in_([models.ProblemStatusEnum.COMPLETED, models.ProblemStatusEnum.VERIFIED]), 1))).desc())

    result = await db.execute(worker_query)
    worker_data = result.all()

    # Convert to list of dicts
    workers = []
    for row in worker_data:
        completion_rate = (row.completed_tasks / row.total_assigned * 100) if row.total_assigned > 0 else 0

        workers.append({
            "worker_name": row.worker_name,
            "department": row.department,
            "total_assigned": row.total_assigned or 0,
            "completed_tasks": row.completed_tasks or 0,
            "completion_rate": round(completion_rate, 2),
            "avg_rating": round(row.avg_rating, 2) if row.avg_rating else None
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "workers": workers
    }

@router.get("/issue-types-distribution", response_model=Dict[str, Any])
async def get_issue_types_distribution(
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get distribution of issues by problem type.
    Returns: count and percentage for each problem type
    """
    start, end = get_date_range(start_date, end_date)

    # Build base query
    base_conditions = [models.Problem.created_at.between(start, end)]
    if district:
        base_conditions.append(models.Problem.district == district)

    # Issue types distribution query
    types_query = select(
        models.Problem.problem_type,
        func.count(models.Problem.id).label('count')
    ).where(and_(*base_conditions)).group_by(models.Problem.problem_type).order_by(func.count(models.Problem.id).desc())

    result = await db.execute(types_query)
    types_data = result.all()

    # Calculate total for percentages
    total_issues = sum(row.count for row in types_data)

    # Convert to list of dicts
    issue_types = []
    for row in types_data:
        percentage = (row.count / total_issues * 100) if total_issues > 0 else 0
        issue_types.append({
            "problem_type": row.problem_type,
            "count": row.count or 0,
            "percentage": round(percentage, 2)
        })

    return {
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        },
        "total_issues": total_issues,
        "issue_types": issue_types
    }

@router.get("/heat-map-data", response_model=Dict[str, Any])
async def get_heat_map_data(
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get heat map data showing issue density by location.
    Returns: latitude, longitude, and issue count for clustering
    """
    # Build base query
    base_conditions = []
    if district:
        base_conditions.append(models.Problem.district == district)

    # Build district filter
    district_filter = ""
    if district and district.strip():
        district_filter = f"AND district = '{district}'"
    
    # Heat map query - group by location clusters
    # Using PostGIS to cluster nearby points
    heat_query = text(f"""
        SELECT
            ST_Y(ST_SnapToGrid(location, 0.001)::geometry) as latitude,
            ST_X(ST_SnapToGrid(location, 0.001)::geometry) as longitude,
            COUNT(*) as issue_count,
            AVG(priority) as avg_priority
        FROM problems
        WHERE status::text IN ('pending', 'assigned', 'completed', 'verified')
        {district_filter}
        AND location IS NOT NULL
        GROUP BY ST_SnapToGrid(location, 0.001)
        HAVING COUNT(*) >= 1
        ORDER BY COUNT(*) DESC
        LIMIT 100
    """)

    result = await db.execute(heat_query)
    heat_data = result.all()

    # Convert to list of dicts
    heat_points = []
    for row in heat_data:
        heat_points.append({
            "latitude": float(row.latitude),
            "longitude": float(row.longitude),
            "issue_count": row.issue_count or 0,
            "avg_priority": round(float(row.avg_priority), 2) if row.avg_priority else None
        })

    return {
        "district": district,
        "heat_points": heat_points,
        "total_clusters": len(heat_points)
    }

@router.get("/export/csv", response_model=Dict[str, Any])
async def export_analytics_csv(
    report_type: str = Query(..., description="Type of report: trends, departments, workers, issues"),
    start_date: Optional[str] = Query(None, description="Start date (ISO format)"),
    end_date: Optional[str] = Query(None, description="End date (ISO format)"),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Export analytics data to CSV format.
    Returns: CSV file content as string
    """
    start, end = get_date_range(start_date, end_date)

    # Get data based on report type
    if report_type == "trends":
        data = await get_daily_trends(start_date, end_date, district, db, current_user)
        df = pd.DataFrame(data["daily_trends"])
    elif report_type == "departments":
        data = await get_department_performance(start_date, end_date, district, db, current_user)
        df = pd.DataFrame(data["departments"])
    elif report_type == "workers":
        data = await get_worker_performance(start_date, end_date, district, db, current_user)
        df = pd.DataFrame(data["workers"])
    elif report_type == "issues":
        data = await get_issue_types_distribution(start_date, end_date, district, db, current_user)
        df = pd.DataFrame(data["issue_types"])
    else:
        raise HTTPException(status_code=400, detail="Invalid report type")

    # Convert to CSV
    csv_buffer = io.StringIO()
    df.to_csv(csv_buffer, index=False)
    csv_content = csv_buffer.getvalue()

    return {
        "filename": f"{report_type}_report_{start.strftime('%Y%m%d')}_{end.strftime('%Y%m%d')}.csv",
        "content": csv_content,
        "content_type": "text/csv",
        "period": {
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "district": district
        }
    }

@router.get("/predictions/issue-volume", response_model=Dict[str, Any])
async def predict_issue_volume(
    days_ahead: int = Query(7, description="Days to predict ahead", ge=1, le=30),
    district: Optional[str] = Query(None, description="Filter by district"),
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Simple prediction for issue volume based on historical trends.
    Uses moving average for basic forecasting.
    """
    # Get last 30 days of data
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=30)

    # Get daily trends
    trends_data = await get_daily_trends(start_date.isoformat(), end_date.isoformat(), district, db, current_user)
    daily_trends = trends_data["daily_trends"]

    if len(daily_trends) < 7:
        return {
            "prediction": "Insufficient data for prediction",
            "days_ahead": days_ahead,
            "confidence": 0,
            "predicted_volume": []
        }

    # Simple moving average prediction
    recent_avg = sum(day["created"] for day in daily_trends[-7:]) / 7

    # Generate predictions
    predictions = []
    for i in range(1, days_ahead + 1):
        predicted_date = end_date + timedelta(days=i)
        # Add some random variation (±20%)
        variation = (i % 3 - 1) * 0.2  # Simple pattern
        predicted_volume = max(0, int(recent_avg * (1 + variation)))

        predictions.append({
            "date": predicted_date.strftime("%Y-%m-%d"),
            "predicted_issues": predicted_volume,
            "confidence": 0.6  # Low confidence for simple model
        })

    return {
        "prediction_method": "Simple Moving Average (7-day)",
        "historical_average": round(recent_avg, 2),
        "days_ahead": days_ahead,
        "confidence": 0.6,
        "predicted_volume": predictions
    }
