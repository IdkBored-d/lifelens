"""Test RAG service"""
import asyncio
from services.rag_service import get_rag_service
from models.schemas import RAGQuery


async def test():
    rag = get_rag_service()
    
    count = await rag.get_document_count()
    print(f"Documents: {count}")
    
    results = await rag.search_similar_conditions(
        RAGQuery(query_text="fever", max_results=3)
    )
    
    for r in results:
        print(f"- {r.condition}")
    
    rag.close()


if __name__ == "__main__":
    asyncio.run(test())