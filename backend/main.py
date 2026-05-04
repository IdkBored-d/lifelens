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


def _is_gemini_enabled() -> bool:
    """Gemini is enabled only when an API key is configured."""
    return bool(settings.gemini_api_key)


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
            "gemini": "operational" if _is_gemini_enabled() else "not configured",
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
    latest_mood = chat_input.latest_mood_label or 'Unknown'
    intensity = chat_input.latest_mood_intensity
    mood_notes = chat_input.latest_mood_notes or 'None'
    recent_moods = chat_input.recent_moods or ['No recent mood logs']
    summary_context = (chat_input.summary_context or '').strip() or 'No summary context available.'

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

    # Build intelligence block — PRIMARY context when available
    intel_block = ''
    if chat_input.intelligence_tier:
        state = chat_input.intelligence_state or {}
        state_flags = [k.replace('_', ' ') for k, v in state.items() if v]
        insights_text = ' | '.join(chat_input.intelligence_insights) if chat_input.intelligence_insights else 'none'
        actions_text = ', '.join(
            a.replace('_', ' ') for a in chat_input.intelligence_actions
        ) if chat_input.intelligence_actions else 'none'
        alert_text = chat_input.intelligence_alert or 'none'
        intel_block = f"""
Behavioral intelligence (supporting context only — never mention this analysis to the user):
- Active flags: {', '.join(state_flags) if state_flags else 'none'}
- Key patterns: {insights_text}
- Suggested focus areas: {actions_text}
- Alert: {alert_text}
"""

    return f"""You are Mini-Me, a friendly personal wellness coach in the LifeLens app.

{task}
{intel_block}
Memory context (PRIMARY truth for this turn):
{_memory_state_to_structured_context(memory_state)}

Supporting context:
- Summary context (primary source from the summarization layer):
{summary_context}
- Latest mood: {latest_mood}
- Mood intensity: {intensity if intensity is not None else 'unknown'} / 5
- Mood notes: {mood_notes}
- Recent moods: {' | '.join(recent_moods)}

Conversation so far:
{history_text}

Current user message:
{chat_input.user_message or '[none: opening suggestion requested]'}

Rules:
- Your response should be driven by the memory state and summary context above.
- If an alert is present, gently check in — do not alarm, but ensure the user feels supported.
- Keep response concise and relevant to current logs.
- If the summary context suggests possible risk, recommend professional care calmly.
- Weave behavioral signals naturally into your guidance — never expose internal analysis or scores to the user.
- Never output markdown lists unless asked.
- Return plain text only.
"""


def _memory_state_to_natural_context(memory_state: MiniMeMemoryState) -> str:
    quick_track = memory_state.quick_track or {}

    confidence = quick_track.get("confidence")
    state_flags = quick_track.get("state_flags") or []
    actions = quick_track.get("actions") or []

    key_points_text = "; ".join(memory_state.key_points[:4]) if memory_state.key_points else "none"
    flags_text = ", ".join(str(item) for item in state_flags) if state_flags else "none"
    actions_text = ", ".join(str(item).replace("_", " ") for item in actions) if actions else "none"

    if isinstance(confidence, (int, float)):
        confidence_text = f"{confidence:.2f}"
    else:
        confidence_text = "unknown"

    return (
        f"Summary: {memory_state.summary}\n"
        f"Mood state: {memory_state.mood_state}. Risk level: {memory_state.risk}.\n"
        f"Confidence: {confidence_text}.\n"
        f"Key points: {key_points_text}.\n"
        f"Active state flags: {flags_text}. Suggested focus actions: {actions_text}."
    )


