"""
Context-Aware Recommendation API
=================================
Reads GPS, app-session, and screen-event data from Supabase,
runs the same feature-engineering pipeline used during training,
and classifies the user with the pre-trained CatBoost model.
"""

from __future__ import annotations

import json
import logging
import math as _math
import os
import sys
import time as _time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import httpx
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s | %(message)s")
logger = logging.getLogger("caers.api")

# ─────────────────────────────────────────── paths ───────────────────────────

_API_DIR     = Path(__file__).resolve().parent
_MODEL_DIR   = _API_DIR / "model"
_MODEL_FILE  = _MODEL_DIR / "catboost_persona.cbm"
_ENCODER_FILE= _MODEL_DIR / "label_encoder.json"
_FEATURES_FILE = _MODEL_DIR / "feature_columns.json"

from feature_engineering import extract_user_features  # noqa: E402
from episodes import compute_episode_shares  # noqa: E402

# ─────────────────────────────────────────── load model ──────────────────────

_model = CatBoostClassifier()
_model.load_model(str(_MODEL_FILE))

with open(_ENCODER_FILE) as f:
    _label_classes: list[str] = json.load(f)["classes"]

with open(_FEATURES_FILE) as f:
    _feature_columns: list[str] = json.load(f)

# ─────────────────────────────────────────── Supabase REST ───────────────────

SUPABASE_URL = os.environ["SUPABASE_URL"].strip()
SUPABASE_KEY = (os.environ.get("SUPABASE_SERVICE_KEY") or os.environ["SUPABASE_ANON_KEY"]).strip()
print(f"[startup] SUPABASE_URL={SUPABASE_URL!r}", flush=True)
GOOGLE_PLACES_KEY = os.environ.get("GOOGLE_PLACES_API_KEY", "")
# Local LLM via Ollama — run: ollama pull qwen2.5:14b && ollama serve
MISTRAL_URL = os.environ.get("MISTRAL_URL", "http://localhost:11434")
LLM_MODEL   = os.environ.get("LLM_MODEL", "qwen2.5:14b")
_SUPA_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def _supa_rpc(fn_name: str, params: dict) -> list[dict]:
    with httpx.Client(timeout=10) as client:
        resp = client.post(
            f"{SUPABASE_URL}/rest/v1/rpc/{fn_name}",
            headers=_SUPA_HEADERS,
            json=params,
        )
        if resp.status_code == 200:
            return resp.json() or []
        logger.warning("[supa_rpc] %s status=%s body=%s", fn_name, resp.status_code, resp.text[:200])
        return []


def _supa_get(table: str, params: dict) -> list[dict]:
    with httpx.Client(timeout=15) as client:
        resp = client.get(
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_SUPA_HEADERS,
            params=params,
        )
        if resp.status_code == 200:
            return resp.json() or []
        logger.warning("[supa_get] %s status=%s body=%s", table, resp.status_code, resp.text[:300])
        return []

# ─────────────────────────────────────────── Google Places ───────────────────

_PLACES_URL = "https://places.googleapis.com/v1/places:searchNearby"
_PLACES_FIELD_MASK = (
    "places.id,places.displayName,places.types,"
    "places.location,places.shortFormattedAddress,places.rating"
)

# Venue types each persona prefers (Google Places New API type strings)
_PERSONA_PLACE_TYPES: dict[str, list[str]] = {
    "EARLY_BIRD":        ["cafe", "park", "gym", "bakery", "restaurant"],
    "HOMEBODY":          ["cafe", "restaurant", "book_store", "library", "park"],
    "NIGHT_OWL":         ["bar", "night_club", "restaurant", "movie_theater", "cafe"],
    "HYBRID":            ["cafe", "restaurant", "park", "museum", "bar"],
    "CONTENT_CONSUMER":  ["movie_theater", "museum", "library", "cafe", "art_gallery"],
    "IRREGULAR":         ["cafe", "park", "restaurant", "book_store", "spa"],
    "STUDENT":           ["library", "cafe", "book_store", "museum", "park"],
    "GAMER":             ["cafe", "restaurant", "park", "shopping_mall", "movie_theater"],
    "PROFESSIONAL":      ["restaurant", "cafe", "bar", "museum", "performing_arts_theater"],
    "TRAVELER":          ["park", "museum", "tourist_attraction", "art_gallery", "performing_arts_theater"],
    "SOCIAL":            ["restaurant", "bar", "cafe", "performing_arts_theater", "park"],
    "ATHLETE":           ["gym", "park", "sports_complex", "restaurant", "cafe"],
}

# Broad type list used for all nearby searches — persona filtering happens in the LLM
_ALL_PLACE_TYPES: list[str] = list({
    t for types in _PERSONA_PLACE_TYPES.values() for t in types
})

_TYPE_TO_CATEGORY: dict[str, str] = {
    "cafe": "Recharge", "coffee_shop": "Recharge", "restaurant": "Recharge",
    "bakery": "Recharge", "shopping_mall": "Recharge",
    "bar": "Social", "night_club": "Social", "performing_arts_theater": "Social",
    "park": "Movement", "tourist_attraction": "Movement", "hiking_area": "Movement",
    "gym": "Health", "sports_complex": "Health", "fitness_center": "Health",
    "museum": "Learning", "art_gallery": "Learning", "library": "Learning",
    "movie_theater": "Learning", "book_store": "Learning",
}

_TYPE_TO_TAGS: dict[str, list[str]] = {
    "cafe": ["Cafe", "Drinks"], "coffee_shop": ["Cafe", "Coffee"],
    "restaurant": ["Food", "Restaurant"], "bakery": ["Bakery", "Sweets"],
    "bar": ["Bar", "Social"], "night_club": ["Night", "Music"],
    "performing_arts_theater": ["Theater", "Culture"],
    "park": ["Park", "Outdoors"],
    "gym": ["Sports", "Fitness"], "sports_complex": ["Sports", "Active"],
    "museum": ["Museum", "Culture"], "art_gallery": ["Art", "Gallery"],
    "library": ["Library", "Quiet"], "movie_theater": ["Cinema", "Film"],
    "book_store": ["Bookstore", "Reading"], "shopping_mall": ["Mall", "Shopping"],
    "tourist_attraction": ["Explore", "Sightseeing"],
}

_CATEGORY_TO_PREF_KEY: dict[str, str] = {
    "Recharge": "food", "Social": "social",
    "Movement": "outdoor", "Health": "outdoor", "Learning": "culture",
}


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    dlat = _math.radians(lat2 - lat1)
    dlon = _math.radians(lon2 - lon1)
    a = (
        _math.sin(dlat / 2) ** 2
        + _math.cos(_math.radians(lat1))
        * _math.cos(_math.radians(lat2))
        * _math.sin(dlon / 2) ** 2
    )
    return 2 * 6371.0 * _math.asin(_math.sqrt(a))


_MAJOR_CITIES: list[tuple[str, float, float]] = [
    ("Istanbul", 41.0082, 28.9784),
    ("Ankara",   39.9334, 32.8597),
    ("Izmir",    38.4192, 27.1287),
    ("Bursa",    40.1826, 29.0665),
    ("Antalya",  36.8969, 30.7133),
    ("Kocaeli",  40.7654, 29.9408),
    ("Adana",    37.0000, 35.3213),
]

