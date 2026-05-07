"""
Load additional medical condition knowledge into Weaviate.

This does not change or retrain the embedding model. The script creates
MedicalKnowledgeDoc records and lets the existing RAG service embed them with
the configured DisEmbedModel before inserting them into MedicalKnowledge.
"""
import asyncio
import logging
import os
import sys
from datetime import UTC, datetime
from typing import Iterable

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from models.schemas import MedicalKnowledgeDoc
from services.rag_service import get_rag_service


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


EXTENDED_KNOWLEDGE = [
    {
        "condition": "Dehydration",
        "symptoms": [
            "dizziness",
            "thirst",
            "dry mouth",
            "dark urine",
            "fatigue",
            "headache",
            "reduced urination",
            "lightheadedness",
        ],
        "description": "Dehydration happens when the body loses more fluid than it takes in. It can follow vomiting, diarrhea, heavy sweating, fever, heat exposure, or not drinking enough fluids.",
        "severity": "mild to severe",
        "treatment": "Drink water or oral rehydration solution, rest in a cool place, and replace electrolytes if fluid loss is significant. Severe dehydration may need urgent medical treatment and IV fluids.",
        "when_to_seek_care": "Seek urgent care for confusion, fainting, inability to keep fluids down, very little urination, rapid heartbeat, severe weakness, or dehydration in infants, older adults, or people with chronic illness.",
        "risk_factors": ["vomiting", "diarrhea", "fever", "heat exposure", "heavy sweating", "limited fluid intake"],
        "complications": ["heat injury", "kidney injury", "electrolyte imbalance", "shock"],
        "source": "MedlinePlus - Dehydration",
    },
    {
        "condition": "Benign Paroxysmal Positional Vertigo (BPPV)",
        "symptoms": [
            "dizziness",
            "vertigo",
            "spinning sensation",
            "loss of balance",
            "nausea",
            "vomiting",
            "triggered by head movement",
        ],
        "description": "BPPV is an inner-ear balance problem that causes brief episodes of vertigo, often triggered by rolling over, looking up, bending down, or turning the head.",
        "severity": "mild to moderate",
        "treatment": "A clinician may use canalith repositioning maneuvers. Avoid risky activities during episodes and rise slowly. Medication is usually not the main treatment.",
        "when_to_seek_care": "Seek medical care for new or recurrent vertigo. Seek emergency care if dizziness occurs with weakness, trouble speaking, chest pain, severe headache, fainting, or vision changes.",
        "risk_factors": ["older age", "head injury", "inner ear disorder", "prior vertigo"],
        "complications": ["falls", "injury", "activity limitation"],
        "source": "Mayo Clinic - BPPV",
    },
    {
        "condition": "Vestibular Neuritis or Labyrinthitis",
        "symptoms": [
            "sudden dizziness",
            "vertigo",
            "nausea",
            "vomiting",
            "balance problems",
            "hearing changes",
            "ear fullness",
        ],
        "description": "Vestibular neuritis and labyrinthitis are inner-ear conditions that can cause sudden vertigo and balance problems, often after a viral infection. Labyrinthitis may also affect hearing.",
        "severity": "moderate",
        "treatment": "Rest, hydration, anti-nausea or vertigo medicines for short-term relief, and vestibular rehabilitation when needed. A clinician should evaluate hearing loss or severe symptoms.",
        "when_to_seek_care": "Seek urgent care for severe sudden vertigo, new hearing loss, severe headache, neurologic symptoms, repeated vomiting, dehydration, or inability to walk safely.",
        "risk_factors": ["recent viral infection", "inner ear inflammation", "respiratory infection"],
        "complications": ["persistent dizziness", "falls", "hearing loss", "dehydration"],
        "source": "NHS - Labyrinthitis and Vestibular Neuritis",
    },
    {
        "condition": "Iron Deficiency Anemia",
        "symptoms": [
            "fatigue",
            "weakness",
            "dizziness",
            "shortness of breath",
            "pale skin",
            "headache",
            "cold hands",
            "rapid heartbeat",
        ],
        "description": "Iron deficiency anemia occurs when the body does not have enough iron to make healthy red blood cells, reducing oxygen delivery to tissues.",
        "severity": "mild to severe",
        "treatment": "Treatment depends on the cause and may include iron-rich foods, oral iron supplements, and evaluation for blood loss or absorption problems.",
        "when_to_seek_care": "See a healthcare provider for persistent fatigue, dizziness, shortness of breath, heavy menstrual bleeding, black stools, or suspected anemia.",
        "risk_factors": ["heavy menstrual bleeding", "pregnancy", "low iron diet", "blood loss", "digestive conditions"],
        "complications": ["heart strain", "pregnancy complications", "developmental issues in children"],
        "source": "MedlinePlus - Iron Deficiency Anemia",
    },
    {
        "condition": "Hypoglycemia (Low Blood Sugar)",
        "symptoms": [
            "shakiness",
            "sweating",
            "hunger",
            "dizziness",
            "confusion",
            "rapid heartbeat",
            "weakness",
            "headache",
            "blurred vision",
        ],
        "description": "Hypoglycemia is a low blood glucose level. It is most common in people using diabetes medicines but can also occur with missed meals, alcohol use, or intense exercise.",
        "severity": "mild to severe",
        "treatment": "Fast-acting carbohydrates such as glucose tablets, juice, or regular soda may help mild episodes. Follow diabetes care instructions and recheck glucose when available.",
        "when_to_seek_care": "Seek emergency help for fainting, seizure, severe confusion, inability to swallow safely, or symptoms that do not improve after sugar intake.",
        "risk_factors": ["diabetes medication", "missed meals", "alcohol use", "intense exercise", "kidney disease"],
        "complications": ["seizure", "loss of consciousness", "injury", "coma"],
        "source": "American Diabetes Association - Hypoglycemia",
    },
    {
        "condition": "Orthostatic Hypotension (Postural Low Blood Pressure)",
        "symptoms": [
            "dizziness when standing",
            "lightheadedness",
            "fainting",
            "blurred vision",
            "weakness",
            "nausea",
            "confusion",
        ],
        "description": "Orthostatic hypotension is a drop in blood pressure after standing up, which can briefly reduce blood flow to the brain and cause dizziness or fainting.",
        "severity": "mild to severe",
        "treatment": "Stand slowly, hydrate, avoid overheating, and review medications with a clinician. Compression stockings or medication may be needed for recurrent cases.",
        "when_to_seek_care": "Seek care for repeated fainting, falls, chest pain, shortness of breath, neurologic symptoms, or dizziness that is frequent or worsening.",
        "risk_factors": ["dehydration", "older age", "blood pressure medication", "diabetes", "bed rest", "heat exposure"],
        "complications": ["falls", "injury", "reduced quality of life"],
        "source": "Mayo Clinic - Orthostatic Hypotension",
    },
    {
        "condition": "Panic Attack",
        "symptoms": [
            "rapid heartbeat",
            "chest tightness",
            "shortness of breath",
            "sweating",
            "trembling",
            "dizziness",
            "nausea",
            "fear of losing control",
            "tingling",
        ],
        "description": "A panic attack is a sudden episode of intense fear or discomfort with physical symptoms that can feel alarming and may peak within minutes.",
        "severity": "mild to moderate",
        "treatment": "Slow breathing, grounding techniques, and moving to a safe environment may help during an attack. Recurrent attacks can be treated with therapy and sometimes medication.",
        "when_to_seek_care": "Seek emergency care for first-time chest pain, fainting, severe shortness of breath, or symptoms that could be heart-related. Seek mental health care for recurrent attacks or avoidance.",
        "risk_factors": ["anxiety disorder", "stress", "trauma", "family history", "stimulants"],
        "complications": ["avoidance", "agoraphobia", "depression", "substance misuse"],
        "source": "National Institute of Mental Health - Panic Disorder",
    },
    {
        "condition": "COVID-19",
        "symptoms": [
            "fever",
            "cough",
            "sore throat",
            "fatigue",
            "body aches",
            "headache",
            "loss of taste",
            "loss of smell",
            "shortness of breath",
            "runny nose",
        ],
        "description": "COVID-19 is a respiratory illness caused by SARS-CoV-2. Symptoms range from mild upper-respiratory symptoms to severe pneumonia and complications.",
        "severity": "mild to severe",
        "treatment": "Rest, fluids, fever reducers, testing, isolation guidance, and medical advice for high-risk people. Antiviral treatment may be recommended for eligible patients early in illness.",
        "when_to_seek_care": "Seek urgent care for trouble breathing, persistent chest pain, confusion, bluish lips or face, dehydration, or worsening symptoms in high-risk individuals.",
        "risk_factors": ["older age", "chronic conditions", "immunocompromise", "no vaccination", "close exposure"],
        "complications": ["pneumonia", "blood clots", "long COVID", "respiratory failure"],
        "source": "CDC - COVID-19 Symptoms",
    },
    {
        "condition": "Strep Throat",
        "symptoms": [
            "sore throat",
            "painful swallowing",
            "fever",
            "swollen tonsils",
            "white patches on tonsils",
            "swollen lymph nodes",
            "headache",
            "stomach pain",
        ],
        "description": "Strep throat is a bacterial throat infection caused by group A Streptococcus. It often causes sudden sore throat and fever without typical cold symptoms.",
        "severity": "mild to moderate",
        "treatment": "A clinician can confirm with testing. Antibiotics are used when strep is confirmed, along with fluids, rest, and pain or fever relief.",
        "when_to_seek_care": "See a healthcare provider for severe sore throat, fever, swollen lymph nodes, rash, trouble swallowing, or symptoms lasting more than a few days.",
        "risk_factors": ["school exposure", "close contact", "age 5-15", "winter or early spring"],
        "complications": ["rheumatic fever", "kidney inflammation", "abscess", "scarlet fever"],
        "source": "CDC - Strep Throat",
    },
    {
        "condition": "Acute Sinusitis",
        "symptoms": [
            "stuffy nose",
            "facial pressure",
            "facial pain",
            "thick nasal discharge",
            "postnasal drip",
            "headache",
            "cough",
            "reduced smell",
            "fever",
        ],
        "description": "Acute sinusitis is inflammation of the sinuses, often after a cold or allergies. It can cause nasal blockage, facial pressure, and thick drainage.",
        "severity": "mild to moderate",
        "treatment": "Saline rinses, fluids, rest, humidified air, and pain relief may help. Antibiotics are usually reserved for suspected bacterial sinusitis.",
        "when_to_seek_care": "Seek care for symptoms lasting more than 10 days, severe facial pain, high fever, swelling around the eye, confusion, stiff neck, or worsening after initial improvement.",
        "risk_factors": ["recent cold", "allergies", "nasal polyps", "asthma", "smoke exposure"],
        "complications": ["chronic sinusitis", "eye infection", "meningitis"],
        "source": "CDC - Sinus Infection",
    },
    {
        "condition": "Pneumonia",
        "symptoms": [
            "cough",
            "fever",
            "chills",
            "shortness of breath",
            "chest pain",
            "fatigue",
            "rapid breathing",
            "mucus",
        ],
        "description": "Pneumonia is an infection of the lungs that can cause air sacs to fill with fluid or pus. It may be caused by bacteria, viruses, or fungi.",
        "severity": "moderate to severe",
        "treatment": "Treatment depends on the cause and severity. It may include antibiotics, antivirals, fluids, rest, fever control, oxygen, or hospital care.",
        "when_to_seek_care": "Seek urgent care for trouble breathing, chest pain, bluish lips, confusion, persistent high fever, dehydration, or symptoms in infants, older adults, or high-risk people.",
        "risk_factors": ["older age", "young age", "chronic lung disease", "smoking", "weak immune system", "recent respiratory infection"],
        "complications": ["respiratory failure", "sepsis", "pleural effusion", "lung abscess"],
        "source": "American Lung Association - Pneumonia",
    },
    {
        "condition": "Acute Bronchitis",
        "symptoms": [
            "cough",
            "mucus",
            "chest discomfort",
            "fatigue",
            "mild fever",
            "chills",
            "shortness of breath",
            "wheezing",
        ],
        "description": "Acute bronchitis is inflammation of the bronchial tubes, usually from a viral infection. It often causes a cough that can last several weeks.",
        "severity": "mild to moderate",
        "treatment": "Rest, fluids, humidified air, honey for cough in appropriate ages, and avoiding smoke may help. Antibiotics usually do not help viral bronchitis.",
        "when_to_seek_care": "Seek care for trouble breathing, chest pain, high or prolonged fever, bloody mucus, symptoms lasting more than three weeks, or high-risk medical conditions.",
        "risk_factors": ["recent cold", "smoking", "air pollution", "asthma", "weakened immune system"],
        "complications": ["pneumonia", "asthma flare", "chronic bronchitis"],
        "source": "Mayo Clinic - Bronchitis",
    },
    {
        "condition": "Food Poisoning",
        "symptoms": [
            "nausea",
            "vomiting",
            "diarrhea",
            "stomach cramps",
            "abdominal pain",
            "fever",
            "weakness",
            "dehydration",
        ],
        "description": "Food poisoning is illness from contaminated food or drinks. Symptoms can start within hours or days depending on the germ or toxin involved.",
        "severity": "mild to severe",
        "treatment": "Hydration is most important. Eat bland foods as tolerated and avoid alcohol, dairy, and fatty foods during recovery. Some cases need medical testing or treatment.",
        "when_to_seek_care": "Seek care for bloody diarrhea, high fever, severe dehydration, persistent vomiting, severe abdominal pain, neurologic symptoms, pregnancy, or symptoms in infants or older adults.",
        "risk_factors": ["undercooked food", "unpasteurized foods", "poor food handling", "travel", "weak immune system"],
        "complications": ["dehydration", "kidney injury", "sepsis", "reactive arthritis"],
        "source": "CDC - Food Poisoning",
    },
    {
        "condition": "Gastroesophageal Reflux Disease (GERD)",
        "symptoms": [
            "heartburn",
            "acid reflux",
            "regurgitation",
            "chest burning",
            "sour taste",
            "chronic cough",
            "hoarseness",
            "trouble swallowing",
        ],
        "description": "GERD is chronic acid reflux where stomach contents flow back into the esophagus, causing irritation and burning symptoms.",
        "severity": "mild to moderate",
        "treatment": "Lifestyle changes, avoiding trigger foods, not lying down after meals, weight management, antacids, H2 blockers, or proton pump inhibitors may help.",
        "when_to_seek_care": "Seek urgent care for chest pain with shortness of breath, sweating, jaw or arm pain. See a clinician for trouble swallowing, weight loss, vomiting blood, or persistent reflux.",
        "risk_factors": ["obesity", "pregnancy", "smoking", "hiatal hernia", "large meals", "trigger foods"],
        "complications": ["esophagitis", "stricture", "Barrett esophagus", "dental erosion"],
        "source": "NIDDK - GERD",
    },
    {
        "condition": "Appendicitis",
        "symptoms": [
            "abdominal pain",
            "right lower abdominal pain",
            "nausea",
            "vomiting",
            "loss of appetite",
            "fever",
            "bloating",
        ],
        "description": "Appendicitis is inflammation of the appendix. Pain often starts near the belly button and moves to the lower right abdomen, but symptoms can vary.",
        "severity": "urgent",
        "treatment": "Appendicitis needs prompt medical evaluation. Treatment often involves surgery and sometimes antibiotics.",
        "when_to_seek_care": "Seek urgent medical care for worsening abdominal pain, right lower abdominal pain, fever with vomiting, rigid abdomen, or severe pain with movement.",
        "risk_factors": ["age 10-30", "family history", "intestinal infection"],
        "complications": ["ruptured appendix", "abscess", "peritonitis", "sepsis"],
        "source": "Mayo Clinic - Appendicitis",
    },
    {
        "condition": "Irritable Bowel Syndrome (IBS)",
        "symptoms": [
            "abdominal pain",
            "bloating",
            "gas",
            "diarrhea",
            "constipation",
            "mucus in stool",
            "cramping",
        ],
        "description": "IBS is a chronic disorder of gut-brain interaction that causes recurring abdominal discomfort and changes in bowel habits without visible bowel damage.",
        "severity": "mild to moderate",
        "treatment": "Diet changes, fiber, hydration, stress management, exercise, and medications targeted to diarrhea, constipation, or pain may help.",
        "when_to_seek_care": "Seek care for weight loss, blood in stool, persistent fever, anemia, nighttime diarrhea, new symptoms after age 50, or severe/worsening pain.",
        "risk_factors": ["younger age", "female sex", "family history", "stress", "prior gastrointestinal infection"],
        "complications": ["reduced quality of life", "mood symptoms", "missed activities"],
        "source": "NIDDK - Irritable Bowel Syndrome",
    },
    {
        "condition": "Tension-Type Headache",
        "symptoms": [
            "headache",
            "pressure around head",
            "neck pain",
            "scalp tenderness",
            "mild nausea",
            "fatigue",
            "sensitivity to light",
        ],
        "description": "Tension-type headache often causes mild to moderate pressure or tightness on both sides of the head and may be related to stress, posture, or muscle tension.",
        "severity": "mild to moderate",
        "treatment": "Rest, hydration, stress reduction, stretching, posture changes, heat or ice, and over-the-counter pain relievers may help when used safely.",
        "when_to_seek_care": "Seek urgent care for sudden severe headache, headache with fever or stiff neck, weakness, confusion, vision changes, head injury, or a new/worsening pattern.",
        "risk_factors": ["stress", "poor sleep", "poor posture", "jaw clenching", "eye strain"],
        "complications": ["chronic headache", "medication overuse headache", "reduced productivity"],
        "source": "MedlinePlus - Tension Headache",
    },
    {
        "condition": "Middle Ear Infection (Otitis Media)",
        "symptoms": [
            "ear pain",
            "ear pressure",
            "fever",
            "hearing difficulty",
            "fluid drainage from ear",
            "irritability",
            "trouble sleeping",
            "dizziness",
        ],
        "description": "A middle ear infection is inflammation or infection behind the eardrum, often after a cold. It is common in children but can affect adults.",
        "severity": "mild to moderate",
        "treatment": "Pain control and observation may be enough in some cases. Antibiotics may be prescribed depending on age, severity, and duration.",
        "when_to_seek_care": "Seek care for severe ear pain, fever, symptoms lasting more than a couple of days, drainage, hearing loss, or symptoms in very young children.",
        "risk_factors": ["young age", "recent cold", "allergies", "daycare", "smoke exposure"],
        "complications": ["hearing loss", "eardrum rupture", "mastoiditis", "speech delay in children"],
        "source": "Mayo Clinic - Ear Infection",
    },
    {
        "condition": "Conjunctivitis (Pink Eye)",
        "symptoms": [
            "red eye",
            "itchy eyes",
            "watery eyes",
            "eye discharge",
            "gritty feeling in eye",
            "crusting eyelids",
            "light sensitivity",
        ],
        "description": "Conjunctivitis is inflammation of the thin membrane covering the eye and eyelid. It may be viral, bacterial, allergic, or irritant-related.",
        "severity": "mild",
        "treatment": "Warm compresses, artificial tears, avoiding contact lenses, and hygiene can help. Bacterial cases may need antibiotic eye drops from a clinician.",
        "when_to_seek_care": "Seek care for eye pain, vision changes, intense redness, light sensitivity, symptoms in newborns, or symptoms that worsen or do not improve.",
        "risk_factors": ["close contact", "allergies", "contact lenses", "eye irritants", "poor hand hygiene"],
        "complications": ["keratitis", "vision problems", "spread to others"],
        "source": "CDC - Conjunctivitis",
    },
    {
        "condition": "Eczema (Atopic Dermatitis)",
        "symptoms": [
            "itchy skin",
            "dry skin",
            "red rash",
            "scaly patches",
            "cracked skin",
            "skin inflammation",
            "sleep disturbance from itching",
        ],
        "description": "Eczema is a chronic inflammatory skin condition that causes dry, itchy, irritated skin and can flare with triggers.",
        "severity": "mild to severe",
        "treatment": "Moisturizers, trigger avoidance, gentle skin care, topical corticosteroids or other prescription medicines may be used depending on severity.",
        "when_to_seek_care": "See a clinician for severe itching, signs of infection, widespread rash, sleep disruption, or symptoms not improving with basic skin care.",
        "risk_factors": ["family history", "asthma", "allergies", "dry climate", "irritants"],
        "complications": ["skin infection", "sleep problems", "thickened skin", "quality of life impact"],
        "source": "American Academy of Dermatology - Eczema",
    },
    {
        "condition": "Hypothyroidism",
        "symptoms": [
            "fatigue",
            "weight gain",
            "cold intolerance",
            "constipation",
            "dry skin",
            "hair thinning",
            "depression",
            "slow heartbeat",
            "heavy periods",
        ],
        "description": "Hypothyroidism occurs when the thyroid gland does not produce enough thyroid hormone, slowing many body functions.",
        "severity": "mild to severe",
        "treatment": "Diagnosis is made with blood tests. Treatment usually involves daily thyroid hormone replacement and monitoring.",
        "when_to_seek_care": "See a healthcare provider for persistent fatigue, unexplained weight gain, cold intolerance, constipation, depression, or menstrual changes.",
        "risk_factors": ["female sex", "older age", "autoimmune disease", "thyroid surgery", "radiation treatment", "family history"],
        "complications": ["heart problems", "infertility", "neuropathy", "myxedema"],
        "source": "MedlinePlus - Hypothyroidism",
    },
    {
        "condition": "Hyperthyroidism",
        "symptoms": [
            "weight loss",
            "rapid heartbeat",
            "palpitations",
            "anxiety",
            "tremor",
            "sweating",
            "heat intolerance",
            "fatigue",
            "increased appetite",
        ],
        "description": "Hyperthyroidism occurs when the thyroid makes too much thyroid hormone, speeding up body processes.",
        "severity": "moderate to severe",
        "treatment": "Treatment may include antithyroid medicines, radioactive iodine, beta blockers, or surgery depending on cause and severity.",
        "when_to_seek_care": "Seek care for unexplained weight loss, rapid heartbeat, tremor, heat intolerance, or anxiety with physical symptoms. Seek urgent care for chest pain, severe shortness of breath, or confusion.",
        "risk_factors": ["Graves disease", "family history", "female sex", "thyroid nodules", "excess iodine"],
        "complications": ["heart rhythm problems", "bone loss", "thyroid storm", "eye problems"],
        "source": "MedlinePlus - Hyperthyroidism",
    },
    {
        "condition": "Kidney Stone",
        "symptoms": [
            "severe side pain",
            "back pain",
            "lower abdominal pain",
            "painful urination",
            "blood in urine",
            "nausea",
            "vomiting",
            "frequent urination",
        ],
        "description": "Kidney stones are hard mineral deposits that can form in the kidneys and cause severe pain as they move through the urinary tract.",
        "severity": "moderate to severe",
        "treatment": "Small stones may pass with fluids and pain control. Larger or blocked stones may need procedures. Evaluation helps determine size, location, and infection risk.",
        "when_to_seek_care": "Seek urgent care for severe pain, fever, chills, vomiting, inability to urinate, blood in urine, or pain with a known single kidney.",
        "risk_factors": ["prior stones", "dehydration", "high sodium diet", "family history", "obesity", "certain supplements"],
        "complications": ["urinary blockage", "kidney infection", "kidney damage", "recurrent stones"],
        "source": "NIDDK - Kidney Stones",
    },
    {
        "condition": "Gallstones",
        "symptoms": [
            "right upper abdominal pain",
            "abdominal pain after fatty meals",
            "nausea",
            "vomiting",
            "back pain",
            "shoulder pain",
            "indigestion",
        ],
        "description": "Gallstones are hardened deposits in the gallbladder. They may cause sudden pain when they block bile flow.",
        "severity": "mild to severe",
        "treatment": "Asymptomatic stones may not need treatment. Symptomatic or complicated gallstones often require surgical evaluation.",
        "when_to_seek_care": "Seek urgent care for severe abdominal pain, fever, yellow skin or eyes, persistent vomiting, or pain lasting several hours.",
        "risk_factors": ["female sex", "pregnancy", "obesity", "rapid weight loss", "age over 40", "family history"],
        "complications": ["cholecystitis", "bile duct blockage", "pancreatitis", "infection"],
        "source": "NIDDK - Gallstones",
    },
    {
        "condition": "Menstrual Cramps (Dysmenorrhea)",
        "symptoms": [
            "lower abdominal cramps",
            "pelvic pain",
            "back pain",
            "thigh pain",
            "nausea",
            "diarrhea",
            "headache",
            "fatigue",
        ],
        "description": "Menstrual cramps are throbbing or cramping pains before or during a menstrual period. They may be primary or related to conditions such as endometriosis or fibroids.",
        "severity": "mild to severe",
        "treatment": "Heat, exercise, rest, and anti-inflammatory medicines may help if safe to use. Persistent or severe cramps should be evaluated.",
        "when_to_seek_care": "See a clinician for severe pain, sudden new cramps, heavy bleeding, fever, pelvic pain outside periods, or cramps that interfere with daily life.",
        "risk_factors": ["younger age", "heavy periods", "smoking", "family history", "endometriosis", "fibroids"],
        "complications": ["missed activities", "underlying pelvic condition", "reduced quality of life"],
        "source": "ACOG - Dysmenorrhea",
    },
    {
        "condition": "Motion Sickness",
        "symptoms": [
            "nausea",
            "vomiting",
            "dizziness",
            "cold sweat",
            "pale skin",
            "increased saliva",
            "headache",
            "fatigue",
        ],
        "description": "Motion sickness occurs when the brain receives conflicting signals from the eyes, inner ears, and body during travel or motion.",
        "severity": "mild to moderate",
        "treatment": "Look at the horizon, sit where motion is least noticeable, get fresh air, avoid heavy meals, and consider motion-sickness medicines when appropriate.",
        "when_to_seek_care": "Seek care if symptoms are severe, persistent after motion stops, associated with neurologic symptoms, or causing dehydration from repeated vomiting.",
        "risk_factors": ["travel", "inner ear sensitivity", "migraine history", "pregnancy", "age 2-12"],
        "complications": ["dehydration", "travel disruption", "falls from dizziness"],
        "source": "CDC Travelers' Health - Motion Sickness",
    },
    {
        "condition": "Medication Side Effect",
        "symptoms": [
            "dizziness",
            "nausea",
            "fatigue",
            "drowsiness",
            "headache",
            "dry mouth",
            "rash",
            "stomach upset",
        ],
        "description": "Many medicines and supplements can cause side effects such as dizziness, nausea, sleepiness, stomach upset, or rash. Symptoms may start after a new medication or dose change.",
        "severity": "mild to severe",
        "treatment": "Review medication timing and dose with a pharmacist or clinician. Do not stop prescribed medicines without medical guidance unless emergency symptoms occur.",
        "when_to_seek_care": "Seek urgent care for trouble breathing, swelling of lips or throat, severe rash, fainting, chest pain, severe confusion, or signs of allergic reaction.",
        "risk_factors": ["new medication", "dose change", "multiple medicines", "older age", "kidney or liver disease", "drug interactions"],
        "complications": ["falls", "allergic reaction", "toxicity", "nonadherence"],
        "source": "MedlinePlus - Drug Reactions",
    },
]