def _memory_state_to_structured_context(memory_state: MiniMeMemoryState) -> str:
    """Build a structured context card from memory state for chat prompt."""
    quick_track = memory_state.quick_track or {}
    
    # Extract risk context
    risk_level = memory_state.risk.upper()
    alert = (quick_track.get("alert") or "").strip()
    actions = quick_track.get("actions") or []
    
    # Build context line with actionable guidance
    if memory_state.risk == "high":
        risk_context = f"RISK: {risk_level}."
        if alert:
            risk_context += f" Alert: {alert}"
        else:
            risk_context += " Consider reaching out to someone you trust or a professional."
    elif memory_state.risk == "medium":
        risk_context = f"RISK: {risk_level}. Stay mindful of patterns."
    else:
        risk_context = f"RISK: {risk_level}."
    
    # Extract mood and symptoms from key_points
    mood_label = "Unknown"
    symptoms_list = []
    
    for key_point in (memory_state.key_points or []):
        if key_point.startswith("mood label:"):
            mood_label = key_point.replace("mood label:", "").strip().title()
        if key_point.startswith("symptoms reported:"):
            symptoms_str = key_point.replace("symptoms reported:", "").strip()
            symptoms_list = [s.strip().title() for s in symptoms_str.split(",") if s.strip()]
    
    symptoms_text = ", ".join(symptoms_list) if symptoms_list else "None"
    
    # Build structured card
    return (
        f"[CONTEXT: {risk_context}\n"
        f"SYMPTOMS: {symptoms_text}.\n"
        f"MOOD: {mood_label}.\n"
        f"SUMMARY: {memory_state.summary}]"
    )


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


def _extract_last_assistant_step(chat_input: MiniMeChatRequest) -> str:
    """Extract the most recent assistant 'Next step' from chat history."""
    for item in reversed(chat_input.chat_history[-12:]):
        if item.role != 'assistant':
            continue
        text = (item.text or '').strip()
        if not text:
            continue

        lowered = text.lower()
        marker = 'next step:'
        idx = lowered.rfind(marker)
        if idx == -1:
            continue

        step = text[idx + len(marker):].strip()
        if not step:
            continue

        # Keep only the first sentence/chunk so follow-up stays focused.
        for sep in ['. ', '\n', ' If ', ' if ']:
            if sep in step:
                step = step.split(sep, 1)[0].strip()
                break
        return step.rstrip('.').strip()

    return ''


