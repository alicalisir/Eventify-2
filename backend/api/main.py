"""
Context-Aware Recommendation API
=================================
Reads GPS, app-session, and screen-event data from Supabase,
runs the same feature-engineering pipeline used during training,
and classifies the user with the pre-trained CatBoost model.
"""

from __future__ import annotations

import json
import math as _math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

import httpx
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

load_dotenv()

# ─────────────────────────────────────────── paths ───────────────────────────

_API_DIR     = Path(__file__).resolve().parent
_ML_DIR      = _API_DIR.parent / "MLPipeline"
_MODEL_DIR   = _ML_DIR / "outputs" / "model"
_MODEL_FILE  = _MODEL_DIR / "catboost_persona.cbm"
_ENCODER_FILE= _MODEL_DIR / "label_encoder.json"
_FEATURES_FILE = _MODEL_DIR / "feature_columns.json"

# Make the MLPipeline package importable so we can reuse feature_engineering.py
sys.path.insert(0, str(_ML_DIR))
from feature_engineering import extract_user_features  # noqa: E402

# ─────────────────────────────────────────── load model ──────────────────────

_model = CatBoostClassifier()
_model.load_model(str(_MODEL_FILE))

with open(_ENCODER_FILE) as f:
    _label_classes: list[str] = json.load(f)["classes"]

with open(_FEATURES_FILE) as f:
    _feature_columns: list[str] = json.load(f)

# ─────────────────────────────────────────── Supabase REST ───────────────────

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ["SUPABASE_ANON_KEY"]
GOOGLE_PLACES_KEY = os.environ.get("GOOGLE_PLACES_API_KEY", "")
# Local Mistral via Ollama — run: ollama pull mistral && ollama serve
MISTRAL_URL = os.environ.get("MISTRAL_URL", "http://localhost:11434")
_SUPA_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def _supa_get(table: str, params: dict) -> list[dict]:
    with httpx.Client(timeout=15) as client:
        resp = client.get(
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_SUPA_HEADERS,
            params=params,
        )
        if resp.status_code == 200:
            return resp.json() or []
        return []

# ─────────────────────────────────────────── Google Places ───────────────────

_PLACES_URL = "https://places.googleapis.com/v1/places:searchNearby"
_PLACES_FIELD_MASK = (
    "places.id,places.displayName,places.types,"
    "places.location,places.shortFormattedAddress,places.rating"
)

# Venue types each persona prefers (Google Places New API type strings)
_PERSONA_PLACE_TYPES: dict[str, list[str]] = {
    "ERKENCI":         ["cafe", "park", "gym", "bakery", "restaurant"],
    "EVCIMEN":         ["cafe", "restaurant", "book_store", "library", "park"],
    "GECE_KUSU":       ["bar", "night_club", "restaurant", "movie_theater", "cafe"],
    "HIBRIT":          ["cafe", "restaurant", "park", "museum", "bar"],
    "ICERIK_TUKETICI": ["movie_theater", "museum", "library", "cafe", "art_gallery"],
    "KRIZ_DUZENSIZ":   ["cafe", "park", "restaurant", "book_store", "spa"],
    "OGRENCI":         ["library", "cafe", "book_store", "museum", "park"],
    "OYUNCU":          ["cafe", "restaurant", "park", "shopping_mall", "movie_theater"],
    "PROFESYONEL":     ["restaurant", "cafe", "bar", "museum", "performing_arts_theater"],
    "SEYYAH":          ["park", "museum", "tourist_attraction", "art_gallery", "performing_arts_theater"],
    "SOSYAL":          ["restaurant", "bar", "cafe", "performing_arts_theater", "park"],
    "SPORCU":          ["gym", "park", "sports_complex", "restaurant", "cafe"],
}

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
    "cafe": ["Kafe", "İçecek"], "coffee_shop": ["Kafe", "Kahve"],
    "restaurant": ["Yemek", "Restoran"], "bakery": ["Fırın", "Tatlı"],
    "bar": ["Bar", "Sosyal"], "night_club": ["Gece", "Müzik"],
    "performing_arts_theater": ["Tiyatro", "Kültür"],
    "park": ["Park", "Açık Hava"],
    "gym": ["Spor", "Fitness"], "sports_complex": ["Spor", "Aktif"],
    "museum": ["Müze", "Kültür"], "art_gallery": ["Sanat", "Galeri"],
    "library": ["Kütüphane", "Sessiz"], "movie_theater": ["Sinema", "Film"],
    "book_store": ["Kitapçı", "Okuma"], "shopping_mall": ["AVM", "Alışveriş"],
    "tourist_attraction": ["Keşif", "Gezi"],
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


