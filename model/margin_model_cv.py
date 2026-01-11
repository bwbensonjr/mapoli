"""
Hold-out cross-validation for MA legislative election margin models.

This script sets up infrastructure for comparing Bayesian regression and
gradient boosted models predicting Democratic margin in Massachusetts
legislative elections.
"""

import pandas as pd
import numpy as np
import bambi as bmb
import arviz as az
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.preprocessing import OneHotEncoder
import xgboost as xgb


def load_data(filepath="ma_leg_two_party_2008_2025.csv"):
    """Load and prepare the election data."""
    df = pd.read_csv(filepath)

    # Select columns needed for modeling
    cols = ["dem_margin", "PVI_N", "incumbent_status", "pres_elec",
            "election_year", "office", "district_display"]
    df = df[cols].copy()

    # Convert boolean to int for modeling
    df["pres_elec"] = df["pres_elec"].astype(int)

    # Ensure incumbent_status is categorical
    df["incumbent_status"] = pd.Categorical(
        df["incumbent_status"],
        categories=["No_Incumbent", "Dem_Incumbent", "GOP_Incumbent"]
    )

    return df


def split_data(df, test_size=0.2, random_state=42):
    """Split data into train and test sets."""
    train_df, test_df = train_test_split(
        df,
        test_size=test_size,
        random_state=random_state,
        stratify=df["incumbent_status"]  # Stratify by incumbent status
    )
    return train_df, test_df


def fit_baseline_model(train_df, samples=2000, chains=4, random_seed=42):
    """
    Fit the baseline margin model (replicating R rstanarm model).

    Model: dem_margin ~ PVI_N + incumbent_status + pres_elec
    """
    model = bmb.Model(
        "dem_margin ~ PVI_N + incumbent_status + pres_elec",
        data=train_df,
        family="gaussian"
    )

    results = model.fit(
        draws=samples,
        chains=chains,
        random_seed=random_seed
    )

    return model, results


def predict_and_evaluate(model, results, test_df):
    """Generate predictions and compute evaluation metrics."""
    # Get posterior predictive mean (adds 'mu' to results.posterior)
    model.predict(results, data=test_df, kind="response_params", inplace=True)

    # Extract mean predictions across chains and draws
    # mu has shape (chains, draws, observations)
    y_pred = results.posterior["mu"].mean(dim=["chain", "draw"]).values
    y_true = test_df["dem_margin"].values

    # Compute metrics
    metrics = {
        "rmse": np.sqrt(mean_squared_error(y_true, y_pred)),
        "mae": mean_absolute_error(y_true, y_pred),
        "r2": r2_score(y_true, y_pred),
        "n_test": len(y_true)
    }

    return metrics, y_pred


def prepare_features_for_trees(train_df, test_df):
    """
    Prepare feature matrices for tree-based models.

    Converts categorical variables to numeric format suitable for
    gradient boosted trees.
    """
    feature_cols = ["PVI_N", "incumbent_status", "pres_elec"]

    # Create copies
    X_train = train_df[feature_cols].copy()
    X_test = test_df[feature_cols].copy()

    # One-hot encode incumbent_status
    encoder = OneHotEncoder(sparse_output=False, drop="first")
    inc_train = encoder.fit_transform(X_train[["incumbent_status"]])
    inc_test = encoder.transform(X_test[["incumbent_status"]])

    # Get feature names for the encoded columns
    inc_feature_names = encoder.get_feature_names_out(["incumbent_status"])

    # Build final feature matrices
    X_train_final = pd.DataFrame({
        "PVI_N": X_train["PVI_N"].values,
        "pres_elec": X_train["pres_elec"].astype(int).values,
    })
    X_test_final = pd.DataFrame({
        "PVI_N": X_test["PVI_N"].values,
        "pres_elec": X_test["pres_elec"].astype(int).values,
    })

    # Add one-hot encoded columns
    for i, name in enumerate(inc_feature_names):
        X_train_final[name] = inc_train[:, i]
        X_test_final[name] = inc_test[:, i]

    y_train = train_df["dem_margin"].values
    y_test = test_df["dem_margin"].values

    return X_train_final, X_test_final, y_train, y_test


def fit_xgboost_model(X_train, y_train, random_seed=42):
    """
    Fit an XGBoost regression model.

    Uses reasonable defaults for a small dataset.
    """
    model = xgb.XGBRegressor(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=random_seed,
        verbosity=0
    )
    model.fit(X_train, y_train)
    return model


def fit_sklearn_gbm_model(X_train, y_train, random_seed=42):
    """
    Fit a scikit-learn HistGradientBoostingRegressor.

    This is sklearn's fast histogram-based gradient boosting implementation,
    similar to LightGBM.
    """
    model = HistGradientBoostingRegressor(
        max_iter=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=random_seed
    )
    model.fit(X_train, y_train)
    return model


def evaluate_tree_model(model, X_test, y_test):
    """Evaluate a tree-based model and return metrics."""
    y_pred = model.predict(X_test)

    metrics = {
        "rmse": np.sqrt(mean_squared_error(y_test, y_pred)),
        "mae": mean_absolute_error(y_test, y_pred),
        "r2": r2_score(y_test, y_pred),
        "n_test": len(y_test)
    }

    return metrics, y_pred


