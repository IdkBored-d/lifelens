"""
Backend analysis service.

Symptom disease prediction uses DisEmbed-backed RAG only. The Gemini client is
kept here because other Mini-Me endpoints use it for wording refinement.
"""
from google import genai
from google.genai import types
from typing import List, Optional, Dict, Any
import logging
import json
import time
import re
from datetime import datetime
import asyncio

from models.schemas import (
    SymptomInput,
    SymptomAnalysisResult,
    UrgencyLevel,
    ConditionPrediction,
    RAGQuery
)
from config.settings import get_settings

logger = logging.getLogger(__name__)


class GeminiAnalysisService:
    """
    Shared analysis service for symptom prediction and Mini-Me refinement.

    Symptom prediction is intentionally RAG/model-only; Gemini is initialized
    for other endpoints that opt into response wording refinement.
    """
    
    # Emergency symptoms that require immediate medical attention
    EMERGENCY_KEYWORDS = {
        'chest pain', 'difficulty breathing', 'severe bleeding',
        'loss of consciousness', 'sudden severe headache',
        'slurred speech', 'weakness on one side', 'confusion',
        'severe abdominal pain', 'coughing up blood', 'vomiting blood',
        'seizure', 'severe allergic reaction', 'suicidal thoughts',
        'severe burns', 'stroke symptoms', 'heart attack',
        'anaphylaxis', 'severe trauma', 'heavy bleeding',
        'can\'t breathe', 'choking', 'severe pain', 'paralysis',
        'unresponsive', 'blue lips', 'blue skin',
        'heart pain', 'heart ache', 'chest pressure', 'chest discomfort'
    }
    
    URGENT_KEYWORDS = {
        'high fever', 'severe pain', 'bleeding', 'vomiting',
        'severe headache', 'difficulty urinating', 'severe diarrhea',
        'dehydration', 'eye injury', 'deep cut', 'animal bite',
        'severe rash', 'broken bone', 'dislocated joint'
    }
    
    def __init__(self):
        """Initialize Gemini client and RAG service"""
        self.settings = get_settings()
        self.client = (
            genai.Client(api_key=self.settings.gemini_api_key)
            if self.settings.gemini_api_key
            else None
        )
        self.rag_service = None
        try:
            from services.rag_service import get_rag_service
            self.rag_service = get_rag_service()
        except Exception as e:
            logger.warning(f"RAG service unavailable, continuing without RAG: {e}")
        if self.client is None:
            logger.warning("Gemini API key is not configured; Gemini responses will use fallback paths")
        logger.info("Initialized Gemini Analysis Service")
    
    def _check_urgency(self, symptoms: List[str]) -> UrgencyLevel:
        """
        Determine urgency level based on symptom keywords
        
        Args:
            symptoms: List of symptom descriptions
            
        Returns:
            Urgency level (emergency, urgent, or routine)
        """
        symptoms_lower = [s.lower() for s in symptoms]
        symptoms_text = ' '.join(symptoms_lower)
        
        # Check for emergency symptoms
        for emergency_keyword in self.EMERGENCY_KEYWORDS:
            if emergency_keyword in symptoms_text:
                logger.warning(f"Emergency symptom detected: {emergency_keyword}")
                return UrgencyLevel.EMERGENCY
        
        # Check for urgent symptoms
        for urgent_keyword in self.URGENT_KEYWORDS:
            if urgent_keyword in symptoms_text:
                logger.info(f"Urgent symptom detected: {urgent_keyword}")
                return UrgencyLevel.URGENT
        
        return UrgencyLevel.ROUTINE
    
    def _build_emergency_response(self, symptoms: List[str]) -> str:
        """Build emergency response message"""
        return f"""🚨 **MEDICAL EMERGENCY DETECTED**

Based on your symptoms ({', '.join(symptoms[:3])}), you should:

**CALL 911 IMMEDIATELY** or go to the nearest emergency room.

These symptoms may indicate a life-threatening condition that requires immediate medical attention. Do not wait or try to treat this at home.

If you are alone:
1. Call 911 first
2. Unlock your door if possible
3. Stay on the line with emergency services

If with others:
1. Have someone call 911
2. Stay calm and still
3. Do not eat or drink anything

**This is not a diagnosis, but these symptoms require immediate professional medical evaluation.**
"""

    def _symptom_terms(self, symptom: str) -> List[str]:
        """Return conservative aliases used only for matching user symptoms to indexed condition symptoms."""
        normalized = symptom.strip().lower()
        aliases = {
            'dizziness': ['dizziness', 'dizzy', 'vertigo', 'lightheaded', 'lightheadedness'],
            'chest pain': ['chest pain', 'chest ache', 'chest pressure', 'chest discomfort', 'heart pain', 'heart ache'],
            'heart pain': ['heart pain', 'heart ache', 'chest pain', 'chest pressure', 'chest discomfort'],
            'stomach pain': ['stomach pain', 'stomach ache', 'abdominal pain', 'belly pain', 'cramps'],
            'body ache': ['body ache', 'body aches', 'muscle pain', 'muscle aches', 'aches', 'myalgia'],
            'congestion': ['congestion', 'congested', 'stuffy nose', 'nasal congestion'],
            'runny nose': ['runny nose', 'rhinitis'],
            'shortness of breath': ['shortness of breath', 'short of breath', 'breathless', 'difficulty breathing'],
        }
        return aliases.get(normalized, [normalized])

    def _contains_any_term(self, haystack: str, terms: List[str]) -> bool:
        return any(term and re.search(rf'\b{re.escape(term)}\b', haystack) for term in terms)

    def _score_chunk_against_symptoms(self, chunk: Dict[str, Any], symptoms: List[str]) -> float:
        """Blend semantic relevance with direct symptom-text overlap for better ranking quality."""
        relevance = float(chunk.get('relevance', 0.0))
        symptom_phrases = [s.strip().lower() for s in symptoms if s.strip()]
        if not symptom_phrases:
            chunk['primary_overlap'] = 0.0
            chunk['secondary_overlap'] = 0.0
            return relevance

        meta = chunk.get('metadata', {}) or {}
        meta_symptoms = meta.get('symptoms') if isinstance(meta, dict) else None
        primary_parts = [str(chunk.get('condition', ''))]
        if isinstance(meta_symptoms, list):
            primary_parts.extend(str(s) for s in meta_symptoms)
        secondary_parts = [str(chunk.get('content', ''))]

        primary_searchable = re.sub(r'\s+', ' ', ' '.join(primary_parts).lower()).strip()
        secondary_searchable = re.sub(r'\s+', ' ', ' '.join(secondary_parts).lower()).strip()
        if not primary_searchable and not secondary_searchable:
            chunk['primary_overlap'] = 0.0
            chunk['secondary_overlap'] = 0.0
            return relevance

        primary_matched = 0
        secondary_matched = 0
        for phrase in symptom_phrases:
            terms = self._symptom_terms(phrase)
            if self._contains_any_term(primary_searchable, terms):
                primary_matched += 1
            elif self._contains_any_term(secondary_searchable, terms):
                secondary_matched += 1

        primary_overlap = primary_matched / max(1, len(symptom_phrases))
        secondary_overlap = secondary_matched / max(1, len(symptom_phrases))
        chunk['primary_overlap'] = primary_overlap
        chunk['secondary_overlap'] = secondary_overlap

        return (0.55 * relevance) + (0.35 * primary_overlap) + (0.10 * secondary_overlap)

    def _rerank_knowledge_chunks(
        self,
        knowledge_chunks: List[Dict[str, Any]],
        symptoms: List[str],
    ) -> List[Dict[str, Any]]:
        """Return chunks sorted by blended score, with original relevance preserved for confidence output."""
        scored: List[tuple[float, Dict[str, Any]]] = []
        for chunk in knowledge_chunks:
            score = self._score_chunk_against_symptoms(chunk, symptoms)
            chunk['match_score'] = score
            primary_overlap = float(chunk.get('primary_overlap', 0.0))
            secondary_overlap = float(chunk.get('secondary_overlap', 0.0))
            relevance = float(chunk.get('relevance', 0.0))
            has_grounded_match = (
                primary_overlap > 0.0
                or (secondary_overlap >= 0.5 and relevance >= 0.45)
                or score >= 0.58
            )
            if not has_grounded_match:
                continue
            scored.append((score, chunk))

        scored.sort(key=lambda item: item[0], reverse=True)
        return [item[1] for item in scored]
    
    async def _retrieve_medical_knowledge(
        self,
        symptoms: List[str],
        max_results: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Retrieve relevant medical knowledge from RAG system
        
        Args:
            symptoms: List of symptoms to search for
            max_results: Maximum number of results to return
            
        Returns:
            List of relevant knowledge chunks
        """
        try:
            if self.rag_service is None:
                return []

            # Create search query from symptoms
            query_text = f"Symptoms: {', '.join(symptoms)}. What medical conditions are associated with these symptoms?"
            
            # Search RAG knowledge base
            rag_query = RAGQuery(
                query_text=query_text,
                max_results=max_results,
                min_certainty=0.35
            )

            results = await self.rag_service.search_similar_conditions(rag_query)

            # Retry with a looser threshold if strict matching returns too few
            # candidates for the Mini-Me top-3 symptom explanation.
            if len(results) < min(3, max_results):
                rag_query = RAGQuery(
                    query_text=query_text,
                    max_results=max_results,
                    min_certainty=0.0
                )
                results = await self.rag_service.search_similar_conditions(rag_query)
            
            # Format results for prompt
            knowledge_chunks = []
            for result in results:
                knowledge_chunks.append({
                    'condition': result.condition,
                    'content': result.content,
                    'relevance': result.relevance_score,
                    'source': result.source,
                    'metadata': result.metadata
                })

            knowledge_chunks = self._rerank_knowledge_chunks(knowledge_chunks, symptoms)
            
            logger.info(f"Retrieved {len(knowledge_chunks)} knowledge chunks from RAG")
            return knowledge_chunks
            
        except Exception as e:
            logger.error(f"Failed to retrieve medical knowledge: {e}")
            return []

    def _build_rag_fallback_analysis(
        self,
        symptom_input: SymptomInput,
        knowledge_chunks: List[Dict[str, Any]],
        urgency: UrgencyLevel,
    ) -> str:
        """Build a useful fallback when Gemini is unavailable/rate-limited."""
        lines = [
            "Gemini is temporarily unavailable, so this response is based on your local vetted medical knowledge index.",
            "",
            f"Symptoms reported: {', '.join(symptom_input.symptoms)}",
            f"Urgency level: {urgency.value}",
            "",
        ]

        if knowledge_chunks:
            lines.append("Likely related conditions (from knowledge base):")
            for chunk in knowledge_chunks[:3]:
                condition = chunk.get("condition", "Unknown")
                relevance = float(chunk.get("relevance", 0.0))
                source = chunk.get("source", "Unknown source")
                lines.append(f"- {condition} (relevance {relevance:.2f}, source: {source})")

            lines.extend([
                "",
                "Recommended next steps:",
                "- Monitor symptoms closely over the next 24 hours.",
                "- Seek urgent care if symptoms worsen or new severe symptoms appear.",
                "- Contact a clinician for diagnosis and treatment confirmation.",
            ])
        else:
            lines.extend([
                "No close condition match was found in the current knowledge base.",
                "",
                "Recommended next steps:",
                "- Track symptom changes, including fever, pain level, and duration.",
                "- Arrange medical evaluation if symptoms persist or worsen.",
                "- Use emergency services immediately for severe warning signs.",
            ])

        lines.extend([
            "",
            "This information is educational only and not a medical diagnosis. Please consult a qualified healthcare provider for proper evaluation and treatment.",
        ])

        return "\n".join(lines)
    
    def _parse_structured_predictions(
        self,
        text: str,
    ) -> tuple[list, str, list, list]:
        """
        Parse Gemini JSON response into (predictions, summary, self_care, warning_signs).
        Falls back gracefully if JSON is malformed.
        """
        import re
        # Strip markdown code fences if present
        cleaned = re.sub(r'^```(?:json)?\s*', '', text.strip(), flags=re.MULTILINE)
        cleaned = re.sub(r'```\s*$', '', cleaned.strip())

        try:
            data = json.loads(cleaned)
        except Exception:
            # JSON parse failed — return the raw text as summary with no predictions
            return [], text.strip(), [], []

        predictions_raw = data.get('predictions', [])
        predictions = []
        for p in predictions_raw[:3]:
            predictions.append(ConditionPrediction(
                condition=str(p.get('condition', 'Unknown')).strip(),
                confidence=float(p.get('confidence', 0.5)),
                description=str(p.get('description', '')).strip(),
                severity=str(p.get('severity', 'moderate')).strip(),
                when_to_seek_care=str(p.get('when_to_seek_care', '')).strip(),
            ))

        summary = str(data.get('summary', '')).strip()
        self_care = [str(s).strip() for s in data.get('self_care_recommendations', []) if str(s).strip()]
        warning_signs = [str(s).strip() for s in data.get('warning_signs', []) if str(s).strip()]
        return predictions, summary, self_care, warning_signs

    def _build_rag_grounded_prompt(
        self,
        symptom_input: SymptomInput,
        knowledge_chunks: List[Dict[str, Any]]
    ) -> str:
        """
        Build a prompt grounded in retrieved medical knowledge.
        Returns a JSON-structured response with top 3 predictions.
        """
        symptoms_text = ", ".join(symptom_input.symptoms)

        demographics = []
        if symptom_input.age:
            demographics.append(f"Age: {symptom_input.age}")
        if symptom_input.sex:
            demographics.append(f"Sex: {symptom_input.sex}")
        if symptom_input.duration:
            demographics.append(f"Duration: {symptom_input.duration}")
        demographics_text = "\n".join(demographics) if demographics else "Not provided"

        knowledge_text = ""
        if knowledge_chunks:
            knowledge_text = "VETTED MEDICAL KNOWLEDGE (use as primary source):\n"
            for i, chunk in enumerate(knowledge_chunks, 1):
                knowledge_text += f"{i}. {chunk['condition']} (relevance {chunk['relevance']:.2f}): {chunk['content']}\n"

        prompt = f"""You are a medical information assistant. Analyze the reported symptoms and return ONLY valid JSON — no markdown, no extra text.

{knowledge_text if knowledge_text else "No specific conditions found in knowledge base. Use general medical knowledge."}

Patient: {demographics_text}
Symptoms: {symptoms_text}
{f"Additional context: {symptom_input.additional_info}" if symptom_input.additional_info else ""}

Return exactly this JSON structure (top 3 predictions, ordered most-likely first):
{{
  "predictions": [
    {{
      "condition": "<condition name>",
      "confidence": <0.0-1.0>,
      "description": "<2-3 sentence explanation>",
      "severity": "<mild|moderate|severe>",
      "when_to_seek_care": "<specific guidance>"
    }}
  ],
  "summary": "<1-2 sentence overall assessment>",
  "self_care_recommendations": ["<recommendation 1>", "<recommendation 2>", "<recommendation 3>"],
  "warning_signs": ["<sign to watch for 1>", "<sign to watch for 2>"]
}}

Requirements:
- Exactly 3 predictions
- confidence values must sum to no more than 2.0 and each be between 0.1 and 0.95
- Only suggest conditions grounded in the knowledge base above
- End summary with: This information is educational only and not a medical diagnosis."""

        return prompt

    def _build_rag_only_result(
        self,
        symptom_input: SymptomInput,
        knowledge_chunks: List[Dict[str, Any]],
        urgency: 'UrgencyLevel',
        start_time: float,
    ) -> 'SymptomAnalysisResult':
        """
        Build a full SymptomAnalysisResult directly from RAG results,
        with no Gemini call required.
        """
        predictions = []
        for chunk in knowledge_chunks[:3]:
            meta = chunk.get('metadata', {})
            condition = chunk.get('condition', 'Unknown condition')
            relevance = float(chunk.get('match_score', chunk.get('relevance', 0.5)))
            description = chunk.get('content', '')
            severity = meta.get('severity', 'moderate')
            when_to_seek = meta.get('when_to_seek_care', '')
            # Strip the markdown bold header line from content if present
            description_lines = [
                l for l in description.splitlines()
                if not l.strip().startswith('**') or len(l.strip()) > len(condition) + 4
            ]
            clean_description = ' '.join(description_lines).strip()

            predictions.append(ConditionPrediction(
                condition=condition,
                confidence=round(min(0.95, max(0.1, relevance)), 2),
                description=clean_description or f"Condition associated with reported symptoms.",
                severity=severity,
                when_to_seek_care=when_to_seek or "Consult a healthcare provider if symptoms persist or worsen.",
            ))

        top = predictions[0].condition if predictions else "reported symptoms"
        summary = (
            f"Based on your symptoms, the most likely match is {top}. "
            "This information is educational only and not a medical diagnosis."
        )

        response_time = int((time.time() - start_time) * 1000)
        sources = [chunk['source'] for chunk in knowledge_chunks]

        return SymptomAnalysisResult(
            urgency=urgency,
            analysis=summary,
            predictions=predictions if predictions else None,
            self_care_recommendations=[
                "Monitor your symptoms and note any changes.",
                "Stay hydrated and rest if needed.",
                "Contact a healthcare provider if symptoms worsen.",
            ],
            warning_signs=[
                "Symptoms become severe or sudden.",
                "Difficulty breathing or chest pain.",
                "High fever (above 39°C / 102°F).",
            ],
            knowledge_sources=sources,
            confidence_score=self._estimate_confidence(knowledge_chunks),
            source="rag",
            response_time_ms=response_time,
        )

    async def analyze_symptoms(
        self,
        symptom_input: SymptomInput
    ) -> SymptomAnalysisResult:
        """
        Complete symptom analysis pipeline.

        Disease prediction intentionally uses the app's own DisEmbed-backed
        medical knowledge retrieval path only. Gemini is not called here;
        it remains available to other endpoints that refine Mini-Me wording.
        """
        start_time = time.time()

        # Step 1: Check for emergency symptoms
        urgency = self._check_urgency(symptom_input.symptoms)

        if urgency == UrgencyLevel.EMERGENCY:
            response_time = int((time.time() - start_time) * 1000)
            return SymptomAnalysisResult(
                urgency=urgency,
                analysis=self._build_emergency_response(symptom_input.symptoms),
                source="emergency_detection",
                response_time_ms=response_time
            )

        # Step 2: Retrieve relevant medical knowledge from RAG
        knowledge_chunks = []
        try:
            knowledge_chunks = await self._retrieve_medical_knowledge(
                symptom_input.symptoms,
                max_results=10
            )
        except Exception as rag_err:
            logger.warning(f"RAG retrieval failed: {rag_err}")

        # Step 3: RAG-only prediction — no Gemini needed
        if knowledge_chunks:
            logger.info("Returning DisEmbed/RAG-only symptom predictions.")
            return self._build_rag_only_result(symptom_input, knowledge_chunks, urgency, start_time)

        # Step 4: Nothing available — return a safe no-data response
        response_time = int((time.time() - start_time) * 1000)
        return SymptomAnalysisResult(
            urgency=urgency,
            analysis=(
                "No matching conditions found in the knowledge base and AI analysis is currently unavailable. "
                "Please consult a healthcare provider for an accurate assessment. "
                "This information is educational only and not a medical diagnosis."
            ),
            source="fallback",
            response_time_ms=response_time,
        )

    def _estimate_confidence(self, knowledge_chunks: List[Dict[str, Any]]) -> float:
        """
        Estimate confidence based on RAG retrieval quality
        
        Args:
            knowledge_chunks: Retrieved knowledge chunks
            
        Returns:
            Confidence score between 0 and 1
        """
        if not knowledge_chunks:
            return 0.3  # Low confidence without knowledge base support
        
        # Calculate average relevance score
        avg_relevance = sum(chunk['relevance'] for chunk in knowledge_chunks) / len(knowledge_chunks)
        
        # Boost confidence if we have multiple good matches
        if len(knowledge_chunks) >= 3 and avg_relevance > 0.75:
            return min(0.9, avg_relevance + 0.1)
        
        return avg_relevance
    
    async def batch_analyze_symptoms(
        self,
        symptom_inputs: List[SymptomInput]
    ) -> List[SymptomAnalysisResult]:
        """
        Analyze multiple symptom inputs in batch
        
        Args:
            symptom_inputs: List of symptom inputs to analyze
            
        Returns:
            List of analysis results
        """
        tasks = [self.analyze_symptoms(input_data) for input_data in symptom_inputs]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Convert exceptions to error results
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"Batch analysis failed for input {i}: {result}")
                processed_results.append(
                    SymptomAnalysisResult(
                        urgency=UrgencyLevel.INFORMATIONAL,
                        analysis=f"Analysis failed: {str(result)}",
                        source="error"
                    )
                )
            else:
                processed_results.append(result)
        
        return processed_results
    
    @staticmethod
    def get_disclaimer() -> str:
        """Get medical disclaimer text"""
        return """
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  IMPORTANT MEDICAL DISCLAIMER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This tool provides general health information only and is NOT:
  ❌ A substitute for professional medical advice
  ❌ A medical diagnosis or treatment plan
  ❌ Emergency medical service
  ❌ A replacement for seeing a doctor

✅ ALWAYS consult a qualified healthcare provider for:
  • Accurate diagnosis
  • Treatment recommendations
  • Medical emergencies
  • Persistent or worsening symptoms

🚨 IF EXPERIENCING A MEDICAL EMERGENCY, CALL 911 IMMEDIATELY

Information provided is based on general medical knowledge and may not
apply to your specific situation. Your healthcare provider can consider
your complete medical history and perform necessary examinations.

By using this tool, you acknowledge these limitations.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""


# Singleton instance
_analysis_service: Optional[GeminiAnalysisService] = None


def get_analysis_service() -> GeminiAnalysisService:
    """Get or create analysis service singleton"""
    global _analysis_service
    if _analysis_service is None:
        _analysis_service = GeminiAnalysisService()
    return _analysis_service
