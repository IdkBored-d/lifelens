import pandas as pd

def get_state_shifts(cdc_filepath):
    """Calculates the deviation of each state from the national obesity average."""
    df = pd.read_csv(cdc_filepath)
    
    # Filter for the correct metric
    obesity_question = "Percent of adults aged 18 years and older who have obesity"
    filtered_df = df[(df['Question'] == obesity_question) & (df['Stratification1'] == 'Total')]
    clean_df = filtered_df[['LocationDesc', 'Data_Value']].dropna()
    
    # Calculate averages and the national baseline
    state_averages = clean_df.groupby('LocationDesc')['Data_Value'].mean()
    national_avg = state_averages.mean()
    
    # Positive delta = higher obesity (unfavorable), Negative = lower obesity (favorable)
    state_shifts = (state_averages - national_avg).to_dict()
    
    return state_shifts, national_avg