def _build_reply_fallback(chat_input: MiniMeChatRequest) -> str:
    if not chat_input.user_message:
        return _build_opening_fallback(chat_input)

    text = chat_input.user_message.strip()
    lower = text.lower()
    mood = (chat_input.latest_mood_label or 'neutral').lower()
    symptoms = ', '.join(chat_input.active_symptoms[:3])
    intensity = chat_input.latest_mood_intensity
    last_step = _extract_last_assistant_step(chat_input)

    recent_user_turns = [
        item.text.strip()
        for item in chat_input.chat_history[-6:]
        if item.role == 'user' and item.text.strip()
    ]
    last_turn = recent_user_turns[-1] if recent_user_turns else ''

    def _compose(reason: str, step: str, safety: str = '', ask_update: bool = True) -> str:
        prefix = f"I hear you. {reason}"
        tail = f" Next step: {step}"
        if safety:
            tail += f" {safety}"
        if ask_update and last_turn:
            tail += " If that does not help, tell me what changed and I will adjust the plan."
        return prefix + tail

    def _mentions(*tokens: str) -> bool:
        return any(token in lower for token in tokens)

    # lightweight conversational tone controls
    greeting = _mentions('hi', 'hello', 'hey', 'good morning', 'good evening') and len(lower.split()) <= 6
    gratitude = _mentions('thanks', 'thank you', 'appreciate it')
    confusion = _mentions('dont understand', "don't understand", 'confused', 'not sure', 'unclear', 'what do you mean')
    asks_why = _mentions('why', 'how come')
    asks_plan = _mentions('plan', 'routine', 'what should i do', 'help me', 'what now')
    asks_next = _mentions('what next', 'next?', 'what should i do next')
    asks_repeat = _mentions('repeat', 'say that again', 'can you repeat', 'summarize')

    # recognize quick acknowledgements for smoother back-and-forth
    if greeting:
        return (
            "Hi, I am with you. Tell me what feels hardest right now and I will give you one clear next step "
            "you can do in the next 10 minutes."
        )

    if gratitude:
        return (
            "You are welcome. If you want, send a quick update in one line: what you tried and how it felt from 0-10, "
            "and I will tailor the next step."
        )

    if confusion:
        if last_step:
            return (
                f"Good call asking for clarity. The last step in plain terms was: {last_step}. "
                "If that feels too big, do a 2-minute version first."
            )
        return (
            "Thanks for saying that. In plain terms, pick one tiny action you can finish in 2-5 minutes, "
            "then tell me what happened and I will refine it."
        )

    high_strain = (intensity is not None and intensity >= 4) or mood in {'fear', 'anger', 'sadness'}

    completion_positive = any(
        token in lower
        for token in [
            'i did', 'done', 'completed', 'finished', 'worked',
            'i followed', 'i did it', 'that helped', 'it helped'
        ]
    )
    completion_negative = any(
        token in lower
        for token in [
            "didn't", 'did not', 'could not', "couldn't", 'not helping',
            'didnt help', 'doesnt help', 'too hard', 'not working'
        ]
    )

    if completion_negative and last_step:
        return _compose(
            "Thanks for telling me that the previous step did not land.",
            "Scale down to a 2-minute version of the same goal and remove friction (set a timer, one location, one action only).",
        )

    if completion_positive and last_step:
        if symptoms:
            return _compose(
                "Nice follow-through on that step.",
                "Keep the same direction and add one gentle check-in in 1 hour: symptom intensity 0-10 plus energy level.",
                "If symptoms escalate or become alarming, seek medical care promptly.",
            )
        return _compose(
            "Great job doing the last step.",
            "Use a progression: repeat it once more today, then add one small challenge (5-10 extra minutes or one extra action).",
        )

    if asks_repeat and last_step:
        return (
            f"Short version: {last_step}. "
            "Start there, then message me with what changed so I can choose the next move."
        )

    if asks_why:
        if symptoms:
            return (
                f"Because your recent mood is {mood} and you reported {symptoms}, the goal is to reduce strain first, "
                "then build momentum safely."
            )
        return (
            "Because your recent pattern suggests stress load, the first step is intentionally small so it is easier to complete "
            "and gives us a clean signal for what to do next."
        )

    if asks_next and last_step:
        return _compose(
            "You are ready for the next step.",
            "Keep momentum: repeat the previous step once, then add one follow-up action focused on recovery and consistency.",
        )

    if _mentions('sleep', 'insomnia', 'tired', 'exhausted', 'rest', 'wake', 'bedtime'):
        return _compose(
            "Your message sounds sleep-related.",
            "Do a 20-minute wind-down now: dim lights, no scrolling, and 6 slow breaths before bed.",
            "If sleep stays very short for several nights, consider checking in with a clinician.",
        )

    if _mentions('anxious', 'anxiety', 'stress', 'overwhelmed', 'panic', 'spiraling', 'tense'):
        return _compose(
            "This sounds like a high-stress moment.",
            "Name one stressor in a sentence, then pick one 10-minute action you can finish right now.",
            "If distress spikes or feels unsafe, reach out to a trusted person or professional support.",
        )

    if _mentions('sad', 'low', 'down', 'empty', 'hopeless', 'unmotivated', 'numb'):
        return _compose(
            "Your mood sounds heavy right now.",
            "Choose one tiny reset: water + sunlight, or a short walk + one supportive text message.",
            "If this keeps worsening, it is important to seek professional support.",
        )

    if _mentions('pain', 'headache', 'nausea', 'dizzy', 'sore', 'symptom', 'hurt'):
        return _compose(
            "It sounds like your body needs a lower-load plan right now.",
            "Do a gentle reset: hydrate, reduce stimulation, and track symptom intensity 0-10 after 20 minutes.",
            "Seek urgent care if symptoms escalate quickly or feel severe.",
        )

    if _mentions('workout', 'exercise', 'gym', 'walk', 'run', 'steps', 'training'):
        step = (
            "Do a 10-minute easy movement block and stop while it still feels manageable."
            if high_strain
            else "Do a 15-minute moderate session and log how your energy feels after."
        )
        return _compose("You are asking about movement.", step)

    if symptoms:
        return _compose(
            f"Given your recent mood ({mood}) and active symptoms ({symptoms}), keeping effort low is a good call.",
            "Pick one low-effort action now, then reassess in 20 minutes.",
            "If symptoms worsen or feel alarming, seek medical care promptly.",
        )

    if asks_plan:
        return _compose(
            f"Your recent trend looks {mood}.",
            "Use a 3-step plan for the next 2 hours: hydrate, one focused task, then a short reset.",
        )

    # If the user asks a direct question and we did not match a domain intent,
    # return a concise clarifying path instead of a generic canned line.
    if '?' in text:
        return (
            "Good question. Give me one detail about your goal right now (sleep, mood, symptoms, or exercise), "
            "and I will answer with a specific next step that fits your current state."
        )

    return _compose(
        f"I am tracking your recent {mood} trend.",
        "Give me one concrete goal for the next hour and I will break it into a simple step-by-step plan.",
    )


