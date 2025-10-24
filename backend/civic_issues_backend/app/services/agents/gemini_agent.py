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
            
            messages = [
                SystemMessage(content="""You are a professional AI assistant for Smart Haryana, a civic issues reporting platform for Haryana, India.

Your role:
- Help users report and track civic issues (potholes, streetlights, water supply, etc.)
- Provide information about Haryana districts and government services
- Answer questions about the app features and how to use them
- Be polite, professional, and helpful

Guidelines:
- Keep responses concise and easy to understand
- Use simple bullet points with dash (-) or numbers for clarity
- DO NOT use asterisks (**) or markdown bold/italic formatting
- Write in plain text with proper spacing
- DO NOT greet the user on every message - only greet once at the start of a new conversation
- Get straight to answering their question
- If you don't know something, be honest and direct
- Encourage users to report civic issues for their community
- Support both English and Hindi when requested
- Be conversational but professional - avoid repetitive phrases

Context: The user is from {district} district.""".format(district=context.get("user_district", "Unknown")))
            ]
            
            # Add chat history
            for msg in chat_history[-10:]: # Get last 10 messages
                if msg["role"] == "user":
                    messages.append(HumanMessage(content=msg["message"]))
                elif msg["role"] == "assistant":
                    messages.append(AIMessage(content=msg["message"]))
            
            # Add current user query
            messages.append(HumanMessage(content=query))
            
            # ✅ Async call
            response = await self.llm.ainvoke(messages)
            answer = response.content
            
            return {
                "response": answer,
                "metadata": {
                    "model": self.llm.model_name if hasattr(self.llm, 'model_name') else "gemini-pro",
                    "tokens": len(answer.split()) # Approximate token count
                },
                "agent_type": "gemini"
            }
            
        except Exception as e:
            logger.error(f"❌ Gemini agent error: {str(e)}", exc_info=True)
            return {
                "response": "I encountered an error while processing your request. Could you please rephrase your question?",
                "metadata": {"error": str(e)},
                "agent_type": "gemini"
            }

    
    async def generate_with_context(self, query: str, retrieved_context: str) -> str:
        """
        Generate response using retrieved context (for RAG, DB, or Web).
        This is now asynchronous with improved corrective RAG.
        """
        if not self.llm:
            # Fallback to returning raw context if LLM fails
            return retrieved_context
        
        try:
            # Improved prompt for "corrective RAG" with better response quality
            prompt = f"""You are a professional assistant for Smart Haryana civic platform.

Your task: Answer the user's question based on the provided context below.

Guidelines:
- Synthesize the information into a clear, natural response
- Use simple bullet points with dash (-) or numbers for listing
- DO NOT use asterisks (**) or markdown bold/italic formatting
- Write in plain, clean text with proper spacing
- DO NOT greet the user (no "Namaste", "Welcome", etc.) - get straight to the answer
- Be direct and professional
- If the context doesn't fully answer the question, acknowledge what you know and what you don't
- Add helpful context or actionable advice where relevant

Provided Context:
---
{retrieved_context}
---

User Question: {query}

Your Answer:"""
            
            # ✅ CORRECTION: Use async ainvoke instead of sync invoke
            response = await self.llm.ainvoke([HumanMessage(content=prompt)])
            return response.content
            
        except Exception as e:
            logger.error(f"Context generation error: {e}")
            # Fallback to returning raw context on error
            return retrieved_context