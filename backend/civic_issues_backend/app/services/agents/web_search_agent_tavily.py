# Web Search Agent - Using Tavily for Haryana Government Schemes
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
from tavily import TavilyClient

class WebSearchAgent(BaseAgent):
    """
    Agent responsible for searching the web for Haryana government schemes and policies.
    Uses Tavily API for optimized search results.
    """
    
    def __init__(self, tavily_api_key: str):
        super().__init__(
            name="Web Search Agent",
            description="Searches for Haryana government schemes, policies, and latest updates using Tavily"
        )
        self.tavily_api_key = tavily_api_key
        self.client = None
        
        if tavily_api_key:
            try:
                self.client = TavilyClient(api_key=tavily_api_key)
            except Exception as e:
                print(f"Tavily initialization error: {e}")
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """
        Check if query is about government schemes, policies, benefits, etc.
        """
        keywords = [
            "scheme", "yojana", "योजना", "policy", "नीति", "government", "सरकार",
            "benefit", "लाभ", "apply", "आवेदन", "eligibility", "पात्रता",
            "subsidy", "सब्सिडी", "pension", "पेंशन", "registration", "पंजीकरण",
            "haryana govt", "हरियाणा सरकार", "cm", "मुख्यमंत्री", "chief minister",
            "ministry", "मंत्रालय", "department scheme", "welfare", "कल्याण"
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
        Perform web search using Tavily and return formatted results.
        """
        
        if not self.client:
            return {
                "response": "Web search is currently unavailable. Please contact the administrator.",
                "metadata": {"error": "TAVILY_API_KEY not configured"},
                "agent_type": "web_search"
            }
        
        try:
            # Enhance query with Haryana context
            search_query = f"Haryana government {query}"
            
            # Search using Tavily
            response = self.client.search(
                query=search_query,
                search_depth="advanced",
                max_results=3,
                include_domains=["haryana.gov.in", "india.gov.in"],  # Prioritize official sites
            )
            
            results = response.get("results", [])
            
            if not results:
                return {
                    "response": "I couldn't find specific information about that scheme. Could you please be more specific or try rephrasing your question?",
                    "metadata": {"query": search_query, "results_count": 0},
                    "agent_type": "web_search"
                }
            
            # Format response
            response_text = f"🔍 **Search Results for: '{query}'**\n\n"
            response_text += "Here's what I found from official sources:\n\n"
            
            for idx, result in enumerate(results, 1):
                title = result.get("title", "No title")
                content = result.get("content", "")
                url = result.get("url", "")
                
                # Truncate content if too long
                if len(content) > 300:
                    content = content[:300] + "..."
                
                response_text += f"**{idx}. {title}**\n"
                response_text += f"{content}\n"
                response_text += f"🔗 Source: {url}\n\n"
            
            response_text += "📌 **Note**: Please visit the official links above for complete and up-to-date information.\n"
            response_text += "For application procedures, visit the official Haryana government portal."
            
            return {
                "response": response_text,
                "metadata": {
                    "query": search_query,
                    "results_count": len(results),
                    "sources": [r.get("url") for r in results]
                },
                "agent_type": "web_search"
            }
            
        except Exception as e:
            print(f"Web search error: {str(e)}")  # Log for debugging
            return {
                "response": "I encountered an error while searching. Please try again or rephrase your question.",
                "metadata": {"error": "search_failed"},
                "agent_type": "web_search"
            }