def _fetch_google_places(lat: float, lon: float, types: list[str]) -> list[dict]:
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
                    "includedTypes": types[:5],
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
            f"Sana {distance_km:.1f} km yakında{rating_str}. "
            f"Bu tür mekanlar senin profil tipine {int(pref_score * 100)}% uyuyor."
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
    "ERKENCI": {
        "display": "Erkenci Kuş",
        "traits": [
            {"label": "Sabah Aktif", "confidence": 0.90},
            {"label": "Disiplinli", "confidence": 0.85},
            {"label": "Verimlilik Odaklı", "confidence": 0.80},
        ],
        "preferences": {"outdoor": 0.7, "culture": 0.6, "social": 0.5, "food": 0.5},
        "recommendations": [
            {"category": "Movement", "title": "Sabah Koşusu",
             "description": "Güne enerjik başla — sabah erken 20-30 dakika koşu.",
             "rationale": "Sabah aktivite örüntün gün erken saatlerde yüksek enerji gösteriyor.",
             "tags": ["Sabah", "Koşu", "Enerji"], "estimated_minutes": 30},
            {"category": "Learning", "title": "Sabah Eğitim Seansı",
             "description": "Bir podcast, dil uygulaması veya online kurs ile güne başla.",
             "rationale": "Sabah saatlerindeki üretken profil öğrenmeye çok uygun.",
             "tags": ["Sabah", "Öğrenme", "Gelişim"], "estimated_minutes": 20},
            {"category": "Recharge", "title": "Kahve Ritüeli",
             "description": "Sevdiğin kafede sessizce kahveni iç, güne hazırlan.",
             "rationale": "Sabah rutinin yapılandırılmış başlangıç için mükemmel.",
             "tags": ["Kahve", "Sabah", "Rutin"], "estimated_minutes": 25},
        ],
    },
    "EVCIMEN": {
        "display": "Evcimen",
        "traits": [
            {"label": "Ev Odaklı", "confidence": 0.90},
            {"label": "İçe Dönük", "confidence": 0.82},
            {"label": "Sakin Yaşam", "confidence": 0.78},
        ],
        "preferences": {"food": 0.7, "culture": 0.6, "outdoor": 0.3, "social": 0.4},
        "recommendations": [
            {"category": "Recharge", "title": "Ev Yakını Kafe",
             "description": "Evine yakın sakin bir kafede mola ver.",
             "rationale": "Ev çevresinde kalma eğilimin yerel mekanlara çok uygun.",
             "tags": ["Kafe", "Yakın", "Sakin"], "estimated_minutes": 40},
            {"category": "Learning", "title": "Çevrimiçi Workshop",
             "description": "Evden katılabileceğin bir online atölyeye kayıt ol.",
             "rationale": "Eve bağlı yaşam tarzın online etkinliklere en uygun.",
             "tags": ["Online", "Öğrenme", "Ev"], "estimated_minutes": 60},
            {"category": "Movement", "title": "Mahalle Yürüyüşü",
             "description": "Kısa bir hava alma yürüyüşü — 20 dakika yeterli.",
             "rationale": "Küçük ama düzenli hareket dengeni korur.",
             "tags": ["Yürüyüş", "Yakın", "Günlük"], "estimated_minutes": 20},
        ],
    },
    "GECE_KUSU": {
        "display": "Gece Kuşu",
        "traits": [
            {"label": "Gece Aktif", "confidence": 0.90},
            {"label": "Spontane", "confidence": 0.80},
            {"label": "Sosyal Gece", "confidence": 0.72},
        ],
        "preferences": {"social": 0.8, "culture": 0.7, "food": 0.8, "outdoor": 0.3},
        "recommendations": [
            {"category": "Social", "title": "Gece Müzik Etkinliği",
             "description": "Canlı müzik veya konser salonuna git.",
             "rationale": "Gece saatlerindeki yüksek aktivite müzik etkinliklerine çok uygun.",
             "tags": ["Müzik", "Gece", "Canlı"], "estimated_minutes": 150},
            {"category": "Recharge", "title": "Geç Saatte Kafe",
             "description": "Gece geç saatlerde açık, sakin bir kafede otur.",
             "rationale": "Gece profili geç saatlerde aktif olmayı tercih ettiğini gösteriyor.",
             "tags": ["Gece", "Kafe", "Sakin"], "estimated_minutes": 60},
            {"category": "Social", "title": "Gece Pazarı",
             "description": "Gece pazarı veya sokak yemekleri etkinliğine git.",
             "rationale": "Hafta sonu gece aktivite örüntüne çok uygun.",
             "tags": ["Pazar", "Yemek", "Keşif"], "estimated_minutes": 90},
        ],
    },
    "HIBRIT": {
        "display": "Hibrit Kullanıcı",
        "traits": [
            {"label": "Dengeli", "confidence": 0.80},
            {"label": "Adaptif", "confidence": 0.75},
            {"label": "Çok Yönlü", "confidence": 0.70},
        ],
        "preferences": {"outdoor": 0.6, "culture": 0.6, "social": 0.6, "food": 0.6},
        "recommendations": [
            {"category": "Social", "title": "Topluluk Etkinliği",
             "description": "Yakınındaki bir topluluk buluşmasına katıl.",
             "rationale": "Dengeli ve çok yönlü profilin topluluk etkinliklerine uygun.",
             "tags": ["Topluluk", "Sosyal", "Yerel"], "estimated_minutes": 90},
            {"category": "Movement", "title": "Şehir Keşfi",
             "description": "Hiç gitmediğin bir mahallede kısa bir yürüyüş.",
             "rationale": "Esnek hareket profilin keşif aktivitelerine uygun.",
             "tags": ["Yürüyüş", "Keşif", "Şehir"], "estimated_minutes": 45},
            {"category": "Recharge", "title": "Yeni Kafe Dene",
             "description": "Yakındaki yeni bir kafe veya restoranı ziyaret et.",
             "rationale": "Dengeli profil için yeni deneyimler ideal.",
             "tags": ["Kafe", "Yeni", "Dinlenme"], "estimated_minutes": 40},
        ],
    },
    "ICERIK_TUKETICI": {
        "display": "İçerik Tüketicisi",
        "traits": [
            {"label": "Dijital Odaklı", "confidence": 0.90},
            {"label": "Medya Sever", "confidence": 0.85},
            {"label": "Evde Konforlu", "confidence": 0.78},
        ],
        "preferences": {"culture": 0.9, "food": 0.6, "outdoor": 0.3, "social": 0.5},
        "recommendations": [
            {"category": "Learning", "title": "Film / Belgesel Festivali",
             "description": "Yakındaki bir sinema veya belgesel gösterimine git.",
             "rationale": "Yüksek medya tüketim oranın film etkinliklerine çok uygun.",
             "tags": ["Film", "Sinema", "Kültür"], "estimated_minutes": 120},
            {"category": "Recharge", "title": "Kitap Kulübü",
             "description": "Bir kitap kulübü toplantısına katıl.",
             "rationale": "İçerik tüketim profilin kitap kulübüne uyuyor.",
             "tags": ["Kitap", "Kültür", "Sosyal"], "estimated_minutes": 90},
            {"category": "Movement", "title": "Kısa Hava Alma Yürüyüşü",
             "description": "Ekran başından kalkıp 20 dakika dışarı çık.",
             "rationale": "Uzun ekran periyotlarının ardından kısa yürüyüş enerji verir.",
             "tags": ["Yürüyüş", "Hava", "Mola"], "estimated_minutes": 20},
        ],
    },
    "KRIZ_DUZENSIZ": {
        "display": "Kriz & Düzensiz",
        "traits": [
            {"label": "Değişken Ritim", "confidence": 0.82},
            {"label": "Yüksek Stres", "confidence": 0.75},
            {"label": "Ani Kararlar", "confidence": 0.70},
        ],
        "preferences": {"outdoor": 0.5, "food": 0.7, "social": 0.5, "culture": 0.4},
        "recommendations": [
            {"category": "Recharge", "title": "Meditasyon / Nefes Egzersizi",
             "description": "5-10 dakikalık rehberli meditasyon dene.",
             "rationale": "Düzensiz aktivite örüntün stres azaltıcı aktivitelere ihtiyaç duyuyor.",
             "tags": ["Meditasyon", "Nefes", "Huzur"], "estimated_minutes": 10},
            {"category": "Movement", "title": "Kısa Yürüyüş Molası",
             "description": "Her iki saatte bir 10 dakika yürü.",
             "rationale": "Küçük düzenli molalar enerji ve odak artırır.",
             "tags": ["Yürüyüş", "Mola", "Düzen"], "estimated_minutes": 10},
            {"category": "Recharge", "title": "Sakin Bir Kafede Mola",
             "description": "Sakin bir ortamda oturup düşüncelerini topla.",
             "rationale": "Düzensiz aktivite örüntün sakin ortamlardan fayda görür.",
             "tags": ["Kafe", "Sessiz", "Toparlanma"], "estimated_minutes": 30},
        ],
    },
    "OGRENCI": {
        "display": "Öğrenci",
        "traits": [
            {"label": "Öğrenme Odaklı", "confidence": 0.90},
            {"label": "Meraklı", "confidence": 0.85},
            {"label": "Bütçe Bilinçli", "confidence": 0.75},
        ],
        "preferences": {"culture": 0.9, "outdoor": 0.6, "social": 0.7, "food": 0.5},
        "recommendations": [
            {"category": "Learning", "title": "Kütüphane veya Study Space",
             "description": "Yakındaki sessiz bir kütüphane veya çalışma alanına git.",
             "rationale": "Öğrenci profiline uygun ücretsiz çalışma ortamı.",
             "tags": ["Kütüphane", "Çalışma", "Ücretsiz"], "estimated_minutes": 120},
            {"category": "Social", "title": "Kampüs / Öğrenci Etkinliği",
             "description": "Yakında düzenlenen öğrenci kulübü veya workshop etkinliğine katıl.",
             "rationale": "Sosyal ve öğrenme odaklı profilin bu tür etkinliklere çok uygun.",
             "tags": ["Öğrenci", "Sosyal", "Network"], "estimated_minutes": 90},
            {"category": "Recharge", "title": "Uygun Fiyatlı Kafe Molası",
             "description": "Bütçene uygun bir kafede mola ver.",
             "rationale": "Yoğun çalışma periyotlarının ardından kısa mola verimlilik artırır.",
             "tags": ["Kafe", "Uygun", "Mola"], "estimated_minutes": 30},
        ],
    },
    "OYUNCU": {
        "display": "Oyuncu",
        "traits": [
            {"label": "Gaming Tutkunu", "confidence": 0.92},
            {"label": "Rekabetçi", "confidence": 0.85},
            {"label": "Dijital Sosyal", "confidence": 0.78},
        ],
        "preferences": {"social": 0.7, "culture": 0.5, "outdoor": 0.3, "food": 0.6},
        "recommendations": [
            {"category": "Social", "title": "Gaming Cafe / Turnuva",
             "description": "Yakındaki bir gaming kafede turnuvaya katıl veya arkadaşlarla oyna.",
             "rationale": "Yüksek gaming profili bu tür sosyal gaming ortamlarına çok uygun.",
             "tags": ["Gaming", "Turnuva", "Sosyal"], "estimated_minutes": 120},
            {"category": "Movement", "title": "Dijital Detoks Yürüyüşü",
             "description": "Ekrandan uzaklaşmak için 30 dakika açık hava yürüyüşü.",
             "rationale": "Uzun gaming seanslarının ardından fiziksel aktivite faydalı.",
             "tags": ["Yürüyüş", "Detoks", "Açık Hava"], "estimated_minutes": 30},
            {"category": "Social", "title": "Board Game Etkinliği",
             "description": "Bir board game kafesinde yüz yüze oyun oyna.",
             "rationale": "Gaming sosyal yönünü yüz yüze aktiviteye taşıma fırsatı.",
             "tags": ["Board Game", "Sosyal", "Eğlence"], "estimated_minutes": 90},
        ],
    },
    "PROFESYONEL": {
        "display": "Profesyonel",
        "traits": [
            {"label": "Kariyer Odaklı", "confidence": 0.90},
            {"label": "Verimli", "confidence": 0.88},
            {"label": "Ağ Kurucu", "confidence": 0.80},
        ],
        "preferences": {"culture": 0.8, "social": 0.7, "food": 0.6, "outdoor": 0.4},
        "recommendations": [
            {"category": "Social", "title": "Networking Etkinliği",
             "description": "Sektörüne uygun bir networking veya konferansa katıl.",
             "rationale": "Profesyonel aktivite örüntün bu tür etkinliklere çok uygun.",
             "tags": ["Network", "Kariyer", "Profesyonel"], "estimated_minutes": 120},
            {"category": "Recharge", "title": "Öğle Molası — Restoran",
             "description": "İş arkadaşlarınla ya da yalnız kaliteli öğle yemeği ye.",
             "rationale": "Verimli çalışma için düzenli mola şart.",
             "tags": ["Yemek", "Mola", "Enerji"], "estimated_minutes": 60},
            {"category": "Learning", "title": "Sektör Podcast / Webinar",
             "description": "Commute sırasında sektörüne ait içerik dinle.",
             "rationale": "Profesyonel gelişim için commute zamanını değerlendir.",
             "tags": ["Podcast", "Öğrenme", "Commute"], "estimated_minutes": 30},
        ],
    },
    "SEYYAH": {
        "display": "Seyyah",
        "traits": [
            {"label": "Aktif Gezgin", "confidence": 0.92},
            {"label": "Keşif Tutkunu", "confidence": 0.88},
            {"label": "Açık Hava Sever", "confidence": 0.85},
        ],
        "preferences": {"outdoor": 0.95, "culture": 0.80, "food": 0.70, "social": 0.60},
        "recommendations": [
            {"category": "Movement", "title": "Şehir Keşif Turu",
             "description": "Hiç gitmediğin bir mahallede detaylı keşif yürüyüşü.",
             "rationale": "Yüksek mobilite yarıçapın ve çeşitli konum geçmişin keşif profili çiziyor.",
             "tags": ["Keşif", "Yürüyüş", "Şehir"], "estimated_minutes": 90},
            {"category": "Health", "title": "Doğa Yürüyüşü",
             "description": "Şehir dışında doğa yürüyüşü veya bisiklet turu.",
             "rationale": "Yüksek günlük mesafe ve hareket profilin doğa aktivitelerine ideal.",
             "tags": ["Doğa", "Bisiklet", "Aktif"], "estimated_minutes": 120},
            {"category": "Social", "title": "Seyahat Topluluğu",
             "description": "Şehirdeki seyahat veya yürüyüş grubuna katıl.",
             "rationale": "Aktif ve sosyal profil bu tür gruplara çok uygun.",
             "tags": ["Grup", "Seyahat", "Sosyal"], "estimated_minutes": 90},
        ],
    },
    "SOSYAL": {
        "display": "Sosyal Kelebek",
        "traits": [
            {"label": "Sosyal & Dışa Dönük", "confidence": 0.92},
            {"label": "Etkinlik Sever", "confidence": 0.88},
            {"label": "Ağ Kurucu", "confidence": 0.80},
        ],
        "preferences": {"social": 0.95, "culture": 0.80, "food": 0.75, "outdoor": 0.50},
        "recommendations": [
            {"category": "Social", "title": "Sosyal Etkinlik / Buluşma",
             "description": "Arkadaşlarla buluşma veya yeni tanışma etkinliğine katıl.",
             "rationale": "Yüksek sosyal medya ve sosyal uygulama kullanımın dışa dönük bir profil gösteriyor.",
             "tags": ["Sosyal", "Buluşma", "Eğlence"], "estimated_minutes": 120},
            {"category": "Social", "title": "Sanat Galerisi / Sergi",
             "description": "Bir sanat galerisini veya sergisini ziyaret et.",
             "rationale": "Sosyal ve kültürel profil bu tür etkinliklere uygun.",
             "tags": ["Sanat", "Kültür", "Sosyal"], "estimated_minutes": 90},
            {"category": "Movement", "title": "Grup Yürüyüşü",
             "description": "Bir şehir yürüyüş grubuna katıl.",
             "rationale": "Sosyal aktiviteler birleştirmek profiline ideal.",
             "tags": ["Grup", "Yürüyüş", "Sosyal"], "estimated_minutes": 60},
        ],
    },
    "SPORCU": {
        "display": "Sporcu",
        "traits": [
            {"label": "Spor Tutkunu", "confidence": 0.95},
            {"label": "Sağlık Odaklı", "confidence": 0.90},
            {"label": "Disiplinli", "confidence": 0.85},
        ],
        "preferences": {"outdoor": 0.95, "health": 0.95, "food": 0.65, "social": 0.55},
        "recommendations": [
            {"category": "Health", "title": "Sabah Antrenmanı",
             "description": "Koşu, bisiklet veya spor salonu antrenmanı.",
             "rationale": "Fitness uygulama kullanımın ve yüksek hareket profilin sporcu kimliğini gösteriyor.",
             "tags": ["Antrenman", "Sabah", "Fitness"], "estimated_minutes": 60},
            {"category": "Health", "title": "Spor Kulübü / Grup Dersi",
             "description": "Bir spor kulübü veya grup fitness dersine katıl.",
             "rationale": "Aktif yaşam tarzın grup sporuna çok uygun.",
             "tags": ["Spor Kulübü", "Grup", "Sosyal"], "estimated_minutes": 60},
            {"category": "Recharge", "title": "Sporcu Beslenmesi",
             "description": "Organik veya sağlıklı bir restoranda beslen.",
             "rationale": "Aktif yaşam tarzı doğru beslenme ile tamamlanır.",
             "tags": ["Sağlıklı", "Beslenme", "Toparlanma"], "estimated_minutes": 45},
        ],
    },
}

