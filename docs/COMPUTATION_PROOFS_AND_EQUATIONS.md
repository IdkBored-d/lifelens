# LifeLens Computation Proofs and Equations (Defense Sheet)

## How to Use This File (Simple Mode)

If this feels too technical, use it like a script, not like a textbook.

### 1) Read only these sections first

- Section 2: Mood Classifier
- Section 5: Mood Trend Summary
- Section 8: Streak Computations
- Section 9: Data Durability and Backup Property

Those four sections are enough for most professor questions.

### 2) What to say out loud

Use this short structure:

1. "We compute a model probability, then apply confidence gates before accepting predictions."
2. "We compute trends from stored history using averages, streaks, and deltas."
3. "We write locally first, then cloud-sync, so data is not lost if cloud fails."

### 3) How to answer equation questions

- If asked "what is this equation for?": explain purpose first (classification, trend, or reliability).
- If asked "why this threshold?": point to the threshold constants in Section 2/3/4 and say they are calibrated policy gates.
- If asked "prove correctness": use the short proof notes under each section (they are intentionally brief defense proofs).

### 4) What to skip unless asked

- Full Mini-Me weighting details in Section 6
- Full symbolic notation in Section 1

You only need those if the professor asks for deeper math.

### 5) One-minute defense script

"LifeLens uses local AI plus deterministic trend logic. For mood, we compute softmax probabilities and only accept predictions after three confidence checks: floor, class threshold, and ambiguity margin. Trends are computed from stored entries using daily deduplication, run grouping, and fitness deltas. Streaks are computed from consecutive logged days. Reliability is local-first: write to Isar first, then cloud sync. So even if cloud fails, the local source of truth remains correct and summaries can be regenerated."

## Professor 5-Step Trace (Exact LifeLens Version)

Use this section if you want one clean end-to-end explanation with real app constants.

### 1) Data goes in -> numeric vector

The app converts raw user input (mood text, symptom text, logs, health signals) into numeric tensors/vectors used by the models.

```text
x = f(x_raw)
```

Where `f` is preprocessing + tokenization + feature construction.

### 2) Model predicts -> probabilities

Mood model output is converted to probabilities and ranked.

```text
p_i = exp(z_i) / sum_j exp(z_j)
hat{y} = argmax_i p_i
p_max = max_i p_i
p_2 = second-largest probability
Delta = p_max - p_2
```

Real class index mapping in LifeLens:

```text
index 0: sadness
index 1: joy
index 2: love
index 3: anger
index 4: fear
index 5: surprise
```

### 3) Deterministic rules filter the prediction

The app accepts only if all three checks pass.

```text
rule1: p_max >= 0.50
rule2: p_max >= tau_class
rule3: Delta >= 0.15
accept = rule1 AND rule2 AND rule3
```

Real class thresholds used:

```text
sadness: 0.62
joy: 0.62
anger: 0.63
fear: 0.65
love: 0.67
surprise: 0.71
```

### 4) Real runtime row + gate check

Captured runtime probabilities:

```text
all_probs = [0.009, 0.000, 0.029, 0.001, 0.872, 0.088]
```

Mapped by class:

```text
sadness=0.009, joy=0.000, love=0.029, anger=0.001, fear=0.872, surprise=0.088
```

Computed values:

```text
p_max = 0.872 (fear)
p_2   = 0.088 (surprise)
Delta = 0.872 - 0.088 = 0.784
```

Gate results:

```text
rule1: 0.872 >= 0.50  -> pass
rule2: 0.872 >= 0.65  -> pass  (fear threshold)
rule3: 0.784 >= 0.15  -> pass
accept = true
```

Final decision for this real row:

```text
predicted class = fear
confidence status = accepted
```

### 5) Trend logic runs separately and deterministically

After classification, trend/streak logic uses stored history and fixed formulas.

```text
delta_f = recent_fitness - oldest_fitness
current_run = (start_days_ago - end_days_ago) + 1
```

Interpretation:

```text
delta_f > 0 -> up
delta_f < 0 -> down
delta_f = 0 -> stable
```

Key defense point:

```text
Same input -> same probabilities -> same gate checks -> same output.
```

This is why the system is deterministic and not arbitrary.

## 1) Symbols

- `z_i`: raw logit for class `i`.
- `p_i`: softmax probability for class `i`.
- `hat{y}`: predicted class index.
- `p_max`: top class probability.
- `p_2`: second-largest class probability.
- `Delta`: ambiguity margin, `p_max - p_2`.
- `tau_c`: class-specific threshold for class `c`.
- `s`: cosine similarity.
- `theta`: similarity threshold.
- `m`: uncertainty margin around `theta`.

## 2) Mood Classifier (MobileBERT)

### Equation

```text
p_i = exp(z_i) / sum_j exp(z_j)
hat{y} = argmax_i p_i
p_max = max_i p_i
Delta = p_max - p_2
```

### Piecewise Decision Function

```text
accept = false if p_max < 0.50
accept = false if p_max < tau_hat{y}
accept = false if Delta < 0.15
accept = true otherwise
```

Class thresholds used:

- sadness: `0.62`
- joy: `0.62`
- anger: `0.63`
- fear: `0.65`
- love: `0.67`
- surprise: `0.71`

### Correctness Notes

