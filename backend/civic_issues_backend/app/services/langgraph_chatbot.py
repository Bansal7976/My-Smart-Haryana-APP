# LangGraph-based Multi-Agent Chatbot System
import json
import uuid
from typing import Dict, Any, List, TypedDict, Annotated, Sequence
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from datetime import datetime
import logging
from langgraph.graph import StateGraph, END
from langchain_core.messages import HumanMessage, AIMessage

from .. import models
from ..config import settings
from .agents.rag_agent import RAGAgent
from .agents.web_search_agent_tavily import WebSearchAgent
from .agents.analytics_agent import AnalyticsAgent
from .agents.gemini_agent import GeminiAgent

logger = logging.getLogger(__name__)

class AgentState(TypedDict):
    """State shared between all agents"""
    query: str
    user_id: int
    user_district: str
    db_session: AsyncSession
    chat_history: List[Dict[str, str]]
    preferred_language: str
    rag_result: Dict[str, Any]
    db_result: Dict[str, Any]
    web_result: Dict[str, Any]
    final_response: str
    agent_used: str
    metadata: Dict[str, Any]

class LangGraphChatbot:
    """
    Multi-Agent Chatbot using LangGraph for orchestration.
    
    Agent Priority:
    1. Analytics Agent (Database queries for stats, user data)
    2. RAG Agent (Knowledge base search)
    3. Web Search Agent (External information)
    4. Gemini Agent (Fallback for general queries)
    """
    
    def __init__(self):
        # Initialize agents with error handling
        try:
            self.rag_agent = RAGAgent(
                google_api_key=settings.GOOGLE_API_KEY,
                pinecone_api_key=getattr(settings, 'PINECONE_API_KEY', '')
            )
        except Exception as e:
            logger.warning(f"RAG Agent initialization failed: {e}")
            self.rag_agent = None
            
        try:
            self.web_agent = WebSearchAgent(
                tavily_api_key=getattr(settings, 'TAVILY_API_KEY', '')
            )
        except Exception as e:
            logger.warning(f"Web Search Agent initialization failed: {e}")
            self.web_agent = None
            
        try:
            self.analytics_agent = AnalyticsAgent()
        except Exception as e:
            logger.warning(f"Analytics Agent initialization failed: {e}")
            self.analytics_agent = None
            
        try:
            self.gemini_agent = GeminiAgent(
                google_api_key=settings.GOOGLE_API_KEY,
                model="gemini-2.5-flash",  # More stable model
                temperature=0.7
            )
        except Exception as e:
            logger.error(f"Gemini Agent initialization failed: {e}")
            self.gemini_agent = None
            
        self.workflow = self._build_workflow()
    
    def _build_workflow(self) -> StateGraph:
        """Build the LangGraph workflow"""
        workflow = StateGraph(AgentState)
        
        # Add nodes
        workflow.add_node("rag_search", self._rag_node)
        workflow.add_node("database_query", self._database_node)
        workflow.add_node("web_search", self._web_search_node)
        workflow.add_node("generate_response", self._generate_node)
        
        # Set entry point
        workflow.set_entry_point("rag_search")
        
        # Add edges
        workflow.add_edge("rag_search", "database_query")
        workflow.add_edge("database_query", "web_search")
        
        # Conditional edge from web_search
        workflow.add_conditional_edges(
            "web_search",
            self._should_use_web,
            {
                "use_web": "generate_response", # Go to generate_response to enhance
                "use_gemini": "generate_response" # Fallback to pure Gemini
            }
        )
        
        workflow.add_edge("generate_response", END)
        
        return workflow.compile()
    
    async def _rag_node(self, state: AgentState) -> AgentState:
        """Check if RAG can answer the query"""
        if not self.rag_agent:
            state["rag_result"] = None
            return state
            
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
        try:
            can_handle = await self.rag_agent.can_handle(state["query"], context)
            
            if can_handle:
                result = await self.rag_agent.execute(
                    state["query"],
                    context,
                    state["db_session"],
                    state["user_id"]
                )
                # Check if docs were actually found
                if result and result.get("metadata", {}).get("docs_retrieved", 0) > 0:
                    state["rag_result"] = result
                else:
                    state["rag_result"] = None # RAG triggered but found no docs
            else:
                state["rag_result"] = None
        except Exception as e:
            logger.warning(f"RAG node error: {e}")
            state["rag_result"] = None
        
        return state
    
    async def _database_node(self, state: AgentState) -> AgentState:
        """Check if database analytics can answer"""
        if not self.analytics_agent:
            state["db_result"] = None
            return state
            
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
        try:
            can_handle = await self.analytics_agent.can_handle(state["query"], context)
            
            if can_handle:
                result = await self.analytics_agent.execute(
                    state["query"],
                    context,
                    state["db_session"],
                    state["user_id"]
                )
                state["db_result"] = result
            else:
                state["db_result"] = None
        except Exception as e:
            logger.warning(f"Database node error: {e}")
            state["db_result"] = None
        
        return state
    
    async def _web_search_node(self, state: AgentState) -> AgentState:
        """Perform web search if needed"""
        if not self.web_agent:
            state["web_result"] = None
            return state
            
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
        try:
            can_handle = await self.web_agent.can_handle(state["query"], context)
            
            if can_handle:
                result = await self.web_agent.execute(
                    state["query"],
                    context,
                    state["db_session"],
                    state["user_id"]
                )
                # Check if results were found
                if result and result.get("metadata", {}).get("results_count", 0) > 0:
                    state["web_result"] = result
                else:
                    state["web_result"] = None # Web search triggered but found no results
            else:
                state["web_result"] = None
        except Exception as e:
            logger.warning(f"Web search node error: {e}")
            state["web_result"] = None
        
        return state
    
    async def _generate_node(self, state: AgentState) -> AgentState:
        """
        Generate final response with corrective RAG approach.
        Priority: Analytics > RAG > Web Search > Gemini
        """
        
        query = state["query"]
        context_to_enhance = None
        agent_used = "gemini" 
        metadata = {}

        # Priority 1: Analytics (Database) - Always use if available
        if state.get("db_result") and state["db_result"].get("response"):
            logger.info("✅ Using Analytics result (highest priority)")
            context_to_enhance = state["db_result"]["response"]
            agent_used = "analytics"
            metadata = state["db_result"].get("metadata", {})
        
        # Priority 2: RAG - Use if analytics didn't provide answer
        elif state.get("rag_result") and state["rag_result"].get("response"):
            logger.info("✅ Using RAG result (second priority)")
            context_to_enhance = state["rag_result"]["response"]
            agent_used = "rag"
            metadata = state["rag_result"].get("metadata", {})
        
        # Priority 3: Web Search - Use if RAG didn't provide answer
        elif state.get("web_result") and state["web_result"].get("response"):
            logger.info("✅ Using Web Search result (third priority)")
            context_to_enhance = state["web_result"]["response"]
            agent_used = "web_search"
            metadata = state["web_result"].get("metadata", {})
        
        # Priority 4: Pure Gemini - Fallback
        else:
            logger.info("🤖 Using pure Gemini (fallback)")
            agent_used = "gemini"
        
        # Generate enhanced response using Gemini
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"],
            "retrieved_context": context_to_enhance,
            "preferred_language": state["preferred_language"]
        }
        
        if self.gemini_agent:
            try:
                gemini_result = await self.gemini_agent.execute(
                    query,
                    context,
                    state["db_session"],
                    state["user_id"]
                )
                
                state["final_response"] = gemini_result["response"]
                state["agent_used"] = agent_used
                state["metadata"] = {
                    **metadata,
                    **gemini_result.get("metadata", {}),
                    "primary_agent": agent_used
                }
            except Exception as e:
                logger.error(f"Gemini agent error: {e}")
                state["final_response"] = "I'm sorry, I'm having trouble processing your request right now. Please try again later."
                state["agent_used"] = "error"
                state["metadata"] = {"error": str(e)}
        else:
            state["final_response"] = "I'm sorry, the AI service is currently unavailable. Please try again later."
            state["agent_used"] = "unavailable"
            state["metadata"] = {"error": "Gemini agent not available"}
        
        return state
    
    def _should_use_web(self, state: AgentState) -> str:
        """Decide whether to use web search results or fallback to Gemini"""
        # Always proceed to generate_response - the logic is handled there
        return "use_web" if state.get("web_result") else "use_gemini"
    
    async def process_message(
        self,
        db: AsyncSession,
        user: models.User,
        message: str,
        session_id: str = None,
        preferred_language: str = "en"
    ) -> Dict[str, Any]:
        """
        Process user message through the multi-agent workflow.
        """
        if not session_id:
            session_id = str(uuid.uuid4())
        
        # Get chat history
        chat_history = await self._get_chat_history(db, user.id, session_id)
        
        # Initialize state
        initial_state: AgentState = {
            "query": message,
            "user_id": user.id,
            "user_district": user.district,
            "db_session": db,
            "chat_history": chat_history,
            "preferred_language": preferred_language,
            "rag_result": None,
            "db_result": None,
            "web_result": None,
            "final_response": "",
            "agent_used": "",
            "metadata": {}
        }
        
        try:
            # Run the workflow
            final_state = await self.workflow.ainvoke(initial_state)
            
            # Save conversation to database
            await self._save_conversation(
                db, user.id, session_id, message, 
                final_state["final_response"], final_state["agent_used"]
            )
            
            return {
                "response": final_state["final_response"],  # Changed from "message" to "response"
                "session_id": session_id,
                "agent_used": final_state["agent_used"],    # Changed from "agent_type" to "agent_used"
                "metadata": final_state["metadata"]
            }
            
        except Exception as e:
            logger.error(f"LangGraph workflow error: {str(e)}")
            
            # Fallback to simple Gemini response
            if self.gemini_agent:
                try:
                    fallback_result = await self.gemini_agent.execute(
                        message,
                        {"chat_history": chat_history, "user_district": user.district},
                        db,
                        user.id
                    )
                    
                    await self._save_conversation(
                        db, user.id, session_id, message,
                        fallback_result["response"], "gemini_fallback"
                    )
                    
                    return {
                        "response": fallback_result["response"],  # Changed from "message" to "response"
                        "session_id": session_id,
                        "agent_used": "gemini_fallback",          # Changed from "agent_type" to "agent_used"
                        "metadata": {"error": str(e)}
                    }
                except Exception as gemini_error:
                    logger.error(f"Gemini fallback also failed: {gemini_error}")
            
            # Final fallback - simple response
            simple_response = "I'm sorry, I'm experiencing technical difficulties. Please try again later or contact support."
            
            await self._save_conversation(
                db, user.id, session_id, message,
                simple_response, "error_fallback"
            )
            
            return {
                "response": simple_response,     # Changed from "message" to "response"
                "session_id": session_id,
                "agent_used": "error_fallback",  # Changed from "agent_type" to "agent_used"
                "metadata": {"error": str(e)}
            }
    
    async def _get_chat_history(
        self, 
        db: AsyncSession, 
        user_id: int, 
        session_id: str, 
        limit: int = 10
    ) -> List[Dict[str, str]]:
        """Get recent chat history for context"""
        query = select(models.ChatHistory).where(
            models.ChatHistory.user_id == user_id,
            models.ChatHistory.session_id == session_id
        ).order_by(desc(models.ChatHistory.created_at)).limit(limit * 2)  # Get more to account for pairs
        
        result = await db.execute(query)
        history = result.scalars().all()
        
        # Convert to format expected by agents
        formatted_history = []
        for chat in reversed(history):  # Reverse to get chronological order
            formatted_history.append({
                "role": chat.role,
                "message": chat.message,
                "timestamp": chat.created_at.isoformat()
            })
        
        return formatted_history[-limit:] if len(formatted_history) > limit else formatted_history
    
    async def _save_conversation(
        self,
        db: AsyncSession,
        user_id: int,
        session_id: str,
        user_message: str,
        bot_response: str,
        agent_type: str
    ):
        """Save conversation to database"""
        # Save user message
        user_chat = models.ChatHistory(
            user_id=user_id,
            session_id=session_id,
            role="user",
            message=user_message,
            agent_type="user"
        )
        db.add(user_chat)
        
        # Save bot response
        bot_chat = models.ChatHistory(
            user_id=user_id,
            session_id=session_id,
            role="assistant",
            message=bot_response,
            agent_type=agent_type
        )
        db.add(bot_chat)
        
        await db.commit()
    
    async def get_user_sessions(self, db: AsyncSession, user_id: int) -> List[Dict[str, Any]]:
        """Get user's chat sessions"""
        query = select(
            models.ChatHistory.session_id,
            func.max(models.ChatHistory.created_at).label('last_message'),
            func.count(models.ChatHistory.id).label('message_count')
        ).where(
            models.ChatHistory.user_id == user_id
        ).group_by(
            models.ChatHistory.session_id
        ).order_by(desc('last_message'))
        
        result = await db.execute(query)
        sessions = result.all()
        
        return [
            {
                "session_id": session.session_id,
                "last_message_time": session.last_message.isoformat(),
                "message_count": session.message_count,
                "title": f"Chat {session.session_id[:8]}..."
            }
            for session in sessions
        ]

# Create global chatbot instance
chatbot = LangGraphChatbot()