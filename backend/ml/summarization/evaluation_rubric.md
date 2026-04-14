# LifeLens Evaluation Rubric

This rubric is for labeling evaluation rows used to validate trend and risk scores. It is intentionally conservative: when evidence conflicts, prefer the label backed by later outcomes and explicit symptom burden over the label suggested by a single positive signal like exercise.

## 1. Trend Rubric

Use this for rows where `dataset_type = trend`.

### Input Evidence Order
1. Outcome-window change in the same signal type.
2. Symptom burden change.
3. Mood change.
4. Sleep change.
5. Activity change.

### Label Rules
- `improving`: recent window is meaningfully better than past window.
  - Typical case: `actual_delta > 0` and `actual_rate > 0` beyond the dataset threshold.
  - Symptoms, if present, are flat or decreasing.
- `stable`: change is small or noisy.
  - Typical case: `abs(actual_delta)` is within threshold and no clear worsening symptom pattern exists.
- `declining`: recent window is meaningfully worse than past window.
  - Typical case: `actual_delta < 0` and `actual_rate < 0` beyond the dataset threshold.
  - Also use `declining` if symptoms worsen even when one channel, such as exercise, improves.

### Trend Edge Cases
- If exercise improves but symptoms, mood, or sleep worsen, label the overall trend `declining` unless the outcome window clearly shows recovery.
- If the signal type is `activity`, exercise improvement can be labeled `improving` even when overall health is not improving.
- If data are sparse or contradictory, choose `stable` and set `annotation_confidence < 0.7`.

### Trend Acceptance Criteria
- Direction accuracy should beat the majority class baseline.
- Macro F1 should be reported across all three labels.
- Confusion should be low between `stable` and the two directional labels.

## 2. Risk Rubric

Use this for rows where `dataset_type = risk`.

### Input Evidence Order
1. Later outcome severity.
2. Symptom burden and symptom slope.
3. Sleep and mood burden.
4. Activity/inactivity burden.
5. Variability and interaction effects.

### Label Rules
- `low`:
  - No meaningful escalation in the outcome window.
  - Only weak or isolated negative signals.
  - Examples: good sleep and mood, low symptom burden, no meaningful downward trend.
- `medium`:
  - Some deterioration or a moderate cluster of risk signals.
  - Examples: low sleep plus moderate symptoms, or mild decline across two channels.
- `high`:
  - Clear multi-signal deterioration or a major escalation outcome.
  - Examples: low sleep, low mood, rising symptoms, and clear downward trend together.

### Risk Override Rules
- A single positive signal, such as more exercise, should not override a cluster of worsening symptoms, sleep, or mood.
- If symptom burden is rising and sleep/mood are falling, risk should usually be at least `medium` even if activity is stable or improving.
- Use `high` when the downstream outcome shows escalation, clinician follow-up, urgent support, or severe worsening.

### Risk Acceptance Criteria
- Higher predicted scores should align with higher downstream severity.
- Report AUC or PR-AUC for separation, plus Brier score or calibration error for score quality.
- Check monotonicity: low sleep, low mood, higher symptoms, and inactivity should not reduce risk.

## 3. Recommended Review Workflow

1. Annotate the row using the outcome window only.
2. Record `label` and `annotation_confidence`.
3. Review disagreements between `predicted_risk_score` and `label`.
4. Track false positives and false negatives by bucket.
5. Re-run the eval set after any policy change.

## 4. Suggested Threshold Defaults

- Trend threshold: use a small absolute delta threshold first, then tune per signal.
- Risk thresholds:
  - `low`: below 35
  - `medium`: 35 to 69
  - `high`: 70 and above

These are starting points only. They should be treated as provisional until they are calibrated on labeled data.