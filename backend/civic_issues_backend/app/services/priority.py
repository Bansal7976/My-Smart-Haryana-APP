from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from .. import models
from ..config import settings 

URGENCY_SCORES = {
    "electrical": 9,
    "sewage": 8,
    "pothole": 6,
    "street light": 8,
    "water supply": 7,
    "road repair": 6,
    "drainage": 7,
    "cleaning": 4,
    "public transport": 5,
    "other": 5,
    "default": 5, 
}

async def calculate_priority_score(db: AsyncSession, problem: models.Problem, longitude: float, latitude: float) -> float:
    """
    Calculates a weighted priority score for a problem based on the density of
    nearby issues and the urgency of the problem type.
    """

    query = text("""
        SELECT COUNT(id) FROM problems
        WHERE status = 'PENDING' AND ST_DWithin(
            location,
            ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
            500
        );
    """)
    
    # Use provided coordinates directly instead of parsing WKT
    lon, lat = longitude, latitude

    result = await db.execute(query, {'lon': lon, 'lat': lat})
    nearby_problem_count = result.scalar_one_or_none() or 0
    

    density_score = min(nearby_problem_count / 10.0, 1.0) * 10
    urgency_score = URGENCY_SCORES.get(problem.problem_type.lower(), URGENCY_SCORES["default"])

    total_priority = (density_score * settings.PRIORITY_DENSITY_WEIGHT) + (urgency_score * settings.PRIORITY_URGENCY_WEIGHT)
    
    return round(total_priority, 2)