def _normalize_condition_name(condition: str) -> str:
    return " ".join(condition.strip().lower().split())


def _get_existing_conditions(rag_service) -> set[str]:
    collection = rag_service.client.collections.get(rag_service.COLLECTION_NAME)
    response = collection.query.fetch_objects(limit=1000)
    return {
        _normalize_condition_name(obj.properties.get("condition", ""))
        for obj in response.objects
        if obj.properties.get("condition")
    }


def _build_docs(items: Iterable[dict]) -> list[MedicalKnowledgeDoc]:
    return [
        MedicalKnowledgeDoc(
            doc_id="",
            condition=item["condition"],
            symptoms=item["symptoms"],
            description=item["description"],
            severity=item["severity"],
            treatment=item["treatment"],
            when_to_seek_care=item["when_to_seek_care"],
            risk_factors=item.get("risk_factors"),
            complications=item.get("complications"),
            source=item["source"],
            last_updated=datetime.now(UTC),
        )
        for item in items
    ]


async def load_extended_data():
    rag_service = None
    try:
        logger.info("Initializing RAG service...")
        rag_service = get_rag_service()

        current_count = await rag_service.get_document_count()
        logger.info("Current knowledge base has %s documents", current_count)

        existing_conditions = _get_existing_conditions(rag_service)
        new_items = [
            item
            for item in EXTENDED_KNOWLEDGE
            if _normalize_condition_name(item["condition"]) not in existing_conditions
        ]

        if not new_items:
            logger.info("No new conditions to add. Extended knowledge is already loaded.")
            return

        logger.info("Adding %s new compatible MedicalKnowledge documents...", len(new_items))
        result = await rag_service.bulk_add_knowledge(_build_docs(new_items))

        logger.info("=" * 60)
        logger.info("EXTENDED LOAD RESULTS")
        logger.info("Total requested: %s", result["total"])
        logger.info("Successfully added: %s", result["successful"])
        logger.info("Failed: %s", result["failed"])

        for error in result.get("errors", []):
            logger.warning("  - %s", error)

        final_count = await rag_service.get_document_count()
        logger.info("Knowledge base now has %s documents", final_count)
        logger.info("=" * 60)

    finally:
        if rag_service is not None:
            rag_service.close()


if __name__ == "__main__":
    asyncio.run(load_extended_data())