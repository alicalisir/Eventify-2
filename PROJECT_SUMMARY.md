# Context-Aware Event Recommendation System — Proje Özeti

Bu dosya, projenin tüm katmanlarını, mimarisini ve teknik detaylarını özetler.
Yeni bir Claude oturumunda bu dosyayı okutarak projeyi sıfırdan açıklayabilirsiniz.

---

## 1. Proje Nedir?

**Bağlam-Duyarlı Etkinlik Öneri Sistemi** — kullanıcının Android telefonundan toplanan
sensör verisini (GPS, uygulama kullanımı, ekran olayları, hareket) analiz ederek
kullanıcıya özel bir **persona** çıkaran, ardından bu personaya ve anlık konuma göre
etkinlik + mekan önerileri sunan bir mobil + backend sistemidir.

**Tech stack özeti:**
- Flutter (Android mobil uygulama)
- FastAPI (Python backend + CatBoost ML)
- Supabase (PostgreSQL veritabanı + Auth + Edge Functions)
- Kotlin Android native (ForegroundService, WorkManager, Activity Recognition)
- Ollama / Anthropic Claude (LLM öneri üretimi)
- Google Places API, OpenWeather API

---

## 2. Dizin Yapısı

```
Context-Aware-Event-Recommendation-System/
├── backend/
│   ├── api/                          # FastAPI sunucusu
│   │   ├── main.py                   # Ana API (1500+ satır)
│   │   ├── feature_engineering.py    # Özellik çıkarımı (hem eğitim hem prod)
│   │   ├── episodes.py               # Kural tabanlı episode tespiti
│   │   ├── event_scraper.py          # Etkinlik veri toplama
│   │   ├── batch_classify.py         # Toplu persona sınıflandırma
│   │   ├── requirements.txt
│   │   ├── model/                    # Eğitilmiş model dosyaları
│   │   │   ├── catboost_persona.cbm  # CatBoost modeli
│   │   │   ├── feature_columns.json  # 90 özellik sırası
│   │   │   └── label_encoder.json    # 12 persona etiketi
│   │   ├── .env                      # Ortam değişkenleri
│   │   └── Procfile                  # Railway deployment
│   └── MLPipeline/                   # Model eğitim pipeline'ı
│       ├── feature_engineering.py    # Kanonik özellik çıkarıcı (paylaşılan)
│       ├── train_catboost_persona_model.py
│       ├── evaluate_persona_model.py
│       ├── generate_training_data.py
│       ├── simulation/               # Ajan tabanlı sentetik veri üretici
│       │   ├── simulate.py           # Ana giriş noktası
│       │   ├── personas.py           # 12 persona tanımı
│       │   ├── agent.py              # Kullanıcı ajan simülasyonu
│       │   ├── episodic.py           # 15 yaşam episodu
│       │   ├── planner.py            # Günlük planlayıcı
│       │   └── behavior.py           # Davranış kuralları
│       └── outputs/
│           ├── model/                # Eğitilmiş artifaktlar
│           └── reports/              # Metrikler, karmaşıklık matrisi, SHAP
├── context_aware_event_recommendation_system/  # Flutter uygulaması
│   ├── lib/
│   │   ├── main.dart                 # Uygulama girişi, Supabase init, Sentry
│   │   ├── routing/app_router.dart   # GoRouter (8 rota)
│   │   ├── domain/models/            # Veri modelleri (Freezed)
│   │   ├── data/services/            # Tüm servisler
│   │   ├── data/repositories/        # Repository katmanı
│   │   ├── ui/                       # Ekranlar ve widget'lar
│   │   └── di/providers.dart         # Riverpod DI konteyneri
│   └── android/app/src/main/kotlin/  # Android native Kotlin kodu
│       ├── MainActivity.kt           # MethodChannel host
│       ├── ScreenEventService.kt     # Ekran olayları ForegroundService
│       ├── AppUsageWorker.kt         # WorkManager 15dk periyodik
│       ├── AppUsageCollector.kt      # UsageStatsManager okuyucu
│       ├── ActivityRecognitionReceiver.kt  # Hareket tanıma
│       └── BootReceiver.kt           # Cihaz yeniden başlatma
├── supabase/
│   ├── migrations/                   # SQL şema dosyaları
│   └── functions/recommend/          # Deno edge function (SSE streaming)
│       ├── index.ts                  # Ana edge function
│       ├── prompt.ts                 # LLM prompt oluşturucu
│       ├── llm_self_host.ts          # Ollama entegrasyonu
│       └── llm_claude.ts             # Anthropic Claude yedek
└── CLAUDE.md                         # Claude Code kılavuzu
```

---

## 3. Veri Akışı (Uçtan Uca)

