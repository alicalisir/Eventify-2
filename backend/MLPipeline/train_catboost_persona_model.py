"""
Train CatBoost Persona Classifier
=================================

Pipeline:
  1. Read raw training CSVs from outputs/train_raw/
  2. Build per-user feature matrix via feature_engineering.features_from_directory
  3. Attach persona labels from users.csv
  4. User-level stratified split into train/val (no user appears in both)
  5. Train CatBoostClassifier (multiclass, class-weighted)
  6. Save model artifact + label encoder + feature column list

Test set is generated separately by `generate_test_data.py` and consumed by
`evaluate_persona_model.py`. We deliberately keep evaluation isolated.

Run:
    python train_catboost_persona_model.py
    FEATURE_SET=with_episodes python train_catboost_persona_model.py
"""

from __future__ import annotations

import json
import logging
import time
from pathlib import Path

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier, Pool
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score, classification_report

import pipeline_config as cfg
import feature_engineering as fe

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
log = logging.getLogger("train")


# ============================================================================
# data preparation
# ============================================================================

def load_training_data() -> pd.DataFrame:
    """Build feature matrix + labels from outputs/train_raw/."""
    if not (cfg.TRAIN_RAW_DIR / "users.csv").exists():
        raise FileNotFoundError(
            f"No training data at {cfg.TRAIN_RAW_DIR}. "
            f"Run generate_training_data.py first."
        )

    log.info(f"reading raw training data from {cfg.TRAIN_RAW_DIR}")
    include_eps = cfg.FEATURE_SET == "with_episodes"
    log.info(f"feature set: {cfg.FEATURE_SET} (episode features = {include_eps})")

    t0 = time.time()
    feats = fe.features_from_directory(
        cfg.TRAIN_RAW_DIR, include_episode_features=include_eps,
    )
    log.info(f"  feature matrix: {feats.shape}  ({time.time()-t0:.1f}s)")

    feats = fe.attach_persona_labels(feats, cfg.TRAIN_RAW_DIR / "users.csv")
    feats = feats.dropna(subset=["persona"])
    log.info(f"  with labels: {feats.shape}")
    log.info(f"  label distribution:\n{feats['persona'].value_counts().to_string()}")

    return feats


def split_users(df: pd.DataFrame, val_fraction: float, seed: int):
    """
    User-level stratified split. Each user_id has exactly one row in the
    feature matrix (per-user aggregation), so plain train_test_split on
    rows == on users. We stratify on persona.
    """
    train_df, val_df = train_test_split(
        df,
        test_size=val_fraction,
        stratify=df["persona"],
        random_state=seed,
    )
    return train_df.reset_index(drop=True), val_df.reset_index(drop=True)


# ============================================================================
# training
# ============================================================================

def train(train_df: pd.DataFrame, val_df: pd.DataFrame):
    feature_cols = fe.feature_columns(train_df)
    log.info(f"  feature columns: {len(feature_cols)}")

    # label encoder (sorted for determinism)
    classes = sorted(train_df["persona"].unique())
    class_to_idx = {c: i for i, c in enumerate(classes)}
    log.info(f"  classes ({len(classes)}): {classes}")

    y_train = train_df["persona"].map(class_to_idx).to_numpy()
    y_val   = val_df["persona"].map(class_to_idx).to_numpy()
    X_train = train_df[feature_cols].to_numpy(dtype=float)
    X_val   = val_df[feature_cols].to_numpy(dtype=float)

    log.info(f"  X_train: {X_train.shape}  X_val: {X_val.shape}")

    train_pool = Pool(X_train, y_train, feature_names=feature_cols)
    val_pool   = Pool(X_val, y_val, feature_names=feature_cols)

    params = dict(cfg.CATBOOST_PARAMS)
    params["classes_count"] = len(classes)

    log.info("CatBoost params:")
    for k, v in params.items():
        log.info(f"  {k:24s}: {v}")

    model = CatBoostClassifier(**params)
    t0 = time.time()
    model.fit(train_pool, eval_set=val_pool)
    log.info(f"training finished in {time.time()-t0:.1f}s")

    # quick sanity metrics on val
    y_pred = model.predict(val_pool).flatten().astype(int)
    acc  = accuracy_score(y_val, y_pred)
    f1   = f1_score(y_val, y_pred, average="macro")
    log.info(f"VAL accuracy = {acc:.4f}")
    log.info(f"VAL macro-F1 = {f1:.4f}")
    log.info("\n" + classification_report(
        y_val, y_pred, target_names=classes, digits=3, zero_division=0))

    return model, classes, feature_cols, {"val_accuracy": acc, "val_macro_f1": f1}


def save_artifacts(model: CatBoostClassifier, classes, feature_cols, metrics):
    cfg.MODEL_DIR.mkdir(parents=True, exist_ok=True)

    model.save_model(str(cfg.MODEL_FILE))
    log.info(f"  saved model     -> {cfg.MODEL_FILE}")

    cfg.LABEL_ENCODER_FILE.write_text(json.dumps(
        {"classes": classes, "feature_set": cfg.FEATURE_SET}, indent=2
    ))
    log.info(f"  saved encoder   -> {cfg.LABEL_ENCODER_FILE}")

    cfg.FEATURE_LIST_FILE.write_text(json.dumps(feature_cols, indent=2))
    log.info(f"  saved features  -> {cfg.FEATURE_LIST_FILE}")

    (cfg.MODEL_DIR / "training_metrics.json").write_text(json.dumps(metrics, indent=2))
    log.info(f"  saved metrics   -> {cfg.MODEL_DIR / 'training_metrics.json'}")


def export_split_features(train_df, val_df):
    """Persist the engineered features for downstream auditing/reuse."""
    cfg.FEATURES_DIR.mkdir(parents=True, exist_ok=True)
    train_df.to_csv(cfg.TRAIN_FEATURES_CSV, index=False)
    val_df.to_csv(cfg.VAL_FEATURES_CSV, index=False)
    log.info(f"  saved train features -> {cfg.TRAIN_FEATURES_CSV}")
    log.info(f"  saved val   features -> {cfg.VAL_FEATURES_CSV}")


# ============================================================================
# main
# ============================================================================

def main():
    cfg.banner("TRAIN CATBOOST PERSONA CLASSIFIER")

    df = load_training_data()
    train_df, val_df = split_users(df, cfg.VAL_FRACTION, seed=cfg.RANDOM_SEED_TRAIN)
    log.info(f"  train: {len(train_df)}  val: {len(val_df)}")

    export_split_features(train_df, val_df)

    model, classes, feature_cols, metrics = train(train_df, val_df)
    save_artifacts(model, classes, feature_cols, metrics)

    log.info("DONE.")


if __name__ == "__main__":
    main()