def _nearest_city(lat: float, lon: float) -> str:
    return min(_MAJOR_CITIES, key=lambda c: _haversine_km(lat, lon, c[1], c[2]))[0]


def _fetch_google_places(lat: float, lon: float) -> list[dict]:
    if not GOOGLE_PLACES_KEY:
        return []
    try:
        with httpx.Client(timeout=10) as client:
            resp = client.post(
                _PLACES_URL,
                json={
                    "locationRestriction": {
                        "circle": {
                            "center": {"latitude": lat, "longitude": lon},
                            "radius": 1500.0,
                        }
                    },
                    "includedTypes": _ALL_PLACE_TYPES,
                    "maxResultCount": 10,
                    "rankPreference": "DISTANCE",
                },
                headers={
                    "Content-Type": "application/json",
                    "X-Goog-Api-Key": GOOGLE_PLACES_KEY,
                    "X-Goog-FieldMask": _PLACES_FIELD_MASK,
                },
            )
        if resp.status_code == 200:
            return resp.json().get("places", [])
    except Exception:
        pass
    return []


def _place_to_suggestion(
    place: dict,
    user_lat: float,
    user_lon: float,
    meta: dict,
    idx: int,
    now_str: str,
) -> Optional[SuggestionResponse]:
    try:
        name = (place.get("displayName") or {}).get("text", "")
        if not name:
            return None

        loc = place.get("location") or {}
        place_lat = float(loc.get("latitude", 0))
        place_lon = float(loc.get("longitude", 0))
        distance_km = _haversine_km(user_lat, user_lon, place_lat, place_lon)

        types: list[str] = place.get("types") or []
        category = next(
            (_TYPE_TO_CATEGORY[t] for t in types if t in _TYPE_TO_CATEGORY),
            "Recharge",
        )
        tags = next(
            (_TYPE_TO_TAGS[t] for t in types if t in _TYPE_TO_TAGS),
            [],
        )
        address = place.get("shortFormattedAddress") or ""
        rating = place.get("rating")
        rating_str = f" — {rating:.1f}★" if rating else ""

        walking_min = max(1, int((distance_km / 5.0) * 60))

        pref_key = _CATEGORY_TO_PREF_KEY.get(category, "food")
        pref_score = meta["preferences"].get(pref_key, 0.5)

        rationale = (
            f"{distance_km:.1f} km away{rating_str}. "
            f"This type of venue matches your profile {int(pref_score * 100)}%."
        )

        return SuggestionResponse(
            id=f"place_{place.get('id', str(idx))}",
            title=name,
            description=address or name,
            rationale=rationale,
            category=category,
            distance=round(distance_km, 1),
            estimated_minutes=walking_min,
            address=address or None,
            latitude=place_lat,
            longitude=place_lon,
            tags=tags,
            created_at=now_str,
        )
    except Exception:
        return None


# ─────────────────────────────────────────── persona catalogue ───────────────
# Each persona class from the model maps to human-readable traits,
# preferences, and event recommendations.

