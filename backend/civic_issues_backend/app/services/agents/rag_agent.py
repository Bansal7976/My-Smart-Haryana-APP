# rag_agent.py
# RAG Agent - Retrieval Augmented Generation for Smart Haryana App Knowledge

from typing import Dict, Any, List
from sqlalchemy.ext.asyncio import AsyncSession
from .base_agent import BaseAgent
from langchain_community.embeddings import SentenceTransformerEmbeddings
from langchain_pinecone import PineconeVectorStore
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document
from dotenv import load_dotenv
from pinecone import Pinecone, ServerlessSpec
import os
import logging
import time

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


class RAGAgent(BaseAgent):
    """
    Agent that uses RAG (Retrieval Augmented Generation) to answer questions
    about the Smart Haryana app, its features, and how to use it.
    """

    def __init__(self, google_api_key: str, pinecone_api_key: str = None, index_name: str = "smart-haryana"):
        super().__init__(
            name="RAG Agent",
            description="Answers questions about Smart Haryana app using knowledge base"
        )
        self.google_api_key = google_api_key
        self.pinecone_api_key = pinecone_api_key or os.getenv("PINECONE_API_KEY")
        self.index_name = index_name
        self.vectorstore = None
        self.embeddings = None
        self.index = None

        self._initialize_rag()

    def _initialize_rag(self):
        """Initialize embeddings and Pinecone vector store"""
        try:
            # Step 1: Initialize local embeddings
            logger.info("Initializing local embeddings (all-MiniLM-L6-v2)...")
            self.embeddings = SentenceTransformerEmbeddings(
                model_name="all-MiniLM-L6-v2",
                model_kwargs={"device": "cpu"}
            )
            logger.info("Local embeddings initialized.")

            # Step 2: Check Pinecone API key
            if not self.pinecone_api_key:
                logger.warning("⚠️ Pinecone API key not found. Using in-memory vectorstore fallback.")
                return

            # Step 3: Initialize Pinecone client (v5+)
            logger.info("Connecting to Pinecone...")
            pc = Pinecone(api_key=self.pinecone_api_key)
            index_list = pc.list_indexes().names()

            # Step 4: Create index if it doesn't exist
            if self.index_name not in index_list:
                logger.info(f"Creating Pinecone index: {self.index_name}")
                pc.create_index(
                    name=self.index_name,
                    dimension=384,
                    metric="cosine",
                    spec=ServerlessSpec(cloud="gcp", region="us-east1")
                )
                time.sleep(5)  # wait for index creation

            # Step 5: Connect to the index
            self.index = pc.Index(self.index_name)

            # Step 6: Initialize LangChain Pinecone vectorstore
            self.vectorstore = PineconeVectorStore(
                index=self.index,
                embedding=self.embeddings,
                text_key="page_content"
            )

            # Step 7: Load knowledge base into Pinecone if empty
            stats = self.index.describe_index_stats()
            total_vectors = stats.get('total_vector_count', 0)
            
            if total_vectors == 0:
                logger.info("Pinecone index is empty. Loading knowledge base...")
                documents = self._create_knowledge_base()
                if documents:
                    self.vectorstore.add_documents(documents)
                    logger.info(f"✅ Uploaded {len(documents)} documents to Pinecone")
                else:
                    logger.warning("No documents found in knowledge base")
            else:
                logger.info(f"✅ Pinecone index has {total_vectors} vectors")

            logger.info("✅ RAG Agent with Pinecone initialized successfully")

        except Exception as e:
            logger.error(f"❌ RAG initialization error: {e}", exc_info=True)
            logger.warning("RAG will use in-memory vectorstore fallback mode")

    def _create_knowledge_base(self) -> List[Document]:
        """Load knowledge base documents from markdown files"""
        documents = []
        kb_path = os.path.join(os.path.dirname(__file__), "../../../knowledge_base")

        if not os.path.exists(kb_path):
            logger.warning(f"Knowledge base directory not found at {kb_path}")
            return documents

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
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()

                    text_splitter = RecursiveCharacterTextSplitter(
                        chunk_size=1000,
                        chunk_overlap=200,
                        separators=["\n\n", "\n", ". ", " ", ""]
                    )

                    chunks = text_splitter.split_text(content)

                    for chunk in chunks:
                        documents.append(
                            Document(
                                page_content=chunk,
                                metadata={"source": filename}
                            )
                        )

                    logger.info(f"Loaded {len(chunks)} chunks from {filename}")

                except Exception as e:
                    logger.error(f"Error loading {filename}: {e}")
            else:
                logger.warning(f"Knowledge base file not found: {filename}")

        logger.info(f"Total documents loaded: {len(documents)}")
        return documents

    async def can_handle(self, query: str, context: Dict[str, Any]) -> bool:
        """Check if query is about the app"""
        keywords = [
            "how to", "कैसे", "what is", "क्या है", "how do i", "मैं कैसे",
            "report", "रिपोर्ट", "track", "ट्रैक", "issue", "समस्या",
            "app", "ऐप", "platform", "feature", "सुविधा", "use", "उपयोग",
            "status", "स्थिति", "verify", "सत्यापित", "feedback", "फीडबैक",
            "account", "खाता", "login", "लॉगिन", "register", "पंजीकरण",
            "priority", "प्राथमिकता", "assignment", "आवंटन", "worker", "कर्मचारी",
            "tutorial", "guide", "help", "मदद", "question", "प्रश्न"
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
        """Execute RAG query"""
        if not self.vectorstore:
            return {
                "response": "Knowledge base is currently unavailable.",
                "metadata": {"error": "vectorstore_not_initialized"},
                "agent_type": "rag"
            }

        try:
            # Use similarity_search_with_score to check semantic relevance
            docs_with_scores = self.vectorstore.similarity_search_with_score(query, k=3)

            if not docs_with_scores:
                return {
                    "response": "No relevant information found in knowledge base.",
                    "metadata": {"docs_found": 0},
                    "agent_type": "rag"
                }

            # Filter by semantic similarity threshold (cosine similarity: 0-1, higher is better)
            # 0.5+ is moderately relevant, 0.7+ is highly relevant
            SIMILARITY_THRESHOLD = 0.5
            relevant_docs = [
                (doc, score) for doc, score in docs_with_scores 
                if score >= SIMILARITY_THRESHOLD
            ]

            if not relevant_docs:
                logger.info(f"No docs above similarity threshold {SIMILARITY_THRESHOLD}. Max score: {max([s for _, s in docs_with_scores]) if docs_with_scores else 0}")
                return {
                    "response": "No relevant information found in knowledge base.",
                    "metadata": {
                        "docs_found": 0,
                        "max_score": max([s for _, s in docs_with_scores]) if docs_with_scores else 0
                    },
                    "agent_type": "rag"
                }

            # Return only relevant content
            response_text = "\n\n".join([doc.page_content for doc, _ in relevant_docs])
            scores = [float(score) for _, score in relevant_docs]
            
            return {
                "response": response_text,
                "metadata": {
                    "docs_retrieved": len(relevant_docs),
                    "sources": list(set([doc.metadata.get("source", "unknown") for doc, _ in relevant_docs])),
                    "similarity_scores": scores,
                    "avg_score": sum(scores) / len(scores) if scores else 0
                },
                "agent_type": "rag"
            }

        except RuntimeError as e:
            if "Session is closed" in str(e):
                logger.error("RAG session closed error - reinitializing vectorstore")
                self._initialize_rag()
                return {
                    "response": "Knowledge base temporarily unavailable. Please try again.",
                    "metadata": {"error": "session_closed_reinitializing"},
                    "agent_type": "rag"
                }
            raise
        except Exception as e:
            logger.error(f"RAG execution error: {str(e)}", exc_info=True)
            return {
                "response": "Error retrieving information. Please try again.",
                "metadata": {"error": "retrieval_failed"},
                "agent_type": "rag"
            }
