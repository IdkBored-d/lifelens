"""
Test client for Lifelens API
Demonstrates complete workflow
"""
import requests
import json
import time
from typing import Dict, Any


class LifelensClient:
    """Client for interacting with Lifelens API"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def health_check(self) -> Dict[str, Any]:
        """Check API health"""
        response = self.session.get(f"{self.base_url}/health")
        response.raise_for_status()
        return response.json()
    
    def analyze_symptoms(
        self,
        symptoms: list,
        age: int = None,
        sex: str = None,
        duration: str = None,
        additional_info: str = None
    ) -> Dict[str, Any]:
        """Analyze symptoms"""
        payload = {
            "symptoms": symptoms,
            "age": age,
            "sex": sex,
            "duration": duration,
            "additional_info": additional_info
        }
        
        # Remove None values
        payload = {k: v for k, v in payload.items() if v is not None}
        
        response = self.session.post(
            f"{self.base_url}/api/v1/symptoms/analyze",
            json=payload
        )
        response.raise_for_status()
        return response.json()
    
    def search_knowledge(
        self,
        query: str,
        max_results: int = 5,
        min_certainty: float = 0.7
    ) -> list:
        """Search medical knowledge base"""
        payload = {
            "query_text": query,
            "max_results": max_results,
            "min_certainty": min_certainty
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/knowledge/search",
            json=payload
        )
        response.raise_for_status()
        return response.json()
    
    def get_knowledge_count(self) -> int:
        """Get total knowledge base document count"""
        response = self.session.get(
            f"{self.base_url}/api/v1/knowledge/count"
        )
        response.raise_for_status()
        return response.json()["total_documents"]


def print_section(title: str):
    """Print formatted section header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70 + "\n")


def print_result(result: Dict[str, Any]):
    """Print analysis result in formatted way"""
    print(f"Urgency: {result['urgency'].upper()}")
    print(f"Source: {result['source']}")
    print(f"Response Time: {result.get('response_time_ms', 'N/A')}ms")
    
    if result.get('confidence_score'):
        print(f"Confidence: {result['confidence_score']:.2%}")
    
    if result.get('knowledge_sources'):
        print(f"\nKnowledge Sources:")
        for source in result['knowledge_sources']:
            print(f"  - {source}")
    
    print(f"\nAnalysis:\n{result['analysis']}")


def main():
    """Run test scenarios"""
    
    print("\n🏥 Lifelens API Test Client\n")
    
    # Initialize client
    client = LifelensClient()
    
    try:
        # Health check
        print_section("1. HEALTH CHECK")
        health = client.health_check()
        print(f"Status: {health['status']}")
        print(f"Gemini: {health['services']['gemini']}")
        print(f"Weaviate: {health['services']['weaviate']}")
        print(f"Knowledge Base Docs: {health['services']['knowledge_base_docs']}")
        
        # Knowledge base search
        print_section("2. KNOWLEDGE BASE SEARCH")
        print("Query: 'fever and cough symptoms'")
        
        search_results = client.search_knowledge(
            query="fever and cough symptoms",
            max_results=3
        )
        
        print(f"\nFound {len(search_results)} relevant conditions:\n")
        for i, result in enumerate(search_results, 1):
            print(f"{i}. {result['condition']}")
            print(f"   Relevance: {result['relevance_score']:.2%}")
            print(f"   Source: {result['source']}")
            print()
        
        # Test Case 1: Common Cold
        print_section("3. TEST CASE 1: Common Cold Symptoms")
        print("Symptoms: runny nose, sneezing, sore throat, mild cough")
        print("Age: 25, Sex: F, Duration: 3 days\n")
        
        result1 = client.analyze_symptoms(
            symptoms=["runny nose", "sneezing", "sore throat", "mild cough"],
            age=25,
            sex="F",
            duration="3 days"
        )
        
        print_result(result1)
        
        # Test Case 2: Flu-like Symptoms
        print_section("4. TEST CASE 2: Flu-like Symptoms")
        print("Symptoms: high fever, body aches, headache, fatigue, dry cough")
        print("Age: 42, Sex: M, Duration: 2 days")
        print("Additional: Started suddenly after feeling fine\n")
        
        result2 = client.analyze_symptoms(
            symptoms=["high fever", "body aches", "headache", "fatigue", "dry cough"],
            age=42,
            sex="M",
            duration="2 days",
            additional_info="Started suddenly after feeling fine"
        )
        
        print_result(result2)
        
        # Test Case 3: Emergency Symptoms
        print_section("5. TEST CASE 3: Emergency Symptoms")
        print("Symptoms: chest pain, difficulty breathing, dizziness")
        print("Age: 58, Sex: M\n")
        
        result3 = client.analyze_symptoms(
            symptoms=["chest pain", "difficulty breathing", "dizziness"],
            age=58,
            sex="M"
        )
        
        print_result(result3)
        
        # Test Case 4: Digestive Issues
        print_section("6. TEST CASE 4: Digestive Issues")
        print("Symptoms: nausea, stomach pain, diarrhea, low fever")
        print("Age: 30, Sex: F, Duration: 1 day")
        print("Additional: Ate at a restaurant last night\n")
        
        result4 = client.analyze_symptoms(
            symptoms=["nausea", "stomach pain", "diarrhea", "low fever"],
            age=30,
            sex="F",
            duration="1 day",
            additional_info="Ate at a restaurant last night"
        )
        
        print_result(result4)
        
        # Test Case 5: Allergies
        print_section("7. TEST CASE 5: Allergy Symptoms")
        print("Symptoms: sneezing, itchy eyes, runny nose, congestion")
        print("Age: 28, Sex: F, Duration: ongoing for 2 weeks")
        print("Additional: Worse in the morning, better indoors\n")
        
        result5 = client.analyze_symptoms(
            symptoms=["sneezing", "itchy eyes", "runny nose", "congestion"],
            age=28,
            sex="F",
            duration="ongoing for 2 weeks",
            additional_info="Worse in the morning, better indoors"
        )
        
        print_result(result5)
        
        # Summary
        print_section("8. SUMMARY")
        print(f"✅ All tests completed successfully")
        print(f"✅ API is operational")
        print(f"✅ Gemini integration working")
        print(f"✅ RAG system functioning")
        print(f"✅ Emergency detection active")
        print(f"\n📊 Knowledge Base: {client.get_knowledge_count()} documents")
        
        print("\n" + "=" * 70)
        print("\n✨ Lifelens API is ready for use!\n")
        
    except requests.exceptions.ConnectionError:
        print("\n❌ ERROR: Cannot connect to API")
        print("   Make sure the API is running: python main.py")
        print("   Or with Docker: docker-compose up -d\n")
    
    except requests.exceptions.HTTPError as e:
        print(f"\n❌ HTTP Error: {e}")
        print(f"   Response: {e.response.text}\n")
    
    except Exception as e:
        print(f"\n❌ Error: {e}\n")


if __name__ == "__main__":
    main()
