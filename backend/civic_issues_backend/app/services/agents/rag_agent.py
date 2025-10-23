# RAG Agent - Retrieval Augmented Generation for Smart Haryana App Knowledge
from typing import Dict, Any, List
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document
import os
import logging

logger = logging.getLogger(__name__)

class RAGAgent(BaseAgent):
    """
    Agent that uses RAG (Retrieval Augmented Generation) to answer questions
    about the Smart Haryana app, its features, and how to use it.
    """
    
    def __init__(self, google_api_key: str, vector_store_path: str = "data/vector_store"):
        super().__init__(
            name="RAG Agent",
            description="Answers questions about Smart Haryana app using knowledge base"
        )
        self.google_api_key = google_api_key
        self.vector_store_path = vector_store_path
        self.vectorstore = None
        self.embeddings = None
        
        # Initialize embeddings and vector store
        self._initialize_rag()
    
    def _initialize_rag(self):
        """Initialize embeddings and vector store"""
        if not self.google_api_key:
            logger.warning("RAG Agent: GOOGLE_API_KEY not set. RAG will be unavailable.")
            return
        
        try:
            # Initialize Gemini embeddings
            self.embeddings = GoogleGenerativeAIEmbeddings(
                model="models/embedding-001",
                google_api_key=self.google_api_key
            )
            
            # Create knowledge base documents
            documents = self._create_knowledge_base()
            
            if not documents:
                 logger.warning("RAG Agent: No knowledge base documents found or loaded.")
                 return

            # Create or load vector store
            os.makedirs(self.vector_store_path, exist_ok=True)
            
            # Check if vector store exists
            if os.path.exists(os.path.join(self.vector_store_path, "chroma.sqlite3")):
                # Load existing vector store
                logger.info(f"Loading existing vector store from {self.vector_store_path}")
                self.vectorstore = Chroma(
                    persist_directory=self.vector_store_path,
                    embedding_function=self.embeddings
                )
            else:
                # Create new vector store
                logger.info(f"Creating new vector store at {self.vector_store_path}")
                self.vectorstore = Chroma.from_documents(
                    documents=documents,
                    embedding=self.embeddings,
                    persist_directory=self.vector_store_path
                )
            logger.info("✅ RAG Agent initialized successfully.")
                
        except Exception as e:
            logger.error(f"❌ RAG initialization error: {e}", exc_info=True)
    
    def _create_knowledge_base(self) -> List[Document]:
        """Create knowledge base documents from markdown files"""
        
        documents = []
        
        # Path to knowledge base directory
        kb_path = os.path.join(os.path.dirname(__file__), "../../../knowledge_base")
        
        # Check if knowledge base directory exists
        if not os.path.exists(kb_path):
            logger.warning(f"RAG Agent: Knowledge base directory not found at {kb_path}")
            return documents
        
        # Read all markdown files from knowledge base
        md_files = [
            "app_guide.md",
            "features.md",
            "faq.md",
            "departments.md",
            "haryana_info.md",
            "troubleshooting.md"
        ]
        
        for filename in md_files:
            file_path = os.path.join(kb_path, filename)
            
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    # Split text into chunks
                    text_splitter = RecursiveCharacterTextSplitter(
                        chunk_size=1000,
                        chunk_overlap=200,
                        length_function=len,
                        separators=["\n\n", "\n", ". ", " ", ""]
                    )
                    
                    chunks = text_splitter.split_text(content)
                    
                    # Create documents with source metadata
                    for chunk in chunks:
                        documents.append(
                            Document(
                                page_content=chunk,
                                metadata={"source": filename}
                            )
                        )
                    
                    logger.info(f"✓ RAG: Loaded {len(chunks)} chunks from {filename}")
                    
                except Exception as e:
                    logger.error(f"RAG: Error loading {filename}: {e}")
            else:
                logger.warning(f"RAG: Knowledge base file not found: {filename}")
        
        logger.info(f"RAG: Total documents loaded: {len(documents)}")
        return documents
    
    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """
        Check if query is about the app itself, features, or how-to questions.
        """
        app_keywords = [
            "how to", "कैसे", "what is", "क्या है", "how do i", "मैं कैसे",
            "report", "रिपोर्ट", "track", "ट्रैक", "issue", "समस्या",
            "app", "ऐप", "platform", "feature", "सुविधा", "use", "उपयोग",
            "status", "स्थिति", "verify", "सत्यापित", "feedback", "फीडबैक",
            "account", "खाता", "login", "लॉगिन", "register", "पंजीकरण",
            "priority", "प्राथमिकता", "assignment", "आवंटन", "worker", "कर्मचारी",
            "tutorial", "guide", "help", "मदद", "question", "प्रश्न"
        ]
        
        query_lower = query.lower()
        return any(keyword in query_lower for keyword in app_keywords)
    
    async def execute(
        self, 
        query: str, 
        context: Dict[str, Any],
        db: AsyncSession,
        user_id: int
    ) -> Dict[str, Any]:
        """
        Execute RAG query to answer app-related questions.
        """
        
        if not self.vectorstore:
            return {
                "response": "I'm sorry, but my knowledge base is currently unavailable. Please try again later.",
                "metadata": {"error": "vectorstore_not_initialized"},
                "agent_type": "rag"
            }
        
        try:
            # Retrieve relevant documents
            retriever = self.vectorstore.as_retriever(
                search_kwargs={"k": 3}  # Top 3 most relevant chunks
            )
            
            # ✅ CORRECTION: Use async aget_relevant_documents
            docs = await retriever.aget_relevant_documents(query)
            
            if not docs:
                return {
                    "response": "I don't have specific information about that in my knowledge base. Could you rephrase your question?",
                    "metadata": {"docs_found": 0},
                    "agent_type": "rag"
                }
            
            # Combine retrieved context
            context_text = "\n\n".join([doc.page_content for doc in docs])
            
            # This context will be sent to the Gemini agent for enhancement
            response_text = context_text
            
            return {
                "response": response_text,
                "metadata": {
                    "docs_retrieved": len(docs),
                    "sources": list(set([doc.metadata.get("source", "unknown") for doc in docs]))
                },
                "agent_type": "rag"
            }
            
        except Exception as e:
            logger.error(f"❌ RAG agent error: {str(e)}", exc_info=True)
            return {
                "response": "I encountered an error while searching my knowledge base. Please try rephrasing your question.",
                "metadata": {"error": "retrieval_failed"},
                "agent_type": "rag"
            }