def _build_suggestions_prompt(suggestion_input: MiniMeSuggestionsRequest) -> str:
    latest_mood = suggestion_input.latest_mood_label or 'Unknown'
    intensity = suggestion_input.latest_mood_intensity
    mood_notes = suggestion_input.latest_mood_notes or 'None'
    recent_moods = suggestion_input.recent_moods or ['No recent mood logs']
    recent_logs = suggestion_input.recent_logs or []
    active_symptoms = suggestion_input.active_symptoms or []
    summary_context = (suggestion_input.summary_context or '').strip() or 'No summary context available.'
    suggestion_window = (suggestion_input.suggestion_window or '').strip().lower()
    trigger_reason = (suggestion_input.trigger_reason or '').strip() or 'regular refresh'
    event_override = suggestion_input.event_override
    window_label = suggestion_window or 'unspecified'
    target_count = 1 if suggestion_window in {
        'morning_anchor',
        'midday_checkin',
        'evening_reflection',
        'event_override',
        'log_update',
    } else 3

    window_instruction = {
        'morning_anchor': (
            'Morning anchor mode: return 1 primary suggestion grounded in overnight sleep and recent mood trend. '
            'Keep it actionable for the next 2-4 hours.'
        ),
        'midday_checkin': (
            'Midday check-in mode: return 1 suggestion only if new logs or strong state shifts are present in context. '
            'If context change is weak, return a conservative continuation step instead of a brand-new plan.'
        ),
        'evening_reflection': (
            'Evening reflection mode: return 1 wrap-up suggestion focused on review, wind-down, or tomorrow prep.'
        ),
        'event_override': (
            'Event override mode: return 1 supportive high-priority suggestion for immediate stabilization. '
            'Use calm language and the lowest-friction next step.'
        ),
        'log_update': (
            'Log-update mode: return 1 updated suggestion that explicitly reflects the newest logged changes. '
            'Do not repeat previous wording if context did not materially change.'
        ),
    }.get(suggestion_window, 'General mode: return up to 3 varied suggestions.')

    history_lines = []
    for item in suggestion_input.chat_history[-12:]:
        speaker = 'User' if item.role == 'user' else 'Mini-Me'
        history_lines.append(f"{speaker}: {item.text}")
    history_text = '\n'.join(history_lines) if history_lines else 'No previous messages.'

    recent_logs_text = '\n'.join(f"- {item}" for item in recent_logs[:28]) if recent_logs else '- No recent log timeline provided.'
    symptoms_text = ', '.join(active_symptoms[:20]) if active_symptoms else 'None reported currently'

    return f"""You are Mini-Me, a supportive wellness coach in the LifeLens app.

Write {target_count} UNIQUE daily suggestion{'s' if target_count != 1 else ''} for this specific user based on ALL available context.

Requirements:
- Each suggestion must feel freshly written for this user's context.
- Each suggestion must be based on whole-picture patterns, not a single log entry.
- Every suggestion should combine at least two signal types when available (for example mood + sleep, or symptoms + exercise, or chat + trend summary).
- Across the 3 suggestions, cover different pattern angles (stabilize, investigate trigger, practical next step).
- Do not repeat or quote prior Mini-Me replies verbatim.
- Use clear, casual, easy-to-understand language.
- Each suggestion should be practical, specific, and warm.
- Avoid medical claims or diagnosis.
- Do not use markdown.
- Return valid JSON only.
{window_instruction}

Return exactly this JSON shape:
{{
  "suggestions": [
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}},
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}},
    {{"action": "One clear next-step sentence.", "reason": "One short reason tied to the user's pattern."}}
  ]
}}

Current context:
- Delivery window: {window_label}
- Trigger reason: {trigger_reason}
- Event override active: {'yes' if event_override else 'no'}
- Summary context (primary source): {summary_context}
- Latest mood: {latest_mood}
- Mood intensity: {intensity if intensity is not None else 'unknown'} / 5
- Mood notes: {mood_notes}
- Recent moods: {' | '.join(recent_moods)}
- Active symptoms: {symptoms_text}

Recent multi-log timeline (use this as evidence for cross-log patterns):
{recent_logs_text}

Mini-Me conversation history:
{history_text}
"""