```
[Android Sensörler]
  ScreenEventService     → ekran aç/kapat/kilit (BroadcastReceiver)
  AppUsageWorker         → uygulama kullanım süresi (UsageStatsManager, 15dk)
  ActivityRecognitionReceiver → yürüme/araç/bisiklet/durağan (Google Play)
  GpsCollectionService   → GPS pingleri her 5 dakika (background service)
        ↓ (SharedPreferences bridge → Flutter)
[Supabase PostgreSQL]
  gps_pings, app_sessions, screen_events tabloları
        ↓
[FastAPI Backend]
  1. Supabase'den ham veri çek (son 14 gün)
  2. extract_user_features() → 90 boyutlu vektör
  3. compute_episode_shares() → 15 episode yüzdesi
  4. CatBoost.predict_proba() → 12 persona olasılığı
  5. En yüksek olasılıklı persona seç (düşük güven → HYBRID)
  6. Yakın mekanları çek (Google Places API, 1.5 km)
  7. Yakın etkinlikleri çek (Supabase RPC nearby_events)
  8. Kullanıcı geçmiş feedback'ini çek (beğenilmeyenler hariç tut)
  9. LLM (Ollama/Claude) → 3 öneri seç (JSON)
  10. 1 saatlik cache'e kaydet
        ↓
[Flutter UI]
  SSE stream → kart kart progressif gösterim
  DashboardScreen → öneri kartları
  SuggestionDetailScreen → harita + detay
  Beğen/beğenme/geç → user_feedback tablosuna kayıt
```

---

## 4. Veritabanı Şeması (Supabase PostgreSQL)

### `users`
```sql
id uuid pk, email text, name text,
has_completed_onboarding boolean,
interests text[],           -- onboarding seçimleri
consent_given_at timestamptz,  -- KVKK/GDPR onay zamanı
persona_json jsonb,         -- son persona {id, name, traits, preferences}
persona_updated_at timestamptz  -- 24 saatlik TTL
```

### `gps_pings`
```sql
id bigserial pk, user_id uuid fk, timestamp timestamptz,
latitude float8, longitude float8, accuracy float,
speed_mps float, movement_state text,  -- stationary/walking/cycling/transit/vehicle
dwell_time_s float
-- RLS: kullanıcı kendi verisini görür
```

### `app_sessions`
```sql
id bigserial pk, user_id uuid fk, timestamp timestamptz,
app_name text, category text, duration_min float, state text
-- UNIQUE: (user_id, app_name, timestamp) — tekrar önleme
```

### `screen_events`
```sql
id bigserial pk, user_id uuid fk, timestamp timestamptz,
event_type text  -- on / off / unlock
```

### `events` (etkinlik kataloğu)
```sql
id uuid pk, title text, description text,
category text,  -- music/sports/culture/food/outdoor/workshop/family
city text, lat float8, lng float8,
starts_at timestamptz, ends_at timestamptz,
is_recurring boolean, is_ticketed boolean,
price_min numeric, price_max numeric, currency text,
tags text[], embedding vector(1024),  -- pgvector
expires_at timestamptz  -- NULL = süresiz
```

### `cached_suggestions` (1 saatlik TTL cache)
```sql
cache_key text pk,  -- sha1(user_id + saat_dilimi)
user_id uuid fk, payload jsonb,
llm_provider text, latency_ms int,
expires_at timestamptz
```

### `user_feedback`
```sql
id uuid pk, user_id uuid fk,
suggestion_id text, event_id uuid fk,
action text,  -- view/open/like/dislike/save/dismiss/external_click/visit_confirmed
suggestion_snapshot jsonb,  -- üretim anındaki tam öneri
context_snapshot jsonb      -- üretim anındaki konum/hava/hareket
```

---

## 5. FastAPI Endpoint'leri

| Method | Endpoint | Açıklama | Cache |
|--------|----------|----------|-------|
| GET | `/health` | Model durumu | — |
| GET | `/api/health/llm` | LLM erişilebilirlik | 5s |
| GET | `/api/persona/{user_id}` | Persona sınıflandırma | 24s |
| GET | `/api/recommendations/{user_id}?lat=X&lon=Y` | Öneri listesi (3 tier) | 1s |
| GET | `/api/debug/episodes/{user_id}` | Episode dağılımı | — |
| GET | `/api/debug/realtime/{user_id}` | Son 1 saat anlık bağlam | — |
| GET | `/api/debug/events/{city}` | Etkinlik kataloğu önizleme | — |
| POST | `/api/admin/scrape-events` | Manuel etkinlik toplama | — |

---

## 6. 12 Persona

