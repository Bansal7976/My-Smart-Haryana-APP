# Analytics Agent - Database queries for statistics
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, desc
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta
from .base_agent import BaseAgent
from ... import models

class AnalyticsAgent(BaseAgent):
    """
    Agent responsible for querying database for analytics and statistics.
    Provides insights about cities, problem resolution, trends, etc.
    """
    
    def __init__(self):
        super().__init__(
            name="Analytics Agent",
            description="Provides statistics and insights from the database"
        )
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """
        Check if query is about statistics, best city, trends, etc.
        """
        keywords = [
            "best", "सबसे अच्छा", "top", "most", "सबसे", "statistics", "आंकड़े",
            "how many", "कितने", "which city", "कौन सा शहर", "district", "जिला",
            "resolved", "solved", "हल", "completed", "पूर्ण", "ranking", "रैंकिंग",
            "comparison", "तुलना", "performance", "प्रदर्शन", "worst", "least"
        ]
        query_lower = query.lower()
        return any(keyword in query_lower for keyword in keywords)
    
    async def execute(
        self, 
        query: str, 
        context: Dict[str, Any],
        db: AsyncSession,
        user_id: int
    ) -> Dict[str, Any]:
        """
        Execute database analytics query based on user request.
        """
        
        query_lower = query.lower()
        
        # Determine what kind of analytics to provide
        if any(word in query_lower for word in ["best", "top", "सबसे अच्छा"]):
            return await self._get_best_performing_cities(db, query_lower)
        elif any(word in query_lower for word in ["worst", "least", "सबसे खराब"]):
            return await self._get_worst_performing_cities(db, query_lower)
        elif any(word in query_lower for word in ["my city", "my district", "मेरा शहर", "मेरा जिला"]):
            return await self._get_user_city_stats(db, user_id)
        elif any(word in query_lower for word in ["overall", "total", "haryana", "कुल"]):
            return await self._get_overall_stats(db)
        elif any(word in query_lower for word in ["department", "विभाग"]):
            return await self._get_department_stats(db)
        else:
            # Default: best performing cities
            return await self._get_best_performing_cities(db, query_lower)
    
    async def _get_best_performing_cities(self, db: AsyncSession, query: str) -> Dict[str, Any]:
        """
        Get cities with most resolved issues in the last 3 months.
        """
        three_months_ago = datetime.utcnow() - timedelta(days=90)
        
        # Query for resolved issues by district
        query_obj = select(
            models.Problem.district,
            func.count(models.Problem.id).label("resolved_count")
        ).where(
            and_(
                models.Problem.status.in_([
                    models.ProblemStatusEnum.COMPLETED, 
                    models.ProblemStatusEnum.VERIFIED
                ]),
                models.Problem.updated_at >= three_months_ago
            )
        ).group_by(
            models.Problem.district
        ).order_by(
            desc("resolved_count")
        ).limit(5)
        
        result = await db.execute(query_obj)
        top_cities = result.all()
        
        if not top_cities:
            return {
                "response": "There's no data available for the last 3 months. Please check back later!",
                "metadata": {"period": "3 months"},
                "agent_type": "analytics"
            }
        
        # Format response
        response_text = "🏆 **Top Performing Cities in Haryana (Last 3 Months)**\n\n"
        response_text += "Based on the number of resolved civic issues:\n\n"
        
        for idx, (district, count) in enumerate(top_cities, 1):
            medal = "🥇" if idx == 1 else "🥈" if idx == 2 else "🥉" if idx == 3 else "⭐"
            response_text += f"{medal} **{district}**: {count} issues resolved\n"
        
        response_text += f"\n**Winner**: {top_cities[0][0]} with {top_cities[0][1]} issues resolved! 🎉"
        
        return {
            "response": response_text,
            "metadata": {
                "period": "3 months",
                "top_city": top_cities[0][0],
                "top_count": top_cities[0][1],
                "cities": [{"district": d, "count": c} for d, c in top_cities]
            },
            "agent_type": "analytics"
        }
    
    async def _get_worst_performing_cities(self, db: AsyncSession, query: str) -> Dict[str, Any]:
        """
        Get cities with most pending issues.
        """
        query_obj = select(
            models.Problem.district,
            func.count(models.Problem.id).label("pending_count")
        ).where(
            models.Problem.status == models.ProblemStatusEnum.PENDING
        ).group_by(
            models.Problem.district
        ).order_by(
            desc("pending_count")
        ).limit(5)
        
        result = await db.execute(query_obj)
        cities_with_pending = result.all()
        
        if not cities_with_pending:
            return {
                "response": "Great news! There are no pending issues in any city right now! 🎉",
                "metadata": {},
                "agent_type": "analytics"
            }
        
        response_text = "📊 **Cities with Most Pending Issues**\n\n"
        
        for idx, (district, count) in enumerate(cities_with_pending, 1):
            response_text += f"{idx}. **{district}**: {count} pending issues\n"
        
        response_text += "\nThese cities need more attention from the administration."
        
        return {
            "response": response_text,
            "metadata": {
                "cities": [{"district": d, "count": c} for d, c in cities_with_pending]
            },
            "agent_type": "analytics"
        }
    
    async def _get_user_city_stats(self, db: AsyncSession, user_id: int) -> Dict[str, Any]:
        """
        Get statistics for the user's city.
        """
        # Get user's district
        user_query = select(models.User).where(models.User.id == user_id)
        user = (await db.execute(user_query)).scalar_one_or_none()
        
        if not user or not user.district:
            return {
                "response": "I couldn't find your city information. Please update your profile.",
                "metadata": {},
                "agent_type": "analytics"
            }
        
        district = user.district
        
        # Get stats for this district
        stats_query = select(
            func.count(models.Problem.id).label("total"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.PENDING, False)).label("pending"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.ASSIGNED, False)).label("assigned"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.COMPLETED, False)).label("completed"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.VERIFIED, False)).label("verified")
        ).where(models.Problem.district == district)
        
        result = (await db.execute(stats_query)).first()
        
        response_text = f"📊 **Statistics for {district}**\n\n"
        response_text += f"📋 Total Issues: {result.total}\n"
        response_text += f"⏳ Pending: {result.pending}\n"
        response_text += f"👷 Assigned: {result.assigned}\n"
        response_text += f"✅ Completed: {result.completed}\n"
        response_text += f"✓ Verified: {result.verified}\n\n"
        
        if result.total > 0:
            resolution_rate = ((result.completed + result.verified) / result.total) * 100
            response_text += f"🎯 Resolution Rate: {resolution_rate:.1f}%"
        
        return {
            "response": response_text,
            "metadata": {
                "district": district,
                "stats": {
                    "total": result.total,
                    "pending": result.pending,
                    "assigned": result.assigned,
                    "completed": result.completed,
                    "verified": result.verified
                }
            },
            "agent_type": "analytics"
        }
    
    async def _get_overall_stats(self, db: AsyncSession) -> Dict[str, Any]:
        """
        Get overall Haryana statistics.
        """
        stats_query = select(
            func.count(models.Problem.id).label("total"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.PENDING, False)).label("pending"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.COMPLETED, False)).label("completed"),
            func.count(func.nullif(models.Problem.status == models.ProblemStatusEnum.VERIFIED, False)).label("verified")
        )
        
        result = (await db.execute(stats_query)).first()
        
        # Get total districts with issues
        districts_query = select(func.count(func.distinct(models.Problem.district)))
        districts_count = (await db.execute(districts_query)).scalar()
        
        response_text = "🏛️ **Smart Haryana - Overall Statistics**\n\n"
        response_text += f"📊 Total Issues Reported: {result.total}\n"
        response_text += f"📍 Districts Covered: {districts_count}\n"
        response_text += f"⏳ Pending: {result.pending}\n"
        response_text += f"✅ Completed: {result.completed}\n"
        response_text += f"✓ Verified: {result.verified}\n\n"
        
        if result.total > 0:
            resolution_rate = ((result.completed + result.verified) / result.total) * 100
            response_text += f"🎯 Overall Resolution Rate: {resolution_rate:.1f}%\n"
            response_text += f"\nTogether, we're making Haryana better! 🌟"
        
        return {
            "response": response_text,
            "metadata": {
                "stats": {
                    "total": result.total,
                    "districts": districts_count,
                    "pending": result.pending,
                    "completed": result.completed,
                    "verified": result.verified
                }
            },
            "agent_type": "analytics"
        }
    
    async def _get_department_stats(self, db: AsyncSession) -> Dict[str, Any]:
        """
        Get statistics by department.
        """
        dept_query = select(
            models.Department.name,
            func.count(models.Problem.id).label("assigned_count")
        ).select_from(
            models.Department
        ).join(
            models.WorkerProfile
        ).join(
            models.Problem,
            models.WorkerProfile.id == models.Problem.assigned_worker_id
        ).group_by(
            models.Department.name
        ).order_by(
            desc("assigned_count")
        )
        
        result = await db.execute(dept_query)
        departments = result.all()
        
        if not departments:
            return {
                "response": "No department data available yet.",
                "metadata": {},
                "agent_type": "analytics"
            }
        
        response_text = "🏢 **Department-wise Statistics**\n\n"
        
        for idx, (dept_name, count) in enumerate(departments, 1):
            response_text += f"{idx}. **{dept_name}**: {count} tasks assigned\n"
        
        return {
            "response": response_text,
            "metadata": {
                "departments": [{"name": d, "count": c} for d, c in departments]
            },
            "agent_type": "analytics"
        }