# ─────────────────────────────────────────── FastAPI ─────────────────────────

app = FastAPI(title="Context-Aware Recommendation API", version="2.0.0")
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

# ─────────────────────────────────────────── data fetching ───────────────────

def _fetch_gps(user_id: str) -> pd.DataFrame:
    rows = _supa_get("gps_pings", {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "2016",
        "select": "timestamp,latitude,longitude,speed_mps,movement_state,dwell_time_s",
    })
    return pd.DataFrame(rows) if rows else pd.DataFrame()


def _fetch_app_sessions(user_id: str) -> pd.DataFrame:
    rows = _supa_get("app_sessions", {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "5000",
        "select": "timestamp,app_name,category,duration_min",
    })
    if not rows:
        return pd.DataFrame()
    df = pd.DataFrame(rows)
    df = df.rename(columns={"app_name": "app"})
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")
    df["hour"] = df["timestamp"].dt.hour
    df["weekday"] = df["timestamp"].dt.weekday
    return df


def _fetch_screen_events(user_id: str) -> pd.DataFrame:
    rows = _supa_get("screen_events", {
        "user_id": f"eq.{user_id}",
        "order": "timestamp.desc",
        "limit": "10000",
        "select": "timestamp,event_type",
    })
    return pd.DataFrame(rows) if rows else pd.DataFrame()

