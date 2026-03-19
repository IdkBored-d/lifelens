import torch
# Assuming you placed the file in a 'utils' folder. 
# If it's in the main folder, just use: from disembed_utils import DisEmbedModel
from utils.disembed_utils import DisEmbedModel

def run_parity_test():
    print("Loading custom DisEmbedModel...")
    # Initialize the class we just built
    model = DisEmbedModel("SalmanFaroz/DisEmbed-v1")
    
    # Define our test data
    query = "Chronic cough with blood-streaked sputum, severe night sweats, and weight loss."
    diseases = ['Asthma', 'Tuberculosis', 'Bronchitis', 'Pneumonia']
    all_texts = [query] + diseases
    
    print("Generating embeddings...")
    # This calls our custom mean-pooling and L2 normalization logic
    embeddings_list = model.encode(all_texts)
    
    # Convert the Python list back to a PyTorch tensor for the math test
    embeddings = torch.tensor(embeddings_list)
    
    # Separate the query from the diseases
    query_embedding = embeddings[0:1]
    disease_embeddings = embeddings[1:]
    
    # Calculate Cosine Similarity
    scores = torch.mm(query_embedding, disease_embeddings.t())
    
    # Find the highest score
    best_match_idx = torch.argmax(scores).item()
    confidence = scores[0][best_match_idx].item()
    
    print(f"\n--- Test Results ---")
    print(f"Query: {query}")
    print(f"Prediction: {diseases[best_match_idx]}")
    print(f"Confidence: {confidence:.4f}")

if __name__ == "__main__":
    run_parity_test()