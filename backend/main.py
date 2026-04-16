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
import json
import asyncio
import re

from models.schemas import (
    SymptomInput,
    SymptomAnalysisResult,
    MedicalKnowledgeDoc,
    RAGQuery,
    RAGResult,
    ErrorResponse,
    MiniMeChatRequest,
    MiniMeChatResponse,
    MiniMeMemoryCompileResponse,
    MiniMeMemoryDiff,
    MiniMeMemoryState,
    MiniMeSuggestionsRequest,
    MiniMeSuggestionsResponse,
    MiniMeSuggestionItem,
    MiniMeExerciseRecommendationRequest,
    MiniMeExerciseRecommendationResponse,
    MiniMeExerciseRecommendationItem,
    IntelligenceAnalyzeRequest,
    IntelligenceAnalyzeResponse,
)
from services.gemini_service import get_analysis_service, GeminiAnalysisService
from services.intelligence import analyze_logs_in_order
from services.intelligence_policy import get_intelligence_policy
from services.memory_compiler import compile_minime_memory_with_diff
from services.memory_logging import log_memory_event
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

    # Keep startup fast: heavy services initialize lazily on first request.
    try:
        policy = get_intelligence_policy()
        logger.info(f"Intelligence policy loaded: version={policy.get('version', 'unknown')}")
    except Exception as e:
        logger.error(f"Intelligence policy initialization failed: {e}")

    logger.info("Core services set to lazy initialization with graceful fallbacks")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Lifelens API...")
    try:
        from services.rag_service import _rag_service
        if _rag_service is not None:
            _rag_service.close()
    except Exception:
        pass


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
    payload = ErrorResponse(
        error=exc.detail,
        detail=str(exc)
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=payload.model_dump(mode="json")
    )