# ─────────────────────────────────────────── LLM (local Mistral / Ollama) ────

_LLM_SYSTEM = (
    "Sen kişiselleştirilmiş etkinlik öneri asistanısın. "
    "Verilen kullanıcı profili, güncel bağlam ve yakın mekan listesine göre "
    "Türkçe olarak tam olarak 3 etkinlik önerisi üret. "
    "Sadece geçerli JSON dizisi döndür, başka hiçbir metin yazma."
)

_MOV_LABELS = {
    "stationary": "Hareketsiz", "walking": "Yürüyor",
    "cycling": "Bisiklet sürüyor", "transit": "Toplu taşımada",
    "vehicle": "Araçta",
}
_CAT_LABELS = {
    "social": "sosyal medya", "gaming": "oyun", "streaming": "dizi/film",
    "music": "müzik", "productivity": "iş/verimlilik", "education": "eğitim",
    "shopping": "alışveriş", "news": "haber", "fitness": "fitness",
    "messaging": "mesajlaşma", "video": "video", "reading": "okuma",
    "browser": "web gezintisi", "short_video": "kısa video",
}
_TIME_LABELS = [
    (0, 6, "Gece"), (6, 9, "Sabah erken"), (9, 12, "Sabah"),
    (12, 14, "Öğle"), (14, 17, "Öğleden sonra"), (17, 20, "Akşam üstü"),
    (20, 24, "Gece"),
]


