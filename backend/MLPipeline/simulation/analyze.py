"""
Persona-recoverability diagnostic.

Reads the exported CSVs and prints the per-persona signal strength so you can
verify the data is ML-ready: clusters should be visible, but with realistic
overlap (no perfect one-app-per-persona giveaways).

Run after simulate.py:
    python analyze.py
"""

from __future__ import annotations

import os
import sys
import pandas as pd

import config

OUT = config.OUTPUT_DIR


def load():
    users = pd.read_csv(os.path.join(OUT, "users.csv"))
    eps   = pd.read_csv(os.path.join(OUT, "episode_log.csv"))
    apps  = pd.read_csv(os.path.join(OUT, "app_sessions.csv")).merge(
        users[["user_id", "persona"]], on="user_id", suffixes=("", "_u")
    )
    daily = pd.read_csv(os.path.join(OUT, "daily_summary.csv")).merge(
        users[["user_id", "persona"]], on="user_id", suffixes=("", "_u")
    )
    return users, eps, apps, daily


def episode_mix(eps: pd.DataFrame) -> pd.DataFrame:
    return (pd.crosstab(eps["persona"], eps["episode_name"], normalize="index") * 100).round(1)


def category_mix(apps: pd.DataFrame) -> pd.DataFrame:
    cat = apps.groupby(["persona", "category"])["duration_min"].sum().unstack(fill_value=0)
    return (cat.div(cat.sum(axis=1), axis=0) * 100).round(1)


def daily_averages(daily: pd.DataFrame) -> pd.DataFrame:
    return daily.groupby("persona")[
        ["total_screen_time_min", "total_distance_m",
         "num_app_sessions", "num_episodes", "num_screen_unlocks"]
    ].mean().round(1)


def main():
    pd.set_option("display.width", 240)
    pd.set_option("display.max_columns", 30)
    pd.set_option("display.max_rows", 40)

    if not os.path.exists(os.path.join(OUT, "users.csv")):
        print(f"No exports found in {OUT}. Run simulate.py first.")
        sys.exit(1)

    users, eps, apps, daily = load()
    print(f"Loaded: {len(users)} users, {len(eps)} episodes, {len(apps)} app sessions\n")

    print("=" * 80)
    print("EPISODE MIX % PER PERSONA")
    print("=" * 80)
    print(episode_mix(eps).fillna(0))
    print()

    print("=" * 80)
    print("APP-CATEGORY MINUTES % PER PERSONA")
    print("=" * 80)
    print(category_mix(apps))
    print()

    print("=" * 80)
    print("DAILY BEHAVIORAL AVERAGES PER PERSONA")
    print("=" * 80)
    print(daily_averages(daily))
    print()


if __name__ == "__main__":
    main()
