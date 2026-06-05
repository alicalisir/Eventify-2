# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend API
```bash
cd backend/api
pip install -r requirements.txt
python -m uvicorn main:app --reload --port 8000
```

### Flutter App
```bash
cd context_aware_event_recommendation_system
flutter pub get
flutter run                                      # default device
flutter run -t lib/main_development.dart         # dev flavor
flutter build apk --release
```

### ML Pipeline
```bash
cd backend/MLPipeline
python simulation/simulate.py --agents 100 --days 7   # synthetic data → FakeData/out/
python train_catboost_persona_model.py                 # → outputs/model/
python generate_test_data.py && python evaluate_persona_model.py
```

### Flutter Tests
```bash
cd context_aware_event_recommendation_system
flutter test
flutter test test/places_api_smoke_test.dart   # single test
```

## Architecture

### Data Flow
```
Android Native (Kotlin ForegroundService)
  → GPS pings every 5 min → Supabase: gps_pings
  → App usage every 60 min → Supabase: app_sessions
  → Screen events (real-time buffered) → Supabase: screen_events

FastAPI /api/recommendations/{user_id}?lat=X&lon=Y
  → Supabase fetch → feature_engineering.py → CatBoost → persona
  → Google Places API (persona-filtered venues)
  → Ollama/Mistral (MISTRAL_URL) → Türkçe LLM önerileri
  → Tier 1: LLM-enriched | Tier 2: Places-only | Tier 3: static persona fallback
```

### Critical Shared Code
`backend/MLPipeline/feature_engineering.py` → `extract_user_features()` is imported by **both** `train_catboost_persona_model.py` and `backend/api/main.py`. Any feature change must happen here and will affect both training and inference simultaneously.

### Feature Vector (91 features)
The CatBoost model expects features in the exact order from `backend/MLPipeline/outputs/model/feature_columns.json`. Groups:
- App session stats (6) + category shares (19) + hourly distribution (28: `hour_share_00..23` + 4 circadian summaries + weekend/p90/p10)
- GPS/mobility (14): distance, radius, unique cells, speeds, movement state shares, dwell times
- Screen events (5): unlocks, on, off, notifications, notif_per_unlock
- Episode shares (15): `ep_share_SLEEP` etc. — computed in production via rule-based `episodes.py` (`compute_episode_shares()`); zero only if data is insufficient or scoring threshold (≥15) not met

Hour-bucket accuracy: `AppUsageService.dart` uses `info.lastForeground` per app (fixed) with a 24h window so a single collection populates all 24 hour buckets correctly. Upsert on `(user_id, app_name, timestamp)` prevents duplicates across hourly runs.

### 12 Personas
`_PERSONA_META` dict in `backend/api/main.py` (line ~238) holds traits, preferences, and static recommendations for each:
`EARLY_BIRD, HOMEBODY, NIGHT_OWL, HYBRID, CONTENT_CONSUMER, IRREGULAR, STUDENT, GAMER, PROFESSIONAL, TRAVELER, SOCIAL, ATHLETE`

### Android Native ↔ Flutter Bridge
Two MethodChannels in `MainActivity.kt`:
- `com.example.caers/screen_events` → `ScreenEventService.kt` (ForegroundService, buffers to SharedPreferences)
- `com.example.caers/activity_recognition` → `ActivityRecognitionReceiver.kt` (Google Play Services, 30s interval, confidence ≥ 50%)

`GpsCollectionService.dart` orchestrates collection: GPS every 5 min, and every 12th tick (~1h) it triggers `AppUsageService.collectAndUpload()` + `ScreenEventService.flush()`.

### Environment Variables
**backend/api/.env:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `GOOGLE_PLACES_API_KEY`, `MISTRAL_URL` (default: `http://localhost:11434`)

**context_aware_event_recommendation_system/.env:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BACKEND_URL`, `OPENWEATHER_API_KEY`, `GOOGLE_PLACES_API_KEY`

### Ollama Remote Setup

**Senaryo A — Backend bu makinede, Ollama farklı makinede:**
1. Yeni makinede: `OLLAMA_HOST=0.0.0.0:11434` environment variable ayarla, sonra `ollama serve`
2. Yeni makinenin firewall'unda 11434 portunu aç
3. `backend/api/.env` → `MISTRAL_URL=http://<yeni-makine-ip>:11434`
4. Doğrulama: `curl http://localhost:8000/api/health/llm`

**Senaryo B — Backend + Ollama yeni makineye taşınırsa:**
1. Yeni makineye repo'yu clone et, `MISTRAL_URL=http://localhost:11434`
2. Flutter `.env` → `BACKEND_URL=http://<yeni-makine-ip>:8000`
3. Yeni makinenin firewall'unda 8000 portunu aç

### Key Conventions
- All UI text, persona descriptions, and LLM prompts are in **Turkish**.
- State management: Riverpod 3.x with code-generated providers (Freezed + `build_runner`).
- After changing any `@freezed` or `@JsonSerializable` class: `flutter pub run build_runner build --delete-conflicting-outputs`
- Backend model path is relative: `../MLPipeline/outputs/model/` — backend must be run from `backend/api/`.
