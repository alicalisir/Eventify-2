"""
Persona-based mobility validation — thesis evidence figure.

Computes radius of gyration per user (same formula as scikit-mobility)
using only pandas + numpy + matplotlib (no conda/GDAL required).

Run:
    python validate_mobility.py
Output:
    outputs/reports/persona_mobility_validation.png
"""

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE = Path(__file__).parent
GPS_PATH   = BASE / "outputs" / "train_raw" / "gps_pings.csv"
USERS_PATH = BASE / "outputs" / "train_raw" / "users.csv"
OUT_DIR    = BASE / "outputs" / "reports"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PERSONAS_OF_INTEREST = [
    "TRAVELER", "ATHLETE", "SOCIAL", "PROFESSIONAL",
    "STUDENT",  "EARLY_BIRD", "NIGHT_OWL", "HOMEBODY",
]

# ── Haversine helper ──────────────────────────────────────────────────────────
def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi  = math.radians(lat2 - lat1)
    dlam  = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── Radius of gyration (same definition as scikit-mobility) ──────────────────
def radius_of_gyration_km(lat_arr, lon_arr):
    """
    RoG = sqrt( mean( d_i^2 ) )  where d_i = distance from centre of mass.
    Returns kilometres.
    """
    if len(lat_arr) < 2:
        return 0.0
    lat_c = lat_arr.mean()
    lon_c = lon_arr.mean()
    sq_dists = [haversine_km(lat_c, lon_c, la, lo) ** 2
                for la, lo in zip(lat_arr, lon_arr)]
    return math.sqrt(sum(sq_dists) / len(sq_dists))


# ── Load data ─────────────────────────────────────────────────────────────────
print("Loading data...")
gps   = pd.read_csv(GPS_PATH,   usecols=["user_id", "latitude", "longitude"])
users = pd.read_csv(USERS_PATH, usecols=["user_id", "persona"])
gps   = gps.merge(users, on="user_id", how="left")

# ── Compute RoG per user ──────────────────────────────────────────────────────
print("Computing radius of gyration per user...")
rog_records = []
for uid, grp in gps.groupby("user_id"):
    rog = radius_of_gyration_km(grp["latitude"].values, grp["longitude"].values)
    persona = grp["persona"].iloc[0]
    rog_records.append({"user_id": uid, "persona": persona, "rog_km": rog})

rog_df = pd.DataFrame(rog_records)
rog_filt = rog_df[rog_df["persona"].isin(PERSONAS_OF_INTEREST)].copy()

summary = (rog_filt.groupby("persona")["rog_km"]
           .agg(mean="mean", median="median", std="std")
           .round(2)
           .sort_values("mean", ascending=False))

print("\nRadius of Gyration (km) per Persona:")
print(summary.to_string())

# ── Plot ──────────────────────────────────────────────────────────────────────
order  = summary.index.tolist()
colors = plt.cm.Set2(np.linspace(0, 1, len(order)))

fig, axes = plt.subplots(1, 2, figsize=(14, 6))
fig.suptitle(
    "Persona-Based Mobility Validation\n"
    "(Simulated Data — Radius of Gyration metric)",
    fontsize=13, fontweight="bold",
)

# Left: boxplot
data_box = [rog_filt[rog_filt["persona"] == p]["rog_km"].dropna().values for p in order]
bp = axes[0].boxplot(data_box, tick_labels=order, patch_artist=True, notch=False)
for patch, color in zip(bp["boxes"], colors):
    patch.set_facecolor(color)
    patch.set_alpha(0.8)
axes[0].set_title("Distribution by Persona")
axes[0].set_ylabel("Radius of Gyration (km)")
axes[0].tick_params(axis="x", rotation=45)
axes[0].grid(axis="y", alpha=0.3)

# Right: horizontal bar
means = summary["mean"]
errs  = summary["std"]
axes[1].barh(order, means, xerr=errs, color=colors, edgecolor="white",
             height=0.6, alpha=0.85)
axes[1].set_title("Mean Radius of Gyration ± Std Dev")
axes[1].set_xlabel("Radius of Gyration (km)")
axes[1].grid(axis="x", alpha=0.3)
for i, (m, s) in enumerate(zip(means, errs)):
    axes[1].text(m + s + 0.05, i, f"{m:.1f} km", va="center", fontsize=9)

plt.tight_layout()
out_path = OUT_DIR / "persona_mobility_validation.png"
plt.savefig(out_path, dpi=150, bbox_inches="tight")
print(f"\nSaved: {out_path}")
plt.show()
