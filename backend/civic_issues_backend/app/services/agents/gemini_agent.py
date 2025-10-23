from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

class GeminiAgent(BaseAgent):
    def __init__(self, google_api_key: str, model: str = "gemini-1.5-flash", temperature: float = 0.7):
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
            except Exception as e:
                print(f"Gemini initialization error: {e}")
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
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
                SystemMessage(content="""You are a helpful AI assistant for Smart Haryana, a civic issues reporting platform for Haryana, India.
                
Your role:
- Help users report and track civic issues (potholes, streetlights, water supply, etc.)
- Provide information about Haryana districts and government services
- Answer questions about the app features and how to use them
- Be polite, professional, and helpful

Guidelines:
- Keep responses concise and easy to understand
- Use bullet points for lists
- If you don't know something, be honest
- Encourage users to report civic issues for their community
- Support both English and Hindi (when requested)

Context: The user is from {district} district.""".format(district=context.get("user_district", "Unknown")))
            ]
            
            for msg in chat_history[-10:]:
                if msg["role"] == "user":
                    messages.append(HumanMessage(content=msg["message"]))
                elif msg["role"] == "assistant":
                    messages.append(AIMessage(content=msg["message"]))
            
            messages.append(HumanMessage(content=query))
            
            # ✅ Async call
            response = await self.llm.ainvoke(messages)
            answer = response.content
            
            return {
                "response": answer,
                "metadata": {
                    "model": self.llm.model_name if hasattr(self.llm, 'model_name') else "gemini-1.5-flash",
                    "tokens": len(answer.split())
                },
                "agent_type": "gemini"
            }
            
        except Exception as e:
            print(f"Gemini agent error: {str(e)}")
            return {
                "response": "I encountered an error while processing your request. Could you please rephrase your question?",
                "metadata": {"error": "generation_failed"},
                "agent_type": "gemini"
            }

    
    def generate_with_context(self, query: str, retrieved_context: str) -> str:
        """
        Generate response using retrieved context (for RAG).
        """
        if not self.llm:
            return retrieved_context
        
        try:
            prompt = f"""Based on the following information about Smart Haryana, answer the user's question.

Context:
{retrieved_context}

User Question: {query}

Answer: (Be concise, helpful, and accurate. Use bullet points if listing steps.)"""
            
            response = self.llm.invoke([HumanMessage(content=prompt)])
            return response.content
            
        except Exception as e:
            print(f"Context generation error: {e}")
            return retrieved_context

