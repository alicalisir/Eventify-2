"""
Persona Schema & Probabilistic User Profile Sampler
===================================================

Each of the 12 predefined personas is a *probability distribution* over latent
behavioral traits, NOT a hardcoded boolean profile. Sampling a persona produces
a UserProfile — a concrete trait vector that drives the agent's day-to-day
decisions, episode utility, and app selection.

Two agents drawn from the same persona are similar but never identical, which
is what makes the dataset useful for ML persona-recovery training.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Tuple

import numpy as np

import config

# ============================================================================
# 1. LATENT TRAIT VECTOR
# ============================================================================
# All numeric traits are in [0, 1] unless otherwise noted. They drive utility
# scoring inside the episode engine — every episode reads from these traits to
# decide whether the agent feels like doing it.

@dataclass
class UserProfile:
    """A concrete realization of a persona — one synthetic person."""

    # ----- identity -----
    persona_name: str
    persona_id: str

    # ----- demographics -----
    age: int                      # 16..70
    occupation: str               # "student","professional","unemployed","freelancer", etc.
    weekday_work: bool            # do weekdays involve work/study?

    # ----- circadian / sleep -----
    sleep_hour: float             # hour-of-day they typically go to sleep (0..47, can wrap)
    wake_hour: float              # hour-of-day they typically wake (0..24)
    sleep_duration_h: float       # total nightly sleep in hours
    chronotype: float             # -1 (extreme morning) .. +1 (extreme night)

    # ----- intensities (0..1) -----
    work_intensity: float
    study_intensity: float
    exercise_propensity: float
    gaming_propensity: float
    content_consumption: float
    social_need: float
    explore_propensity: float
    digital_addiction: float        # nighttime browsing, app burst frequency
    routine_stability: float        # 1 = same routine each day, 0 = chaotic
    weekday_weekend_delta: float    # 0..1 — how different weekends are
    home_centeredness: float        # 0..1 — bias to stay near home

    # ----- mobility -----
    mobility_radius_km: float       # typical daily reach
    transit_pref_speed: float       # m/min — walk vs drive vs transit

    # ----- screen -----
    screen_time_target_h: float     # daily target screen time (hours)

    # ----- app preference distribution -----
    # Maps app_name -> weight (>0). Normalized internally when sampling.
    app_weights: Dict[str, float] = field(default_factory=dict)

    # ----- sub-persona blend (for HIBRIT) -----
    blend: Dict[str, float] = field(default_factory=dict)

    def to_record(self) -> dict:
        """Flat dict for CSV export (drops dict-typed fields)."""
        d = asdict(self)
        # serialize app_weights as compact "name:weight,..." string
        d["app_weights"] = "|".join(f"{k}:{v:.2f}" for k, v in self.app_weights.items())
        d["blend"] = "|".join(f"{k}:{v:.2f}" for k, v in self.blend.items())
        return d

    # ---- convenience helpers used by episodes/agent ----
    def is_active_hour(self, hour: int) -> bool:
        """Is the agent typically awake at this hour-of-day?"""
        wake = self.wake_hour % 24
        sleep = self.sleep_hour % 24
        if wake < sleep:
            return wake <= hour < sleep
        # wraps midnight (e.g. wake=10, sleep=3)
        return hour >= wake or hour < sleep

    def hours_until_typical_sleep(self, current_hour: float) -> float:
        delta = (self.sleep_hour - current_hour) % 24
        return delta if delta < 24 else 0


# ============================================================================
# 2. PERSONA PRIOR
# ============================================================================
# A persona is a dict of (mean, std) for each numeric trait, plus categorical
# choices and an app-affinity vector. The sampler converts this into a
# UserProfile.

NUMERIC_TRAITS = [
    "wake_hour", "sleep_hour", "sleep_duration_h", "chronotype",
    "work_intensity", "study_intensity", "exercise_propensity",
    "gaming_propensity", "content_consumption", "social_need",
    "explore_propensity", "digital_addiction", "routine_stability",
    "weekday_weekend_delta", "home_centeredness",
    "mobility_radius_km", "transit_pref_speed", "screen_time_target_h",
]


@dataclass
class PersonaPrior:
    """Probability distribution over UserProfile traits for one persona."""
    name: str
    persona_id: str
    age_range: Tuple[int, int]
    occupations: List[Tuple[str, float]]           # (label, weight)
    weekday_work_prob: float
    means: Dict[str, float]
    stds: Dict[str, float]
    app_affinity: Dict[str, float]                 # category-level base weights
    app_overrides: Dict[str, float] = field(default_factory=dict)  # specific app boosts
    blend: Dict[str, float] = field(default_factory=dict)


def _sample_normal(mean: float, std: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return float(np.clip(np.random.normal(mean, std), lo, hi))


def _sample_choice(weighted: List[Tuple[str, float]]) -> str:
    labels, weights = zip(*weighted)
    weights = np.array(weights, dtype=float)
    weights = weights / weights.sum()
    return str(np.random.choice(labels, p=weights))


def _build_app_weights(prior: "PersonaPrior") -> Dict[str, float]:
    """
    Build a per-app weight vector by combining:
      - persona's category-level affinities  (e.g. social=0.9)
      - individual app overrides             (e.g. discord=2.0)
      - mild per-user jitter so two same-persona users differ
    """
    weights: Dict[str, float] = {}
    for app, meta in config.APPS.items():
        base = prior.app_affinity.get(meta["category"], 0.05)
        boost = prior.app_overrides.get(app, 1.0)
        jitter = float(np.random.uniform(0.7, 1.3))
        weights[app] = max(0.001, base * boost * jitter)
    return weights


def sample_user_profile(prior: PersonaPrior) -> UserProfile:
    """Draw a concrete UserProfile from a persona prior."""

    # numeric traits — sample with bounds appropriate to each
    sampled: Dict[str, float] = {}
    for trait in NUMERIC_TRAITS:
        m = prior.means.get(trait)
        s = prior.stds.get(trait, 0.1)
        if m is None:
            continue
        if trait in ("wake_hour", "sleep_hour"):
            sampled[trait] = float(np.clip(np.random.normal(m, s), 0, 47)) % 24
        elif trait == "sleep_duration_h":
            sampled[trait] = float(np.clip(np.random.normal(m, s), 4, 11))
        elif trait == "chronotype":
            sampled[trait] = float(np.clip(np.random.normal(m, s), -1, 1))
        elif trait == "mobility_radius_km":
            sampled[trait] = float(np.clip(np.random.normal(m, s), 0.3, 50))
        elif trait == "transit_pref_speed":
            sampled[trait] = float(np.clip(np.random.normal(m, s), 80, 600))
        elif trait == "screen_time_target_h":
            sampled[trait] = float(np.clip(np.random.normal(m, s), 1.0, 14.0))
        else:  # 0..1 traits
            sampled[trait] = _sample_normal(m, s, 0.0, 1.0)

    age = int(np.random.uniform(*prior.age_range))
    occupation = _sample_choice(prior.occupations)
    weekday_work = bool(np.random.random() < prior.weekday_work_prob)

    profile = UserProfile(
        persona_name=prior.name,
        persona_id=prior.persona_id,
        age=age,
        occupation=occupation,
        weekday_work=weekday_work,
        wake_hour=sampled["wake_hour"],
        sleep_hour=sampled["sleep_hour"],
        sleep_duration_h=sampled["sleep_duration_h"],
        chronotype=sampled["chronotype"],
        work_intensity=sampled["work_intensity"],
        study_intensity=sampled["study_intensity"],
        exercise_propensity=sampled["exercise_propensity"],
        gaming_propensity=sampled["gaming_propensity"],
        content_consumption=sampled["content_consumption"],
        social_need=sampled["social_need"],
        explore_propensity=sampled["explore_propensity"],
        digital_addiction=sampled["digital_addiction"],
        routine_stability=sampled["routine_stability"],
        weekday_weekend_delta=sampled["weekday_weekend_delta"],
        home_centeredness=sampled["home_centeredness"],
        mobility_radius_km=sampled["mobility_radius_km"],
        transit_pref_speed=sampled["transit_pref_speed"],
        screen_time_target_h=sampled["screen_time_target_h"],
        app_weights=_build_app_weights(prior),
        blend=dict(prior.blend),
    )
    return profile


# ============================================================================
# 3. THE 12 PERSONA PRIORS
# ============================================================================
# Notation:
#   means/stds keyed by trait name.
#   app_affinity uses category names from config.APPS[*].category.

# Default category baseline (everyone uses these a little):
_BASE_CATS = {
    "social": 0.20, "messaging": 0.30, "video": 0.20, "short_video": 0.15,
    "music": 0.20, "streaming": 0.10, "gaming": 0.05, "productivity": 0.10,
    "browser": 0.20, "navigation": 0.30, "fitness": 0.05, "education": 0.05,
    "reading": 0.05, "news": 0.10, "finance": 0.10, "shopping": 0.10,
    "photo": 0.10, "ride_share": 0.05, "dating": 0.02,
}


def _cat(updates: Dict[str, float]) -> Dict[str, float]:
    """Merge category overrides on top of base."""
    d = dict(_BASE_CATS)
    d.update(updates)
    return d


# 1. GECE KUŞU (Night Owl) -----------------------------------------------------
GECE_KUSU = PersonaPrior(
    name="Gece Kuşu", persona_id="GECE_KUSU",
    age_range=(18, 35),
    occupations=[("student", 0.4), ("freelancer", 0.3), ("creative", 0.2), ("unemployed", 0.1)],
    weekday_work_prob=0.5,
    means={
        "wake_hour": 11.5, "sleep_hour": 3.0, "sleep_duration_h": 7.5, "chronotype": 0.85,
        "work_intensity": 0.3, "study_intensity": 0.3, "exercise_propensity": 0.15,
        "gaming_propensity": 0.55, "content_consumption": 0.8, "social_need": 0.6,
        "explore_propensity": 0.2, "digital_addiction": 0.85, "routine_stability": 0.4,
        "weekday_weekend_delta": 0.3, "home_centeredness": 0.7,
        "mobility_radius_km": 5.0, "transit_pref_speed": 250, "screen_time_target_h": 8.5,
    },
    stds={
        "wake_hour": 1.5, "sleep_hour": 1.5, "sleep_duration_h": 1.0, "chronotype": 0.1,
        "work_intensity": 0.15, "study_intensity": 0.15, "exercise_propensity": 0.1,
        "gaming_propensity": 0.2, "content_consumption": 0.1, "social_need": 0.15,
        "explore_propensity": 0.1, "digital_addiction": 0.08, "routine_stability": 0.15,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.15,
        "mobility_radius_km": 3.0, "transit_pref_speed": 80, "screen_time_target_h": 1.5,
    },
    app_affinity=_cat({
        "social": 0.85, "short_video": 0.85, "video": 0.7, "streaming": 0.7,
        "messaging": 0.7, "gaming": 0.5, "music": 0.5,
    }),
    app_overrides={"tiktok": 1.6, "youtube": 1.4, "twitch": 1.5, "reddit": 1.3,
                   "instagram": 1.2, "discord": 1.4, "netflix": 1.3},
)

# 2. ERKENCI (Early Bird) ------------------------------------------------------
ERKENCI = PersonaPrior(
    name="Erkenci", persona_id="ERKENCI",
    age_range=(25, 60),
    occupations=[("professional", 0.5), ("teacher", 0.2), ("retired", 0.15), ("freelancer", 0.15)],
    weekday_work_prob=0.85,
    means={
        "wake_hour": 6.0, "sleep_hour": 22.5, "sleep_duration_h": 7.5, "chronotype": -0.7,
        "work_intensity": 0.7, "study_intensity": 0.2, "exercise_propensity": 0.55,
        "gaming_propensity": 0.05, "content_consumption": 0.3, "social_need": 0.35,
        "explore_propensity": 0.25, "digital_addiction": 0.2, "routine_stability": 0.85,
        "weekday_weekend_delta": 0.35, "home_centeredness": 0.45,
        "mobility_radius_km": 10.0, "transit_pref_speed": 350, "screen_time_target_h": 3.5,
    },
    stds={
        "wake_hour": 0.6, "sleep_hour": 0.7, "sleep_duration_h": 0.7, "chronotype": 0.1,
        "work_intensity": 0.12, "study_intensity": 0.1, "exercise_propensity": 0.15,
        "gaming_propensity": 0.05, "content_consumption": 0.1, "social_need": 0.12,
        "explore_propensity": 0.1, "digital_addiction": 0.1, "routine_stability": 0.08,
        "weekday_weekend_delta": 0.1, "home_centeredness": 0.12,
        "mobility_radius_km": 4.0, "transit_pref_speed": 100, "screen_time_target_h": 1.0,
    },
    app_affinity=_cat({
        "productivity": 0.75, "news": 0.6, "fitness": 0.5, "navigation": 0.7,
        "messaging": 0.5, "reading": 0.4,
    }),
    app_overrides={"gmail": 1.6, "outlook": 1.4, "news": 1.5, "fitbit": 1.4,
                   "podcasts": 1.5, "kindle": 1.3, "banking": 1.2},
)

# 3. SOSYAL (Social Media Heavy) ----------------------------------------------
SOSYAL = PersonaPrior(
    name="Sosyal", persona_id="SOSYAL",
    age_range=(16, 32),
    occupations=[("student", 0.4), ("influencer", 0.2), ("retail", 0.2), ("professional", 0.2)],
    weekday_work_prob=0.7,
    means={
        "wake_hour": 9.5, "sleep_hour": 1.0, "sleep_duration_h": 7.5, "chronotype": 0.4,
        "work_intensity": 0.4, "study_intensity": 0.3, "exercise_propensity": 0.3,
        "gaming_propensity": 0.15, "content_consumption": 0.7, "social_need": 0.95,
        "explore_propensity": 0.6, "digital_addiction": 0.85, "routine_stability": 0.5,
        "weekday_weekend_delta": 0.55, "home_centeredness": 0.3,
        "mobility_radius_km": 12.0, "transit_pref_speed": 320, "screen_time_target_h": 7.0,
    },
    stds={
        "wake_hour": 1.2, "sleep_hour": 1.2, "sleep_duration_h": 0.9, "chronotype": 0.15,
        "work_intensity": 0.15, "study_intensity": 0.15, "exercise_propensity": 0.15,
        "gaming_propensity": 0.1, "content_consumption": 0.15, "social_need": 0.05,
        "explore_propensity": 0.15, "digital_addiction": 0.08, "routine_stability": 0.15,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.12,
        "mobility_radius_km": 4.0, "transit_pref_speed": 80, "screen_time_target_h": 1.3,
    },
    app_affinity=_cat({
        "social": 0.95, "short_video": 0.85, "messaging": 0.85, "photo": 0.8,
        "shopping": 0.5, "dating": 0.25,
    }),
    app_overrides={"instagram": 2.0, "snapchat": 1.7, "tiktok": 1.5, "twitter": 1.4,
                   "whatsapp": 1.5, "telegram": 1.3, "camera": 1.6, "trendyol": 1.3},
)

# 4. OYUNCU (Gamer) ------------------------------------------------------------
OYUNCU = PersonaPrior(
    name="Oyuncu", persona_id="OYUNCU",
    age_range=(15, 35),
    occupations=[("student", 0.4), ("freelancer", 0.25), ("unemployed", 0.15), ("professional", 0.2)],
    weekday_work_prob=0.55,
    means={
        "wake_hour": 11.0, "sleep_hour": 2.5, "sleep_duration_h": 8.0, "chronotype": 0.7,
        "work_intensity": 0.3, "study_intensity": 0.25, "exercise_propensity": 0.15,
        "gaming_propensity": 0.95, "content_consumption": 0.7, "social_need": 0.55,
        "explore_propensity": 0.15, "digital_addiction": 0.9, "routine_stability": 0.55,
        "weekday_weekend_delta": 0.35, "home_centeredness": 0.85,
        "mobility_radius_km": 4.0, "transit_pref_speed": 220, "screen_time_target_h": 9.0,
    },
    stds={
        "wake_hour": 1.5, "sleep_hour": 1.5, "sleep_duration_h": 1.0, "chronotype": 0.1,
        "work_intensity": 0.15, "study_intensity": 0.12, "exercise_propensity": 0.1,
        "gaming_propensity": 0.05, "content_consumption": 0.15, "social_need": 0.15,
        "explore_propensity": 0.1, "digital_addiction": 0.07, "routine_stability": 0.15,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.1,
        "mobility_radius_km": 2.5, "transit_pref_speed": 80, "screen_time_target_h": 1.5,
    },
    app_affinity=_cat({
        "gaming": 1.0, "streaming": 0.85, "messaging": 0.7, "video": 0.7,
        "social": 0.4, "music": 0.4,
    }),
    app_overrides={"discord": 2.0, "twitch": 1.8, "mobile_legends": 1.7,
                   "pubg_mobile": 1.6, "valorant_mobile": 1.6, "youtube": 1.4,
                   "reddit": 1.3, "clash_royale": 1.3},
)

# 5. ICERIK_TUKETICI (Content Consumer) ---------------------------------------
ICERIK_TUKETICI = PersonaPrior(
    name="İçerik Tüketicisi", persona_id="ICERIK_TUKETICI",
    age_range=(18, 50),
    occupations=[("professional", 0.4), ("freelancer", 0.2), ("student", 0.2), ("homemaker", 0.2)],
    weekday_work_prob=0.7,
    means={
        "wake_hour": 9.0, "sleep_hour": 0.5, "sleep_duration_h": 7.5, "chronotype": 0.25,
        "work_intensity": 0.5, "study_intensity": 0.2, "exercise_propensity": 0.2,
        "gaming_propensity": 0.2, "content_consumption": 0.95, "social_need": 0.45,
        "explore_propensity": 0.25, "digital_addiction": 0.8, "routine_stability": 0.7,
        "weekday_weekend_delta": 0.3, "home_centeredness": 0.7,
        "mobility_radius_km": 6.0, "transit_pref_speed": 280, "screen_time_target_h": 7.5,
    },
    stds={
        "wake_hour": 1.0, "sleep_hour": 1.0, "sleep_duration_h": 0.8, "chronotype": 0.15,
        "work_intensity": 0.15, "study_intensity": 0.12, "exercise_propensity": 0.1,
        "gaming_propensity": 0.12, "content_consumption": 0.05, "social_need": 0.15,
        "explore_propensity": 0.12, "digital_addiction": 0.08, "routine_stability": 0.12,
        "weekday_weekend_delta": 0.12, "home_centeredness": 0.12,
        "mobility_radius_km": 3.0, "transit_pref_speed": 80, "screen_time_target_h": 1.3,
    },
    app_affinity=_cat({
        "video": 0.95, "streaming": 0.95, "short_video": 0.7, "music": 0.6,
        "reading": 0.4, "news": 0.5,
    }),
    app_overrides={"youtube": 1.8, "netflix": 1.7, "disney_plus": 1.4,
                   "twitch": 1.2, "spotify": 1.4, "podcasts": 1.3, "medium": 1.3},
)

# 6. SPORCU (Fitness-Oriented) ------------------------------------------------
SPORCU = PersonaPrior(
    name="Sporcu", persona_id="SPORCU",
    age_range=(20, 50),
    occupations=[("professional", 0.5), ("trainer", 0.2), ("student", 0.15), ("freelancer", 0.15)],
    weekday_work_prob=0.85,
    means={
        "wake_hour": 6.5, "sleep_hour": 23.0, "sleep_duration_h": 7.5, "chronotype": -0.4,
        "work_intensity": 0.6, "study_intensity": 0.2, "exercise_propensity": 0.95,
        "gaming_propensity": 0.05, "content_consumption": 0.3, "social_need": 0.4,
        "explore_propensity": 0.45, "digital_addiction": 0.25, "routine_stability": 0.9,
        "weekday_weekend_delta": 0.25, "home_centeredness": 0.4,
        "mobility_radius_km": 12.0, "transit_pref_speed": 380, "screen_time_target_h": 3.5,
    },
    stds={
        "wake_hour": 0.7, "sleep_hour": 0.8, "sleep_duration_h": 0.7, "chronotype": 0.1,
        "work_intensity": 0.15, "study_intensity": 0.1, "exercise_propensity": 0.05,
        "gaming_propensity": 0.05, "content_consumption": 0.1, "social_need": 0.12,
        "explore_propensity": 0.12, "digital_addiction": 0.1, "routine_stability": 0.08,
        "weekday_weekend_delta": 0.1, "home_centeredness": 0.12,
        "mobility_radius_km": 5.0, "transit_pref_speed": 120, "screen_time_target_h": 1.0,
    },
    app_affinity=_cat({
        "fitness": 1.0, "music": 0.7, "navigation": 0.6, "productivity": 0.5,
        "social": 0.3, "messaging": 0.4,
    }),
    app_overrides={"strava": 2.0, "nike_run": 1.8, "fitbit": 1.6,
                   "spotify": 1.6, "podcasts": 1.3, "maps": 1.3},
)

# 7. OGRENCI (Akademik / Student) ---------------------------------------------
OGRENCI = PersonaPrior(
    name="Öğrenci", persona_id="OGRENCI",
    age_range=(17, 27),
    occupations=[("student", 0.85), ("intern", 0.1), ("part_time", 0.05)],
    weekday_work_prob=0.95,
    means={
        "wake_hour": 8.5, "sleep_hour": 1.5, "sleep_duration_h": 7.0, "chronotype": 0.3,
        "work_intensity": 0.2, "study_intensity": 0.85, "exercise_propensity": 0.3,
        "gaming_propensity": 0.4, "content_consumption": 0.6, "social_need": 0.7,
        "explore_propensity": 0.4, "digital_addiction": 0.65, "routine_stability": 0.6,
        "weekday_weekend_delta": 0.45, "home_centeredness": 0.5,
        "mobility_radius_km": 8.0, "transit_pref_speed": 280, "screen_time_target_h": 6.0,
    },
    stds={
        "wake_hour": 1.0, "sleep_hour": 1.2, "sleep_duration_h": 1.0, "chronotype": 0.15,
        "work_intensity": 0.15, "study_intensity": 0.1, "exercise_propensity": 0.15,
        "gaming_propensity": 0.2, "content_consumption": 0.15, "social_need": 0.12,
        "explore_propensity": 0.15, "digital_addiction": 0.12, "routine_stability": 0.15,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.15,
        "mobility_radius_km": 3.0, "transit_pref_speed": 100, "screen_time_target_h": 1.5,
    },
    app_affinity=_cat({
        "education": 0.9, "productivity": 0.7, "messaging": 0.8, "social": 0.7,
        "video": 0.6, "short_video": 0.5, "browser": 0.7,
    }),
    app_overrides={"notion": 1.7, "duolingo": 1.6, "khan_academy": 1.5,
                   "coursera": 1.4, "whatsapp": 1.5, "telegram": 1.4,
                   "youtube": 1.3, "instagram": 1.3, "chrome": 1.4},
)

# 8. PROFESYONEL (Working Professional) --------------------------------------
PROFESYONEL = PersonaPrior(
    name="Profesyonel", persona_id="PROFESYONEL",
    age_range=(25, 55),
    occupations=[("professional", 0.85), ("manager", 0.1), ("consultant", 0.05)],
    weekday_work_prob=0.97,
    means={
        "wake_hour": 7.0, "sleep_hour": 23.5, "sleep_duration_h": 7.0, "chronotype": -0.2,
        "work_intensity": 0.95, "study_intensity": 0.2, "exercise_propensity": 0.35,
        "gaming_propensity": 0.1, "content_consumption": 0.4, "social_need": 0.45,
        "explore_propensity": 0.2, "digital_addiction": 0.45, "routine_stability": 0.9,
        "weekday_weekend_delta": 0.5, "home_centeredness": 0.45,
        "mobility_radius_km": 15.0, "transit_pref_speed": 400, "screen_time_target_h": 5.0,
    },
    stds={
        "wake_hour": 0.6, "sleep_hour": 0.7, "sleep_duration_h": 0.7, "chronotype": 0.1,
        "work_intensity": 0.05, "study_intensity": 0.1, "exercise_propensity": 0.15,
        "gaming_propensity": 0.08, "content_consumption": 0.12, "social_need": 0.12,
        "explore_propensity": 0.12, "digital_addiction": 0.12, "routine_stability": 0.05,
        "weekday_weekend_delta": 0.12, "home_centeredness": 0.12,
        "mobility_radius_km": 5.0, "transit_pref_speed": 120, "screen_time_target_h": 1.2,
    },
    app_affinity=_cat({
        "productivity": 0.95, "news": 0.6, "navigation": 0.8, "messaging": 0.7,
        "finance": 0.5, "browser": 0.7,
    }),
    app_overrides={"outlook": 1.8, "teams": 1.7, "slack": 1.6, "gmail": 1.5,
                   "news": 1.4, "banking": 1.4, "maps": 1.4, "linkedin": 1.3},
)

# 9. EVCIMEN (Home-Centered) --------------------------------------------------
EVCIMEN = PersonaPrior(
    name="Evcimen", persona_id="EVCIMEN",
    age_range=(22, 65),
    occupations=[("homemaker", 0.4), ("remote_worker", 0.3), ("retired", 0.15), ("freelancer", 0.15)],
    weekday_work_prob=0.5,
    means={
        "wake_hour": 8.0, "sleep_hour": 23.5, "sleep_duration_h": 8.0, "chronotype": -0.1,
        "work_intensity": 0.3, "study_intensity": 0.2, "exercise_propensity": 0.25,
        "gaming_propensity": 0.25, "content_consumption": 0.75, "social_need": 0.35,
        "explore_propensity": 0.1, "digital_addiction": 0.55, "routine_stability": 0.85,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.95,
        "mobility_radius_km": 2.0, "transit_pref_speed": 150, "screen_time_target_h": 6.0,
    },
    stds={
        "wake_hour": 0.8, "sleep_hour": 0.8, "sleep_duration_h": 0.8, "chronotype": 0.12,
        "work_intensity": 0.15, "study_intensity": 0.12, "exercise_propensity": 0.12,
        "gaming_propensity": 0.15, "content_consumption": 0.12, "social_need": 0.15,
        "explore_propensity": 0.08, "digital_addiction": 0.12, "routine_stability": 0.1,
        "weekday_weekend_delta": 0.1, "home_centeredness": 0.05,
        "mobility_radius_km": 1.0, "transit_pref_speed": 60, "screen_time_target_h": 1.5,
    },
    app_affinity=_cat({
        "video": 0.7, "streaming": 0.8, "messaging": 0.6, "shopping": 0.6,
        "reading": 0.5, "music": 0.5,
    }),
    app_overrides={"netflix": 1.6, "youtube": 1.4, "disney_plus": 1.3,
                   "trendyol": 1.6, "getir": 1.5, "kindle": 1.4,
                   "whatsapp": 1.4, "candy_crush": 1.3},
)

# 10. SEYYAH (Traveler / Explorer) -------------------------------------------
SEYYAH = PersonaPrior(
    name="Seyyah", persona_id="SEYYAH",
    age_range=(20, 45),
    occupations=[("freelancer", 0.4), ("photographer", 0.2), ("blogger", 0.2), ("professional", 0.2)],
    weekday_work_prob=0.6,
    means={
        "wake_hour": 7.5, "sleep_hour": 0.5, "sleep_duration_h": 7.0, "chronotype": 0.0,
        "work_intensity": 0.4, "study_intensity": 0.2, "exercise_propensity": 0.5,
        "gaming_propensity": 0.1, "content_consumption": 0.4, "social_need": 0.55,
        "explore_propensity": 0.95, "digital_addiction": 0.45, "routine_stability": 0.25,
        "weekday_weekend_delta": 0.2, "home_centeredness": 0.15,
        "mobility_radius_km": 30.0, "transit_pref_speed": 420, "screen_time_target_h": 5.0,
    },
    stds={
        "wake_hour": 1.0, "sleep_hour": 1.2, "sleep_duration_h": 0.9, "chronotype": 0.15,
        "work_intensity": 0.15, "study_intensity": 0.12, "exercise_propensity": 0.15,
        "gaming_propensity": 0.08, "content_consumption": 0.12, "social_need": 0.15,
        "explore_propensity": 0.05, "digital_addiction": 0.12, "routine_stability": 0.12,
        "weekday_weekend_delta": 0.12, "home_centeredness": 0.1,
        "mobility_radius_km": 8.0, "transit_pref_speed": 120, "screen_time_target_h": 1.3,
    },
    app_affinity=_cat({
        "navigation": 0.95, "photo": 0.9, "social": 0.6, "ride_share": 0.7,
        "music": 0.5, "reading": 0.3, "video": 0.4,
    }),
    app_overrides={"maps": 2.0, "yandex_maps": 1.4, "uber": 1.7, "bitaksi": 1.4,
                   "camera": 1.8, "instagram": 1.5, "gallery": 1.4,
                   "spotify": 1.3},
)

# 11. KRIZ_DUZENSIZ (Chaotic / Irregular) ------------------------------------
KRIZ_DUZENSIZ = PersonaPrior(
    name="Kriz / Düzensiz", persona_id="KRIZ_DUZENSIZ",
    age_range=(18, 55),
    occupations=[("unemployed", 0.4), ("freelancer", 0.3), ("gig_worker", 0.2), ("student", 0.1)],
    weekday_work_prob=0.4,
    means={
        "wake_hour": 11.0, "sleep_hour": 4.0, "sleep_duration_h": 6.0, "chronotype": 0.5,
        "work_intensity": 0.25, "study_intensity": 0.2, "exercise_propensity": 0.2,
        "gaming_propensity": 0.4, "content_consumption": 0.6, "social_need": 0.55,
        "explore_propensity": 0.35, "digital_addiction": 0.85, "routine_stability": 0.15,
        "weekday_weekend_delta": 0.15, "home_centeredness": 0.55,
        "mobility_radius_km": 8.0, "transit_pref_speed": 280, "screen_time_target_h": 7.5,
    },
    # NOTE: high stds — this persona is defined by *variance*
    stds={
        "wake_hour": 4.5, "sleep_hour": 4.0, "sleep_duration_h": 2.5, "chronotype": 0.4,
        "work_intensity": 0.25, "study_intensity": 0.2, "exercise_propensity": 0.25,
        "gaming_propensity": 0.3, "content_consumption": 0.25, "social_need": 0.3,
        "explore_propensity": 0.25, "digital_addiction": 0.15, "routine_stability": 0.08,
        "weekday_weekend_delta": 0.25, "home_centeredness": 0.25,
        "mobility_radius_km": 8.0, "transit_pref_speed": 200, "screen_time_target_h": 3.0,
    },
    app_affinity=_cat({
        "social": 0.7, "short_video": 0.7, "messaging": 0.6, "gaming": 0.4,
        "video": 0.6, "browser": 0.5,
    }),
    app_overrides={"tiktok": 1.5, "instagram": 1.3, "twitter": 1.3,
                   "youtube": 1.2, "reddit": 1.2},
)

# 12. HIBRIT (Mixed / Adaptive) ----------------------------------------------
# Modeled as a *blend* of other personas. We pick 2-3 random personas and average
# their priors at sampling time.

HIBRIT_BASE = PersonaPrior(
    name="Hibrit", persona_id="HIBRIT",
    age_range=(20, 45),
    occupations=[("professional", 0.35), ("student", 0.25), ("freelancer", 0.25), ("creative", 0.15)],
    weekday_work_prob=0.7,
    means={},  # filled per sample by blending other personas
    stds={},
    app_affinity=_BASE_CATS,
    blend={},  # populated at sample time
)


# ============================================================================
# 4. PERSONA REGISTRY
# ============================================================================

PERSONAS: Dict[str, PersonaPrior] = {
    "GECE_KUSU":       GECE_KUSU,
    "ERKENCI":         ERKENCI,
    "SOSYAL":          SOSYAL,
    "OYUNCU":          OYUNCU,
    "ICERIK_TUKETICI": ICERIK_TUKETICI,
    "SPORCU":          SPORCU,
    "OGRENCI":         OGRENCI,
    "PROFESYONEL":     PROFESYONEL,
    "EVCIMEN":         EVCIMEN,
    "SEYYAH":          SEYYAH,
    "KRIZ_DUZENSIZ":   KRIZ_DUZENSIZ,
    "HIBRIT":          HIBRIT_BASE,
}

# Distribution used when randomly assigning personas to a population.
# Tuned roughly to a realistic urban smartphone-user mix.
PERSONA_POPULATION_WEIGHTS: Dict[str, float] = {
    "PROFESYONEL":     0.18,
    "OGRENCI":         0.13,
    "SOSYAL":          0.12,
    "ICERIK_TUKETICI": 0.11,
    "EVCIMEN":         0.09,
    "GECE_KUSU":       0.08,
    "ERKENCI":         0.07,
    "OYUNCU":          0.06,
    "SPORCU":          0.05,
    "SEYYAH":          0.04,
    "KRIZ_DUZENSIZ":   0.04,
    "HIBRIT":          0.03,
}


def sample_persona_id(rng: random.Random | None = None) -> str:
    """Pick a persona id according to PERSONA_POPULATION_WEIGHTS."""
    rng = rng or random
    ids = list(PERSONA_POPULATION_WEIGHTS.keys())
    weights = list(PERSONA_POPULATION_WEIGHTS.values())
    return rng.choices(ids, weights=weights, k=1)[0]


def make_user_profile(persona_id: str | None = None) -> UserProfile:
    """Top-level convenience: pick a persona and return a sampled UserProfile."""
    if persona_id is None:
        persona_id = sample_persona_id()
    if persona_id == "HIBRIT":
        return _sample_hibrit_profile()
    prior = PERSONAS[persona_id]
    return sample_user_profile(prior)


def _sample_hibrit_profile() -> UserProfile:
    """
    HIBRIT = blend 2-3 source personas, average their numeric means weighted by
    a Dirichlet-ish weight vector. The result still varies because we sample
    around the blended means.
    """
    candidates = [
        "PROFESYONEL", "OGRENCI", "SOSYAL", "ICERIK_TUKETICI",
        "EVCIMEN", "SPORCU", "GECE_KUSU", "SEYYAH",
    ]
    k = np.random.choice([2, 3])
    chosen = list(np.random.choice(candidates, size=k, replace=False))
    weights = np.random.dirichlet(np.ones(k))

    blend = {pid: float(w) for pid, w in zip(chosen, weights)}

    # Build blended numeric means/stds
    blended_means: Dict[str, float] = {}
    blended_stds: Dict[str, float] = {}
    for trait in NUMERIC_TRAITS:
        m_acc = 0.0
        s_acc = 0.0
        for pid, w in blend.items():
            p = PERSONAS[pid]
            m_acc += w * p.means.get(trait, 0.5)
            s_acc += w * p.stds.get(trait, 0.1)
        blended_means[trait] = m_acc
        # Hibrits get extra noise (they're adaptive)
        blended_stds[trait] = s_acc * 1.3

    # Blended app affinity & overrides
    blended_aff: Dict[str, float] = {}
    blended_over: Dict[str, float] = {}
    for pid, w in blend.items():
        p = PERSONAS[pid]
        for cat, val in p.app_affinity.items():
            blended_aff[cat] = blended_aff.get(cat, 0.0) + w * val
        for app, val in p.app_overrides.items():
            blended_over[app] = blended_over.get(app, 0.0) + w * val

    blended_prior = PersonaPrior(
        name="Hibrit",
        persona_id="HIBRIT",
        age_range=HIBRIT_BASE.age_range,
        occupations=HIBRIT_BASE.occupations,
        weekday_work_prob=HIBRIT_BASE.weekday_work_prob,
        means=blended_means,
        stds=blended_stds,
        app_affinity=blended_aff,
        app_overrides=blended_over,
        blend=blend,
    )
    return sample_user_profile(blended_prior)
