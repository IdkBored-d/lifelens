"""
Load sample medical knowledge into Weaviate
This script populates the knowledge base with common conditions
"""
import asyncio
import sys
import os
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.schemas import MedicalKnowledgeDoc
from services.rag_service import get_rag_service
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# Sample medical knowledge data
SAMPLE_KNOWLEDGE = [
    {
        "condition": "Common Cold",
        "symptoms": [
            "runny nose", "stuffy nose", "sneezing", "sore throat",
            "cough", "mild headache", "low-grade fever", "fatigue"
        ],
        "description": "The common cold is a viral infection of the upper respiratory tract. "
                      "It's typically caused by rhinoviruses and is highly contagious. Most people "
                      "recover within 7-10 days without medical treatment.",
        "severity": "mild",
        "treatment": "Rest, stay hydrated, use over-the-counter pain relievers for discomfort. "
                    "Decongestants and cough suppressants may help with symptoms. Vitamin C and zinc "
                    "may slightly reduce duration.",
        "when_to_seek_care": "Seek medical care if symptoms last more than 10 days, fever is high "
                           "(>101.3°F/38.5°C) or persistent, you have severe symptoms, or difficulty breathing.",
        "risk_factors": ["close contact with infected persons", "weak immune system", "young age", "stress"],
        "complications": ["sinus infection", "ear infection", "bronchitis", "pneumonia"],
        "source": "CDC - Common Cold Information"
    },
    {
        "condition": "Influenza (Flu)",
        "symptoms": [
            "high fever", "body aches", "headache", "fatigue",
            "dry cough", "sore throat", "chills", "muscle pain"
        ],
        "description": "Influenza is a viral respiratory infection that's more severe than the common cold. "
                      "It comes on suddenly and can cause serious complications, especially in high-risk groups. "
                      "Annual vaccination is the best prevention.",
        "severity": "moderate",
        "treatment": "Antiviral medications (oseltamivir, zanamivir) if started within 48 hours. "
                    "Rest, fluids, and over-the-counter medications for symptom relief. Avoid aspirin in children.",
        "when_to_seek_care": "Seek immediate care for difficulty breathing, chest pain, severe dizziness, "
                           "confusion, or symptoms that improve then worsen. High-risk individuals should "
                           "contact their doctor at symptom onset.",
        "risk_factors": ["no flu vaccination", "age >65 or <5", "pregnancy", "chronic conditions", "weak immune system"],
        "complications": ["pneumonia", "bronchitis", "sinus infections", "ear infections", "myocarditis", "death"],
        "source": "CDC - Influenza Information"
    },
    {
        "condition": "Migraine Headache",
        "symptoms": [
            "severe headache", "throbbing pain", "nausea", "vomiting",
            "sensitivity to light", "sensitivity to sound", "visual disturbances", "aura"
        ],
        "description": "Migraines are intense headaches often accompanied by nausea and sensitivity to light "
                      "and sound. They can last hours to days and may be preceded by warning signs (aura). "
                      "Triggers include stress, certain foods, hormonal changes, and sleep disturbances.",
        "severity": "moderate",
        "treatment": "Pain relievers (ibuprofen, acetaminophen), triptans for severe cases, anti-nausea medications. "
                    "Rest in dark, quiet room. Preventive medications may be prescribed for frequent migraines. "
                    "Identify and avoid triggers.",
        "when_to_seek_care": "Seek immediate care for sudden, severe headache ('thunderclap'), headache with "
                           "fever, stiff neck, confusion, vision changes, difficulty speaking, or numbness. "
                           "See a doctor if migraines are frequent or interfering with daily life.",
        "risk_factors": ["family history", "female sex", "hormonal changes", "age 10-40", "stress"],
        "complications": ["medication overuse headache", "status migrainosus", "stroke", "chronic migraine"],
        "source": "Mayo Clinic - Migraine Information"
    },
    {
        "condition": "Gastroenteritis (Stomach Flu)",
        "symptoms": [
            "diarrhea", "nausea", "vomiting", "stomach cramps",
            "abdominal pain", "low-grade fever", "dehydration", "loss of appetite"
        ],
        "description": "Gastroenteritis is inflammation of the digestive tract, usually caused by viral or "
                      "bacterial infection. It's highly contagious and spreads through contaminated food, water, "
                      "or contact with infected individuals. Most cases resolve within a few days.",
        "severity": "mild to moderate",
        "treatment": "Stay hydrated with clear liquids, oral rehydration solutions. Gradually return to bland diet "
                    "(BRAT diet: bananas, rice, applesauce, toast). Anti-diarrheal medications may help. "
                    "Avoid dairy, caffeine, alcohol, and fatty foods until recovered.",
        "when_to_seek_care": "Seek care for signs of severe dehydration (extreme thirst, dark urine, dizziness), "
                           "bloody or black stools, high fever (>102°F/39°C), severe abdominal pain, vomiting for "
                           ">24 hours, or symptoms lasting >3 days.",
        "risk_factors": ["contaminated food or water", "poor hand hygiene", "close contact with infected persons", "weakened immunity"],
        "complications": ["severe dehydration", "electrolyte imbalance", "kidney failure", "sepsis"],
        "source": "Mayo Clinic - Gastroenteritis"
    },
    {
        "condition": "Urinary Tract Infection (UTI)",
        "symptoms": [
            "painful urination", "frequent urination", "urgency to urinate",
            "cloudy urine", "strong-smelling urine", "pelvic pain", "lower back pain", "blood in urine"
        ],
        "description": "A urinary tract infection is a bacterial infection affecting any part of the urinary system "
                      "(kidneys, bladder, ureters, urethra). Most UTIs affect the bladder and urethra. Women are "
                      "at higher risk. Prompt treatment with antibiotics prevents complications.",
        "severity": "mild to moderate",
        "treatment": "Antibiotics prescribed by healthcare provider (trimethoprim-sulfamethoxazole, nitrofurantoin, "
                    "or others). Drink plenty of water. Cranberry products may help prevent recurrence. "
                    "Complete full course of antibiotics even if symptoms improve.",
        "when_to_seek_care": "See a doctor if you have UTI symptoms, especially fever, chills, nausea, vomiting, "
                           "or back/side pain (signs of kidney infection). Seek immediate care for severe symptoms "
                           "or if you're pregnant.",
        "risk_factors": ["female anatomy", "sexual activity", "certain birth control", "menopause", "urinary tract abnormalities", "catheter use"],
        "complications": ["kidney infection (pyelonephritis)", "recurrent infections", "kidney damage", "sepsis", "urethral narrowing"],
        "source": "Mayo Clinic - UTI Information"
    },
    {
        "condition": "Allergic Rhinitis (Hay Fever)",
        "symptoms": [
            "sneezing", "runny nose", "stuffy nose", "itchy nose",
            "itchy eyes", "watery eyes", "postnasal drip", "cough", "fatigue"
        ],
        "description": "Allergic rhinitis is an allergic reaction to airborne allergens like pollen, dust mites, "
                      "pet dander, or mold. It can be seasonal (hay fever) or year-round (perennial). Symptoms "
                      "occur when the immune system overreacts to allergens.",
        "severity": "mild",
        "treatment": "Antihistamines (cetirizine, loratadine, fexofenadine), nasal corticosteroid sprays, "
                    "decongestants. Allergen avoidance is key. Consider allergy testing and immunotherapy "
                    "(allergy shots) for severe cases. Nasal irrigation may help.",
        "when_to_seek_care": "See a doctor if symptoms interfere with daily activities, over-the-counter medications "
                           "don't help, or you experience side effects from medications. Consider allergy specialist "
                           "referral for persistent symptoms.",
        "risk_factors": ["family history of allergies", "asthma", "eczema", "exposure to allergens"],
        "complications": ["sinusitis", "ear infections", "sleep disturbances", "asthma exacerbation"],
        "source": "American Academy of Allergy, Asthma & Immunology"
    },
    {
        "condition": "Anxiety Disorder",
        "symptoms": [
            "excessive worry", "restlessness", "difficulty concentrating",
            "irritability", "muscle tension", "sleep disturbances", "rapid heartbeat",
            "sweating", "trembling", "fatigue"
        ],
        "description": "Anxiety disorders involve persistent, excessive worry and fear about everyday situations. "
                      "Physical symptoms often accompany mental distress. Several types exist including generalized "
                      "anxiety disorder, panic disorder, and social anxiety disorder. Treatment is highly effective.",
        "severity": "mild to moderate",
        "treatment": "Cognitive behavioral therapy (CBT) is first-line treatment. Medications may include SSRIs, "
                    "SNRIs, or benzodiazepines (short-term). Lifestyle changes: regular exercise, adequate sleep, "
                    "stress management, mindfulness, limiting caffeine and alcohol. Support groups can help.",
        "when_to_seek_care": "Seek help if anxiety interferes with work, relationships, or daily activities, "
                           "causes significant distress, or leads to avoidance behaviors. Seek immediate help "
                           "for suicidal thoughts or self-harm urges.",
        "risk_factors": ["family history", "personality traits", "trauma", "chronic stress", "other mental health conditions"],
        "complications": ["depression", "substance abuse", "social isolation", "impaired functioning", "physical health problems"],
        "source": "National Institute of Mental Health - Anxiety Disorders"
    },
    {
        "condition": "Type 2 Diabetes",
        "symptoms": [
            "increased thirst", "frequent urination", "increased hunger",
            "fatigue", "blurred vision", "slow-healing sores", "frequent infections",
            "numbness or tingling", "unintended weight loss"
        ],
        "description": "Type 2 diabetes is a chronic condition affecting how the body processes blood sugar (glucose). "
                      "The body becomes resistant to insulin or doesn't produce enough. It's often preventable and "
                      "manageable with lifestyle changes and medication. Risk increases with age, obesity, and inactivity.",
        "severity": "moderate to severe",
        "treatment": "Lifestyle modifications: healthy diet, regular exercise, weight loss. Medications: metformin "
                    "(first-line), other oral medications, or insulin. Regular blood sugar monitoring. "
                    "Annual eye exams, foot checks, and cardiovascular screening. Diabetes education classes.",
        "when_to_seek_care": "See a doctor if you have diabetes symptoms or risk factors for screening. "
                           "Seek immediate care for very high blood sugar (>600 mg/dL), ketoacidosis symptoms "
                           "(fruity breath, nausea, difficulty breathing), or severe hypoglycemia (confusion, seizures).",
        "risk_factors": ["overweight/obesity", "age >45", "family history", "physical inactivity", "prediabetes", "gestational diabetes"],
        "complications": ["heart disease", "stroke", "neuropathy", "kidney disease", "eye damage", "foot damage", "infections"],
        "source": "American Diabetes Association"
    },
    {
        "condition": "Hypertension (High Blood Pressure)",
        "symptoms": [
            "often no symptoms", "headache", "shortness of breath",
            "nosebleeds", "dizziness", "chest pain", "vision changes"
        ],
        "description": "Hypertension is a condition where blood pressure is consistently too high (≥130/80 mmHg). "
                      "Often called the 'silent killer' because it usually has no symptoms but increases risk of "
                      "heart disease, stroke, and kidney disease. Regular screening is essential.",
        "severity": "moderate to severe",
        "treatment": "Lifestyle changes: DASH diet, reduce sodium, maintain healthy weight, regular exercise, "
                    "limit alcohol, quit smoking, stress management. Medications if needed: ACE inhibitors, "
                    "ARBs, diuretics, calcium channel blockers, beta-blockers. Regular monitoring required.",
        "when_to_seek_care": "Seek emergency care for blood pressure >180/120 with chest pain, shortness of breath, "
                           "back pain, numbness, vision changes, or difficulty speaking (hypertensive crisis). "
                           "See doctor for routine screening or if blood pressure is consistently elevated.",
        "risk_factors": ["age", "race", "family history", "obesity", "physical inactivity", "tobacco use", "high sodium diet", "stress", "chronic conditions"],
        "complications": ["heart attack", "stroke", "heart failure", "kidney disease", "vision loss", "dementia", "aneurysm"],
        "source": "American Heart Association"
    },
    {
        "condition": "Asthma",
        "symptoms": [
            "shortness of breath", "wheezing", "coughing", "chest tightness",
            "difficulty breathing", "worsening at night", "exercise-induced symptoms"
        ],
        "description": "Asthma is a chronic respiratory condition where airways become inflamed and narrow, "
                      "making breathing difficult. Symptoms vary in severity and frequency. Triggers include "
                      "allergens, exercise, cold air, smoke, and respiratory infections. Well-managed with proper treatment.",
        "severity": "mild to severe",
        "treatment": "Quick-relief inhalers (albuterol) for acute symptoms. Long-term control medications: "
                    "inhaled corticosteroids, leukotriene modifiers, long-acting bronchodilators. "
                    "Asthma action plan essential. Identify and avoid triggers. Peak flow monitoring. "
                    "Allergy treatment if applicable.",
        "when_to_seek_care": "Seek emergency care for severe shortness of breath, no improvement after quick-relief "
                           "inhaler, difficulty speaking, bluish lips or nails. See doctor if asthma symptoms occur "
                           "frequently, interfere with activities, or you use quick-relief inhaler >2 days/week.",
        "risk_factors": ["family history", "allergies", "respiratory infections", "occupational exposures", "smoking", "air pollution", "obesity"],
        "complications": ["permanent airway narrowing", "frequent hospitalizations", "pneumonia", "respiratory failure", "death"],
        "source": "National Heart, Lung, and Blood Institute"
    }
]