@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    payload = ErrorResponse(
        error="Internal server error",
        detail=str(exc)
    )
    return JSONResponse(
        status_code=500,
        content=payload.model_dump(mode="json")
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
        rag_service = await asyncio.wait_for(
            asyncio.to_thread(get_rag_service), timeout=5.0
        )
        doc_count = await asyncio.wait_for(rag_service.get_document_count(), timeout=5.0)
    except TimeoutError:
        rag_error = "RAG health check timed out"
        weaviate_status = "degraded"
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
            "intelligence_analyze": "/api/v1/intelligence/analyze",
            "minime_chat": "/api/v1/minime/chat",
            "minime_suggestions": "/api/v1/minime/suggestions",
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


def _build_minime_prompt(chat_input: MiniMeChatRequest, memory_state: MiniMeMemoryState) -> str:
    summary_context, context_block, persona_style = _resolve_companion_context(chat_input, memory_state)

    history_lines = []
    for item in chat_input.chat_history[-4:]:
        speaker = 'User' if item.role == 'user' else 'Mini-Me'
        history_lines.append(f"{speaker}: {item.text}")
    history_text = '\n'.join(history_lines) if history_lines else 'No previous messages.'

    if not chat_input.user_message:
        task = (
            'Return ONLY a 2-3 sentence opening coaching suggestion before the user asks anything. '
            'It must be specific to the summarized context and include one small actionable step for today.'
        )
    else:
        task = (
            'Respond to the user message in 3-5 supportive sentences. Build on the summarized context. '
            'Give concrete next-step guidance and keep tone warm, practical, and non-judgmental. '
            'Do not claim a diagnosis.'
        )

    return f"""You are Mini-Me, a friendly personal wellness coach in the LifeLens app.

{task}
{persona_style}
Use this context block as truth for this turn:
{context_block}

Conversation so far:
{history_text}

Current user message:
{chat_input.user_message or '[none: opening suggestion requested]'}

Rules:
- Your response should be driven by the context block above.
- If an alert is present, gently check in — do not alarm, but ensure the user feels supported.
- Keep response concise and relevant to current logs.
- If the summary indicates possible risk, recommend professional care calmly.
- Weave behavioral signals naturally into your guidance — never expose internal analysis or scores to the user.
- Never output markdown lists unless asked.
- Return plain text only.
"""


def _sanitize_chat_summary_context(summary_context: str | None, max_words: int = 80) -> str:
    text = (summary_context or '').strip()
    if not text:
        return 'No summary context available.'

    text = ' '.join(text.split())
    text = re.sub(
        r"\b(?:sleep_avg_3|mood_avg_3|sleep_slope|mood_slope|risk|trend)\s*=\s*-?\d+(?:\.\d+)?\b",
        '',
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(r"\s+", ' ', text).strip(' .,')

    words = [w for w in text.split(' ') if w]
    if len(words) > max_words:
        text = ' '.join(words[:max_words]).rstrip(' ,') + '.'

    return text or 'No summary context available.'


def _build_companion_context_block(
    chat_input: MiniMeChatRequest,
    memory_state: MiniMeMemoryState,
    summary_context: str,
) -> str:
    risk_line = _memory_state_to_risk_line(memory_state)
    condition_text = ', '.join([c for c in chat_input.condition_labels if c]) or 'None reported'

    symptom_values = [s.strip() for s in chat_input.active_symptoms if s.strip()]
    symptoms_text = ', '.join(symptom_values) if symptom_values else 'None reported'

    step_chunks = []
    for symptom in symptom_values[:4]:
        step_text = (chat_input.symptom_steps or {}).get(symptom, '').strip()
        if not step_text:
            continue
        step_chunks.append(f"For {symptom} - {step_text}.")
    symptom_steps_text = ' '.join(step_chunks) if step_chunks else 'N/A'

    mood = chat_input.latest_mood_label or 'Unknown'
    general = [g.strip() for g in chat_input.general_steps if g.strip()]
    general_text = ' '.join(general[:4]) if general else 'Drink water. Take a short breathing pause. Reassess in 20 minutes.'

    return (
        f"[CONTEXT: {risk_line}\n"
        f"CONDITION: {condition_text}.\n"
        f"SYMPTOMS: {symptoms_text}.\n"
        f"SYMPTOM STEPS: {symptom_steps_text}\n"
        f"MOOD: {mood}.\n"
        f"GENERAL STEPS: {general_text}\n"
        f"SUMMARY: {summary_context}]"
    )


def _memory_state_to_risk_line(memory_state: MiniMeMemoryState) -> str:
    quick_track = memory_state.quick_track or {}
    alert = (quick_track.get('alert') or '').strip()
    risk = (memory_state.risk or 'low').upper()

    if memory_state.risk == 'high':
        if alert:
            return f"RISK: {risk}. Alert: {alert}"
        return f"RISK: {risk}. Trend may be worsening and needs close support."
    if memory_state.risk == 'medium':
        return f"RISK: {risk}. Trends need active monitoring."
    return f"RISK: {risk}."


def _resolve_minime_persona_style(summary_context: str, risk_level: str, intelligence_tier: str | None) -> str:
    text = (summary_context or "").lower()
    tier = (intelligence_tier or "").strip().lower()
    risk = (risk_level or "low").strip().lower()

    declining_markers = (
        "declin",
        "worsen",
        "downward",
        "fatigue risk",
        "high risk",
        "alert",
    )
    improving_markers = (
        "improv",
        "recover",
        "stable",
        "momentum",
    )

    if risk == "high" or tier == "high" or any(marker in text for marker in declining_markers):
        return (
            "Persona mode: Warm-Supportive. Start with empathy and emotional validation. "
            "Use gentle, low-pressure guidance and safety-aware language when risk appears elevated."
        )

    if risk == "medium" or tier == "medium":
        return (
            "Persona mode: Steady-Coaching. Be calm and practical, balancing reassurance with one concrete next step."
        )

    if any(marker in text for marker in improving_markers):
        return (
            "Persona mode: Encouraging-Progress. Reinforce wins without overhyping, then suggest one sustainable next action."
        )

    return "Persona mode: Neutral-Coaching. Keep tone supportive, clear, and grounded in the current summary context."


def _resolve_companion_context(
    chat_input: MiniMeChatRequest,
    memory_state: MiniMeMemoryState,
) -> tuple[str, str, str]:
    summary_context = _sanitize_chat_summary_context(chat_input.summary_context)
    context_block = _build_companion_context_block(chat_input, memory_state, summary_context)
    persona_style = _resolve_minime_persona_style(
        summary_context=summary_context,
        risk_level=memory_state.risk,
        intelligence_tier=chat_input.intelligence_tier,
    )
    return summary_context, context_block, persona_style


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


def _suggestions_to_chat_request(suggestion_input: MiniMeSuggestionsRequest) -> MiniMeChatRequest:
    return MiniMeChatRequest(
        user_message='',
        latest_mood_label=suggestion_input.latest_mood_label,
        latest_mood_intensity=suggestion_input.latest_mood_intensity,
        latest_mood_notes=suggestion_input.latest_mood_notes,
        summary_context=suggestion_input.summary_context,
        recent_moods=suggestion_input.recent_moods,
        active_symptoms=suggestion_input.active_symptoms,
        condition_labels=suggestion_input.condition_labels,
        symptom_steps=suggestion_input.symptom_steps,
        general_steps=suggestion_input.general_steps,
        chat_history=suggestion_input.chat_history,
        user_id_hash=suggestion_input.user_id_hash,
        intelligence_tier=suggestion_input.intelligence_tier,
        intelligence_phase=suggestion_input.intelligence_phase,
        intelligence_insights=suggestion_input.intelligence_insights,
        intelligence_actions=suggestion_input.intelligence_actions,
        intelligence_alert=suggestion_input.intelligence_alert,
        intelligence_risk_score=suggestion_input.intelligence_risk_score,
        intelligence_confidence=suggestion_input.intelligence_confidence,
        intelligence_state=suggestion_input.intelligence_state,
        previous_memory=suggestion_input.previous_memory,
    )


def _exercise_to_chat_request(recommendation_input: MiniMeExerciseRecommendationRequest) -> MiniMeChatRequest:
    return MiniMeChatRequest(
        user_message='',
        latest_mood_label=recommendation_input.latest_mood_label,
        latest_mood_intensity=recommendation_input.latest_mood_intensity,
        latest_mood_notes=recommendation_input.latest_mood_notes,
        summary_context=recommendation_input.summary_context,
        recent_moods=recommendation_input.recent_moods,
        active_symptoms=recommendation_input.active_symptoms,
        condition_labels=recommendation_input.condition_labels,
        symptom_steps=recommendation_input.symptom_steps,
        general_steps=recommendation_input.general_steps,
        chat_history=recommendation_input.chat_history,
        user_id_hash=recommendation_input.user_id_hash,
        intelligence_tier=recommendation_input.intelligence_tier,
        intelligence_phase=recommendation_input.intelligence_phase,
        intelligence_insights=recommendation_input.intelligence_insights,
        intelligence_actions=recommendation_input.intelligence_actions,
        intelligence_alert=recommendation_input.intelligence_alert,
        intelligence_risk_score=recommendation_input.intelligence_risk_score,
        intelligence_confidence=recommendation_input.intelligence_confidence,
        intelligence_state=recommendation_input.intelligence_state,
        previous_memory=recommendation_input.previous_memory,
    )


def _build_suggestions_prompt(
    suggestion_input: MiniMeSuggestionsRequest,
    context_block: str,
    persona_style: str,
) -> str:

    history_lines = []
    for item in suggestion_input.chat_history[-12:]:
        speaker = 'User' if item.role == 'user' else 'Mini-Me'
        history_lines.append(f"{speaker}: {item.text}")
    history_text = '\n'.join(history_lines) if history_lines else 'No previous messages.'

    return f"""You are Mini-Me, a supportive wellness coach in the LifeLens app.

Write 3 UNIQUE daily suggestions for this specific user based on their summarized context and chat history.
{persona_style}

Requirements:
- Each suggestion must feel freshly written for this user's context.
- Do not repeat or quote prior Mini-Me replies verbatim.
- Use clear, casual, easy-to-understand language.
- Each suggestion should be practical, specific, and warm.
- Avoid medical claims or diagnosis.
- Use the context block below as source-of-truth.
- Do not use markdown.
- Return valid JSON only.

Return exactly this JSON shape:
{{
  "suggestions": [
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}},
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}},
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}}
  ]
}}

Current context:
{context_block}

Mini-Me conversation history:
{history_text}
"""


def _build_suggestions_fallback(
    suggestion_input: MiniMeSuggestionsRequest,
    memory_state: MiniMeMemoryState | None = None,
) -> MiniMeSuggestionsResponse:
    mood = (suggestion_input.latest_mood_label or 'neutral').lower()
    summary_context = (suggestion_input.summary_context or '').lower()
    risk = (memory_state.risk if memory_state else 'low').lower()
    symptoms = ''
    for line in summary_context.split('\n'):
        trimmed = line.strip()
        if trimmed.lower().startswith('symptom summary:'):
            symptoms = trimmed[len('Symptom summary:'):].strip()
            break

    suggestions = [
        MiniMeSuggestionItem(
            action=(
                f"Keep today simple and choose one low-effort habit that supports your {mood} baseline."
                if risk != 'high'
                else f"Keep today very gentle and choose one stabilizing step that supports your {mood} baseline."
            ),
            reason=(
                "Your recent logs suggest consistency will help more than doing a lot at once."
                if risk != 'high'
                else "Risk signals look elevated, so a small stabilizing action is safer than a big plan right now."
            ),
        ),
        MiniMeSuggestionItem(
            action="Notice what happens right before your next mood shift and log one short detail.",
            reason="A clearer trigger makes Mini-Me's next suggestion more personal.",
        ),
        MiniMeSuggestionItem(
            action=(
                "Give yourself one short reset block today."
                if not symptoms
                else f"Work around your current symptoms ({symptoms}) with one low-effort reset today."
            ),
            reason="Recent context suggests a gentle next step is more useful than a big plan.",
        ),
    ]

    return MiniMeSuggestionsResponse(
        suggestions=suggestions,
        source='fallback',
    )


def _build_exercise_recommendations_prompt(
    recommendation_input: MiniMeExerciseRecommendationRequest,
    context_block: str,
    persona_style: str,
) -> str:
    history_lines = []
    for item in recommendation_input.chat_history[-12:]:
        speaker = 'User' if item.role == 'user' else 'Mini-Me'
        history_lines.append(f"{speaker}: {item.text}")
    history_text = '\n'.join(history_lines) if history_lines else 'No previous messages.'

    exercise_lines = []
    for exercise in recommendation_input.exercises:
        summary = f"{exercise.id} | {exercise.name} | {exercise.type} | {exercise.muscle} | {exercise.difficulty}"
        if exercise.description:
            summary += f" | {exercise.description}"
        exercise_lines.append(summary)

    return f"""You are Mini-Me, a supportive wellness coach in the LifeLens app.

Choose the BEST 3 exercises for this user right now from the provided catalog.
{persona_style}

Requirements:
- Only recommend exercises from the provided catalog.
- Match the user's context block and Mini-Me context.
- Prefer realistic, low-friction choices when the user seems stressed, low-energy, or physically uncomfortable.
- Avoid recommending intense exercise when the summarized context suggests caution.
- Use clear, casual, easy-to-understand language.
- Do not use markdown.
- Return valid JSON only.

Return exactly this JSON shape:
{{
  "headline": "One short sentence describing the overall recommendation angle.",
  "recommendations": [
    {{"exercise_id": "catalog id", "focus": "Short why-this-now label", "reason": "One short reason tied to the user's context."}},
    {{"exercise_id": "catalog id", "focus": "Short why-this-now label", "reason": "One short reason tied to the user's context."}},
    {{"exercise_id": "catalog id", "focus": "Short why-this-now label", "reason": "One short reason tied to the user's context."}}
  ]
}}

Current context:
{context_block}

Mini-Me conversation history:
{history_text}

Available exercise catalog:
{chr(10).join(exercise_lines)}
"""


def _build_exercise_recommendations_fallback(
    recommendation_input: MiniMeExerciseRecommendationRequest,
    memory_state: MiniMeMemoryState | None = None,
) -> MiniMeExerciseRecommendationResponse:
    exercises = recommendation_input.exercises
    mood = (recommendation_input.latest_mood_label or 'neutral').lower()
    risk = (memory_state.risk if memory_state else 'low').lower()
    summary_context = (recommendation_input.summary_context or '').lower()
    symptoms_text = summary_context
    cautious = any(
        word in symptoms_text
        for word in ['pain', 'injury', 'dizzy', 'fatigue', 'tired', 'headache']
    ) or (recommendation_input.latest_mood_intensity or 0) >= 4 or risk in {'medium', 'high'}

    def score(exercise):
        score_value = 0
        exercise_type = exercise.type.lower()
        difficulty = exercise.difficulty.lower()

        if cautious:
            if exercise_type in {'mobility', 'stretching', 'yoga', 'walking'}:
                score_value += 4
            if difficulty == 'beginner':
                score_value += 3
        elif mood in {'anxious', 'stressed', 'overwhelmed'}:
            if exercise_type in {'mobility', 'stretching', 'yoga', 'pilates'}:
                score_value += 4
            if difficulty == 'beginner':
                score_value += 2
        elif mood in {'sad', 'low', 'down'}:
            if exercise_type in {'cardio', 'walking', 'dance', 'strength'}:
                score_value += 4
        else:
            if exercise_type in {'strength', 'cardio', 'mobility'}:
                score_value += 3
        return score_value

    ranked = sorted(exercises, key=score, reverse=True)[:3]
    if not ranked:
        ranked = exercises[:3]

    recommendations = [
        MiniMeExerciseRecommendationItem(
            exercise_id=exercise.id,
            focus='Gentle fit' if cautious else 'Good next step',
            reason=(
                'This looks easier to start right now and should feel manageable.'
                if cautious
                else 'This matches your recent mood pattern without making the next step feel too big.'
            ),
        )
        for exercise in ranked
    ]

    return MiniMeExerciseRecommendationResponse(
        headline=(
            'Mini-Me picked a few gentle exercises that look realistic for how you have been feeling.'
            if cautious
            else 'Mini-Me picked a few exercises that look realistic for how you have been feeling.'
        ),
        recommendations=recommendations,
        source='fallback',
    )


@app.post(
    "/api/v1/intelligence/analyze",
    response_model=IntelligenceAnalyzeResponse,
    tags=["Intelligence"],
    summary="Analyze behavior logs into state, insights, and actions"
)
async def intelligence_analyze(payload: IntelligenceAnalyzeRequest):
    """Compute deterministic statistical state, forecasts, anomalies, and actions."""
    logs = {
        "sleep": payload.sleep,
        "mood": payload.mood,
        "exercise": payload.exercise,
        "symptom_count": payload.symptom_count,
    }
    try:
        return await analyze_logs_in_order(
            logs,
            include_gemini_message=payload.include_gemini_message,
        )
    except Exception as e:
        logger.error(f"Intelligence analyze failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Intelligence analysis failed: {str(e)}"
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
    memory_state, memory_diff, _validation_passed = compile_minime_memory_with_diff(chat_input)
    try:
        log_memory_event(chat_input, memory_state, memory_diff, _validation_passed)
    except Exception as e:
        logger.warning(f"Mini-Me memory logging failed (chat): {e}")

    try:
        prompt = _build_minime_prompt(chat_input, memory_state)
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
            memory_state=memory_state,
        )
    except Exception as e:
        logger.warning(f"Mini-Me chat fallback used: {e}")
        fallback_opening = _build_opening_fallback(chat_input)
        return MiniMeChatResponse(
            opening_suggestion=fallback_opening if is_opening_request else '',
            reply=_build_reply_fallback(chat_input),
            source='fallback',
            memory_state=memory_state,
        )


@app.post(
    "/api/v1/minime/memory",
    response_model=MiniMeMemoryCompileResponse,
    tags=["Mini-Me"],
    summary="Compile Mini-Me structured memory"
)
async def compile_minime_memory_state(chat_input: MiniMeChatRequest):
    """Compile deterministic memory JSON from chat history and quick-track context."""
    memory_state, memory_diff, validation_passed = compile_minime_memory_with_diff(chat_input)
    try:
        log_memory_event(chat_input, memory_state, memory_diff, validation_passed)
    except Exception as e:
        logger.warning(f"Mini-Me memory logging failed (memory endpoint): {e}")
    return MiniMeMemoryCompileResponse(
        memory_state=memory_state,
        validation_passed=validation_passed,
    )


@app.post(
    "/api/v1/minime/suggestions",
    response_model=MiniMeSuggestionsResponse,
    tags=["Mini-Me"],
    summary="Generate unique Mini-Me daily suggestions"
)
async def minime_suggestions(
    suggestion_input: MiniMeSuggestionsRequest,
    analysis_service: GeminiAnalysisService = Depends(get_analysis_service)
):
    """Generate user-specific Mini-Me suggestions from logs and chat history."""
    chat_context = _suggestions_to_chat_request(suggestion_input)
    memory_state, memory_diff, validation_passed = compile_minime_memory_with_diff(chat_context)
    try:
        log_memory_event(chat_context, memory_state, memory_diff, validation_passed)
    except Exception as e:
        logger.warning(f"Mini-Me memory logging failed (suggestions endpoint): {e}")

    _summary_context, context_block, persona_style = _resolve_companion_context(chat_context, memory_state)
    try:
        prompt = _build_suggestions_prompt(suggestion_input, context_block, persona_style)
        response = analysis_service.client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.9,
                top_p=0.95,
                top_k=40,
                max_output_tokens=700,
                candidate_count=1,
                response_mime_type='application/json',
            ),
        )

        text = (response.text or '').strip()
        if not text:
            raise ValueError('Empty response from Gemini')

        decoded = json.loads(text)
        raw_suggestions = decoded.get('suggestions', [])
        suggestions = [
            MiniMeSuggestionItem(
                action=(item.get('action') or '').strip(),
                reason=(item.get('reason') or '').strip(),
            )
            for item in raw_suggestions[:3]
            if (item.get('action') or '').strip() and (item.get('reason') or '').strip()
        ]

        if not suggestions:
            raise ValueError('No valid suggestions returned from Gemini')

        return MiniMeSuggestionsResponse(
            suggestions=suggestions,
            source='gemini',
        )
    except Exception as e:
        logger.warning(f"Mini-Me suggestions fallback used: {e}")
        return _build_suggestions_fallback(suggestion_input, memory_state)


