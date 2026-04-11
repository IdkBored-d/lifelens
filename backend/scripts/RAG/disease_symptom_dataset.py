import torch
from sentence_transformers import SentenceTransformer, util

# 1. Load the medical-specific embedding model
# DisEmbed-v1 is optimized for mapping symptoms to disease names
model = SentenceTransformer("SalmanFaroz/DisEmbed-v1")

# Sample medical knowledge data

DISEASE_DATASET = [
    {
        "condition": "Fungal infection",
        "symptoms": ["itching", "skin rash", "nodal skin eruptions", "dischromic patches"],
        "description": "Fungal infections are caused by fungi that invade the skin or other tissues. They are common in warm, moist areas of the body and can spread from person to person or via contaminated surfaces.",
        "severity": "mild",
        "treatment": "antifungal cream, fluconazole, terbinafine, clotrimazole, ketoconazole",
        "source": "Mayo Clinic - Fungal Infections"
    },
    {
        "condition": "Allergy",
        "symptoms": ["continuous sneezing", "shivering", "chills", "watering from eyes"],
        "description": "An allergic reaction is an immune system overreaction to a foreign substance (allergen). The body produces IgE antibodies that trigger the release of histamine, leading to symptoms.",
        "severity": "mild",
        "treatment": "apply calamine, apply cetirizine, antihistamines, avoid allergens",
        "source": "NIH - MedlinePlus"
    },
    {
        "condition": "GERD",
        "symptoms": ["stomach pain", "acidity", "ulcers on tongue", "vomiting", "cough", "chest pain"],
        "description": "Gastroesophageal reflux disease occurs when stomach acid frequently flows back into the esophagus. This chronic acid reflux can irritate the esophageal lining over time.",
        "severity": "moderate",
        "treatment": "avoid fatty spicy food, avoid late night meals, sleep upright, antacids",
        "source": "Mayo Clinic - GERD Overview"
    },
    {
        "condition": "Chronic cholestasis",
        "symptoms": ["itching", "vomiting", "yellowish skin", "nausea", "abdominal pain", "yellowing of eyes"],
        "description": "Cholestasis is any condition in which the flow of bile from the liver stops or slows, leading to a buildup of bilirubin in the blood.",
        "severity": "severe",
        "treatment": "ursodeoxycholic acid, avoid alcohol, low fat diet, surgical intervention",
        "source": "NIH - Liver Disease"
    },
    {
        "condition": "Drug Reaction",
        "symptoms": ["itching", "skin rash", "stomach pain", "burning micturition", "spotting urination"],
        "description": "An adverse drug reaction is an unwanted or harmful reaction experienced following the administration of a drug or combination of drugs under normal conditions of use.",
        "severity": "moderate to severe",
        "treatment": "stop irritation, consult nearest doctor, antihistamines, epinephrine",
        "source": "CDC - Medication Safety"
    },
    {
        "condition": "Peptic ulcer disease",
        "symptoms": ["vomiting", "loss of appetite", "abdominal pain", "passage of gases", "internal itching"],
        "description": "Peptic ulcers are open sores that develop on the inside lining of your stomach and the upper portion of your small intestine.",
        "severity": "moderate",
        "treatment": "avoid fatty spicy food, consume probiotic food, eliminate alcohol, H2 blockers",
        "source": "Mayo Clinic - Peptic Ulcer"
    },
    {
        "condition": "AIDS",
        "symptoms": ["muscle wasting", "patches in throat", "high fever", "extra marital contacts"],
        "description": "Acquired immunodeficiency syndrome (AIDS) is the most severe phase of HIV infection. People with AIDS have badly damaged immune systems that lead to increasing numbers of severe illnesses.",
        "severity": "severe",
        "treatment": "antiretroviral therapy (ART), follow up, avoid open cuts, protective measures",
        "source": "CDC - HIV/AIDS"
    },
    {
        "condition": "Diabetes",
        "symptoms": ["fatigue", "weight loss", "restlessness", "lethargy", "irregular sugar level",
                     "increased appetite", "obesity"],
        "description": "Diabetes is a chronic disease that occurs either when the pancreas does not produce enough insulin or when the body cannot effectively use the insulin it produces.",
        "severity": "severe",
        "treatment": "diet modification, insulin therapy, exercise, regular blood sugar monitoring",
        "source": "WHO / NIH"
    },
    {
        "condition": "Gastroenteritis",
        "symptoms": ["vomiting", "sunken eyes", "dehydration", "diarrhea"],
        "description": "Often called 'stomach flu,' this is an inflammation of the lining of the intestines caused by a virus, bacteria, or parasites.",
        "severity": "moderate",
        "treatment": "stop eating solid food for a while, stay hydrated, salt water gargle, rest",
        "source": "Mayo Clinic - Gastroenteritis"
    },
    {
        "condition": "Bronchial Asthma",
        "symptoms": ["fatigue", "cough", "high fever", "breathlessness", "family history", "mucoid sputum"],
        "description": "Asthma is a long-term inflammatory disease of the airways of the lungs. It is characterized by variable and recurring symptoms and reversible airflow obstruction.",
        "severity": "moderate",
        "treatment": "switch to clouds, breath deep, use albuterol, avoid triggers",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Hypertension",
        "symptoms": ["headache", "chest pain", "dizziness", "loss of balance", "lack of concentration"],
        "description": "High blood pressure is a condition in which the long-term force of the blood against your artery walls is high enough that it may eventually cause health problems.",
        "severity": "moderate",
        "treatment": "meditation, salt reduction, exercise, antihypertensive medication",
        "source": "American Heart Association"
    },
    {
        "condition": "Migraine",
        "symptoms": ["acidity", "indigestion", "headache", "blurred and distorted vision", "excessive hunger",
                     "stiff neck", "depression", "irritability", "visual disturbances"],
        "description": "A migraine is a headache that can cause severe throbbing pain or a pulsing sensation, usually on one side of the head. It's often accompanied by nausea and sensitivity to light.",
        "severity": "moderate",
        "treatment": "meditation, reduce stress, use ice packs, sleep in dark room",
        "source": "Mayo Clinic - Migraine"
    },
    {
        "condition": "Cervical spondylosis",
        "symptoms": ["back pain", "dizziness", "loss of balance", "neck pain", "weakness in limbs"],
        "description": "Cervical spondylosis is a general term for age-related wear and tear affecting the spinal disks in your neck.",
        "severity": "moderate",
        "treatment": "use heating pad or cold pack, exercise, take vitamin d, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Paralysis (brain hemorrhage)",
        "symptoms": ["vomiting", "headache", "weakness of one body side", "altered sensorium"],
        "description": "A brain hemorrhage is a type of stroke. It's caused by an artery in the brain bursting and causing localized bleeding in the surrounding tissues.",
        "severity": "severe",
        "treatment": "massage, eat healthy, consult doctor, physical therapy",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Jaundice",
        "symptoms": ["itching", "vomiting", "fatigue", "weight loss", "high fever", "yellowish skin", "dark urine",
                     "abdominal pain"],
        "description": "Jaundice is a condition in which the skin, whites of the eyes and mucous membranes turn yellow because of a high level of bilirubin, a yellow-orange bile pigment.",
        "severity": "moderate",
        "treatment": "drink plenty of water, consume probiotics, reduce alcohol, sunlight exposure",
        "source": "CDC"
    },
    {
        "condition": "Malaria",
        "symptoms": ["chills", "vomiting", "high fever", "sweating", "headache", "nausea", "muscle pain"],
        "description": "Malaria is a life-threatening disease caused by parasites that are transmitted to people through the bites of infected female Anopheles mosquitoes.",
        "severity": "severe",
        "treatment": "Consult nearest doctor, avoid oily food, use mosquito nets, antimalarial drugs",
        "source": "WHO"
    },
    {
        "condition": "Chicken pox",
        "symptoms": ["itching", "skin rash", "fatigue", "lethargy", "high fever", "headache", "loss of appetite",
                     "mild fever", "swelled lymph nodes", "malaise", "red spots over body"],
        "description": "Chickenpox is a highly contagious disease caused by the varicella-zoster virus (VZV). It can cause an itchy, blister-like rash.",
        "severity": "moderate",
        "treatment": "use calamine, take supplements, avoid scratching, isolation",
        "source": "CDC"
    },
    {
        "condition": "Dengue",
        "symptoms": ["skin rash", "chills", "joint pain", "vomiting", "fatigue", "high fever", "headache", "nausea",
                     "loss of appetite", "pain behind the eyes", "back pain", "muscle pain", "red spots over body"],
        "description": "Dengue is a viral infection transmitted to humans through the bite of infected mosquitoes. The primary vectors that transmit the disease are Aedes aegypti mosquitoes.",
        "severity": "severe",
        "treatment": "drink plenty of fluids, use mosquito net, keep hydrtated, acetaminophen",
        "source": "WHO"
    },
    {
        "condition": "Typhoid",
        "symptoms": ["chills", "vomiting", "fatigue", "high fever", "headache", "nausea", "constipation",
                     "abdominal pain", "diarrhea", "toxic look (typhos)"],
        "description": "Typhoid fever is a life-threatening infection caused by the bacterium Salmonella Typhi. It is usually spread through contaminated food or water.",
        "severity": "severe",
        "treatment": "eat high calorie veg, antibiotic therapy, rest, hydration",
        "source": "CDC"
    },
    {
        "condition": "Hepatitis A",
        "symptoms": ["joint pain", "vomiting", "fatigue", "yellowish skin", "dark urine", "nausea", "loss of appetite",
                     "abdominal pain", "yellowing of eyes", "mild fever"],
        "description": "Hepatitis A is a highly contagious liver infection caused by the hepatitis A virus. It is one of several types of hepatitis viruses that cause inflammation and affect your liver's ability to function.",
        "severity": "moderate",
        "treatment": "Consult nearest doctor, eat healthy, avoid fatty food, rest",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Hepatitis B",
        "symptoms": ["itching", "fatigue", "lethargy", "yellowish skin", "dark urine", "loss of appetite",
                     "abdominal pain", "yellowing of eyes", "malaise", "receiving blood transfusion",
                     "receiving unsterile injections"],
        "description": "Hepatitis B is a serious liver infection caused by the hepatitis B virus (HBV). For most people, hepatitis B is short-term, also called acute, and lasts less than six months.",
        "severity": "severe",
        "treatment": "consult doctor, eat healthy, antiviral meds, avoid alcohol",
        "source": "CDC"
    },
    {
        "condition": "Hepatitis C",
        "symptoms": ["fatigue", "yellowish skin", "nausea", "loss of appetite", "yellowing of eyes", "family history"],
        "description": "Hepatitis C is a viral infection that causes liver inflammation, sometimes leading to serious liver damage. The hepatitis C virus (HCV) spreads through contaminated blood.",
        "severity": "severe",
        "treatment": "Consult nearest doctor, eat healthy, follow regimen, antiviral therapy",
        "source": "NIH"
    },
    {
        "condition": "Hepatitis D",
        "symptoms": ["joint pain", "vomiting", "fatigue", "yellowish skin", "dark urine", "nausea", "loss of appetite",
                     "abdominal pain", "yellowing of eyes"],
        "description": "Hepatitis D, also known as 'delta hepatitis,' is a liver disease caused by the hepatitis D virus (HDV). HDV only occurs in people who are also infected with the hepatitis B virus.",
        "severity": "severe",
        "treatment": "consult doctor, eat healthy, follow medication, rest",
        "source": "WHO"
    },
    {
        "condition": "Hepatitis E",
        "symptoms": ["joint pain", "vomiting", "fatigue", "yellowish skin", "dark urine", "nausea", "loss of appetite",
                     "abdominal pain", "yellowing of eyes", "acute liver failure", "coma", "stomach bleeding"],
        "description": "Hepatitis E is a liver inflammation caused by infection with the hepatitis E virus (HEV). HEV is transmitted mainly through contaminated drinking water.",
        "severity": "severe",
        "treatment": "stop alcohol, rest, eat healthy, consult doctor",
        "source": "WHO"
    },
    {
        "condition": "Alcoholic hepatitis",
        "symptoms": ["vomiting", "yellowish skin", "abdominal pain", "swelling of stomach", "distention of abdomen",
                     "history of alcohol consumption", "fluid overload"],
        "description": "Alcoholic hepatitis is inflammation of the liver caused by drinking alcohol. It's most likely to occur in people who drink heavily over many years.",
        "severity": "severe",
        "treatment": "stop alcohol, consult doctor, eat healthy, corticosteroids",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Tuberculosis",
        "symptoms": ["chills", "vomiting", "fatigue", "weight loss", "cough", "high fever", "breathlessness",
                     "sweating", "loss of appetite", "mild fever", "yellowing of eyes", "swelled lymph nodes",
                     "malaise", "phlegm", "chest pain", "blood in sputum"],
        "description": "Tuberculosis (TB) is a potentially serious infectious disease that mainly affects your lungs. The bacteria that cause tuberculosis are spread from one person to another through tiny droplets released into the air via coughs and sneezes.",
        "severity": "severe",
        "treatment": "cover mouth, consult doctor, complete medication course, isolation",
        "source": "CDC"
    },
    {
        "condition": "Common Cold",
        "symptoms": ["continuous sneezing", "chills", "fatigue", "cough", "high fever", "headache",
                     "swelled lymph nodes", "malaise", "phlegm", "throat irritation", "redness of eyes",
                     "sinus pressure", "runny nose", "congestion", "chest pain", "loss of smell", "muscle pain"],
        "description": "The common cold is a viral infection of your nose and throat (upper respiratory tract). It's usually harmless, although it might not feel that way.",
        "severity": "mild",
        "treatment": "drink vitamin c rich fruits, rest, salt water gargle, steam inhalation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pneumonia",
        "symptoms": ["chills", "fatigue", "cough", "high fever", "breathlessness", "sweating", "malaise", "phlegm",
                     "chest pain", "fast heart rate", "rusty sputum"],
        "description": "Pneumonia is an infection that inflames the air sacs in one or both lungs. The air sacs may fill with fluid or pus, causing cough with phlegm or pus, fever, chills, and difficulty breathing.",
        "severity": "severe",
        "treatment": "consult doctor, follow medication, rest, hydration",
        "source": "NIH"
    },
    {
        "condition": "Dimorphic hemorrhoids(piles)",
        "symptoms": ["constipation", "pain during bowel movements", "pain in anal region", "bloody stool",
                     "irritation in anus"],
        "description": "Hemorrhoids are swollen veins in your anus and lower rectum, similar to varicose veins.",
        "severity": "moderate",
        "treatment": "avoid fatty spicy food, consume fiber rich food, use sitz bath, stay hydrated",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Heart attack",
        "symptoms": ["vomiting", "breathlessness", "sweating", "chest pain"],
        "description": "A heart attack occurs when the flow of blood to the heart is severely reduced or blocked. The blockage is usually due to a buildup of fat, cholesterol and other substances in the heart (coronary) arteries.",
        "severity": "emergency",
        "treatment": "call ambulance, chew aspirin, keep calm, stay hydrated",
        "source": "American Heart Association"
    },
    {
        "condition": "Varicose veins",
        "symptoms": ["fatigue", "cramps", "bruising", "obesity", "swollen legs", "swollen blood vessels",
                     "prominent veins on calf", "fatigue in legs"],
        "description": "Varicose veins are twisted, enlarged veins. Any vein that is close to the skin's surface (superficial) can become varicose.",
        "severity": "moderate",
        "treatment": "lie down flat and raise legs, use compression stockings, exercise, avoid standing long",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Hypothyroidism",
        "symptoms": ["fatigue", "weight gain", "lethargy", "dizziness", "puffy face and eyes", "enlarged thyroid",
                     "brittle nails", "swollen blood vessels", "depression", "irritability", "abnormal menstruation"],
        "description": "Hypothyroidism (underactive thyroid) is a condition in which your thyroid gland doesn't produce enough of certain crucial hormones.",
        "severity": "moderate",
        "treatment": "reduce weight, exercise, hormone replacement therapy, eat healthy",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Hyperthyroidism",
        "symptoms": ["fatigue", "mood swings", "weight loss", "restlessness", "sweating", "diarrhea", "fast heart rate",
                     "excessive hunger", "muscle weakness", "irritability", "abnormal menstruation"],
        "description": "Hyperthyroidism (overactive thyroid) occurs when your thyroid gland produces too much of the hormone thyroxine. Hyperthyroidism can accelerate your body's metabolism.",
        "severity": "moderate",
        "treatment": "eat healthy, massage, medication, avoid caffeine",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Hypoglycemia",
        "symptoms": ["vomiting", "fatigue", "anxiety", "sweating", "headache", "nausea", "blurred and distorted vision",
                     "excessive hunger", "drying and tingling lips", "slurred speech", "irritability", "palpitations"],
        "description": "Hypoglycemia is a condition in which your blood sugar (glucose) level is lower than the standard range. Glucose is your body's main energy source.",
        "severity": "moderate to severe",
        "treatment": "lie down on side, drink sugary drink, check sugar levels, consult doctor",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Osteoarthristis",
        "symptoms": ["joint pain", "neck pain", "knee pain", "hip joint pain", "swelling joints", "painful walking"],
        "description": "Osteoarthritis is the most common form of arthritis, affecting millions of people worldwide. It occurs when the protective cartilage that cushions the ends of the bones wears down over time.",
        "severity": "moderate",
        "treatment": "acetaminophen, consult doctor, salt water bath, physical therapy",
        "source": "Arthritis Foundation"
    },
    {
        "condition": "Arthritis",
        "symptoms": ["muscle weakness", "stiff joints", "swelling joints", "movement stiffness", "painful walking"],
        "description": "Arthritis is the swelling and tenderness of one or more of your joints. The main symptoms of arthritis are joint pain and stiffness, which typically worsen with age.",
        "severity": "moderate",
        "treatment": "exercise, use hot and cold packs, massage, anti-inflammatory meds",
        "source": "Mayo Clinic"
    },
    {
        "condition": "(vertigo) Paroymsal  Positional Vertigo",
        "symptoms": ["vomiting", "headache", "nausea", "spinning movements", "loss of balance", "unsteadiness"],
        "description": "Benign paroxysmal positional vertigo (BPPV) is one of the most common causes of vertigo — the sudden sensation that you're spinning or that the inside of your head is spinning.",
        "severity": "moderate",
        "treatment": "lie down, avoid sudden head movements, Epley maneuver, consult doctor",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Acne",
        "symptoms": ["skin rash", "pus filled pimples", "blackheads", "scurring"],
        "description": "Acne is a skin condition that occurs when your hair follicles become plugged with oil and dead skin cells. It causes whiteheads, blackheads or pimples.",
        "severity": "mild",
        "treatment": "bath twice a day, avoid fatty spicy food, use benzoyl peroxide, avoid picking",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Urinary tract infection",
        "symptoms": ["burning micturition", "bladder discomfort", "foul smell of urine", "continuous feel of urine"],
        "description": "A urinary tract infection (UTI) is an infection in any part of your urinary system — your kidneys, ureters, bladder and urethra.",
        "severity": "moderate",
        "treatment": "drink plenty of water, increase vitamin c, cranberry juice, antibiotics",
        "source": "CDC"
    },
    {
        "condition": "Psoriasis",
        "symptoms": ["skin rash", "joint pain", "skin peeling", "silver like dusting", "small dents in nails",
                     "inflammatory nails"],
        "description": "Psoriasis is a skin disease that causes a rash with itchy, scaly patches, most commonly on the knees, elbows, trunk and scalp.",
        "severity": "moderate",
        "treatment": "stop eating fatty food, apply steroid cream, light therapy, salt water bath",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Impetigo",
        "symptoms": ["skin rash", "high fever", "blister", "red sore around nose", "yellow crust ooze"],
        "description": "Impetigo is a common and highly contagious skin infection that mainly affects infants and young children. It usually appears as reddish sores on the face.",
        "severity": "mild",
        "treatment": "soak affected area in warm water, use antibiotic ointment, isolation, hygiene",
        "source": "CDC"
    },
    {
        "condition": "Panic disorder",
        "symptoms": ["palpitations", "sweating", "trembling", "shortness of breath", "fear of losing control",
                     "dizziness"],
        "description": "Panic disorder is an anxiety disorder where you regularly have sudden attacks of panic or fear.",
        "severity": "moderate",
        "treatment": "antidepressant medications, cognitive behavioral therapy, relaxation techniques",
        "source": "NIH - NIMH"
    },
    {
        "condition": "Vocal cord polyp",
        "symptoms": ["hoarseness", "vocal changes", "vocal fatigue"],
        "description": "A vocal cord polyp is a noncancerous growth on your vocal cords that can be caused by vocal abuse.",
        "severity": "mild",
        "treatment": "voice rest, speech therapy, surgical removal",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Turner syndrome",
        "symptoms": ["short stature", "webbed neck", "delayed puberty", "heart defects", "infertility"],
        "description": "Turner syndrome, a condition that affects only females, results when one of the X chromosomes is missing or partially missing.",
        "severity": "severe",
        "treatment": "growth hormone therapy, estrogen replacement therapy, cardiac monitoring",
        "source": "NIH"
    },
    {
        "condition": "Ethylene glycol poisoning",
        "symptoms": ["nausea", "vomiting", "abdominal pain", "malaise", "weakness", "increased thirst"],
        "description": "Ethylene glycol poisoning is caused by the ingestion of ethylene glycol, the primary ingredient in automotive antifreeze.",
        "severity": "emergency",
        "treatment": "supportive measures, gastric decontamination, antidote administration, hemodialysis",
        "source": "CDC"
    },
    {
        "condition": "Atrophic vaginitis",
        "symptoms": ["vaginal dryness", "vaginal burning", "frequent urination", "urinary tract infections",
                     "painful intercourse"],
        "description": "Vaginal atrophy is thinning, drying and inflammation of the vaginal walls that may occur when your body has less estrogen.",
        "severity": "moderate",
        "treatment": "vaginal moisturizers, vaginal estrogen therapy, lifestyle modifications",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Fracture",
        "symptoms": ["pain", "swelling", "bruising", "deformity", "inability to move the affected limb"],
        "description": "A fracture is a break, usually in a bone. If the broken bone punctures the skin, it is called an open or compound fracture.",
        "severity": "moderate to severe",
        "treatment": "immobilization, pain management, surgical repair, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Angle-Closure Glaucoma",
        "symptoms": ["severe eye pain", "headache", "blurred vision", "halos around lights", "nausea", "vomiting"],
        "description": "Angle-closure glaucoma is a serious eye condition that happens when the fluid in your eye can't drain as it should.",
        "severity": "emergency",
        "treatment": "topical beta blockers, alpha agonists, prostaglandins, laser peripheral iridotomy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Normal-Tension Glaucoma",
        "symptoms": ["gradual loss of vision", "visual field defects"],
        "description": "Normal-tension glaucoma is a form of glaucoma where the optic nerve is damaged even though the eye pressure is within the normal range.",
        "severity": "moderate",
        "treatment": "eye drops to lower intraocular pressure, laser therapy, surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Cataract",
        "symptoms": ["blurred vision", "cloudy vision", "difficulty seeing at night", "sensitivity to light",
                     "halos around lights"],
        "description": "A cataract is a clouding of the normally clear lens of your eye. For people who have cataracts, seeing through cloudy lenses is like looking through a frosty or fogged-up window.",
        "severity": "moderate",
        "treatment": "prescription eyeglasses, cataract surgery, lifestyle changes",
        "source": "NIH - NEI"
    },
    {
        "condition": "Macular Degeneration",
        "symptoms": ["blurred vision", "distorted vision", "difficulty recognizing faces", "blind spots"],
        "description": "Age-related macular degeneration (AMD) is an eye disease that can blur your central vision. It happens when aging causes damage to the macula — the part of the eye that controls sharp, straight-ahead vision.",
        "severity": "moderate to severe",
        "treatment": "anti-VEGF injections, laser therapy, photodynamic therapy, vitamin supplements",
        "source": "NIH - National Eye Institute"
    },
    {
        "condition": "Stye",
        "symptoms": ["red lump on eyelid", "eyelid pain", "eyelid swelling", "tearing"],
        "description": "A stye (hordeolum) is a red, painful lump near the edge of your eyelid that may look like a boil or a pimple. Styes are often filled with pus.",
        "severity": "mild",
        "treatment": "warm compress, antibiotic drops, avoid wearing contacts, avoid eye makeup",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Uveitis",
        "symptoms": ["eye redness", "eye pain", "light sensitivity", "blurred vision", "floaters"],
        "description": "Uveitis is a form of eye inflammation. It affects the middle layer of tissue in the eye wall (uvea). Warning signs often come on suddenly and get worse quickly.",
        "severity": "moderate to severe",
        "treatment": "corticosteroids, immunosuppressive drugs, surgical intervention",
        "source": "NIH - NEI"
    },
    {
        "condition": "Blepharitis",
        "symptoms": ["red eyes", "itchy eyelids", "swollen eyelids", "gritty sensation in the eye"],
        "description": "Blepharitis is inflammation of the eyelids. It usually involves the part of the eyelid where the eyelashes grow and affects both eyelids.",
        "severity": "mild",
        "treatment": "eyelid scrubs, warm compresses, antibiotic ointments, steroid eye drops",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Dry eye syndrome",
        "symptoms": ["stinging sensation", "burning sensation", "scratchy sensation", "eye redness",
                     "light sensitivity"],
        "description": "Dry eye disease is a common condition that occurs when your tears aren't able to provide adequate lubrication for your eyes.",
        "severity": "mild to moderate",
        "treatment": "artificial tears, lifestyle changes, punctal plugs, prescription eye drops",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Bell's palsy",
        "symptoms": ["facial droop", "difficulty making facial expressions", "pain around the jaw",
                     "increased sensitivity to sound"],
        "description": "Bell's palsy causes sudden, temporary weakness in your facial muscles. This makes half of your face appear to droop.",
        "severity": "moderate",
        "treatment": "corticosteroids, antiviral drugs, physical therapy, eye protection",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Multiple sclerosis",
        "symptoms": ["numbness or weakness", "electric-shock sensations", "tremor", "lack of coordination",
                     "unsteady gait"],
        "description": "Multiple sclerosis (MS) is a potentially disabling disease of the brain and spinal cord (central nervous system) where the immune system attacks the protective sheath (myelin).",
        "severity": "severe",
        "treatment": "corticosteroids, disease-modifying therapies, plasma exchange, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Parkinson's disease",
        "symptoms": ["tremor", "slowed movement", "rigid muscles", "impaired posture and balance",
                     "loss of automatic movements"],
        "description": "Parkinson's disease is a progressive disorder that affects the nervous system and the parts of the body controlled by the nerves.",
        "severity": "severe",
        "treatment": "levodopa, dopamine agonists, MAO B inhibitors, deep brain stimulation",
        "source": "NIH - NIA"
    },
    {
        "condition": "Alzheimer's disease",
        "symptoms": ["memory loss", "confusion with time or place", "difficulty completing familiar tasks",
                     "trouble understanding visual images"],
        "description": "Alzheimer's disease is a progressive neurologic disorder that causes the brain to shrink (atrophy) and brain cells to die.",
        "severity": "severe",
        "treatment": "cholinesterase inhibitors, memantine, aducanumab, cognitive stimulation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Epilepsy",
        "symptoms": ["temporary confusion", "staring spell", "stiff muscles", "uncontrollable jerking movements",
                     "loss of consciousness"],
        "description": "Epilepsy is a central nervous system (neurological) disorder in which brain activity becomes abnormal, causing seizures or periods of unusual behavior.",
        "severity": "moderate to severe",
        "treatment": "anti-epileptic drugs, ketogenic diet, vagus nerve stimulation, surgery",
        "source": "CDC"
    },
    {
        "condition": "Bipolar disorder",
        "symptoms": ["abnormally upbeat", "increased activity", "exaggerated sense of well-being",
                     "decreased need for sleep", "unusual talkativeness"],
        "description": "Bipolar disorder is a mental health condition that causes extreme mood swings that include emotional highs (mania or hypomania) and lows (depression).",
        "severity": "moderate to severe",
        "treatment": "mood stabilizers, antipsychotics, antidepressants, psychotherapy",
        "source": "NIH - NIMH"
    },
    {
        "condition": "Schizophrenia",
        "symptoms": ["delusions", "hallucinations", "disorganized thinking", "extremely disorganized motor behavior"],
        "description": "Schizophrenia is a serious mental disorder in which people interpret reality abnormally. It results in some combination of hallucinations and delusions.",
        "severity": "severe",
        "treatment": "antipsychotic medications, psychosocial interventions, family therapy, vocational rehabilitation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Obsessive-compulsive disorder",
        "symptoms": ["fear of contamination", "needing things orderly", "aggressive thoughts", "unwanted thoughts"],
        "description": "Obsessive-compulsive disorder (OCD) features a pattern of unwanted thoughts and fears (obsessions) that lead you to do repetitive behaviors (compulsions).",
        "severity": "moderate",
        "treatment": "cognitive behavioral therapy, SSRIs, exposure and response prevention",
        "source": "NIH - NIMH"
    },
    {
        "condition": "Post-traumatic stress disorder",
        "symptoms": ["intrusive memories", "avoidance", "negative changes in thinking and mood",
                     "changes in physical and emotional reactions"],
        "description": "PTSD is a mental health condition that's triggered by a terrifying event — either experiencing it or witnessing it.",
        "severity": "moderate to severe",
        "treatment": "cognitive therapy, exposure therapy, EMDR, antidepressants",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Generalized anxiety disorder",
        "symptoms": ["persistent worrying", "overthinking plans", "perceiving situations as threatening",
                     "difficulty handling uncertainty"],
        "description": "GAD is characterized by persistent and excessive worry about a number of different things.",
        "severity": "moderate",
        "treatment": "psychotherapy, buspirone, benzodiazepines, lifestyle changes",
        "source": "NIH - NIMH"
    },
    {
        "condition": "Major depressive disorder",
        "symptoms": ["feelings of sadness", "loss of interest or pleasure", "sleep disturbances",
                     "tiredness and lack of energy"],
        "description": "Depression is a mood disorder that causes a persistent feeling of sadness and loss of interest.",
        "severity": "moderate to severe",
        "treatment": "SSRIs, SNRIs, psychotherapy, electroconvulsive therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Anorexia nervosa",
        "symptoms": ["extreme weight loss", "thin appearance", "abnormal blood counts", "fatigue", "insomnia",
                     "dizziness"],
        "description": "Anorexia is an eating disorder characterized by an abnormally low body weight, an intense fear of gaining weight and a distorted perception of weight.",
        "severity": "severe",
        "treatment": "hospitalization, nutritional rehabilitation, psychotherapy, family-based therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Bulimia nervosa",
        "symptoms": ["being preoccupied with body shape", "living in fear of gaining weight",
                     "repeated episodes of binging", "forced vomiting"],
        "description": "Bulimia is a serious, potentially life-threatening eating disorder. People with bulimia may secretly binge and then purge.",
        "severity": "severe",
        "treatment": "psychotherapy, fluoxetine, nutritional education, hospitalization",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Sleep apnea",
        "symptoms": ["loud snoring", "episodes in which you stop breathing", "gasping for air during sleep",
                     "awakening with a dry mouth"],
        "description": "Sleep apnea is a potentially serious sleep disorder in which breathing repeatedly stops and starts.",
        "severity": "moderate",
        "treatment": "CPAP machine, oral appliances, surgery, weight loss",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Insomnia",
        "symptoms": ["difficulty falling asleep", "waking up during the night", "waking up too early",
                     "not feeling well-rested"],
        "description": "Insomnia is a common sleep disorder that can make it hard to fall asleep, hard to stay asleep, or cause you to wake up too early and not be able to get back to sleep.",
        "severity": "moderate",
        "treatment": "cognitive behavioral therapy for insomnia, sleep hygiene, prescription sleep aids",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Narcolepsy",
        "symptoms": ["excessive daytime sleepiness", "sudden loss of muscle tone", "sleep paralysis", "hallucinations"],
        "description": "Narcolepsy is a chronic sleep disorder characterized by overwhelming daytime drowsiness and sudden attacks of sleep.",
        "severity": "moderate to severe",
        "treatment": "stimulants, SSRIs, SNRIs, sodium oxybate",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Restless legs syndrome",
        "symptoms": ["sensations that begin after resting", "relief with movement",
                     "worsening of symptoms in the evening", "nighttime leg twitching"],
        "description": "RLS is a condition that causes an uncontrollable urge to move your legs, usually because of an uncomfortable sensation.",
        "severity": "moderate",
        "treatment": "iron supplements, dopamine agonists, alpha-2-delta ligands",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Cystic fibrosis",
        "symptoms": ["persistent cough", "wheezing", "exercise intolerance", "repeated lung infections",
                     "inflamed nasal passages"],
        "description": "Cystic fibrosis is an inherited disorder that causes severe damage to the lungs, digestive system and other organs in the body.",
        "severity": "severe",
        "treatment": "CFTR modulators, airway clearance techniques, inhaled medications, lung transplant",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "COPD",
        "symptoms": ["shortness of breath", "wheezing", "chest tightness", "chronic cough",
                     "frequent respiratory infections"],
        "description": "Chronic obstructive pulmonary disease is a chronic inflammatory lung disease that causes obstructed airflow from the lungs.",
        "severity": "severe",
        "treatment": "smoking cessation, bronchodilators, inhaled steroids, oxygen therapy",
        "source": "CDC"
    },
    {
        "condition": "Emphysema",
        "symptoms": ["shortness of breath", "wheezing", "chronic cough", "fatigue"],
        "description": "Emphysema is a lung condition that causes shortness of breath. In people with emphysema, the air sacs in the lungs (alveoli) are damaged.",
        "severity": "severe",
        "treatment": "bronchodilators, inhaled steroids, antibiotics, pulmonary rehabilitation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Chronic bronchitis",
        "symptoms": ["cough", "production of mucus", "fatigue", "shortness of breath", "slight fever and chills",
                     "chest discomfort"],
        "description": "Chronic bronchitis is inflammation of the lining of your bronchial tubes, which carry air to and from your lungs.",
        "severity": "moderate to severe",
        "treatment": "bronchodilators, steroids, pulmonary rehabilitation, oxygen therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pulmonary embolism",
        "symptoms": ["shortness of breath", "chest pain", "cough", "leg pain or swelling", "discoloration of skin",
                     "fever"],
        "description": "Pulmonary embolism is a blockage in one of the pulmonary arteries in your lungs. In most cases, it is caused by blood clots that travel to the lungs from deep veins in the legs.",
        "severity": "emergency",
        "treatment": "blood thinners, thrombolytics, surgical clot removal, vein filter",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pulmonary hypertension",
        "symptoms": ["shortness of breath", "fatigue", "dizziness", "chest pressure", "swelling in ankles and legs"],
        "description": "Pulmonary hypertension is a type of high blood pressure that affects the arteries in your lungs and the right side of your heart.",
        "severity": "severe",
        "treatment": "vasodilators, calcium channel blockers, anticoagulants, diuretics",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Sleep apnea",
        "symptoms": ["loud snoring", "episodes in which you stop breathing", "gasping for air during sleep",
                     "awakening with a dry mouth"],
        "description": "Sleep apnea is a potentially serious sleep disorder in which breathing repeatedly stops and starts.",
        "severity": "moderate",
        "treatment": "CPAP machine, oral appliances, surgery, weight loss",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Pleurisy",
        "symptoms": ["chest pain that worsens when you breathe", "shortness of breath", "cough", "fever"],
        "description": "Pleurisy is a condition in which the pleura — two large, thin layers of tissue that separate your lungs from your chest wall — becomes inflamed.",
        "severity": "moderate",
        "treatment": "antibiotics, anti-inflammatory drugs, pain relievers",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pneumothorax",
        "symptoms": ["sudden chest pain", "shortness of breath"],
        "description": "A pneumothorax is a collapsed lung. It occurs when air leaks into the space between your lung and chest wall.",
        "severity": "emergency",
        "treatment": "observation, needle aspiration, chest tube insertion, surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Lung cancer",
        "symptoms": ["new cough that doesn't go away", "coughing up blood", "shortness of breath", "chest pain",
                     "hoarseness"],
        "description": "Lung cancer is a type of cancer that begins in the lungs. Your lungs are two spongy organs in your chest that take in oxygen and release carbon dioxide.",
        "severity": "severe",
        "treatment": "surgery, chemotherapy, radiation therapy, targeted drug therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Irritable bowel syndrome",
        "symptoms": ["abdominal pain", "cramping", "bloating", "excess gas", "diarrhea or constipation"],
        "description": "IBS is a common disorder that affects the large intestine. Signs and symptoms include cramping, abdominal pain, bloating, gas, and diarrhea or constipation.",
        "severity": "moderate",
        "treatment": "dietary changes, fiber supplements, laxatives, anti-diarrheal medications",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Crohn's disease",
        "symptoms": ["diarrhea", "fever", "fatigue", "abdominal pain and cramping", "blood in your stool"],
        "description": "Crohn's disease is a type of inflammatory bowel disease (IBD). It causes inflammation of your digestive tract, which can lead to abdominal pain and severe diarrhea.",
        "severity": "severe",
        "treatment": "corticosteroids, immunosuppressants, biologics, surgery",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Ulcerative colitis",
        "symptoms": ["diarrhea with blood or pus", "abdominal pain and cramping", "rectal pain", "rectal bleeding"],
        "description": "Ulcerative colitis is an inflammatory bowel disease (IBD) that causes inflammation and ulcers (sores) in your digestive tract.",
        "severity": "severe",
        "treatment": "anti-inflammatory drugs, immunosuppressants, biologics, surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Celiac disease",
        "symptoms": ["diarrhea", "fatigue", "weight loss", "bloating and gas", "abdominal pain", "nausea and vomiting"],
        "description": "Celiac disease is an immune reaction to eating gluten, a protein found in wheat, barley and rye.",
        "severity": "moderate to severe",
        "treatment": "strict gluten-free diet, vitamin and mineral supplements",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Diverticulitis",
        "symptoms": ["pain in the lower left side of the abdomen", "nausea and vomiting", "fever",
                     "abdominal tenderness"],
        "description": "Diverticulitis is the infection or inflammation of pouches (diverticula) that can form in your intestines.",
        "severity": "moderate to severe",
        "treatment": "antibiotics, liquid diet, surgery for complications",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gallstones",
        "symptoms": ["sudden and rapidly intensifying pain in the upper right portion of your abdomen",
                     "back pain between your shoulder blades", "nausea or vomiting"],
        "description": "Gallstones are hardened deposits of digestive fluid that can form in your gallbladder.",
        "severity": "moderate to severe",
        "treatment": "gallbladder removal surgery (cholecystectomy), medications to dissolve gallstones",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Cholecystitis",
        "symptoms": ["severe pain in your upper right or center abdomen",
                     "pain that spreads to your right shoulder or back", "tenderness over your abdomen", "nausea",
                     "vomiting", "fever"],
        "description": "Cholecystitis is inflammation of the gallbladder. In most cases, gallstones blocking the tube leading out of your gallbladder cause cholecystitis.",
        "severity": "severe",
        "treatment": "hospitalization, fasting, IV fluids, antibiotics, gallbladder removal",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pancreatitis",
        "symptoms": ["upper abdominal pain", "abdominal pain that radiates to your back",
                     "abdominal pain that feels worse after eating", "fever", "rapid pulse"],
        "description": "Pancreatitis is inflammation in the pancreas. The pancreas is a long, flat gland that sits tucked behind the stomach in the upper abdomen.",
        "severity": "severe",
        "treatment": "hospitalization, IV fluids, pain medications, procedures to remove obstructions",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Liver cirrhosis",
        "symptoms": ["fatigue", "bleeding or bruising easily", "loss of appetite", "nausea", "swelling in your legs",
                     "weight loss"],
        "description": "Cirrhosis is a late stage of scarring (fibrosis) of the liver caused by many forms of liver diseases and conditions, such as hepatitis and chronic alcoholism.",
        "severity": "severe",
        "treatment": "treatment for alcohol dependency, weight loss, medications for hepatitis, liver transplant",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Kidney stones",
        "symptoms": ["severe pain in the side and back", "pain that radiates to the lower abdomen and groin",
                     "pain that comes in waves", "pain or burning sensation while urinating"],
        "description": "Kidney stones (renal calculi) are hard deposits made of minerals and salts that form inside your kidneys.",
        "severity": "moderate to severe",
        "treatment": "drinking water, pain relievers, medical therapy (alpha blockers), lithotripsy",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Chronic kidney disease",
        "symptoms": ["nausea", "vomiting", "loss of appetite", "fatigue and weakness", "sleep problems",
                     "changes in how much you urinate"],
        "description": "Chronic kidney disease, also called chronic kidney failure, describes the gradual loss of kidney function.",
        "severity": "severe",
        "treatment": "blood pressure medications, cholesterol medications, anemia medications, dialysis, kidney transplant",
        "source": "CDC"
    },
    {
        "condition": "Polycystic kidney disease",
        "symptoms": ["high blood pressure", "back or side pain", "headache", "increase in the size of your abdomen",
                     "blood in your urine"],
        "description": "PKD is an inherited disorder in which clusters of cysts develop primarily within your kidneys, causing your kidneys to enlarge and lose function over time.",
        "severity": "severe",
        "treatment": "blood pressure control, tolvaptan, pain management, dialysis, kidney transplant",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Prostatitis",
        "symptoms": ["pain or burning sensation when urinating", "difficulty urinating", "frequent urination",
                     "urgent need to urinate", "cloudy urine"],
        "description": "Prostatitis is swelling and inflammation of the prostate gland, a walnut-sized gland situated directly below the bladder in men.",
        "severity": "moderate",
        "treatment": "antibiotics, alpha blockers, anti-inflammatory agents",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Erectile dysfunction",
        "symptoms": ["trouble getting an erection", "trouble keeping an erection", "reduced sexual desire"],
        "description": "ED is the inability to get and keep an erection firm enough for sex.",
        "severity": "moderate",
        "treatment": "sildenafil, tadalafil, vardenafil, testosterone replacement, counseling",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Endometriosis",
        "symptoms": ["painful periods", "pain with intercourse", "pain with bowel movements or urination",
                     "excessive bleeding"],
        "description": "Endometriosis is an often painful disorder in which tissue similar to the tissue that normally lines the inside of your uterus — the endometrium — grows outside your uterus.",
        "severity": "moderate to severe",
        "treatment": "pain medications, hormone therapy, conservative surgery, hysterectomy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Polycystic ovary syndrome",
        "symptoms": ["irregular periods", "excess androgen", "polycystic ovaries"],
        "description": "PCOS is a hormonal disorder common among women of reproductive age. Women with PCOS may have infrequent or prolonged menstrual periods or excess male hormone (androgen) levels.",
        "severity": "moderate",
        "treatment": "birth control pills, metformin, spironolactone, lifestyle changes",
        "source": "NIH - NICHD"
    },
    {
        "condition": "Menopause symptoms",
        "symptoms": ["hot flashes", "night sweats", "mood changes", "vaginal dryness", "sleep problems"],
        "description": "Menopause is the time that marks the end of your menstrual cycles. It's diagnosed after you've gone 12 months without a menstrual period.",
        "severity": "moderate",
        "treatment": "hormone therapy, vaginal estrogen, low-dose antidepressants, gabapentin",
        "source": "NIH - NIA"
    },
    {
        "condition": "Breast cancer",
        "symptoms": ["breast lump", "change in breast size or shape", "skin dimpling", "newly inverted nipple",
                     "peeling or crusting of skin"],
        "description": "Breast cancer is cancer that forms in the cells of the breasts. After skin cancer, breast cancer is the most common cancer diagnosed in women.",
        "severity": "severe",
        "treatment": "surgery, radiation therapy, chemotherapy, hormone therapy, targeted therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Cushing syndrome",
        "symptoms": ["weight gain", "fatty tissue deposits", "pink or purple stretch marks", "thinning skin",
                     "slow healing"],
        "description": "Cushing syndrome occurs when your body has too much of the hormone cortisol over time. This can result from the body making too much cortisol or from taking oral corticosteroid medication.",
        "severity": "severe",
        "treatment": "reducing steroid use, surgery, radiation therapy, medications to control cortisol",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Addison's disease",
        "symptoms": ["extreme fatigue", "weight loss", "darkening of skin", "low blood pressure", "salt craving",
                     "low blood sugar"],
        "description": "Addison's disease, also called adrenal insufficiency, is an uncommon disorder that occurs when your body doesn't produce enough of certain hormones.",
        "severity": "severe",
        "treatment": "hormone replacement therapy, corticosteroids, clinical monitoring",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Lupus",
        "symptoms": ["fatigue", "fever", "joint pain", "butterfly-shaped rash", "skin lesions", "shortness of breath"],
        "description": "Lupus is a systemic autoimmune disease that occurs when your body's immune system attacks your own tissues and organs. Inflammation caused by lupus can affect many different body systems.",
        "severity": "severe",
        "treatment": "NSAIDs, antimalarial drugs, corticosteroids, immunosuppressants",
        "source": "CDC"
    },
    {
        "condition": "Rheumatoid arthritis",
        "symptoms": ["tender joints", "joint stiffness", "fatigue", "fever", "loss of appetite"],
        "description": "Rheumatoid arthritis is a chronic inflammatory disorder that can affect more than just your joints. In some people, the condition can damage a wide variety of body systems, including the skin, eyes, lungs, and heart.",
        "severity": "severe",
        "treatment": "DMARDs, biologics, physical therapy, NSAIDs",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Sjogren's syndrome",
        "symptoms": ["dry eyes", "dry mouth", "joint pain", "swollen salivary glands", "skin rashes",
                     "persistent dry cough"],
        "description": "Sjogren's syndrome is a disorder of your immune system identified by its two most common symptoms — dry eyes and a dry mouth.",
        "severity": "moderate",
        "treatment": "artificial tears, eye drops, increasing fluid intake, medications for dry mouth",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Scleroderma",
        "symptoms": ["hard patches of skin", "Raynaud's phenomenon", "digestive issues", "heart or lung problems"],
        "description": "Scleroderma is a group of rare diseases that involve the hardening and tightening of the skin and connective tissues.",
        "severity": "severe",
        "treatment": "blood pressure medications, immunosuppressants, physical therapy, light therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Rosacea",
        "symptoms": ["facial redness", "swollen red bumps", "eye problems", "enlarged nose"],
        "description": "Rosacea is a common skin condition that causes blushing or flushing and visible blood vessels in your face. It may also produce small, pus-filled bumps.",
        "severity": "mild to moderate",
        "treatment": "topical medications, oral antibiotics, laser therapy, trigger avoidance",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Eczema (Atopic Dermatitis)",
        "symptoms": ["dry skin", "itching", "red to brownish-gray patches", "small raised bumps",
                     "thickened or cracked skin"],
        "description": "Atopic dermatitis (eczema) is a condition that makes your skin red and itchy. It's common in children but can occur at any age.",
        "severity": "mild to moderate",
        "treatment": "moisturizing, corticosteroid creams, light therapy, avoidance of irritants",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Vitiligo",
        "symptoms": ["patchy loss of skin color", "premature whitening of hair",
                     "loss of color in tissues inside the mouth"],
        "description": "Vitiligo is a disease that causes loss of skin color in patches. The discolored areas usually get bigger with time.",
        "severity": "mild",
        "treatment": "corticosteroid creams, light therapy, depigmentation, surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Alopecia areata",
        "symptoms": ["patchy hair loss", "exclamation point hairs", "nail changes"],
        "description": "Alopecia areata is a condition that causes hair to fall out in small patches, which can be unnoticeable but may connect and then become noticeable.",
        "severity": "moderate",
        "treatment": "corticosteroid injections, topical immunotherapy, minoxidil",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Meningitis",
        "symptoms": ["sudden high fever", "stiff neck", "severe headache", "nausea or vomiting", "confusion"],
        "description": "Meningitis is an inflammation of the fluid and membranes (meninges) surrounding your brain and spinal cord.",
        "severity": "emergency",
        "treatment": "antibiotics (bacterial), antiviral meds (viral), corticosteroids, fluids",
        "source": "CDC"
    },
    {
        "condition": "Encephalitis",
        "symptoms": ["headache", "fever", "aches in muscles or joints", "fatigue or weakness", "confusion"],
        "description": "Encephalitis is inflammation of the brain. There are several causes, but the most common is a viral infection.",
        "severity": "emergency",
        "treatment": "antiviral medications, supportive care, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Lyme disease",
        "symptoms": ["bulls-eye rash", "fever", "chills", "fatigue", "body aches", "headache"],
        "description": "Lyme disease is caused by the bacterium Borrelia burgdorferi and is transmitted to humans through the bite of infected black-legged ticks.",
        "severity": "moderate to severe",
        "treatment": "antibiotics (doxycycline, amoxicillin), rest, anti-inflammatory meds",
        "source": "CDC"
    },
    {
        "condition": "Rocky Mountain spotted fever",
        "symptoms": ["fever", "headache", "rash", "nausea", "vomiting", "muscle pain"],
        "description": "RMSF is a bacterial disease spread through the bite of an infected tick. It can be deadly if not treated early with the right antibiotic.",
        "severity": "severe",
        "treatment": "doxycycline (early administration is critical), hospitalization",
        "source": "CDC"
    },
    {
        "condition": "West Nile virus",
        "symptoms": ["fever", "headache", "body aches", "vomiting", "diarrhea", "rash"],
        "description": "West Nile virus is the leading cause of mosquito-borne disease in the continental United States. Most people do not feel sick, but some develop a life-threatening illness.",
        "severity": "moderate to severe",
        "treatment": "rest, fluids, pain relievers, supportive care in hospital for severe cases",
        "source": "CDC"
    },
    {
        "condition": "Zika virus",
        "symptoms": ["fever", "rash", "headache", "joint pain", "red eyes", "muscle pain"],
        "description": "Zika is spread mostly by the bite of an infected Aedes species mosquito. Zika can be passed from a pregnant woman to her fetus, causing birth defects.",
        "severity": "moderate",
        "treatment": "rest, fluids, acetaminophen (avoid NSAIDs until dengue is ruled out)",
        "source": "WHO"
    },
    {
        "condition": "Ebola virus disease",
        "symptoms": ["fever", "severe headache", "muscle pain", "weakness", "fatigue", "diarrhea", "vomiting"],
        "description": "Ebola is a rare and deadly disease in people and nonhuman primates. It is caused by an infection with a group of viruses within the genus Ebolavirus.",
        "severity": "emergency",
        "treatment": "monoclonal antibody treatments, supportive care, fluid management",
        "source": "CDC"
    },
    {
        "condition": "Mononucleosis",
        "symptoms": ["fatigue", "sore throat", "fever", "swollen lymph nodes", "swollen tonsils", "headache"],
        "description": "Infectious mononucleosis (mono) is often called the kissing disease. The virus that causes mono (EBV) is transmitted through saliva.",
        "severity": "moderate",
        "treatment": "rest, hydration, over-the-counter pain meds, avoid contact sports",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Rabies",
        "symptoms": ["fever", "headache", "excess salivation", "muscle spasms", "paralysis", "mental confusion"],
        "description": "Rabies is a preventable viral disease most often transmitted through the bite of a rabid animal. Once clinical symptoms appear, rabies is virtually 100% fatal.",
        "severity": "emergency",
        "treatment": "rabies vaccine (post-exposure), rabies immune globulin",
        "source": "CDC"
    },
    {
        "condition": "Tetanus",
        "symptoms": ["jaw cramping", "muscle spasms", "painful muscle stiffness", "trouble swallowing", "fever"],
        "description": "Tetanus is a serious disease caused by a bacterial toxin that affects your nervous system, leading to painful muscle contractions.",
        "severity": "emergency",
        "treatment": "antitoxin, wound care, antibiotics, vaccination, supportive care",
        "source": "CDC"
    },
    {
        "condition": "Diphtheria",
        "symptoms": ["thick gray membrane covering throat", "sore throat", "hoarseness", "swollen glands",
                     "difficulty breathing"],
        "description": "Diphtheria is a serious bacterial infection that usually affects the mucous membranes of your nose and throat.",
        "severity": "severe",
        "treatment": "antitoxin, antibiotics (erythromycin or penicillin), isolation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pertussis (Whooping cough)",
        "symptoms": ["runny nose", "low-grade fever", "mild cough", "high-pitched whoop sound"],
        "description": "Pertussis is a highly contagious respiratory tract infection. In many people, it's marked by a severe hacking cough followed by a high-pitched intake of breath.",
        "severity": "moderate to severe",
        "treatment": "antibiotics (azithromycin), hydration, monitoring in infants",
        "source": "CDC"
    },
    {
        "condition": "Measles",
        "symptoms": ["fever", "dry cough", "runny nose", "sore throat", "inflamed eyes",
                     "tiny white spots inside mouth", "skin rash"],
        "description": "Measles is a childhood infection caused by a virus. Once quite common, measles can now almost always be prevented with a vaccine.",
        "severity": "moderate to severe",
        "treatment": "fever reducers, vitamin A, antibiotics for secondary infections",
        "source": "CDC"
    },
    {
        "condition": "Mumps",
        "symptoms": ["swollen salivary glands", "pain while chewing", "fever", "headache", "muscle aches", "fatigue"],
        "description": "Mumps is a viral infection that primarily affects salivary glands that are located near your ears.",
        "severity": "moderate",
        "treatment": "pain relievers, warm/cold compresses for glands, soft diet",
        "source": "CDC"
    },
    {
        "condition": "Rubella (German measles)",
        "symptoms": ["mild fever", "headache", "stuffy or runny nose", "inflamed red eyes", "enlarged lymph nodes",
                     "fine pink rash"],
        "description": "Rubella is a contagious viral infection best known for its distinctive red rash. It's not the same as measles, but the two illnesses share some characteristics.",
        "severity": "mild",
        "treatment": "rest, fluids, fever reducers",
        "source": "CDC"
    },
    {
        "condition": "Hand-foot-and-mouth disease",
        "symptoms": ["fever", "sore throat", "painful blister-like lesions on tongue", "rash on palms and soles"],
        "description": "Hand-foot-and-mouth disease is a mild, contagious viral infection common in young children — characterized by sores in the mouth and a rash on the hands and feet.",
        "severity": "mild",
        "treatment": "topical anesthetic for mouth sores, pain relievers, hydration",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Scabies",
        "symptoms": ["itching", "thin irregular burrow tracks", "small bumps or blisters"],
        "description": "Scabies is an itchy skin condition caused by a tiny burrowing mite called Sarcoptes scabiei. Intense itching occurs in the area where the mite burrows.",
        "severity": "mild",
        "treatment": "permethrin cream, ivermectin, antihistamines for itching",
        "source": "CDC"
    },
    {
        "condition": "Lice (Pediculosis)",
        "symptoms": ["intense itching", "tickling feeling from movement of hair", "lice on scalp",
                     "lice eggs (nits) on hair shafts"],
        "description": "Lice are tiny, wingless, parasitic insects that feed on human blood. Lice are easily spread through close personal contact and sharing belongings.",
        "severity": "mild",
        "treatment": "OTC medicated shampoos, fine-toothed combing, washing clothing/bedding",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Ringworm (Tinea corporis)",
        "symptoms": ["scaly ring-shaped area", "itching", "clear or scaly area inside the ring", "expanding rings"],
        "description": "Ringworm of the body is a fungal infection that develops on the top layer of your skin. It's characterized by a red circular rash with clearer skin in the middle.",
        "severity": "mild",
        "treatment": "OTC antifungal creams (clotrimazole), prescription antifungals",
        "source": "CDC"
    },
    {
        "condition": "Athlete's foot",
        "symptoms": ["scaly red rash", "itching", "stinging and burning", "blisters", "dry scaly skin on soles"],
        "description": "Athlete's foot is a fungal infection that usually begins between the toes. It commonly occurs in people whose feet have become very sweaty while confined within tight-fitting shoes.",
        "severity": "mild",
        "treatment": "OTC antifungal products, keeping feet dry, antifungal powders",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Cellulitis",
        "symptoms": ["red area of skin that tends to expand", "swelling", "tenderness", "pain", "warmth", "fever",
                     "red spots", "blisters"],
        "description": "Cellulitis is a common, potentially serious bacterial skin infection. The affected skin appears swollen and red and is typically painful and warm to the touch.",
        "severity": "moderate to severe",
        "treatment": "oral antibiotics, wound care, elevation of affected limb",
        "source": "CDC"
    },
    {
        "condition": "Folliculitis",
        "symptoms": ["clusters of small red bumps", "pus-filled blisters", "itchy burning skin",
                     "large swollen bump or mass"],
        "description": "Folliculitis is a common skin condition in which hair follicles become inflamed. It's usually caused by a bacterial or fungal infection.",
        "severity": "mild",
        "treatment": "antibiotic creams, warm compresses, anti-itch lotions",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Boils (Furuncles)",
        "symptoms": ["painful red bump", "yellowish-white tip", "fever", "swollen lymph nodes"],
        "description": "A boil is a painful, pus-filled bump that forms under your skin when bacteria infect and inflame one or more of your hair follicles.",
        "severity": "mild",
        "treatment": "warm compresses, incision and drainage (by doctor), antibiotics",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Carbuncles",
        "symptoms": ["cluster of boils", "painful red bumps", "fever", "malaise"],
        "description": "A carbuncle is a cluster of boils that form a connected area of infection under the skin.",
        "severity": "moderate",
        "treatment": "antibiotics, professional drainage, warm compresses",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Abscess",
        "symptoms": ["painful swollen lump", "redness", "warmth", "pus drainage", "fever"],
        "description": "A skin abscess is a pocket of pus that's caused by a bacterial infection. It's usually a tender, red, and warm mass.",
        "severity": "moderate",
        "treatment": "incision and drainage, antibiotics, pain relief",
        "source": "NIH - MedlinePlus"
    },
    {
        "condition": "Warts (HPV)",
        "symptoms": ["small fleshy grainy bumps", "flesh-colored white pink or tan", "rough to the touch",
                     "sprinkled with black pinpoints"],
        "description": "Common warts are small, grainy skin growths that occur most often on your fingers or hands.",
        "severity": "mild",
        "treatment": "salicylic acid, cryotherapy (freezing), minor surgery, laser treatment",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Herpes simplex (Cold sores)",
        "symptoms": ["tingling and itching", "blisters", "oozing and crusting"],
        "description": "Cold sores — also called fever blisters — are a common viral infection. They are tiny, fluid-filled blisters on and around your lips.",
        "severity": "mild",
        "treatment": "antiviral creams, oral antiviral meds (acyclovir), cold compresses",
        "source": "NIH - MedlinePlus"
    },
    {
        "condition": "Shingles (Herpes zoster)",
        "symptoms": ["pain burning or tingling", "sensitivity to touch", "red rash", "fluid-filled blisters", "itching",
                     "fever"],
        "description": "Shingles is a viral infection that causes a painful rash. Although shingles can occur anywhere on your body, it most often appears as a single stripe of blisters.",
        "severity": "moderate to severe",
        "treatment": "antiviral medications, pain relievers, calamine lotion",
        "source": "CDC"
    },
    {
        "condition": "Seborrheic dermatitis",
        "symptoms": ["skin flakes (dandruff)", "patches of greasy skin", "red skin", "itching"],
        "description": "Seborrheic dermatitis is a common skin condition that mainly affects your scalp. It causes scaly patches, red skin and stubborn dandruff.",
        "severity": "mild",
        "treatment": "medicated shampoos, antifungal creams, corticosteroid ointments",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Urticaria (Hives)",
        "symptoms": ["raised red or skin-colored welts", "intense itching", "painful swelling (angioedema)"],
        "description": "Hives — also known as urticaria — are red, itchy welts that result from a skin reaction. The welts vary in size and appear and fade repeatedly.",
        "severity": "mild to moderate",
        "treatment": "antihistamines, corticosteroids, avoid triggers",
        "source": "American Academy of Dermatology"
    },
    {
        "condition": "Angioedema",
        "symptoms": ["large thick firm welts", "swelling and redness", "pain or warmth", "difficulty breathing"],
        "description": "Angioedema is an area of swelling of the lower layer of skin and tissue just under the skin or mucous membranes.",
        "severity": "emergency (if throat involved)",
        "treatment": "antihistamines, epinephrine, corticosteroids, airway management",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Anaphylaxis",
        "symptoms": ["skin reactions", "low blood pressure", "constriction of airways", "weak and rapid pulse",
                     "nausea vomiting or diarrhea"],
        "description": "Anaphylaxis is a severe, potentially life-threatening allergic reaction. It can occur within seconds or minutes of exposure to something you're allergic to.",
        "severity": "emergency",
        "treatment": "epinephrine (EpiPen), oxygen, IV antihistamines, corticosteroids",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Hypothermia",
        "symptoms": ["shivering", "slurred speech", "slow shallow breathing", "weak pulse", "clumsiness", "confusion"],
        "description": "Hypothermia is a medical emergency that occurs when your body loses heat faster than it can produce heat, causing a dangerously low body temperature.",
        "severity": "emergency",
        "treatment": "gentle rewarming, removal of wet clothes, warm fluids, medical monitoring",
        "source": "CDC"
    },
    {
        "condition": "Heat exhaustion",
        "symptoms": ["cool moist skin with goose bumps", "heavy sweating", "faintness", "dizziness", "fatigue",
                     "weak rapid pulse"],
        "description": "Heat exhaustion is a condition whose symptoms may include heavy sweating and a rapid pulse, a result of your body overheating.",
        "severity": "moderate",
        "treatment": "cooling down, hydration, rest in shade, electrolytes",
        "source": "CDC"
    },
    {
        "condition": "Heatstroke",
        "symptoms": ["high body temperature", "altered mental state", "alteration in sweating", "nausea and vomiting",
                     "flushed skin", "rapid breathing"],
        "description": "Heatstroke is a condition caused by your body overheating, usually as a result of prolonged exposure to or physical exertion in high temperatures.",
        "severity": "emergency",
        "treatment": "rapid cooling (ice bath), hydration, medical intervention",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Frostbite",
        "symptoms": ["cold skin and a prickling feeling", "numbness",
                     "skin that looks red white bluish-white or grayish-yellow", "hard or waxy-looking skin"],
        "description": "Frostbite is an injury caused by freezing of the skin and underlying tissues. First your skin becomes very cold and red, then numb, hard and pale.",
        "severity": "moderate to severe",
        "treatment": "gradual rewarming, protection of injured area, pain relief",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Dehydration",
        "symptoms": ["extreme thirst", "less frequent urination", "dark-colored urine", "fatigue", "dizziness",
                     "confusion"],
        "description": "Dehydration occurs when you use or lose more fluid than you take in, and your body doesn't have enough water and other fluids to carry out its normal functions.",
        "severity": "moderate to severe",
        "treatment": "oral rehydration salts, water, IV fluids for severe cases",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Scurvy (Vitamin C deficiency)",
        "symptoms": ["fatigue", "soreness and stiffness of joints", "bleeding gums", "small red/blue spots on skin",
                     "bruising"],
        "description": "Scurvy is a disease caused by a serious vitamin C deficiency. While rare in developed countries, it leads to weakness, anemia, and skin hemorrhages.",
        "severity": "moderate",
        "treatment": "vitamin C supplementation, diet rich in citrus fruits and vegetables",
        "source": "NIH - ODS"
    },
    {
        "condition": "Rickets (Vitamin D deficiency)",
        "symptoms": ["delayed growth", "bowed legs", "weakness", "pain in spine pelvis and legs"],
        "description": "Rickets is the softening and weakening of bones in children, usually because of an extreme and prolonged vitamin D deficiency.",
        "severity": "moderate",
        "treatment": "vitamin D and calcium supplements, sunlight exposure, corrective surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Iron deficiency anemia",
        "symptoms": ["extreme fatigue", "weakness", "pale skin", "chest pain", "fast heartbeat", "shortness of breath",
                     "headache", "dizziness"],
        "description": "Iron deficiency anemia is a common type of anemia — a condition in which blood lacks adequate healthy red blood cells.",
        "severity": "moderate",
        "treatment": "iron supplements, iron-rich diet, vitamin C (to aid absorption)",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Goiter",
        "symptoms": ["swelling at the base of neck", "tight feeling in throat", "coughing", "hoarseness",
                     "difficulty swallowing"],
        "description": "A goiter is an abnormal enlargement of your thyroid gland. While goiters are usually painless, a large goiter can cause a cough and make it hard for you to swallow or breathe.",
        "severity": "moderate",
        "treatment": "iodine supplementation, thyroid hormone replacement, surgery, observation",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pellagra (Vitamin B3 deficiency)",
        "symptoms": ["diarrhea", "dermatitis", "dementia", "sores in the mouth"],
        "description": "Pellagra is a disease caused by a lack of the vitamin niacin (vitamin B3). Symptoms include inflamed skin, diarrhea, dementia, and sores in the mouth.",
        "severity": "severe",
        "treatment": "nicotinamide or niacin supplementation, high-protein diet",
        "source": "NIH - Office of Dietary Supplements"
    },
    {
        "condition": "Beriberi (Vitamin B1 deficiency)",
        "symptoms": ["loss of appetite", "weakness", "pain in the limbs", "shortness of breath",
                     "swollen feet or legs"],
        "description": "Beriberi is a disease caused by a vitamin B1 (thiamine) deficiency. There are two main types: wet beriberi affects the heart and circulatory system, and dry beriberi damages the nerves.",
        "severity": "severe",
        "treatment": "thiamine supplements (oral or IV), diet rich in whole grains and pork",
        "source": "NIH - MedlinePlus"
    },
    {
        "condition": "Night blindness",
        "symptoms": ["difficulty seeing in low light", "difficulty seeing while driving at night",
                     "blurred vision in the dark"],
        "description": "Night blindness (nyctalopia) is a type of vision impairment. People with night blindness have poor vision at night or in dimly lit environments.",
        "severity": "moderate",
        "treatment": "Vitamin A supplements, corrective lenses, treating underlying cataracts",
        "source": "American Academy of Ophthalmology"
    },
    {
        "condition": "Kwashiorkor",
        "symptoms": ["fatigue", "irritability", "lethargy", "swelling (edema)", "large protuberant belly"],
        "description": "Kwashiorkor is a form of severe protein-energy malnutrition characterized by edema and an enlarged liver with fatty infiltrates.",
        "severity": "severe",
        "treatment": "gradual increase in protein and calories, vitamin/mineral supplements",
        "source": "CDC / WHO"
    },
    {
        "condition": "Marasmus",
        "symptoms": ["severe weight loss", "dehydration", "chronic diarrhea", "stomach shrinkage"],
        "description": "Marasmus is a form of severe malnutrition characterized by energy deficiency. It can occur in anyone with a severe inadequate intake of calories and protein.",
        "severity": "severe",
        "treatment": "rehydration, controlled nutritional rehabilitation, infection management",
        "source": "WHO"
    },
    {
        "condition": "Otitis media (Ear infection)",
        "symptoms": ["ear pain", "drainage of fluid from ear", "diminished hearing", "sore throat", "fever"],
        "description": "An ear infection (acute otitis media) is an infection of the middle ear, the air-filled space behind the eardrum that contains the tiny vibrating bones of the ear.",
        "severity": "mild to moderate",
        "treatment": "antibiotics, ear drops, pain relievers, warm compress",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Otitis externa (Swimmer's ear)",
        "symptoms": ["itching in ear canal", "redness inside ear", "drainage of clear odorless fluid",
                     "pain when ear is tugged"],
        "description": "Swimmer's ear is an infection in the outer ear canal, which runs from your eardrum to the outside of your head. It's often brought on by water that remains in your ear.",
        "severity": "mild",
        "treatment": "cleaning of ear canal, antibiotic or antifungal ear drops, steroid drops",
        "source": "CDC"
    },
    {
        "condition": "Tinnitus",
        "symptoms": ["ringing in the ears", "buzzing", "roaring", "clicking", "hissing"],
        "description": "Tinnitus is when you experience ringing or other noises in one or both of your ears. The noise you hear when you have tinnitus isn't caused by an external sound.",
        "severity": "mild to moderate",
        "treatment": "white noise machines, hearing aids, treating underlying blood vessel conditions",
        "source": "NIH - NIDCD"
    },
    {
        "condition": "Meniere's disease",
        "symptoms": ["dizziness (vertigo)", "hearing loss", "ringing in the ear (tinnitus)",
                     "feeling of fullness in the ear"],
        "description": "Meniere's disease is a disorder of the inner ear that can lead to dizzy spells (vertigo) and hearing loss. In most cases, Meniere's disease affects only one ear.",
        "severity": "moderate to severe",
        "treatment": "motion sickness meds, anti-nausea meds, salt restriction, diuretics",
        "source": "NIH - NIDCD"
    },
    {
        "condition": "Labyrinthitis",
        "symptoms": ["dizziness", "vertigo", "nausea", "vomiting", "loss of balance", "hearing loss"],
        "description": "Labyrinthitis is an inner ear disorder. The two vestibular nerves in your inner ear send your brain information about your spatial navigation and balance control. When one of these nerves becomes inflamed, it causes labyrinthitis.",
        "severity": "moderate",
        "treatment": "corticosteroids, antihistamines, physical therapy (vestibular rehabilitation)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Presbycusis (Age-related hearing loss)",
        "symptoms": ["speech of others sounds mumbled", "high-pitched sounds are hard to hear",
                     "conversations are difficult to understand"],
        "description": "Presbycusis is the most common type of sensorineural hearing loss caused by the natural aging of the auditory system.",
        "severity": "mild to moderate",
        "treatment": "hearing aids, assistive listening devices, cochlear implants (severe cases)",
        "source": "NIH - NIA"
    },
    {
        "condition": "Hyperacusis",
        "symptoms": ["everyday sounds seem too loud", "pain or discomfort from sound", "ear fullness"],
        "description": "Hyperacusis is a debilitating hearing disorder characterized by an increased sensitivity to everyday sounds.",
        "severity": "moderate",
        "treatment": "sound therapy (retraining), cognitive behavioral therapy, ear protection",
        "source": "American Tinnitus Association"
    },
    {
        "condition": "Chalazion",
        "symptoms": ["painless bump on eyelid", "eyelid tenderness", "blurred vision if bump is large"],
        "description": "A chalazion is a slow-growing, painless lump on the eyelid. It’s caused by a blockage in one of the small oil glands (meibomian glands) in the upper or lower eyelid.",
        "severity": "mild",
        "treatment": "warm compresses, eyelid massage, steroid injections, surgical drainage",
        "source": "American Academy of Ophthalmology"
    },
    {
        "condition": "Conjunctivitis (Pink Eye)",
        "symptoms": ["redness in one or both eyes", "itchiness", "gritty feeling", "discharge that forms a crust"],
        "description": "Pink eye (conjunctivitis) is an inflammation or infection of the transparent membrane (conjunctiva) that lines your eyelid and covers the white part of your eyeball.",
        "severity": "mild",
        "treatment": "antibiotic eye drops (if bacterial), antihistamines (if allergic), cold compress",
        "source": "CDC"
    },
    {
        "condition": "Keratoconus",
        "symptoms": ["blurred or distorted vision", "increased sensitivity to bright light",
                     "frequent changes in eyeglass prescriptions"],
        "description": "Keratoconus is an eye condition in which your cornea — the clear, dome-shaped front surface of your eye — thins and gradually bulges outward into a cone shape.",
        "severity": "moderate to severe",
        "treatment": "contact lenses, corneal cross-linking, corneal transplant",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Strabismus (Crossed Eyes)",
        "symptoms": ["eyes that don't look in the same direction", "uncoordinated eye movements", "double vision"],
        "description": "Strabismus is a condition in which your eyes don't line up with one another. In other words, one eye looks in a different direction from the other eye.",
        "severity": "mild to moderate",
        "treatment": "eyeglasses, prism lenses, vision therapy, eye muscle surgery",
        "source": "American Optometric Association"
    },
    {
        "condition": "Amblyopia (Lazy Eye)",
        "symptoms": ["an eye that wanders inward or outward", "eyes that appear to not work together",
                     "poor depth perception"],
        "description": "Amblyopia is reduced vision in one eye caused by abnormal visual development early in life. The 'lazy' eye often wanders inward or outward.",
        "severity": "moderate",
        "treatment": "corrective eyewear, eye patches, eye drops (to blur the strong eye)",
        "source": "NIH - NEI"
    },
    {
        "condition": "Retinal detachment",
        "symptoms": ["sudden appearance of many floaters", "flashes of light",
                     "a curtain-like shadow over your visual field"],
        "description": "Retinal detachment describes an emergency situation in which a critical layer of tissue (the retina) at the back of the eye pulls away from the layer of blood vessels that provides it with oxygen.",
        "severity": "emergency",
        "treatment": "laser surgery, freezing (cryopexy), pneumatic retinopexy, vitrectomy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Diabetic retinopathy",
        "symptoms": ["spots or dark strings floating in vision", "blurred vision", "fluctuating vision",
                     "dark or empty areas in vision"],
        "description": "Diabetic retinopathy is a diabetes complication that affects eyes. It's caused by damage to the blood vessels of the light-sensitive tissue at the back of the eye (retina).",
        "severity": "severe",
        "treatment": "blood sugar control, laser treatment, vitrectomy, injections (anti-VEGF)",
        "source": "NIH - NEI"
    },
    {
        "condition": "Color blindness",
        "symptoms": ["difficulty distinguishing between colors", "inability to see shades or tones of the same color"],
        "description": "Most people with color blindness are unable to distinguish between certain shades of red and green. Less commonly, people cannot distinguish between shades of blue and yellow.",
        "severity": "mild",
        "treatment": "specialized lenses, mobile apps for color identification",
        "source": "NIH - NEI"
    },
    {
        "condition": "Anisocoria (Uneven pupils)",
        "symptoms": ["one pupil is larger than the other", "drooping eyelid", "eye pain"],
        "description": "Anisocoria is a condition where the pupils of your eyes are not the same size. Your pupils are the black circles in the middle of your eyes.",
        "severity": "mild to severe (depends on cause)",
        "treatment": "treating the underlying cause (infection, injury, or neurological issue)",
        "source": "American Academy of Ophthalmology"
    },
    {
        "condition": "Astigmatism",
        "symptoms": ["blurred or distorted vision", "eyestrain or discomfort", "headaches",
                     "difficulty with night vision"],
        "description": "Astigmatism is a common and generally treatable imperfection in the curvature of the eye that causes blurred distance and near vision.",
        "severity": "mild",
        "treatment": "corrective lenses (glasses or contacts), refractive surgery (LASIK)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Farsightedness (Hyperopia)",
        "symptoms": ["nearby objects may appear blurry", "need to squint to see clearly", "eyestrain", "burning eyes"],
        "description": "Farsightedness is a common vision condition in which you can see distant objects clearly, but objects nearby may be blurry.",
        "severity": "mild",
        "treatment": "eyeglasses, contact lenses, refractive surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Nearsightedness (Myopia)",
        "symptoms": ["blurry vision when looking at distant objects", "need to squint",
                     "headaches caused by eyestrain"],
        "description": "Nearsightedness is a common vision condition in which you can see objects near to you clearly, but objects farther away are blurry.",
        "severity": "mild",
        "treatment": "eyeglasses, contact lenses, refractive surgery, ortho-k",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Sinusitis",
        "symptoms": ["thick yellow or green mucus", "blocked or stuffy nose", "pain and tenderness around eyes",
                     "reduced sense of smell"],
        "description": "Sinusitis is an inflammation or swelling of the tissue lining the sinuses. Healthy sinuses are filled with air. But when they become blocked and filled with fluid, germs can grow and cause an infection.",
        "severity": "mild to moderate",
        "treatment": "saline nasal spray, nasal corticosteroids, decongestants, antibiotics",
        "source": "CDC"
    },
    {
        "condition": "Hay fever (Allergic rhinitis)",
        "symptoms": ["runny nose", "itchy eyes mouth or skin", "sneezing", "fatigue"],
        "description": "Hay fever, also called allergic rhinitis, causes cold-like signs and symptoms, such as a runny nose, itchy eyes, congestion, sneezing and sinus pressure.",
        "severity": "mild",
        "treatment": "antihistamines, nasal steroid sprays, decongestants, immunotherapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Nasal polyps",
        "symptoms": ["runny nose", "persistent stuffiness", "postnasal drip", "decreased sense of smell",
                     "facial pain"],
        "description": "Nasal polyps are soft, painless, noncancerous growths on the lining of your nasal passages or sinuses. They hang down like teardrops or grapes.",
        "severity": "moderate",
        "treatment": "nasal corticosteroids, oral corticosteroids, surgery (polypectomy)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Deviated septum",
        "symptoms": ["obstruction of one or both nostrils", "nosebleeds", "facial pain",
                     "noisy breathing during sleep"],
        "description": "A deviated septum occurs when the thin wall (nasal septum) between your nostrils is displaced to one side, making one nasal passage smaller.",
        "severity": "mild to moderate",
        "treatment": "decongestants, antihistamines, nasal steroid sprays, septoplasty surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Anosmia (Loss of smell)",
        "symptoms": ["inability to smell", "change in the way things smell", "reduced sense of taste"],
        "description": "Anosmia is the partial or complete loss of the sense of smell. This loss may be temporary or permanent.",
        "severity": "mild to moderate",
        "treatment": "treating underlying cause (sinusitis, polyps), smell retraining therapy",
        "source": "NIH - NIDCD"
    },
    {
        "condition": "Glossitis (Tongue inflammation)",
        "symptoms": ["swollen tongue", "smooth appearance of the tongue", "tongue color changes",
                     "difficulty speaking or eating"],
        "description": "Glossitis is a condition in which the tongue is swollen and changes color, often making the surface of the tongue appear smooth.",
        "severity": "mild",
        "treatment": "good oral hygiene, antibiotics (if infected), dietary changes",
        "source": "NIH - MedlinePlus"
    },
    {
        "condition": "Oral thrush",
        "symptoms": ["creamy white lesions on tongue", "redness or soreness", "feeling of cotton in mouth",
                     "loss of taste"],
        "description": "Oral thrush — also called oral candidiasis — is a condition in which the fungus Candida albicans accumulates on the lining of your mouth.",
        "severity": "mild to moderate",
        "treatment": "antifungal medications (fluconazole), antifungal mouthwash",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gingivitis",
        "symptoms": ["swollen or puffy gums", "dusky red or dark red gums", "gums that bleed easily", "bad breath"],
        "description": "Gingivitis is a common and mild form of gum disease (periodontal disease) that causes irritation, redness and swelling of your gingiva, the part of your gum around the base of your teeth.",
        "severity": "mild",
        "treatment": "professional dental cleaning, scaling and root planing, improved oral hygiene",
        "source": "American Dental Association"
    },
    {
        "condition": "Periodontitis",
        "symptoms": ["swollen or puffy gums", "bright red or purplish gums", "gums that feel tender",
                     "new spaces developing between teeth"],
        "description": "Periodontitis is a serious gum infection that damages the soft tissue and, without treatment, can destroy the bone that supports your teeth.",
        "severity": "moderate to severe",
        "treatment": "scaling and root planing, antibiotics, flap surgery, bone grafts",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Canker sore",
        "symptoms": ["small oval-shaped ulcer", "painful", "white or yellow center with red border",
                     "tingling sensation"],
        "description": "Canker sores, also called aphthous ulcers, are small, shallow lesions that develop on the soft tissues in your mouth or at the base of your gums.",
        "severity": "mild",
        "treatment": "mouth rinses (salt water), topical products (benzocaine), nutritional supplements",
        "source": "Mayo Clinic"
    },
    {
        "condition": "TMJ disorder",
        "symptoms": ["pain or tenderness of the jaw", "pain in one or both temporomandibular joints",
                     "aching pain in and around the ear"],
        "description": "Temporomandibular joint (TMJ) disorders cause pain in your jaw joint and in the muscles that control jaw movement.",
        "severity": "mild to moderate",
        "treatment": "pain relievers, oral splints/mouth guards, physical therapy",
        "source": "NIH - NIDCR"
    },
    {
        "condition": "Bruxism (Teeth grinding)",
        "symptoms": ["teeth grinding or clenching", "teeth that are flattened or chipped", "worn tooth enamel",
                     "jaw soreness"],
        "description": "Bruxism is a condition in which you grind, gnash or clench your teeth. If you have bruxism, you may unconsciously clench your teeth when you're awake or grind them during sleep.",
        "severity": "mild to moderate",
        "treatment": "mouth guards, dental correction, stress management, biofeedback",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Sleepwalking",
        "symptoms": ["getting out of bed and walking around", "sitting up in bed and opening eyes",
                     "having a glazed expression", "not responding to others"],
        "description": "Sleepwalking — also known as somnambulism — involves rising from a fragmented state of sleep and walking around while appearing to be asleep.",
        "severity": "mild to moderate",
        "treatment": "improving sleep hygiene, treating underlying conditions, anticipatory awakening",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Night terrors",
        "symptoms": ["sudden awakening from sleep", "persistent fear or terror", "sweating", "rapid heart rate",
                     "confusion"],
        "description": "Sleep terrors are episodes of screaming, intense fear and flailing while still asleep. Also known as night terrors, sleep terrors often are paired with sleepwalking.",
        "severity": "moderate",
        "treatment": "addressing stress, improving sleep schedule, medication (rarely)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Raynaud's disease",
        "symptoms": ["cold fingers or toes", "color changes in skin", "numb prickly feeling upon warming"],
        "description": "Raynaud's disease causes smaller arteries that supply blood to your skin to narrow, limiting blood circulation to affected areas (vasospasm).",
        "severity": "mild to moderate",
        "treatment": "keeping hands/feet warm, calcium channel blockers, vasodilators",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Anemia of chronic disease",
        "symptoms": ["fatigue", "shortness of breath", "pale skin", "lightheadedness", "fast heartbeat"],
        "description": "Anemia of inflammation, also called anemia of chronic disease, is a type of anemia that affects people who have conditions that cause inflammation, such as infections or autoimmune diseases.",
        "severity": "moderate",
        "treatment": "treating the underlying disease, erythropoietin injections, iron therapy",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Thalassemia",
        "symptoms": ["fatigue", "weakness", "pale or yellowish skin", "facial bone deformities", "slow growth",
                     "abdominal swelling"],
        "description": "Thalassemia is an inherited blood disorder that causes your body to have less hemoglobin than normal. Hemoglobin enables red blood cells to carry oxygen.",
        "severity": "moderate to severe",
        "treatment": "blood transfusions, chelation therapy, folic acid supplements, bone marrow transplant",
        "source": "CDC"
    },
    {
        "condition": "Sickle cell anemia",
        "symptoms": ["episodes of pain (crises)", "swelling of hands and feet", "frequent infections", "delayed growth",
                     "vision problems"],
        "description": "Sickle cell anemia is one of a group of inherited disorders known as sickle cell disease. It affects the shape of red blood cells, which carry oxygen to all parts of the body.",
        "severity": "severe",
        "treatment": "hydroxyurea, pain relievers, blood transfusions, stem cell transplant",
        "source": "CDC"
    },
    {
        "condition": "Hemophilia",
        "symptoms": ["unexplained and excessive bleeding", "many large or deep bruises", "pain or swelling in joints",
                     "blood in urine or stool"],
        "description": "Hemophilia is a rare disorder in which your blood doesn't clot normally because it lacks sufficient blood-clotting proteins (clotting factors).",
        "severity": "severe",
        "treatment": "replacement therapy (factor VIII or IX), desmopressin (DDAVP), physical therapy",
        "source": "CDC"
    },
    {
        "condition": "Leukemia",
        "symptoms": ["fever or chills", "persistent fatigue", "frequent or severe infections",
                     "losing weight without trying", "swollen lymph nodes"],
        "description": "Leukemia is cancer of the body's blood-forming tissues, including the bone marrow and the lymphatic system. Many types of leukemia exist.",
        "severity": "severe",
        "treatment": "chemotherapy, targeted therapy, radiation therapy, bone marrow transplant",
        "source": "NIH - NCI"
    },
    {
        "condition": "Lymphoma",
        "symptoms": ["painless swelling of lymph nodes", "persistent fatigue", "fever", "night sweats",
                     "shortness of breath"],
        "description": "Lymphoma is a cancer of the lymphatic system, which is part of the body's germ-fighting network.",
        "severity": "severe",
        "treatment": "chemotherapy, immunotherapy drugs, radiation therapy, bone marrow transplant",
        "source": "NIH - NCI"
    },
    {
        "condition": "Multiple myeloma",
        "symptoms": ["bone pain in spine or chest", "nausea", "constipation", "loss of appetite", "mental confusion"],
        "description": "Multiple myeloma is a cancer that forms in a type of white blood cell called a plasma cell. Healthy plasma cells help you fight infections by making antibodies.",
        "severity": "severe",
        "treatment": "targeted therapy, immunotherapy, chemotherapy, corticosteroids, bone marrow transplant",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Deep vein thrombosis (DVT)",
        "symptoms": ["swelling in the affected leg", "pain in the leg", "red or discolored skin on the leg",
                     "feeling of warmth in the affected leg"],
        "description": "Deep vein thrombosis (DVT) occurs when a blood clot (thrombus) forms in one or more of the deep veins in your body, usually in your legs.",
        "severity": "severe",
        "treatment": "blood thinners (anticoagulants), clot busters (thrombolytics), filters, compression stockings",
        "source": "CDC"
    },
    {
        "condition": "Aortic aneurysm",
        "symptoms": ["deep aching pain in back or side", "throbbing sensation near the navel", "shortness of breath",
                     "cough"],
        "description": "An aortic aneurysm is a balloon-like bulge in the aorta, the large artery that carries blood from the heart through the chest and torso.",
        "severity": "severe",
        "treatment": "monitoring (watchful waiting), medications to lower blood pressure, surgery",
        "source": "CDC"
    },
    {
        "condition": "Peripheral artery disease",
        "symptoms": ["painful cramping in hips or legs", "leg numbness or weakness", "coldness in lower leg or foot",
                     "sores on toes or feet that won't heal"],
        "description": "Peripheral artery disease (PAD) is a common circulatory problem in which narrowed arteries reduce blood flow to your limbs.",
        "severity": "moderate to severe",
        "treatment": "cholesterol medications, blood pressure medications, supervised exercise, angioplasty",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Atrial fibrillation",
        "symptoms": ["palpitations", "shortness of breath", "weakness", "fatigue", "lightheadedness", "chest pain"],
        "description": "Atrial fibrillation (A-fib) is an irregular and often very rapid heart rhythm (arrhythmia) that can lead to blood clots in the heart and increase the risk of stroke and heart failure.",
        "severity": "severe",
        "treatment": "blood thinners, beta blockers, cardioversion, catheter ablation",
        "source": "American Heart Association"
    },
    {
        "condition": "Angina",
        "symptoms": ["chest pain", "pressure in chest", "squeezing sensation", "pain in arms neck or jaw"],
        "description": "Angina is a type of chest pain caused by reduced blood flow to the heart. It is a symptom of coronary artery disease.",
        "severity": "moderate to severe",
        "treatment": "nitroglycerin, lifestyle changes, angioplasty, beta blockers",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Mitral valve regurgitation",
        "symptoms": ["shortness of breath", "fatigue", "lightheadedness", "heart palpitations",
                     "swollen feet or ankles"],
        "description": "Mitral valve regurgitation is a type of heart valve disease in which the valve between the left heart chambers doesn't close tightly, allowing blood to leak backward.",
        "severity": "severe",
        "treatment": "diuretics, blood thinners, mitral valve repair or replacement",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Endocarditis",
        "symptoms": ["fever and chills", "aching joints and muscles", "chest pain when breathing", "fatigue",
                     "night sweats"],
        "description": "Endocarditis is a life-threatening inflammation of the inner lining of the heart's chambers and valves, usually caused by bacteria.",
        "severity": "emergency",
        "treatment": "high-dose IV antibiotics, heart valve surgery, supportive care",
        "source": "CDC"
    },
    {
        "condition": "Pericarditis",
        "symptoms": ["sharp chest pain", "shortness of breath", "palpitations", "low-grade fever", "overall weakness"],
        "description": "Pericarditis is swelling and irritation of the thin, saclike tissue surrounding the heart (pericardium). It often causes sharp chest pain.",
        "severity": "moderate",
        "treatment": "anti-inflammatory meds (colchicine), aspirin, rest",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Sciatica",
        "symptoms": ["pain radiating from lower spine to buttock", "numbness in leg", "tingling sensation",
                     "muscle weakness"],
        "description": "Sciatica refers to pain that radiates along the path of the sciatic nerve, which branches from your lower back through your hips and buttocks and down each leg.",
        "severity": "moderate",
        "treatment": "physical therapy, hot/cold packs, pain relievers, steroid injections",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Herniated disk",
        "symptoms": ["arm or leg pain", "numbness or tingling", "weakness in muscles", "sharp electric-like pain"],
        "description": "A herniated disk refers to a problem with one of the rubbery cushions (disks) that sit between the individual bones (vertebrae) that stack to make your spine.",
        "severity": "moderate to severe",
        "treatment": "rest, physical therapy, muscle relaxants, surgery (discectomy)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Spinal stenosis",
        "symptoms": ["numbness or tingling in hand or foot", "weakness", "pain or cramping in one or both legs",
                     "back pain"],
        "description": "Spinal stenosis is a narrowing of the spaces within your spine, which can put pressure on the nerves that travel through the spine.",
        "severity": "moderate to severe",
        "treatment": "physical therapy, decompression surgery, pain management",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Fibromyalgia",
        "symptoms": ["widespread muscle pain", "fatigue", "sleep issues", "memory issues", "mood issues"],
        "description": "Fibromyalgia is a disorder characterized by widespread musculoskeletal pain accompanied by fatigue, sleep, memory and mood issues.",
        "severity": "moderate",
        "treatment": "pain relievers, antidepressants, anti-seizure drugs, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gout",
        "symptoms": ["intense joint pain", "lingering discomfort", "inflammation and redness",
                     "limited range of motion"],
        "description": "Gout is a common and complex form of arthritis that can affect anyone. It's characterized by sudden, severe attacks of pain, swelling, and redness in the joints.",
        "severity": "moderate",
        "treatment": "NSAIDs, colchicine, corticosteroids, medications to lower uric acid",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Paget's disease of bone",
        "symptoms": ["bone pain", "enlarged bones", "fractures", "joint pain", "hearing loss (if in skull)"],
        "description": "Paget's disease of bone interferes with your body's normal bone recycling process, in which new bone tissue gradually replaces old bone tissue. Over time, bones can become fragile and misshapen.",
        "severity": "moderate",
        "treatment": "bisphosphonates, surgery for fractures, physical therapy",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Osteomyelitis",
        "symptoms": ["fever", "swelling and warmth in the area of infection", "pain in the area of infection",
                     "fatigue"],
        "description": "Osteomyelitis is an infection in a bone. Infections can reach a bone by traveling through the bloodstream or spreading from nearby tissue.",
        "severity": "severe",
        "treatment": "IV antibiotics, surgical drainage, removal of infected bone",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Kyphosis",
        "symptoms": ["rounded back", "back pain", "stiffness", "fatigue"],
        "description": "Kyphosis is an exaggerated, forward rounding of the back. It can occur at any age but is most common in older women.",
        "severity": "mild to moderate",
        "treatment": "physical therapy, back braces, pain medication, surgery for severe curves",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Scoliosis",
        "symptoms": ["uneven shoulders", "one shoulder blade that appears more prominent", "uneven waist",
                     "one hip higher than the other"],
        "description": "Scoliosis is a sideways curvature of the spine that occurs most often during the growth spurt just before puberty.",
        "severity": "mild to moderate",
        "treatment": "bracing, physical therapy, spinal fusion surgery (severe cases)",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Bunions",
        "symptoms": ["bulging bump on outside of base of big toe", "swelling and redness", "corns or calluses",
                     "ongoing pain"],
        "description": "A bunion is a bony bump that forms on the joint at the base of your big toe. It occurs when some of the bones in the front part of your foot move out of place.",
        "severity": "mild",
        "treatment": "changing shoes, padding, ice, surgery (bunionectomy)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Plantar fasciitis",
        "symptoms": ["stabbing pain in the bottom of foot near the heel", "pain with the first steps in morning",
                     "pain after long periods of standing"],
        "description": "Plantar fasciitis is one of the most common causes of heel pain. It involves inflammation of a thick band of tissue that runs across the bottom of each foot.",
        "severity": "mild",
        "treatment": "stretching exercises, physical therapy, orthotics, night splints",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Carpal tunnel syndrome",
        "symptoms": ["tingling or numbness in fingers", "weakness in hand", "dropping objects", "pain in wrist"],
        "description": "Carpal tunnel syndrome is caused by pressure on the median nerve. The carpal tunnel is a narrow passageway surrounded by bones and ligaments on the palm side of your hand.",
        "severity": "moderate",
        "treatment": "wrist splinting, NSAIDs, corticosteroid injections, surgery (release)",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Tennis elbow",
        "symptoms": ["pain radiating from outside of elbow into forearm", "weakness in grip",
                     "pain when lifting something"],
        "description": "Tennis elbow (lateral epicondylitis) is a painful condition that occurs when tendons in your elbow are overworked, usually by repetitive motions of the wrist and arm.",
        "severity": "mild",
        "treatment": "rest, ice, physical therapy, counter-force brace",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Ganglion cyst",
        "symptoms": ["round or oval lump", "painless or slight ache", "tingling or numbness if pressing on nerve"],
        "description": "Ganglion cysts are noncancerous lumps that most commonly develop along the tendons or joints of your wrists or hands.",
        "severity": "mild",
        "treatment": "observation, immobilization, aspiration (draining), surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Bursitis",
        "symptoms": ["joints feel stiff or achy", "pain when moving the joint", "joint looks swollen and red"],
        "description": "Bursitis is a painful condition that affects the small, fluid-filled sacs — called bursae — that cushion the bones, tendons and muscles near your joints.",
        "severity": "mild",
        "treatment": "rest, ice, pain relievers, physical therapy, steroid injections",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Tendonitis",
        "symptoms": ["pain described as dull ache", "tenderness", "mild swelling"],
        "description": "Tendinitis is inflammation or irritation of a tendon — the thick fibrous cords that attach muscle to bone. The condition causes pain and tenderness just outside a joint.",
        "severity": "mild",
        "treatment": "R.I.C.E (rest, ice, compression, elevation), physical therapy, corticosteroids",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gallbladder cancer",
        "symptoms": ["abdominal pain in upper right", "abdominal bloating", "fever", "losing weight without trying",
                     "jaundice"],
        "description": "Gallbladder cancer is uncommon. When gallbladder cancer is discovered at its earliest stages, the chance for a cure is very good.",
        "severity": "severe",
        "treatment": "cholecystectomy, liver resection, chemotherapy, radiation therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Colon cancer",
        "symptoms": ["change in bowel habits", "rectal bleeding", "persistent abdominal discomfort",
                     "weakness or fatigue", "unexplained weight loss"],
        "description": "Colon cancer is a type of cancer that begins in the large intestine (colon). The colon is the final part of the digestive tract.",
        "severity": "severe",
        "treatment": "surgery (colectomy), chemotherapy, radiation therapy, targeted drug therapy",
        "source": "CDC"
    },
    {
        "condition": "Pancreatic cancer",
        "symptoms": ["abdominal pain radiating to back", "loss of appetite", "yellowing of skin",
                     "light-colored stools", "dark-colored urine"],
        "description": "Pancreatic cancer begins in the tissues of your pancreas — an organ in your abdomen that lies behind the lower part of your stomach.",
        "severity": "severe",
        "treatment": "Whipple procedure, distal pancreatectomy, chemotherapy, radiation",
        "source": "NIH - NCI"
    },
    {
        "condition": "Stomach cancer",
        "symptoms": ["fatigue", "feeling bloated after eating", "feeling full after small amounts of food",
                     "severe indigestion", "persistent nausea"],
        "description": "Stomach cancer, also known as gastric cancer, is an abnormal growth of cells that begins in the stomach.",
        "severity": "severe",
        "treatment": "surgery (gastrectomy), chemotherapy, radiation therapy, immunotherapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Esophageal cancer",
        "symptoms": ["difficulty swallowing", "weight loss without trying", "chest pain or burning",
                     "worsening indigestion", "coughing or hoarseness"],
        "description": "Esophageal cancer is cancer that occurs in the esophagus — a long, hollow tube that runs from your throat to your stomach.",
        "severity": "severe",
        "treatment": "surgery (esophagectomy), chemotherapy, radiation therapy, laser therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Liver cancer",
        "symptoms": ["losing weight without trying", "loss of appetite", "upper abdominal pain", "nausea and vomiting",
                     "general weakness and fatigue"],
        "description": "Liver cancer is cancer that begins in the cells of your liver. The most common type of liver cancer is hepatocellular carcinoma.",
        "severity": "severe",
        "treatment": "liver transplant, partial hepatectomy, ablation, chemoembolization",
        "source": "NIH - NCI"
    },
    {
        "condition": "Bladder cancer",
        "symptoms": ["blood in urine", "frequent urination", "painful urination", "back pain"],
        "description": "Bladder cancer is a common type of cancer that begins in the cells of the bladder.",
        "severity": "severe",
        "treatment": "transurethral resection, cystectomy, chemotherapy, immunotherapy",
        "source": "CDC"
    },
    {
        "condition": "Kidney cancer",
        "symptoms": ["blood in urine", "pain in back or side that doesn't go away", "loss of appetite",
                     "unexplained weight loss", "fatigue"],
        "description": "Kidney cancer is cancer that begins in the kidneys. Your kidneys are two bean-shaped organs, each about the size of your fist.",
        "severity": "severe",
        "treatment": "nephrectomy, cryoablation, radiofrequency ablation, immunotherapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Prostate cancer",
        "symptoms": ["trouble urinating", "decreased force in the stream of urine", "blood in urine", "blood in semen",
                     "bone pain"],
        "description": "Prostate cancer is cancer that occurs in the prostate. Prostate cancer is one of the most common types of cancer.",
        "severity": "severe",
        "treatment": "active surveillance, prostatectomy, radiation therapy, hormone therapy",
        "source": "CDC"
    },
    {
        "condition": "Ovarian cancer",
        "symptoms": ["abdominal bloating or swelling", "quickly feeling full when eating", "weight loss",
                     "discomfort in pelvic area", "fatigue"],
        "description": "Ovarian cancer is a type of cancer that begins in the ovaries. The female reproductive system contains two ovaries, one on each side of the uterus.",
        "severity": "severe",
        "treatment": "surgery (oophorectomy), chemotherapy, targeted therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Cervical cancer",
        "symptoms": ["vaginal bleeding after intercourse", "watery bloody vaginal discharge",
                     "pelvic pain or pain during intercourse"],
        "description": "Cervical cancer is a type of cancer that occurs in the cells of the cervix — the lower part of the uterus that connects to the vagina.",
        "severity": "severe",
        "treatment": "cone biopsy, hysterectomy, radiation therapy, chemotherapy",
        "source": "CDC"
    },
    {
        "condition": "Testicular cancer",
        "symptoms": ["lump or enlargement in either testicle", "feeling of heaviness in scrotum",
                     "dull ache in abdomen or groin", "sudden collection of fluid in scrotum"],
        "description": "Testicular cancer occurs in the testicles (testes), which are located inside the scrotum, a loose bag of skin underneath the penis.",
        "severity": "severe",
        "treatment": "radical inguinal orchiectomy, lymph node dissection, chemotherapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Skin cancer (Basal cell carcinoma)",
        "symptoms": ["pearly white or waxy bump", "flat flesh-colored scar-like lesion",
                     "bleeding or scabbing sore that heals and returns"],
        "description": "Basal cell carcinoma is a type of skin cancer. Basal cell carcinoma begins in the basal cells — a type of cell within the skin that produces new skin cells as old ones die off.",
        "severity": "moderate",
        "treatment": "Mohs surgery, curettage and electrodesiccation, cryosurgery",
        "source": "Skin Cancer Foundation"
    },
    {
        "condition": "Skin cancer (Squamous cell carcinoma)",
        "symptoms": ["firm red nodule", "flat sore with a scaly crust", "new sore or raised area on an old scar",
                     "rough scaly patch on lip"],
        "description": "Squamous cell carcinoma of the skin is a common form of skin cancer that develops in the squamous cells that make up the middle and outer layers of the skin.",
        "severity": "moderate",
        "treatment": "excision, Mohs surgery, radiation therapy",
        "source": "Skin Cancer Foundation"
    },
    {
        "condition": "Melanoma",
        "symptoms": ["large brownish spot with darker speckles", "mole that changes in color size or feel",
                     "small lesion with irregular border", "dark lesions on palms or soles"],
        "description": "Melanoma, the most serious type of skin cancer, develops in the cells (melanocytes) that produce melanin — the pigment that gives your skin its color.",
        "severity": "severe",
        "treatment": "surgical excision, sentinel lymph node biopsy, immunotherapy, targeted therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Sarcoma",
        "symptoms": ["lump that can be felt through the skin", "bone pain", "broken bone that happens unexpectedly",
                     "abdominal pain", "weight loss"],
        "description": "Sarcoma is a type of cancer that can occur in various locations in your body. Sarcoma is the general term for a broad group of cancers that begin in the bones and in the soft tissues.",
        "severity": "severe",
        "treatment": "surgery, radiation therapy, chemotherapy, targeted therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Brain tumor",
        "symptoms": ["new onset of headaches", "headaches that become more frequent", "unexplained nausea",
                     "vision problems", "loss of sensation in limbs"],
        "description": "A brain tumor is a mass or growth of abnormal cells in your brain. Many different types of brain tumors exist.",
        "severity": "severe",
        "treatment": "surgery, radiation therapy, radiosurgery, chemotherapy, targeted drug therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Thyroid cancer",
        "symptoms": ["lump that can be felt through skin on neck", "changes to your voice", "difficulty swallowing",
                     "pain in neck and throat", "swollen lymph nodes in neck"],
        "description": "Thyroid cancer is a type of cancer that starts in the thyroid gland. The thyroid gland is a butterfly-shaped gland located at the base of your neck.",
        "severity": "severe",
        "treatment": "thyroidectomy, radioactive iodine, thyroid hormone therapy",
        "source": "American Thyroid Association"
    },
    {
        "condition": "Mouth cancer",
        "symptoms": ["sore that doesn't heal", "white or reddish patch on inside of mouth", "loose teeth",
                     "growth or lump inside mouth", "mouth pain"],
        "description": "Mouth cancer refers to cancer that develops in any of the parts that make up the mouth (oral cavity).",
        "severity": "severe",
        "treatment": "surgery to remove tumor, radiation therapy, chemotherapy, targeted therapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Hodgkin's lymphoma",
        "symptoms": ["painless swelling of lymph nodes", "persistent fatigue", "fever", "night sweats",
                     "unexplained weight loss", "severe itching"],
        "description": "Hodgkin's lymphoma is a type of cancer that affects the lymphatic system, which is part of the body's germ-fighting immune system.",
        "severity": "severe",
        "treatment": "chemotherapy, radiation therapy, bone marrow transplant, immunotherapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Non-Hodgkin's lymphoma",
        "symptoms": ["swollen lymph nodes in neck armpits or groin", "abdominal pain or swelling",
                     "chest pain coughing or trouble breathing", "persistent fatigue", "fever"],
        "description": "Non-Hodgkin's lymphoma is a cancer that starts in white blood cells called lymphocytes, which are part of the body's immune system.",
        "severity": "severe",
        "treatment": "chemotherapy, immunotherapy, targeted therapy, bone marrow transplant",
        "source": "NIH - NCI"
    },
    {
        "condition": "Anaemia",
        "symptoms": ["fatigue", "weakness", "pale or yellowish skin", "irregular heartbeats", "shortness of breath",
                     "dizziness"],
        "description": "Anemia is a condition in which you lack enough healthy red blood cells to carry adequate oxygen to your body's tissues.",
        "severity": "moderate",
        "treatment": "iron supplements, vitamin B supplements, blood transfusions (if severe)",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Aneurysm",
        "symptoms": ["sudden extremely severe headache", "nausea and vomiting", "stiff neck",
                     "blurred or double vision", "sensitivity to light"],
        "description": "A brain aneurysm is a bulge or ballooning in a blood vessel in the brain. It often looks like a berry hanging on a stem.",
        "severity": "emergency",
        "treatment": "surgical clipping, endovascular coiling, flow diverters",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Appendicitis",
        "symptoms": ["sudden pain in lower right abdomen", "nausea and vomiting", "loss of appetite", "low-grade fever",
                     "constipation or diarrhea"],
        "description": "Appendicitis is an inflammation of the appendix, a finger-shaped pouch that projects from your colon on the lower right side of your abdomen.",
        "severity": "emergency",
        "treatment": "appendectomy (surgery to remove appendix), antibiotics",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Arteriosclerosis",
        "symptoms": ["chest pain", "sudden numbness or weakness in arms or legs", "difficulty speaking",
                     "leg pain when walking"],
        "description": "Arteriosclerosis occurs when the blood vessels that carry oxygen and nutrients from your heart to the rest of your body (arteries) become thick and stiff.",
        "severity": "severe",
        "treatment": "cholesterol medications, beta blockers, diuretics, lifestyle changes",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Atherosclerosis",
        "symptoms": ["chest pain (angina)", "numbness or weakness in limbs", "leg pain while exercising",
                     "high blood pressure"],
        "description": "Atherosclerosis is a specific type of arteriosclerosis. It refers to the buildup of fats, cholesterol and other substances in and on your artery walls (plaque).",
        "severity": "severe",
        "treatment": "statins, anti-platelet meds, angioplasty, lifestyle modifications",
        "source": "American Heart Association"
    },
    {
        "condition": "Bronchitis",
        "symptoms": ["cough", "production of mucus", "fatigue", "shortness of breath", "slight fever and chills",
                     "chest discomfort"],
        "description": "Bronchitis is an inflammation of the lining of your bronchial tubes, which carry air to and from your lungs. It can be acute or chronic.",
        "severity": "moderate",
        "treatment": "rest, fluids, cough medicine, humidified air, bronchodilators",
        "source": "CDC"
    },
    {
        "condition": "Colitis",
        "symptoms": ["diarrhea with blood or pus", "abdominal pain and cramping", "rectal pain", "rectal bleeding",
                     "urgency to defecate"],
        "description": "Colitis is inflammation of the inner lining of the colon. There are many types of colitis, including ulcerative colitis and Crohn's disease.",
        "severity": "moderate to severe",
        "treatment": "anti-inflammatory meds, immunosuppressants, lifestyle changes, hydration",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Concussion",
        "symptoms": ["headache", "confusion", "nausea", "dizziness", "drowsiness", "blurred vision"],
        "description": "A concussion is a traumatic brain injury that affects your brain function. Effects are usually temporary but can include headaches and problems with concentration.",
        "severity": "moderate",
        "treatment": "physical and cognitive rest, gradual return to activity, over-the-counter pain relievers",
        "source": "CDC"
    },
    {
        "condition": "Conjunctivitis",
        "symptoms": ["redness", "itchiness", "gritty feeling", "discharge that forms a crust"],
        "description": "Commonly known as pink eye, this is an inflammation or infection of the transparent membrane that lines your eyelid and covers the white part of your eyeball.",
        "severity": "mild",
        "treatment": "antibiotic eye drops, artificial tears, cold compresses",
        "source": "CDC"
    },
    {
        "condition": "Cystitis",
        "symptoms": ["strong persistent urge to urinate", "burning sensation when urinating",
                     "passing small amounts of urine", "blood in urine"],
        "description": "Cystitis is the medical term for inflammation of the bladder. Most of the time, the inflammation is caused by a bacterial infection, and it's called a urinary tract infection (UTI).",
        "severity": "moderate",
        "treatment": "antibiotics, increased fluid intake, heating pad",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Dementia",
        "symptoms": ["memory loss", "difficulty communicating", "difficulty with visual and spatial abilities",
                     "confusion and disorientation"],
        "description": "Dementia is not a specific disease, but rather a general term for the impaired ability to remember, think, or make decisions that interferes with doing everyday activities.",
        "severity": "severe",
        "treatment": "cholinesterase inhibitors, memantine, occupational therapy",
        "source": "CDC"
    },
    {
        "condition": "Dermatitis",
        "symptoms": ["itchy skin", "dry skin", "rash on swollen red skin", "blisters"],
        "description": "Dermatitis is a general term that describes a common skin irritation. It has many causes and forms and usually involves itchy, dry skin or a rash.",
        "severity": "mild",
        "treatment": "corticosteroid creams, calcineurin inhibitors, phototherapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Dysentery",
        "symptoms": ["abdominal cramps", "nausea", "vomiting", "fever", "diarrhea containing blood or mucus"],
        "description": "Dysentery is an intestinal inflammation, primarily of the colon. It can lead to severe diarrhea with mucus or blood in the feces.",
        "severity": "moderate to severe",
        "treatment": "rehydration, antibiotics (if bacterial), anti-parasitic meds (if amoebic)",
        "source": "WHO"
    },
    {
        "condition": "Fibrosis",
        "symptoms": ["shortness of breath", "dry cough", "fatigue", "unexplained weight loss",
                     "aching muscles and joints"],
        "description": "Fibrosis is the formation of excess fibrous connective tissue in an organ or tissue in a reparative or reactive process. Commonly affects lungs (pulmonary fibrosis).",
        "severity": "severe",
        "treatment": "oxygen therapy, pulmonary rehabilitation, lung transplant, antifibrotic drugs",
        "source": "NIH - NHLBI"
    },
    {
        "condition": "Gastritis",
        "symptoms": ["gnawing or burning ache in upper abdomen", "nausea", "vomiting",
                     "feeling of fullness after eating"],
        "description": "Gastritis is a general term for a group of conditions with one thing in common: inflammation of the lining of the stomach.",
        "severity": "moderate",
        "treatment": "antacids, proton pump inhibitors, H2 blockers, antibiotics for H. pylori",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gastroenteritis",
        "symptoms": ["watery diarrhea", "abdominal cramps", "nausea", "vomiting", "fever"],
        "description": "Often called the stomach flu, this is an inflammation of the lining of the intestines caused by a virus, bacteria, or parasites.",
        "severity": "moderate",
        "treatment": "rest, oral rehydration, bland diet (BRAT)",
        "source": "CDC"
    },
    {
        "condition": "Glaucoma",
        "symptoms": ["patchy blind spots in side or central vision", "tunnel vision", "severe headache", "eye pain",
                     "blurred vision"],
        "description": "Glaucoma is a group of eye conditions that damage the optic nerve, the health of which is vital for good vision. This damage is often caused by an abnormally high pressure in your eye.",
        "severity": "severe",
        "treatment": "prostaglandin eye drops, beta blockers, laser therapy, trabeculectomy",
        "source": "NIH - NEI"
    },
    {
        "condition": "Hepatitis A",
        "symptoms": ["fatigue", "nausea", "abdominal pain", "loss of appetite", "low-grade fever", "dark urine",
                     "jaundice"],
        "description": "Hepatitis A is a highly contagious liver infection caused by the hepatitis A virus. It is one of several types of hepatitis viruses that cause inflammation that affects your liver's ability to function.",
        "severity": "moderate",
        "treatment": "rest, adequate nutrition, fluids, avoidance of alcohol",
        "source": "CDC"
    },
    {
        "condition": "Hepatitis B",
        "symptoms": ["abdominal pain", "dark urine", "fever", "joint pain", "loss of appetite", "nausea", "jaundice"],
        "description": "Hepatitis B is a serious liver infection caused by the hepatitis B virus (HBV). For some people, hepatitis B infection becomes chronic, meaning it lasts more than six months.",
        "severity": "severe",
        "treatment": "antiviral medications, interferon injections, liver transplant",
        "source": "CDC"
    },
    {
        "condition": "Hepatitis C",
        "symptoms": ["bleeding easily", "bruising easily", "fatigue", "poor appetite", "jaundice",
                     "dark-colored urine"],
        "description": "Hepatitis C is a viral infection that causes liver inflammation, sometimes leading to serious liver damage. The hepatitis C virus (HCV) spreads through contaminated blood.",
        "severity": "severe",
        "treatment": "direct-acting antiviral (DAA) tablets, liver transplant",
        "source": "CDC"
    },
    {
        "condition": "Hernia",
        "symptoms": ["bulge in the affected area", "pain or discomfort", "weakness or pressure in abdomen",
                     "burning sensation at bulge"],
        "description": "A hernia occurs when an organ or fatty tissue squeezes through a weak spot in a surrounding muscle or connective tissue called fascia.",
        "severity": "moderate",
        "treatment": "monitoring, truss (supportive garment), laparoscopic or open surgery",
        "source": "FDA"
    },
    {
        "condition": "Hydrocephalus",
        "symptoms": ["unusually large head", "rapid increase in head size", "vomiting", "sleepiness", "irritability",
                     "seizures"],
        "description": "Hydrocephalus is the buildup of fluid in the cavities (ventricles) deep within the brain. The excess fluid increases the size of the ventricles and puts pressure on the brain.",
        "severity": "severe",
        "treatment": "surgical shunt insertion, endoscopic third ventriculostomy (ETV)",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Hyperthyroidism",
        "symptoms": ["unintentional weight loss", "rapid heartbeat", "increased appetite", "nervousness", "tremor",
                     "sweating"],
        "description": "Hyperthyroidism (overactive thyroid) occurs when your thyroid gland produces too much of the hormone thyroxine.",
        "severity": "moderate to severe",
        "treatment": "radioactive iodine, anti-thyroid medications, beta blockers, thyroidectomy",
        "source": "American Thyroid Association"
    },
    {
        "condition": "Hypothyroidism",
        "symptoms": ["fatigue", "increased sensitivity to cold", "constipation", "dry skin", "weight gain",
                     "puffy face"],
        "description": "Hypothyroidism (underactive thyroid) is a condition in which your thyroid gland doesn't produce enough of certain crucial hormones.",
        "severity": "moderate",
        "treatment": "levothyroxine (synthetic thyroid hormone)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Impetigo",
        "symptoms": ["red sores that rupture", "honey-colored crusts", "itching and soreness"],
        "description": "Impetigo is a common and highly contagious skin infection that mainly affects infants and children. It usually appears as red sores on the face, especially around a child's nose and mouth.",
        "severity": "mild",
        "treatment": "topical antibiotics (mupirocin), oral antibiotics",
        "source": "CDC"
    },
    {
        "condition": "Influenza",
        "symptoms": ["fever", "aching muscles", "chills and sweats", "headache", "dry persistent cough",
                     "shortness of breath", "fatigue"],
        "description": "Influenza is a viral infection that attacks your respiratory system — your nose, throat and lungs. Commonly called the flu.",
        "severity": "moderate",
        "treatment": "rest, fluids, antiviral drugs (oseltamivir), fever reducers",
        "source": "CDC"
    },
    {
        "condition": "Jaundice",
        "symptoms": ["yellowing of skin", "yellowing of whites of eyes", "pale stools", "dark urine"],
        "description": "Jaundice is a condition in which the skin, sclera (whites of the eyes) and mucous membranes turn yellow. This yellow color is caused by a high level of bilirubin.",
        "severity": "moderate to severe (symptom of underlying issue)",
        "treatment": "treating the underlying cause, phototherapy (in newborns)",
        "source": "CDC"
    },
    {
        "condition": "Laryngitis",
        "symptoms": ["hoarseness", "weak voice or voice loss", "tickling sensation in throat", "sore throat",
                     "dry cough"],
        "description": "Laryngitis is an inflammation of your voice box (larynx) from overuse, irritation or infection.",
        "severity": "mild",
        "treatment": "resting the voice, hydration, humidified air, avoiding irritants",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Malaria",
        "symptoms": ["fever", "chills", "headache", "nausea and vomiting", "muscle pain and fatigue"],
        "description": "Malaria is a disease caused by a parasite. The parasite is spread to humans through the bites of infected mosquitoes.",
        "severity": "severe",
        "treatment": "antimalarial drugs (chloroquine, artemisinin-based therapies)",
        "source": "WHO"
    },
    {
        "condition": "Mastitis",
        "symptoms": ["breast tenderness", "swelling", "pain or burning sensation continuously or while breast-feeding",
                     "skin redness", "fever"],
        "description": "Mastitis is an inflammation of breast tissue that sometimes involves an infection. The inflammation results in breast pain, swelling, warmth and redness.",
        "severity": "moderate",
        "treatment": "antibiotics, pain relievers, continued breast-feeding or pumping",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Migraine",
        "symptoms": ["severe throbbing pain", "nausea", "vomiting", "extreme sensitivity to light and sound"],
        "description": "A migraine is a headache that can cause severe throbbing pain or a pulsing sensation, usually on one side of the head.",
        "severity": "moderate to severe",
        "treatment": "triptans, pain relievers, preventative meds (beta blockers), trigger avoidance",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Nephritis",
        "symptoms": ["pink or cola-colored urine", "foamy urine", "high blood pressure",
                     "swelling in face hands feet and abdomen"],
        "description": "Nephritis is a condition in which the nephrons, the functional units of the kidneys, become inflamed. Also known as glomerulonephritis.",
        "severity": "severe",
        "treatment": "corticosteroids, immunosuppressants, blood pressure meds, dialysis",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Osteoporosis",
        "symptoms": ["back pain caused by fractured vertebra", "loss of height over time", "stooped posture",
                     "bone that breaks easily"],
        "description": "Osteoporosis causes bones to become weak and brittle — so brittle that a fall or even mild stresses such as bending over or coughing can cause a fracture.",
        "severity": "moderate to severe",
        "treatment": "bisphosphonates, hormone-related therapy, bone-building meds, calcium/Vit D",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Pneumonia",
        "symptoms": ["chest pain when you breathe or cough", "confusion", "cough which may produce phlegm", "fatigue",
                     "fever", "shortness of breath"],
        "description": "Pneumonia is an infection that inflames the air sacs in one or both lungs. The air sacs may fill with fluid or pus.",
        "severity": "severe",
        "treatment": "antibiotics (bacterial), antivirals (viral), cough medicine, fever reducers",
        "source": "American Lung Association"
    },
    {
        "condition": "Psoriasis",
        "symptoms": ["red patches of skin covered with thick silvery scales", "small scaling spots", "dry cracked skin",
                     "itching burning or soreness"],
        "description": "Psoriasis is a skin disease that causes red, itchy scaly patches, most commonly on the knees, elbows, trunk and scalp.",
        "severity": "moderate",
        "treatment": "topical steroids, retinoids, light therapy, biologics",
        "source": "NIH - NIAMS"
    },
    {
        "condition": "Rheumatic fever",
        "symptoms": ["fever", "painful tender joints", "chest pain", "fatigue", "jerky uncontrollable body movements"],
        "description": "Rheumatic fever is a disease that can develop when strep throat or scarlet fever isn't properly treated. It is caused by an immune response to the bacteria.",
        "severity": "severe",
        "treatment": "antibiotics (penicillin), anti-inflammatory meds, anticonvulsant meds",
        "source": "CDC"
    },
    {
        "condition": "Scurvy",
        "symptoms": ["fatigue", "swollen bleeding gums", "joint pain", "poor wound healing",
                     "red or blue spots on skin"],
        "description": "Scurvy is a condition caused by a severe lack of vitamin C in the diet. Although rare today, it was historically common among sailors.",
        "severity": "moderate",
        "treatment": "vitamin C supplements, eating citrus fruits and vegetables",
        "source": "NIH - ODS"
    },
    {
        "condition": "Septicemia",
        "symptoms": ["fever and chills", "very low body temperature", "peeing less than normal", "fast heartbeat",
                     "nausea and vomiting", "confusion"],
        "description": "Septicemia, or sepsis, is a life-threatening complication of an infection. It occurs when chemicals released into the bloodstream to fight the infection trigger inflammation throughout the body.",
        "severity": "emergency",
        "treatment": "IV antibiotics, IV fluids, vasopressors, supportive care",
        "source": "CDC"
    },
    {
        "condition": "Sinusitis",
        "symptoms": ["thick yellow or green mucus", "blocked or stuffy nose", "pain and tenderness around eyes",
                     "reduced sense of smell"],
        "description": "Sinusitis is an inflammation or swelling of the tissue lining the sinuses. It can be acute (short-term) or chronic (long-term).",
        "severity": "mild to moderate",
        "treatment": "nasal corticosteroids, saline nasal spray, decongestants, antibiotics",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Smallpox",
        "symptoms": ["fever", "overall discomfort", "headache", "severe fatigue", "back pain", "vomiting",
                     "flat red spots"],
        "description": "Smallpox was a contagious, disfiguring and often deadly disease that has been eradicated worldwide thanks to a global vaccination campaign.",
        "severity": "emergency (eradicated)",
        "treatment": "vaccination (prevention), antiviral drugs (tecovirimat)",
        "source": "CDC"
    },
    {
        "condition": "Syphilis",
        "symptoms": ["painless sore (chancre)", "skin rash", "sore throat", "fever", "swollen lymph glands", "fatigue"],
        "description": "Syphilis is a bacterial infection usually spread by sexual contact. The disease starts as a painless sore — typically on your genitals, rectum or mouth.",
        "severity": "severe",
        "treatment": "penicillin (preferred), doxycycline",
        "source": "CDC"
    },
    {
        "condition": "Tuberculosis",
        "symptoms": ["coughing for three or more weeks", "coughing up blood", "chest pain", "unintentional weight loss",
                     "fatigue", "fever", "night sweats"],
        "description": "Tuberculosis (TB) is a potentially serious infectious disease that mainly affects your lungs. The bacteria that cause tuberculosis are spread from one person to another through tiny droplets released into the air.",
        "severity": "severe",
        "treatment": "long-term antibiotics (isoniazid, rifampin, ethambutol)",
        "source": "CDC"
    },
    {
        "condition": "Typhoid",
        "symptoms": ["fever that starts low and increases", "headache", "weakness and fatigue", "muscle aches",
                     "sweating", "dry cough", "loss of appetite"],
        "description": "Typhoid fever is caused by Salmonella typhi bacteria. Typhoid fever is rare in developed countries. It is still a serious health threat in the developing world.",
        "severity": "severe",
        "treatment": "antibiotics (ciprofloxacin, azithromycin), hydration",
        "source": "CDC"
    },
    {
        "condition": "Urethritis",
        "symptoms": ["frequent urge to urinate", "pain during urination", "discharge from the urethral opening",
                     "blood in urine or semen"],
        "description": "Urethritis is inflammation of the urethra, the tube that carries urine from the bladder out of the body. It is often caused by an infection.",
        "severity": "moderate",
        "treatment": "antibiotics (azithromycin, doxycycline), treating partners",
        "source": "CDC"
    },
    {
        "condition": "Varicose veins",
        "symptoms": ["veins that are dark purple or blue", "veins that appear twisted and bulging",
                     "an achy or heavy feeling in legs", "burning throbbing and muscle cramping"],
        "description": "Varicose veins are swollen, twisted veins that lie just under the skin and usually occur in the legs.",
        "severity": "mild",
        "treatment": "compression stockings, sclerotherapy, laser treatment, vein stripping",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Yellow fever",
        "symptoms": ["fever", "headache", "muscle aches", "nausea", "vomiting", "jaundice", "bleeding"],
        "description": "Yellow fever is a viral infection spread by a particular species of mosquito. It's most common in areas of Africa and South America.",
        "severity": "severe",
        "treatment": "supportive care, fluids, oxygen, blood pressure management",
        "source": "WHO"
    },
    {
        "condition": "Angioedema",
        "symptoms": ["swelling around eyes lips or hands", "abdominal cramping", "difficulty breathing"],
        "description": "Angioedema is an area of swelling of the lower layer of skin and tissue just under the skin or mucous membranes.",
        "severity": "emergency (if airways involved)",
        "treatment": "antihistamines, epinephrine, corticosteroids",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Bacterial vaginosis",
        "symptoms": ["thin gray white or green vaginal discharge", "foul-smelling fishy vaginal odor",
                     "vaginal itching", "burning during urination"],
        "description": "Bacterial vaginosis is a type of vaginal inflammation caused by the overgrowth of bacteria naturally found in the vagina, which upsets the natural balance.",
        "severity": "mild",
        "treatment": "metronidazole, clindamycin, tinidazole",
        "source": "CDC"
    },
    {
        "condition": "Candidiasis",
        "symptoms": ["itching and irritation", "burning sensation", "redness and swelling", "vaginal pain",
                     "thick white odorless discharge"],
        "description": "Candidiasis is a fungal infection caused by a yeast (a type of fungus) called Candida. Often called a yeast infection.",
        "severity": "mild",
        "treatment": "antifungal creams (monistat), oral fluconazole",
        "source": "CDC"
    },
    {
        "condition": "Chlamydia",
        "symptoms": ["painful urination", "vaginal discharge in women", "discharge from the penis in men",
                     "pain during sexual intercourse"],
        "description": "Chlamydia is a common sexually transmitted infection (STI) caused by bacteria. You might not know you have chlamydia because many people don't have signs or symptoms.",
        "severity": "moderate",
        "treatment": "antibiotics (azithromycin, doxycycline)",
        "source": "CDC"
    },
    {
        "condition": "Gonorrhea",
        "symptoms": ["painful urination", "pus-like discharge from penis", "increased vaginal discharge",
                     "vaginal bleeding between periods", "pelvic pain"],
        "description": "Gonorrhea is a sexually transmitted disease (STD) that can infect both men and women. It can cause infections in the genitals, rectum, and throat.",
        "severity": "moderate to severe",
        "treatment": "ceftriaxone injection, oral azithromycin",
        "source": "CDC"
    },
    {
        "condition": "Genital herpes",
        "symptoms": ["pain or itching", "small red bumps or tiny white blisters", "ulcers", "scabs"],
        "description": "Genital herpes is a common sexually transmitted infection caused by the herpes simplex virus (HSV). Sexual contact is the primary way that the virus spreads.",
        "severity": "moderate",
        "treatment": "acyclovir, valacyclovir, famciclovir",
        "source": "CDC"
    },
    {
        "condition": "Genital warts",
        "symptoms": ["small flesh-colored or gray swellings",
                     "several warts close together that take on a cauliflower-like shape", "itching or discomfort",
                     "bleeding with intercourse"],
        "description": "Genital warts are a common sexually transmitted infection caused by the human papillomavirus (HPV).",
        "severity": "moderate",
        "treatment": "topical creams (imiquimod), cryotherapy, surgical excision, laser treatments",
        "source": "CDC"
    },
    {
        "condition": "Trichomoniasis",
        "symptoms": ["foul-smelling vaginal discharge", "genital itching", "painful urination",
                     "pain during intercourse"],
        "description": "Trichomoniasis is a very common sexually transmitted disease (STD) that is caused by infection with a protozoan parasite called Trichomonas vaginalis.",
        "severity": "moderate",
        "treatment": "metronidazole, tinidazole",
        "source": "CDC"
    },
    {
        "condition": "HIV/AIDS",
        "symptoms": ["fever", "headache", "muscle aches and joint pain", "rash", "sore throat and painful mouth sores",
                     "swollen lymph glands"],
        "description": "HIV is a virus that attacks the body’s immune system. If HIV is not treated, it can lead to AIDS (acquired immunodeficiency syndrome).",
        "severity": "severe",
        "treatment": "antiretroviral therapy (ART)",
        "source": "CDC"
    },
    {
        "condition": "Pelvic inflammatory disease",
        "symptoms": ["pain in your lower abdomen and pelvis", "abnormal or heavy vaginal discharge",
                     "abnormal uterine bleeding", "pain during intercourse", "fever"],
        "description": "Pelvic inflammatory disease (PID) is an infection of the female reproductive organs. It most often occurs when sexually transmitted bacteria spread from your vagina to your uterus, fallopian tubes or ovaries.",
        "severity": "severe",
        "treatment": "antibiotics, treating partners, temporary abstinence",
        "source": "CDC"
    },
    {
        "condition": "Molluscum contagiosum",
        "symptoms": ["raised round flesh-colored bumps", "small bumps with a small indentation or dot on top",
                     "red and inflamed bumps", "itching"],
        "description": "Molluscum contagiosum is a relatively common viral skin infection that results in round, firm, painless bumps ranging in size from a pinhead to a pencil eraser.",
        "severity": "mild",
        "treatment": "scraping (curettage), freezing (cryotherapy), topical acids",
        "source": "CDC"
    },
    {
        "condition": "Tonsillitis",
        "symptoms": ["red swollen tonsils", "white or yellow coating or patches on the tonsils", "sore throat",
                     "difficult or painful swallowing", "fever"],
        "description": "Tonsillitis is inflammation of the tonsils, two oval-shaped pads of tissue at the back of the throat — one tonsil on each side.",
        "severity": "mild to moderate",
        "treatment": "antibiotics (if bacterial), fluids, throat lozenges, tonsillectomy (if chronic)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Endometriosis",
        "symptoms": ["painful periods", "pain with intercourse", "pain with bowel movements", "excessive bleeding",
                     "infertility"],
        "description": "Endometriosis is an often painful disorder in which tissue similar to the tissue that normally lines the inside of your uterus — the endometrium — grows outside your uterus.",
        "severity": "moderate to severe",
        "treatment": "pain medications, hormone therapy, conservative surgery, hysterectomy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Polycystic ovary syndrome (PCOS)",
        "symptoms": ["irregular periods", "excess androgen", "polycystic ovaries", "weight gain", "acne",
                     "thinning hair"],
        "description": "PCOS is a hormonal disorder common among women of reproductive age. Women with PCOS may have infrequent or prolonged menstrual periods or excess male hormone levels.",
        "severity": "moderate",
        "treatment": "birth control pills, metformin, spironolactone, lifestyle changes",
        "source": "NIH - NICHD"
    },
    {
        "condition": "Uterine fibroids",
        "symptoms": ["heavy menstrual bleeding", "menstrual periods lasting more than a week",
                     "pelvic pressure or pain", "frequent urination"],
        "description": "Uterine fibroids are noncancerous growths of the uterus that often appear during childbearing years. Also called leiomyomas or myomas.",
        "severity": "moderate",
        "treatment": "watchful waiting, gonadotropin-releasing hormone agonists, uterine artery embolization, myomectomy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Ectopic pregnancy",
        "symptoms": ["pelvic pain", "light vaginal bleeding", "shoulder pain", "fainting or shock"],
        "description": "An ectopic pregnancy occurs when a fertilized egg implants and grows outside the main cavity of the uterus, most often in a fallopian tube.",
        "severity": "emergency",
        "treatment": "methotrexate medication, laparoscopic surgery, emergency surgery for rupture",
        "source": "American College of Obstetricians and Gynecologists"
    },
    {
        "condition": "Preeclampsia",
        "symptoms": ["high blood pressure", "excess protein in urine", "severe headaches", "vision changes",
                     "shortness of breath"],
        "description": "Preeclampsia is a pregnancy complication characterized by high blood pressure and signs of damage to another organ system, most often the liver and kidneys.",
        "severity": "emergency",
        "treatment": "delivery of the baby (primary treatment), blood pressure meds, anticonvulsants",
        "source": "CDC"
    },
    {
        "condition": "Celiac disease",
        "symptoms": ["diarrhea", "fatigue", "weight loss", "bloating and gas", "abdominal pain", "nausea and vomiting"],
        "description": "Celiac disease is an immune reaction to eating gluten, a protein found in wheat, barley and rye. Over time, this reaction damages your small intestine's lining.",
        "severity": "moderate to severe",
        "treatment": "strict gluten-free diet, vitamin and mineral supplements",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Irritable bowel syndrome (IBS)",
        "symptoms": ["abdominal pain", "cramping", "bloating", "gas", "diarrhea or constipation"],
        "description": "IBS is a common disorder that affects the large intestine. Signs and symptoms include cramping, abdominal pain, bloating, gas, and diarrhea or constipation.",
        "severity": "moderate",
        "treatment": "dietary changes (low FODMAP), stress management, fiber supplements, probiotics",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Crohn's disease",
        "symptoms": ["diarrhea", "fever", "fatigue", "abdominal pain and cramping", "blood in stool", "mouth sores",
                     "reduced appetite"],
        "description": "Crohn's disease is a type of inflammatory bowel disease (IBD). It causes inflammation of your digestive tract, which can lead to abdominal pain and severe diarrhea.",
        "severity": "severe",
        "treatment": "corticosteroids, immunosuppressants, biologics, surgery",
        "source": "Crohn's & Colitis Foundation"
    },
    {
        "condition": "Ulcerative colitis",
        "symptoms": ["diarrhea with blood or pus", "abdominal pain", "rectal pain", "urgency to defecate",
                     "weight loss"],
        "description": "Ulcerative colitis is an inflammatory bowel disease that causes long-lasting inflammation and ulcers in your digestive tract. It affects the innermost lining of your large intestine.",
        "severity": "severe",
        "treatment": "5-aminosalicylates, corticosteroids, biologics, colectomy (surgery)",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Diverticulitis",
        "symptoms": ["pain in lower left abdomen", "nausea and vomiting", "fever", "abdominal tenderness",
                     "constipation"],
        "description": "Diverticulitis occurs when small, bulging pouches (diverticula) that can form in the lining of your digestive system become inflamed or infected.",
        "severity": "moderate to severe",
        "treatment": "antibiotics, liquid diet, surgery for complications",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Peptic ulcer",
        "symptoms": ["burning stomach pain", "feeling of fullness", "intolerance to fatty foods", "heartburn",
                     "nausea"],
        "description": "Peptic ulcers are open sores that develop on the inside lining of your stomach and the upper portion of your small intestine.",
        "severity": "moderate",
        "treatment": "antibiotics (for H. pylori), PPIs, H2 blockers, antacids",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Gastroesophageal reflux disease (GERD)",
        "symptoms": ["heartburn", "chest pain", "difficulty swallowing", "regurgitation of food or sour liquid",
                     "sensation of a lump in throat"],
        "description": "GERD occurs when stomach acid frequently flows back into the tube connecting your mouth and stomach (esophagus). This backwash (acid reflux) can irritate the lining of your esophagus.",
        "severity": "moderate",
        "treatment": "antacids, H2 blockers, PPIs, fundoplication surgery",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Hemorrhoids",
        "symptoms": ["painless bleeding during bowel movements", "itching or irritation in anal region",
                     "pain or discomfort", "swelling around anus"],
        "description": "Hemorrhoids are swollen veins in your anus and lower rectum, similar to varicose veins.",
        "severity": "mild",
        "treatment": "high-fiber diet, OTC creams, sitz baths, rubber band ligation",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Gallstones",
        "symptoms": ["sudden and rapidly intensifying pain in upper right abdomen", "back pain between shoulder blades",
                     "pain in right shoulder", "nausea or vomiting"],
        "description": "Gallstones are hardened deposits of digestive fluid that can form in your gallbladder. Your gallbladder is a small, pear-shaped organ on the right side of your abdomen.",
        "severity": "moderate to severe",
        "treatment": "cholecystectomy (gallbladder removal), medications to dissolve stones",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Pancreatitis",
        "symptoms": ["upper abdominal pain", "abdominal pain that radiates to your back",
                     "tenderness when touching the abdomen", "fever", "rapid pulse"],
        "description": "Pancreatitis is inflammation in the pancreas. The pancreas is a long, flat gland that sits tucked behind the stomach in the upper abdomen.",
        "severity": "severe",
        "treatment": "hospitalization, IV fluids, fasting to rest pancreas, pain management",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Cirrhosis",
        "symptoms": ["fatigue", "easily bleeding or bruising", "loss of appetite", "nausea",
                     "swelling in legs feet or ankles", "jaundice"],
        "description": "Cirrhosis is a late stage of scarring (fibrosis) of the liver caused by many forms of liver diseases and conditions, such as hepatitis and chronic alcoholism.",
        "severity": "severe",
        "treatment": "treating alcohol dependency, weight loss, hepatitis medications, liver transplant",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Cystic fibrosis",
        "symptoms": ["persistent cough that produces thick mucus", "wheezing", "exercise intolerance",
                     "repeated lung infections", "foul-smelling greasy stools"],
        "description": "Cystic fibrosis is an inherited disorder that causes severe damage to the lungs, digestive system and other organs in the body.",
        "severity": "severe",
        "treatment": "CFTR modulators, airway clearance techniques, inhaled medications, lung transplant",
        "source": "Cystic Fibrosis Foundation"
    },
    {
        "condition": "Multiple sclerosis",
        "symptoms": ["numbness or weakness in limbs", "electric-shock sensations", "tremor", "lack of coordination",
                     "vision problems", "slurred speech"],
        "description": "Multiple sclerosis (MS) is a potentially disabling disease of the brain and spinal cord (central nervous system). The immune system attacks the protective sheath (myelin) that covers nerve fibers.",
        "severity": "severe",
        "treatment": "corticosteroids, plasmapheresis, disease-modifying therapies (Ocrevus, etc.)",
        "source": "National MS Society"
    },
    {
        "condition": "Parkinson's disease",
        "symptoms": ["tremor", "slowed movement (bradykinesia)", "rigid muscles", "impaired posture and balance",
                     "loss of automatic movements", "speech changes"],
        "description": "Parkinson's disease is a progressive nervous system disorder that affects movement. Symptoms start gradually, sometimes starting with a barely noticeable tremor in just one hand.",
        "severity": "severe",
        "treatment": "levodopa, dopamine agonists, MAO B inhibitors, deep brain stimulation",
        "source": "Parkinson's Foundation"
    },
    {
        "condition": "Alzheimer's disease",
        "symptoms": ["memory loss", "confusion with time or place", "difficulty completing familiar tasks",
                     "misplacing things", "withdrawal from social activities"],
        "description": "Alzheimer's disease is a progressive neurologic disorder that causes the brain to shrink (atrophy) and brain cells to die. Alzheimer's disease is the most common cause of dementia.",
        "severity": "severe",
        "treatment": "cholinesterase inhibitors, memantine, aducanumab, supportive care",
        "source": "Alzheimer's Association"
    },
    {
        "condition": "Amyotrophic lateral sclerosis (ALS)",
        "symptoms": ["difficulty walking", "tripping and falling", "weakness in legs feet or ankles",
                     "hand weakness or clumsiness", "slurred speech"],
        "description": "ALS is a progressive nervous system disease that affects nerve cells in the brain and spinal cord, causing loss of muscle control. Also known as Lou Gehrig's disease.",
        "severity": "severe",
        "treatment": "riluzole, edaravone, physical therapy, speech therapy, breathing support",
        "source": "ALS Association"
    },
    {
        "condition": "Huntington's disease",
        "symptoms": ["involuntary jerking (chorea)", "muscle problems", "slow or unusual eye movements",
                     "impaired gait", "difficulty swallowing"],
        "description": "Huntington's disease is an inherited disease that causes the progressive breakdown (degeneration) of nerve cells in the brain.",
        "severity": "severe",
        "treatment": "tetrabenazine, antipsychotic drugs, physical and occupational therapy",
        "source": "Huntington's Disease Society of America"
    },
    {
        "condition": "Myasthenia gravis",
        "symptoms": ["drooping of one or both eyelids", "blurred or double vision", "altered speaking",
                     "difficulty swallowing", "weakness in arms and legs"],
        "description": "Myasthenia gravis is characterized by weakness and rapid fatigue of any of the muscles under your voluntary control. It's caused by a breakdown in communication between nerves and muscles.",
        "severity": "severe",
        "treatment": "cholinesterase inhibitors, corticosteroids, immunosuppressants, plasmapheresis",
        "source": "Myasthenia Gravis Foundation of America"
    },
    {
        "condition": "Guillain-Barre syndrome",
        "symptoms": ["prickling pins and needles sensations", "weakness in legs that spreads to upper body",
                     "unsteady walking", "difficulty with facial movements"],
        "description": "Guillain-Barre syndrome is a rare disorder in which your body's immune system attacks your nerves. Weakness and tingling in your extremities are usually the first symptoms.",
        "severity": "emergency",
        "treatment": "plasmapheresis, immunoglobulin therapy, physical therapy",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Bell's palsy",
        "symptoms": ["sudden weakness on one side of face", "facial droop", "drooling", "pain around the jaw",
                     "increased sensitivity to sound", "headache"],
        "description": "Bell's palsy causes sudden, temporary weakness in your facial muscles. This makes half of your face appear to droop.",
        "severity": "moderate",
        "treatment": "corticosteroids, antiviral drugs, physical therapy, eye protection",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Epilepsy",
        "symptoms": ["temporary confusion", "staring spell", "uncontrollable jerking movements",
                     "loss of consciousness or awareness", "fear or anxiety"],
        "description": "Epilepsy is a central nervous system (neurological) disorder in which brain activity becomes abnormal, causing seizures or periods of unusual behavior and sensations.",
        "severity": "moderate to severe",
        "treatment": "anti-epileptic medications, ketogenic diet, vagus nerve stimulation, surgery",
        "source": "Epilepsy Foundation"
    },
    {
        "condition": "Aphasia",
        "symptoms": ["speak in short or incomplete sentences", "speak in sentences that don't make sense",
                     "substitute one word for another", "difficulty understanding others"],
        "description": "Aphasia is a condition that robs you of the ability to communicate. It can affect your ability to speak, write and understand language, both spoken and written.",
        "severity": "moderate to severe",
        "treatment": "speech and language rehabilitation, group therapy",
        "source": "National Aphasia Association"
    },
    {
        "condition": "Narcolepsy",
        "symptoms": ["excessive daytime sleepiness", "sudden loss of muscle tone (cataplexy)", "sleep paralysis",
                     "changes in REM sleep", "hallucinations"],
        "description": "Narcolepsy is a chronic sleep disorder characterized by overwhelming daytime drowsiness and sudden attacks of sleep.",
        "severity": "moderate to severe",
        "treatment": "stimulants, SSRIs, SNRIs, sodium oxybate",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Restless legs syndrome",
        "symptoms": ["sensations that begin after resting", "relief with movement", "worsening of symptoms in evening",
                     "nighttime leg twitching"],
        "description": "Restless legs syndrome (RLS) is a condition that causes an uncontrollable urge to move your legs, usually because of an uncomfortable sensation.",
        "severity": "mild to moderate",
        "treatment": "iron supplements, dopamine precursors, lifestyle changes, good sleep hygiene",
        "source": "RLS Foundation"
    },
    {
        "condition": "Sleep apnea",
        "symptoms": ["loud snoring", "episodes in which you stop breathing during sleep",
                     "gasping for air during sleep", "awakening with dry mouth", "morning headache"],
        "description": "Sleep apnea is a potentially serious sleep disorder in which breathing repeatedly stops and starts.",
        "severity": "moderate to severe",
        "treatment": "CPAP machine, oral appliances, upper airway surgery, weight loss",
        "source": "American Sleep Apnea Association"
    },
    {
        "condition": "Insomnia",
        "symptoms": ["difficulty falling asleep at night", "waking up during the night", "waking up too early",
                     "not feeling well-rested after a night's sleep"],
        "description": "Insomnia is a common sleep disorder that can make it hard to fall asleep, hard to stay asleep, or cause you to wake up too early and not be able to get back to sleep.",
        "severity": "mild to moderate",
        "treatment": "cognitive behavioral therapy for insomnia (CBT-I), sleep hygiene, melatonin",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Generalized anxiety disorder",
        "symptoms": ["persistent worrying", "overthinking plans", "perceiving situations as threatening",
                     "difficulty handling uncertainty", "restlessness"],
        "description": "GAD is characterized by persistent and excessive worry about a number of different things.",
        "severity": "moderate",
        "treatment": "psychotherapy (CBT), antidepressants, buspirone, benzodiazepines",
        "source": "NAMI"
    },
    {
        "condition": "Panic disorder",
        "symptoms": ["sense of impending doom or danger", "fear of loss of control or death", "rapid heart rate",
                     "sweating", "trembling", "shortness of breath"],
        "description": "Panic disorder is a type of anxiety disorder. It causes panic attacks, which are sudden feelings of terror when there is no real danger.",
        "severity": "moderate to severe",
        "treatment": "CBT, SSRIs, SNRIs, benzodiazepines",
        "source": "NIMH"
    },
    {
        "condition": "Obsessive-compulsive disorder (OCD)",
        "symptoms": ["fear of contamination", "needing things orderly", "aggressive thoughts", "excessive cleaning",
                     "ordering and arranging", "checking"],
        "description": "OCD is a disorder in which people have recurring, unwanted thoughts, ideas or sensations (obsessions) that make them feel driven to do something repetitively (compulsions).",
        "severity": "moderate to severe",
        "treatment": "CBT (Exposure and Response Prevention), SSRIs",
        "source": "International OCD Foundation"
    },
    {
        "condition": "Post-traumatic stress disorder (PTSD)",
        "symptoms": ["intrusive memories", "flashbacks", "avoidance", "negative changes in thinking and mood",
                     "changes in physical and emotional reactions"],
        "description": "PTSD is a mental health condition that's triggered by a terrifying event — either experiencing it or witnessing it.",
        "severity": "severe",
        "treatment": "cognitive therapy, exposure therapy, EMDR, antidepressants",
        "source": "VA - National Center for PTSD"
    },
    {
        "condition": "Major depressive disorder",
        "symptoms": ["feelings of sadness or hopelessness", "angry outbursts", "loss of interest in normal activities",
                     "sleep disturbances", "reduced appetite"],
        "description": "Depression is a mood disorder that causes a persistent feeling of sadness and loss of interest.",
        "severity": "severe",
        "treatment": "SSRIs, SNRIs, psychotherapy, ECT, lifestyle changes",
        "source": "NIMH"
    },
    {
        "condition": "Bipolar disorder",
        "symptoms": ["abnormally upbeat or jumpy", "increased activity or energy",
                     "exaggerated sense of self-confidence", "decreased need for sleep", "unusual talkativeness"],
        "description": "Bipolar disorder, formerly called manic depression, is a mental health condition that causes extreme mood swings that include emotional highs (mania or hypomania) and lows (depression).",
        "severity": "severe",
        "treatment": "mood stabilizers (lithium), antipsychotics, antidepressants, psychotherapy",
        "source": "NAMI"
    },
    {
        "condition": "Schizophrenia",
        "symptoms": ["delusions", "hallucinations", "disorganized thinking",
                     "extremely disorganized or abnormal motor behavior", "negative symptoms"],
        "description": "Schizophrenia is a serious mental disorder in which people interpret reality abnormally.",
        "severity": "severe",
        "treatment": "antipsychotic medications, psychosocial interventions, hospitalization",
        "source": "NIMH"
    },
    {
        "condition": "Autism spectrum disorder",
        "symptoms": ["fails to respond to name", "resists cuddling and holding", "poor eye contact",
                     "doesn't speak or has delayed speech", "repetitive movements"],
        "description": "ASD is a condition related to brain development that impacts how a person perceives and socializes with others, causing problems in social interaction and communication.",
        "severity": "variable",
        "treatment": "behavior and communication therapies, educational therapies, family therapies, medications",
        "source": "CDC"
    },
    {
        "condition": "ADHD",
        "symptoms": ["difficulty sustaining attention", "struggle to follow instructions",
                     "difficulty organizing tasks", "fidgeting or squirming", "excessive talking"],
        "description": "ADHD is a chronic condition including attention difficulty, hyperactivity, and impulsiveness.",
        "severity": "mild to moderate",
        "treatment": "stimulants (Ritalin, Adderall), behavior therapy, social skills training",
        "source": "CHADD"
    },
    {
        "condition": "Sepsis",
        "symptoms": ["confusion or disorientation", "shortness of breath", "high heart rate", "fever or shivering",
                     "extreme pain or discomfort", "clammy or sweaty skin"],
        "description": "Sepsis is the body’s extreme response to an infection. It is a life-threatening medical emergency.",
        "severity": "emergency",
        "treatment": "antibiotics, IV fluids, vasopressors, supportive care",
        "source": "CDC"
    },
    {
        "condition": "Hypoglycemia",
        "symptoms": ["shakiness", "dizziness", "sweating", "hunger", "fast heartbeat", "inability to concentrate",
                     "confusion"],
        "description": "Hypoglycemia is a condition in which your blood sugar (glucose) level is lower than normal.",
        "severity": "moderate to severe",
        "treatment": "consuming high-sugar foods or drinks, glucagon injection, treating underlying cause",
        "source": "American Diabetes Association"
    },
    {
        "condition": "Hyperglycemia",
        "symptoms": ["increased thirst", "frequent urination", "blurred vision", "fatigue", "headache"],
        "description": "Hyperglycemia is the technical term for high blood sugar (blood glucose).",
        "severity": "moderate to severe",
        "treatment": "insulin, exercise, dietary changes, increased fluid intake",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Ketoacidosis",
        "symptoms": ["excessive thirst", "frequent urination", "nausea and vomiting", "abdominal pain",
                     "weakness or fatigue", "shortness of breath", "fruity-scented breath"],
        "description": "Diabetic ketoacidosis (DKA) is a serious complication of diabetes that occurs when your body produces high levels of blood acids called ketones.",
        "severity": "emergency",
        "treatment": "fluid replacement, electrolyte replacement, insulin therapy",
        "source": "American Diabetes Association"
    },
    {
        "condition": "Osteoarthritis",
        "symptoms": ["pain", "stiffness", "tenderness", "loss of flexibility", "grating sensation", "bone spurs",
                     "swelling"],
        "description": "Osteoarthritis is the most common form of arthritis, affecting millions of people worldwide. It occurs when the protective cartilage that cushions the ends of your bones wears down over time.",
        "severity": "moderate",
        "treatment": "acetaminophen, NSAIDs, physical therapy, joint replacement surgery",
        "source": "Arthritis Foundation"
    },
    {
        "condition": "Infectious mononucleosis",
        "symptoms": ["fatigue", "sore throat", "fever", "swollen lymph nodes in neck and armpits", "swollen tonsils",
                     "headache", "skin rash", "soft swollen spleen"],
        "description": "Infectious mononucleosis (mono) is often called the kissing disease. The virus that causes mono (EBV) is transmitted through saliva.",
        "severity": "moderate",
        "treatment": "rest, fluids, over-the-counter pain/fever meds",
        "source": "CDC"
    },
    {
        "condition": "Scoliosis",
        "symptoms": ["uneven shoulders", "one shoulder blade that appears more prominent", "uneven waist",
                     "one hip higher than the other"],
        "description": "Scoliosis is a sideways curvature of the spine.",
        "severity": "mild to moderate",
        "treatment": "monitoring, back braces, spinal fusion surgery",
        "source": "National Scoliosis Foundation"
    },
    {
        "condition": "Tinnitus",
        "symptoms": ["ringing in the ears", "buzzing", "roaring", "clicking", "hissing"],
        "description": "Tinnitus is the perception of noise or ringing in the ears.",
        "severity": "mild to moderate",
        "treatment": "treating underlying causes, white noise machines, hearing aids",
        "source": "American Tinnitus Association"
    },
    {
        "condition": "Vertigo",
        "symptoms": ["spinning sensation", "tilting", "swaying", "unbalanced", "nausea", "vomiting"],
        "description": "Vertigo is a sensation of spinning. If you have these dizzy spells, you might feel like you're spinning or that the world around you is spinning.",
        "severity": "moderate",
        "treatment": "Epley maneuver, vestibular rehabilitation, canalith repositioning",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Eczema",
        "symptoms": ["dry skin", "itching", "red to brownish-gray patches", "small raised bumps",
                     "thickened cracked scaly skin"],
        "description": "Atopic dermatitis (eczema) is a condition that makes your skin red and itchy.",
        "severity": "mild to moderate",
        "treatment": "moisturizers, topical corticosteroids, calcineurin inhibitors",
        "source": "National Eczema Association"
    },
    {
        "condition": "Heat Stroke",
        "symptoms": ["high body temperature (104 F or higher)", "altered mental state or behavior",
                     "alteration in sweating", "nausea and vomiting", "flushed skin", "rapid breathing"],
        "description": "Heatstroke is a condition caused by your body overheating, usually as a result of prolonged exposure to or physical exertion in high temperatures. This most serious form of heat injury requires emergency treatment.",
        "severity": "emergency",
        "treatment": "immersion in cold water, evaporation cooling techniques, cooling blankets, medications to stop shivering",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Frostbite",
        "symptoms": ["cold skin and a prickling feeling", "numbness",
                     "skin that looks red white bluish-white or grayish-yellow", "hard or waxy-looking skin",
                     "clumsiness due to joint stiffness"],
        "description": "Frostbite is an injury caused by freezing of the skin and underlying tissues. First your skin becomes very cold and red, then numb, hard and pale.",
        "severity": "moderate to severe",
        "treatment": "rewarming of the area, oral pain medicine, protecting the injury, removal of damaged tissue (debridement)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Carbon Monoxide Poisoning",
        "symptoms": ["dull headache", "weakness", "dizziness", "nausea or vomiting", "shortness of breath", "confusion",
                     "blurred vision", "loss of consciousness"],
        "description": "Carbon monoxide poisoning occurs when carbon monoxide builds up in your bloodstream. When too much carbon monoxide is in the air, your body replaces the oxygen in your red blood cells with carbon monoxide.",
        "severity": "emergency",
        "treatment": "pure oxygen breathing, hyperbaric oxygen chamber",
        "source": "CDC"
    },
    {
        "condition": "Hypothermia",
        "symptoms": ["shivering", "slurred speech or mumbling", "slow shallow breathing", "weak pulse", "clumsiness",
                     "low energy", "confusion"],
        "description": "Hypothermia is a medical emergency that occurs when your body loses heat faster than it can produce heat, causing a dangerously low body temperature.",
        "severity": "emergency",
        "treatment": "passive rewarming (blankets), warm fluids, medicinal rewarming (warmed IV fluids)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Altitude Sickness",
        "symptoms": ["headache", "nausea and vomiting", "dizziness", "tiredness", "loss of appetite",
                     "shortness of breath"],
        "description": "Altitude sickness is a group of symptoms that can strike if you walk or climb to a higher elevation (altitude) too quickly.",
        "severity": "moderate to severe",
        "treatment": "descending to lower altitude, oxygen, acetazolamide, dexamethasone",
        "source": "CDC"
    },
    {
        "condition": "Decompression Sickness",
        "symptoms": ["joint pain", "dizziness", "headache", "difficulty thinking clearly", "extreme fatigue", "rash",
                     "weakness in arms or legs"],
        "description": "Also known as 'the bends,' this occurs when nitrogen bubbles form in the blood and tissues due to a rapid decrease in surrounding pressure (usually in divers).",
        "severity": "emergency",
        "treatment": "100% oxygen, hyperbaric oxygen therapy",
        "source": "Navy Medicine"
    },
    {
        "condition": "Carpal Tunnel Syndrome",
        "symptoms": ["tingling or numbness in the thumb and fingers", "weakness in the hand",
                     "pain radiating up the arm"],
        "description": "A condition that causes numbness, tingling, and other symptoms in the hand and arm. It's caused by a compressed nerve in the carpal tunnel, a narrow passage on the palm side of your wrist.",
        "severity": "moderate",
        "treatment": "wrist splinting, NSAIDs, corticosteroids, surgery (carpal tunnel release)",
        "source": "NIH - NINDS"
    },
    {
        "condition": "Mesothelioma",
        "symptoms": ["chest pain", "painful coughing", "shortness of breath",
                     "unusual lumps of tissue under the skin on chest", "unexplained weight loss"],
        "description": "A tumor of the tissue that lines the lungs, stomach, heart, and other organs. It is almost always caused by exposure to asbestos.",
        "severity": "severe",
        "treatment": "surgery, chemotherapy, radiation therapy, immunotherapy",
        "source": "NIH - NCI"
    },
    {
        "condition": "Black Lung Disease",
        "symptoms": ["shortness of breath", "chronic cough", "phlegm production"],
        "description": "Also known as coal workers' pneumoconiosis (CWP), it is caused by long-term exposure to coal dust. It is common in coal miners.",
        "severity": "severe",
        "treatment": "oxygen therapy, pulmonary rehabilitation, lung transplant",
        "source": "NIOSH"
    },
    {
        "condition": "Asbestosis",
        "symptoms": ["shortness of breath", "persistent dry cough", "loss of appetite with weight loss",
                     "fingertips and toes that appear wider/rounder (clubbing)"],
        "description": "A chronic lung disease caused by inhaling asbestos fibers. Prolonged exposure to these fibers can cause lung tissue scarring and shortness of breath.",
        "severity": "severe",
        "treatment": "oxygen therapy, pulmonary rehabilitation, avoidance of further exposure",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Legionnaires' Disease",
        "symptoms": ["headache", "muscle pain", "chills", "fever that may be 104 F or higher", "cough",
                     "shortness of breath"],
        "description": "A severe form of pneumonia — lung inflammation usually caused by infection. It's caused by a bacterium known as legionella, typically found in water systems.",
        "severity": "severe",
        "treatment": "antibiotics (fluoroquinolones, macrolides)",
        "source": "CDC"
    },
    {
        "condition": "Hantavirus Pulmonary Syndrome",
        "symptoms": ["fever and chills", "muscle aches", "headache", "vomiting or diarrhea", "shortness of breath",
                     "fluid in the lungs"],
        "description": "A severe, sometimes fatal, respiratory disease in humans caused by infection with hantaviruses, typically spread by rodents.",
        "severity": "emergency",
        "treatment": "supportive care, oxygen therapy, intubation (in severe cases)",
        "source": "CDC"
    },
    {
        "condition": "Fibrodysplasia Ossificans Progressiva (FOP)",
        "symptoms": ["malformed big toes at birth", "swelling in neck or back", "progressive loss of mobility",
                     "bone growth in muscles/ligaments"],
        "description": "An extremely rare genetic connective tissue disease where fibrous tissue (muscle, tendon, ligament) is irreversibly replaced by bone (ossified) when damaged.",
        "severity": "severe",
        "treatment": "corticosteroids for flare-ups, occupational therapy, preventative care",
        "source": "IFOPA / NIH"
    },
    {
        "condition": "Tay-Sachs Disease",
        "symptoms": ["loss of motor skills", "exaggerated reactions to loud noises", "seizures",
                     "vision and hearing loss", "cherry-red spot in the eye"],
        "description": "A rare, inherited disorder that destroys nerve cells in the brain and spinal cord. Typically appearing in infancy.",
        "severity": "severe",
        "treatment": "supportive care, seizure medications, physical therapy",
        "source": "NORD"
    },
    {
        "condition": "Huntington's Disease",
        "symptoms": ["involuntary jerking or writhing movements", "muscle problems (dystonia)",
                     "slow or unusual eye movements", "impaired gait", "difficulty swallowing"],
        "description": "An inherited disease that causes the progressive breakdown (degeneration) of nerve cells in the brain.",
        "severity": "severe",
        "treatment": "tetrabenazine, antipsychotic drugs, physical therapy",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Cystic Fibrosis",
        "symptoms": ["salty-tasting skin", "persistent coughing", "frequent lung infections", "wheezing",
                     "poor growth or weight gain"],
        "description": "An inherited life-threatening disorder that damages the lungs and digestive system. It affects the cells that produce mucus, sweat, and digestive juices.",
        "severity": "severe",
        "treatment": "CFTR modulators, airway clearance, inhaled meds, lung transplant",
        "source": "Cystic Fibrosis Foundation"
    },
    {
        "condition": "Ehlers-Danlos Syndrome",
        "symptoms": ["overly flexible joints", "stretchy skin", "fragile skin", "easy bruising", "chronic pain"],
        "description": "A group of inherited disorders that affect your connective tissues — primarily your skin, joints, and blood vessel walls.",
        "severity": "moderate to severe",
        "treatment": "physical therapy, bracing, surgery for joint repairs",
        "source": "The Ehlers-Danlos Society"
    },
    {
        "condition": "Marfan Syndrome",
        "symptoms": ["tall and slender build", "disproportionately long arms legs and fingers",
                     "breastbone that protrudes or dips", "high arched palate", "heart murmurs"],
        "description": "An inherited disorder that affects connective tissue. It most commonly affects the heart, eyes, blood vessels, and skeleton.",
        "severity": "moderate to severe",
        "treatment": "blood pressure meds, corrective lenses, surgery (aorta repair)",
        "source": "The Marfan Foundation"
    },
    {
        "condition": "Sickle Cell Anemia",
        "symptoms": ["episodes of pain (crises)", "swelling of hands and feet", "frequent infections", "delayed growth",
                     "vision problems"],
        "description": "An inherited group of disorders where red blood cells contort into a sickle shape. The cells die early, leaving a shortage of healthy red blood cells.",
        "severity": "severe",
        "treatment": "blood transfusions, hydroxyurea, bone marrow transplant",
        "source": "CDC"
    },
    {
        "condition": "Tourette Syndrome",
        "symptoms": ["eye blinking", "head jerking", "shoulder shrugging", "grunting", "coughing", "shouting",
                     "repeating words"],
        "description": "A nervous system disorder involving repetitive movements or unwanted sounds (tics) that can't be easily controlled.",
        "severity": "mild to moderate",
        "treatment": "behavioral therapy, dopamine blockers, ADHD/OCD meds",
        "source": "Tourette Association of America"
    },
    {
        "condition": "Narcolepsy",
        "symptoms": ["excessive daytime sleepiness", "sudden loss of muscle tone (cataplexy)", "sleep paralysis",
                     "hallucinations"],
        "description": "A chronic sleep disorder characterized by overwhelming daytime drowsiness and sudden attacks of sleep.",
        "severity": "moderate to severe",
        "treatment": "stimulants, SSRIs, SNRIs, sodium oxybate",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Restless Legs Syndrome",
        "symptoms": ["unpleasant crawling or creeping sensations in legs", "uncontrollable urge to move legs",
                     "symptoms worsen at night"],
        "description": "A condition that causes an uncontrollable urge to move your legs, usually because of an uncomfortable sensation. It typically happens in the evening or nighttime hours.",
        "severity": "mild to moderate",
        "treatment": "iron supplements, dopamine-increasing drugs, sleep hygiene",
        "source": "RLS Foundation"
    },
    {
        "condition": "Sleep Apnea",
        "symptoms": ["loud snoring", "episodes in which you stop breathing during sleep",
                     "gasping for air during sleep", "morning headache", "excessive daytime sleepiness"],
        "description": "A potentially serious sleep disorder in which breathing repeatedly stops and starts.",
        "severity": "moderate to severe",
        "treatment": "CPAP machine, oral appliances, weight loss, surgery",
        "source": "American Sleep Apnea Association"
    },
    {
        "condition": "Trichotillomania",
        "symptoms": ["repeatedly pulling out your hair", "increasing sense of tension before pulling",
                     "sense of pleasure or relief after pulling", "bare patches on scalp"],
        "description": "A mental disorder that involves irresistible urges to pull out hair from your scalp, eyebrows, or other areas of your body.",
        "severity": "moderate",
        "treatment": "habit reversal training, cognitive therapy, SSRIs",
        "source": "NAMI"
    },
    {
        "condition": "Body Dysmorphic Disorder",
        "symptoms": ["extreme preoccupation with a perceived flaw in appearance",
                     "strong belief that you have a defect", "frequent mirror checking", "avoiding social situations"],
        "description": "A mental health disorder in which you can't stop thinking about one or more perceived defects or flaws in your appearance.",
        "severity": "moderate to severe",
        "treatment": "cognitive behavioral therapy, SSRIs",
        "source": "Anxiety & Depression Association of America"
    },
    {
        "condition": "Hoarding Disorder",
        "symptoms": ["persistent inability to part with possessions", "cluttered living spaces",
                     "distress when trying to discard items"],
        "description": "A persistent difficulty discarding or parting with possessions because of a perceived need to save them.",
        "severity": "moderate",
        "treatment": "CBT, SSRIs",
        "source": "American Psychiatric Association"
    },
    {
        "condition": "Schizoaffective Disorder",
        "symptoms": ["hallucinations", "delusions", "disorganized thinking", "depressed mood", "manic periods"],
        "description": "A mental health disorder that is marked by a combination of schizophrenia symptoms, such as hallucinations or delusions, and mood disorder symptoms, such as depression or mania.",
        "severity": "severe",
        "treatment": "antipsychotics, mood stabilizers, antidepressants, psychotherapy",
        "source": "NAMI"
    },
    {
        "condition": "Social Anxiety Disorder",
        "symptoms": ["fear of situations in which you may be judged", "worrying about embarrassing yourself",
                     "intense fear of talking to strangers", "avoidance of being center of attention"],
        "description": "A chronic mental health condition in which social interactions cause irrational anxiety, fear, self-consciousness, and embarrassment.",
        "severity": "moderate",
        "treatment": "CBT, SSRIs, SNRIs, beta blockers",
        "source": "NIMH"
    },
    {
        "condition": "Borderline Personality Disorder",
        "symptoms": ["intense fear of abandonment", "pattern of unstable relationships",
                     "rapid changes in self-identity", "impulsive and risky behavior", "wide mood swings"],
        "description": "A mental health disorder that impacts the way you think and feel about yourself and others, causing problems functioning in everyday life.",
        "severity": "severe",
        "treatment": "dialectical behavior therapy (DBT), schema-focused therapy, antipsychotics/mood stabilizers",
        "source": "NAMI"
    },
    {
        "condition": "Dissociative Identity Disorder",
        "symptoms": ["existence of two or more distinct identities", "gaps in memory of everyday events",
                     "distress in social or work areas"],
        "description": "Formerly known as multiple personality disorder, this is a condition characterized by 'switching' to alternate identities.",
        "severity": "severe",
        "treatment": "psychotherapy, hypnotherapy",
        "source": "American Psychiatric Association"
    },
    {
        "condition": "Lyme Disease",
        "symptoms": ["bulls-eye rash", "fever", "chills", "fatigue", "body aches", "joint pain",
                     "neurological problems"],
        "description": "A tick-borne illness caused by the bacterium Borrelia burgdorferi. It is transmitted to humans through the bite of infected black-legged ticks.",
        "severity": "moderate",
        "treatment": "antibiotics (doxycycline, amoxicillin)",
        "source": "CDC"
    },
    {
        "condition": "Rocky Mountain Spotted Fever",
        "symptoms": ["fever", "headache", "rash (small red spots on wrists/ankles)", "nausea and vomiting",
                     "muscle pain", "lack of appetite"],
        "description": "A bacterial disease spread through the bite of an infected tick. If not treated early with the right antibiotic, it can be fatal.",
        "severity": "severe",
        "treatment": "doxycycline",
        "source": "CDC"
    },
    {
        "condition": "West Nile Virus",
        "symptoms": ["fever", "headache", "body aches", "vomiting", "diarrhea", "fatigue", "skin rash"],
        "description": "The leading cause of mosquito-borne disease in the continental United States. Most people infected do not feel sick.",
        "severity": "mild to severe",
        "treatment": "supportive care, OTC pain relievers, hospitalization for severe cases",
        "source": "CDC"
    },
    {
        "condition": "Zika Virus",
        "symptoms": ["fever", "rash", "joint pain", "conjunctivitis (red eyes)", "muscle pain", "headache"],
        "description": "A virus spread primarily by Aedes mosquitoes. Infection during pregnancy can cause birth defects like microcephaly.",
        "severity": "moderate",
        "treatment": "rest, fluids, acetaminophen",
        "source": "WHO"
    },
    {
        "condition": "Dengue Fever",
        "symptoms": ["high fever", "severe headache", "pain behind the eyes", "joint and muscle pain", "rash",
                     "mild bleeding"],
        "description": "A mosquito-borne viral disease that has spread rapidly in all regions of WHO in recent years. Also known as 'breakbone fever'.",
        "severity": "moderate to severe",
        "treatment": "fluids, pain relievers (avoid aspirin/ibuprofen), supportive care",
        "source": "WHO"
    },
    {
        "condition": "Cholera",
        "symptoms": ["profuse watery diarrhea", "vomiting", "rapid heart rate", "loss of skin elasticity",
                     "low blood pressure", "thirst", "muscle cramps"],
        "description": "An acute diarrheal infection caused by ingestion of food or water contaminated with the bacterium Vibrio cholerae.",
        "severity": "emergency",
        "treatment": "oral rehydration salts (ORS), IV fluids, antibiotics",
        "source": "WHO"
    },
    {
        "condition": "Brucellosis",
        "symptoms": ["fever", "sweats", "malaise", "anorexia", "headache", "pain in muscles joints and back",
                     "fatigue"],
        "description": "An infectious disease caused by bacteria. People can get the disease when they are in contact with infected animals or animal products contaminated with the bacteria.",
        "severity": "moderate",
        "treatment": "antibiotics (rifampin, doxycycline)",
        "source": "CDC"
    },
    {
        "condition": "Anthrax",
        "symptoms": ["small blister or swelling", "painless skin sore with black center", "fever and chills",
                     "chest discomfort", "shortness of breath", "nausea"],
        "description": "A serious infectious disease caused by gram-positive, rod-shaped bacteria known as Bacillus anthracis. It occurs naturally in soil and commonly affects domestic and wild animals.",
        "severity": "severe",
        "treatment": "antibiotics (ciprofloxacin, doxycycline), antitoxin",
        "source": "CDC"
    },
    {
        "condition": "Rabies",
        "symptoms": ["fever", "headache", "nausea", "vomiting", "agitation", "anxiety", "confusion", "hyperactivity",
                     "difficulty swallowing"],
        "description": "A deadly virus spread to people from the saliva of infected animals. Once symptoms appear, it is nearly always fatal.",
        "severity": "emergency",
        "treatment": "rabies vaccine (post-exposure prophylaxis), rabies immune globulin",
        "source": "WHO"
    },
    {
        "condition": "Tetanus",
        "symptoms": ["jaw cramping", "sudden involuntary muscle spasms", "painful muscle stiffness all over the body",
                     "trouble swallowing", "seizures"],
        "description": "A serious disease caused by a bacterial toxin that affects your nervous system, leading to painful muscle contractions, particularly of your jaw and neck muscles. Also known as 'lockjaw'.",
        "severity": "emergency",
        "treatment": "antitoxin, wound care, supportive care, vaccination",
        "source": "CDC"
    },
    {
        "condition": "Ebola Virus Disease",
        "symptoms": ["fever", "severe headache", "muscle pain", "weakness", "fatigue", "diarrhea", "vomiting",
                     "unexplained hemorrhage"],
        "description": "A rare and deadly disease in people and nonhuman primates. The viruses that cause EVD are located mainly in sub-Saharan Africa.",
        "severity": "emergency",
        "treatment": "supportive care (fluids, electrolytes), monoclonal antibodies",
        "source": "WHO"
    },
    {
        "condition": "Plague",
        "symptoms": ["sudden onset of fever", "headache", "chills", "weakness",
                     "one or more swollen tender and painful lymph nodes (buboes)"],
        "description": "An infectious disease caused by the bacterium Yersinia pestis, usually found in small mammals and their fleas.",
        "severity": "emergency",
        "treatment": "antibiotics (gentamicin, fluoroquinolones)",
        "source": "CDC"
    },
    {
        "condition": "Cushing's Syndrome",
        "symptoms": ["weight gain and fatty tissue deposits", "pink or purple stretch marks", "thinning fragile skin",
                     "slow healing of cuts", "acne"],
        "description": "Occurs when your body is exposed to high levels of the hormone cortisol for a long time.",
        "severity": "moderate to severe",
        "treatment": "reducing steroid use, surgery (tumor removal), radiation, medication",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Addison's Disease",
        "symptoms": ["extreme fatigue", "weight loss and decreased appetite", "darkening of skin (hyperpigmentation)",
                     "low blood pressure", "salt craving"],
        "description": "Also called adrenal insufficiency, this is an uncommon disorder that occurs when your body doesn't produce enough of certain hormones.",
        "severity": "severe",
        "treatment": "oral corticosteroids (hydrocortisone, prednisone), hormone replacement",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Graves' Disease",
        "symptoms": ["anxiety and irritability", "fine tremor of hands or fingers", "heat sensitivity", "weight loss",
                     "bulging eyes (Graves' ophthalmopathy)"],
        "description": "An immune system disorder that results in the overproduction of thyroid hormones (hyperthyroidism).",
        "severity": "moderate",
        "treatment": "radioactive iodine therapy, anti-thyroid meds, beta blockers, surgery",
        "source": "American Thyroid Association"
    },
    {
        "condition": "Hashimoto's Thyroiditis",
        "symptoms": ["fatigue and sluggishness", "increased sensitivity to cold", "constipation", "pale dry skin",
                     "puffy face", "brittle nails"],
        "description": "A condition in which your immune system attacks your thyroid, a small gland at the base of your neck below your Adam's apple.",
        "severity": "moderate",
        "treatment": "levothyroxine (synthetic thyroid hormone)",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Acromegaly",
        "symptoms": ["enlarged hands and feet", "coarsened facial features", "excessive sweating",
                     "small outgrowths of skin tissue (skin tags)", "fatigue and muscle weakness"],
        "description": "A hormonal disorder that develops when your pituitary gland produces too much growth hormone during adulthood.",
        "severity": "moderate to severe",
        "treatment": "surgery (pituitary tumor removal), medications (somatostatin analogs), radiation",
        "source": "NIH - NIDDK"
    },
    {
        "condition": "Pheochromocytoma",
        "symptoms": ["high blood pressure", "headache", "heavy sweating", "rapid heartbeat", "tremors",
                     "paleness in the face"],
        "description": "A rare, usually noncancerous (benign) tumor that develops in an adrenal gland.",
        "severity": "moderate to severe",
        "treatment": "surgery (adrenalectomy), alpha blockers, beta blockers",
        "source": "Mayo Clinic"
    },
    {
        "condition": "Gigantism",
        "symptoms": ["very large hands and feet", "thick toes and fingers", "a prominent jaw and forehead",
                     "coarse facial features"],
        "description": "A rare condition that causes abnormal growth in children. This change is most notable in terms of height, but girth is affected as well. It occurs when the pituitary gland makes too much growth hormone.",
        "severity": "moderate to severe",
        "treatment": "surgery, medication, radiation therapy",
        "source": "NORD"
    },
    {
        "condition": "Diabetes Insipidus",
        "symptoms": ["extreme thirst", "producing large amounts of pale urine",
                     "frequent need to get up to urinate during the night", "preference for cold drinks"],
        "description": "An uncommon disorder that causes an imbalance of fluids in the body. This imbalance makes you very thirsty even if you've had something to drink. It also leads you to produce large amounts of urine.",
        "severity": "moderate",
        "treatment": "desmopressin, low-salt diet, drinking enough water",
        "source": "NIH - NIDDK"
    }

]

# symptoms_registry.py
# this is al of the possible symptons that the dataset includes - we can use this for validation and to ensure we have a comprehensive list of symptoms for search and retrieval purposes

ALL_UNIQUE_SYMPTOMS = [
    # General & Constitutional
    "fever", "low-grade fever", "high fever", "chills", "night sweats",
    "fatigue", "weakness", "lethargy", "unexplained weight loss", "weight gain",
    "loss of appetite", "malaise", "shivering", "excessive sweating",

    # Neurological & Pain
    "headache", "severe headache", "migraine", "thunderclap headache", "throbbing pain",
    "dizziness", "lightheadedness", "fainting", "confusion", "disorientation",
    "seizures", "tremors", "numbness", "tingling", "pins and needles",
    "muscle weakness", "lack of coordination", "unsteady gait", "slurred speech",
    "memory loss", "difficulty concentrating", "hallucinations", "aura",

    # Respiratory
    "runny nose", "stuffy nose", "sneezing", "cough", "dry cough", "persistent cough",
    "shortness of breath", "difficulty breathing", "wheezing", "chest tightness",
    "sore throat", "postnasal drip", "hoarseness", "voice loss",

    # Cardiovascular
    "chest pain", "heart palpitations", "rapid heartbeat", "irregular heartbeats",
    "high blood pressure", "low blood pressure", "swelling in feet or ankles",
    "cold extremities", "cyanosis (bluish lips/nails)",

    # Gastrointestinal
    "nausea", "vomiting", "diarrhea", "bloody stools", "black stools",
    "stomach cramps", "abdominal pain", "bloating", "gas", "indigestion",
    "heartburn", "acid reflux", "constipation", "jaundice (yellowing of skin/eyes)",
    "pale stools", "dark urine",

    # Urinary & Reproductive
    "painful urination", "frequent urination", "urgency to urinate", "cloudy urine",
    "blood in urine", "pelvic pain", "lower back pain", "vaginal discharge",
    "penile discharge", "pain during intercourse", "irregular periods",

    # Musculoskeletal
    "body aches", "muscle pain", "joint pain", "stiff neck", "swollen joints",
    "limited range of motion", "bone pain", "back pain", "muscle spasms",

    # Dermatological (Skin)
    "rash", "itchy skin", "dry skin", "blisters", "redness", "hives",
    "sores that don't heal", "honey-colored crusts", "peeling skin",
    "stretchy skin", "easy bruising",

    # Sensory (Eyes/Ears/Nose)
    "itchy eyes", "watery eyes", "blurred vision", "double vision", "vision loss",
    "sensitivity to light", "sensitivity to sound", "ringing in ears (tinnitus)",
    "hearing loss", "earache", "gritty feeling in eye", "loss of smell or taste"
]


# Total count for reference: ~130+ unique identifiers


def test_medical_retrieval(query, dataset, top_k=3):
    # Create descriptions for the dataset (Condition + Symptoms)
    descriptions = [f"{d['condition']}: {d['symptoms']}" for d in dataset]

    # Generate embeddings
    query_embedding = model.encode(query, convert_to_tensor=True)
    dataset_embeddings = model.encode(descriptions, convert_to_tensor=True)

    # Compute cosine similarity
    cosine_scores = util.cos_sim(query_embedding, dataset_embeddings)[0]

    # Get top results
    top_results = torch.topk(cosine_scores, k=min(top_k, len(dataset)))

    print(f"Query: {query}\n")
    print(f"{'Condition':<20} | {'Similarity Score'}")
    print("-" * 40)

    for score, idx in zip(top_results[0], top_results[1]):
        condition = dataset[idx]['condition']
        print(f"{condition:<20} | {score:.4f}")


# Execute Test
if __name__ == "__main__":
    test_input = "chills,fatigue, lose of appetite"
    test_medical_retrieval(test_input, DISEASE_DATASET)