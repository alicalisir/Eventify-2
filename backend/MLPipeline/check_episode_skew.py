"""
Episode Feature Skew Check — Step 6

Compares GT episode labels (from episode_log.csv, written by the simulator)
against the rule-based approximation (compute_episode_shares from episodes.py)
for a sample of training users.

Findings inform whether to retrain with FEATURE_SET=with_episodes.

Run:
    python check_episode_skew.py
"""

import sys
from pathlib import Path
import random
import numpy as np
import pandas as pd

# Allow importing the production episodes module
API_DIR = Path(__file__).parent.parent / "api"
sys.path.insert(0, str(API_DIR))
from episodes import compute_episode_shares, EPISODE_TYPES  # noqa: E402

DATA_DIR  = Path(__file__).parent / "outputs" / "train_raw"
OUT_DIR   = Path(__file__).parent / "outputs" / "reports"
OUT_DIR.mkdir(parents=True, exist_ok=True)

N_SAMPLE  = 50   # users to compare
RANDOM_SEED = 42

EP_COLS = [f"ep_share_{ep}" for ep in EPISODE_TYPES]

# ── Load raw data ─────────────────────────────────────────────────────────────
print("Loading raw data...")
gps_all    = pd.read_csv(DATA_DIR / "gps_pings.csv")
apps_all   = pd.read_csv(DATA_DIR / "app_sessions.csv")
screen_all = pd.read_csv(DATA_DIR / "screen_events.csv")
ep_log     = pd.read_csv(DATA_DIR / "episode_log.csv")
users      = pd.read_csv(DATA_DIR / "users.csv", usecols=["user_id", "persona"])

# ── Sample users ──────────────────────────────────────────────────────────────
random.seed(RANDOM_SEED)
all_uids = users["user_id"].tolist()
sample_uids = random.sample(all_uids, min(N_SAMPLE, len(all_uids)))

print(f"Comparing GT vs rule-based episode shares for {len(sample_uids)} users...")

rows = []
for uid in sample_uids:
    gps_u    = gps_all[gps_all["user_id"]    == uid].copy()
    apps_u   = apps_all[apps_all["user_id"]  == uid].copy()
    screen_u = screen_all[screen_all["user_id"] == uid].copy()
    ep_u     = ep_log[ep_log["user_id"]      == uid].copy()

    persona = users.loc[users["user_id"] == uid, "persona"].iloc[0]

    # Ground truth: from simulator episode_log
    if not ep_u.empty:
        ep_counts = ep_u["episode_name"].value_counts(normalize=True).to_dict()
        gt = {ep: float(ep_counts.get(ep, 0.0)) for ep in EPISODE_TYPES}
        n_days_gt = max(1, pd.to_datetime(ep_u["timestamp"]).dt.date.nunique())
        gt_epd = len(ep_u) / n_days_gt
    else:
        gt = {ep: 0.0 for ep in EPISODE_TYPES}
        gt_epd = 0.0

    # Rule-based: production approximation
    try:
        rb = compute_episode_shares(gps_u, apps_u, screen_u)
    except Exception as exc:
        print(f"  [WARN] user {uid}: {exc}")
        rb = {ep: 0.0 for ep in EPISODE_TYPES}
        rb["episodes_per_day"] = 0.0

    # Cosine similarity between the two 15-dim share vectors
    gt_vec = np.array([gt[ep]         for ep in EPISODE_TYPES])
    rb_vec = np.array([rb.get(f"ep_share_{ep}", 0.0) for ep in EPISODE_TYPES])
    denom  = (np.linalg.norm(gt_vec) * np.linalg.norm(rb_vec))
    cos_sim = float(np.dot(gt_vec, rb_vec) / denom) if denom > 1e-9 else 0.0

    # Mean absolute error across shares
    mae = float(np.mean(np.abs(gt_vec - rb_vec)))

    rows.append({
        "user_id":   uid,
        "persona":   persona,
        "cosine_sim": round(cos_sim, 3),
        "mae":        round(mae, 4),
        "gt_epd":     round(gt_epd, 2),
        "rb_epd":     round(rb.get("episodes_per_day", 0.0), 2),
        "rb_all_zero": int(rb_vec.sum() < 1e-9),
    })

df = pd.DataFrame(rows)

print("\n=== Overall Stats ===")
print(f"  Mean cosine similarity:  {df['cosine_sim'].mean():.3f}")
print(f"  Median cosine similarity:{df['cosine_sim'].median():.3f}")
print(f"  Mean MAE (share diff):   {df['mae'].mean():.4f}")
print(f"  Users with all-zero RB:  {df['rb_all_zero'].sum()} / {len(df)}")

print("\n=== Per-Persona Cosine Similarity ===")
persona_stats = df.groupby("persona")[["cosine_sim", "mae"]].mean().round(3)
print(persona_stats.to_string())

# Save per-user results
out_csv = OUT_DIR / "episode_skew_check.csv"
df.to_csv(out_csv, index=False)
print(f"\nSaved per-user results: {out_csv}")

# Decision guidance
mean_cos = df["cosine_sim"].mean()
all_zero_frac = df["rb_all_zero"].mean()
print("\n=== Recommendation ===")
if all_zero_frac > 0.5:
    print("  > >50% of rule-based outputs are all-zero → compute_episode_shares")
    print("    has insufficient data signal. Keep FEATURE_SET=telemetry.")
    print("    FIX: Remove feat.update(ep_feats) in main.py (dead code).")
elif mean_cos >= 0.60:
    print(f"  > Mean cosine sim = {mean_cos:.3f} — rule-based approximation is")
    print("    reasonably aligned with GT labels.")
    print("    FIX: Retrain with FEATURE_SET=with_episodes so model actually")
    print("    uses episode features. Production compute_episode_shares() serves")
    print("    as a valid approximation bridge.")
else:
    print(f"  > Mean cosine sim = {mean_cos:.3f} — moderate alignment.")
    print("    OPTION A: Retrain with with_episodes (accept known domain shift).")
    print("    OPTION B: Remove feat.update(ep_feats) and keep telemetry mode.")
    print("    For thesis: OPTION A is more academically interesting to document.")
