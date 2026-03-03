"""
Lifelens Backend API
FastAPI application with Gemini and RAG integration
"""
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from typing import List
import time

from models.schemas import (
    SymptomInput,
    SymptomAnalysisResult,
    MedicalKnowledgeDoc,
    RAGQuery,
    RAGResult,
    ErrorResponse
)
from services.gemini_service import get_analysis_service, GeminiAnalysisService
from services.rag_service import get_rag_service, WeaviateRAGService
from config.settings import get_settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get settings
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("Starting Lifelens API...")
    logger.info(f"Gemini API configured: {bool(settings.gemini_api_key)}")
    logger.info(f"Weaviate URL: {settings.weaviate_url}")
    
    # Initialize services
    try:
        analysis_service = get_analysis_service()
        rag_service = get_rag_service()
        logger.info("Services initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize services: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Shutting down Lifelens API...")
    rag_service.close()


# Create FastAPI app
app = FastAPI(
    title="Lifelens API",
    description="Symptom analysis API with Gemini and RAG integration",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Exception handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=exc.detail,
            detail=str(exc)
        ).dict()
    )


@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="Internal server error",
            detail=str(exc)
        ).dict()
    )


# Health check endpoint
@app.get("/health", tags=["System"])
async def health_check():
    """Check API health and service status"""
    try:
        rag_service = get_rag_service()
        doc_count = await rag_service.get_document_count()
        
        return {
            "status": "healthy",
            "services": {
                "api": "operational",
                "gemini": "operational" if settings.gemini_api_key else "not configured",
                "weaviate": "operational",
                "knowledge_base_docs": doc_count
            },
            "timestamp": time.time()
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": time.time()
            }
        )


# Root endpoint
@app.get("/", tags=["System"])
async def root():
    """API information"""
    return {
        "name": "Lifelens API",
        "version": "1.0.0",
        "description": "Symptom analysis with Gemini and RAG",
        "endpoints": {
            "health": "/health",
            "analyze": "/api/v1/symptoms/analyze",
            "batch_analyze": "/api/v1/symptoms/batch-analyze",
            "disclaimer": "/api/v1/disclaimer",
            "knowledge": "/api/v1/knowledge/*"
        }
    }


# Symptom Analysis Endpoints
@app.post(
    "/api/v1/symptoms/analyze",
    response_model=SymptomAnalysisResult,
    tags=["Symptom Analysis"],
    summary="Analyze symptoms with Gemini and RAG"
)
async def analyze_symptoms(
    symptom_input: SymptomInput,
    analysis_service: GeminiAnalysisService = Depends(get_analysis_service)
):
    """
    Analyze user symptoms and provide medical information
    
    - **symptoms**: List of symptoms (required, 1-20 items)
    - **age**: Patient age (optional)
    - **sex**: Patient sex (optional: M/F/Other)
    - **duration**: How long symptoms have lasted (optional)
    - **additional_info**: Any additional context (optional)
    
    Returns comprehensive analysis with:
    - Urgency level
    - Possible conditions
    - When to seek care
    - Self-care recommendations
    """
    try:
        logger.info(f"Analyzing symptoms: {symptom_input.symptoms}")
        result = await analysis_service.analyze_symptoms(symptom_input)
        return result
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Symptom analysis failed: {str(e)}"
        )


@app.post(
    "/api/v1/symptoms/batch-analyze",
    response_model=List[SymptomAnalysisResult],
    tags=["Symptom Analysis"],
    summary="Analyze multiple symptom sets in batch"
)
async def batch_analyze_symptoms(
    symptom_inputs: List[SymptomInput],
    analysis_service: GeminiAnalysisService = Depends(get_analysis_service)
):
    """
    Analyze multiple symptom inputs efficiently
    
    Useful for:
    - Processing historical symptom logs
    - Comparing different symptom combinations
    - Bulk analysis for research
    
    Maximum 10 inputs per batch.
    """
    if len(symptom_inputs) > 10:
        raise HTTPException(
            status_code=400,
            detail="Maximum 10 symptom inputs per batch"
        )
    
    try:
        logger.info(f"Batch analyzing {len(symptom_inputs)} symptom sets")
        results = await analysis_service.batch_analyze_symptoms(symptom_inputs)
        return results
    except Exception as e:
        logger.error(f"Batch analysis failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Batch analysis failed: {str(e)}"
        )


