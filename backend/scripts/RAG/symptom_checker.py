"""
symptom_checker.py
------------------
Natural language symptom extraction + disease matching using:
  - SentenceTransformer (DisEmbed-v1) for semantic similarity
  - Fuzzy matching (rapidfuzz) for typo-tolerant symptom extraction
  - Your DISEASE_DATASET and ALL_UNIQUE_SYMPTOMS from load_sample_knowledge.py

Usage:
    python symptom_checker.py

Requirements:
    pip install sentence-transformers torch rapidfuzz
"""

import re
import torch
from rapidfuzz import process, fuzz
from sentence_transformers import SentenceTransformer, util

# ── Import your data ──────────────────────────────────────────────────────────
from backend.scripts.RAG.disease_symptom_dataset import DISEASE_DATASET, ALL_UNIQUE_SYMPTOMS

# ── Config ────────────────────────────────────────────────────────────────────
FUZZY_THRESHOLD = 70        # Min score (0-100) to accept a symptom match
TOP_K_DISEASES  = 2         # How many candidate conditions to return
MODEL_NAME      = "SalmanFaroz/DisEmbed-v1"

# ── Load model once at startup ────────────────────────────────────────────────
print("Loading model (first run may take a moment)...")
model = SentenceTransformer(MODEL_NAME)
print("Model ready.\n")


# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 – Extract symptoms from free-text using fuzzy matching
# ─────────────────────────────────────────────────────────────────────────────

def extract_symptoms_from_text(user_text: str) -> list[str]:
    """
    Scan the user's sentence and fuzzy-match fragments against ALL_UNIQUE_SYMPTOMS.
    Returns a deduplicated list of matched symptom strings.
    """
    text_lower = user_text.lower()

    # Build a sliding window of 1–5 word n-grams from the input
    tokens   = re.findall(r"[a-z]+(?:\s[a-z]+){0,4}", text_lower)
    # Also try whole-sentence chunks split by common delimiters
    chunks   = re.split(r"[,;.!?]|\band\b|\balso\b|\bwith\b|\bplus\b", text_lower)
    chunks   = [c.strip() for c in chunks if c.strip()]

    candidates = list(set(tokens + chunks))

    matched = {}
    for candidate in candidates:
        result = process.extractOne(
            candidate,
            ALL_UNIQUE_SYMPTOMS,
            scorer=fuzz.partial_ratio,
            score_cutoff=FUZZY_THRESHOLD
        )
        if result:
            symptom, score, _ = result
            # Keep the highest-scoring match per symptom
            if symptom not in matched or matched[symptom] < score:
                matched[symptom] = score

    return list(matched.keys())


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 – Match extracted symptoms → diseases via semantic embeddings
# ─────────────────────────────────────────────────────────────────────────────

def match_diseases(symptoms: list[str], top_k: int = TOP_K_DISEASES) -> list[dict]:
    """
    Encode the symptom list and compare against all disease descriptions.
    Returns the top_k disease entries with their similarity scores.
    """
    if not symptoms:
        return []

    query = ", ".join(symptoms)

    descriptions = [
        f"{d['condition']}: {', '.join(d['symptoms'])}"
        for d in DISEASE_DATASET
    ]

    query_emb   = model.encode(query, convert_to_tensor=True)
    dataset_emb = model.encode(descriptions, convert_to_tensor=True)

    scores      = util.cos_sim(query_emb, dataset_emb)[0]
    top_results = torch.topk(scores, k=min(top_k, len(DISEASE_DATASET)))

    results = []
    for score, idx in zip(top_results[0], top_results[1]):
        entry = DISEASE_DATASET[int(idx)].copy()
        entry["_score"] = float(score)
        results.append(entry)

    return results


# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 – Format the response
# ─────────────────────────────────────────────────────────────────────────────

def format_response(user_text: str, symptoms: list[str], matches: list[dict]) -> str:
    """Build the human-readable clinical-style response."""

    if not symptoms:
        return (
            "⚠️  I wasn't able to identify any recognisable symptoms in your description.\n"
            "Please try rephrasing or listing your symptoms separated by commas.\n\n"
            "─────────────────────────────────────────────────────\n"
            "Medical Disclaimer: This software is for informational and technical\n"
            "testing only. Symptom matching via AI is not a diagnosis.\n"
        )

    if not matches:
        return (
            f"Symptoms detected: {', '.join(symptoms)}\n\n"
            "⚠️  No matching conditions found in the dataset.\n\n"
            "─────────────────────────────────────────────────────\n"
            "Medical Disclaimer: This software is for informational and technical\n"
            "testing only. Symptom matching via AI is not a diagnosis.\n"
        )

    primary   = matches[0]
    secondary = matches[1] if len(matches) > 1 else None

    confidence_label = (
        "high"   if primary["_score"] >= 0.75 else
        "moderate" if primary["_score"] >= 0.55 else
        "low"
    )

    lines = [
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "🩺  SYMPTOM ANALYSIS RESULT",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"\n📝  Your description:\n    \"{user_text.strip()}\"",
        f"\n✅  Symptoms identified:\n    {', '.join(symptoms)}",
        "",
        "─────────────────────────────────────────────────────",
        f"Based on your described symptoms there is a {confidence_label} chance",
        f"that you are experiencing: {primary['condition'].upper()}",
        "",
        f"   About:     {primary['description']}",
        f"   Severity:  {primary['severity'].capitalize()}",
        f"   Treatment: {primary['treatment']}",
        f"   Source:    {primary['source']}",
    ]

    if secondary:
        lines += [
            "",
            "─────────────────────────────────────────────────────",
            f"It could also be: {secondary['condition']}",
            f"   Severity:  {secondary['severity'].capitalize()}",
            f"   Treatment: {secondary['treatment']}",
            f"   Source:    {secondary['source']}",
        ]

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "⚠️  Medical Disclaimer: This software logic is for informational",
        "   and technical testing only. Symptom matching via AI is not a",
        "   diagnosis. Always consult a qualified healthcare professional.",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ]

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 – Main pipeline
# ─────────────────────────────────────────────────────────────────────────────

def analyse(user_text: str) -> str:
    """End-to-end: text → symptoms → diseases → formatted response."""
    symptoms = extract_symptoms_from_text(user_text)
    matches  = match_diseases(symptoms)
    return format_response(user_text, symptoms, matches)


# ─────────────────────────────────────────────────────────────────────────────
# Entry point – interactive or single-shot
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # ── Test cases (comment out to use interactive mode) ─────────────────────
    test_inputs = [
        # Typo test
        "i have a bad hedache and my stomoach hurts",
    ]

    for sentence in test_inputs:
        print(analyse(sentence))
        print()

    # ── Interactive mode ──────────────────────────────────────────────────────
    # Uncomment the block below to run interactively:
    #
    # while True:
    #     user_input = input("\nDescribe your symptoms (or 'quit' to exit):\n> ").strip()
    #     if user_input.lower() in ("quit", "exit", "q"):
    #         break
    #     if user_input:
    #         print(analyse(user_input))