def _build_llm_prompt(
    persona_class: str,
    meta: dict,
    raw_places: list[dict],
    ctx: dict,
    now: datetime,
) -> str:
    hour = now.hour
    time_label = next((l for a, b, l in _TIME_LABELS if a <= hour < b), "Gece")

    traits_str = ", ".join(
        f"{t['label']} (%{int(t['confidence'] * 100)})" for t in meta["traits"]
    )
    prefs = meta["preferences"]
    prefs_str = (
        f"açık hava={prefs.get('outdoor', 0):.1f}, "
        f"sosyal={prefs.get('social', 0):.1f}, "
        f"yemek={prefs.get('food', 0):.1f}, "
        f"kültür={prefs.get('culture', 0):.1f}"
    )

    movement = _MOV_LABELS.get(ctx.get("movement_state", "stationary"), "Hareketsiz")
    top_cat = _CAT_LABELS.get(ctx.get("top_app_category", ""), "belirsiz")

    places_lines = []
    for i, p in enumerate(raw_places[:8]):
        name = (p.get("displayName") or {}).get("text", "?")
        types = p.get("types") or []
        cat = next((_TYPE_TO_CATEGORY.get(t) for t in types if t in _TYPE_TO_CATEGORY), "Mekan")
        addr = p.get("shortFormattedAddress", "")
        rating = p.get("rating")
        r_str = f" ★{rating:.1f}" if rating else ""
        places_lines.append(f"{i + 1}. {name} — {cat}{r_str} — {addr}")

    places_str = "\n".join(places_lines) or "Yakın mekan bulunamadı."

    return f"""## Kullanıcı Profili
Persona: {meta['display']} ({persona_class})
Özellikler: {traits_str}
Tercihler: {prefs_str}

## Güncel Bağlam
Zaman: {time_label} ({hour:02d}:{now.minute:02d})
Hareket durumu: {movement}
Son 24 saatte ağırlıklı uygulama türü: {top_cat}

## Yakındaki Mekanlar (1.5 km içinde)
{places_str}

## Görev
Bu kullanıcı için en uygun 3 mekanı seç ve etkinlik öner. JSON formatında döndür:
[
  {{
    "title": "kısa etkinlik başlığı",
    "description": "1-2 cümle açıklama",
    "rationale": "neden bu kullanıcıya uygun (1 cümle)",
    "category": "Movement|Recharge|Learning|Social|Health",
    "venue_index": 0,
    "estimated_minutes": 30
  }}
]
venue_index, yukarıdaki numaralı listede hangi mekanı seçtiğini belirtir (0-indexed)."""


