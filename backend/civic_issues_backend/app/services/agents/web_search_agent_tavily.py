# Web Search Agent - Using Tavily for Haryana Government Schemes
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
# ✅ CORRECTION: Import AsyncTavilyClient
from tavily import AsyncTavilyClient
import logging

logger = logging.getLogger(__name__)

class WebSearchAgent(BaseAgent):
    """
    Agent responsible for searching the web for Haryana government schemes and policies.
    Uses Tavily API for optimized search results. (Asynchronous)
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
                # ✅ CORRECTION: Use AsyncTavilyClient
                self.client = AsyncTavilyClient(api_key=tavily_api_key)
                logger.info("✅ Tavily Async client initialized.")
            except Exception as e:
                logger.error(f"❌ Tavily initialization error: {e}")
        else:
            logger.warning("WebSearchAgent: TAVILY_API_KEY not set. Web search will be unavailable.")
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """
        Web search ONLY for: government schemes, news, events, policies, specific Haryana info.
        Skip: greetings, language requests, general questions, conversational queries.
        """
        query_lower = query.lower().strip()
        
        # Skip greetings and very short queries
        skip_keywords = ["hello", "hi", "hey", "namaste", "thanks", "thank you", "dhanyavaad", "bye", "ok", "okay"]
        if query_lower in skip_keywords or len(query_lower) < 3:
            return False
        
        # Skip language-related queries (Hindi, English, translate, convert)
        language_keywords = ["hindi", "हिंदी", "हिन्दी", "english", "translate", "convert", "language", "bhasha", "भाषा"]
        if any(keyword in query_lower for keyword in language_keywords):
            return False
        
        # Only trigger for specific government/scheme/policy queries
        web_search_keywords = [
            "scheme", "योजना", "policy", "नीति", "government", "सरकार", 
            "latest", "news", "update", "notification", "apply", "eligibility",
            "cm manohar lal", "haryana budget", "official", "portal", "website"
        ]
        
        # Return True only if query contains web-search-worthy keywords
        return any(keyword in query_lower for keyword in web_search_keywords)
    
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
            # Smart query formation - add Haryana context if not present
            if "haryana" not in query.lower():
                search_query = f"Haryana {query}"
            else:
                search_query = query
            
            logger.info(f"Tavily searching: {search_query}")
            
            # ✅ Use await with the async client
            response = await self.client.search(
                query=search_query,
                search_depth="basic",  # Changed to basic for faster results
                max_results=3,
            )
            
            results = response.get("results", [])
            
            if not results:
                return {
                    "response": "I couldn't find specific information about that scheme. Could you please be more specific or try rephrasing your question?",
                    "metadata": {"query": search_query, "results_count": 0},
                    "agent_type": "web_search"
                }
            
            # Format response text (will be enhanced by Gemini)
            response_text = f"Web search results for '{query}':\n\n"
            
            for idx, result in enumerate(results, 1):
                title = result.get("title", "No title")
                content = result.get("content", "")
                url = result.get("url", "")
                
                # Truncate content if too long
                if len(content) > 250:
                    content = content[:250] + "..."
                
                response_text += f"{idx}. {title}\n"
                response_text += f"{content}\n"
                response_text += f"Source: {url}\n\n"
            
            response_text += "Note: Please verify at official sources."
            
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
            logger.error(f"❌ Web search error: {str(e)}", exc_info=True)
            return {
                "response": "I encountered an error while searching. Please try again or rephrase your question.",
                "metadata": {"error": "search_failed"},
                "agent_type": "web_search"
            }