@app.get(
    "/api/v1/disclaimer",
    tags=["System"],
    summary="Get medical disclaimer"
)
async def get_disclaimer():
    """Get the medical disclaimer text"""
    return {
        "disclaimer": GeminiAnalysisService.get_disclaimer(),
        "version": "1.0",
        "required": True
    }


# Knowledge Base Management Endpoints
@app.post(
    "/api/v1/knowledge/add",
    tags=["Knowledge Base"],
    summary="Add medical knowledge document"
)
async def add_knowledge(
    document: MedicalKnowledgeDoc,
    rag_service: WeaviateRAGService = Depends(get_rag_service)
):
    """
    Add a medical knowledge document to the RAG system
    
    Requires:
    - condition: Name of medical condition
    - symptoms: List of associated symptoms
    - description: Detailed description
    - severity: mild/moderate/severe/emergency
    - treatment: Treatment recommendations
    - when_to_seek_care: When to see a doctor
    - source: Information source (e.g., "CDC", "Mayo Clinic")
    """
    try:
        doc_id = await rag_service.add_medical_knowledge(document)
        return {
            "success": True,
            "doc_id": doc_id,
            "message": f"Added knowledge for condition: {document.condition}"
        }
    except Exception as e:
        logger.error(f"Failed to add knowledge: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to add knowledge: {str(e)}"
        )


@app.post(
    "/api/v1/knowledge/bulk-add",
    tags=["Knowledge Base"],
    summary="Bulk add medical knowledge documents"
)
async def bulk_add_knowledge(
    documents: List[MedicalKnowledgeDoc],
    rag_service: WeaviateRAGService = Depends(get_rag_service)
):
    """
    Add multiple medical knowledge documents efficiently
    
    Useful for:
    - Initial knowledge base setup
    - Importing from datasets (Kaggle, PhysioNet)
    - Batch updates from medical sources
    
    Maximum 100 documents per request.
    """
    if len(documents) > 100:
        raise HTTPException(
            status_code=400,
            detail="Maximum 100 documents per batch"
        )
    
    try:
        result = await rag_service.bulk_add_knowledge(documents)
        return {
            "success": True,
            "summary": result
        }
    except Exception as e:
        logger.error(f"Bulk add failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Bulk add failed: {str(e)}"
        )


@app.post(
    "/api/v1/knowledge/search",
    response_model=List[RAGResult],
    tags=["Knowledge Base"],
    summary="Search medical knowledge base"
)
async def search_knowledge(
    query: RAGQuery,
    rag_service: WeaviateRAGService = Depends(get_rag_service)
):
    """
    Search the medical knowledge base using semantic similarity
    
    - **query_text**: Natural language query
    - **max_results**: Maximum results to return (1-10)
    - **min_certainty**: Minimum relevance score (0.0-1.0)
    
    Returns relevant medical knowledge documents ranked by similarity.
    """
    try:
        results = await rag_service.search_similar_conditions(query)
        return results
    except Exception as e:
        logger.error(f"Knowledge search failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Search failed: {str(e)}"
        )


@app.get(
    "/api/v1/knowledge/count",
    tags=["Knowledge Base"],
    summary="Get knowledge base document count"
)
async def get_knowledge_count(
    rag_service: WeaviateRAGService = Depends(get_rag_service)
):
    """Get total number of documents in knowledge base"""
    try:
        count = await rag_service.get_document_count()
        return {
            "total_documents": count,
            "status": "ready" if count > 0 else "empty"
        }
    except Exception as e:
        logger.error(f"Failed to get count: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get count: {str(e)}"
        )


@app.delete(
    "/api/v1/knowledge/{doc_id}",
    tags=["Knowledge Base"],
    summary="Delete knowledge document"
)
async def delete_knowledge(
    doc_id: str,
    rag_service: WeaviateRAGService = Depends(get_rag_service)
):
    """Delete a medical knowledge document by ID"""
    try:
        success = await rag_service.delete_document(doc_id)
        if success:
            return {
                "success": True,
                "message": f"Deleted document: {doc_id}"
            }
        else:
            raise HTTPException(
                status_code=404,
                detail=f"Document not found: {doc_id}"
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete: {str(e)}"
        )


# Run with: uvicorn main:app --reload
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.api_reload,
        log_level=settings.log_level.lower()
    )