def _call_mistral(
    persona_class: str,
    meta: dict,
    raw_places: list[dict],
    ctx: dict,
    now: datetime,
) -> Optional[list[dict]]:
    if not raw_places:
        return None
    try:
        prompt = _build_llm_prompt(persona_class, meta, raw_places, ctx, now)
        with httpx.Client(timeout=30) as client:
            resp = client.post(
                f"{MISTRAL_URL}/v1/chat/completions",
                json={
                    "model": "mistral",
                    "messages": [
                        {"role": "system", "content": _LLM_SYSTEM},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.7,
                    "stream": False,
                },
            )
        if resp.status_code != 200:
            return None
        text = resp.json()["choices"][0]["message"]["content"].strip()
        start, end = text.find("["), text.rfind("]") + 1
        if start == -1 or end == 0:
            return None
        parsed = json.loads(text[start:end])
        return parsed if isinstance(parsed, list) else None
    except httpx.ConnectError as e:
        logger.warning("[mistral] Bağlantı kurulamadı → %s: %s", MISTRAL_URL, e)
        return None
    except Exception:
        return None


def _llm_to_suggestions(
    llm_items: list[dict],
    raw_places: list[dict],
    user_lat: float,
    user_lon: float,
    now_str: str,
) -> list[SuggestionResponse]:
    results = []
    for item in llm_items[:3]:
        idx = item.get("venue_index", 0)
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

def _classify(user_id: str) -> tuple[str, dict, int, dict]:
    """Returns (persona_class, meta_dict, signals_today, context_summary)."""
    gps    = _fetch_gps(user_id)
    apps   = _fetch_app_sessions(user_id)
    screen = _fetch_screen_events(user_id)

    # signals_today = GPS pings from today
    signals_today = 0
    if not gps.empty:
        gps["ts"] = pd.to_datetime(gps["timestamp"], utc=True, errors="coerce")
        today = datetime.now(timezone.utc).date()
        signals_today = int((gps["ts"].dt.date == today).sum())

    feat = extract_user_features(user_id, gps, apps, screen, episode_user=None)

    # Build feature vector in the exact column order the model expects
    row = {col: feat.get(col, 0.0) for col in _feature_columns}
    X = pd.DataFrame([row])[_feature_columns]
    X = X.fillna(0.0)

    pred_idx = int(_model.predict(X)[0])
    persona_class = _label_classes[pred_idx]
    meta = _PERSONA_META.get(persona_class, _PERSONA_META["HIBRIT"])

    # Build lightweight context summary for LLM prompt
    context_summary: dict = {}

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


@app.get("/api/persona/{user_id}", response_model=PersonaResponse)
def get_persona(user_id: str):
    persona_class, meta, signals_today, _ = _classify(user_id)
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
):
    persona_class, meta, _, ctx = _classify(user_id)
    now = datetime.now(timezone.utc)
    now_str = now.isoformat()

    # When GPS provided, fetch real nearby venues and generate LLM recommendations.
    if lat is not None and lon is not None and GOOGLE_PLACES_KEY:
        place_types = _PERSONA_PLACE_TYPES.get(persona_class, _PERSONA_PLACE_TYPES["HIBRIT"])
        raw_places = _fetch_google_places(lat, lon, place_types)

        # Tier 1: LLM-enriched recommendations (persona + places + app context → Mistral)
        if raw_places:
            llm_items = _call_mistral(persona_class, meta, raw_places, ctx, now)
            if llm_items:
                suggestions = _llm_to_suggestions(llm_items, raw_places, lat, lon, now_str)
                if suggestions:
                    return suggestions

        # Tier 2: Direct Places results without LLM enrichment
        place_suggestions = [
            s
            for i, p in enumerate(raw_places)
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