def print_model_summary(results):
    """Print a summary of the fitted model."""
    print("\n" + "=" * 60)
    print("MODEL SUMMARY")
    print("=" * 60)
    print(az.summary(results, var_names=["Intercept", "PVI_N", "incumbent_status", "pres_elec", "sigma"]))


def print_evaluation_metrics(metrics, model_name="Baseline"):
    """Print evaluation metrics in a formatted way."""
    print("\n" + "=" * 60)
    print(f"EVALUATION METRICS: {model_name}")
    print("=" * 60)
    print(f"  RMSE:     {metrics['rmse']:.3f}")
    print(f"  MAE:      {metrics['mae']:.3f}")
    print(f"  R²:       {metrics['r2']:.3f}")
    print(f"  N (test): {metrics['n_test']}")


def compare_models(results_dict):
    """
    Compare multiple models side by side.

    Parameters
    ----------
    results_dict : dict
        Dictionary mapping model names to their metrics dictionaries
    """
    print("\n" + "=" * 60)
    print("MODEL COMPARISON")
    print("=" * 60)

    # Create comparison DataFrame
    comparison = pd.DataFrame(results_dict).T
    comparison.index.name = "Model"
    print(comparison.to_string())

    return comparison


def main():
    """Run the hold-out cross-validation comparing all models."""
    print("Loading data...")
    df = load_data()
    print(f"  Total observations: {len(df)}")

    print("\nSplitting data (80/20 train/test)...")
    train_df, test_df = split_data(df, test_size=0.2)
    print(f"  Training set: {len(train_df)}")
    print(f"  Test set: {len(test_df)}")

    all_metrics = {}

    # -------------------------------------------------------------------------
    # 1. Bayesian Linear Model (baseline)
    # -------------------------------------------------------------------------
    print("\n" + "=" * 60)
    print("FITTING BAYESIAN LINEAR MODEL (Baseline)")
    print("=" * 60)
    print("  Model: dem_margin ~ PVI_N + incumbent_status + pres_elec")

    bayesian_model, bayesian_results = fit_baseline_model(train_df)
    print_model_summary(bayesian_results)

    print("\nGenerating predictions on test set...")
    bayesian_metrics, bayesian_preds = predict_and_evaluate(
        bayesian_model, bayesian_results, test_df
    )
    print_evaluation_metrics(bayesian_metrics, model_name="Bayesian Linear")
    all_metrics["Bayesian Linear"] = bayesian_metrics

    # -------------------------------------------------------------------------
    # 2. Prepare features for tree-based models
    # -------------------------------------------------------------------------
    print("\n" + "=" * 60)
    print("PREPARING FEATURES FOR TREE MODELS")
    print("=" * 60)
    X_train, X_test, y_train, y_test = prepare_features_for_trees(train_df, test_df)
    print(f"  Features: {list(X_train.columns)}")

    # -------------------------------------------------------------------------
    # 3. XGBoost Model
    # -------------------------------------------------------------------------
    print("\n" + "=" * 60)
    print("FITTING XGBOOST MODEL")
    print("=" * 60)

    xgb_model = fit_xgboost_model(X_train, y_train)
    xgb_metrics, xgb_preds = evaluate_tree_model(xgb_model, X_test, y_test)
    print_evaluation_metrics(xgb_metrics, model_name="XGBoost")
    all_metrics["XGBoost"] = xgb_metrics

    # Print feature importances
    print("\n  Feature Importances:")
    for name, importance in zip(X_train.columns, xgb_model.feature_importances_):
        print(f"    {name}: {importance:.3f}")

    # -------------------------------------------------------------------------
    # 4. Scikit-learn HistGradientBoosting Model
    # -------------------------------------------------------------------------
    print("\n" + "=" * 60)
    print("FITTING SKLEARN HISTGRADIENTBOOSTING MODEL")
    print("=" * 60)

    sklearn_gbm = fit_sklearn_gbm_model(X_train, y_train)
    sklearn_metrics, sklearn_preds = evaluate_tree_model(sklearn_gbm, X_test, y_test)
    print_evaluation_metrics(sklearn_metrics, model_name="Sklearn HistGBM")
    all_metrics["Sklearn HistGBM"] = sklearn_metrics

    # -------------------------------------------------------------------------
    # 5. Model Comparison
    # -------------------------------------------------------------------------
    comparison = compare_models(all_metrics)

    return {
        "comparison": comparison,
        "all_metrics": all_metrics,
        "models": {
            "bayesian": (bayesian_model, bayesian_results),
            "xgboost": xgb_model,
            "sklearn_gbm": sklearn_gbm
        },
        "predictions": {
            "bayesian": bayesian_preds,
            "xgboost": xgb_preds,
            "sklearn_gbm": sklearn_preds
        },
        "train_df": train_df,
        "test_df": test_df,
        "X_train": X_train,
        "X_test": X_test,
        "y_train": y_train,
        "y_test": y_test
    }


if __name__ == "__main__":
    output = main()
