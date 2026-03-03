"""
Data models for Lifelens API
"""
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


class UrgencyLevel(str, Enum):
    """Symptom urgency levels"""
    EMERGENCY = "emergency"
    URGENT = "urgent"
    ROUTINE = "routine"
    INFORMATIONAL = "informational"


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
