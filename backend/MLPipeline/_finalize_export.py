"""
One-shot helper: re-build daily_summary.csv, ml_features.csv, hourly_activity.csv
from the raw event CSVs already on disk. Used after the heavy 1000-user run when
the in-process aggregation was killed.

Usage:
    python _finalize_export.py train_raw
    python _finalize_export.py test_raw
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

import pipeline_config as cfg

# vectorized haversine (duplicate of the one in data_export so we don't need
# the simulator at all for this stage).
def _hav(lat1, lon1, lat2, lon2):
    R = 6_371_000.0
    p1 = np.radians(lat1); p2 = np.radians(lat2)
    dphi = p2 - p1
    dlmb = np.radians(lon2 - lon1)
    a = np.sin(dphi/2)**2 + np.cos(p1) * np.cos(p2) * np.sin(dlmb/2)**2
    return 2 * R * np.arcsin(np.sqrt(a))


def daily_summary(out_dir: Path):
    print("[daily_summary] reading raw csvs ...")
    gps = pd.read_csv(out_dir / "gps_pings.csv", parse_dates=["timestamp"])
    apps = pd.read_csv(out_dir / "app_sessions.csv", parse_dates=["timestamp"])
    screen = pd.read_csv(out_dir / "screen_events.csv", parse_dates=["timestamp"])
    eps = pd.read_csv(out_dir / "episode_log.csv", parse_dates=["timestamp"]) \
          if (out_dir / "episode_log.csv").exists() else pd.DataFrame()

    gps["date"] = gps["timestamp"].dt.date
    apps["date"] = apps["timestamp"].dt.date
    screen["date"] = screen["timestamp"].dt.date
    if not eps.empty:
        eps["date"] = eps["timestamp"].dt.date

    print("[daily_summary] computing distances ...")
    gps = gps.sort_values(["user_id", "timestamp"]).reset_index(drop=True)
    gps["lat_prev"] = gps.groupby("user_id")["latitude"].shift()
    gps["lon_prev"] = gps.groupby("user_id")["longitude"].shift()
    mask = gps["lat_prev"].notna()
    gps["seg_m"] = 0.0
    gps.loc[mask, "seg_m"] = _hav(
        gps.loc[mask, "lat_prev"].to_numpy(), gps.loc[mask, "lon_prev"].to_numpy(),
        gps.loc[mask, "latitude"].to_numpy(), gps.loc[mask, "longitude"].to_numpy(),
    )

    base = (gps.groupby(["user_id", "date"])["seg_m"].sum()
              .round(1).rename("total_distance_m").reset_index())

    cells = (gps.assign(cell_lat=gps["latitude"].round(3),
                        cell_lon=gps["longitude"].round(3))
             .drop_duplicates(["user_id", "date", "cell_lat", "cell_lon"])
             .groupby(["user_id", "date"]).size()
             .rename("num_locations_unique").reset_index())

    app_agg = apps.groupby(["user_id", "date"])["duration_min"].agg(
        total_screen_time_min="sum", num_app_sessions="size").reset_index()
    app_agg["total_screen_time_min"] = app_agg["total_screen_time_min"].round(1)

    top_app = (apps.groupby(["user_id", "date", "app"])["duration_min"].sum().reset_index()
               .sort_values("duration_min", ascending=False)
               .drop_duplicates(["user_id", "date"])
               .rename(columns={"app": "top_app"})[["user_id", "date", "top_app"]])

    top_cat = (apps.groupby(["user_id", "date", "category"])["duration_min"].sum().reset_index()
               .sort_values("duration_min", ascending=False)
               .drop_duplicates(["user_id", "date"])
               .rename(columns={"category": "top_category"})[["user_id", "date", "top_category"]])

    unlocks = (screen[screen["event_type"] == "unlock"]
               .groupby(["user_id", "date"]).size()
               .rename("num_screen_unlocks").reset_index())

    out = base.merge(cells, on=["user_id", "date"], how="left") \
              .merge(app_agg, on=["user_id", "date"], how="left") \
              .merge(top_app, on=["user_id", "date"], how="left") \
              .merge(top_cat, on=["user_id", "date"], how="left") \
              .merge(unlocks, on=["user_id", "date"], how="left")

    if not eps.empty:
        ep_count = eps.groupby(["user_id", "date"]).size().rename("num_episodes").reset_index()
        top_ep = (eps.groupby(["user_id", "date", "episode_name"]).size().reset_index(name="n")
                  .sort_values("n", ascending=False)
                  .drop_duplicates(["user_id", "date"])
                  .rename(columns={"episode_name": "top_episode"})
                  [["user_id", "date", "top_episode"]])
        out = out.merge(ep_count, on=["user_id", "date"], how="left") \
                 .merge(top_ep, on=["user_id", "date"], how="left")

    out = out.fillna({
        "num_locations_unique": 0, "total_screen_time_min": 0.0,
        "num_app_sessions": 0, "num_screen_unlocks": 0, "num_episodes": 0,
        "top_app": "", "top_category": "", "top_episode": "",
    })
    for c in ("num_locations_unique","num_app_sessions","num_screen_unlocks","num_episodes"):
        out[c] = out[c].astype(int)
    out.to_csv(out_dir / "daily_summary.csv", index=False)
    print(f"[daily_summary] -> {len(out):,} rows")


def ml_features(out_dir: Path):
    """Reuse feature_engineering.features_from_directory + attach personas."""
    import feature_engineering as fe
    print("[ml_features] building feature matrix ...")
    feats = fe.features_from_directory(out_dir, include_episode_features=True)
    feats = fe.attach_persona_labels(feats, out_dir / "users.csv")
    feats.to_csv(out_dir / "ml_features.csv", index=False)
    print(f"[ml_features] -> {feats.shape[0]:,} rows × {feats.shape[1]} cols")


def hourly_activity(out_dir: Path):
    print("[hourly_activity] building ...")
    apps = pd.read_csv(out_dir / "app_sessions.csv", parse_dates=["timestamp"])
    apps["date"] = apps["timestamp"].dt.date
    apps["hour"] = apps["timestamp"].dt.hour
    g = (apps.groupby(["user_id", "date", "hour"]).agg(
            total_min=("duration_min", "sum"),
            num_sessions=("duration_min", "size"),
            top_category=("category", lambda s: s.value_counts().index[0]),
            top_app=("app", lambda s: s.value_counts().index[0]),
        ).reset_index())
    g.to_csv(out_dir / "hourly_activity.csv", index=False)
    print(f"[hourly_activity] -> {len(g):,} rows")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "train_raw"
    out_dir = cfg.OUTPUTS / target
    print(f"finalizing exports in: {out_dir}")
    t = time.time()
    daily_summary(out_dir)
    print(f"  daily_summary: {time.time()-t:.1f}s"); t = time.time()
    ml_features(out_dir)
    print(f"  ml_features:   {time.time()-t:.1f}s"); t = time.time()
    hourly_activity(out_dir)
    print(f"  hourly_activity: {time.time()-t:.1f}s")
    print("done.")


if __name__ == "__main__":
    main()