- Probability validity: `p_i > 0` and `sum_i p_i = 1`.
- Argmax rule is Bayes-optimal for 0-1 loss under calibrated class posteriors.
- Margin stability: if probabilities are perturbed by at most `epsilon`, rank flip requires `2epsilon > Delta`. Enforcing `Delta >= 0.15` creates a robustness buffer.

## 3) Symptom Similarity Confidence (DisEmbed)

### Equation

```text
s = cosine(u, v) = (u · v) / (||u|| * ||v||)
```

Parameters:

- `theta = 0.3846`
- `m = 0.05`
- uncertainty band: `[theta - m, theta + m] = [0.3346, 0.4346]`

### Piecewise Decision Function

```text
if abs(s - theta) <= m: uncertain
else if s > 0.55: high-similar
else if s < 0.20: high-dissimilar
else: medium
```

### Correctness Notes

- Cosine output is bounded in `[-1, 1]`.
- The uncertain region is a symmetric tolerance interval around the boundary.

## 4) Fitness Confidence (MLP)

### Equation

Given probabilities `q = [q0, q1] = [P(not-fit), P(fit)]`:

```text
hat{y} = 1 if q1 >= 0.5 else 0
c = max(q0, q1)
```

### Piecewise Decision Function

```text
confidence_ok = false if c < 0.70
confidence_ok = true otherwise
```

### Correctness Notes

- `c` is the posterior certainty of the predicted class.
- Thresholding `c` is a standard selective-classification strategy.

## 5) Mood Trend Summary

The app first deduplicates entries by date (latest entry per day), then groups consecutive equal labels.

### Equations

- Current run length:

```text
current_run = (start_days_ago - end_days_ago) + 1
```

- Fitness delta over window:

```text
delta_f = recent_fitness - oldest_fitness
```

Direction:

```text
up if delta_f > 0
down if delta_f < 0
stable if delta_f == 0
```

### Correctness Notes

- Dedup-by-day prevents same-day overcount bias.
- Run grouping is maximal-segment decomposition of a categorical time series.

## 6) Mini-Me Visual Computations

Core normalized features (all clamped to the range 0 to 1):

```text
Ds = clamp((7.5 - avg_recent_sleep_hours) / 3.5, 0, 1)
Dm = clamp((avg_previous_mood - avg_recent_mood) / 2.2, 0, 1)
C  = clamp(tracked_days_last_7 / 7, 0, 1)
T  = clamp(consecutive_days_from_today / 7, 0, 1)
```

Weighted composites:

```text
W = clamp(0.22*Ds + 0.22*DsleepDrop + 0.20*Dm + 0.14*distress + 0.12*symptom - 0.18*R, 0, 1)
E = clamp(0.62 + 0.16*C + 0.08*T + 0.18*R - 0.48*Ds - 0.26*distress - 0.16*symptom, 0, 1)
```

### Correctness Notes

- Clamp guarantees bounded outputs for rendering and animation.
- Weighted sums define interpretable monotonic effects (for example, higher sleep debt reduces energy).

## 7) Sleep Insight Calculations

For `n` sleep logs with durations `d_i` and quality scores `q_i`:

```text
average_duration = (d1 + d2 + ... + dn) / n
average_quality   = (q1 + q2 + ... + qn) / n
goal_difference   = average_duration_hours - 8
best_night        = max(d_i)
```

## 8) Streak Computations

Let `L` be the set of logged days normalized to day granularity.

### Equations

- Current streak:

```text
current = largest k such that {today, yesterday, ..., today-(k-1)} is all in L
```

- Best streak: longest consecutive-day subsequence in sorted `L`.

### Correctness Notes

- Current streak algorithm is exact by induction on contiguous days from today.
- Best streak algorithm is a linear scan over sorted dates, equivalent to longest-run detection.

## 9) Data Durability and Backup Property

Write order for mood logs:

1. Local Isar write
2. UI/store refresh
3. Cloud sync attempt (if signed in)

Property:

If cloud sync fails but local write succeeded, the entry still exists in local source-of-truth storage.

```text
W_local = 1 and W_cloud = 0 implies the entry exists in IsarMoodEntries
```

This is why trend and summary regeneration remains possible offline.

## 10) Traceability to Code

- Mood result types: [lib/models/mood_result.dart](../lib/models/mood_result.dart)
- Confidence rules: [lib/services/confidence_manager.dart](../lib/services/confidence_manager.dart)
- Mood and symptom pipelines: [lib/services/mood_pipeline_service.dart](../lib/services/mood_pipeline_service.dart), [lib/services/symptom_pipeline_service.dart](../lib/services/symptom_pipeline_service.dart)
- Summary/trend generation: [lib/services/quick_track_service.dart](../lib/services/quick_track_service.dart)
- Mini-Me visual scoring: [lib/minime_screen.dart](../lib/minime_screen.dart)
- Sleep insight math: [lib/widgets/sleep_insights_widget.dart](../lib/widgets/sleep_insights_widget.dart)
- Streak algorithms: [lib/services/streak_service.dart](../lib/services/streak_service.dart)
- Local persistence: [lib/database/isar_service.dart](../lib/database/isar_service.dart)
- Mood save and cloud sync: [lib/moodlog_screen.dart](../lib/moodlog_screen.dart)