"""
Lifelens Backend API
FastAPI application with Gemini and RAG integration
"""
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from typing import List, Any
import time

from models.schemas import (
    SymptomInput,
    SymptomAnalysisResult,
    MedicalKnowledgeDoc,
    RAGQuery,
    RAGResult,
    ErrorResponse,
    MiniMeChatRequest,
    MiniMeChatResponse,
)
from services.gemini_service import get_analysis_service, GeminiAnalysisService
from config.settings import get_settings
from google.genai import types

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get settings
settings = get_settings()


def get_rag_service_dependency() -> Any:
    """Lazy RAG dependency loader so app can run without optional RAG deps."""
    try:
        from services.rag_service import get_rag_service
        return get_rag_service()
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"RAG service unavailable: {e}",
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("Starting Lifelens API...")
    logger.info(f"Gemini API configured: {bool(settings.gemini_api_key)}")
    logger.info(f"Weaviate URL: {settings.weaviate_url}")
    
    # Initialize services
    analysis_service = None
    rag_service = None
    try:
        analysis_service = get_analysis_service()
    except Exception as e:
        logger.error(f"Gemini analysis service initialization failed: {e}")

    try:
        from services.rag_service import get_rag_service
        rag_service = get_rag_service()
    except Exception as e:
        logger.error(f"RAG service initialization failed: {e}")

    if analysis_service or rag_service:
        logger.info("Core services initialized with graceful fallbacks")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Lifelens API...")
    if rag_service is not None:
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
    weaviate_status = "operational"
    doc_count = 0
    rag_error = None

    try:
        from services.rag_service import get_rag_service
        rag_service = get_rag_service()
        doc_count = await rag_service.get_document_count()
    except Exception as e:
        rag_error = str(e)
        weaviate_status = "degraded"

    return {
        "status": "degraded" if rag_error else "healthy",
        "services": {
            "api": "operational",
            "gemini": "operational" if settings.gemini_api_key else "not configured",
            "weaviate": weaviate_status,
            "knowledge_base_docs": doc_count,
            "rag_error": rag_error,
        },
        "timestamp": time.time(),
    }


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
            "minime_chat": "/api/v1/minime/chat",
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


def _build_minime_prompt(chat_input: MiniMeChatRequest) -> str:
    latest_mood = chat_input.latest_mood_label or 'Unknown'
    intensity = chat_input.latest_mood_intensity
    mood_notes = chat_input.latest_mood_notes or 'None'
    recent_moods = chat_input.recent_moods or ['No recent mood logs']
    active_symptoms = chat_input.active_symptoms or ['No active symptoms logged']

    history_lines = []
    for item in chat_input.chat_history[-12:]:
        speaker = 'User' if item.role == 'user' else 'Mini-Me'
        history_lines.append(f"{speaker}: {item.text}")
    history_text = '\n'.join(history_lines) if history_lines else 'No previous messages.'

    if not chat_input.user_message:
        task = (
            'Return ONLY a 2-3 sentence opening coaching suggestion before the user asks anything. '
            'It must be specific to the mood/symptom context and include one small actionable step for today.'
        )
    else:
        task = (
            'Respond to the user message in 3-5 supportive sentences. Build on the logged mood/symptoms. '
            'Give concrete next-step guidance and keep tone warm, practical, and non-judgmental. '
            'Do not claim a diagnosis.'
        )

    return f"""You are Mini-Me, a friendly personal wellness coach in the LifeLens app.

{task}

Current context:
- Latest mood: {latest_mood}
- Mood intensity: {intensity if intensity is not None else 'unknown'} / 5
- Mood notes: {mood_notes}
- Recent moods: {' | '.join(recent_moods)}
- Active symptoms: {' | '.join(active_symptoms)}

Conversation so far:
{history_text}

Current user message:
{chat_input.user_message or '[none: opening suggestion requested]'}

Rules:
- Keep response concise and relevant to current logs.
- If symptoms suggest possible risk, recommend professional care calmly.
- Never output markdown lists unless asked.
- Return plain text only.
"""


def _build_opening_fallback(chat_input: MiniMeChatRequest) -> str:
    mood = chat_input.latest_mood_label or 'neutral'
    symptoms = ', '.join(chat_input.active_symptoms[:2]) if chat_input.active_symptoms else ''
    if symptoms:
        return (
            f"Based on your recent {mood} mood and symptoms ({symptoms}), start with one gentle reset: "
            "drink water, take 5 slow breaths, and do a 10-minute low-stress task. "
            "After that, check if your symptoms are easing."
        )
    return (
        f"Your current mood trend looks {mood}. Start with one small win: a 5-minute pause, "
        "name your top priority, and complete just the first step."
    )


def _build_reply_fallback(chat_input: MiniMeChatRequest) -> str:
    if not chat_input.user_message:
        return _build_opening_fallback(chat_input)

    mood = chat_input.latest_mood_label or 'neutral'
    symptoms = ', '.join(chat_input.active_symptoms[:3])
    if symptoms:
        return (
            f"I hear you. With your recent {mood} mood and symptoms ({symptoms}), "
            "let us keep your next step simple: choose one low-effort action now, "
            "then reassess how you feel in 20 minutes. If symptoms worsen or feel alarming, seek medical care."
        )

    return (
        f"I hear you. With your recent {mood} mood trend, pick one concrete next step you can finish in 10 minutes, "
        "then send me what changed and I will help you adjust."
    )


@app.post(
    "/api/v1/minime/chat",
    response_model=MiniMeChatResponse,
    tags=["Mini-Me"],
    summary="Generate context-aware Mini-Me chat responses"
)
async def minime_chat(
    chat_input: MiniMeChatRequest,
    analysis_service: GeminiAnalysisService = Depends(get_analysis_service)
):
    """Generate Mini-Me response grounded in logged mood and symptom context."""
    is_opening_request = not bool(chat_input.user_message.strip())

    try:
        prompt = _build_minime_prompt(chat_input)
        response = analysis_service.client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.55,
                top_p=0.9,
                top_k=40,
                max_output_tokens=500,
                candidate_count=1,
            ),
        )

        text = (response.text or '').strip()
        if not text:
            raise ValueError('Empty response from Gemini')

        return MiniMeChatResponse(
            opening_suggestion=text if is_opening_request else '',
            reply=text,
            source='gemini',
        )
    except Exception as e:
        logger.warning(f"Mini-Me chat fallback used: {e}")
        fallback_opening = _build_opening_fallback(chat_input)
        return MiniMeChatResponse(
            opening_suggestion=fallback_opening if is_opening_request else '',
            reply=_build_reply_fallback(chat_input),
            source='fallback',
        )


# Knowledge Base Management Endpoints
@app.post(
    "/api/v1/knowledge/add",
    tags=["Knowledge Base"],
    summary="Add medical knowledge document"
)
async def add_knowledge(
    document: MedicalKnowledgeDoc,
    rag_service: Any = Depends(get_rag_service_dependency)
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
    rag_service: Any = Depends(get_rag_service_dependency)
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
    rag_service: Any = Depends(get_rag_service_dependency)
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
    rag_service: Any = Depends(get_rag_service_dependency)
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
    rag_service: Any = Depends(get_rag_service_dependency)
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
