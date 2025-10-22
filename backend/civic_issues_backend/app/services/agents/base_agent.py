# Base Agent for Multi-Agent System
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession

class BaseAgent(ABC):
    """
    Abstract base class for all agents in the multi-agent system.
    """
    
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description
    
    @abstractmethod
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """
        Determine if this agent can handle the given query.
        """
        pass
    
    @abstractmethod
    async def execute(
        self, 
        query: str, 
        context: Dict[str, Any],
        db: AsyncSession,
        user_id: int
    ) -> Dict[str, Any]:
        """
        Execute the agent's task and return the response.
        Returns: {
            "response": str,
            "metadata": Optional[Dict],
            "agent_type": str
        }
        """
        pass
    
    def __str__(self):
        return f"{self.name}: {self.description}"