```
EARLY_BIRD        — Sabah erken aktif, düzenli, kahve/park
HOMEBODY          — Yüksek ev süresi, düşük mobilite, kitap/cafe
NIGHT_OWL         — 22:00-03:00 aktif, sosyal, bar/gece kulübü
HYBRID            — Dengeli, karma davranış (düşük güven fallback)
CONTENT_CONSUMER  — Yüksek streaming/video kullanımı
IRREGULAR         — Değişken paternler, stres sinyalleri
STUDENT           — Eğitim uygulamaları, kütüphane/cafe
GAMER             — Yüksek oyun süresi, geç saatler
PROFESSIONAL      — İş saatleri, networking, iş uygulamaları
TRAVELER          — Yüksek günlük mesafe, keşif, çeşitli POI
SOCIAL            — Yüksek sosyal medya, grup aktiviteleri
ATHLETE           — Fitness uygulamaları, hareket, açık hava
```

---

## 7. ML Pipeline Detayları

### Eğitim Süreci
1. **Simülasyon**: 1000 eğitim + 300 test sentetik kullanıcı (14 gün × kullanıcı)
2. **Özellik çıkarımı**: `feature_engineering.py` → 90 boyutlu vektör
3. **CatBoost eğitimi**:
   ```python
   CatBoostClassifier(
     loss_function="MultiClass",
     iterations=1500,
     learning_rate=0.05,
     depth=6,
     auto_class_weights="Balanced"
   )
   ```
4. **Sonuçlar**: Doğruluk %94.33, Top-2 %98.67, Macro-F1: 0.937

### 90 Özellik Grupları
- **Uygulama oturumu istatistikleri** (6): total_screen_min, mean/median session, num_sessions, unique_apps, foreground_ratio
- **Kategori payları** (19): share_cat_social, gaming, video, streaming, messaging, fitness, vb.
- **Saatlik dağılım** (28): hour_share_00..23 + 4 sirkadiyen blok + weekend_ratio + p90/p10
- **GPS/Mobilite** (14): radius_of_gyration, daily_distance_m, visited_cells, movement_state_share_*, dwell_time
- **Ekran olayları** (5): unlocks, on, off, notifications, notif_per_unlock
- **Episode payları** (15): ep_share_SLEEP, COMMUTE, WORK_DAY, GAMING_MARATHON, vb.

### Kritik Not
`backend/MLPipeline/feature_engineering.py` **hem eğitimde hem de production'da** kullanılır.
`backend/api/main.py` bu dosyayı import eder. Herhangi bir özellik değişikliği her iki
yerde eş zamanlı etkili olur — modeli yeniden eğitmek gerekir.

---

## 8. 3 Katmanlı Öneri Sistemi

```
Tier 1 (LLM-Zenginleştirilmiş):
  Koşul: GPS mevcutsa
  - Google Places API (1.5 km, persona filtrelenmiş mekan türleri)
  - Supabase RPC nearby_events (şehir bazlı, 72 saatlik pencere)
  - Ollama (qwen2.5:14b) veya Claude → JSON 3 öneri
  - Yapı: {item_ref, title, description, rationale, category, estimated_minutes}

Tier 2 (Places-only):
  Koşul: LLM başarısız olursa
  - Google Places sonuçlarını doğrudan formatla

Tier 3 (Statik Persona):
  Koşul: GPS/API yoksa
  - main.py içindeki _PERSONA_META'dan statik öneriler
  - Her zaman 3 kart döner (tam offline fallback)
```

---

## 9. Supabase Edge Function (SSE Streaming)

`supabase/functions/recommend/index.ts` (Deno/TypeScript):

1. Auth: Bearer token doğrula
2. `users.persona_json` → persona yükle
3. `nearby_events()` RPC → yakın etkinlikler
4. Kullanıcı feedback → hariç tutulacak ID'ler
5. LLM (self-host Ollama önce, cloud Claude yedek)
6. Her öneriyi ayrı `data: {...}` mesajı olarak stream et
7. `cached_suggestions`'a kaydet
8. Langfuse ile gözlemlenebilirlik

---

## 10. Flutter Uygulama Mimarisi

### Navigasyon (GoRouter, 8 rota)
```
/login → /register → /onboarding → /dashboard
                                      ├── /suggestion/:id
                                      ├── /profile
                                      └── /preferences
```

### State Management (Riverpod)
- `authProvider` — oturum durumu
- `suggestionStreamProvider` — SSE streaming öneriler
- `ambientContextProvider` — anlık hava/konum/zaman
- `visibleSuggestionsProvider` — reddedilenler filtrelenmiş liste
- `feedbackServiceProvider` — kullanıcı etkileşim kaydı

