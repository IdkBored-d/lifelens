import pandas as pd

def calculate_onboarding_score(user_data, user_state, mlp_pipeline, feature_cols, state_shifts, significance_weight=0.2):
    """DAY 1: Calculates initial score using the Global Model + CDC State Shift."""
    user_df = pd.DataFrame([user_data])
    user_df['bmi'] = user_df['weight_kg'] / ((user_df['height_cm'] / 100) ** 2)
    user_df['gender_M'] = 1 if str(user_data['gender']).lower() == 'male' else 0
    
    X_user = user_df[feature_cols]
    
    # Predict directly with the pipeline (no manual scaling needed)
    mlp_prob = mlp_pipeline.predict_proba(X_user)[0][1] * 100 
    shift = state_shifts.get(user_state, 0.0)
    
    adjusted_score = mlp_prob - (shift * significance_weight)
    final_score = max(0.0, min(100.0, adjusted_score))
    
    return final_score

def calculate_daily_score(daily_data, old_score, mlp_pipeline, feature_cols, alpha=0.3):
    """
    DAY 2+: Calculates daily progression using Exponential Moving Average (EMA).
    This compares the user to their own baseline rather than the global standard.
    """
    user_df = pd.DataFrame([daily_data])
    user_df['bmi'] = user_df['weight_kg'] / ((user_df['height_cm'] / 100) ** 2)
    user_df['gender_M'] = 1 if str(daily_data['gender']).lower() == 'male' else 0
    
    X_user = user_df[feature_cols]
    
    # 1. Get the raw new score for today's effort
    new_mlp_prob = mlp_pipeline.predict_proba(X_user)[0][1] * 100 
    
    # 2. Apply the EMA Formula (User vs. Themselves)
    # current_score = (ɑ * new_score) + ((1 - ɑ) * old_score)
    smoothed_score = (alpha * new_mlp_prob) + ((1.0 - alpha) * old_score)
    
    return new_mlp_prob, smoothed_score