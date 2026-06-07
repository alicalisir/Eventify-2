"""
Rule-based episode detection — production counterpart of the simulator.

During training the simulator writes 15 episode types (SLEEP, WORK_DAY, ...)
as ground-truth labels; in production no such labels exist. This module splits
raw user data into 30-minute windows, scores each window against episode
signatures, assigns the best-matching episode, and returns ep_share_*
percentages.

References simulation/episodic.py for each episode's characteristic dominant
app category, time range, location requirement, and movement profile. Those
signatures are matched here against observable signals.

This version is intentionally simple. Once real-world data is labelled, it will
be replaced with a supervised model.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

EPISODE_TYPES = [
    "SLEEP", "NIGHT_BROWSING", "MORNING_ROUTINE",
    "COMMUTE_TO_WORK", "COMMUTE_HOME", "WORK_DAY", "STUDY_BLOCK",
    "GO_TO_CAFE", "SOCIALIZE", "EXERCISE",
    "RELAX_AT_HOME", "CONTENT_BINGE", "GAMING_MARATHON",
    "ERRAND_CHAIN", "EXPLORATION_DAY",
]

WINDOW_MINUTES = 30
WINDOW_FREQ = f"{WINDOW_MINUTES}min"
HOME_CELL_PRECISION = 3   # round(lat, 3) ≈ 100 m grid


# =============================================================================
# 1. HOME / WORK CELL DETECTION
# =============================================================================

def _detect_anchor_cells(gps: pd.DataFrame) -> Tuple[Optional[tuple], Optional[tuple]]:
    """Identify the two most-visited GPS cells as home and work.

    - Home: most frequent cell during 00:00-07:00 (sleep hours -> likely home)
    - Work: most frequent cell on weekdays 09:00-17:00 (if different from home)

    Returns (None, None) when data is insufficient; home/work-dependent rules
    are disabled in that case.
    """
    if gps.empty or len(gps) < 20:
        return None, None

    g = gps.copy()
    g["ts"] = pd.to_datetime(g["timestamp"], utc=True, errors="coerce")
    g = g.dropna(subset=["ts", "latitude", "longitude"])
    if g.empty:
        return None, None

    g["cell"] = list(zip(
        g["latitude"].round(HOME_CELL_PRECISION),
        g["longitude"].round(HOME_CELL_PRECISION),
    ))
    g["hour"] = g["ts"].dt.hour
    g["weekday"] = g["ts"].dt.weekday

    night = g[(g["hour"] < 7) | (g["hour"] >= 23)]
    home_cell = night["cell"].mode().iloc[0] if not night.empty else g["cell"].mode().iloc[0]

    work_window = g[(g["weekday"] < 5) & (g["hour"] >= 9) & (g["hour"] < 17)]
    work_window = work_window[work_window["cell"] != home_cell]
    work_cell = work_window["cell"].mode().iloc[0] if not work_window.empty else None

    return home_cell, work_cell


def _cell_of(lat: float, lon: float) -> tuple:
    return (round(lat, HOME_CELL_PRECISION), round(lon, HOME_CELL_PRECISION))


# =============================================================================
# 2. PER-WINDOW FEATURE EXTRACTION
# =============================================================================

def _build_windows(
    gps: pd.DataFrame,
    apps: pd.DataFrame,
    screen: pd.DataFrame,
    tz_offset: int = 0,
) -> pd.DataFrame:
    """Divide the full time range into 30-min windows and compute per-window summaries."""

    # Determine the time range to scan
    stamps = []
    for df, col in [(gps, "timestamp"), (apps, "timestamp"), (screen, "timestamp")]:
        if not df.empty and col in df.columns:
            ts = pd.to_datetime(df[col], utc=True, errors="coerce").dropna()
            if not ts.empty:
                stamps.append(ts)
    if not stamps:
        return pd.DataFrame()

    all_ts = pd.concat(stamps)
    t_min = all_ts.min().floor(WINDOW_FREQ)
    t_max = all_ts.max().ceil(WINDOW_FREQ)

    window_starts = pd.date_range(t_min, t_max, freq=WINDOW_FREQ, tz="UTC")
    if len(window_starts) < 2:
        return pd.DataFrame()

    # Pre-bin all data frames
    apps_w = apps.copy() if not apps.empty else pd.DataFrame()
    if not apps_w.empty:
        apps_w["ts"] = pd.to_datetime(apps_w["timestamp"], utc=True, errors="coerce")
        apps_w = apps_w.dropna(subset=["ts"])
        apps_w["bin"] = apps_w["ts"].dt.floor(WINDOW_FREQ)

    gps_w = gps.copy() if not gps.empty else pd.DataFrame()
    if not gps_w.empty:
        gps_w["ts"] = pd.to_datetime(gps_w["timestamp"], utc=True, errors="coerce")
        gps_w = gps_w.dropna(subset=["ts"])
        gps_w["bin"] = gps_w["ts"].dt.floor(WINDOW_FREQ)
        gps_w["cell"] = list(zip(
            gps_w["latitude"].round(HOME_CELL_PRECISION),
            gps_w["longitude"].round(HOME_CELL_PRECISION),
        ))

    scr_w = screen.copy() if not screen.empty else pd.DataFrame()
    if not scr_w.empty:
        scr_w["ts"] = pd.to_datetime(scr_w["timestamp"], utc=True, errors="coerce")
        scr_w = scr_w.dropna(subset=["ts"])
        scr_w["bin"] = scr_w["ts"].dt.floor(WINDOW_FREQ)

    rows = []
    for w_start in window_starts[:-1]:
        local_hour = (w_start.hour + tz_offset) % 24
        local_weekday = w_start.weekday() if tz_offset == 0 else (
            (w_start + pd.Timedelta(hours=tz_offset)).weekday()
        )
        rec = {
            "bin": w_start,
            "hour": local_hour + w_start.minute / 60.0,
            "weekday": local_weekday,
            "is_weekend": local_weekday >= 5,
        }

        # ----- app activity
        if not apps_w.empty:
            slc = apps_w[apps_w["bin"] == w_start]
            if not slc.empty:
                cat_min = slc.groupby("category")["duration_min"].sum().to_dict()
                rec["app_total_min"] = float(sum(cat_min.values()))
                rec["app_cat_min"] = cat_min
                top_cat = max(cat_min, key=cat_min.get) if cat_min else None
                rec["top_cat"] = top_cat
                rec["top_cat_share"] = (cat_min[top_cat] / rec["app_total_min"]) if top_cat and rec["app_total_min"] > 0 else 0.0
            else:
                rec["app_total_min"] = 0.0
                rec["app_cat_min"] = {}
                rec["top_cat"] = None
                rec["top_cat_share"] = 0.0
        else:
            rec["app_total_min"] = 0.0
            rec["app_cat_min"] = {}
            rec["top_cat"] = None
            rec["top_cat_share"] = 0.0

        # ----- GPS / movement
        if not gps_w.empty:
            slc = gps_w[gps_w["bin"] == w_start]
            if not slc.empty:
                rec["gps_count"] = len(slc)
                rec["unique_cells"] = slc["cell"].nunique()
                rec["dominant_cell"] = slc["cell"].mode().iloc[0]
                if "movement_state" in slc.columns:
                    rec["dominant_movement"] = slc["movement_state"].mode().iloc[0]
                    rec["moving_share"] = float((slc["movement_state"] != "stationary").mean())
                else:
                    rec["dominant_movement"] = "stationary"
                    rec["moving_share"] = 0.0
                if "speed_mps" in slc.columns:
                    rec["max_speed"] = float(slc["speed_mps"].max())
                else:
                    rec["max_speed"] = 0.0
            else:
                rec["gps_count"] = 0
                rec["unique_cells"] = 0
                rec["dominant_cell"] = None
                rec["dominant_movement"] = "stationary"
                rec["moving_share"] = 0.0
                rec["max_speed"] = 0.0
        else:
            rec["gps_count"] = 0
            rec["unique_cells"] = 0
            rec["dominant_cell"] = None
            rec["dominant_movement"] = "stationary"
            rec["moving_share"] = 0.0
            rec["max_speed"] = 0.0

        # ----- screen
        if not scr_w.empty:
            slc = scr_w[scr_w["bin"] == w_start]
            if not slc.empty:
                ev = slc["event_type"].value_counts().to_dict()
                rec["scr_on"] = int(ev.get("on", 0))
                rec["scr_off"] = int(ev.get("off", 0))
                rec["scr_unlock"] = int(ev.get("unlock", 0))
            else:
                rec["scr_on"] = rec["scr_off"] = rec["scr_unlock"] = 0
        else:
            rec["scr_on"] = rec["scr_off"] = rec["scr_unlock"] = 0

        rows.append(rec)

    return pd.DataFrame(rows)


# =============================================================================
# 3. EPISODE SCORING (per window)
# =============================================================================

# Dominant app category groups expected for each episode.
# If the window's top_cat is in this set, the "category signature matches".
_EP_CATEGORIES = {
    "SLEEP":            set(),
    "NIGHT_BROWSING":   {"short_video", "social", "video", "messaging"},
    "MORNING_ROUTINE":  {"news", "messaging", "social"},
    "COMMUTE_TO_WORK":  {"navigation", "music", "messaging", "news", "social"},
    "COMMUTE_HOME":     {"navigation", "music", "video", "social"},
    "WORK_DAY":         {"productivity", "browser", "messaging"},
    "STUDY_BLOCK":      {"education", "productivity", "browser", "reading"},
    "GO_TO_CAFE":       {"social", "messaging", "music", "photo"},
    "SOCIALIZE":        {"messaging", "social", "photo"},
    "EXERCISE":         {"fitness", "music"},
    "RELAX_AT_HOME":    {"video", "short_video", "social", "music", "messaging", "reading"},
    "CONTENT_BINGE":    {"streaming", "video", "short_video"},
    "GAMING_MARATHON":  {"gaming"},
    "ERRAND_CHAIN":     {"shopping", "finance", "messaging"},
    "EXPLORATION_DAY":  {"navigation", "photo", "social", "music"},
}


def _is_home(w: dict, home_cell: Optional[tuple]) -> Optional[bool]:
    """True/False/None (None = insufficient data)."""
    if home_cell is None or w["dominant_cell"] is None:
        return None
    return w["dominant_cell"] == home_cell


def _is_work(w: dict, work_cell: Optional[tuple]) -> Optional[bool]:
    if work_cell is None or w["dominant_cell"] is None:
        return None
    return w["dominant_cell"] == work_cell


def _cat_match(w: dict, ep: str) -> float:
    """0-1: does the window's dominant app fall in the episode's signature category group?"""
    cats = _EP_CATEGORIES.get(ep, set())
    if not cats or not w["top_cat"]:
        return 0.0
    if w["top_cat"] in cats:
        return float(w["top_cat_share"])
    return 0.0


def _in_window(h: float, lo: float, hi: float) -> bool:
    """Time-range check; handles ranges that cross midnight."""
    if lo <= hi:
        return lo <= h < hi
    return h >= lo or h < hi


def _score(w: dict, ep: str, home_cell, work_cell) -> float:
    h = w["hour"]
    weekend = w["is_weekend"]
    at_home = _is_home(w, home_cell)
    at_work = _is_work(w, work_cell)
    cat_sig = _cat_match(w, ep)
    moving = w["moving_share"] > 0.4
    no_phone = w["app_total_min"] < 1.0 and w["scr_unlock"] == 0
    has_gps = w["gps_count"] > 0

    # --------------------------------------------------------------- SLEEP
    if ep == "SLEEP":
        if not _in_window(h, 23, 7):
            return 0.0
        s = 60.0 if no_phone else 10.0
        if at_home is True:
            s += 30
        elif at_home is False:
            s -= 30
        if w["moving_share"] > 0.2:
            s -= 40
        return max(0.0, s)

    # ----------------------------------------------------- NIGHT_BROWSING
    if ep == "NIGHT_BROWSING":
        if not _in_window(h, 21.5, 2):
            return 0.0
        if w["app_total_min"] < 2:
            return 0.0
        s = 30 + 50 * cat_sig
        if at_home is True:
            s += 20
        elif at_home is False:
            s -= 30
        if moving:
            s -= 30
        return max(0.0, s)

    # ----------------------------------------------------- MORNING_ROUTINE
    if ep == "MORNING_ROUTINE":
        if not (5 <= h < 10):
            return 0.0
        if at_home is False:
            return 0.0
        s = 30 + 40 * cat_sig
        if at_home is True:
            s += 25
        if w["scr_unlock"] >= 1:
            s += 10
        if moving:
            s -= 30
        return max(0.0, s)

    # ---------------------------------------------------- COMMUTE_TO_WORK
    if ep == "COMMUTE_TO_WORK":
        if weekend or not (6 <= h < 11):
            return 0.0
        if not has_gps:
            return 0.0
        if w["moving_share"] < 0.3 and w["max_speed"] < 2.0:
            return 0.0
        s = 40 + 35 * cat_sig
        if w["dominant_movement"] in ("transit", "vehicle"):
            s += 30
        elif w["dominant_movement"] in ("walking", "cycling"):
            s += 15
        if at_home is True:
            s -= 20  # still at home -> probably hasn't left yet
        return max(0.0, s)

    # -------------------------------------------------------- COMMUTE_HOME
    if ep == "COMMUTE_HOME":
        if weekend or not (16 <= h < 21):
            return 0.0
        if w["moving_share"] < 0.3 and w["max_speed"] < 2.0:
            return 0.0
        s = 40 + 35 * cat_sig
        if w["dominant_movement"] in ("transit", "vehicle"):
            s += 30
        if at_home is True:
            s -= 20
        return max(0.0, s)

    # ---------------------------------------------------------- WORK_DAY
    if ep == "WORK_DAY":
        if weekend or not (9 <= h < 18):
            return 0.0
        if at_home is True:
            return 0.0  # work location must differ from home
        s = 30 + 50 * cat_sig
        if at_work is True:
            s += 40
        if w["moving_share"] < 0.2:
            s += 10
        return max(0.0, s)

    # -------------------------------------------------------- STUDY_BLOCK
    if ep == "STUDY_BLOCK":
        if not (9 <= h < 23):
            return 0.0
        if w["app_total_min"] < 3:
            return 0.0
        s = 20 + 55 * cat_sig
        if moving:
            s -= 30
        return max(0.0, s)

    # --------------------------------------------------------- GO_TO_CAFE
    if ep == "GO_TO_CAFE":
        if not (10 <= h < 23):
            return 0.0
        if w["app_total_min"] < 2:
            return 0.0
        s = 15 + 45 * cat_sig
        # not at home, not at work, and stationary -> likely a third location (cafe etc.)
        if at_home is False and at_work is False and not moving:
            s += 25
        if moving:
            s -= 20
        return max(0.0, s)

    # ---------------------------------------------------------- SOCIALIZE
    if ep == "SOCIALIZE":
        if not (_in_window(h, 12, 26) or h < 2):
            return 0.0
        if w["app_total_min"] < 2:
            return 0.0
        s = 15 + 40 * cat_sig
        if at_home is False and at_work is False:
            s += 25
        if w["is_weekend"]:
            s += 10
        return max(0.0, s)

    # ----------------------------------------------------------- EXERCISE
    if ep == "EXERCISE":
        if not ((5 <= h < 9) or (17 <= h < 21)):
            return 0.0
        s = 0.0
        if w["dominant_movement"] in ("walking", "cycling") and w["max_speed"] > 1.0:
            s += 50
        if w["app_total_min"] > 0 and w["top_cat"] == "fitness":
            s += 50
        elif cat_sig > 0:
            s += 20 * cat_sig
        if w["unique_cells"] >= 3:  # route is changing
            s += 15
        if at_home is True and w["moving_share"] < 0.2:
            return 0.0
        return s

    # ------------------------------------------------------ RELAX_AT_HOME
    if ep == "RELAX_AT_HOME":
        if at_home is False:
            return 0.0
        if not (6 <= h < 24):
            return 0.0
        s = 10 + 35 * cat_sig
        if at_home is True:
            s += 20
        if moving:
            s -= 30
        # at home with light phone activity: even a weak signal preserves the baseline
        if w["app_total_min"] > 0:
            s += 5
        return max(0.0, s)

    # ------------------------------------------------------ CONTENT_BINGE
    if ep == "CONTENT_BINGE":
        if w["app_total_min"] < 15:  # binge requires meaningful screen time
            return 0.0
        if w["top_cat"] not in {"streaming", "video", "short_video"}:
            return 0.0
        s = 40 + 50 * w["top_cat_share"]
        if at_home is True:
            s += 20
        if moving:
            s -= 30
        return max(0.0, s)

    # ----------------------------------------------------- GAMING_MARATHON
    if ep == "GAMING_MARATHON":
        if w["top_cat"] != "gaming":
            return 0.0
        if w["app_total_min"] < 10:
            return 0.0
        s = 50 + 40 * w["top_cat_share"]
        if at_home is True:
            s += 15
        if moving:
            s -= 30
        return max(0.0, s)

    # -------------------------------------------------------- ERRAND_CHAIN
    if ep == "ERRAND_CHAIN":
        if not (10 <= h < 19):
            return 0.0
        if w["unique_cells"] < 2:
            return 0.0
        s = 20 + 25 * cat_sig
        if w["unique_cells"] >= 3:
            s += 20
        if at_home is False and at_work is False:
            s += 15
        return max(0.0, s)

    # ----------------------------------------------------- EXPLORATION_DAY
    if ep == "EXPLORATION_DAY":
        if not (10 <= h < 20):
            return 0.0
        if w["unique_cells"] < 3 and w["max_speed"] < 1.0:
            return 0.0
        s = 15 + 30 * cat_sig
        if w["unique_cells"] >= 4:
            s += 30
        if at_home is False and at_work is False:
            s += 15
        if w["is_weekend"]:
            s += 10
        return max(0.0, s)

    return 0.0


# =============================================================================
# 4. PUBLIC ENTRY POINT
# =============================================================================

def compute_episode_shares(
    gps: pd.DataFrame,
    apps: pd.DataFrame,
    screen: pd.DataFrame,
    tz_offset: int = 0,
) -> Dict[str, float]:
    """Compute 15 ep_share_* values + episodes_per_day from raw data.

    Returns:
        {
          "ep_share_SLEEP": 0.30,
          ...
          "ep_share_EXPLORATION_DAY": 0.0,
          "episodes_per_day": 6.2,
        }
        All zeros when data is insufficient.
    """
    blank = {f"ep_share_{ep}": 0.0 for ep in EPISODE_TYPES}
    blank["episodes_per_day"] = 0.0

    windows = _build_windows(gps, apps, screen, tz_offset=tz_offset)
    if windows.empty:
        return blank

    home_cell, work_cell = _detect_anchor_cells(gps)

    labels: List[Optional[str]] = []
    for _, w in windows.iterrows():
        w_dict = w.to_dict()
        scores = {ep: _score(w_dict, ep, home_cell, work_cell) for ep in EPISODE_TYPES}
        best_ep = max(scores, key=scores.get)
        best_score = scores[best_ep]
        # Score too low -> "unknown" -- exclude from share calculation
        labels.append(best_ep if best_score >= 15.0 else None)

    valid = [l for l in labels if l is not None]
    if not valid:
        return blank

    n = len(valid)
    counts = pd.Series(valid).value_counts().to_dict()
    out = {f"ep_share_{ep}": float(counts.get(ep, 0)) / n for ep in EPISODE_TYPES}

    # Episodes per day: consecutive identical labels count as one episode
    distinct_episodes = 0
    prev = None
    for l in labels:
        if l is not None and l != prev:
            distinct_episodes += 1
        prev = l

    n_days = max(1, (windows["bin"].max() - windows["bin"].min()).days + 1)
    out["episodes_per_day"] = float(distinct_episodes / n_days)

    return out