async def load_sample_data():
    """Load sample medical knowledge into Weaviate"""
    rag_service = None
    try:
        logger.info("Initializing RAG service...")
        rag_service = get_rag_service()
        
        # Check current document count
        current_count = await rag_service.get_document_count()
        logger.info(f"Current knowledge base has {current_count} documents")
        
        # Convert sample data to MedicalKnowledgeDoc objects
        documents = []
        for data in SAMPLE_KNOWLEDGE:
            doc = MedicalKnowledgeDoc(
                doc_id="",  # Will be auto-generated
                condition=data["condition"],
                symptoms=data["symptoms"],
                description=data["description"],
                severity=data["severity"],
                treatment=data["treatment"],
                when_to_seek_care=data["when_to_seek_care"],
                risk_factors=data.get("risk_factors"),
                complications=data.get("complications"),
                source=data["source"],
                last_updated=datetime.utcnow()
            )
            documents.append(doc)
        
        # Bulk add documents
        logger.info(f"Adding {len(documents)} medical knowledge documents...")
        result = await rag_service.bulk_add_knowledge(documents)
        
        logger.info("=" * 60)
        logger.info("LOAD RESULTS:")
        logger.info(f"Total documents: {result['total']}")
        logger.info(f"Successfully added: {result['successful']}")
        logger.info(f"Failed: {result['failed']}")
        
        if result['errors']:
            logger.warning("Errors encountered:")
            for error in result['errors']:
                logger.warning(f"  - {error}")
        
        # Verify final count
        final_count = await rag_service.get_document_count()
        logger.info(f"Knowledge base now has {final_count} documents")
        logger.info("=" * 60)
        
        # Test search
        logger.info("\nTesting search functionality...")
        from models.schemas import RAGQuery
        
        test_query = RAGQuery(
            query_text="I have a headache, fever, and body aches",
            max_results=3,
            min_certainty=0.6
        )
        
        results = await rag_service.search_similar_conditions(test_query)
        logger.info(f"Found {len(results)} relevant conditions:")
        for i, result in enumerate(results, 1):
            logger.info(f"{i}. {result.condition} (relevance: {result.relevance_score:.2f})")
        
        logger.info("\n✅ Sample data loaded successfully!")
        
    except Exception as e:
        logger.error(f"Failed to load sample data: {e}", exc_info=True)
        raise
    finally:
        if rag_service is not None:
            rag_service.close()


if __name__ == "__main__":
    asyncio.run(load_sample_data())