_PERSONA_META: dict[str, dict[str, Any]] = {
    "EARLY_BIRD": {
        "display": "Early Bird",
        "traits": [
            {"label": "Morning Active", "confidence": 0.90},
            {"label": "Disciplined", "confidence": 0.85},
            {"label": "Productivity-Focused", "confidence": 0.80},
        ],
        "preferences": {"outdoor": 0.7, "culture": 0.6, "social": 0.5, "food": 0.5},
        "recommendations": [
            {"category": "Movement", "title": "Morning Run",
             "description": "Start your day energetically — 20-30 minutes of early morning jogging.",
             "rationale": "Your morning activity pattern shows high energy in the early hours.",
             "tags": ["Morning", "Running", "Energy"], "estimated_minutes": 30},
            {"category": "Learning", "title": "Morning Learning Session",
             "description": "Start the day with a podcast, language app, or online course.",
             "rationale": "Your productive morning profile is ideal for learning.",
             "tags": ["Morning", "Learning", "Growth"], "estimated_minutes": 20},
            {"category": "Recharge", "title": "Coffee Ritual",
             "description": "Quietly enjoy your coffee at your favorite cafe and prepare for the day.",
             "rationale": "Your morning routine is perfect for a structured start.",
             "tags": ["Coffee", "Morning", "Routine"], "estimated_minutes": 25},
        ],
    },
    "HOMEBODY": {
        "display": "Homebody",
        "traits": [
            {"label": "Home-Centered", "confidence": 0.90},
            {"label": "Introverted", "confidence": 0.82},
            {"label": "Calm Lifestyle", "confidence": 0.78},
        ],
        "preferences": {"food": 0.7, "culture": 0.6, "outdoor": 0.3, "social": 0.4},
        "recommendations": [
            {"category": "Recharge", "title": "Nearby Cafe",
             "description": "Take a break at a quiet cafe close to home.",
             "rationale": "Your tendency to stay close to home fits local venues perfectly.",
             "tags": ["Cafe", "Nearby", "Quiet"], "estimated_minutes": 40},
            {"category": "Learning", "title": "Online Workshop",
             "description": "Register for an online workshop you can join from home.",
             "rationale": "Your home-centered lifestyle is best suited for online events.",
             "tags": ["Online", "Learning", "Home"], "estimated_minutes": 60},
            {"category": "Movement", "title": "Neighborhood Walk",
             "description": "A short walk for some fresh air — 20 minutes is enough.",
             "rationale": "Small but regular movement keeps your balance.",
             "tags": ["Walk", "Nearby", "Daily"], "estimated_minutes": 20},
        ],
    },
    "NIGHT_OWL": {
        "display": "Night Owl",
        "traits": [
            {"label": "Night Active", "confidence": 0.90},
            {"label": "Spontaneous", "confidence": 0.80},
            {"label": "Social at Night", "confidence": 0.72},
        ],
        "preferences": {"social": 0.8, "culture": 0.7, "food": 0.8, "outdoor": 0.3},
        "recommendations": [
            {"category": "Social", "title": "Live Music Event",
             "description": "Head to a live music venue or concert hall.",
             "rationale": "Your high nighttime activity is a great match for music events.",
             "tags": ["Music", "Night", "Live"], "estimated_minutes": 150},
            {"category": "Recharge", "title": "Late-Night Cafe",
             "description": "Sit at a quiet cafe that stays open late.",
             "rationale": "Your night profile shows a preference for being active in late hours.",
             "tags": ["Night", "Cafe", "Quiet"], "estimated_minutes": 60},
            {"category": "Social", "title": "Night Market",
             "description": "Visit a night market or street food event.",
             "rationale": "A great fit for your weekend nighttime activity pattern.",
             "tags": ["Market", "Food", "Explore"], "estimated_minutes": 90},
        ],
    },
    "HYBRID": {
        "display": "Hybrid User",
        "traits": [
            {"label": "Balanced", "confidence": 0.80},
            {"label": "Adaptive", "confidence": 0.75},
            {"label": "Versatile", "confidence": 0.70},
        ],
        "preferences": {"outdoor": 0.6, "culture": 0.6, "social": 0.6, "food": 0.6},
        "recommendations": [
            {"category": "Social", "title": "Community Event",
             "description": "Join a community meetup nearby.",
             "rationale": "Your balanced and versatile profile fits community events well.",
             "tags": ["Community", "Social", "Local"], "estimated_minutes": 90},
            {"category": "Movement", "title": "City Exploration",
             "description": "Take a short walk through a neighborhood you've never visited.",
             "rationale": "Your flexible movement profile suits exploration activities.",
             "tags": ["Walk", "Explore", "City"], "estimated_minutes": 45},
            {"category": "Recharge", "title": "Try a New Cafe",
             "description": "Visit a new cafe or restaurant nearby.",
             "rationale": "New experiences are ideal for a balanced profile.",
             "tags": ["Cafe", "New", "Relax"], "estimated_minutes": 40},
        ],
    },
    "CONTENT_CONSUMER": {
        "display": "Content Consumer",
        "traits": [
            {"label": "Digitally-Focused", "confidence": 0.90},
            {"label": "Media Lover", "confidence": 0.85},
            {"label": "Comfortable at Home", "confidence": 0.78},
        ],
        "preferences": {"culture": 0.9, "food": 0.6, "outdoor": 0.3, "social": 0.5},
        "recommendations": [
            {"category": "Learning", "title": "Film / Documentary Festival",
             "description": "Go to a nearby cinema or documentary screening.",
             "rationale": "Your high media consumption rate is a great match for film events.",
             "tags": ["Film", "Cinema", "Culture"], "estimated_minutes": 120},
            {"category": "Recharge", "title": "Book Club",
             "description": "Join a book club meeting.",
             "rationale": "Your content consumption profile aligns well with book clubs.",
             "tags": ["Books", "Culture", "Social"], "estimated_minutes": 90},
            {"category": "Movement", "title": "Short Fresh-Air Walk",
             "description": "Step away from the screen and get outside for 20 minutes.",
             "rationale": "A short walk after long screen sessions restores energy.",
             "tags": ["Walk", "Fresh Air", "Break"], "estimated_minutes": 20},
        ],
    },
    "IRREGULAR": {
        "display": "Irregular",
        "traits": [
            {"label": "Variable Rhythm", "confidence": 0.82},
            {"label": "High Stress", "confidence": 0.75},
            {"label": "Impulsive Decisions", "confidence": 0.70},
        ],
        "preferences": {"outdoor": 0.5, "food": 0.7, "social": 0.5, "culture": 0.4},
        "recommendations": [
            {"category": "Recharge", "title": "Meditation / Breathing Exercise",
             "description": "Try a 5-10 minute guided meditation.",
             "rationale": "Your irregular activity pattern indicates a need for stress-reducing activities.",
             "tags": ["Meditation", "Breathing", "Calm"], "estimated_minutes": 10},
            {"category": "Movement", "title": "Short Walk Break",
             "description": "Walk for 10 minutes every two hours.",
             "rationale": "Small regular breaks boost energy and focus.",
             "tags": ["Walk", "Break", "Routine"], "estimated_minutes": 10},
            {"category": "Recharge", "title": "Quiet Cafe Break",
             "description": "Sit in a calm environment and gather your thoughts.",
             "rationale": "Your irregular pattern benefits from quiet, structured environments.",
             "tags": ["Cafe", "Quiet", "Reset"], "estimated_minutes": 30},
        ],
    },
    "STUDENT": {
        "display": "Student",
        "traits": [
            {"label": "Learning-Focused", "confidence": 0.90},
            {"label": "Curious", "confidence": 0.85},
            {"label": "Budget-Conscious", "confidence": 0.75},
        ],
        "preferences": {"culture": 0.9, "outdoor": 0.6, "social": 0.7, "food": 0.5},
        "recommendations": [
            {"category": "Learning", "title": "Library or Study Space",
             "description": "Go to a quiet library or study area nearby.",
             "rationale": "A free study environment perfect for your student profile.",
             "tags": ["Library", "Study", "Free"], "estimated_minutes": 120},
            {"category": "Social", "title": "Campus / Student Event",
             "description": "Join a nearby student club or workshop event.",
             "rationale": "Your social and learning-focused profile fits these events perfectly.",
             "tags": ["Student", "Social", "Network"], "estimated_minutes": 90},
            {"category": "Recharge", "title": "Budget-Friendly Cafe Break",
             "description": "Take a break at an affordable cafe.",
             "rationale": "Short breaks after intense study sessions increase productivity.",
             "tags": ["Cafe", "Affordable", "Break"], "estimated_minutes": 30},
        ],
    },
    "GAMER": {
        "display": "Gamer",
        "traits": [
            {"label": "Gaming Enthusiast", "confidence": 0.92},
            {"label": "Competitive", "confidence": 0.85},
            {"label": "Digitally Social", "confidence": 0.78},
        ],
        "preferences": {"social": 0.7, "culture": 0.5, "outdoor": 0.3, "food": 0.6},
        "recommendations": [
            {"category": "Social", "title": "Gaming Cafe / Tournament",
             "description": "Join a tournament at a nearby gaming cafe or play with friends.",
             "rationale": "Your high gaming profile is a great fit for social gaming environments.",
             "tags": ["Gaming", "Tournament", "Social"], "estimated_minutes": 120},
            {"category": "Movement", "title": "Digital Detox Walk",
             "description": "30 minutes of outdoor walking to step away from screens.",
             "rationale": "Physical activity after long gaming sessions is beneficial.",
             "tags": ["Walk", "Detox", "Outdoors"], "estimated_minutes": 30},
            {"category": "Social", "title": "Board Game Event",
             "description": "Play face-to-face games at a board game cafe.",
             "rationale": "A chance to bring your social gaming side into an in-person activity.",
             "tags": ["Board Game", "Social", "Fun"], "estimated_minutes": 90},
        ],
    },
    "PROFESSIONAL": {
        "display": "Professional",
        "traits": [
            {"label": "Career-Focused", "confidence": 0.90},
            {"label": "Efficient", "confidence": 0.88},
            {"label": "Networker", "confidence": 0.80},
        ],
        "preferences": {"culture": 0.8, "social": 0.7, "food": 0.6, "outdoor": 0.4},
        "recommendations": [
            {"category": "Social", "title": "Networking Event",
             "description": "Attend a networking event or conference relevant to your field.",
             "rationale": "Your professional activity pattern is a strong match for these events.",
             "tags": ["Network", "Career", "Professional"], "estimated_minutes": 120},
            {"category": "Recharge", "title": "Lunch Break — Restaurant",
             "description": "Have a quality lunch with colleagues or on your own.",
             "rationale": "Regular breaks are essential for sustained productivity.",
             "tags": ["Food", "Break", "Energy"], "estimated_minutes": 60},
            {"category": "Learning", "title": "Industry Podcast / Webinar",
             "description": "Listen to industry content during your commute.",
             "rationale": "Make the most of your commute time for professional development.",
             "tags": ["Podcast", "Learning", "Commute"], "estimated_minutes": 30},
        ],
    },
    "TRAVELER": {
        "display": "Traveler",
        "traits": [
            {"label": "Active Explorer", "confidence": 0.92},
            {"label": "Discovery-Driven", "confidence": 0.88},
            {"label": "Outdoors Lover", "confidence": 0.85},
        ],
        "preferences": {"outdoor": 0.95, "culture": 0.80, "food": 0.70, "social": 0.60},
        "recommendations": [
            {"category": "Movement", "title": "City Discovery Tour",
             "description": "Detailed exploration walk through a neighborhood you've never visited.",
             "rationale": "Your high mobility radius and varied location history signal an explorer profile.",
             "tags": ["Explore", "Walk", "City"], "estimated_minutes": 90},
            {"category": "Health", "title": "Nature Hike",
             "description": "Nature hike or cycling tour outside the city.",
             "rationale": "Your high daily distance and movement profile are ideal for outdoor activities.",
             "tags": ["Nature", "Cycling", "Active"], "estimated_minutes": 120},
            {"category": "Social", "title": "Travel Community",
             "description": "Join a travel or hiking group in your city.",
             "rationale": "Your active and social profile is a great fit for these groups.",
             "tags": ["Group", "Travel", "Social"], "estimated_minutes": 90},
        ],
    },
    "SOCIAL": {
        "display": "Social Butterfly",
        "traits": [
            {"label": "Social & Extroverted", "confidence": 0.92},
            {"label": "Event Lover", "confidence": 0.88},
            {"label": "Networker", "confidence": 0.80},
        ],
        "preferences": {"social": 0.95, "culture": 0.80, "food": 0.75, "outdoor": 0.50},
        "recommendations": [
            {"category": "Social", "title": "Social Event / Meetup",
             "description": "Join a meetup with friends or a new social gathering.",
             "rationale": "Your high social media and social app usage indicates an extroverted profile.",
             "tags": ["Social", "Meetup", "Fun"], "estimated_minutes": 120},
            {"category": "Social", "title": "Art Gallery / Exhibition",
             "description": "Visit an art gallery or exhibition.",
             "rationale": "Your social and cultural profile fits these events well.",
             "tags": ["Art", "Culture", "Social"], "estimated_minutes": 90},
            {"category": "Movement", "title": "Group Walk",
             "description": "Join a city walking group.",
             "rationale": "Combining social activities with movement is ideal for your profile.",
             "tags": ["Group", "Walk", "Social"], "estimated_minutes": 60},
        ],
    },
    "ATHLETE": {
        "display": "Athlete",
        "traits": [
            {"label": "Sports Enthusiast", "confidence": 0.95},
            {"label": "Health-Focused", "confidence": 0.90},
            {"label": "Disciplined", "confidence": 0.85},
        ],
        "preferences": {"outdoor": 0.95, "health": 0.95, "food": 0.65, "social": 0.55},
        "recommendations": [
            {"category": "Health", "title": "Morning Workout",
             "description": "Running, cycling, or gym training.",
             "rationale": "Your fitness app usage and high movement profile confirm an athlete identity.",
             "tags": ["Workout", "Morning", "Fitness"], "estimated_minutes": 60},
            {"category": "Health", "title": "Sports Club / Group Class",
             "description": "Join a sports club or group fitness class.",
             "rationale": "Your active lifestyle is a great fit for group sports.",
             "tags": ["Sports Club", "Group", "Social"], "estimated_minutes": 60},
            {"category": "Recharge", "title": "Athlete Nutrition",
             "description": "Eat at an organic or healthy restaurant.",
             "rationale": "An active lifestyle is completed with proper nutrition.",
             "tags": ["Healthy", "Nutrition", "Recovery"], "estimated_minutes": 45},
        ],
    },
}

