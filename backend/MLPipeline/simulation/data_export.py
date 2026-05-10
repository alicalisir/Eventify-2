"""
CSV export pipeline.

Writes:
  user_profile.csv   — full latent trait vector per user (ML ground truth)
  users.csv          — slim {user_id, persona, home/work coords}
  gps_pings.csv      — (user_id, ts, lat, lon, accuracy)
  app_sessions.csv   — (user_id, ts, app, category, duration_min)
  screen_events.csv  — (user_id, ts, event_type)
  episode_log.csv    — every episode an agent ran (with rationale)
  daily_summary.csv  — aggregated per (user, day)
"""

from __future__ import annotations

import os
import logging
import pandas as pd

import config
import utils

logger = logging.getLogger(__name__)


def export_simulation_data(model, output_dir: str = None) -> dict:
    output_dir = output_dir or config.OUTPUT_DIR
    os.makedirs(output_dir, exist_ok=True)
    logger.info(f"Exporting to {output_dir}")

    results = {}

    # ------------------------------------------------------- user_profile
    profiles = []
    slim = []
    for agent in model.schedule.agents:
        rec = agent.profile.to_record()
        rec["user_id"] = agent.unique_id
        rec["home_lat"] = round(agent.home_poi["latitude"], 6)
        rec["home_lon"] = round(agent.home_poi["longitude"], 6)
        rec["work_lat"] = round(agent.work_poi["latitude"], 6)
        rec["work_lon"] = round(agent.work_poi["longitude"], 6)
        profiles.append(rec)
        slim.append({
            "user_id": agent.unique_id,
            "persona": agent.persona_id,
            "persona_name": agent.profile.persona_name,
            "home_lat": rec["home_lat"], "home_lon": rec["home_lon"],
            "work_lat": rec["work_lat"], "work_lon": rec["work_lon"],
            "age": agent.profile.age,
            "occupation": agent.profile.occupation,
        })
    pd.DataFrame(profiles).to_csv(os.path.join(output_dir, "user_profile.csv"), index=False)
    pd.DataFrame(slim).to_csv(os.path.join(output_dir, "users.csv"), index=False)
    results["user_profile"] = len(profiles)
    results["users"] = len(slim)

    # ------------------------------------------------------- gps_pings
    if model.gps_pings:
        pd.DataFrame(model.gps_pings).to_csv(
            os.path.join(output_dir, "gps_pings.csv"), index=False
        )
        results["gps_pings"] = len(model.gps_pings)

    # ------------------------------------------------------- app_sessions
    if model.app_sessions:
        pd.DataFrame(model.app_sessions).to_csv(
            os.path.join(output_dir, "app_sessions.csv"), index=False
        )
        results["app_sessions"] = len(model.app_sessions)

    # ------------------------------------------------------- screen_events
    if model.screen_events:
        pd.DataFrame(model.screen_events).to_csv(
            os.path.join(output_dir, "screen_events.csv"), index=False
        )
        results["screen_events"] = len(model.screen_events)

    # ------------------------------------------------------- episode_log
    if model.episode_log:
        pd.DataFrame(model.episode_log).to_csv(
            os.path.join(output_dir, "episode_log.csv"), index=False
        )
        results["episode_log"] = len(model.episode_log)

    # ------------------------------------------------------- daily_summary
    daily = _generate_daily_summary(model)
    if daily is not None and not daily.empty:
        daily.to_csv(os.path.join(output_dir, "daily_summary.csv"), index=False)
        results["daily_summary"] = len(daily)

    # ------------------------------------------------------- ml_features
    ml = _generate_ml_features(model)
    if ml is not None and not ml.empty:
        ml.to_csv(os.path.join(output_dir, "ml_features.csv"), index=False)
        results["ml_features"] = len(ml)

    # ------------------------------------------------------- hourly_activity
    hourly = _generate_hourly_activity(model)
    if hourly is not None and not hourly.empty:
        hourly.to_csv(os.path.join(output_dir, "hourly_activity.csv"), index=False)
        results["hourly_activity"] = len(hourly)

    logger.info("Export complete:")
    for k, v in results.items():
        logger.info(f"  {k:18s}: {v:,}")
    return results


def _vec_haversine_m(lat1, lon1, lat2, lon2):
    """Vectorized haversine — accepts numpy arrays. Returns meters."""
    import numpy as np
    R = 6_371_000.0
    p1 = np.radians(lat1); p2 = np.radians(lat2)
    dphi = p2 - p1
    dlmb = np.radians(lon2 - lon1)
    a = np.sin(dphi/2)**2 + np.cos(p1) * np.cos(p2) * np.sin(dlmb/2)**2
    return 2 * R * np.arcsin(np.sqrt(a))


