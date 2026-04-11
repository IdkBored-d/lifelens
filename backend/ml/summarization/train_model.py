import argparse
import os
from pathlib import Path

from datasets import load_dataset
from transformers import T5Tokenizer, T5ForConditionalGeneration, Trainer, TrainingArguments
from transformers.trainer_utils import get_last_checkpoint

from artifact_paths import default_artifact_root, training_paths


def preprocess(example, tokenizer):
    input_text = str(example["input"])
    target_text = example["target"]

    inputs = tokenizer(input_text, padding="max_length", truncation=True, max_length=128)
    labels = tokenizer(target_text, padding="max_length", truncation=True, max_length=64)

    inputs["labels"] = labels["input_ids"]
    return inputs


def main():
    parser = argparse.ArgumentParser(description="Train LifeLens summarization model")
    parser.add_argument("--dataset", default="summarization_dataset.json")
    parser.add_argument("--artifact-root", default=None)
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    dataset_path = (base / args.dataset).resolve() if not Path(args.dataset).is_absolute() else Path(args.dataset)

    artifact_root = Path(args.artifact_root).expanduser().resolve() if args.artifact_root else default_artifact_root()
    paths = training_paths(artifact_root)
    paths["results_dir"].mkdir(parents=True, exist_ok=True)
    paths["model_dir"].mkdir(parents=True, exist_ok=True)

    dataset = load_dataset("json", data_files=str(dataset_path))

    tokenizer = T5Tokenizer.from_pretrained("t5-small")
    model = T5ForConditionalGeneration.from_pretrained("t5-small")

    dataset = dataset.map(lambda ex: preprocess(ex, tokenizer))

    training_args = TrainingArguments(
        output_dir=str(paths["results_dir"]),
        per_device_train_batch_size=int(os.getenv("LL_TRAIN_BATCH_SIZE", "4")),
        num_train_epochs=float(os.getenv("LL_TRAIN_EPOCHS", "3")),
        save_strategy="steps",
        save_steps=int(os.getenv("LL_SAVE_STEPS", "25")),
        save_total_limit=3,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
    )

    last_checkpoint = None
    if os.path.isdir(training_args.output_dir):
        last_checkpoint = get_last_checkpoint(training_args.output_dir)

    trainer.train(resume_from_checkpoint=last_checkpoint)

    model.save_pretrained(str(paths["model_dir"]))
    tokenizer.save_pretrained(str(paths["model_dir"]))

    print(f"Training artifacts written to: {paths['root']}")


if __name__ == "__main__":
    main()