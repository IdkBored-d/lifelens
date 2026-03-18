import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModel

class DisEmbedModel:
    def __init__(self, model_id: str):
        self.tokenizer = AutoTokenizer.from_pretrained(model_id)
        self.model = AutoModel.from_pretrained(model_id)

    def encode(self, texts):
        # Handle both single strings and lists of strings
        if isinstance(texts, str):
            texts = [texts]

        encoded_input = self.tokenizer(texts, padding=True, truncation=True, return_tensors='pt')
        
        with torch.no_grad():
            model_output = self.model(**encoded_input)

        # Mean Pooling
        token_embeddings = model_output[0]
        input_mask_expanded = encoded_input['attention_mask'].unsqueeze(-1).expand(token_embeddings.size()).float()
        sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
        sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
        mean_pooled = sum_embeddings / sum_mask

        # L2 Normalization
        normalized_embeddings = F.normalize(mean_pooled, p=2, dim=1)
        
        # Return as a standard Python list for Weaviate ingestion
        return normalized_embeddings.tolist()