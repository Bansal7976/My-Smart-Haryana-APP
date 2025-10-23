from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from .. import models
from ..config import settings
import logging

logger = logging.getLogger(__name__)

# Urgency scores by problem type (0-10 scale)
# Higher score = more urgent
URGENCY_SCORES = {
    "electrical": 9,        # High risk - power outages, safety hazards
    "sewage": 8,           # Health hazard
    "street light": 8,     # Public safety
    "water supply": 7,     # Essential service
    "drainage": 7,         # Health and safety
    "pothole": 6,          # Infrastructure damage, vehicle safety
    "road repair": 6,      # Infrastructure
    "public transport": 5, # Convenience
    "cleaning": 4,         # Aesthetics
    "other": 5,            # Default for unknown types
    "default": 5,
}

async def calculate_priority_score(
    db: AsyncSession, 
    problem: models.Problem, 
    longitude: float, 
    latitude: float
) -> float:
    """
    Production-ready priority calculation using geospatial analysis.
    
    Formula: Priority = (Density × 0.6) + (Urgency × 0.4)
    
    Args:
        db: Database session
        problem: Problem instance
        longitude: Problem location longitude
        latitude: Problem location latitude
    
    Returns:
        float: Priority score (0-10 scale)
    
    Components:
    1. Density Score (0-10):
       - Counts pending problems within 500m radius
       - Uses PostGIS ST_DWithin for spatial query
       - Formula: min(nearby_count / 10.0, 1.0) × 10
       
    2. Urgency Score (0-10):
       - Based on problem type
       - Electrical/Sewage: highest priority
       - Cleaning: lowest priority
       
    Weights:
    - Density: 60% (cluster detection)
    - Urgency: 40% (problem type importance)
    """
    try:
        # Spatial query to find nearby pending problems within 500m
        query = text("""
            SELECT COUNT(id) FROM problems
            WHERE status = 'pending' 
            AND ST_DWithin(
                location,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                500
            );
        """)
        
        result = await db.execute(query, {'lon': longitude, 'lat': latitude})
        nearby_problem_count = result.scalar_one_or_none() or 0
        
        # Calculate density score (0-10 scale, capped at 10 nearby problems)
        density_score = min(nearby_problem_count / 10.0, 1.0) * 10
        
        # Get urgency score based on problem type
        problem_type_lower = problem.problem_type.lower()
        urgency_score = URGENCY_SCORES.get(problem_type_lower, URGENCY_SCORES["default"])
        
        # Calculate weighted priority
        total_priority = (
            (density_score * settings.PRIORITY_DENSITY_WEIGHT) + 
            (urgency_score * settings.PRIORITY_URGENCY_WEIGHT)
        )
        
        priority = round(total_priority, 2)
        
        logger.debug(
            f"Priority calculated for problem #{problem.id}: {priority} "
            f"(density={density_score:.1f}, urgency={urgency_score}, nearby={nearby_problem_count})"
        )
        
        return priority
        
    except Exception as e:
        logger.error(f"Priority calculation error: {str(e)}")
        # Fallback to urgency-only if spatial query fails
        urgency_score = URGENCY_SCORES.get(problem.problem_type.lower(), URGENCY_SCORES["default"])
        return round(urgency_score * settings.PRIORITY_URGENCY_WEIGHT, 2)