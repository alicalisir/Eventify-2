"""
Feature Engineering — canonical extractor used by BOTH training and inference.
==============================================================================

Why this module is separate from the simulator's `data_export._generate_ml_features`:
  - The simulator's exporter reads the live agent objects (in-memory). That code
    path doesn't exist when you have only raw CSVs (real-world telemetry).
  - This module takes ONLY raw event DataFrames (gps, apps, screen, [episode])
    and returns a per-user feature row. The same code therefore runs unchanged
    on:
       1. synthetic data exported by simulate.py
       2. real-world telemetry shipped from devices

If you ever change the feature definitions, change them HERE and only HERE.

Two feature sets are supported:
  * `telemetry`     — derivable from gps + apps + screen alone (production)
  * `with_episodes` — adds episode_log shares (synthetic-only upper bound)
"""

from __future__ import annotations

from typing import List, Optional, Iterable
from pathlib import Path
import math

import numpy as np
import pandas as pd

# --------------------------------------------------------------- constants ---

APP_CATEGORIES = [
    "social", "messaging", "video", "short_video", "music", "streaming",
    "gaming", "productivity", "browser", "navigation", "fitness",
    "education", "reading", "news", "shopping", "finance", "photo", "ride_share",
    "dating",
]

EPISODE_TYPES = [
    "SLEEP", "NIGHT_BROWSING", "MORNING_ROUTINE",
    "COMMUTE_TO_WORK", "COMMUTE_HOME", "WORK_DAY", "STUDY_BLOCK",
    "GO_TO_CAFE", "SOCIALIZE", "EXERCISE",
    "RELAX_AT_HOME", "CONTENT_BINGE", "GAMING_MARATHON",
    "ERRAND_CHAIN", "EXPLORATION_DAY",
]

MOVEMENT_STATES = ["stationary", "walking", "cycling", "transit", "vehicle"]

# Earth radius in meters
_R_EARTH = 6_371_000.0


def _haversine_m(lat1, lon1, lat2, lon2) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * _R_EARTH * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _radius_of_gyration(lats: np.ndarray, lons: np.ndarray) -> float:
    if len(lats) == 0:
        return 0.0
    lat_c, lon_c = float(np.mean(lats)), float(np.mean(lons))
    d = np.array([_haversine_m(lat_c, lon_c, la, lo) for la, lo in zip(lats, lons)])
    return float(np.sqrt(np.mean(d * d)))


def _movement_state_from_speed(speed_mps: float) -> str:
    if speed_mps < 0.5:  return "stationary"
    if speed_mps < 2.0:  return "walking"
    if speed_mps < 5.0:  return "cycling"
    if speed_mps < 20.0: return "transit"
    return "vehicle"


