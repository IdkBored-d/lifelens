import argparse
import os
from pathlib import Path

from datasets import Dataset, load_dataset
from transformers import T5Tokenizer, T5ForConditionalGeneration, Trainer, TrainingArguments
from transformers.trainer_utils import get_last_checkpoint

try:
    from .artifact_paths import default_artifact_root, training_paths
except ImportError:
    from artifact_paths import default_artifact_root, training_paths


def preprocess(example, tokenizer):
    input_text = str(example["input"])
    if os.getenv("LL_USE_INSTRUCTION_TAGS", "0") == "1":
        task_tag = _instruction_tag(example)
        input_text = f"{task_tag} {input_text}"
    target_text = example["target"]

    inputs = tokenizer(input_text, padding="max_length", truncation=True, max_length=128)
    labels = tokenizer(target_text, padding="max_length", truncation=True, max_length=64)

    inputs["labels"] = labels["input_ids"]
    return inputs


def _bucket_from_target(target_text: str) -> str:
    t = str(target_text).lower()
    if "high" in t and "risk" in t:
        return "high_risk"
    if "low sleep" in t or "sleep deficit" in t:
        return "low_sleep"
    if "low mood" in t or ("mood" in t and "low" in t):
        return "low_mood"
    if "improv" in t or "recover" in t:
        return "improving"
    if "declin" in t or "worsen" in t:
        return "declining"
    if "stable" in t or "steady" in t:
        return "stable"
    return "other"


def _instruction_tag(example: dict) -> str:
    bucket = str(example.get("bucket", "")).strip().lower()
    if not bucket:
        bucket = _bucket_from_target(example.get("target", ""))

    mapping = {
        "declining": "[TASK_DECLINING]",
        "stable": "[TASK_STABLE]",
        "improving": "[TASK_IMPROVING]",
        "low_sleep": "[TASK_LOW_SLEEP]",
        "low_mood": "[TASK_LOW_MOOD]",
        "high_risk": "[TASK_HIGH_RISK]",
    }
    return mapping.get(bucket, "[TASK_SUMMARIZE]")


def _oversample_gold_rows(rows: list[dict], gold_factor: int, gold_source_token: str) -> list[dict]:
    if gold_factor <= 1:
        return rows

    expanded = []
    token = gold_source_token.strip().lower()
    for row in rows:
        source = str(row.get("source", "")).strip().lower()
        repeats = gold_factor if source == token else 1
        for _ in range(repeats):
            expanded.append(row)
    return expanded


def main():
    parser = argparse.ArgumentParser(description="Train LifeLens summarization model")
    parser.add_argument("--dataset", default="summarization_dataset.json")
    parser.add_argument("--artifact-root", default=None)
    parser.add_argument("--gold-source-token", default="gold_seed")
    parser.add_argument(
        "--resume-from-last-checkpoint",
        action="store_true",
        help="Resume from latest checkpoint in results dir. Disabled by default for clean retraining.",
    )
    args = parser.parse_args()

    base = Path(__file__).resolve().parent
    if Path(args.dataset).is_absolute():
        dataset_path = Path(args.dataset)
    elif (base / args.dataset).exists():
        dataset_path = (base / args.dataset).resolve()
    else:
        dataset_path = Path(args.dataset).resolve()

    artifact_root = Path(args.artifact_root).expanduser().resolve() if args.artifact_root else default_artifact_root()
    paths = training_paths(artifact_root)
    paths["results_dir"].mkdir(parents=True, exist_ok=True)
    paths["model_dir"].mkdir(parents=True, exist_ok=True)

    dataset = load_dataset("json", data_files=str(dataset_path))

    gold_factor = int(os.getenv("LL_GOLD_OVERSAMPLE_FACTOR", "5"))
    train_rows = dataset["train"].to_list()
    train_rows = _oversample_gold_rows(
        rows=train_rows,
        gold_factor=gold_factor,
        gold_source_token=args.gold_source_token,
    )
    dataset["train"] = Dataset.from_list(train_rows)

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

    should_resume = args.resume_from_last_checkpoint or os.getenv("LL_RESUME_FROM_CHECKPOINT", "0") == "1"
    last_checkpoint = None
    if should_resume and os.path.isdir(training_args.output_dir):
        last_checkpoint = get_last_checkpoint(training_args.output_dir)

    trainer.train(resume_from_checkpoint=last_checkpoint)

    model.save_pretrained(str(paths["model_dir"]))
    tokenizer.save_pretrained(str(paths["model_dir"]))

    print(f"Training artifacts written to: {paths['root']}")


if __name__ == "__main__":
    main()