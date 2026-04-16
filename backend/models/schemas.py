"""
Data models for Lifelens API
"""
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any, Literal
from datetime import datetime
from enum import Enum


class UrgencyLevel(str, Enum):
    """Symptom urgency levels"""
    EMERGENCY = "emergency"
    URGENT = "urgent"
    ROUTINE = "routine"
    INFORMATIONAL = "informational"


CANONICAL_MOOD_LABELS = {
    'sadness',
    'joy',
    'love',
    'anger',
    'fear',
    'surprise',
}


def _normalize_canonical_mood_label(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    label = value.strip().lower()
    if not label:
        return None
    if label not in CANONICAL_MOOD_LABELS:
        allowed = ', '.join(sorted(CANONICAL_MOOD_LABELS))
        raise ValueError(f"Mood label must be one of: {allowed}")
    return label


class SymptomInput(BaseModel):
    """Input model for symptom analysis"""
    symptoms: List[str] = Field(..., min_items=1, max_items=20, description="List of symptoms")
    age: Optional[int] = Field(None, ge=0, le=120, description="Patient age")
    sex: Optional[str] = Field(None, description="Patient sex (M/F/Other)")
    duration: Optional[str] = Field(None, max_length=200, description="Duration of symptoms")
    additional_info: Optional[str] = Field(None, max_length=1000, description="Additional context")
    user_id_hash: Optional[str] = Field(None, description="Anonymized user identifier")
    
    @validator('symptoms')
    def validate_symptoms(cls, v):
        """Ensure symptoms are non-empty and cleaned"""
        cleaned = [s.strip() for s in v if s.strip()]
        if not cleaned:
            raise ValueError("At least one non-empty symptom is required")
        return cleaned
    
    @validator('sex')
    def validate_sex(cls, v):
        """Normalize sex input"""
        if v is None:
            return None
        v_upper = v.upper()
        if v_upper in ['M', 'MALE']:
            return 'M'
        elif v_upper in ['F', 'FEMALE']:
            return 'F'
        elif v_upper in ['O', 'OTHER', 'NON-BINARY']:
            return 'Other'
        return v


class ConditionPrediction(BaseModel):
    """Single condition prediction"""
    condition: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    description: str
    severity: str
    when_to_seek_care: str


class SymptomAnalysisResult(BaseModel):
    """Complete analysis result"""
    urgency: UrgencyLevel
    analysis: str
    predictions: Optional[List[ConditionPrediction]] = None
    self_care_recommendations: Optional[List[str]] = None
    warning_signs: Optional[List[str]] = None
    knowledge_sources: Optional[List[str]] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    source: str = Field(..., description="'gemini', 'rag', or 'local'")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    response_time_ms: Optional[int] = None


class MedicalKnowledgeDoc(BaseModel):
    """Medical knowledge document for RAG"""
    doc_id: str
    condition: str
    symptoms: List[str]
    description: str
    severity: str
    treatment: str
    when_to_seek_care: str
    risk_factors: Optional[List[str]] = None
    complications: Optional[List[str]] = None
    source: str
    last_updated: datetime = Field(default_factory=datetime.utcnow)


class RAGQuery(BaseModel):
    """Query for RAG system"""
    query_text: str
    max_results: int = Field(5, ge=1, le=10)
    min_certainty: float = Field(0.7, ge=0.0, le=1.0)


class RAGResult(BaseModel):
    """RAG retrieval result"""
    doc_id: str
    condition: str
    content: str
    relevance_score: float
    source: str
    metadata: Dict[str, Any] = {}


class MiniMeChatHistoryItem(BaseModel):
    """Single Mini-Me chat turn for context."""
    role: str = Field(..., description="user or assistant")
    text: str = Field(..., min_length=1, max_length=2000)

    @validator('role')
    def validate_role(cls, v):
        role = v.strip().lower()
        if role not in {'user', 'assistant'}:
            raise ValueError("role must be 'user' or 'assistant'")
        return role


class MiniMeChatRequest(BaseModel):
    """Request model for Mini-Me chat."""
    user_message: str = Field('', max_length=2000)
    latest_mood_label: Optional[str] = Field(None, max_length=80)
    latest_mood_intensity: Optional[int] = Field(None, ge=0, le=5)
    latest_mood_notes: Optional[str] = Field(None, max_length=1000)
    summary_context: Optional[str] = Field(None, max_length=8000)
    recent_moods: List[str] = Field(default_factory=list, max_items=8)
    active_symptoms: List[str] = Field(default_factory=list, max_items=20)
    condition_labels: List[str] = Field(default_factory=list, max_items=8)
    symptom_steps: Dict[str, str] = Field(default_factory=dict)
    general_steps: List[str] = Field(default_factory=list, max_items=12)
    chat_history: List[MiniMeChatHistoryItem] = Field(default_factory=list, max_items=20)
    user_id_hash: Optional[str] = Field(None, max_length=128)
    # Intelligence context (optional — passed through from client-side analysis)
    intelligence_tier: Optional[str] = Field(None, max_length=20)
    intelligence_phase: Optional[str] = Field(None, max_length=30)
    intelligence_insights: List[str] = Field(default_factory=list, max_items=5)
    intelligence_actions: List[str] = Field(default_factory=list, max_items=5)
    intelligence_alert: Optional[str] = Field(None, max_length=500)
    intelligence_risk_score: Optional[float] = Field(None, ge=0, le=100)
    intelligence_confidence: Optional[float] = Field(None, ge=0, le=1)
    intelligence_state: Optional[Dict[str, bool]] = Field(None)
    previous_memory: Optional[Dict[str, Any]] = Field(None)

    @validator('user_message')
    def validate_user_message(cls, v):
        return v.strip()

    @validator('latest_mood_label')
    def validate_latest_mood_label(cls, v):
        return _normalize_canonical_mood_label(v)

    @validator('recent_moods', each_item=True)
    def validate_recent_mood_item(cls, v):
        normalized = _normalize_canonical_mood_label(v)
        if normalized is None:
            raise ValueError("recent_moods entries must be non-empty canonical mood labels")
        return normalized

    @validator('summary_context')
    def validate_summary_context(cls, v):
        return v.strip() if v is not None else None

    @validator('active_symptoms', each_item=True)
    def validate_active_symptom_item(cls, v):
        return v.strip()

    @validator('condition_labels', each_item=True)
    def validate_condition_label_item(cls, v):
        return v.strip()

    @validator('general_steps', each_item=True)
    def validate_general_step_item(cls, v):
        return v.strip()


class MiniMeMemoryState(BaseModel):
    """Minimal structured memory block used by Mini-Me prompt pipeline."""
    summary: str = Field('', max_length=320)
    key_points: List[str] = Field(default_factory=list, max_items=10)
    mood_state: Literal['positive', 'neutral', 'negative'] = 'neutral'
    risk: Literal['low', 'medium', 'high'] = 'low'
    quick_track: Dict[str, Any] = Field(default_factory=dict)


class MiniMeMemoryDiff(BaseModel):
    """Deterministic change log for memory updates."""
    changed_fields: List[str] = Field(default_factory=list, max_items=12)
    reason: str = Field('', max_length=500)
    contradiction_count: int = Field(0, ge=0)
    contradiction_reasons: List[str] = Field(default_factory=list, max_items=8)
    stability_score: float = Field(1.0, ge=0.0, le=1.0)


class MiniMeMemoryCompileResponse(BaseModel):
    """Structured memory compilation result."""
    memory_state: MiniMeMemoryState
    validation_passed: bool = True


class MiniMeChatResponse(BaseModel):
    """Response model for Mini-Me chat."""
    opening_suggestion: str
    reply: str
    source: str = Field(..., description="Provenance of the reply: gemini or fallback")
    memory_state: Optional[MiniMeMemoryState] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class MiniMeSuggestionItem(BaseModel):
    """Single generated Mini-Me suggestion."""
    action: str = Field(..., min_length=1, max_length=240)
    reason: str = Field(..., min_length=1, max_length=240)


class MiniMeSuggestionsRequest(BaseModel):
    """Request model for generated Mini-Me suggestions."""
    latest_mood_label: Optional[str] = Field(None, max_length=80)
    latest_mood_intensity: Optional[int] = Field(None, ge=0, le=5)
    latest_mood_notes: Optional[str] = Field(None, max_length=1000)
    summary_context: Optional[str] = Field(None, max_length=8000)
    recent_moods: List[str] = Field(default_factory=list, max_items=10)
    recent_logs: List[str] = Field(default_factory=list, max_items=12)
    active_symptoms: List[str] = Field(default_factory=list, max_items=20)
    condition_labels: List[str] = Field(default_factory=list, max_items=8)
    symptom_steps: Dict[str, str] = Field(default_factory=dict)
    general_steps: List[str] = Field(default_factory=list, max_items=12)
    chat_history: List[MiniMeChatHistoryItem] = Field(default_factory=list, max_items=20)
    user_id_hash: Optional[str] = Field(None, max_length=128)
    intelligence_tier: Optional[str] = Field(None, max_length=20)
    intelligence_phase: Optional[str] = Field(None, max_length=30)
    intelligence_insights: List[str] = Field(default_factory=list, max_items=5)
    intelligence_actions: List[str] = Field(default_factory=list, max_items=5)
    intelligence_alert: Optional[str] = Field(None, max_length=500)
    intelligence_risk_score: Optional[float] = Field(None, ge=0, le=100)
    intelligence_confidence: Optional[float] = Field(None, ge=0, le=1)
    intelligence_state: Optional[Dict[str, bool]] = Field(None)
    previous_memory: Optional[Dict[str, Any]] = Field(None)

    @validator('recent_moods', each_item=True)
    def validate_suggestion_recent_mood_item(cls, v):
        normalized = _normalize_canonical_mood_label(v)
        if normalized is None:
            raise ValueError("recent_moods entries must be non-empty canonical mood labels")
        return normalized

    @validator('latest_mood_label')
    def validate_suggestion_latest_mood_label(cls, v):
        return _normalize_canonical_mood_label(v)

    @validator('summary_context')
    def validate_suggestion_summary_context(cls, v):
        return v.strip() if v is not None else None

    @validator('recent_logs', each_item=True)
    def validate_recent_log_item(cls, v):
        return v.strip()

    @validator('active_symptoms', each_item=True)
    def validate_suggestion_active_symptom_item(cls, v):
        return v.strip()

    @validator('condition_labels', each_item=True)
    def validate_suggestion_condition_label_item(cls, v):
        return v.strip()

    @validator('general_steps', each_item=True)
    def validate_suggestion_general_step_item(cls, v):
        return v.strip()


class MiniMeSuggestionsResponse(BaseModel):
    """Response model for generated Mini-Me suggestions."""
    suggestions: List[MiniMeSuggestionItem] = Field(default_factory=list, min_items=1, max_items=3)
    source: str = Field(..., description="gemini or fallback")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class MiniMeExerciseCandidate(BaseModel):
    """Exercise candidate available for recommendation."""
    id: str = Field(..., min_length=1, max_length=200)
    name: str = Field(..., min_length=1, max_length=120)
    type: str = Field(..., min_length=1, max_length=80)
    muscle: str = Field(..., min_length=1, max_length=80)
    difficulty: str = Field(..., min_length=1, max_length=80)
    description: Optional[str] = Field(None, max_length=400)


class MiniMeExerciseRecommendationRequest(BaseModel):
    """Request model for Mini-Me exercise recommendations."""
    latest_mood_label: Optional[str] = Field(None, max_length=80)
    latest_mood_intensity: Optional[int] = Field(None, ge=0, le=5)
    latest_mood_notes: Optional[str] = Field(None, max_length=1000)
    summary_context: Optional[str] = Field(None, max_length=8000)
    recent_moods: List[str] = Field(default_factory=list, max_items=10)
    recent_logs: List[str] = Field(default_factory=list, max_items=12)
    active_symptoms: List[str] = Field(default_factory=list, max_items=20)
    condition_labels: List[str] = Field(default_factory=list, max_items=8)
    symptom_steps: Dict[str, str] = Field(default_factory=dict)
    general_steps: List[str] = Field(default_factory=list, max_items=12)
    chat_history: List[MiniMeChatHistoryItem] = Field(default_factory=list, max_items=20)
    exercises: List[MiniMeExerciseCandidate] = Field(default_factory=list, min_items=1, max_items=100)
    user_id_hash: Optional[str] = Field(None, max_length=128)
    intelligence_tier: Optional[str] = Field(None, max_length=20)
    intelligence_phase: Optional[str] = Field(None, max_length=30)
    intelligence_insights: List[str] = Field(default_factory=list, max_items=5)
    intelligence_actions: List[str] = Field(default_factory=list, max_items=5)
    intelligence_alert: Optional[str] = Field(None, max_length=500)
    intelligence_risk_score: Optional[float] = Field(None, ge=0, le=100)
    intelligence_confidence: Optional[float] = Field(None, ge=0, le=1)
    intelligence_state: Optional[Dict[str, bool]] = Field(None)
    previous_memory: Optional[Dict[str, Any]] = Field(None)

    @validator('recent_moods', each_item=True)
    def validate_exercise_recent_mood_item(cls, v):
        normalized = _normalize_canonical_mood_label(v)
        if normalized is None:
            raise ValueError("recent_moods entries must be non-empty canonical mood labels")
        return normalized

    @validator('latest_mood_label')
    def validate_exercise_latest_mood_label(cls, v):
        return _normalize_canonical_mood_label(v)

    @validator('summary_context')
    def validate_exercise_summary_context(cls, v):
        return v.strip() if v is not None else None

    @validator('recent_logs', each_item=True)
    def validate_exercise_recent_log_item(cls, v):
        return v.strip()

    @validator('active_symptoms', each_item=True)
    def validate_exercise_active_symptom_item(cls, v):
        return v.strip()

    @validator('condition_labels', each_item=True)
    def validate_exercise_condition_label_item(cls, v):
        return v.strip()

    @validator('general_steps', each_item=True)
    def validate_exercise_general_step_item(cls, v):
        return v.strip()


class MiniMeExerciseRecommendationItem(BaseModel):
    """Single recommended exercise item."""
    exercise_id: str = Field(..., min_length=1, max_length=200)
    reason: str = Field(..., min_length=1, max_length=240)
    focus: str = Field(..., min_length=1, max_length=140)


class MiniMeExerciseRecommendationResponse(BaseModel):
    """Response model for Mini-Me exercise recommendations."""
    headline: str = Field(..., min_length=1, max_length=160)
    recommendations: List[MiniMeExerciseRecommendationItem] = Field(
        default_factory=list,
        min_items=1,
        max_items=3,
    )
    source: str = Field(..., description="gemini or fallback")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class IntelligenceAnalyzeRequest(BaseModel):
    """Request model for intelligence analysis endpoint."""
    sleep: List[int] = Field(..., min_items=1, max_items=60)
    mood: List[int] = Field(..., min_items=1, max_items=60)
    exercise: List[int] = Field(..., min_items=1, max_items=60)
    symptom_count: List[int] = Field(default_factory=list, max_items=60)
    include_gemini_message: bool = True


class IntelligenceAnalyzeResponse(BaseModel):
    """Versioned intelligence contract with deterministic decision outputs."""
    contract_version: str = Field(default="2.0")
    state: Dict[str, bool]
    health_state_vector: List[float] = Field(default_factory=list)
    health_state_vector_labels: List[str] = Field(default_factory=list)
    features: Dict[str, float] = Field(default_factory=dict)
    health_score: Optional[float] = Field(None, ge=0.0, le=100.0)
    scores: Dict[str, float] = Field(default_factory=dict)
    trends: Dict[str, float] = Field(default_factory=dict)
    trend_classification: Dict[str, str] = Field(default_factory=dict)
    projection: Dict[str, float] = Field(default_factory=dict)
    next_day_predictions: Dict[str, float] = Field(default_factory=dict)
    prediction_model: Dict[str, Any] = Field(default_factory=dict)
    anomalies: List[Dict[str, Any]] = Field(default_factory=list)
    flags: List[str] = Field(default_factory=list)
    risk_score: float = Field(..., ge=0.0, le=100.0)
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    intervention_tier: str = Field(..., description="low, medium, or high")
    user_phase: str = Field(..., description="stable, declining, recovering, or acute-risk")
    selected_actions: List[str] = Field(default_factory=list)
    reasons: List[str] = Field(default_factory=list)
    evidence: List[str] = Field(default_factory=list)
    constraints: List[str] = Field(default_factory=list)
    explanation_trace: List[str] = Field(default_factory=list)
    action_probabilities: Dict[str, float] = Field(default_factory=dict)
    calibration: Dict[str, Any] = Field(default_factory=dict)
    evaluation: Dict[str, Any] = Field(default_factory=dict)
    weaviate_signal: Dict[str, Any] = Field(default_factory=dict)
    mini_me_linkage: Dict[str, Any] = Field(default_factory=dict)

    # Backward compatibility with current frontend wiring.
    insights: List[str]
    actions: List[str]

    message: str
    alert: Optional[str] = None
    prompt_preview: Optional[str] = None


class HealthDisclaimer(BaseModel):
    """Medical disclaimer"""
    text: str
    version: str = "1.0"
    effective_date: datetime = Field(default_factory=datetime.utcnow)


class ErrorResponse(BaseModel):
    """Error response model"""
    error: str
    detail: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
