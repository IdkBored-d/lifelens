"""
Lifelens Backend API
FastAPI application with Gemini and RAG integration
"""
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
import re
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
    NotifySphereMembersRequest,
)
from services.gemini_service import get_analysis_service, GeminiAnalysisService
from services.intelligence import analyze_logs_in_order
from services.intelligence_policy import get_intelligence_policy
from services.memory_compiler import compile_minime_memory_with_diff
from services.memory_logging import log_memory_event
from services.notification_service import send_sphere_message_notification
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
_gemini_suggestions_disabled_until = 0.0


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
    description="Symptom analysis API with DisEmbed/RAG prediction and Mini-Me refinement endpoints",
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
        "description": "Symptom analysis with DisEmbed/RAG; Gemini is reserved for optional Mini-Me wording refinement",
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
    summary="Analyze symptoms with DisEmbed/RAG"
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
    raw_mood = (chat_input.latest_mood_label or 'neutral').strip().lower()
    mood_text = {
        'joy': 'positive',
        'love': 'connected',
        'anger': 'frustrated',
        'fear': 'stress-sensitive',
        'surprise': 'mixed',
        'sadness': 'low',
    }.get(raw_mood, raw_mood)
    symptoms = ', '.join(chat_input.active_symptoms[:2]) if chat_input.active_symptoms else ''
    if symptoms:
        return (
            f"I noticed {mood_text} mood notes with {symptoms}. Try water, a few slow breaths, and one easy next step."
        )
    return (
        f"I noticed your mood has felt {mood_text}. Try one tiny win: pause, pick one priority, and do the first step."
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


def _is_diagnosis_style_question(text: str) -> bool:
    lower = (text or '').strip().lower()
    if not lower:
        return False
    diagnosis_phrases = [
        'what could i have', 'what do i have', 'what is this', 'what condition',
        'what disease', 'what illness', 'what infection', 'could it be',
        'what might i have', 'what could cause', 'diagnose', 'diagnosis',
    ]
    return any(phrase in lower for phrase in diagnosis_phrases)


def _extract_symptoms_from_chat_input(chat_input: MiniMeChatRequest) -> List[str]:
    symptoms: List[str] = []
    seen = set()

    def _push(value: str) -> None:
        cleaned = value.strip().strip('.!?;:').lower()
        if not cleaned:
            return
        if cleaned in seen:
            return
        seen.add(cleaned)
        symptoms.append(cleaned)

    for item in (chat_input.active_symptoms or []):
        _push(item)

    text = (chat_input.user_message or '').strip().lower()
    if text:
        # Pull likely symptom chunks from free text if user typed symptoms inline.
        tail = text
        for marker in ('based on', 'with', 'having', 'feeling'):
            idx = text.find(marker)
            if idx != -1:
                tail = text[idx + len(marker):]
                break

        tail = tail.replace(' and ', ',')
        tail = re.sub(r'[^a-z0-9,\-\s]', ' ', tail)
        for chunk in tail.split(','):
            chunk = chunk.strip()
            if not chunk:
                continue
            if chunk in {
                'what could i have', 'what do i have', 'what is this', 'what condition',
                'what disease', 'what illness', 'what infection', 'could it be',
                'what might i have', 'what could cause', 'diagnose', 'diagnosis',
            }:
                continue
            if len(chunk) > 64:
                continue
            _push(chunk)

    return symptoms[:20]


async def _build_minime_symptom_prediction_reply(
    chat_input: MiniMeChatRequest,
    analysis_service: GeminiAnalysisService,
) -> str:
    if not _is_diagnosis_style_question(chat_input.user_message):
        return ''

    symptoms = _extract_symptoms_from_chat_input(chat_input)
    if not symptoms:
        return (
            "I can definitely help with that. Share 2-5 symptoms (for example: headache, fatigue, dry throat), "
            "and I will give you your possible conditions in chat."
        )

    try:
        result = await analysis_service.analyze_symptoms(SymptomInput(symptoms=symptoms))
    except Exception as e:
        logger.warning(f"Mini-Me symptom prediction lookup failed: {e}")
        return (
            "I could not run the symptom lookup right now. Please try again in a moment, "
            "or log the symptoms in the Symptoms screen and I will analyze them there."
        )

    predictions = (result.predictions or [])[:3]
    if not predictions:
        return (
            "I could not find strong condition matches yet for those symptoms. "
            "If symptoms persist or worsen, please seek medical care."
        )

    lines = [
        "Based on what you shared, here are your possible conditions:",
    ]
    for index, item in enumerate(predictions, start=1):
        confidence_pct = int(round(item.confidence * 100))
        lines.append(f"{index}. {item.condition} ({confidence_pct}% match)")

    if result.warning_signs:
        lines.append(f"Watch for: {result.warning_signs[0]}")
    lines.append("This is not a diagnosis, but it can help guide your next step.")

    return ' '.join(lines)


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
    recent_assistant_turns = [
        item.text.strip().lower()
        for item in chat_input.chat_history[-6:]
        if item.role == 'assistant' and item.text.strip()
    ]
    last_assistant_turn = recent_assistant_turns[-1] if recent_assistant_turns else ''

    def _extract_goal_statement(message: str) -> str:
        raw = (message or '').strip()
        lowered = raw.lower().strip()
        if not lowered:
            return ''

        prefixes = [
            'i want to ',
            'i need to ',
            'i am going to ',
            "i'm going to ",
            'im going to ',
            'i will ',
            "i'll ",
            'my goal is to ',
            'today i will ',
            'i plan to ',
            'i am focusing on ',
            "i'm focusing on ",
            'i am working on ',
            "i'm working on ",
        ]
        for prefix in prefixes:
            if lowered.startswith(prefix):
                goal = raw[len(prefix):].strip(' .!')
                goal_lower = goal.lower()
                if goal_lower.startswith('focus on '):
                    goal = goal[len('focus on '):].strip(' .!')
                return goal

        # Common natural phrasing: "I want to focus on ..."
        special = 'i want to focus on '
        if lowered.startswith(special):
            goal = raw[len(special):].strip(' .!')
            return goal

        if 'focus on' in lowered:
            idx = lowered.find('focus on')
            goal = raw[idx + len('focus on'):].strip(' .!')
            if goal:
                return goal

        return ''

    goal_statement = _extract_goal_statement(text)

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

    _negative_moods_strain = {'fear', 'anger', 'sadness', 'anxious', 'stressed', 'overwhelmed', 'disgust'}
    high_strain = (intensity is not None and intensity >= 4 and mood in _negative_moods_strain) or mood in {'fear', 'anger', 'sadness'}

    completion_positive = any(
        token in lower
        for token in [
            'i did', 'done', 'completed', 'finished', 'worked',
            'i followed', 'i did it', 'that helped', 'it helped',
            'feel better', 'feeling better', 'more relaxed', 'calmer',
            'less stressed', 'more calm', 'better now'
        ]
    )
    completion_negative = any(
        token in lower
        for token in [
            "didn't", 'did not', 'could not', "couldn't", 'not helping',
            'didnt help', 'doesnt help', 'too hard', 'not working'
        ]
    )

    if completion_positive and _mentions('relaxed', 'calmer', 'less stressed', 'better'):
        if goal_statement:
            return _compose(
                "Great update, that means the reset helped.",
                f"Use this calmer window for one focused 20-minute block on {goal_statement}, then take a short break.",
                ask_update=False,
            )
        return _compose(
            "Great update, that means the reset helped.",
            "Use this calmer window for one focused 20-minute task, then take a 5-minute break and send me one line on what moved forward.",
            ask_update=False,
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
                ask_update=False,
            )
        return _compose(
            "Great job doing the last step.",
            "Use a progression: repeat it once more today, then add one small challenge (5-10 extra minutes or one extra action).",
            ask_update=False,
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

    if goal_statement:
        if any(
            token in last_assistant_turn
            for token in ['one concrete goal', 'give me one concrete goal']
        ):
            return _compose(
                "Great, that is a clear goal.",
                f"Run one focused 25-minute block on {goal_statement}. Then take a 5-minute reset, and send me this update: done or blocked plus one blocker.",
                ask_update=False,
            )
        return _compose(
            "Good commitment.",
            f"Start now with one focused 20-25 minute block on {goal_statement}, then take a short reset and report what changed.",
            ask_update=False,
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
        # If the user is asking what they could have / what condition matches,
        # redirect them to the symptom log feature rather than giving a generic plan.
        asks_diagnosis = any(
            phrase in lower
            for phrase in [
                'what could i have', 'what do i have', 'what is this', 'what condition',
                'what disease', 'what illness', 'what infection', 'could it be',
                'what might i have', 'what could cause', 'diagnose', 'diagnosis',
            ]
        )
        if asks_diagnosis:
            return (
                "That is a great question to explore. For your best answer, log those symptoms in the Symptoms screen — "
                "I will run a full analysis and show you your possible conditions matched to your specific combination. "
                "I cannot make diagnoses, but the analysis can point you in the right direction and tell you when to seek care."
            )

        # Avoid repeating the exact same canned advice when the last reply was identical
        _symptom_step_marker = 'gentle reset: hydrate, reduce stimulation'
        if _symptom_step_marker in last_assistant_turn:
            return _compose(
                "You mentioned physical symptoms again.",
                "Check in with the intensity on a 0-10 scale compared to 20 minutes ago — has it shifted? "
                "If it is the same or worse, that is worth a note to your doctor.",
                "Seek urgent care immediately if you notice trouble breathing, chest pain, or sudden worsening.",
                ask_update=False,
            )

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
            f"Your recent pattern looks {mood}.",
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
        "Thanks for the update.",
        "Share one concrete goal for the next hour, and I will break it into simple step-by-step actions.",
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
- If logs contain notes, tags, sleep notes, workout details, or symptom context, reuse at least one concrete phrase/noun from those details in the action or reason.
- If recent logs are similar to previous days, change the angle instead of repeating the same advice: trigger, friction, timing, environment, recovery cost, boundary, support, or what to protect next.
- Do not give category-only advice like "log mood", "sleep earlier", "rest more", or "take a walk" when a specific note/context is available.
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


def _build_suggestions_refinement_prompt(
        suggestion_input: MiniMeSuggestionsRequest,
        base_suggestions: List[MiniMeSuggestionItem],
) -> str:
        suggestion_window = (suggestion_input.suggestion_window or '').strip().lower() or 'unspecified'
        latest_mood = (suggestion_input.latest_mood_label or 'unknown').strip()
        intensity = suggestion_input.latest_mood_intensity
        summary_context = (suggestion_input.summary_context or '').strip() or 'No summary context available.'
        active_symptoms = suggestion_input.active_symptoms or []
        symptoms_text = ', '.join(active_symptoms[:20]) if active_symptoms else 'None reported currently'

        lines = []
        for index, item in enumerate(base_suggestions, start=1):
                lines.append(
                        f"{index}. action: {item.action}\n"
                        f"   reason: {item.reason}"
                )
        base_text = '\n'.join(lines)

        target_count = len(base_suggestions)
        return f"""You are editing Mini-Me suggestions for readability only.

Task:
- Rewrite each suggestion so it is clearer and more natural for users.
- Preserve the original intent and practical next step.
- Preserve concrete user context from notes/logs when it appears in the original suggestion or summary.
- If a suggestion is generic but the context includes notes, tags, sleep notes, workout details, or symptom context, make the wording point to that concrete detail without inventing facts.
- Keep the same number of suggestions ({target_count}).
- Keep each action and reason concise, warm, and easy to understand.
- Do not add medical diagnosis or new high-risk guidance.
- Do not invent new goals unrelated to the original suggestions.
- Return valid JSON only.

Return exactly this JSON shape:
{{
    "suggestions": [
        {{"action": "Refined action sentence.", "reason": "Refined reason sentence."}},
        {{"action": "Refined action sentence.", "reason": "Refined reason sentence."}},
        {{"action": "Refined action sentence.", "reason": "Refined reason sentence."}}
    ]
}}

Context:
- Delivery window: {suggestion_window}
- Latest mood: {latest_mood}
- Mood intensity: {intensity if intensity is not None else 'unknown'} / 5
- Active symptoms: {symptoms_text}
- Summary context: {summary_context}

Base suggestions to refine (keep same intent/order/count):
{base_text}
"""


def _build_suggestions_fallback(
    suggestion_input: MiniMeSuggestionsRequest,
) -> MiniMeSuggestionsResponse:
    mood = (suggestion_input.latest_mood_label or 'neutral').lower()
    intensity = suggestion_input.latest_mood_intensity or 0
    suggestion_window = (suggestion_input.suggestion_window or '').strip().lower()
    trigger_reason = (suggestion_input.trigger_reason or '').strip().lower()
    mood_notes = (suggestion_input.latest_mood_notes or '').strip().lower()
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
    context_text = f"{summary_context} {log_text} {symptom_text} {mood_notes}".strip()

    # ── Mood classification ────────────────────────────────────────────────
    _positive_moods = {'joy', 'love', 'happy', 'excited', 'content', 'calm', 'grateful', 'hopeful', 'surprise', 'surprised'}
    _negative_moods = {'fear', 'anger', 'sadness', 'anxious', 'stressed', 'overwhelmed', 'disgust', 'sad', 'angry', 'anxious'}
    mood_is_positive = mood in _positive_moods
    mood_is_negative = mood in _negative_moods

    # ── Sleep quality parsing ──────────────────────────────────────────────
    # Flutter sends "Sleep logs: average X.X hours ... Sleep quality pattern: excellent/good/fair/poor ..."
    # and "X recent entries were under 7 hours."
    _good_sleep_labels = {'excellent', 'great', 'very good', 'good'}
    _bad_sleep_labels = {'poor', 'bad', 'terrible', 'awful', 'light', 'restless', 'fair'}
    sleep_quality_is_good = any(label in summary_context for label in _good_sleep_labels)
    sleep_quality_is_bad = any(label in summary_context for label in _bad_sleep_labels)
    sleep_has_no_logs = 'sleep logs: none' in summary_context or 'sleep logs: none yet' in summary_context
    sleep_has_low_hours = 'under 7 hours' in summary_context and '0 recent entries were under 7' not in summary_context
    # Sleep needs attention only if quality is poor/bad OR hours are short
    sleep_needs_attention = (not sleep_has_no_logs) and (sleep_quality_is_bad or sleep_has_low_hours)
    # Sleep recently logged and already good
    sleep_is_solid = sleep_quality_is_good and not sleep_has_low_hours and not sleep_has_no_logs

    # ── Exercise parsing ───────────────────────────────────────────────────
    # Flutter sends "Exercise logs: X today and Y in the last 7 days."
    exercise_has_no_logs = 'exercise logs: none' in summary_context or 'exercise logs: none yet' in summary_context
    exercise_today_zero = 'exercise logs: 0 today' in summary_context
    exercise_week_zero = '0 in the last 7' in summary_context
    exercise_missing = exercise_has_no_logs or (exercise_today_zero and exercise_week_zero)
    exercise_logged = not exercise_missing and (
        'exercise log:' in log_text or  # individual log entry
        ('exercise logs:' in summary_context and 'none' not in summary_context.split('exercise logs:')[1][:30])
    )

    # ── Symptom / discomfort signals ───────────────────────────────────────
    has_physical_discomfort = any(
        token in context_text
        for token in ['pain', 'injury', 'headache', 'dizzy', 'nausea', 'sore']
    )
    has_stress_signal = any(
        token in context_text
        for token in ['stress', 'anxious', 'overwhelmed', 'panic', 'tense']
    )
    has_low_energy_signal = any(
        token in context_text
        for token in ['fatigue', 'tired', 'drained', 'low energy']
    )

    # ── Cautious mode: only for genuinely negative/strained states ─────────
    _negative_moods_strain = {'fear', 'anger', 'sadness', 'anxious', 'stressed', 'overwhelmed', 'disgust'}
    cautious_mode = has_physical_discomfort or (intensity >= 4 and mood in _negative_moods_strain)

    # ── Mood context: heavier patterns from recent logs ────────────────────
    recent_heavy_count = sum(
        1 for log in recent_logs
        if any(token in log for token in ['sadness', 'fear', 'anger', 'anxious', 'stressed', 'overwhelmed'])
    )
    mood_pattern_heavy = recent_heavy_count >= 2

    fallback_items: List[MiniMeSuggestionItem] = []
    scored_items: List[tuple[int, str, str, str]] = []
    seen_actions = set()

    def add_item(action: str, reason: str, score: int = 10, category: str = 'general'):
        normalized = action.strip().lower()
        if not normalized or normalized in seen_actions:
            return
        seen_actions.add(normalized)
        scored_items.append((score, category, action.strip()[:240], reason.strip()[:240]))

    def _stable_index(count: int) -> int:
        if count <= 0:
            return 0
        seed = '|'.join([
            suggestion_window,
            mood,
            str(intensity),
            ' '.join(recent_logs[:4]),
            symptom_text,
            str(len(recent_logs)),
        ])
        return sum(ord(ch) for ch in seed) % count

    latest_log = recent_logs[0] if recent_logs else ''
    latest_is_mood_log = 'mood log:' in latest_log or 'mood' in trigger_reason
    latest_is_sleep_log = 'sleep log:' in latest_log or 'sleep' in trigger_reason
    latest_is_symptom_log = 'symptom log:' in latest_log or 'symptom' in trigger_reason
    latest_is_exercise_log = 'exercise log:' in latest_log or 'exercise' in trigger_reason
    has_recurring_symptom_pattern = 'some symptoms appear more than once' in summary_context
    fitness_declining = 'fitness logs:' in summary_context and 'overall declining' in summary_context
    has_positive_food_note = any(
        token in mood_notes or token in latest_log
        for token in ['food', 'meal', 'ate', 'eat', 'taste', 'tasted', 'dinner', 'lunch', 'breakfast', 'snack']
    ) and any(
        token in mood_notes or token in latest_log
        for token in ['better than expected', 'good', 'great', 'nice', 'surprised', 'surprise', 'enjoyed', 'tasty', 'delicious']
    )

    def _first_symptoms() -> str:
        if active_symptoms:
            return ', '.join(active_symptoms[:3])
        if symptom_text:
            pieces = [part.strip() for part in re.split(r'[,|]', symptom_text) if part.strip()]
            return ', '.join(pieces[:3])
        return 'your symptoms'

    # Cross-signal playbook: these candidates intentionally combine multiple
    # logs so suggestions feel specific instead of only reacting to one mood.
    if latest_is_mood_log and has_positive_food_note:
        add_item(
            'Save that food win: note what made it better than expected, then use it as an easy repeat meal idea.',
            'Your newest mood note is about a pleasant food surprise, so the best suggestion should build on that specific positive moment.',
            score=132,
            category='latest_mood_note',
        )
        if sleep_needs_attention:
            add_item(
                'Keep the good-food momentum simple tonight: repeat one small thing you enjoyed, then protect sleep early.',
                'The food note is positive, but your sleep trend still needs care, so this keeps the suggestion grounded without turning it into pure recovery advice.',
                score=130,
                category='latest_mood_note_sleep',
            )

    if active_symptoms and sleep_needs_attention:
        add_item(
            'Make the next block a recovery block: hydrate, lower stimulation, and plan an earlier wind-down tonight.',
            f'Your active symptoms ({_first_symptoms()}) overlap with weaker sleep, so recovery should come before pushing harder.',
            score=116 if latest_is_mood_log else 124,
            category='symptoms_sleep',
        )
    if active_symptoms and exercise_logged:
        add_item(
            'Keep movement gentle today: use stretching or an easy walk instead of adding intensity.',
            f'You have symptoms logged ({_first_symptoms()}) and recent movement, so maintaining without overdoing it fits better.',
            score=118,
            category='symptoms_exercise',
        )
    if has_recurring_symptom_pattern:
        add_item(
            'Track the repeated symptom pattern once today: symptom, time, trigger, and intensity from 0-10.',
            'Your recent symptom logs show a repeat pattern, so a small tracking note may reveal what sets it off.',
            score=116,
            category='symptom_pattern',
        )
    if sleep_needs_attention and mood_is_negative:
        add_item(
            'Protect tonight first: choose one sleep anchor, then keep the rest of the evening low-pressure.',
            'Heavier mood plus weaker sleep usually calls for recovery before productivity.',
            score=114,
            category='sleep_mood',
        )
    if sleep_needs_attention and has_low_energy_signal:
        add_item(
            'Use an energy-conservation plan: one must-do task, one easy reset, and no extra pressure tonight.',
            'Low energy and weaker sleep are showing up together, so reducing load is more useful than adding tasks.',
            score=108 if suggestion_window == 'log_update' else 112,
            category='sleep_energy',
        )
    if sleep_is_solid and mood_is_positive and exercise_missing:
        add_item(
            'Use the good recovery window for a short movement win: 10 minutes, easy pace, then log how it felt.',
            'Your mood and sleep look supportive, but movement is the missing signal today.',
            score=112,
            category='mood_sleep_exercise',
        )
    if fitness_declining and exercise_missing:
        add_item(
            'Start with a minimum movement baseline today: 5-8 minutes walking or mobility, then stop while it feels manageable.',
            'Fitness is trending down and movement has been light, so the goal is restarting gently, not intensity.',
            score=110,
            category='fitness_exercise',
        )
    if exercise_logged and mood_is_positive and not cautious_mode:
        add_item(
            'Lock in the routine signal: repeat today’s movement pattern once more this week at the same easy level.',
            'Movement and mood are both pointing in a useful direction, so consistency beats a big jump.',
            score=106,
            category='exercise_mood',
        )
    if has_stress_signal and exercise_missing and not cautious_mode:
        add_item(
            'Use movement as a pressure valve: take a 7-minute walk, then write the one thing that feels most controllable.',
            'Stress is present and movement is light, so a small physical reset may make the next choice clearer.',
            score=104,
            category='stress_exercise',
        )
    if latest_is_symptom_log and active_symptoms:
        add_item(
            'For the next hour, choose comfort over optimization: fluids, rest, and one quick symptom intensity check.',
            f'Your newest log is symptom-related ({_first_symptoms()}), so the suggestion should match your body state first.',
            score=122,
            category='latest_symptom',
        )
    if latest_is_sleep_log and sleep_needs_attention:
        add_item(
            'Treat the latest sleep log as tonight’s cue: pick one earlier wind-down step and keep wake time steady tomorrow.',
            'The newest log points to sleep needing attention, so the most relevant next step is a repeatable sleep anchor.',
            score=121,
            category='latest_sleep',
        )
    if latest_is_exercise_log and exercise_logged and not cautious_mode:
        add_item(
            'Use that exercise log as momentum: schedule the next session now, but keep it the same difficulty.',
            'The newest movement data is already a win; repeating it is more reliable than increasing intensity immediately.',
            score=120,
            category='latest_exercise',
        )
    if latest_is_mood_log and sleep_needs_attention and mood_is_positive:
        add_item(
            'Let the better mood stay light: do one useful thing, then protect an earlier wind-down tonight.',
            'Your newest mood is stronger, but recent sleep is still very low, so the best plan is small momentum plus recovery.',
            score=123,
            category='latest_mood_sleep',
        )
    if latest_is_mood_log and sleep_needs_attention and not mood_is_positive:
        add_item(
            'Treat this mood check-in as a recovery signal: lower the next task size and choose one bedtime cue now.',
            'The newest mood log is landing on top of weak sleep, so reducing pressure is more useful than adding a big plan.',
            score=123,
            category='latest_mood_sleep',
        )
    if latest_is_mood_log and mood_is_positive and sleep_is_solid:
        add_item(
            'Use this lighter mood for one meaningful task, then stop and preserve the good energy.',
            'Your newest mood is positive and sleep looks steady, so a focused but bounded effort fits the moment.',
            score=119,
            category='latest_mood',
        )

    # Fresh log updates should primarily respond to the newest log. These score
    # above generic cautious/sleep/exercise items so different moods do not all
    # collapse into the same fallback suggestion when Gemini is unavailable.
    if suggestion_window == 'log_update':
        if mood in {'sad', 'sadness'}:
            add_item(
                'That sounded like a low moment. Try a tiny lift: step into light, take a short walk, or text someone you trust.',
                'Small support is enough for right now.',
                score=110,
                category='mood',
            )
        elif mood in {'fear', 'anxious', 'overwhelmed'}:
            add_item(
                'That sounded scary or tense. Write down what feels uncertain, then pick just one thing you can do next.',
                'One clear step can make things feel less loud.',
                score=110,
                category='mood',
            )
        elif mood in {'anger', 'stressed'}:
            add_item(
                'That sounded frustrating. Take five minutes away from the trigger, then choose one calm next move.',
                'A small pause can help you respond instead of react.',
                score=110,
                category='mood',
            )
        elif mood_is_positive:
            add_item(
                'Nice, that log sounded lighter. Use the momentum for one focused 20-minute task, then stop while it still feels good.',
                'Keep the win easy to finish.',
                score=110,
                category='mood',
            )

    # ── Cautious / strain mode ─────────────────────────────────────────────
    if cautious_mode:
        add_item(
            'Try a gentle 3-minute reset: sip water, loosen your shoulders, and take six slow breaths.',
            'Keep it easy on your body.',
            score=95,
        )
        add_item(
            'Keep the next step small: lower the noise for 10 minutes, then check how you feel.',
            'Start with steadying yourself.',
            score=92,
        )

    # ── Negative mood handling ─────────────────────────────────────────────
    if mood_is_negative and not cautious_mode:
        if mood in {'sad', 'sadness'}:
            add_item(
                'Pick one small lift: sunlight, a short walk, or a quick chat with someone you trust.',
                'Tiny support still counts.',
                score=82,
            )
            add_item(
                'Try one easy connection step: send a short text or sit somewhere brighter for 10 minutes.',
                'You do not have to force productivity.',
                score=80,
            )
        elif mood in {'fear', 'anxious', 'overwhelmed'}:
            add_item(
                'Name what is weighing on you, then choose the smallest next step.',
                'Small and clear is the goal.',
                score=84,
            )
            add_item(
                'Make two quick lists: what you can control, and what can wait.',
                'This can lower the pressure a little.',
                score=81,
            )
        elif mood in {'anger', 'stressed'}:
            add_item(
                'Step away for five minutes, breathe slowly, then come back to one small next move.',
                'Give yourself room first.',
                score=84,
            )
            add_item(
                'Before doing anything big, unclench your jaw, drop your shoulders, and take six slow breaths.',
                'Let your body settle first.',
                score=82,
            )

    if mood_pattern_heavy and not mood_is_negative:
        add_item(
            'You have had a few heavier moments lately. Pick one thing today that protects your energy.',
            'A little protection early can help.',
            score=76,
        )

    # ── Sleep suggestions: only when sleep actually needs attention ────────
    if sleep_needs_attention and not cautious_mode:
        add_item(
            'Set a simple sleep anchor tonight: pick one consistent bedtime cue and aim to keep your wake time steady tomorrow.',
            'Your recent sleep data shows room to improve — bedtime consistency is the most practical lever.',
            score=78,
        )
    elif sleep_is_solid and mood_is_positive:
        # Sleep is already great — acknowledge and build on it
        add_item(
            'Your sleep has been solid — protect that streak by keeping your wind-down routine consistent tonight.',
            'Good sleep is one of the strongest contributors to mood and energy. Keeping it consistent compounds the benefit.',
            score=70,
        )

    # ── Exercise suggestions: context-aware ───────────────────────────────
    if exercise_missing and mood_is_positive and not cautious_mode:
        add_item(
            'Try adding a short 10-minute movement block today — a walk or light stretch is a great first step.',
            "You haven't logged exercise yet. Even a brief session boosts mood and energy on days you're already feeling good.",
            score=72,
        )
    elif exercise_missing and not cautious_mode:
        add_item(
            'Even 5-10 minutes of gentle movement (walk, stretch) can help shift your energy today.',
            'Light activity is low-risk and often improves how the rest of the day feels, regardless of current mood.',
            score=68,
        )
    elif exercise_logged and not cautious_mode:
        add_item(
            'Great job logging exercise. Next session, try adding 5 minutes or one more set to keep the momentum.',
            'You have already built the habit — small progressive increases maintain improvement without burnout.',
            score=64,
        )

    # ── Positive reinforcement when everything looks good ─────────────────
    if mood_is_positive and sleep_is_solid and not cautious_mode and len(fallback_items) < target_count:
        add_item(
            'Your mood and sleep are both in a good place — use this energy to tackle one thing you have been putting off.',
            "High-energy windows are the best time for harder tasks. Acting now turns positive momentum into tangible progress.",
            score=80,
        )
        add_item(
            'Use this good window for one focused 20-minute block, then stop and log what moved forward.',
            'Your recent mood and sleep look supportive, so a short focused push fits the moment without overdoing it.',
            score=78,
        )

    # ── Stress / low-energy fallbacks ────────────────────────────────────
    if has_stress_signal and not mood_is_negative:
        add_item(
            'Write one sentence naming the top stressor, then choose one tiny action you can finish in 10 minutes.',
            'Breaking stress into one concrete step reduces mental load and builds momentum quickly.',
            score=74,
        )

    if has_low_energy_signal and not cautious_mode:
        add_item(
            'Pick a low-friction energy boost: drink a glass of water, do 5 minutes of light movement, or step outside briefly.',
            'Low-energy patterns often respond to tiny physical resets before requiring bigger changes.',
            score=73,
        )

    if suggestion_window == 'log_update':
        add_item(
            'Use this new log as your cue: pick one small step that matches how you feel right now.',
            'Check in again after 20 minutes.',
            score=88,
        )

    if recent_logs and not cautious_mode:
        add_item(
            'Compare your latest log with the previous one and choose one adjustment: easier pace, more rest, or one focused task.',
            'Your recent logs give enough context to tune the next step instead of repeating the same plan.',
            score=66,
        )

    # ── Reflection as a safe filler when nothing specific fires ──────────
    if len(fallback_items) < target_count:
        add_item(
            'Do a quick evening reflection: one win, one challenge, and one small plan for tomorrow.',
            'This keeps progress visible and helps tomorrow start with less friction.',
            score=40,
        )

    if len(fallback_items) < target_count:
        add_item(
            'Choose one clear wellness step for the next 2-4 hours and treat it as your baseline win for today.',
            'A single committed action is easier to follow through on and still moves your overall trend forward.',
            score=35,
        )

    scored_items.sort(key=lambda item: item[0], reverse=True)
    if scored_items:
        if target_count == 1:
            best_score = scored_items[0][0]
            top_band = [item for item in scored_items if item[0] >= best_score - 6]
            if best_score < 112:
                top_band = scored_items[:min(5, len(scored_items))]
            rotated = top_band[_stable_index(len(top_band))]
            fallback_items = [
                MiniMeSuggestionItem(action=rotated[2], reason=rotated[3])
            ]
        else:
            selected = []
            used_categories = set()
            for item in scored_items:
                if item[1] in used_categories and len(selected) < target_count - 1:
                    continue
                selected.append(item)
                used_categories.add(item[1])
                if len(selected) >= target_count:
                    break
            if len(selected) < target_count:
                for item in scored_items:
                    if item in selected:
                        continue
                    selected.append(item)
                    if len(selected) >= target_count:
                        break

            start = _stable_index(len(selected)) if selected else 0
            if len(selected) > 1:
                top = selected[0]
                rest = selected[1:]
                rest = rest[start % len(rest):] + rest[:start % len(rest)]
                selected = [top] + rest

            fallback_items = [
                MiniMeSuggestionItem(action=item[2], reason=item[3])
                for item in selected[:target_count]
            ]

    suggestions = fallback_items[:target_count] if fallback_items else [
        MiniMeSuggestionItem(
            action='Take one small supportive step now: hydrate, breathe slowly for one minute, and name your next tiny action.',
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

    symptom_prediction_reply = await _build_minime_symptom_prediction_reply(
        chat_input,
        analysis_service,
    )
    if symptom_prediction_reply:
        return MiniMeChatResponse(
            opening_suggestion='',
            reply=symptom_prediction_reply,
            source='symptom_analysis',
            memory_state=memory_state,
        )

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
            model=settings.gemini_model,
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
    """Generate deterministic suggestions, then optionally refine wording with Gemini."""
    global _gemini_suggestions_disabled_until
    base_response = _build_suggestions_fallback(suggestion_input)
    try:
        if (not _is_gemini_enabled()) or analysis_service.client is None:
            return base_response
        if time.time() < _gemini_suggestions_disabled_until:
            return base_response

        prompt = _build_suggestions_refinement_prompt(
            suggestion_input,
            base_response.suggestions,
        )
        response = analysis_service.client.models.generate_content(
            model=settings.gemini_model,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.35,
                top_p=0.9,
                top_k=40,
                max_output_tokens=500,
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
            for item in raw_suggestions[:len(base_response.suggestions)]
            if (item.get('action') or '').strip() and (item.get('reason') or '').strip()
        ]

        if not suggestions:
            raise ValueError('No valid refinement returned from Gemini')

        while len(suggestions) < len(base_response.suggestions):
            suggestions.append(base_response.suggestions[len(suggestions)])

        return MiniMeSuggestionsResponse(
            suggestions=suggestions,
            source='fallback',
        )
    except Exception as e:
        error_text = str(e)
        if '429' in error_text or 'RESOURCE_EXHAUSTED' in error_text:
            _gemini_suggestions_disabled_until = time.time() + 300
        logger.warning(f"Mini-Me suggestion refinement skipped; using deterministic fallback: {e}")
        return base_response


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
            model=settings.gemini_model,
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


@app.post("/api/v1/notify/sphere_message", status_code=202)
async def notify_sphere_message(request: NotifySphereMembersRequest):
    """
    Sends a push notification to all sphere members except the sender.
    Called by the Flutter client after posting a message.
    Returns 202 immediately; notification delivery is best-effort.
    """
    await send_sphere_message_notification(
        sphere_id=request.sphere_id,
        sphere_name=request.sphere_name,
        sender_user_id=request.sender_user_id,
        sender_nickname=request.sender_nickname,
        text=request.text,
    )
    return {"status": "queued"}


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