### Önemli Servisler
| Servis | Görev |
|--------|-------|
| `GpsCollectionService` | Background GPS (5 dakika aralık) |
| `AppUsageService` | SharedPrefs buffer → Supabase upload |
| `ScreenEventService` | Native bridge → ekran olayları |
| `BackendService` | FastAPI HTTP çağrıları |
| `LLMService` | Supabase edge function SSE stream |
| `FeedbackService` | Kullanıcı etkileşimlerini kaydet |

### Otomatik Yenileme Koşulları
- Kullanıcı 500m'den fazla hareket ettiğinde
- Hava durumu değiştiğinde
- Görünür öneriler tükendiğinde
- Uygulama arka plandan öne geldiğinde

---

## 11. Android Native Bileşenler

### MethodChannel'lar (MainActivity.kt)
- `com.example.caers/screen_events` — ekran servisini başlat/durdur/flush
- `com.example.caers/activity_recognition` — hareket takibini başlat/durdur
- `com.example.caers/app_info` — uygulama kategorisi meta verisi

### Servisler
| Bileşen | Tip | Görev |
|---------|-----|-------|
| `ScreenEventService` | ForegroundService | Ekran aç/kapat/kilit (BroadcastReceiver) |
| `AppUsageWorker` | WorkManager (15dk) | UsageStatsManager → JSON buffer |
| `ActivityRecognitionReceiver` | BroadcastReceiver | Google hareket API (30s, %50 güven) |
| `BootReceiver` | BroadcastReceiver | Cihaz yeniden başlatmada servisleri ayağa kaldır |

### SharedPreferences Bridge
Android native servisler → `flutter.*` prefix ile Flutter SharedPreferences'a yazar.
Flutter background service aynı prefs'i okur. IPC overhead yok.

---

## 12. Ortam Değişkenleri

### `backend/api/.env`
```
SUPABASE_URL=https://...supabase.co
SUPABASE_SERVICE_KEY=...
GOOGLE_PLACES_API_KEY=...
MISTRAL_URL=http://localhost:11434   # Ollama sunucu adresi
LLM_MODEL=qwen2.5:14b
ADMIN_SECRET=...
```

### `context_aware_event_recommendation_system/.env`
```
SUPABASE_URL=https://...supabase.co
SUPABASE_ANON_KEY=...
BACKEND_URL=http://...              # FastAPI sunucu adresi
OPENWEATHER_API_KEY=...
GOOGLE_PLACES_API_KEY=...
```

---

## 13. Deployment

- **Backend**: Railway (FastAPI, `Procfile` mevcut)
- **Veritabanı**: Supabase Cloud
- **Edge Functions**: Supabase (otomatik deploy)
- **Mobil**: Flutter Android APK (release build)
- **LLM**: Ollama self-hosted (aynı makine veya LAN'daki başka makine)

---

## 14. Önemli Teknik Detaylar

- **Timezone inference**: Explicit alan yok; medyan GPS koordinatlarından `timezonefinder` ile hesaplanır
- **Persona cache**: `sha1(user_id + saat_dilimi)` → 1 saatlik TTL
- **Feedback exclusion**: "dislike" veya "dismiss" → hariç tut; sonraki "like" → geri al
- **Simüle veri**: Tüm model gerçek kullanıcı verisi olmadan 9.4M sentetik event ile eğitildi
- **Episode tespiti**: ML yok, saf kural tabanlı (30 dakikalık pencere, dominant kategori + zaman + konum)
- **Radius of gyration**: `sqrt(mean(haversine_distance²))` — mobilite yayılımı ölçütü
- **GDPR/KVKK**: `consent_given_at` zorunlu, `interests` onboarding'de toplana, tam audit trail

---

## 15. Model Performansı

| Metrik | Değer |
|--------|-------|
| Test Doğruluğu | %94.33 |
| Top-2 Doğruluk | %98.67 |
| Macro-F1 | 0.9370 |
| Eğitim verisi | 1000 kullanıcı × 14 gün |
| Test verisi | 300 ayrı kullanıcı |
| Özellik boyutu | 90 |
| Sınıf sayısı | 12 |

En düşük F1: HYBRID (0.688) — beklenen, 2-3 personanın karışımı  
En yüksek F1: TRAVELER (1.000), GAMER (0.984), SOCIAL (0.980)

En ayırt edici özellikler (CatBoost gain + SHAP):
1. `share_cat_news`
2. `share_cat_short_video`
3. `share_cat_streaming`
4. `share_cat_gaming`
5. `share_cat_fitness`

---

*Bu dosya `PROJECT_SUMMARY.md` olarak proje kökünde bulunur.*
*Tez yazımı, mimari sorular veya yeni özellik geliştirme için bu dosyayı Claude'a okutun.*
