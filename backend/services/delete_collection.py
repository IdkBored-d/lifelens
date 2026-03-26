from services.rag_service import get_rag_service

def delete_collection():
    rag = get_rag_service()

    try:
        rag.client.collections.delete("MedicalKnowledge")
        print("✅ Successfully deleted MedicalKnowledge collection")
    except Exception as e:
        print(f"❌ Failed to delete collection: {e}")
    finally:
        rag.close()

if __name__ == "__main__":
    delete_collection()
