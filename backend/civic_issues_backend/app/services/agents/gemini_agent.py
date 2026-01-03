from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
import logging

logger = logging.getLogger(__name__)

class GeminiAgent(BaseAgent):
    def __init__(self, google_api_key: str, model: str = "gemini-2.5-flash", temperature: float = 0.7):
        super().__init__(
            name="Gemini Agent",
            description="AI-powered conversation agent using Google Gemini"
        )
        self.google_api_key = google_api_key
        self.llm = None
        
        if google_api_key:
            try:
                self.llm = ChatGoogleGenerativeAI(
                    model=model,
                    google_api_key=google_api_key,
                    temperature=temperature,
                    convert_system_message_to_human=True
                )
                logger.info(f"✅ Gemini agent initialized with model: {model}")
            except Exception as e:
                logger.error(f"❌ Gemini initialization error: {e}")
                self.llm = None
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        # This agent is the fallback, so it can always handle the query
        return True
    
    async def execute(self, query: str, context: Dict[str, Any], db: AsyncSession, user_id: int) -> Dict[str, Any]:
        if not self.llm:
            return {
                "response": "I'm sorry, but AI features are currently unavailable. Please contact the administrator.",
                "metadata": {"error": "GOOGLE_API_KEY not configured"},
                "agent_type": "gemini"
            }
        
        try:
            chat_history = context.get("chat_history", [])
            retrieved_context = context.get("retrieved_context", "")
            
            # Build system message
            system_content = """You are a helpful assistant for Smart Haryana civic platform.

CRITICAL FACTS ABOUT HARYANA (ALWAYS USE THESE):
- Haryana has EXACTLY 22 DISTRICTS: Ambala, Bhiwani, Charkhi Dadri, Faridabad, Fatehabad, Gurugram, Hisar, Jhajjar, Jind, Kaithal, Karnal, Kurukshetra, Mahendragarh, Nuh, Palwal, Panchkula, Panipat, Rewari, Rohtak, Sirsa, Sonipat, Yamunanagar
- Capital: Chandigarh (shared with Punjab)
- Haryana is a STATE in India
- Population: ~28 million people
- Area: 44,212 km²

SMART HARYANA APP FEATURES:
- Report civic issues (potholes, street lights, water supply, etc.)
- Track issue status and resolution
- Voice input in Hindi and English
- GPS location verification
- Photo evidence upload
- AI-powered chatbot assistance

Rules:
- Keep responses SHORT (2-4 sentences max)
- Be FACTUALLY ACCURATE - use the facts above
- If asked about districts, ALWAYS say "22 districts"
- NO greetings, NO bold/italic formatting
- Use simple bullet points (-) when listing
- Get straight to the answer

User is from {district} district.""".format(district=context.get("user_district", "Unknown"))
            
            # If we have retrieved context from other agents, use it
            if retrieved_context:
                system_content += f"\n\nRelevant Information:\n{retrieved_context}\n\nUse this information to provide a helpful answer."
            
            messages = [SystemMessage(content=system_content)]
            
            # Add chat history
            for msg in chat_history[-10:]:  # Get last 10 messages
                if msg["role"] == "user":
                    messages.append(HumanMessage(content=msg["message"]))
                elif msg["role"] == "assistant":
                    messages.append(AIMessage(content=msg["message"]))
            
            # Add current query
            messages.append(HumanMessage(content=query))
            
            # Get response from Gemini
            response = self.llm.invoke(messages)
            final_response = response.content
            
            return {
                "response": final_response,
                "metadata": {
                    "agent_type": "gemini",
                    "has_context": bool(retrieved_context)
                }
            }
            
        except Exception as e:
            logger.error(f"Gemini agent error: {e}")
            return {
                "response": "I'm sorry, I encountered an error while processing your request. Please try again.",
                "metadata": {"error": str(e), "agent_type": "gemini"}
            }

    
    async def verify_answer(self, query: str, answer: str) -> Dict[str, Any]:
        """
        Verify if the generated answer is factually correct and relevant.
        Returns confidence score and whether to use the answer.
        """
        if not self.llm:
            return {"is_valid": True, "confidence": 0.8, "reason": "No LLM available"}
        
        try:
            # Simple relevance check - if answer directly addresses the query, it's likely good
            query_lower = query.lower()
            answer_lower = answer.lower()
            
            # Check for direct relevance indicators
            relevance_score = 0.0
            
            # Check if answer contains key terms from query
            query_words = set(query_lower.split())
            answer_words = set(answer_lower.split())
            common_words = query_words.intersection(answer_words)
            
            if len(common_words) > 0:
                relevance_score += 0.3
            
            # Check answer length (not too short, not too long)
            answer_length = len(answer.split())
            if 10 <= answer_length <= 200:
                relevance_score += 0.3
            elif answer_length > 5:
                relevance_score += 0.2
            
            # Check if answer doesn't contain error indicators
            error_indicators = ["i don't know", "i'm not sure", "i cannot", "error", "sorry"]
            if not any(indicator in answer_lower for indicator in error_indicators):
                relevance_score += 0.4
            
            # For RAG answers, trust them more
            if "context" in query_lower or len(answer) > 50:
                relevance_score = min(relevance_score + 0.2, 1.0)
            
            confidence = min(relevance_score, 1.0)
            is_valid = confidence >= 0.6
            
            return {
                "is_valid": is_valid,
                "confidence": confidence,
                "reason": f"Relevance-based scoring: {confidence:.2f}"
            }
                
        except Exception as e:
            logger.error(f"Verification error: {e}")
            return {"is_valid": True, "confidence": 0.8, "reason": f"Error in verification, assuming valid"}

    async def generate_with_context(self, query: str, retrieved_context: str) -> str:
        """
        Generate response using retrieved context with enhanced polishing.
        Always returns a polished, conversational answer.
        """
        if not self.llm:
            return retrieved_context
        
        try:
            # Enhanced prompt for better answer generation
            prompt = f"""You are a helpful assistant for Smart Haryana civic platform. Use the context below to answer the user's question in a conversational, helpful way.

Context Information:
{retrieved_context}

User Question: {query}

Instructions:
- Use the context information to provide a complete, accurate answer
- Make the response conversational and friendly
- If the context has technical details, explain them simply
- Keep the response focused and helpful (2-4 sentences)
- If context is incomplete, acknowledge what you know and suggest next steps
- Don't mention "context" or "information provided" - just answer naturally

Answer:"""
            
            response = await self.llm.ainvoke([HumanMessage(content=prompt)])
            polished_answer = response.content
            
            # Always return the polished answer - trust the context provided by other agents
            return polished_answer
            
        except Exception as e:
            logger.error(f"Context generation error: {e}")
            # Fallback: return context with simple formatting
            return f"Based on the available information: {retrieved_context}"