import os

from datasets import load_dataset
from transformers import T5Tokenizer, T5ForConditionalGeneration, Trainer, TrainingArguments
from transformers.trainer_utils import get_last_checkpoint

# Load dataset
dataset = load_dataset('json', data_files='summarization_dataset.json')

# Load model + tokenizer
tokenizer = T5Tokenizer.from_pretrained("t5-small")
model = T5ForConditionalGeneration.from_pretrained("t5-small")

# Convert your data into model format
def preprocess(example):
    input_text = str(example["input"])
    target_text = example["target"]

    inputs = tokenizer(input_text, padding="max_length", truncation=True, max_length=128)
    labels = tokenizer(target_text, padding="max_length", truncation=True, max_length=64)

    inputs["labels"] = labels["input_ids"]
    return inputs

dataset = dataset.map(preprocess)

# Training setup
training_args = TrainingArguments(
    output_dir="./results",
    per_device_train_batch_size=int(os.getenv("LL_TRAIN_BATCH_SIZE", "4")),
    num_train_epochs=float(os.getenv("LL_TRAIN_EPOCHS", "3")),
    save_strategy="steps",
    save_steps=int(os.getenv("LL_SAVE_STEPS", "25")),
    save_total_limit=3,
)

# Trainer
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset["train"],
)

# Train
last_checkpoint = None
if os.path.isdir(training_args.output_dir):
    last_checkpoint = get_last_checkpoint(training_args.output_dir)

trainer.train(resume_from_checkpoint=last_checkpoint)

# Save model
model.save_pretrained("./summarization_model")
tokenizer.save_pretrained("./summarization_model")