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
# ✅ CORRECTION: Fixed import path
from .agents.web_search_agent import WebSearchAgent
from .agents.analytics_agent import AnalyticsAgent
from .agents.gemini_agent import GeminiAgent

logger = logging.getLogger(__name__)

class AgentState(TypedDict):
    """State for the multi-agent graph"""
    query: str
    chat_history: List[Dict[str, Any]]
    user_id: int
    user_district: str
    db_session: Any
    
    # Agent results
    rag_result: Dict[str, Any]
    db_result: Dict[str, Any]
    web_result: Dict[str, Any]
    
    # Final response
    final_response: str
    agent_used: str
    metadata: Dict[str, Any]


class LangGraphChatbot:
    """
    LangGraph-based chatbot with intelligent routing:
    Query → Check RAG → Check Database → Web Search → Gemini Generation
    """
    
    def __init__(self):
        # Initialize agents
        self.rag_agent = RAGAgent(
            google_api_key=settings.GOOGLE_API_KEY,
            vector_store_path=settings.VECTOR_STORE_PATH
        )
        self.web_agent = WebSearchAgent(tavily_api_key=settings.TAVILY_API_KEY)
        self.analytics_agent = AnalyticsAgent()
        self.gemini_agent = GeminiAgent(
            google_api_key=settings.GOOGLE_API_KEY,
            model=settings.CHATBOT_MODEL,
            temperature=settings.CHATBOT_TEMPERATURE
        )
        
        # Build the graph
        self.graph = self._build_graph()
        logger.info("✅ LangGraph Chatbot initialized.")
    
    def _build_graph(self) -> StateGraph:
        """Build the LangGraph workflow"""
        
        # Define the graph
        workflow = StateGraph(AgentState)
        
        # Add nodes
        workflow.add_node("rag_check", self._rag_node)
        workflow.add_node("database_check", self._database_node)
        workflow.add_node("web_search", self._web_search_node)
        workflow.add_node("generate_response", self._generate_node)
        
        # Set entry point
        workflow.set_entry_point("rag_check")
        
        # Add edges with conditional routing
        workflow.add_conditional_edges(
            "rag_check",
            self._should_use_rag,
            {
                "use_rag": "generate_response", # Go to generate_response to enhance
                "try_database": "database_check"
            }
        )
        
        workflow.add_conditional_edges(
            "database_check",
            self._should_use_database,
            {
                "use_database": "generate_response", # Go to generate_response to enhance
                "try_web": "web_search"
            }
        )
        
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
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
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
        
        return state
    
    async def _database_node(self, state: AgentState) -> AgentState:
        """Check if database analytics can answer"""
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
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
        
        return state
    
    async def _web_search_node(self, state: AgentState) -> AgentState:
        """Perform web search if needed"""
        context = {
            "chat_history": state["chat_history"],
            "user_district": state["user_district"]
        }
        
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
        
        return state
    
    async def _generate_node(self, state: AgentState) -> AgentState:
        """
        Generate final response.
        ✅ IMPROVEMENT: Enhance RAG, DB, and Web results with Gemini for
        a consistent, high-quality conversational response.
        """
        
        query = state["query"]
        context_to_enhance = None
        agent_used = "gemini" # Default
        metadata = {}

        if state.get("rag_result"):
            logger.info("Using RAG result for enhancement.")
            context_to_enhance = state["rag_result"]["response"]
            agent_used = "rag"
            metadata = state["rag_result"].get("metadata", {})
            
        elif state.get("db_result"):
            logger.info("Using Analytics result for enhancement.")
            context_to_enhance = state["db_result"]["response"]
            agent_used = "analytics"
            metadata = state["db_result"].get("metadata", {})
            
        elif state.get("web_result"):
            logger.info("Using Web Search result for enhancement.")
            context_to_enhance = state["web_result"]["response"]
            agent_used = "web_search"
            metadata = state["web_result"].get("metadata", {})
            
        if context_to_enhance:
            # Enhance RAG, DB, or Web result with Gemini
            # ✅ CORRECTION: Added 'await' for the async call
            final_response = await self.gemini_agent.generate_with_context(
                query,
                context_to_enhance
            )
        else:
            # Fallback to Gemini for general conversation
            logger.info("No specific agent context. Using pure Gemini.")
            context = {
                "chat_history": state["chat_history"],
                "user_district": state["user_district"]
            }
            
            gemini_result = await self.gemini_agent.execute(
                query,
                context,
                state["db_session"],
                state["user_id"]
            )
            
            final_response = gemini_result["response"]
            agent_used = "gemini"
            metadata = gemini_result.get("metadata", {})
        
        state["final_response"] = final_response
        state["agent_used"] = agent_used
        state["metadata"] = metadata
        
        return state
    
    def _should_use_rag(self, state: AgentState) -> str:
        """Decide if RAG result is good enough"""
        if state.get("rag_result") and state["rag_result"].get("response"):
            return "use_rag"
        return "try_database"
    
    def _should_use_database(self, state: AgentState) -> str:
        """Deca-ide if database result is good enough"""
        if state.get("db_result") and state["db_result"].get("response"):
            return "use_database"
        return "try_web"
    
    def _should_use_web(self, state: AgentState) -> str:
        """Decide if web search found results"""
        if state.get("web_result") and state["web_result"].get("response"):
            return "use_web"
        return "use_gemini" # Fallback to pure Gemini
    
    async def process_message(
        self,
        db: AsyncSession,
        user: models.User,
        message: str,
        session_id: str = None
    ) -> Dict[str, Any]:
        """
        Process user message through LangGraph workflow
        """
        
        # Generate session ID if not provided
        if not session_id:
            session_id = str(uuid.uuid4())
        
        # Get chat history
        chat_history = await self._get_chat_history(db, user.id, session_id)
        
        # Save user message
        await self._save_message(
            db, user.id, session_id, "user", message, None, None
        )
        
        # Prepare initial state
        initial_state: AgentState = {
            "query": message,
            "chat_history": chat_history,
            "user_id": user.id,
            "user_district": user.district or "Unknown",
            "db_session": db,
            "rag_result": None,
            "db_result": None,
            "web_result": None,
            "final_response": "",
            "agent_used": "",
            "metadata": {}
        }
        
        try:
            # Run through graph
            final_state = await self.graph.ainvoke(initial_state)
            
            # Save assistant response
            await self._save_message(
                db,
                user.id,
                session_id,
                "assistant",
                final_state["final_response"],
                final_state["agent_used"],
                json.dumps(final_state["metadata"], default=str) # Use default=str for non-serializable items
            )
            
            return {
                "response": final_state["final_response"],
                "session_id": session_id,
                "agent_used": final_state["agent_used"],
                "metadata": final_state["metadata"]
            }
        except Exception as e:
            logger.error(f"❌ Error in LangGraph processing: {e}", exc_info=True)
            error_response = "I'm sorry, I encountered an unexpected error. Please try again."
            # Save error response to history
            await self._save_message(
                db,
                user.id,
                session_id,
                "assistant",
                error_response,
                "error",
                json.dumps({"error": str(e)})
            )
            return {
                "response": error_response,
                "session_id": session_id,
                "agent_used": "error",
                "metadata": {"error": str(e)}
            }

    
    async def _get_chat_history(
        self,
        db: AsyncSession,
        user_id: int,
        session_id: str
    ) -> List[Dict[str, str]]:
        """Retrieve chat history"""
        query = select(models.ChatHistory).where(
            models.ChatHistory.user_id == user_id,
            models.ChatHistory.session_id == session_id
        ).order_by(
            models.ChatHistory.created_at.asc()
        ).limit(settings.MAX_CHAT_HISTORY * 2) # Get pairs
        
        result = await db.execute(query)
        history = result.scalars().all()
        
        return [
            {
                "role": h.role,
                "message": h.message,
                "agent_type": h.agent_type,
                "timestamp": h.created_at.isoformat()
            }
            for h in history
        ]
    
    async def _save_message(
        self,
        db: AsyncSession,
        user_id: int,
        session_id: str,
        role: str,
        message: str,
        agent_type: str = None,
        metadata_json: str = None
    ):
        """Save message to chat history"""
        chat_message = models.ChatHistory(
            user_id=user_id,
            session_id=session_id,
            role=role,
            message=message,
            agent_type=agent_type,
            metadata_json=metadata_json
        )
        db.add(chat_message)
        await db.commit()
    
    async def get_user_sessions(
        self,
        db: AsyncSession,
        user_id: int,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Get user's chat sessions"""
        query = select(
            models.ChatHistory.session_id,
            func.min(models.ChatHistory.created_at).label("started_at"),
            func.max(models.ChatHistory.created_at).label("last_message_at"),
            func.count(models.ChatHistory.id).label("message_count")
        ).where(
            models.ChatHistory.user_id == user_id
        ).group_by(
            models.ChatHistory.session_id
        ).order_by(
            desc("last_message_at")
        ).limit(limit)
        
        result = await db.execute(query)
        sessions = result.all()
        
        return [
            {
                "session_id": s.session_id,
                "started_at": s.started_at.isoformat(),
                "last_message_at": s.last_message_at.isoformat(),
                "message_count": s.message_count
            }
            for s in sessions
        ]


# Global instance
chatbot = LangGraphChatbot()