@app.post(
    "/api/v1/minime/exercise-recommendations",
    response_model=MiniMeExerciseRecommendationResponse,
    tags=["Mini-Me"],
    summary="Generate Mini-Me exercise recommendations"
)
async def minime_exercise_recommendations(
    recommendation_input: MiniMeExerciseRecommendationRequest,
    analysis_service: GeminiAnalysisService = Depends(get_analysis_service)
):
    """Generate exercise picks grounded in mood logs, symptoms, and chat history."""
    chat_context = _exercise_to_chat_request(recommendation_input)
    memory_state, memory_diff, validation_passed = compile_minime_memory_with_diff(chat_context)
    try:
        log_memory_event(chat_context, memory_state, memory_diff, validation_passed)
    except Exception as e:
        logger.warning(f"Mini-Me memory logging failed (exercise endpoint): {e}")

    _summary_context, context_block, persona_style = _resolve_companion_context(chat_context, memory_state)
    try:
        prompt = _build_exercise_recommendations_prompt(recommendation_input, context_block, persona_style)
        response = analysis_service.client.models.generate_content(
            model='gemini-2.5-flash-lite',
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.75,
                top_p=0.95,
                top_k=40,
                max_output_tokens=800,
                candidate_count=1,
                response_mime_type='application/json',
            ),
        )

        text = (response.text or '').strip()
        if not text:
            raise ValueError('Empty response from Gemini')

        decoded = json.loads(text)
        raw_recommendations = decoded.get('recommendations', [])
        catalog_ids = {exercise.id for exercise in recommendation_input.exercises}
        recommendations = [
            MiniMeExerciseRecommendationItem(
                exercise_id=(item.get('exercise_id') or '').strip(),
                focus=(item.get('focus') or '').strip(),
                reason=(item.get('reason') or '').strip(),
            )
            for item in raw_recommendations[:3]
            if (item.get('exercise_id') or '').strip() in catalog_ids
            and (item.get('focus') or '').strip()
            and (item.get('reason') or '').strip()
        ]

        if not recommendations:
            raise ValueError('No valid exercise recommendations returned from Gemini')

        headline = (decoded.get('headline') or '').strip()
        if not headline:
            headline = 'Mini-Me picked a few exercises based on how you have been feeling lately.'

        return MiniMeExerciseRecommendationResponse(
            headline=headline,
            recommendations=recommendations,
            source='gemini',
        )
    except Exception as e:
        logger.warning(f"Mini-Me exercise recommendation fallback used: {e}")
        return _build_exercise_recommendations_fallback(recommendation_input, memory_state)


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