def _generate_daily_summary(model):
    """Aggregate (user, day) statistics — fully vectorized."""
    import numpy as np

    if not model.gps_pings:
        return None

    gps = pd.DataFrame(model.gps_pings)
    gps["timestamp"] = pd.to_datetime(gps["timestamp"])
    gps["date"] = gps["timestamp"].dt.date

    apps = pd.DataFrame(model.app_sessions) if model.app_sessions else pd.DataFrame()
    if not apps.empty:
        apps["timestamp"] = pd.to_datetime(apps["timestamp"])
        apps["date"] = apps["timestamp"].dt.date

    screen = pd.DataFrame(model.screen_events) if model.screen_events else pd.DataFrame()
    if not screen.empty:
        screen["timestamp"] = pd.to_datetime(screen["timestamp"])
        screen["date"] = screen["timestamp"].dt.date

    eps = pd.DataFrame(model.episode_log) if model.episode_log else pd.DataFrame()
    if not eps.empty:
        eps["timestamp"] = pd.to_datetime(eps["timestamp"])
        eps["date"] = eps["timestamp"].dt.date

    # ---- distance per (user, day) via vectorized haversine on shifted columns
    gps = gps.sort_values(["user_id", "timestamp"]).reset_index(drop=True)
    gps["lat_prev"] = gps.groupby("user_id")["latitude"].shift()
    gps["lon_prev"] = gps.groupby("user_id")["longitude"].shift()
    mask = gps["lat_prev"].notna()
    gps["seg_m"] = 0.0
    gps.loc[mask, "seg_m"] = _vec_haversine_m(
        gps.loc[mask, "lat_prev"].to_numpy(),
        gps.loc[mask, "lon_prev"].to_numpy(),
        gps.loc[mask, "latitude"].to_numpy(),
        gps.loc[mask, "longitude"].to_numpy(),
    )

    base = gps.groupby(["user_id", "date"]).agg(
        total_distance_m=("seg_m", "sum"),
        num_pings=("seg_m", "size"),
    ).reset_index()
    base["total_distance_m"] = base["total_distance_m"].round(1)

    # unique locations per (user, day)
    cells = (gps.assign(
        cell_lat=gps["latitude"].round(3),
        cell_lon=gps["longitude"].round(3),
    ).drop_duplicates(["user_id", "date", "cell_lat", "cell_lon"])
       .groupby(["user_id", "date"]).size().rename("num_locations_unique").reset_index())

    out = base.merge(cells, on=["user_id", "date"], how="left").drop(columns=["num_pings"])

    # app aggregates
    if not apps.empty:
        app_agg = apps.groupby(["user_id", "date"]).agg(
            total_screen_time_min=("duration_min", "sum"),
            num_app_sessions=("duration_min", "size"),
        ).reset_index()
        app_agg["total_screen_time_min"] = app_agg["total_screen_time_min"].round(1)
        out = out.merge(app_agg, on=["user_id", "date"], how="left")

        top_app = (apps.groupby(["user_id", "date", "app"])["duration_min"].sum()
                   .reset_index()
                   .sort_values("duration_min", ascending=False)
                   .drop_duplicates(["user_id", "date"])
                   .rename(columns={"app": "top_app"})[["user_id", "date", "top_app"]])
        out = out.merge(top_app, on=["user_id", "date"], how="left")

        top_cat = (apps.groupby(["user_id", "date", "category"])["duration_min"].sum()
                   .reset_index()
                   .sort_values("duration_min", ascending=False)
                   .drop_duplicates(["user_id", "date"])
                   .rename(columns={"category": "top_category"})[["user_id", "date", "top_category"]])
        out = out.merge(top_cat, on=["user_id", "date"], how="left")
    else:
        out["total_screen_time_min"] = 0.0
        out["num_app_sessions"] = 0
        out["top_app"] = ""
        out["top_category"] = ""

    # screen unlocks
    if not screen.empty:
        unlocks = (screen[screen["event_type"] == "unlock"]
                   .groupby(["user_id", "date"]).size()
                   .rename("num_screen_unlocks").reset_index())
        out = out.merge(unlocks, on=["user_id", "date"], how="left")
    out["num_screen_unlocks"] = out.get("num_screen_unlocks", 0)
    out["num_screen_unlocks"] = out["num_screen_unlocks"].fillna(0).astype(int)

    # episodes
    if not eps.empty:
        ep_count = eps.groupby(["user_id", "date"]).size().rename("num_episodes").reset_index()
        out = out.merge(ep_count, on=["user_id", "date"], how="left")
        top_ep = (eps.groupby(["user_id", "date", "episode_name"]).size()
                  .reset_index(name="n")
                  .sort_values("n", ascending=False)
                  .drop_duplicates(["user_id", "date"])
                  .rename(columns={"episode_name": "top_episode"})
                  [["user_id", "date", "top_episode"]])
        out = out.merge(top_ep, on=["user_id", "date"], how="left")
    else:
        out["num_episodes"] = 0
        out["top_episode"] = ""

    out["num_episodes"] = out["num_episodes"].fillna(0).astype(int)
    out["num_app_sessions"] = out["num_app_sessions"].fillna(0).astype(int)
    out["num_locations_unique"] = out["num_locations_unique"].fillna(0).astype(int)

    return out


