"""
Gemini API Service for Symptom Analysis
Integrates with RAG system for grounded medical responses
"""
from google import genai
from google.genai import types
from typing import List, Optional, Dict, Any
import logging
import time
from datetime import datetime
import asyncio

from models.schemas import (
    SymptomInput,
    SymptomAnalysisResult,
    UrgencyLevel,
    ConditionPrediction,
    RAGQuery
)
from services.rag_service import get_rag_service
from config.settings import get_settings

logger = logging.getLogger(__name__)


class GeminiAnalysisService:
    """
    Complete Gemini API integration for symptom analysis
    Uses RAG for grounded responses and prevents hallucinations
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
        'unresponsive', 'blue lips', 'blue skin'
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
        self.client = genai.Client(api_key=self.settings.gemini_api_key)
        self.rag_service = get_rag_service()
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
            # Create search query from symptoms
            query_text = f"Symptoms: {', '.join(symptoms)}. What medical conditions are associated with these symptoms?"
            
            # Search RAG knowledge base
            rag_query = RAGQuery(
                query_text=query_text,
                max_results=max_results,
                min_certainty=0.65
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
            
            logger.info(f"Retrieved {len(knowledge_chunks)} knowledge chunks from RAG")
            return knowledge_chunks
            
        except Exception as e:
            logger.error(f"Failed to retrieve medical knowledge: {e}")
            return []
    
    def _build_rag_grounded_prompt(
        self,
        symptom_input: SymptomInput,
        knowledge_chunks: List[Dict[str, Any]]
    ) -> str:
        """
        Build a prompt grounded in retrieved medical knowledge
        
        Args:
            symptom_input: User's symptom information
            knowledge_chunks: Retrieved medical knowledge
            
        Returns:
            Formatted prompt for Gemini
        """
        # Format symptoms
        symptoms_text = ", ".join(symptom_input.symptoms)
        
        # Format demographics
        demographics = []
        if symptom_input.age:
            demographics.append(f"Age: {symptom_input.age}")
        if symptom_input.sex:
            demographics.append(f"Sex: {symptom_input.sex}")
        if symptom_input.duration:
            demographics.append(f"Duration: {symptom_input.duration}")
        
        demographics_text = "\n".join(demographics) if demographics else "Not provided"
        
        # Format retrieved knowledge
        knowledge_text = ""
        if knowledge_chunks:
            knowledge_text = "\n\n**VETTED MEDICAL KNOWLEDGE (use this as your primary source):**\n\n"
            
            for i, chunk in enumerate(knowledge_chunks, 1):
                knowledge_text += f"{i}. **{chunk['condition']}** (Relevance: {chunk['relevance']:.2f})\n"
                knowledge_text += f"   Source: {chunk['source']}\n"
                knowledge_text += f"   {chunk['content']}\n\n"
        
        # Build complete prompt
        prompt = f"""You are a medical information assistant helping users understand their symptoms. You must base your response primarily on the VETTED MEDICAL KNOWLEDGE provided below.

{knowledge_text if knowledge_text else "**NOTE:** No specific matching conditions found in knowledge base. Provide general guidance only and strongly recommend consulting a healthcare provider."}

**PATIENT INFORMATION:**
{demographics_text}

**REPORTED SYMPTOMS:**
{symptoms_text}

{f"**ADDITIONAL CONTEXT:** {symptom_input.additional_info}" if symptom_input.additional_info else ""}

**YOUR TASK:**
Provide a clear, helpful health assessment with the following sections:

1. **Possible Conditions** (3-5 possibilities based on the knowledge above)
   - List conditions in order of likelihood based on symptom match
   - For each condition: brief explanation (2-3 sentences)
   - Include approximate confidence (High/Medium/Low)
   - **IMPORTANT:** Only suggest conditions supported by the knowledge base above

2. **When to Seek Medical Care**
   - Specify urgency: immediate attention, within 24 hours, or routine appointment
   - List specific warning signs to watch for
   - Be clear about when to call 911 or go to ER

3. **Self-Care Recommendations**
   - What can be done at home to manage symptoms
   - Over-the-counter treatments that might help
   - Lifestyle modifications
   - **Only recommend what is mentioned in the knowledge base or is generally safe**

4. **Important Notes**
   - Are there serious conditions that should be ruled out?
   - What additional information would help narrow diagnosis?
   - Remind that this is informational, not a diagnosis

**CRITICAL REQUIREMENTS:**
- Use clear, simple language (avoid medical jargon)
- Be empathetic and reassuring while accurate
- If symptoms don't match knowledge base well, say so explicitly
- Do NOT speculate beyond what's in the knowledge base
- Always emphasize consulting a healthcare provider
- If unsure, err on side of recommending medical evaluation
- Keep response to 300-400 words maximum

**MEDICAL DISCLAIMER:** End with: "This information is educational only and not a medical diagnosis. Please consult a qualified healthcare provider for proper evaluation and treatment."
"""
        
        return prompt
    
    async def analyze_symptoms(
        self,
        symptom_input: SymptomInput
    ) -> SymptomAnalysisResult:
        """
        Complete symptom analysis pipeline
        
        Args:
            symptom_input: User's symptom information
            
        Returns:
            Complete analysis result with recommendations
        """
        start_time = time.time()
        
        try:
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
            knowledge_chunks = await self._retrieve_medical_knowledge(
                symptom_input.symptoms,
                max_results=5
            )
            
            # Step 3: Build grounded prompt
            prompt = self._build_rag_grounded_prompt(symptom_input, knowledge_chunks)
            
            # Step 4: Call Gemini API
            logger.info("Calling Gemini API for symptom analysis")
            
            response = self.client.models.generate_content(
                model='gemini-2.5-flash-lite',
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.2,  # Low temperature for consistent medical advice
                    top_p=0.85,
                    top_k=40,
                    max_output_tokens=2000,
                    candidate_count=1
                )
            )
            
            # Step 5: Extract and validate response
            analysis_text = response.text
            
            # Calculate response time
            response_time = int((time.time() - start_time) * 1000)
            
            # Extract knowledge sources
            sources = [chunk['source'] for chunk in knowledge_chunks]
            
            # Build result
            result = SymptomAnalysisResult(
                urgency=urgency,
                analysis=analysis_text,
                knowledge_sources=sources,
                confidence_score=self._estimate_confidence(knowledge_chunks),
                source="gemini_rag" if knowledge_chunks else "gemini_direct",
                response_time_ms=response_time
            )
            
            logger.info(f"Analysis completed in {response_time}ms")
            return result
            
        except Exception as e:
            logger.error(f"Symptom analysis failed: {e}")
            response_time = int((time.time() - start_time) * 1000)
            
            # Return error result
            return SymptomAnalysisResult(
                urgency=UrgencyLevel.INFORMATIONAL,
                analysis=f"⚠️ Unable to complete analysis due to technical error: {str(e)}\n\n"
                         f"Please try again or consult a healthcare provider directly.",
                source="error",
                response_time_ms=response_time
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
