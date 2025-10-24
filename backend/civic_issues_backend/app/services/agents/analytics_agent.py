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
        Check if query is about statistics, best city, trends, or user's own problems.
        """
        keywords = [
            "best", "सबसे अच्छा", "top", "most", "सबसे", "statistics", "आंकड़े",
            "how many", "कितने", "which city", "कौन सा शहर", "district", "जिला",
            "resolved", "solved", "हल", "completed", "पूर्ण", "ranking", "रैंकिंग",
            "comparison", "तुलना", "performance", "प्रदर्शन", "worst", "least",
            # User's own problems
            "my issues", "my problems", "मेरी समस्याएं", "मेरे मुद्दे", "reported",
            "my report", "मेरी रिपोर्ट", "last", "recent", "latest", "नवीनतम",
            "show my", "दिखाओ मेरे", "status", "स्थिति", "track", "ट्रैक"
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
        # Check for user's own problems first (higher priority)
        if any(word in query_lower for word in ["my issues", "my problems", "my report", "मेरी समस्याएं", "मेरे मुद्दे", "show my"]):
            return await self._get_user_problems(db, user_id, query_lower)
        elif any(word in query_lower for word in ["latest", "last problem", "recent problem", "नवीनतम", "status of"]) and any(word in query_lower for word in ["my", "मेरा"]):
            return await self._get_latest_problem_status(db, user_id)
        elif any(word in query_lower for word in ["best", "top", "सबसे अच्छा"]):
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
    
    async def _get_user_problems(self, db: AsyncSession, user_id: int, query: str) -> Dict[str, Any]:
        """
        Get user's recently reported problems.
        """
        # Determine how many to show (default 3)
        limit = 3
        if "4" in query or "four" in query or "चार" in query:
            limit = 4
        elif "5" in query or "five" in query or "पांच" in query:
            limit = 5
        elif "last" in query or "latest" in query:
            limit = 3
        
        # Query user's problems
        problems_query = select(models.Problem).where(
            models.Problem.submitted_by_id == user_id
        ).order_by(
            desc(models.Problem.created_at)
        ).limit(limit).options(
            selectinload(models.Problem.assigned_to)
        )
        
        result = await db.execute(problems_query)
        problems = result.scalars().all()
        
        if not problems:
            return {
                "response": "You haven't reported any issues yet. Use the app to report civic problems in your area!",
                "metadata": {"count": 0},
                "agent_type": "analytics"
            }
        
        # Format response
        response_text = f"📋 Your Last {len(problems)} Reported Issue{'s' if len(problems) > 1 else ''}:\n\n"
        
        status_icons = {
            "PENDING": "⏳",
            "ASSIGNED": "👷",
            "COMPLETED": "✅",
            "VERIFIED": "✓"
        }
        
        for idx, problem in enumerate(problems, 1):
            status_icon = status_icons.get(problem.status.value, "📌")
            status_text = problem.status.value.replace("_", " ").title()
            
            # Format date
            created_date = problem.created_at.strftime("%d %b %Y")
            
            response_text += f"{idx}. {status_icon} Problem ID: #{problem.id}\n"
            response_text += f"   Type: {problem.problem_type}\n"
            response_text += f"   Status: {status_text}\n"
            response_text += f"   Location: {problem.area}, {problem.district}\n"
            response_text += f"   Reported: {created_date}\n"
            
            if problem.description and len(problem.description) > 0:
                desc_preview = problem.description[:60] + "..." if len(problem.description) > 60 else problem.description
                response_text += f"   Description: {desc_preview}\n"
            
            response_text += "\n"
        
        response_text += "💡 Tip: You can track these issues in the 'My Issues' section of the app!"
        
        return {
            "response": response_text,
            "metadata": {
                "count": len(problems),
                "problems": [
                    {
                        "id": p.id,
                        "type": p.problem_type,
                        "status": p.status.value,
                        "district": p.district,
                        "created_at": p.created_at.isoformat()
                    } for p in problems
                ]
            },
            "agent_type": "analytics"
        }
    
    async def _get_latest_problem_status(self, db: AsyncSession, user_id: int) -> Dict[str, Any]:
        """
        Get status of user's latest reported problem.
        """
        # Query latest problem
        problem_query = select(models.Problem).where(
            models.Problem.submitted_by_id == user_id
        ).order_by(
            desc(models.Problem.created_at)
        ).limit(1).options(
            selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.user),
            selectinload(models.Problem.assigned_to).selectinload(models.WorkerProfile.department),
            selectinload(models.Problem.feedback)
        )
        
        result = await db.execute(problem_query)
        problem = result.scalar_one_or_none()
        
        if not problem:
            return {
                "response": "You haven't reported any issues yet. Use the app to report civic problems in your area!",
                "metadata": {},
                "agent_type": "analytics"
            }
        
        # Format detailed status
        status_icons = {
            "PENDING": "⏳",
            "ASSIGNED": "👷",
            "COMPLETED": "✅",
            "VERIFIED": "✓"
        }
        
        status_icon = status_icons.get(problem.status.value, "📌")
        status_text = problem.status.value.replace("_", " ").title()
        
        created_date = problem.created_at.strftime("%d %b %Y at %I:%M %p")
        updated_date = problem.updated_at.strftime("%d %b %Y at %I:%M %p")
        
        response_text = f"🔍 Status of Your Latest Report:\n\n"
        response_text += f"📌 Problem ID: #{problem.id}\n"
        response_text += f"📍 Location: {problem.area}, {problem.district}\n"
        response_text += f"🏷️ Type: {problem.problem_type}\n"
        response_text += f"{status_icon} Status: {status_text}\n"
        response_text += f"📅 Reported: {created_date}\n"
        response_text += f"🔄 Last Updated: {updated_date}\n"
        
        if problem.description:
            response_text += f"\n📝 Description:\n{problem.description}\n"
        
        # Add worker info if assigned
        if problem.assigned_to and problem.assigned_to.user:
            worker_name = problem.assigned_to.user.full_name
            dept_name = problem.assigned_to.department.name if problem.assigned_to.department else "Unknown"
            response_text += f"\n👷 Assigned to: {worker_name} ({dept_name})\n"
        
        # Add feedback if verified
        if problem.status.value == "VERIFIED" and problem.feedback:
            feedback = problem.feedback[0]
            response_text += f"\n⭐ Your Rating: {feedback.rating}/5\n"
            if feedback.comment:
                response_text += f"💬 Your Feedback: {feedback.comment}\n"
        
        # Add action guidance
        if problem.status.value == "PENDING":
            response_text += "\n💡 Your issue is waiting to be assigned to a worker. We'll notify you once it's picked up!"
        elif problem.status.value == "ASSIGNED":
            response_text += "\n💡 A worker is currently working on your issue. You'll be notified when it's completed!"
        elif problem.status.value == "COMPLETED":
            response_text += "\n💡 The work is done! Please verify and provide feedback in the app."
        elif problem.status.value == "VERIFIED":
            response_text += "\n✨ Thank you for your feedback! Your issue has been successfully resolved."
        
        return {
            "response": response_text,
            "metadata": {
                "problem_id": problem.id,
                "status": problem.status.value,
                "type": problem.problem_type,
                "created_at": problem.created_at.isoformat(),
                "updated_at": problem.updated_at.isoformat()
            },
            "agent_type": "analytics"
        }