"""
ML Pipeline Configuration
=========================

Module name is `pipeline_config` (not `config`) to avoid a name collision with
the simulator's own `config.py` — both folders end up on sys.path and Python
caches the first match. All ML pipeline scripts use:

    import pipeline_config as cfg

Folder layout produced by the pipeline:

    MLPipeline/
    ├── pipeline_config.py
    ├── feature_engineering.py
    ├── generate_training_data.py
    ├── generate_test_data.py
    ├── train_catboost_persona_model.py
    ├── evaluate_persona_model.py
    └── outputs/
        ├── train_raw/        ← raw simulator CSVs for training population
        ├── test_raw/         ← raw simulator CSVs for held-out test population
        ├── features/         ← engineered feature matrices (train, val, test)
        ├── model/            ← trained CatBoost artifact + metadata
        └── reports/          ← evaluation metrics, plots, SHAP summary
"""

from __future__ import annotations

import os
from pathlib import Path

# ---------------------------------------------------------------- paths ---
ROOT = Path(__file__).resolve().parent
OUTPUTS = ROOT / "outputs"

TRAIN_RAW_DIR = OUTPUTS / "train_raw"
TEST_RAW_DIR  = OUTPUTS / "test_raw"
FEATURES_DIR  = OUTPUTS / "features"
MODEL_DIR     = OUTPUTS / "model"
REPORTS_DIR   = OUTPUTS / "reports"

for d in (TRAIN_RAW_DIR, TEST_RAW_DIR, FEATURES_DIR, MODEL_DIR, REPORTS_DIR):
    d.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------- simulation settings ---
N_USERS_TRAIN     = int(os.environ.get("N_USERS_TRAIN",     "1000"))
N_USERS_TEST      = int(os.environ.get("N_USERS_TEST",      "300"))
DAYS_PER_USER     = int(os.environ.get("DAYS_PER_USER",     "14"))
RANDOM_SEED_TRAIN = int(os.environ.get("RANDOM_SEED_TRAIN", "42"))
RANDOM_SEED_TEST  = int(os.environ.get("RANDOM_SEED_TEST",  "1337"))

# Balanced persona sampling for supervised learning. When True we override the
# default `PERSONA_POPULATION_WEIGHTS` so every persona gets ~1/12 of the
# population (avoids severe class collapse). When False we keep the realistic
# population mix.
BALANCE_PERSONAS = os.environ.get("BALANCE_PERSONAS", "true").lower() in ("1", "true", "yes")

# ----------------------------------------------- train / val / test split ---
# Test set is generated as a *separate* simulation (different seed, disjoint
# user ids). Train + val come from the training simulation and are split by
# user (so the same user never crosses splits).
VAL_FRACTION = 0.15

# ----------------------------------------------- feature-set composition ---
# Episode-share features come from episode_log.csv which is only available in
# synthetic data. To deploy on real telemetry, we train two model variants:
#   "telemetry"      — features derivable from gps + apps + screen events only
#   "with_episodes"  — adds episode-share features (synthetic-only, upper bound)
# Default training builds both; `evaluate_persona_model.py` reports both.
FEATURE_SET = os.environ.get("FEATURE_SET", "telemetry")  # "telemetry" | "with_episodes"

# ------------------------------------------------------ catboost settings ---
CATBOOST_PARAMS = {
    "iterations":            int(os.environ.get("CB_ITERATIONS", "1500")),
    "learning_rate":         float(os.environ.get("CB_LR", "0.05")),
    "depth":                 int(os.environ.get("CB_DEPTH", "6")),
    "loss_function":         "MultiClass",
    "eval_metric":           "TotalF1",         # macro-F1
    "early_stopping_rounds": 100,
    "use_best_model":        True,
    "verbose":               100,
    "random_seed":           42,
    "auto_class_weights":    "Balanced",        # handles residual imbalance
    "l2_leaf_reg":           3.0,
    "task_type":             os.environ.get("CB_TASK_TYPE", "GPU"),
}

# ---------------------------------------------- file naming conventions ---
TRAIN_FEATURES_CSV = FEATURES_DIR / "train_features.csv"
VAL_FEATURES_CSV   = FEATURES_DIR / "val_features.csv"
TEST_FEATURES_CSV  = FEATURES_DIR / "test_features.csv"

MODEL_FILE         = MODEL_DIR / "catboost_persona.cbm"
LABEL_ENCODER_FILE = MODEL_DIR / "label_encoder.json"
FEATURE_LIST_FILE  = MODEL_DIR / "feature_columns.json"

EVAL_REPORT_MD     = REPORTS_DIR / "evaluation_report.md"
CONFUSION_PNG      = REPORTS_DIR / "confusion_matrix.png"
FEATURE_IMP_PNG    = REPORTS_DIR / "feature_importance.png"
SHAP_SUMMARY_PNG   = REPORTS_DIR / "shap_summary.png"
PER_CLASS_CSV      = REPORTS_DIR / "per_class_metrics.csv"


# Make the simulator package importable (MLPipeline/simulation/)
import sys
SIM_PATH = ROOT / "simulation"
if str(SIM_PATH) not in sys.path:
    sys.path.insert(0, str(SIM_PATH))


def banner(title: str):
    line = "=" * max(60, len(title) + 4)
    print(f"\n{line}\n  {title}\n{line}")
