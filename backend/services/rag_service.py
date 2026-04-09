"""
Weaviate RAG Service for Medical Knowledge Retrieval
Complete implementation with vector database management
"""
import weaviate
from weaviate.classes.init import Auth
from weaviate.classes.query import MetadataQuery
from typing import List, Dict, Optional, Any
import logging
from datetime import datetime
import hashlib
from urllib.parse import urlparse

# 1. Swapped import to use your custom PyTorch utility
from utils.disembed_utils import DisEmbedModel
from models.schemas import MedicalKnowledgeDoc, RAGResult, RAGQuery
from config.settings import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class WeaviateRAGService:
    """
    Complete RAG implementation using Weaviate vector database
    Handles medical knowledge storage, retrieval, and updates
    """
    
    COLLECTION_NAME = "MedicalKnowledge"
    
    def __init__(self):
        """Initialize Weaviate client and embedding model"""
        self.settings = get_settings()
        self.client = None
        self.embedding_model = None
        self._initialize_client()

    def _ensure_embedding_model(self):
        """Lazily load the embedding model on first use."""
        if self.embedding_model is None:
            self._initialize_embedding_model()
    
    def _initialize_client(self):
        """Connect to Weaviate instance"""
        try:
            raw_url = (self.settings.weaviate_url or "http://localhost:8080").strip()
            parsed = urlparse(raw_url if "://" in raw_url else f"http://{raw_url}")
            host = (parsed.hostname or "localhost").strip()
            port = parsed.port or 8080
            scheme = (parsed.scheme or "http").lower()
            has_api_key = bool((self.settings.weaviate_api_key or "").strip())
            is_local_host = host in {"localhost", "127.0.0.1", "0.0.0.0", "weaviate"}

            # Use cloud connection only for non-local endpoints.
            if has_api_key and not is_local_host:
                cluster_url = raw_url if "://" in raw_url else f"https://{raw_url}"
                self.client = weaviate.connect_to_weaviate_cloud(
                    cluster_url=cluster_url,
                    auth_credentials=Auth.api_key(self.settings.weaviate_api_key.strip())
                )
            else:
                self.client = weaviate.connect_to_local(
                    host=host,
                    port=port
                )
            
            logger.info(f"Successfully connected to Weaviate at {self.settings.weaviate_url}")
            self._create_schema()
            
        except Exception as e:
            logger.error(f"Failed to connect to Weaviate: {e}")
            raise
    
    def _initialize_embedding_model(self):
        """Load custom PyTorch model for embeddings"""
        try:
            # 2. Replaced SentenceTransformer with DisEmbedModel
            self.embedding_model = DisEmbedModel(self.settings.embedding_model)
            logger.info(f"Loaded custom embedding model: {self.settings.embedding_model}")
        except Exception as e:
            logger.error(f"Failed to load embedding model: {e}")
            raise
    
    def _create_schema(self):
        """Create Weaviate schema for medical knowledge"""
        try:
            collections = self.client.collections.list_all()
            
            if self.COLLECTION_NAME in collections:
                logger.info(f"Collection {self.COLLECTION_NAME} already exists")
                return
            
            from weaviate.classes.config import Property, DataType, Configure
            
            self.client.collections.create(
                name=self.COLLECTION_NAME,
                description="Medical knowledge base for symptom analysis",
                vectorizer_config=Configure.Vectorizer.none(),
                properties=[
                    Property(name="doc_id",            data_type=DataType.TEXT),
                    Property(name="condition",          data_type=DataType.TEXT),
                    Property(name="symptoms",           data_type=DataType.TEXT_ARRAY),
                    Property(name="description",        data_type=DataType.TEXT),
                    Property(name="severity",           data_type=DataType.TEXT),
                    Property(name="treatment",          data_type=DataType.TEXT),
                    Property(name="when_to_seek_care",  data_type=DataType.TEXT),
                    Property(name="risk_factors",       data_type=DataType.TEXT_ARRAY),
                    Property(name="complications",      data_type=DataType.TEXT_ARRAY),
                    Property(name="source",             data_type=DataType.TEXT),
                    Property(name="content_vector",     data_type=DataType.TEXT),
                ]
            )
            
            logger.info(f"Created collection: {self.COLLECTION_NAME}")
            
        except Exception as e:
            logger.error(f"Failed to create schema: {e}")
            raise
    
    def _generate_doc_id(self, condition: str, source: str) -> str:
        """Generate unique document ID"""
        unique_string = f"{condition}_{source}_{datetime.utcnow().isoformat()}"
        return hashlib.sha256(unique_string.encode()).hexdigest()[:16]
    
    def _create_content_vector_text(self, doc: MedicalKnowledgeDoc) -> str:
        """Create combined text for embedding"""
        parts = [
            f"Condition: {doc.condition}",
            f"Symptoms: {', '.join(doc.symptoms)}",
            f"Description: {doc.description}",
            f"Severity: {doc.severity}",
            f"Treatment: {doc.treatment}",
            f"When to seek care: {doc.when_to_seek_care}"
        ]
        
        if doc.risk_factors:
            parts.append(f"Risk factors: {', '.join(doc.risk_factors)}")
        
        if doc.complications:
            parts.append(f"Complications: {', '.join(doc.complications)}")
        
        return " | ".join(parts)
    
    async def add_medical_knowledge(self, doc: MedicalKnowledgeDoc) -> str:
        """Add a medical knowledge document to Weaviate"""
        try:
            self._ensure_embedding_model()
            collection = self.client.collections.get(self.COLLECTION_NAME)
            
            if not doc.doc_id:
                doc.doc_id = self._generate_doc_id(doc.condition, doc.source)
            
            content_text = self._create_content_vector_text(doc)
            
            # 3. Extract the flat list from the 2D output
            embedding = self.embedding_model.encode(content_text)[0]
            
            data_object = {
                "doc_id": doc.doc_id,
                "condition": doc.condition,
                "symptoms": doc.symptoms,
                "description": doc.description,
                "severity": doc.severity,
                "treatment": doc.treatment,
                "when_to_seek_care": doc.when_to_seek_care,
                "risk_factors": doc.risk_factors or [],
                "complications": doc.complications or [],
                "source": doc.source,
                "last_updated": doc.last_updated.isoformat(),
                "content_vector": content_text
            }
            
            collection.data.insert(
                properties=data_object,
                vector=embedding
            )
            
            logger.info(f"Added document {doc.doc_id} for condition: {doc.condition}")
            return doc.doc_id
            
        except Exception as e:
            logger.error(f"Failed to add document: {e}")
            raise
    
    async def bulk_add_knowledge(self, docs: List[MedicalKnowledgeDoc]) -> Dict[str, Any]:
        """Bulk add multiple documents efficiently"""
        try:
            self._ensure_embedding_model()
            collection = self.client.collections.get(self.COLLECTION_NAME)
            
            successful = 0
            failed = 0
            errors = []
            
            # 4. OPTIMIZATION: Extract all text and encode in one batch
            # This is significantly faster than encoding inside the loop
            content_texts = [self._create_content_vector_text(doc) for doc in docs]
            batch_embeddings = self.embedding_model.encode(content_texts)
            
            with collection.batch.dynamic() as batch:
                for idx, doc in enumerate(docs):
                    try:
                        if not doc.doc_id:
                            doc.doc_id = self._generate_doc_id(doc.condition, doc.source)
                        
                        data_object = {
                            "doc_id": doc.doc_id,
                            "condition": doc.condition,
                            "symptoms": doc.symptoms,
                            "description": doc.description,
                            "severity": doc.severity,
                            "treatment": doc.treatment,
                            "when_to_seek_care": doc.when_to_seek_care,
                            "risk_factors": doc.risk_factors or [],
                            "complications": doc.complications or [],
                            "source": doc.source,
                            "last_updated": doc.last_updated.isoformat(),
                            "content_vector": content_texts[idx]
                        }
                        
                        batch.add_object(
                            properties=data_object,
                            vector=batch_embeddings[idx] # Use pre-calculated vector
                        )
                        
                        successful += 1
                        
                    except Exception as e:
                        failed += 1
                        errors.append(f"{doc.condition}: {str(e)}")
                        logger.error(f"Failed to add {doc.condition}: {e}")
            
            result = {
                "total": len(docs),
                "successful": successful,
                "failed": failed,
                "errors": errors[:10]
            }
            
            logger.info(f"Bulk insert completed: {successful} successful, {failed} failed")
            return result
            
        except Exception as e:
            logger.error(f"Bulk insert failed: {e}")
            raise
    
    async def search_similar_conditions(
        self,
        query: RAGQuery
    ) -> List[RAGResult]:
        """Search for medically relevant knowledge based on symptoms"""
        try:
            self._ensure_embedding_model()
            collection = self.client.collections.get(self.COLLECTION_NAME)
            
            # 5. Extract flat list for query
            query_embedding = self.embedding_model.encode(query.query_text)[0]
            
            response = collection.query.near_vector(
                near_vector=query_embedding,
                limit=query.max_results,
                return_metadata=MetadataQuery(distance=True)
            )
            
            results = []
            for obj in response.objects:
                certainty = 1 - obj.metadata.distance
                
                if certainty < query.min_certainty:
                    continue
                
                result = RAGResult(
                    doc_id=obj.properties.get('doc_id', 'unknown'),
                    condition=obj.properties.get('condition', 'Unknown'),
                    content=self._format_content(obj.properties),
                    relevance_score=certainty,
                    source=obj.properties.get('source', 'Unknown'),
                    metadata={
                        'symptoms': obj.properties.get('symptoms', []),
                        'severity': obj.properties.get('severity', 'Unknown'),
                        'when_to_seek_care': obj.properties.get('when_to_seek_care', ''),
                        'treatment': obj.properties.get('treatment', '')
                    }
                )
                
                results.append(result)
            
            logger.info(f"Found {len(results)} relevant results for query")
            return results
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            raise
    
    def _format_content(self, properties: Dict[str, Any]) -> str:
        """Format document properties into readable content"""
        parts = []
        condition = properties.get('condition', 'Unknown')
        parts.append(f"**{condition}**")
        
        symptoms = properties.get('symptoms', [])
        if symptoms:
            parts.append(f"Common symptoms: {', '.join(symptoms)}")
        
        description = properties.get('description', '')
        if description:
            parts.append(f"Description: {description}")
        
        severity = properties.get('severity', '')
        if severity:
            parts.append(f"Severity: {severity}")
        
        treatment = properties.get('treatment', '')
        if treatment:
            parts.append(f"Treatment: {treatment}")
        
        when_to_seek = properties.get('when_to_seek_care', '')
        if when_to_seek:
            parts.append(f"When to seek care: {when_to_seek}")
        
        return "\n".join(parts)
    
    async def delete_document(self, doc_id: str) -> bool:
        """Delete a document by ID"""
        try:
            collection = self.client.collections.get(self.COLLECTION_NAME)
            response = collection.data.delete_many(
                where={
                    "path": ["doc_id"],
                    "operator": "Equal",
                    "valueText": doc_id
                }
            )
            logger.info(f"Deleted document {doc_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete document {doc_id}: {e}")
            return False
    
    async def get_document_count(self) -> int:
        """Get total number of documents in knowledge base"""
        try:
            collection = self.client.collections.get(self.COLLECTION_NAME)
            aggregate = collection.aggregate.over_all(total_count=True)
            return aggregate.total_count
        except Exception as e:
            logger.error(f"Failed to get document count: {e}")
            return 0
    
    async def update_document(self, doc_id: str, updated_doc: MedicalKnowledgeDoc) -> bool:
        """Update an existing document"""
        try:
            await self.delete_document(doc_id)
            updated_doc.doc_id = doc_id
            await self.add_medical_knowledge(updated_doc)
            logger.info(f"Updated document {doc_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to update document {doc_id}: {e}")
            return False
    
    def close(self):
        """Close Weaviate connection"""
        if self.client:
            self.client.close()
            logger.info("Closed Weaviate connection")

# Singleton instance
_rag_service: Optional[WeaviateRAGService] = None

def get_rag_service() -> WeaviateRAGService:
    """Get or create RAG service singleton"""
    global _rag_service
    if _rag_service is None:
        _rag_service = WeaviateRAGService()
    return _rag_service