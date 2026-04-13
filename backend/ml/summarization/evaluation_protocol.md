# LifeLens Scientific Validation Protocol

This document defines how to validate trend and risk scoring against labeled data in a way that is reproducible, defensible, and resistant to leakage.

## 1. Research Question

We are not trying to prove the scores in a mathematical sense. We are testing whether the scores and trend labels are:
- consistent with the labeled ground truth,
- better than simple baselines,
- calibrated to downstream outcomes,
- stable across users and time,
- and robust under ablation testing.

## 2. Ground Truth Definition

### Trend Ground Truth
The trend label should come from the later window, not from the model.
- `improving` means the later window is meaningfully better than the earlier window.
- `stable` means the difference is within the pre-defined tolerance.
- `declining` means the later window is meaningfully worse than the earlier window.

### Risk Ground Truth
The risk label should come from a downstream outcome, such as:
- symptom escalation,
- worsening mood or sleep pattern,
- clinician follow-up,
- urgent support request,
- or a severity score assigned after the window.

## 3. Dataset Construction

Use [evaluation_dataset.schema.json](evaluation_dataset.schema.json) to store rows.

Recommended fields:
- `user_id`
- `window_start`
- `window_end`
- `dataset_type` (`trend` or `risk`)
- `label`
- `annotation_confidence`
- `predicted_risk_score` for risk rows
- `actual_delta` and `actual_rate` for trend rows

### Data Split Rule
Split by user and by time.
- Train on earlier periods.
- Validate on later periods.
- Hold out entire users when possible.

Do not randomly split rows, because adjacent rows from the same user can leak the answer.

## 4. Baselines

Always compare against simple baselines.

### Trend Baselines
- Majority-class baseline.
- Rule-based threshold baseline.
- Simple linear or logistic model using the same input features.

### Risk Baselines
- Majority-class baseline.
- Simple threshold rule based on the current policy.
- Logistic regression or linear heuristic using the same features.

The model should outperform these baselines, or the score is not adding enough value.

## 5. Metrics

### Trend Metrics
- Accuracy.
- Macro-F1.
- Confusion matrix.
- Optionally, weighted-F1 if classes are imbalanced.

### Risk Metrics
- AUC or PR-AUC.
- Calibration curve.
- Brier score.
- Spearman correlation with severity.
- Optional: top-k precision if the score is used for prioritization.

## 6. Statistical Reliability

Use bootstrap confidence intervals so the result is not dependent on one lucky split.
- Report the mean metric.
- Report the 95% confidence interval.
- Repeat evaluation across multiple seeds or time splits when possible.

## 7. Ablation Testing

Remove one signal group at a time and measure the drop in performance.

Recommended ablations:
- sleep removed
- mood removed
- activity removed
- symptoms removed
- interaction terms removed

If removing a feature does not lower performance, that feature may not be contributing meaningfully.

## 8. Human Label Quality

If humans annotate the data, measure agreement before trusting the labels.
- Cohen’s kappa for two annotators.
- Krippendorff’s alpha for more than two annotators.

If agreement is low, fix the rubric before evaluating the model.

## 9. Subgroup Checks

Evaluate whether the score behaves reasonably across different patterns.

Examples:
- users with high activity but worsening symptoms,
- users with stable mood but declining sleep,
- users with low symptoms but rising risk score,
- users with conflicting signals.

The score should not collapse into one signal only. It should reflect the full pattern.

## 10. Acceptance Criteria

A score is scientifically defensible if it:
- matches the labeled ground truth on held-out data,
- beats the baselines,
- shows acceptable calibration,
- survives ablation testing,
- and stays stable across users and subgroups.

The correct claim is: the score was validated on labeled data and shown to be reproducible and better than simple baselines. Do not claim it is clinically proven unless it has been validated in a clinical study.