def _build_suggestions_fallback(
    suggestion_input: MiniMeSuggestionsRequest,
) -> MiniMeSuggestionsResponse:
    mood = (suggestion_input.latest_mood_label or 'neutral').lower()
    intensity = suggestion_input.latest_mood_intensity or 0
    suggestion_window = (suggestion_input.suggestion_window or '').strip().lower()
    summary_context = (suggestion_input.summary_context or '').lower()
    recent_logs = [item.lower() for item in (suggestion_input.recent_logs or [])]
    active_symptoms = [item.lower() for item in (suggestion_input.active_symptoms or [])]

    target_count = 1 if suggestion_window in {
        'morning_anchor',
        'midday_checkin',
        'evening_reflection',
        'event_override',
        'log_update',
    } else 3

    symptom_text = ' '.join(active_symptoms)
    log_text = ' '.join(recent_logs)
    context_text = f"{summary_context} {log_text} {symptom_text}".strip()

    has_sleep_signal = any(
        token in context_text
        for token in ['sleep', 'bed', 'wake', 'insomnia', 'rest', 'night']
    )
    has_exercise_signal = any(
        token in context_text
        for token in ['exercise', 'workout', 'walk', 'steps', 'movement', 'cardio', 'strength']
    )
    has_stress_signal = any(
        token in context_text
        for token in ['stress', 'anxious', 'overwhelmed', 'panic', 'tense']
    )
    has_low_energy_signal = any(
        token in context_text
        for token in ['fatigue', 'tired', 'drained', 'low energy']
    )
    has_physical_discomfort = any(
        token in context_text
        for token in ['pain', 'injury', 'headache', 'dizzy', 'nausea', 'sore']
    )

    cautious_mode = has_physical_discomfort or intensity >= 4

    fallback_items: List[MiniMeSuggestionItem] = []
    seen_actions = set()

    def add_item(action: str, reason: str):
        normalized = action.strip().lower()
        if not normalized or normalized in seen_actions:
            return
        seen_actions.add(normalized)
        fallback_items.append(
            MiniMeSuggestionItem(
                action=action.strip()[:240],
                reason=reason.strip()[:240],
            )
        )

    if cautious_mode:
        add_item(
            'Take a gentle 3-minute reset: sip water, loosen your shoulders, and do 6 slow breaths.',
            'Your recent signals suggest higher strain, so a low-effort calming step is safer and easier to start.',
        )

    if has_sleep_signal:
        add_item(
            'Set a simple sleep anchor tonight: pick one bedtime cue and keep wake time steady tomorrow.',
            'Your recent context mentions sleep patterns, and consistency is the most practical next lever.',
        )

    if has_exercise_signal and not cautious_mode:
        add_item(
            'Do a 10-minute movement block now (walk, stretch, or light bodyweight) and stop while it still feels easy.',
            'Your recent logs suggest movement helps, and short sessions improve follow-through without burnout.',
        )

    if mood in {'anxious', 'stressed', 'overwhelmed'} or has_stress_signal:
        add_item(
            'Write one sentence naming the top stressor, then choose one tiny action you can finish in 10 minutes.',
            'Breaking stress into one concrete step reduces mental load and builds momentum quickly.',
        )

    if mood in {'sad', 'low', 'down'} or has_low_energy_signal:
        add_item(
            'Pick one mood-lift pair for today: brief sunlight + short walk, or water + stretch break.',
            'Low-energy patterns usually improve with very small physical and environmental boosts.',
        )

    add_item(
        'Do a quick evening reflection: one win, one challenge, and one tiny plan for tomorrow.',
        'This keeps progress visible and helps tomorrow start with less friction.',
    )

    add_item(
        'Choose one non-negotiable wellness step for the next 2-4 hours and treat it as your baseline win.',
        'A single clear commitment is easier to keep and still moves your overall trend in the right direction.',
    )

    suggestions = fallback_items[:target_count] if fallback_items else [
        MiniMeSuggestionItem(
            action='Take one small supportive step now: hydrate, breathe slowly for one minute, and plan your next tiny action.',
            reason='When context is mixed, a low-friction reset helps stabilize and makes follow-through more likely.',
        ),
    ]

    return MiniMeSuggestionsResponse(
        suggestions=suggestions,
        source='fallback',
    )