# ============================================================================
# ml_features — flat per-user feature vector, ready for clustering/classification
# ============================================================================

def _generate_ml_features(model):
    """Aggregate the multi-day signal into one row per user — vectorized."""
    import numpy as np

    if not model.app_sessions or not model.gps_pings:
        return None

    apps = pd.DataFrame(model.app_sessions)
    gps = pd.DataFrame(model.gps_pings)
    eps = pd.DataFrame(model.episode_log) if model.episode_log else pd.DataFrame()

    apps["timestamp"] = pd.to_datetime(apps["timestamp"])
    gps["timestamp"] = pd.to_datetime(gps["timestamp"])
    apps["hour"] = apps["timestamp"].dt.hour
    apps["weekday"] = apps["timestamp"].dt.weekday

    persona_by_uid = {a.unique_id: a.persona_id for a in model.schedule.agents}
    user_ids = list(persona_by_uid.keys())

    # ---- app aggregates per user ----
    g = apps.groupby("user_id")
    base = g["duration_min"].agg(
        total_screen_min="sum",
        mean_session_min="mean",
        num_sessions="size",
    ).reset_index()

    # ---- category share matrix ----
    cat_pivot = (apps.groupby(["user_id", "category"])["duration_min"].sum()
                 .unstack(fill_value=0.0))
    cat_share = cat_pivot.div(cat_pivot.sum(axis=1).replace(0, 1), axis=0)
    for c in ["social","messaging","video","short_video","music","streaming","gaming",
              "productivity","browser","navigation","fitness","education","reading","news",
              "shopping","finance","photo","ride_share"]:
        if c not in cat_share.columns:
            cat_share[c] = 0.0
    cat_share = cat_share.add_prefix("share_cat_").reset_index()

    # ---- hour share matrix ----
    hour_pivot = (apps.groupby(["user_id", "hour"])["duration_min"].sum()
                  .unstack(fill_value=0.0))
    for h in range(24):
        if h not in hour_pivot.columns:
            hour_pivot[h] = 0.0
    hour_share = hour_pivot.div(hour_pivot.sum(axis=1).replace(0, 1), axis=0)
    hour_share.columns = [f"hour_share_{h:02d}" for h in hour_share.columns]
    hour_share = hour_share.reset_index()

    # ---- weekend ratio ----
    wd_we = (apps.assign(is_weekend=apps["weekday"] >= 5)
             .groupby(["user_id", "is_weekend"])["duration_min"].sum()
             .unstack(fill_value=0.0))
    wd_we.columns = [f"_we_{c}" for c in wd_we.columns]
    if "_we_True" not in wd_we.columns:
        wd_we["_we_True"] = 0.0
    if "_we_False" not in wd_we.columns:
        wd_we["_we_False"] = 0.0
    wd_we["weekend_ratio"] = wd_we["_we_True"] / (wd_we["_we_True"] + wd_we["_we_False"]).replace(0, 1)
    wd_we = wd_we[["weekend_ratio"]].reset_index()

    # ---- mobility (vectorized haversine) ----
    gps = gps.sort_values(["user_id", "timestamp"]).reset_index(drop=True)
    gps["lat_prev"] = gps.groupby("user_id")["latitude"].shift()
    gps["lon_prev"] = gps.groupby("user_id")["longitude"].shift()
    mask = gps["lat_prev"].notna()
    gps["seg_m"] = 0.0
    gps.loc[mask, "seg_m"] = _vec_haversine_m(
        gps.loc[mask, "lat_prev"].to_numpy(),
        gps.loc[mask, "lon_prev"].to_numpy(),
        gps.loc[mask, "latitude"].to_numpy(),
        gps.loc[mask, "longitude"].to_numpy(),
    )

    mob = gps.groupby("user_id").agg(
        total_distance_m=("seg_m", "sum"),
    ).reset_index()

    # radius of gyration: rms distance to user centroid
    centroids = gps.groupby("user_id")[["latitude", "longitude"]].mean().rename(
        columns={"latitude": "_cent_lat", "longitude": "_cent_lon"})
    gps2 = gps.merge(centroids, on="user_id")
    d_to_cent = _vec_haversine_m(gps2["_cent_lat"].to_numpy(),
                                 gps2["_cent_lon"].to_numpy(),
                                 gps2["latitude"].to_numpy(),
                                 gps2["longitude"].to_numpy())
    gps2["_d_cent_sq"] = d_to_cent ** 2
    rad = (gps2.groupby("user_id")["_d_cent_sq"].mean()
              .pow(0.5).rename("mobility_radius_m").reset_index())

    cells = (gps.assign(
        cell_lat=gps["latitude"].round(3), cell_lon=gps["longitude"].round(3),
    ).drop_duplicates(["user_id", "cell_lat", "cell_lon"])
       .groupby("user_id").size().rename("unique_cells_100m").reset_index())

    # ---- episode share ----
    if not eps.empty:
        ep_pivot = (eps.groupby(["user_id", "episode_name"]).size()
                    .unstack(fill_value=0))
        ep_share = ep_pivot.div(ep_pivot.sum(axis=1).replace(0, 1), axis=0)
        for ep in ["SLEEP","NIGHT_BROWSING","MORNING_ROUTINE","COMMUTE_TO_WORK","COMMUTE_HOME",
                   "WORK_DAY","STUDY_BLOCK","GO_TO_CAFE","SOCIALIZE","EXERCISE","RELAX_AT_HOME",
                   "CONTENT_BINGE","GAMING_MARATHON","ERRAND_CHAIN","EXPLORATION_DAY"]:
            if ep not in ep_share.columns:
                ep_share[ep] = 0.0
        ep_share = ep_share.add_prefix("ep_share_").reset_index()
    else:
        ep_share = pd.DataFrame({"user_id": user_ids})
        for ep in ["SLEEP","NIGHT_BROWSING","MORNING_ROUTINE","COMMUTE_TO_WORK","COMMUTE_HOME",
                   "WORK_DAY","STUDY_BLOCK","GO_TO_CAFE","SOCIALIZE","EXERCISE","RELAX_AT_HOME",
                   "CONTENT_BINGE","GAMING_MARATHON","ERRAND_CHAIN","EXPLORATION_DAY"]:
            ep_share[f"ep_share_{ep}"] = 0.0

    # ---- merge all ----
    out = pd.DataFrame({"user_id": user_ids})
    out["persona"] = out["user_id"].map(persona_by_uid)
    for piece in (base, cat_share, hour_share, wd_we, mob, rad, cells, ep_share):
        out = out.merge(piece, on="user_id", how="left")
    return out.fillna(0.0)


