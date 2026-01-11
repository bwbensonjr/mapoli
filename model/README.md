# MA Legislative Election Models

This directory contains statistical models for predicting outcomes in Massachusetts legislative elections.

## Overview

The models predict Democratic margin (percentage point difference between Democratic and Republican candidates) based on:

- **PVI_N**: Partisan Voting Index (numeric) - measures how Democratic or Republican a district leans
- **incumbent_status**: Whether there's an incumbent and their party (No_Incumbent, Dem_Incumbent, GOP_Incumbent)
- **pres_elec**: Whether the election occurs in a presidential election year

## Models

### Bayesian Linear Model (R)

The original model in `ma_leg_model.R` uses `rstanarm::stan_glm` with:
- Logistic regression for win probability (`dem_win ~ PVI_N + incumbent_status + pres_elec`)
- Linear regression for margin prediction (`dem_margin ~ PVI_N + incumbent_status + pres_elec`)

### Python Models

`margin_model_cv.py` provides Python implementations for model comparison:

1. **Bayesian Linear** (Bambi/PyMC) - Direct port of the R rstanarm model
2. **XGBoost** - Gradient boosted trees
3. **Sklearn HistGBM** - Scikit-learn's histogram-based gradient boosting

## Setup

This directory uses `uv` for Python dependency management.

```bash
# Install dependencies
uv sync

# Run the model comparison
uv run python margin_model_cv.py
```

## Data

- `ma_leg_two_party_2008_2025.csv` - Prepared dataset of MA legislative elections with two or more candidates (2008-2025)
- Source data comes from the MA Election Database and PVI calculations in `../pvi/`

## Usage

### Running the Comparison

```bash
uv run python margin_model_cv.py
```

This will:
1. Load the election data
2. Split into 80/20 train/test sets (stratified by incumbent status)
3. Fit all three models
4. Print evaluation metrics (RMSE, MAE, R²) and a comparison table

### Using as a Library

```python
from margin_model_cv import (
    load_data,
    split_data,
    fit_baseline_model,
    fit_xgboost_model,
    prepare_features_for_trees,
    evaluate_tree_model
)

# Load and split data
df = load_data()
train_df, test_df = split_data(df, test_size=0.2)

# Fit Bayesian model
model, results = fit_baseline_model(train_df)

# Fit XGBoost model
X_train, X_test, y_train, y_test = prepare_features_for_trees(train_df, test_df)
xgb_model = fit_xgboost_model(X_train, y_train)
metrics, predictions = evaluate_tree_model(xgb_model, X_test, y_test)
```

## Results

Typical hold-out validation results (80/20 split):

| Model | RMSE | MAE | R² |
|-------|------|-----|-----|
| XGBoost | ~15.9 | ~11.9 | ~0.60 |
| Bayesian Linear | ~16.2 | ~12.1 | ~0.58 |
| Sklearn HistGBM | ~16.4 | ~12.2 | ~0.57 |

The models perform similarly, with XGBoost showing a slight edge. The most important predictors are GOP incumbent status and PVI.

## Dependencies

See `pyproject.toml` for the full list. Key packages:
- `bambi` / `pymc` - Bayesian modeling
- `xgboost` - Gradient boosted trees
- `scikit-learn` - ML utilities and HistGradientBoosting
- `arviz` - Bayesian model diagnostics
- `pandas` / `numpy` - Data manipulation
