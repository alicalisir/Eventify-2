"""
Context-Aware Recommendation API
=================================
Reads GPS, app-session, and screen-event data from Supabase,
runs the same feature-engineering pipeline used during training,
and classifies the user with the pre-trained CatBoost model.
"""

from __future__ import annotations

import json
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
from fastapi import FastAPI, HTTPException
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
SUPABASE_KEY = os.environ["SUPABASE_ANON_KEY"]
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

# ─────────────────────────────────────────── classification ──────────────────

def _classify(user_id: str) -> tuple[str, dict, int]:
    """Returns (persona_class, meta_dict, signals_today)."""
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
    return persona_class, meta, signals_today

# ─────────────────────────────────────────── routes ──────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": str(_MODEL_FILE.name),
        "personas": len(_label_classes),
    }


@app.get("/api/persona/{user_id}", response_model=PersonaResponse)
def get_persona(user_id: str):
    persona_class, meta, signals_today = _classify(user_id)
    return PersonaResponse(
        persona_id=persona_class,
        persona_name=meta["display"],
        traits=[PersonaTrait(**t) for t in meta["traits"]],
        preferences=meta["preferences"],
        last_updated=datetime.now(timezone.utc).isoformat(),
        signals_processed_today=signals_today,
    )


@app.get("/api/recommendations/{user_id}", response_model=list[SuggestionResponse])
def get_recommendations(user_id: str):
    persona_class, meta, _ = _classify(user_id)
    now_str = datetime.now(timezone.utc).isoformat()
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