def _enrich_gps_with_derived_speed(gps_df: pd.DataFrame) -> pd.DataFrame:
    """When device reports speed_mps == 0 for all pings, derive speed from
    consecutive GPS coordinates. Skips gaps > 15 minutes to avoid false highs.
    Also re-derives movement_state when it is uniformly 'stationary'."""
    if gps_df.empty or len(gps_df) < 2:
        return gps_df

    # Only enrich when device speed is effectively zero
    if "speed_mps" in gps_df.columns and float(gps_df["speed_mps"].max()) >= 0.5:
        return gps_df

    df = gps_df.copy()
    df["_ts"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
    df = df.sort_values("_ts").reset_index(drop=True)

    derived = [0.0]
    for i in range(1, len(df)):
        dt_s = (df.at[i, "_ts"] - df.at[i - 1, "_ts"]).total_seconds()
        # Ignore gaps > 15 min — position jump doesn't imply motion
        if dt_s <= 0 or dt_s > 900:
            derived.append(0.0)
            continue
        dist_m = _haversine_m(
            float(df.at[i - 1, "latitude"]), float(df.at[i - 1, "longitude"]),
            float(df.at[i, "latitude"]),     float(df.at[i, "longitude"]),
        )
        derived.append(min(dist_m / dt_s, 50.0))  # cap at 180 km/h

    df["speed_mps"] = derived
    df = df.drop(columns=["_ts"])

    # Re-derive movement_state when uniformly stationary
    if "movement_state" not in df.columns or (df["movement_state"] == "stationary").all():
        df["movement_state"] = df["speed_mps"].apply(_movement_state_from_speed)

    return df


# ============================================================================
# 1. PER-USER EXTRACTOR
# ============================================================================

def extract_user_features(
    user_id,
    gps_user: pd.DataFrame,
    apps_user: pd.DataFrame,
    screen_user: pd.DataFrame,
    episode_user: Optional[pd.DataFrame] = None,
) -> dict:
    """Compute the full feature dict for one user given their event slices."""

    feat = {"user_id": user_id}

    # Enrich GPS with derived speed/movement when device reports zero velocity
    if not gps_user.empty:
        gps_user = _enrich_gps_with_derived_speed(gps_user)

    # ---------------------------------------------------- app/session feats
    if not apps_user.empty:
        total_min = float(apps_user["duration_min"].sum())
        feat["total_screen_min"]  = total_min
        feat["mean_session_min"]  = float(apps_user["duration_min"].mean())
        feat["median_session_min"] = float(apps_user["duration_min"].median())
        feat["num_sessions"]      = int(len(apps_user))
        feat["unique_apps"]       = int(apps_user["app"].nunique())

        # foreground/background ratio (added in latest schema)
        if "state" in apps_user.columns:
            fg = (apps_user["state"] == "foreground").sum()
            feat["foreground_ratio"] = float(fg / max(1, len(apps_user)))
        else:
            feat["foreground_ratio"] = 1.0

        # category share (out of total session minutes)
        cat = apps_user.groupby("category")["duration_min"].sum()
        cat_share = (cat / cat.sum()).to_dict() if cat.sum() > 0 else {}
        for c in APP_CATEGORIES:
            feat[f"share_cat_{c}"] = float(cat_share.get(c, 0.0))

        # hour-of-day distribution
        hour_total = apps_user.groupby("hour")["duration_min"].sum()
        hour_share = (hour_total / hour_total.sum()).to_dict() if hour_total.sum() > 0 else {}
        for h in range(24):
            feat[f"hour_share_{h:02d}"] = float(hour_share.get(h, 0.0))

        # circadian summaries (compact)
        feat["share_hours_00_06"] = sum(feat[f"hour_share_{h:02d}"] for h in range(0, 6))
        feat["share_hours_06_12"] = sum(feat[f"hour_share_{h:02d}"] for h in range(6, 12))
        feat["share_hours_12_18"] = sum(feat[f"hour_share_{h:02d}"] for h in range(12, 18))
        feat["share_hours_18_24"] = sum(feat[f"hour_share_{h:02d}"] for h in range(18, 24))

        # weekday vs weekend
        wd = apps_user[apps_user["weekday"] < 5]["duration_min"].sum()
        we = apps_user[apps_user["weekday"] >= 5]["duration_min"].sum()
        feat["weekend_ratio"] = float(we / max(1.0, wd + we))

        # session duration percentiles
        feat["session_p90_min"] = float(apps_user["duration_min"].quantile(0.9))
        feat["session_p10_min"] = float(apps_user["duration_min"].quantile(0.1))
    else:
        # empty user — still emit zeros so column set is stable
        feat["total_screen_min"] = 0.0
        feat["mean_session_min"] = 0.0
        feat["median_session_min"] = 0.0
        feat["num_sessions"] = 0
        feat["unique_apps"] = 0
        feat["foreground_ratio"] = 0.0
        for c in APP_CATEGORIES:
            feat[f"share_cat_{c}"] = 0.0
        for h in range(24):
            feat[f"hour_share_{h:02d}"] = 0.0
        feat["share_hours_00_06"] = 0.0
        feat["share_hours_06_12"] = 0.0
        feat["share_hours_12_18"] = 0.0
        feat["share_hours_18_24"] = 0.0
        feat["weekend_ratio"] = 0.0
        feat["session_p90_min"] = 0.0
        feat["session_p10_min"] = 0.0

    # ---------------------------------------------------- mobility feats
    if not gps_user.empty:
        gps_sorted = gps_user.sort_values("timestamp")
        lats = gps_sorted["latitude"].to_numpy()
        lons = gps_sorted["longitude"].to_numpy()
        total_d = 0.0
        for i in range(1, len(lats)):
            total_d += _haversine_m(lats[i-1], lons[i-1], lats[i], lons[i])
        feat["total_distance_m"]  = float(total_d)
        feat["mobility_radius_m"] = _radius_of_gyration(lats, lons)
        feat["unique_cells_100m"] = int(
            len(gps_sorted[["latitude", "longitude"]].round(3).drop_duplicates())
        )

        # speed / movement_state mix (newer schema)
        if "speed_mps" in gps_user.columns:
            feat["speed_p50_mps"] = float(gps_user["speed_mps"].quantile(0.5))
            feat["speed_p90_mps"] = float(gps_user["speed_mps"].quantile(0.9))
            feat["speed_max_mps"] = float(gps_user["speed_mps"].max())
        else:
            feat["speed_p50_mps"] = feat["speed_p90_mps"] = feat["speed_max_mps"] = 0.0

        if "movement_state" in gps_user.columns:
            ms = gps_user["movement_state"].value_counts(normalize=True).to_dict()
            for s in MOVEMENT_STATES:
                feat[f"movstate_share_{s}"] = float(ms.get(s, 0.0))
        else:
            for s in MOVEMENT_STATES:
                feat[f"movstate_share_{s}"] = 0.0

        if "dwell_time_s" in gps_user.columns:
            feat["dwell_p90_s"] = float(gps_user["dwell_time_s"].quantile(0.9))
            feat["dwell_mean_s"] = float(gps_user["dwell_time_s"].mean())
        else:
            feat["dwell_p90_s"] = feat["dwell_mean_s"] = 0.0
    else:
        feat["total_distance_m"]  = 0.0
        feat["mobility_radius_m"] = 0.0
        feat["unique_cells_100m"] = 0
        feat["speed_p50_mps"] = feat["speed_p90_mps"] = feat["speed_max_mps"] = 0.0
        for s in MOVEMENT_STATES:
            feat[f"movstate_share_{s}"] = 0.0
        feat["dwell_p90_s"] = feat["dwell_mean_s"] = 0.0

    # ---------------------------------------------------- screen feats
    if not screen_user.empty:
        ev = screen_user["event_type"].value_counts().to_dict()
        feat["unlocks_total"]      = int(ev.get("unlock", 0))
        feat["screen_on_total"]    = int(ev.get("on", 0))
        feat["screen_off_total"]   = int(ev.get("off", 0))
        feat["notifications_total"] = int(ev.get("notification", 0))
        # notification per-day (will be normalized by N_DAYS later if known)
        feat["notif_per_unlock"] = float(
            feat["notifications_total"] / max(1, feat["unlocks_total"])
        )
    else:
        feat["unlocks_total"] = 0
        feat["screen_on_total"] = 0
        feat["screen_off_total"] = 0
        feat["notifications_total"] = 0
        feat["notif_per_unlock"] = 0.0

    # ---------------------------------------------------- episode feats (optional)
    if episode_user is not None and not episode_user.empty:
        ep_share = episode_user["episode_name"].value_counts(normalize=True).to_dict()
        for ep in EPISODE_TYPES:
            feat[f"ep_share_{ep}"] = float(ep_share.get(ep, 0.0))
        feat["episodes_per_day"] = float(len(episode_user) / max(1, episode_user["timestamp"].dt.date.nunique()))
    else:
        for ep in EPISODE_TYPES:
            feat[f"ep_share_{ep}"] = 0.0
        feat["episodes_per_day"] = 0.0

    return feat


# ============================================================================
# 2. DATAFRAME-LEVEL EXTRACTOR
# ============================================================================

def build_feature_matrix(
    gps: pd.DataFrame,
    apps: pd.DataFrame,
    screen: pd.DataFrame,
    episode: Optional[pd.DataFrame] = None,
    user_ids: Optional[Iterable] = None,
    include_episode_features: bool = False,
) -> pd.DataFrame:
    """Compute features for every user in the input DataFrames.

    Args:
        gps, apps, screen, episode: raw event DataFrames
        user_ids: optional iterable of user_ids to include (default: all)
        include_episode_features: pass through episode_log to per-user extractor

    Returns:
        DataFrame with one row per user.
    """
    # Normalize timestamps & extract derived columns once
    def _is_datetime(series):
        try:
            return np.issubdtype(series.dtype, np.datetime64)
        except TypeError:
            return False

    if not apps.empty:
        if not _is_datetime(apps["timestamp"]):
            apps = apps.copy()
            apps["timestamp"] = pd.to_datetime(apps["timestamp"])
        apps["hour"] = apps["timestamp"].dt.hour
        apps["weekday"] = apps["timestamp"].dt.weekday

    if not gps.empty and not _is_datetime(gps["timestamp"]):
        gps = gps.copy()
        gps["timestamp"] = pd.to_datetime(gps["timestamp"])

    if not screen.empty and not _is_datetime(screen["timestamp"]):
        screen = screen.copy()
        screen["timestamp"] = pd.to_datetime(screen["timestamp"])

    if episode is not None and not episode.empty:
        if not _is_datetime(episode["timestamp"]):
            episode = episode.copy()
            episode["timestamp"] = pd.to_datetime(episode["timestamp"])

    if user_ids is None:
        ids = sorted(pd.unique(pd.concat([
            apps["user_id"] if not apps.empty else pd.Series(dtype=int),
            gps["user_id"]  if not gps.empty  else pd.Series(dtype=int),
        ])))
    else:
        ids = list(user_ids)

    # group once for speed
    gps_g = gps.groupby("user_id") if not gps.empty else {}
    apps_g = apps.groupby("user_id") if not apps.empty else {}
    screen_g = screen.groupby("user_id") if not screen.empty else {}
    eps_g = episode.groupby("user_id") if (episode is not None and not episode.empty) else {}

    rows: List[dict] = []
    for uid in ids:
        gps_u = gps_g.get_group(uid) if uid in (gps_g.groups if hasattr(gps_g, "groups") else {}) else pd.DataFrame()
        apps_u = apps_g.get_group(uid) if uid in (apps_g.groups if hasattr(apps_g, "groups") else {}) else pd.DataFrame()
        screen_u = screen_g.get_group(uid) if uid in (screen_g.groups if hasattr(screen_g, "groups") else {}) else pd.DataFrame()
        eps_u = (eps_g.get_group(uid)
                 if (include_episode_features and uid in (eps_g.groups if hasattr(eps_g, "groups") else {}))
                 else None)

        rows.append(extract_user_features(uid, gps_u, apps_u, screen_u, eps_u))

    df = pd.DataFrame(rows)
    return df


# ============================================================================
# 3. CSV-LEVEL ENTRY POINT
# ============================================================================

def features_from_directory(
    directory: Path,
    include_episode_features: bool = False,
) -> pd.DataFrame:
    """Read raw CSVs from a directory and produce the feature matrix.

    Expected files:
        gps_pings.csv, app_sessions.csv, screen_events.csv, [episode_log.csv]

    Returns a feature matrix with `user_id`. `persona` is NOT joined here — it
    lives in `users.csv` and is added by the caller (training pipeline only).
    """
    directory = Path(directory)
    gps     = pd.read_csv(directory / "gps_pings.csv")     if (directory / "gps_pings.csv").exists()    else pd.DataFrame()
    apps    = pd.read_csv(directory / "app_sessions.csv")  if (directory / "app_sessions.csv").exists() else pd.DataFrame()
    screen  = pd.read_csv(directory / "screen_events.csv") if (directory / "screen_events.csv").exists() else pd.DataFrame()
    episode = pd.read_csv(directory / "episode_log.csv")   if (directory / "episode_log.csv").exists()  else None

    return build_feature_matrix(
        gps, apps, screen, episode,
        include_episode_features=include_episode_features,
    )


def attach_persona_labels(features: pd.DataFrame, users_csv: Path) -> pd.DataFrame:
    """Join persona labels from users.csv. Training only."""
    users = pd.read_csv(users_csv)[["user_id", "persona"]]
    return features.merge(users, on="user_id", how="left")


# ============================================================================
# 4. FEATURE COLUMN UTILITIES
# ============================================================================

def feature_columns(df: pd.DataFrame) -> List[str]:
    """Return the ordered list of feature column names (drop labels/ids)."""
    drop = {"user_id", "persona", "persona_name"}
    return [c for c in df.columns if c not in drop]
