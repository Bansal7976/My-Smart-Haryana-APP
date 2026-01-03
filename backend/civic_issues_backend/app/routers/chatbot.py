# in app/routers/chatbot.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from .. import database, schemas, models, utils
from ..services.langgraph_chatbot import chatbot

router = APIRouter(prefix="/chatbot", tags=["AI Chatbot - LangGraph + Gemini"])

@router.post("/chat", response_model=schemas.ChatResponse)
async def chat_with_bot(
    chat_request: schemas.ChatRequest,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Main endpoint for communicating with the AI-powered multi-agent chatbot.
    
    The chatbot can:
    - Search for Haryana government schemes
    - Provide statistics about cities and issue resolution
    - Help with platform usage
    - Answer general questions
    - Support multiple languages (English, Hindi, Punjabi)
    """
    result = await chatbot.process_message(
        db=db,
        user=current_user,
        message=chat_request.message,
        session_id=chat_request.session_id,
        preferred_language=chat_request.preferred_language
    )
    
    return schemas.ChatResponse(**result)

@router.get("/sessions", response_model=List[schemas.ChatSessionInfo])
async def get_chat_sessions(
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get list of user's chat sessions.
    """
    sessions = await chatbot.get_user_sessions(db, current_user.id)
    return [schemas.ChatSessionInfo(**s) for s in sessions]

@router.get("/history/{session_id}", response_model=List[schemas.ChatHistoryItem])
async def get_chat_history(
    session_id: str,
    db: AsyncSession = Depends(database.get_db),
    current_user: models.User = Depends(utils.get_current_user)
):
    """
    Get chat history for a specific session.
    """
    from sqlalchemy import select
    
    query = select(models.ChatHistory).where(
        models.ChatHistory.user_id == current_user.id,
        models.ChatHistory.session_id == session_id
    ).order_by(models.ChatHistory.created_at.asc())
    
    result = await db.execute(query)
    history = result.scalars().all()
    
    return [
        schemas.ChatHistoryItem(
            role=h.role,
            message=h.message,
            agent_type=h.agent_type,
            timestamp=h.created_at.isoformat()
        )
        for h in history
    ]