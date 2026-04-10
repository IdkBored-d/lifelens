from transformers import T5Tokenizer, T5ForConditionalGeneration

tokenizer = T5Tokenizer.from_pretrained("./summarization_model")
model = T5ForConditionalGeneration.from_pretrained("./summarization_model")

input_text = "sleep decreasing mood low risk high"

inputs = tokenizer(input_text, return_tensors="pt")
outputs = model.generate(**inputs, max_length=50)

print(tokenizer.decode(outputs[0], skip_special_tokens=True))