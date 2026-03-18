import asyncio
from services.rag_service import get_rag_service
from scripts.load_sample_knowledge import SAMPLE_KNOWLEDGE
from models.schemas import MedicalKnowledgeDoc
from datetime import datetime


async def load_knowledge():
    rag = get_rag_service()

    docs = [
        MedicalKnowledgeDoc(
            doc_id="",
            condition=data["condition"],
            symptoms=data["symptoms"],
            description=data["description"],
            severity=data["severity"],
            treatment=data["treatment"],
            when_to_seek_care=data["when_to_seek_care"],
            risk_factors=data.get("risk_factors"),
            complications=data.get("complications"),
            source=data["source"],
            last_updated=datetime.utcnow(),
        )
        for data in SAMPLE_KNOWLEDGE
    ]

    result = await rag.bulk_add_knowledge(docs)
    print(f"✅ Loaded {result['successful']} documents using DisEmbed-v1")

    rag.close()


if __name__ == "__main__":
    asyncio.run(load_knowledge())