import asyncio
from services.rag_service import get_rag_service
from models.schemas import RAGQuery

async def search_symptoms():
    print("Initializing RAG Service and loading DisEmbed model...")
    rag = get_rag_service()

    # 1. Simulate a user entering their symptoms
    user_input = "Chronic cough with blood-streaked sputum, severe night sweats, and weight loss."
    print(f"\nUser Query: '{user_input}'")
    print("-" * 50)

    # 2. Construct the query object based on your schema
    query = RAGQuery(
        query_text=user_input,
        max_results=3,       # Retrieve the top 3 most likely conditions
        min_certainty=0.10   # The minimum similarity score to be considered a match
    )

    print("Searching vector database...\n")
    
    # 3. Call the engine
    results = await rag.search_similar_conditions(query)

    # 4. Display the results clearly
    if not results:
        print("No matching conditions found above the certainty threshold.")
    else:
        print(f"Found {len(results)} potential matches:\n")
        for i, result in enumerate(results, 1):
            print(f"[{i}] {result.condition}")
            print(f"    Confidence: {result.relevance_score:.4f}")
            print(f"    Severity:   {result.metadata.get('severity', 'N/A')}")
            print(f"    Treatment:  {result.metadata.get('treatment', 'N/A')}")
            print("")

    # Clean up the connection
    rag.close()

if __name__ == "__main__":
    asyncio.run(search_symptoms())