# ─────────────────────────────────────────── FastAPI ─────────────────────────

from contextlib import asynccontextmanager  # noqa: E402

@asynccontextmanager
async def lifespan(app):
    from apscheduler.schedulers.background import BackgroundScheduler
    from event_scraper import ensure_demo_events, scrape_all_cities
    import threading

    # Seed demo events immediately if table is sparse (no external API needed)
    threading.Thread(target=ensure_demo_events, daemon=True).start()

    interval_h = int(os.environ.get("SCRAPER_INTERVAL_HOURS", "6"))
    scheduler = BackgroundScheduler()
    scheduler.add_job(scrape_all_cities, "interval", hours=interval_h, id="event_scraper")
    scheduler.start()
    logger.info("[scheduler] event scraper started — interval=%dh", interval_h)
    yield
    scheduler.shutdown(wait=False)
    logger.info("[scheduler] stopped")


app = FastAPI(title="Context-Aware Recommendation API", version="2.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────── Pydantic models ─────────────────

class PersonaTrait(BaseModel):
    label: str
    confidence: float

class PersonaResponse(BaseModel):
    persona_id: str
    persona_name: str
    traits: list[PersonaTrait]
    preferences: dict[str, float]
    last_updated: str
    signals_processed_today: int

class SuggestionResponse(BaseModel):
    id: str
    title: str
    description: str
    rationale: str
    category: str
    distance: Optional[float] = None
    estimated_minutes: Optional[int] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    tags: list[str] = []
    weather: Optional[str] = None
    created_at: str

# ─────────────────────────────────────────── timezone helpers ────────────────

def _compute_tz_offset(gps_df: pd.DataFrame) -> int:
    """Return the user's UTC offset in whole hours using GPS coordinates.
    Uses timezonefinder for exact lookup; falls back to longitude estimate."""
    if gps_df.empty or "latitude" not in gps_df.columns or "longitude" not in gps_df.columns:
        return 0
    try:
        from timezonefinder import TimezoneFinder
        import pytz
        tf = TimezoneFinder()
        lat = float(gps_df["latitude"].median())
        lon = float(gps_df["longitude"].median())
        tz_name = tf.timezone_at(lat=lat, lng=lon)
        if tz_name:
            tz = pytz.timezone(tz_name)
            now_utc = datetime.now(timezone.utc)
            offset_td = tz.utcoffset(now_utc.replace(tzinfo=None))
            return int(offset_td.total_seconds() // 3600)
    except Exception:
        pass
    # Longitude-based fallback (±1h accuracy)
    median_lon = float(gps_df["longitude"].median())
    return max(-12, min(14, round(median_lon / 15.0)))


def _apply_tz_to_apps(apps: pd.DataFrame, tz_offset: int) -> pd.DataFrame:
    """Shift hour and weekday columns to local time for circadian features."""
    if apps.empty or tz_offset == 0:
        return apps
    apps = apps.copy()
    local_ts = apps["timestamp"] + pd.Timedelta(hours=tz_offset)
    apps["hour"]    = local_ts.dt.hour
    apps["weekday"] = local_ts.dt.weekday
    return apps


# ─────────────────────────────────────────── persona cache (users table) ─────

_PERSONA_CACHE_TTL_H = 24  # re-classify after this many hours


def _load_persona_cache(user_id: str) -> Optional[tuple[str, dict, dict]]:
    """Return (persona_class, meta, context) from users.persona_json if fresh, else None."""
    rows = _supa_get("users", {
        "id": f"eq.{user_id}",
        "select": "persona_json,persona_updated_at",
    })
    if not rows or not rows[0].get("persona_json") or not rows[0].get("persona_updated_at"):
        return None
    try:
        updated_at = datetime.fromisoformat(rows[0]["persona_updated_at"].replace("Z", "+00:00"))
        age_h = (datetime.now(timezone.utc) - updated_at).total_seconds() / 3600
        if age_h > _PERSONA_CACHE_TTL_H:
            return None
        pj = rows[0]["persona_json"]
        persona_class = pj["persona_id"]
        meta = _PERSONA_META.get(persona_class, _PERSONA_META["HYBRID"])
        ctx = pj.get("context", {})
        logger.info("[persona_cache] HIT for %s — persona=%s age=%.1fh", user_id, persona_class, age_h)
        return persona_class, meta, ctx
    except Exception as e:
        logger.warning("[persona_cache] parse error: %s", e)
        return None


def _save_persona_cache(user_id: str, persona_class: str, signals_today: int, ctx: dict) -> None:
    """Write persona result to users.persona_json and persona_updated_at."""
    meta = _PERSONA_META.get(persona_class, _PERSONA_META["HYBRID"])
    now_str = datetime.now(timezone.utc).isoformat()
    payload = {
        "persona_id": persona_class,
        "persona_name": meta["display"],
        "traits": meta["traits"],
        "preferences": meta["preferences"],
        "signals_today": signals_today,
        "context": ctx,
        "classified_at": now_str,
    }
    try:
        with httpx.Client(timeout=10) as client:
            resp = client.patch(
                f"{SUPABASE_URL}/rest/v1/users",
                headers=_SUPA_HEADERS,
                params={"id": f"eq.{user_id}"},
                json={"persona_json": payload, "persona_updated_at": now_str},
            )
        if resp.status_code in (200, 204):
            logger.info("[persona_cache] WRITE %s → %s", user_id, persona_class)
        else:
            logger.warning("[persona_cache] PATCH failed status=%s body=%s", resp.status_code, resp.text[:300])
    except Exception as e:
        logger.warning("[persona_cache] write failed: %s", e)


# ─────────────────────────────────────────── data fetching ───────────────────

def _fetch_gps(user_id: str, since: Optional[datetime] = None) -> pd.DataFrame:
    params: dict = {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "2016",
        "select": "timestamp,latitude,longitude,speed_mps,movement_state,dwell_time_s",
    }
    if since is not None:
        params["timestamp"] = f"gte.{since.isoformat()}"
        params["limit"] = "500"
    rows = _supa_get("gps_pings", params)
    return pd.DataFrame(rows) if rows else pd.DataFrame()


def _fetch_app_sessions(user_id: str, since: Optional[datetime] = None) -> pd.DataFrame:
    params: dict = {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "5000",
        "select": "timestamp,app_name,category,duration_min",
    }
    if since is not None:
        params["timestamp"] = f"gte.{since.isoformat()}"
        params["limit"] = "200"
    rows = _supa_get("app_sessions", params)
    if not rows:
        return pd.DataFrame()
    df = pd.DataFrame(rows)
    df = df.rename(columns={"app_name": "app"})
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
    df["hour"] = df["timestamp"].dt.hour
    df["weekday"] = df["timestamp"].dt.weekday
    return df


def _fetch_screen_events(user_id: str, since: Optional[datetime] = None) -> pd.DataFrame:
    params: dict = {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "10000",
        "select": "timestamp,event_type",
    }
    if since is not None:
        params["timestamp"] = f"gte.{since.isoformat()}"
        params["limit"] = "500"
    rows = _supa_get("screen_events", params)
    return pd.DataFrame(rows) if rows else pd.DataFrame()

# ─────────────────────────────────────────── real-time context ───────────────

def _build_realtime_context(user_id: str) -> dict:
    """Last-1-hour snapshot — always computed fresh, never cached."""
    since = datetime.now(timezone.utc) - timedelta(hours=1)
    gps    = _fetch_gps(user_id, since=since)
    apps   = _fetch_app_sessions(user_id, since=since)
    screen = _fetch_screen_events(user_id, since=since)

    ctx: dict = {}

    # Movement pattern + distance
    if not gps.empty:
        gps["ts"] = pd.to_datetime(gps["timestamp"], utc=True, errors="coerce")
        gps = gps.sort_values("ts")
        dist = 0.0
        for i in range(1, len(gps)):
            dist += _haversine_km(
                float(gps.iloc[i - 1]["latitude"]), float(gps.iloc[i - 1]["longitude"]),
                float(gps.iloc[i]["latitude"]),     float(gps.iloc[i]["longitude"]),
            )
        ctx["distance_last_hour_km"] = round(dist, 2)
        if "movement_state" in gps.columns:
            dominant = gps["movement_state"].value_counts().idxmax()
            ctx["movement_pattern"] = (
                "transit"    if dominant in ("vehicle", "transit") else
                "moving"     if dominant in ("walking", "cycling") else
                "stationary"
            )
        else:
            ctx["movement_pattern"] = "stationary"
    else:
        ctx["distance_last_hour_km"] = 0.0
        ctx["movement_pattern"] = "unknown"

    # Top apps last hour
    if not apps.empty and "category" in apps.columns and "duration_min" in apps.columns:
        top = (apps.groupby("category")["duration_min"].sum()
               .sort_values(ascending=False).head(3))
        ctx["last_hour_top_apps"] = [
            {"category": cat, "minutes": round(float(mins), 1)}
            for cat, mins in top.items()
        ]
    else:
        ctx["last_hour_top_apps"] = []

    # Screen activity
    if not screen.empty and "event_type" in screen.columns:
        ctx["screen_unlocks"] = int((screen["event_type"] == "unlock").sum())
    else:
        ctx["screen_unlocks"] = 0

    now = datetime.now(timezone.utc)
    ctx["is_weekend"] = now.weekday() >= 5

    return ctx


# ─────────────────────────────────────────── event fetching ──────────────────

# DB-valid categories: music, sports, culture, food, outdoor, workshop, family
_PERSONA_INTERESTS: dict[str, list[str]] = {
    "EARLY_BIRD":       ["sports", "outdoor", "food"],
    "HOMEBODY":         ["culture", "music", "workshop"],
    "NIGHT_OWL":        ["music", "culture", "food"],
    "HYBRID":           ["music", "culture", "sports", "food"],
    "CONTENT_CONSUMER": ["music", "culture"],
    "IRREGULAR":        ["workshop", "food", "sports"],
    "STUDENT":          ["workshop", "culture", "music"],
    "GAMER":            ["workshop", "food", "music"],
    "PROFESSIONAL":     ["workshop", "food", "culture"],
    "TRAVELER":         ["culture", "music", "outdoor", "workshop"],
    "SOCIAL":           ["music", "food", "workshop", "culture"],
    "ATHLETE":          ["sports", "outdoor", "food"],
}


def _fetch_nearby_events(lat: float, lon: float, persona_class: str) -> list[dict]:
    city = _nearest_city(lat, lon)
    interests = _PERSONA_INTERESTS.get(persona_class, ["music", "culture", "sports", "food"])
    return _supa_rpc("nearby_events", {
        "p_city": city,
        "p_interests": interests,
        "p_limit": 8,
    })


# ─────────────────────────────────────────── LLM (local Mistral / Ollama) ────

_LLM_SYSTEM = (
    "You are a personalized activity recommendation assistant. "
    "You will receive a user profile, real-time context, a list of nearby venues (V0, V1, ...) "
    "and upcoming events (E0, E1, ...). "
    "Select exactly 3 options and return ONLY a valid JSON array — no prose, no markdown, no explanation. "
    "Each object must include item_ref (e.g. V2 or E1), title, description, rationale, "
    "category, and estimated_minutes."
)

_MOV_LABELS = {
    "stationary": "Stationary", "walking": "Walking",
    "cycling": "Cycling", "transit": "On public transit",
    "vehicle": "In a vehicle",
}
_CAT_LABELS = {
    "social": "social media", "gaming": "gaming", "streaming": "streaming",
    "music": "music", "productivity": "work/productivity", "education": "education",
    "shopping": "shopping", "news": "news", "fitness": "fitness",
    "messaging": "messaging", "video": "video", "reading": "reading",
    "browser": "web browsing", "short_video": "short-form video",
}
_TIME_LABELS = [
    (0, 6, "Night"), (6, 9, "Early morning"), (9, 12, "Morning"),
    (12, 14, "Midday"), (14, 17, "Afternoon"), (17, 20, "Evening"),
    (20, 24, "Night"),
]


def _build_llm_prompt(
    persona_class: str,
    meta: dict,
    raw_places: list[dict],
    nearby_events: list[dict],
    realtime_ctx: dict,
    now: datetime,
) -> str:
    hour = now.hour
    time_label = next((l for a, b, l in _TIME_LABELS if a <= hour < b), "Night")
    day_type = "Weekend" if realtime_ctx.get("is_weekend") else "Weekday"

    traits_str = ", ".join(
        f"{t['label']} (%{int(t['confidence'] * 100)})" for t in meta["traits"]
    )
    prefs = meta["preferences"]
    prefs_str = (
        f"outdoor={prefs.get('outdoor', 0):.1f}, "
        f"social={prefs.get('social', 0):.1f}, "
        f"food={prefs.get('food', 0):.1f}, "
        f"culture={prefs.get('culture', 0):.1f}"
    )

    # Real-time context
    movement_pattern = realtime_ctx.get("movement_pattern", "unknown")
    dist_km = realtime_ctx.get("distance_last_hour_km", 0.0)
    top_apps = realtime_ctx.get("last_hour_top_apps", [])
    top_apps_str = ", ".join(
        f"{a['category']} ({int(a['minutes'])} min)" for a in top_apps
    ) or "no data"
    unlocks = realtime_ctx.get("screen_unlocks", 0)

    # Venues prefixed V0, V1… — Events prefixed E0, E1…
    places_lines = []
    for i, p in enumerate(raw_places[:8]):
        name = (p.get("displayName") or {}).get("text", "?")
        types = p.get("types") or []
        cat = next((_TYPE_TO_CATEGORY.get(t) for t in types if t in _TYPE_TO_CATEGORY), "Venue")
        addr = p.get("shortFormattedAddress", "")
        rating = p.get("rating")
        r_str = f" ★{rating:.1f}" if rating else ""
        places_lines.append(f"V{i}. {name} — {cat}{r_str} — {addr}")
    places_str = "\n".join(places_lines) or "No nearby venues found."

    event_lines = []
    for i, ev in enumerate(nearby_events[:8]):
        title = ev.get("title", "?")
        cat = ev.get("category", "event")
        venue = ev.get("venue_name") or ev.get("address") or ""
        starts = ev.get("starts_at", "")
        try:
            dt = datetime.fromisoformat(starts.replace("Z", "+00:00"))
            starts = dt.strftime("%a %d %b %H:%M")
        except Exception:
            pass
        ticketed = " (ticketed)" if ev.get("is_ticketed") else ""
        price = ""
        if ev.get("price_min") and ev.get("price_max"):
            price = f" {int(ev['price_min'])}-{int(ev['price_max'])} {ev.get('currency', 'TRY')}"
        event_lines.append(f"E{i}. {title} — {cat} — {venue} — {starts}{price}{ticketed}")
    events_str = "\n".join(event_lines) if event_lines else "No upcoming events found nearby."

    return f"""## User Profile
Persona: {meta['display']} ({persona_class})
Traits: {traits_str}
Preferences: {prefs_str}

## Right Now (last hour)
Time: {time_label} ({hour:02d}:{now.minute:02d}) — {day_type}
Movement: {movement_pattern} ({dist_km} km traveled)
Top apps last hour: {top_apps_str}
Screen unlocks: {unlocks}

## Upcoming Events near you — PICK FROM HERE FIRST (E0, E1, ...)
{events_str}

## Nearby Venues — use only if no events fit (V0, V1, ...)
{places_str}

## Task
Select exactly 3 recommendations for this user.
RULE: If ANY event above matches the user's persona or current mood, pick it.
Only fall back to venues when there are no suitable events at all.
Use the ref codes: E0, E1, ... for events  |  V0, V1, ... for venues.
Return ONLY a valid JSON array, no other text:
[
  {{
    "item_ref": "E0",
    "title": "short activity title",
    "description": "1-2 sentence description",
    "rationale": "why this fits the user right now (1 sentence)",
    "category": "Movement|Recharge|Learning|Social|Health",
    "estimated_minutes": 30
  }}
]"""


def _call_mistral(
    persona_class: str,
    meta: dict,
    raw_places: list[dict],
    nearby_events: list[dict],
    realtime_ctx: dict,
    now: datetime,
) -> Optional[tuple[list[dict], int, int, int]]:
    """Returns (items, prompt_tokens, completion_tokens, latency_ms) or None."""
    if not raw_places and not nearby_events:
        return None
    try:
        t0 = _time.monotonic()
        prompt = _build_llm_prompt(persona_class, meta, raw_places, nearby_events, realtime_ctx, now)
        with httpx.Client(timeout=30) as client:
            resp = client.post(
                f"{MISTRAL_URL}/v1/chat/completions",
                json={
                    "model": LLM_MODEL,
                    "messages": [
                        {"role": "system", "content": _LLM_SYSTEM},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.7,
                    "stream": False,
                },
            )
        latency_ms = int((_time.monotonic() - t0) * 1000)
        if resp.status_code != 200:
            return None
        body = resp.json()
        usage = body.get("usage") or {}
        prompt_tokens = int(usage.get("prompt_tokens", 0))
        completion_tokens = int(usage.get("completion_tokens", 0))
        text = body["choices"][0]["message"]["content"].strip()
        start, end = text.find("["), text.rfind("]") + 1
        if start == -1 or end == 0:
            return None
        parsed = json.loads(text[start:end])
        if not isinstance(parsed, list):
            return None
        return parsed, prompt_tokens, completion_tokens, latency_ms
    except httpx.ConnectError as e:
        logger.warning("[mistral] Connection failed -> %s: %s", MISTRAL_URL, e)
        return None
    except Exception:
        return None


def _cache_key_for(user_id: str) -> str:
    import hashlib
    hour_bucket = datetime.now(timezone.utc).strftime("%Y%m%d%H")
    return hashlib.sha1(f"{user_id}:{hour_bucket}".encode()).hexdigest()


def _read_cached_suggestions(user_id: str) -> Optional[list[dict]]:
    """Return cached LLM payload if it exists and hasn't expired, else None."""
    cache_key = _cache_key_for(user_id)
    rows = _supa_get("cached_suggestions", {
        "cache_key": f"eq.{cache_key}",
        "select": "payload,expires_at",
        "limit": "1",
    })
    if not rows:
        return None
    row = rows[0]
    try:
        expires_at = datetime.fromisoformat(row["expires_at"].replace("Z", "+00:00"))
        if expires_at > datetime.now(timezone.utc):
            return row["payload"]
    except Exception:
        pass
    return None


def _save_cached_suggestions(
    user_id: str,
    payload: list[dict],
    prompt_tokens: int = 0,
    completion_tokens: int = 0,
    latency_ms: int = 0,
) -> None:
    """Persist LLM recommendation output to the cached_suggestions table."""
    now = datetime.now(timezone.utc)
    cache_key = _cache_key_for(user_id)
    expires_at = (now + timedelta(hours=1)).isoformat()
    cache_headers = {**_SUPA_HEADERS, "Prefer": "resolution=merge-duplicates,return=minimal"}
    try:
        with httpx.Client(timeout=10) as client:
            resp = client.post(
                f"{SUPABASE_URL}/rest/v1/cached_suggestions",
                headers=cache_headers,
                json={
                    "cache_key": cache_key,
                    "user_id": user_id,
                    "payload": payload,
                    "llm_provider": LLM_MODEL,
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "latency_ms": latency_ms,
                    "expires_at": expires_at,
                },
            )
        if resp.status_code in (200, 201):
            logger.info("[cache] saved suggestions for user %s (latency=%dms)", user_id, latency_ms)
        else:
            logger.warning("[cache] save failed status=%s body=%s", resp.status_code, resp.text[:200])
    except Exception as e:
        logger.warning("[cache] save error: %s", e)


def _llm_to_suggestions(
    llm_items: list[dict],
    raw_places: list[dict],
    nearby_events: list[dict],
    user_lat: float,
    user_lon: float,
    now_str: str,
) -> list[SuggestionResponse]:
    results = []
    for item in llm_items[:3]:
        # Parse item_ref (new format: "V0", "E2"). Fall back to legacy source+index.
        ref = item.get("item_ref", "")
        if ref.upper().startswith("E"):
            source = "event"
            try:
                idx = int(ref[1:])
            except ValueError:
                idx = 0
        elif ref.upper().startswith("V"):
            source = "venue"
            try:
                idx = int(ref[1:])
            except ValueError:
                idx = 0
        else:
            # Legacy fallback
            source = item.get("source", "venue")
            idx = item.get("index", item.get("venue_index", 0)) or 0

        if source == "event" and nearby_events:
            if not (0 <= idx < len(nearby_events)):
                idx = 0
            ev = nearby_events[idx]
            results.append(SuggestionResponse(
                id=f"event_{ev.get('event_id', str(idx))}",
                title=item.get("title") or ev.get("title", ""),
                description=item.get("description", ""),
                rationale=item.get("rationale", ""),
                category=item.get("category", "Social"),
                distance=None,
                estimated_minutes=item.get("estimated_minutes"),
                address=ev.get("address") or ev.get("venue_name") or None,
                latitude=None,
                longitude=None,
                tags=[ev.get("category", "")] if ev.get("category") else [],
                created_at=now_str,
            ))
        else:
            if not raw_places:
                continue
            if not (0 <= idx < len(raw_places)):
                idx = 0
            place = raw_places[idx]
            loc = place.get("location") or {}
            place_lat = float(loc.get("latitude", 0))
            place_lon = float(loc.get("longitude", 0))
            distance_km = _haversine_km(user_lat, user_lon, place_lat, place_lon)
            addr = place.get("shortFormattedAddress") or ""
            walking_min = item.get("estimated_minutes") or max(1, int((distance_km / 5.0) * 60))
            results.append(SuggestionResponse(
                id=f"llm_{place.get('id', str(idx))}",
                title=item.get("title", ""),
                description=item.get("description", ""),
                rationale=item.get("rationale", ""),
                category=item.get("category", "Recharge"),
                distance=round(distance_km, 1),
                estimated_minutes=walking_min,
                address=addr or None,
                latitude=place_lat,
                longitude=place_lon,
                tags=[],
                created_at=now_str,
            ))
    return results


# ─────────────────────────────────────────── classification ──────────────────

def _classify(user_id: str, force: bool = False) -> tuple[str, dict, int, dict]:
    """Returns (persona_class, meta_dict, signals_today, context_summary).

    Reads from users.persona_json cache when fresh (< PERSONA_CACHE_TTL_H hours).
    Set force=True to bypass cache and re-run the model.
    """
    if not force:
        cached = _load_persona_cache(user_id)
        if cached is not None:
            persona_class, meta, ctx = cached
            return persona_class, meta, 0, ctx

    gps    = _fetch_gps(user_id)
    apps   = _fetch_app_sessions(user_id)
    screen = _fetch_screen_events(user_id)

    # Estimate user's local timezone from GPS coordinates and adjust hour features
    tz_offset = _compute_tz_offset(gps)
    if tz_offset != 0:
        logger.info("[classify] GPS-derived tz_offset=%+dh for user %s", tz_offset, user_id)
    apps = _apply_tz_to_apps(apps, tz_offset)

    # signals_today = GPS pings from today
    signals_today = 0
    if not gps.empty:
        gps["ts"] = pd.to_datetime(gps["timestamp"], utc=True, errors="coerce")
        today = datetime.now(timezone.utc).date()
        signals_today = int((gps["ts"].dt.date == today).sum())

    feat = extract_user_features(user_id, gps, apps, screen, episode_user=None)

    # Episode features are empty in production (no labelled data). Fill the 15 ep_share_*
    # + episodes_per_day values using the rule-based episode detector.
    # On error leave as zero — do not break the request.
    try:
        ep_feats = compute_episode_shares(gps, apps, screen, tz_offset=tz_offset)
        feat.update(ep_feats)
    except Exception as e:
        logger.warning("[episodes] inference failed for %s: %s", user_id, e)

    # Build feature vector in the exact column order the model expects
    row = {col: feat.get(col, 0.0) for col in _feature_columns}
    X = pd.DataFrame([row])[_feature_columns]
    X = X.fillna(0.0)

    proba = _model.predict_proba(X)[0]
    confidence = float(np.max(proba))
    pred_idx = int(np.argmax(proba))
    persona_class = _label_classes[pred_idx] if confidence >= 0.35 else "HYBRID"
    meta = _PERSONA_META.get(persona_class, _PERSONA_META["HYBRID"])

    # Build lightweight context summary for LLM prompt
    context_summary: dict = {
        "model_confidence": round(confidence, 3),
        "confidence_tier": "high" if confidence >= 0.55 else "low",
    }

    # Latest movement state from most recent GPS ping
    if not gps.empty:
        context_summary["movement_state"] = str(gps.iloc[0].get("movement_state", "stationary"))
    else:
        context_summary["movement_state"] = "stationary"

    # Dominant app category in the last 24 h
    if not apps.empty:
        cutoff = pd.Timestamp.now(tz="UTC") - pd.Timedelta(hours=24)
        apps_ts = apps.copy()
        apps_ts["ts"] = pd.to_datetime(apps_ts["timestamp"], utc=True, errors="coerce")
        recent = apps_ts[apps_ts["ts"] >= cutoff]
        source = recent if not recent.empty else apps_ts
        if "category" in source.columns and not source.empty:
            top = source.groupby("category")["duration_min"].sum().idxmax()
            context_summary["top_app_category"] = str(top)
        else:
            context_summary["top_app_category"] = "unknown"
    else:
        context_summary["top_app_category"] = "unknown"

    _save_persona_cache(user_id, persona_class, signals_today, context_summary)

    return persona_class, meta, signals_today, context_summary

# ─────────────────────────────────────────── routes ──────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": str(_MODEL_FILE.name),
        "personas": len(_label_classes),
    }


@app.get("/api/health/llm")
def health_llm():
    try:
        with httpx.Client(timeout=5) as c:
            r = c.get(f"{MISTRAL_URL}/api/tags")
            return {"url": MISTRAL_URL, "status": r.status_code, "models": r.json().get("models", [])}
    except Exception as e:
        return {"url": MISTRAL_URL, "status": "unreachable", "error": str(e)}


@app.get("/api/debug/episodes/{user_id}")
def debug_episodes(user_id: str):
    gps    = _fetch_gps(user_id)
    apps   = _fetch_app_sessions(user_id)
    screen = _fetch_screen_events(user_id)

    try:
        ep_shares = compute_episode_shares(gps, apps, screen)
    except Exception as e:
        return {"error": str(e), "user_id": user_id}

    active = {k: round(v, 4) for k, v in ep_shares.items() if v > 0}
    all_shares = {k: round(v, 4) for k, v in ep_shares.items()}

    return {
        "user_id": user_id,
        "data_summary": {
            "gps_rows": len(gps),
            "app_rows": len(apps),
            "screen_rows": len(screen),
        },
        "active_episodes": active,
        "all_episode_shares": all_shares,
    }


_ADMIN_SECRET = os.environ.get("ADMIN_SECRET", "")

@app.post("/api/admin/scrape-events")
def admin_scrape_events(x_admin_key: Optional[str] = Header(None)):
    if not _ADMIN_SECRET or x_admin_key != _ADMIN_SECRET:
        raise HTTPException(status_code=403, detail="Forbidden")
    from event_scraper import scrape_all_cities
    import threading
    threading.Thread(target=scrape_all_cities, daemon=True).start()
    return {"status": "scrape started in background"}


@app.get("/api/debug/realtime/{user_id}")
def debug_realtime(user_id: str):
    ctx = _build_realtime_context(user_id)
    return {"user_id": user_id, "realtime_context": ctx}


@app.get("/api/debug/events/{city}")
def debug_events(city: str):
    """Show what nearby_events RPC returns for a city (no auth required)."""
    interests = ["music", "culture", "sports", "food", "outdoor", "workshop", "family"]
    events = _supa_rpc("nearby_events", {"p_city": city, "p_interests": interests, "p_limit": 20})
    total = _supa_get("events", {"city": f"eq.{city}", "select": "id", "limit": "1"})
    return {
        "city": city,
        "rpc_events": len(events),
        "events": events,
        "total_in_db_note": "use city=eq.Istanbul exactly",
    }


@app.get("/api/persona/{user_id}", response_model=PersonaResponse)
def get_persona(user_id: str, force: bool = Query(False)):
    persona_class, meta, signals_today, _ = _classify(user_id, force=force)
    return PersonaResponse(
        persona_id=persona_class,
        persona_name=meta["display"],
        traits=[PersonaTrait(**t) for t in meta["traits"]],
        preferences=meta["preferences"],
        last_updated=datetime.now(timezone.utc).isoformat(),
        signals_processed_today=signals_today,
    )


@app.get("/api/recommendations/{user_id}", response_model=list[SuggestionResponse])
def get_recommendations(
    user_id: str,
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    force: bool = Query(False),
):
    persona_class, meta, _, _ = _classify(user_id, force=force)
    now = datetime.now(timezone.utc)
    now_str = now.isoformat()

    # Tier 0: Return cached LLM output if still valid (1h TTL), unless force=True.
    if not force:
        cached_payload = _read_cached_suggestions(user_id)
        if cached_payload:
            logger.info("[cache] hit for user %s", user_id)
            try:
                return [SuggestionResponse(**s) for s in cached_payload]
            except Exception as e:
                logger.warning("[cache] payload parse error, skipping: %s", e)

    # When GPS provided, fetch real nearby venues and generate LLM recommendations.
    if lat is not None and lon is not None and GOOGLE_PLACES_KEY:
        raw_places     = _fetch_google_places(lat, lon)
        nearby_events  = _fetch_nearby_events(lat, lon, persona_class)
        realtime_ctx   = _build_realtime_context(user_id)

        # Keep only venue types that match this persona's interests (relevance filter).
        preferred_types = set(_PERSONA_PLACE_TYPES.get(persona_class, _ALL_PLACE_TYPES))
        persona_places = [
            p for p in raw_places
            if any(t in preferred_types for t in (p.get("types") or []))
        ]
        if not persona_places:
            persona_places = raw_places  # fallback: send all if nothing matched

        # Tier 1: LLM-enriched recommendations (persona + places + events + realtime)
        if persona_places or nearby_events:
            llm_result = _call_mistral(persona_class, meta, persona_places, nearby_events, realtime_ctx, now)
            if llm_result:
                llm_items, prompt_tokens, completion_tokens, latency_ms = llm_result
                suggestions = _llm_to_suggestions(llm_items, persona_places, nearby_events, lat, lon, now_str)
                if suggestions:
                    _save_cached_suggestions(
                        user_id,
                        [s.model_dump() for s in suggestions],
                        prompt_tokens, completion_tokens, latency_ms,
                    )
                    return suggestions

        # Tier 2: Direct Places results without LLM enrichment (persona-filtered)
        place_suggestions = [
            s
            for i, p in enumerate(persona_places)
            if (s := _place_to_suggestion(p, lat, lon, meta, i, now_str)) is not None
        ]
        if place_suggestions:
            return place_suggestions[:6]

    # Tier 3: Static persona-based recommendations (offline fallback)
    return [
        SuggestionResponse(
            id=f"{persona_class}_{i}",
            title=rec["title"],
            description=rec["description"],
            rationale=rec["rationale"],
            category=rec["category"],
            estimated_minutes=rec.get("estimated_minutes"),
            tags=rec.get("tags", []),
            created_at=now_str,
        )
        for i, rec in enumerate(meta["recommendations"])
    ]