def _build_exercise_recommendations_prompt(
    recommendation_input: MiniMeExerciseRecommendationRequest,
) -> str:
    latest_mood = recommendation_input.latest_mood_label or 'Unknown'
    intensity = recommendation_input.latest_mood_intensity
    mood_notes = recommendation_input.latest_mood_notes or 'None'
    recent_moods = recommendation_input.recent_moods or ['No recent mood logs']
    summary_context = (recommendation_input.summary_context or '').strip() or 'No summary context available.'

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

Requirements:
- Only recommend exercises from the provided catalog.
- Match the user's mood, intensity, summarized context, and Mini-Me context.
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
- Summary context (primary source): {summary_context}
- Latest mood: {latest_mood}
- Mood intensity: {intensity if intensity is not None else 'unknown'} / 5
- Mood notes: {mood_notes}
- Recent moods: {' | '.join(recent_moods)}

Mini-Me conversation history:
{history_text}

Available exercise catalog:
{chr(10).join(exercise_lines)}
"""


def _build_exercise_recommendations_fallback(
    recommendation_input: MiniMeExerciseRecommendationRequest,
) -> MiniMeExerciseRecommendationResponse:
    exercises = recommendation_input.exercises
    mood = (recommendation_input.latest_mood_label or 'neutral').lower()
    summary_context = (recommendation_input.summary_context or '').lower()
    symptoms_text = summary_context
    cautious = any(
        word in symptoms_text
        for word in ['pain', 'injury', 'dizzy', 'fatigue', 'tired', 'headache']
    ) or (recommendation_input.latest_mood_intensity or 0) >= 4

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
        headline='Mini-Me picked a few exercises that look realistic for how you have been feeling.',
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
        if (not _is_gemini_enabled()) or analysis_service.client is None:
            fallback_opening = _build_opening_fallback(chat_input)
            return MiniMeChatResponse(
                opening_suggestion=fallback_opening if is_opening_request else '',
                reply=_build_reply_fallback(chat_input),
                source='fallback',
                memory_state=memory_state,
            )

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
    try:
        if (not _is_gemini_enabled()) or analysis_service.client is None:
            return _build_suggestions_fallback(suggestion_input)

        prompt = _build_suggestions_prompt(suggestion_input)
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
        try:
            return _build_suggestions_fallback(suggestion_input)
        except Exception as fallback_error:
            logger.error(f"Mini-Me suggestions fallback failed: {fallback_error}")
            raise HTTPException(
                status_code=503,
                detail="Mini-Me suggestions are temporarily unavailable.",
            )


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
    try:
        if (not _is_gemini_enabled()) or analysis_service.client is None:
            return _build_exercise_recommendations_fallback(recommendation_input)

        prompt = _build_exercise_recommendations_prompt(recommendation_input)
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
        return _build_exercise_recommendations_fallback(recommendation_input)


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
