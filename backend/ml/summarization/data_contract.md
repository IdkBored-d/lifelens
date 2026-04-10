# Summarization Data Contract

## Row Schema
Each training row must be a JSON object with this shape:

```json
{
  "input": "sleep_avg_3=5.20 mood_avg_3=2.10 sleep_slope=-0.300 mood_slope=-0.250 risk=68.40 trend=-0.190",
  "target": "Sleep and mood are trending downward, suggesting rising fatigue risk."
}
```

## Required Fields
- `input`: non-empty string
- `target`: non-empty string

## Input Tokens (required)
- `sleep_avg_3`
- `mood_avg_3`
- `sleep_slope`
- `mood_slope`
- `risk`
- `trend`

## Value Ranges
- `sleep_avg_3`: 0.0 to 12.0
- `mood_avg_3`: 0.0 to 5.0
- `sleep_slope`: -2.0 to 2.0
- `mood_slope`: -2.0 to 2.0
- `risk`: 0.0 to 100.0
- `trend`: -2.0 to 2.0

## Target Quality Rules
- Must be natural language.
- Must not contain feature token echoes like `risk=` or `sleep_avg_3=`.
- Keep concise: 8 to 40 words.

## Label Buckets (for balance checks)
- `declining`
- `stable`
- `improving`
- `low_sleep`
- `low_mood`
- `high_risk`
- `other`

## Deduplication Key
- Deduplicate by normalized tuple: `(input.strip().lower(), target.strip().lower())`.