def _radius_of_gyration(lats, lons) -> float:
    """Standalone RG (kept only for legacy callers; vectorized version is inline)."""
    import numpy as np
    if len(lats) == 0:
        return 0.0
    lat_c, lon_c = float(np.mean(lats)), float(np.mean(lons))
    dists = [utils.haversine_distance(lat_c, lon_c, la, lo) for la, lo in zip(lats, lons)]
    return float(np.sqrt(np.mean(np.square(dists))))


# ============================================================================
# hourly_activity — (user, date, hour) -> dominant signal; ready for sequence
# models (e.g. transformer over a 168-hour weekly sequence).
# ============================================================================

def _generate_hourly_activity(model):
    if not model.app_sessions:
        return None
    apps = pd.DataFrame(model.app_sessions)
    apps["timestamp"] = pd.to_datetime(apps["timestamp"])
    apps["date"] = apps["timestamp"].dt.date
    apps["hour"] = apps["timestamp"].dt.hour

    g = apps.groupby(["user_id", "date", "hour"]).agg(
        total_min=("duration_min", "sum"),
        num_sessions=("duration_min", "size"),
        top_category=("category", lambda s: s.value_counts().index[0]),
        top_app=("app", lambda s: s.value_counts().index[0]),
    ).reset_index()
    return g
