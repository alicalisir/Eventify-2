# Faz 3: LLM Tabanlı Etkinlik Öneri Sistemi — Kapsamlı Yol Haritası

**Tarih:** 2026-05-12
**Proje:** Context-Aware Event Recommendation System
**Kapsam:** Faz 3 (ML persona + LLM öneri sistemi) — Faz 0/1/2 ayrı yol haritasında

---

## Context

Mevcut Flutter uygulaması GPS + hava + (gelecekte) app/screen verisini Supabase'e topluyor. Arkadaşının **CatBoost ML modeli** bu verilerden kullanıcının **persona/segment**'ini çıkartacak. Bu yol haritasının kapsamı: **persona + RichContext + yakın mekanlar/etkinlikler** verilerini bir **LLM** ile birleştirerek kullanıcıya **kişiselleştirilmiş etkinlik önerileri** üreten sistemi tasarlamak ve uçtan uca entegre etmek.

Mevcut kodda `SuggestionRepository` ve `ContextService` mock data döndürüyor; `LlmPromptBuilder` ve `LlmContextPayload` stub durumda; LLM çağrısı yok. Bu döngünün tamamlanması Faz 3'ün ana hedefidir.

**Kullanıcı kararları (alınmış):**
- Etkinlik verisi: **Curated seed + Google Places** (MVP) → Web scraping V2'de
- LLM çalıştırma: **Kendi RTX 3080 GPU**'da self-host (Ollama / vLLM)
- Model tipi: **Pure İngilizce/multilingual base model** (Türkçe-finetune YOK); default **Mistral Nemo 12B Instruct**
- Retrieval: **V2'de RAG** (events ölçeklendiğinde); **fine-tuning kullanılmıyor** (problemimiz dinamik bilgi, stil değil)
- Backend: **Supabase Edge Functions (Deno)**
- MVP kapsamı: **Faz 3a (minimal uçtan uca)** önce, scraping/cache/eval sonra

---

## Mimari Üst Görünüm

```
┌──────────────────────────────────────────────────────────────────────┐
│  FLUTTER APP                                                          │
│  Dashboard → SuggestionRepository → LlmService                        │
│                                          │                            │
└──────────────────────────────────────────┼────────────────────────────┘
                                           │ HTTPS (JWT)
                                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SUPABASE EDGE FUNCTION  /functions/v1/recommend                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ 1. JWT doğrula → user_id                                      │    │
│  │ 2. Persona oku (users.persona_json)                           │    │
│  │ 3. Context al (body'den) + nearby places + events DB sorgu    │    │
│  │ 4. Cache kontrol (cached_suggestions, bucket_key)             │    │
│  │ 5. Prompt build (system EN + user TR + tool-schema)           │    │
│  │ 6. LLM çağrı: önce self-host, hata → Claude fallback          │    │
│  │ 7. Parse + validate + sanitize                                │    │
│  │ 8. Cache yaz + log (Langfuse)                                 │    │
│  │ 9. Response döndür                                            │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────┬───────────────────────────┘
                                           │
                  ┌────────────────────────┼────────────────────────┐
                  ▼                        ▼                        ▼
        ┌──────────────────┐    ┌──────────────────┐     ┌──────────────────┐
        │ Cloudflare Tunnel│    │ Anthropic API    │     │ Supabase Postgres│
        │ → Home GPU       │    │ (fallback)       │     │ - events         │
        │ → Ollama :11434  │    │ Claude Sonnet 4.6│     │ - cached_sugg    │
        │ Mistral Nemo 12B │    │                  │     │ - user_feedback  │
        │ (yedek: Llama 8B)│    │                  │     │ - users.persona  │
        └──────────────────┘    └──────────────────┘     └──────────────────┘
```

---

## Dal 1 — Etkinlik Veri Pipeline

**Karar:** Hibrit, üç-katmanlı kaynak.

| Katman | Kaynak | Faz | Sorumluluk |
|---|---|---|---|
| Tier 1 | Google Places API v1 (mevcut) | 3a | Her zaman aktif POI |
| Tier 2 | Supabase `events` tablosu (curated, manuel) | 3a | 30-50 İstanbul/Ankara etkinliği seed |
| Tier 3 | Web scraping (Biletix/Biletinial/Mobilet) | V2 | Haftalık batch crawler |

### `events` Tablo Şeması

```sql
create table public.events (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('curated','places','scraped')),
  external_id text,
  title text not null,
  description text,
  category text not null,           -- music|sports|culture|food|outdoor|workshop|family
  subcategory text,
  venue_name text,
  address text,
  city text,
  lat double precision,
  lng double precision,
  starts_at timestamptz,
  ends_at timestamptz,
  is_recurring boolean default false,
  recurrence_rule text,
  is_ticketed boolean default false,
  price_min numeric,
  price_max numeric,
  currency text default 'TRY',
  ticket_url text,
  image_url text,
  tags text[],
  language text default 'tr',
  popularity_score real default 0,
  embedding vector(1024),           -- pgvector (V2 RAG için bekliyor)
  embedding_model_version text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  expires_at timestamptz
);
```

### Cold-Start Fallback (yeni şehir / veri kıt)
1. Yarıçapı 1.5km → 10km'ye genişlet
2. Komşu şehir events (≤50km)
3. Places-only kategori-evrensel önerileri
4. "Yarın için planla" — bir sonraki güne kayma

### V2 — Web Scraping
- Hedef: Biletinial, Mobilet, biletimGO (dakikada 1 req rate limit)
- Biletix/Passo ertelendi: anti-bot agresif
- Dedupe: title+venue+starts_at hash ile

---

## Dal 2 — LLM Mimari Seçimi (RTX 3080 self-host)

**Karar:** Birincil: **Mistral Nemo 12B Instruct (Q4_K_M)** Ollama üzerinde. Cloud fallback: **Claude Sonnet 4.6**.

### Model Karşılaştırması (3080 10GB)

| Model | Boyut | VRAM (Q4) | Türkçe çıktı | Reasoning | Tok/s | Notlar |
|---|---|---|---|---|---|---|
| **Mistral Nemo 12B Instruct** | 12B | ~7 GB | İyi | **Güçlü** | ~22-28 | DEFAULT |
| Llama 3.3 8B Instruct | 8B | ~5 GB | Orta-İyi | İyi | ~35-45 | YEDEK |
| Phi-4 14B | 14B | ~9 GB | Zayıf-Orta | Çok güçlü | ~15-20 | Türkçe yetersiz |
| DeepSeek R1 distill 8B | 8B | ~5.5 GB | Zayıf | Mükemmel | ~30-35 | Türkçe sınırlı |
| Qwen 2.5 14B | 14B | ~9 GB | İyi | İyi | ~15-20 | Sınırda VRAM |

**Elenen alternatifler:**
- **DeepSeek V4**: V4-Flash bile minimum 33GB VRAM — RTX 3080 10GB'de fiziksel olarak imkansız.
- **Türkçe-finetune** (Trendyol-LLM vb.): E-ticaret odaklı, reasoning/JSON reliability sınırlı.

### Inference Stack
- Ollama: `ollama pull mistral-nemo:12b-instruct-q4_K_M`
- OpenAI-uyumlu API: `http://localhost:11434/v1/chat/completions`
- vLLM (production batching) → V2'ye ertelendi

### GPU'yu İnternet'e Açma
**Cloudflare Tunnel (cloudflared):** ücretsiz, sabit subdomain, zero-trust auth.
```bash
cloudflared tunnel --hostname gpu.alanin.com --url http://localhost:11434
```
Güvenlik: Service Token (`CF-Access-Client-Id/Secret`) Edge Function'da zorunlu.

### Fallback Stratejisi
```
self_host_health = ping(GPU_TUNNEL, timeout=300ms)
if self_host_health:        → Mistral Nemo 12B
elif ALLOW_CLOUD_FALLBACK:  → Claude Sonnet 4.6
else:                       → cached_or_popularity_based()
```

### Latency Beklentisi
- Self-host 12B Q4: full ~18-23s, ilk token ~2s (streaming ile ilk kart 3-4s'de görünür)
- Cloud Claude: full ~3-5s, ilk token ~0.8s
- Dashboard: önce cached gösterilir, paralel fresh stream alınır

### Prompt Tasarımı
- **System prompt: İngilizce** (instruction-following kalitesi)
- **User content + output: Türkçe** (multilingual pretraining yeterli)
- Output format: `<json>...</json>` delimiter + regex extract (Ollama tool-calling sınırlı)
- Claude fallback: native `tools` API
- Retry-once: parse fail → "Re-output strictly valid JSON only"

---

## Dal 3 — Retrieval Stratejisi: SQL → RAG

**Karar:** MVP: LLM-only + SQL pre-filter. V2: pgvector RAG (events >300 satır olunca).
**Fine-tuning kullanılmıyor** — problemimiz dinamik bilgi retrieval, stil değil.

### Neden RAG, Neden Fine-Tuning Değil?

| Boyut | RAG | Fine-Tuning |
|---|---|---|
| Çözdüğü problem | Dinamik **bilgi** retrieve etmek | Modelin **stilini** öğretmek |
| Bizim sorunumuz | ✅ Events sürekli değişiyor | ❌ Stil sabit, sorun değil |
| Yeni event eklenince | INSERT (saniyeler) | Tüm modeli yeniden eğit (saatler) |
| Maliyet | ~$0.02/M token embedding | $100-1000+ GPU + maintenance |
| Güncel kalma | Saniyeler | Her güncellemede yeniden eğitim |

**Kritik:** Fine-tune ile öğretilen event bilgisi hafta bittikten sonra yanlış faktüel bilgi üretir. RAG'da `DELETE FROM events WHERE expires_at < now()` yeterli.

### MVP Pre-Filter Sorgusu
```sql
select * from public.events
where city = $1
  and (starts_at is null or starts_at between now() and now() + interval '48 hours')
  and (expires_at is null or expires_at > now())
order by
  case when category = any($2::text[]) then 0 else 1 end,
  popularity_score desc,
  starts_at asc nulls last
limit 15;
```

### V2 RAG Eşiği
Events >300 satır **VEYA** scraping aktive **VEYA** çoklu şehir desteği → pgvector aktive edilir.
`embedding vector(1024)` kolonu MVP'de eklenir (boş kalır, V2'ye hazır).

---

## Dal 4 — Persona + Context → Prompt Pipeline

### Persona Contract (CatBoost model çıktısı)
```json
{
  "persona_id": "outdoor-active-2",
  "segment_label": "Outdoor Explorer",
  "traits": [
    {"label": "nature-lover", "confidence": 0.84},
    {"label": "early-bird", "confidence": 0.71}
  ],
  "preferences": {
    "outdoor": 0.91, "culture": 0.65, "food": 0.4,
    "music": 0.55, "sports": 0.3, "social": 0.6
  },
  "model_version": "catboost-v1.2",
  "inferred_at": "2026-05-12T08:30:00Z",
  "signals_processed": 1247
}
```
Bozuk veri koruması: confidence < 0.3 trait'ler atlanır; preferences boşsa "yeni kullanıcı" template'i.

### Genişletilmiş `LlmContextPayload`
```dart
@freezed
class LlmContextPayload with _$LlmContextPayload {
  factory LlmContextPayload({
    required PersonaModel persona,
    required ContextState context,
    required List<PlaceModel> nearbyPlaces,
    required List<EventModel> nearbyEvents,
    required List<String> userInterests,
    required List<String> recentDismissedTitles,
    required List<String> recentLikedCategories,
    @Default('tr-TR') String languageCode,
    required DateTime builtAt,
  }) = _LlmContextPayload;
}
```

### Prompt İskeleti (system EN, user TR)
```
SYSTEM:
You are a context-aware event recommendation assistant for a Turkish audience.
Output 3 suggestions in Turkish inside <json>...</json> tags.
Each: {id, title, category, rationale, rationale_signals[], match_score(0-1),
       distance_m?, venue_name?, event_id?}

Constraints:
- Diversity: ≥2 different categories.
- Weather: rainy/snow → no outdoor.
- Time: hour ≥22 → prefer indoor/open-late.
- Persona: top-2 traits with confidence ≥0.5.
- Avoid: titles in recent_dismissed list.
- Rationale: 1-2 sentence Turkish, mention specific signal.
- Rationale_signals: 2-4 labels, max 18 chars each.

[Few-shot example 1: rainy evening, foodie → café + museum + indoor concert]
[Few-shot example 2: sunny morning, outdoor → park + bike trail + brunch]

USER:
KULLANICI DURUMU: [saat, konum, hava, hareket, persona, ilgiler, ...]
YAKIN ETKINLIKLER (15): [...]
YAKIN MEKANLAR (10): [...]
3 öneri üret.
```

### Hard Constraints (Server-Side)
1. ≥2 farklı kategori (yoksa replace)
2. rain/snow → outdoor filtrele
3. recent_dismissed başlık eşleşmesi → filtrele
4. JSON şema doğrulama (Zod)

---

## Dal 5 — Caching & Cost Control

### `cached_suggestions` Şeması
```sql
create table public.cached_suggestions (
  cache_key text primary key,
  user_id uuid references public.users(id) on delete cascade,
  payload jsonb not null,
  llm_provider text,
  prompt_tokens int,
  completion_tokens int,
  latency_ms int,
  created_at timestamptz default now(),
  expires_at timestamptz not null
);
```

### Cache Key Bucket
```ts
sha256({ user_id, persona_version, lat_3dec, lng_3dec,
         hour_block (2h), weather_condition, day_of_week })
```

### Invalidation
- Konum delta >500m, hava değişti, yeni feedback, manual yenile, TTL geçti

---

## Dal 6 — Feedback Loop & Evaluation

### `user_feedback` Şeması
```sql
create table public.user_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  suggestion_id text not null,
  event_id uuid references public.events(id),
  action text not null check (action in
    ('view','open','like','dislike','save','dismiss','external_click','visit_confirmed')),
  suggestion_snapshot jsonb not null,
  context_snapshot jsonb,
  llm_provider text,
  created_at timestamptz default now()
);
```

### Evaluation
- **Offline:** 10 golden senaryo + LLM-as-judge (Claude API, 0-10 puan)
- **Online:** CTR, dismiss rate, diversity score (kategori entropisi)

---

## Dal 7 — Cold Start & Fallback

### Onboarding Genişlemesi
Mevcut 3 slide'a **4. slide** eklenecek: İlgi alanı seçici (en az 3 seç).

**Kategoriler:** Spor & Hareket | Yeme-İçme | Sanat & Kültür | Doğa & Açık Hava |
Eğlence & Gece | Eğitim & Atölye | Müzik & Konser | Aile & Çocuk | Sakin & Solo

### `users` Tablo Genişlemesi
```sql
alter table public.users
  add column interests text[] default '{}',
  add column consent_given_at timestamptz,
  add column persona_json jsonb,
  add column persona_updated_at timestamptz;
```

### Persona Blend (ilk 14 gün)
```
weight_manual = max(0, 1 - days_since_signup / 14)
weight_ml     = 1 - weight_manual
final_prefs   = manual * w_manual + ml_prefs * w_ml
```

---

## Dal 8 — Güvenlik, Privacy, KVKK

- Aydınlatma metni + açık rıza (`consent_given_at`) onboarding'de zorunlu
- LLM payload'dan PII çıkarılır (email/isim gönderilmez, konum 3 decimal)
- `gps_pings` 90 gün sonra `pg_cron` ile silinir
- Anthropic ABD host → aydınlatmada belirt; self-host bu riski azaltır
- Profile'da "Verilerimi sil" butonu (cascading delete)
- API anahtarları sadece Edge Function secrets (Flutter'da yok)

---

## Dal 9 — UI/UX

### Yeni Bileşenler
- `lib/ui/home/widgets/rationale_chip_row.dart` — 2-4 chip, max 18 karakter
- `lib/ui/suggestion/widgets/suggestion_actions_bar.dart` — Kalp / Yer-imi / X
- `lib/ui/onboarding/widgets/interests_selection_screen.dart` — FilterChip grid
- `lib/ui/onboarding/widgets/consent_screen.dart` — KVKK metni + checkbox

### Streaming UI (Faz 3b)
SSE → Flutter `Stream<SuggestionModel>` → kart kart UI'a düşer. İlk kart ~3s, tam liste ~15s.

---

## Dal 10 — Test, Deployment, Monitoring

- **Unit:** `LlmPromptBuilder.build()` snapshot, `LlmResponseParser.parse()` malformed JSON
- **Integration:** Mock LLM response ile `recommend` Edge Function (Deno test)
- **Langfuse:** Her LLM çağrısı için trace (provider, latency, cost) — savunma için altın değer
- **Sentry:** UI hataları (mevcut)
- **Deployment:** `supabase functions deploy recommend`, `supabase db push`

---

## Öncelik Matrisi

### Faz 3a — MVP (~12 gün)

| # | İş | Dal |
|---|---|---|
| 1 | `events` tablosu + migration'lar + 30-50 seed | 1 |
| 2 | `users` alter + `cached_suggestions` + `user_feedback` migration | 5,6,7,8 |
| 3 | RTX 3080: Ollama + Mistral Nemo 12B + smoke test | 2 |
| 4 | Cloudflare Tunnel + Service Token | 2,8 |
| 5 | `recommend` Edge Function (JWT → LLM → parse → response) | 2,4 |
| 6 | Claude fallback wiring | 2 |
| 7 | `LlmContextPayload` genişletme + `LlmPromptBuilder` gerçek prompt | 4 |
| 8 | `LlmService` (Flutter) + `SuggestionRepository` mock→gerçek | 2,4 |
| 9 | `EventModel` + `EventsService` + `EventsRepository` | 1 |
| 10 | `InterestsSelectionScreen` + `ConsentScreen` onboarding | 7,8,9 |
| 11 | `FeedbackService` + like/dismiss UI | 6,9 |
| 12 | `RationaleChipRow` widget | 9 |
| 13 | Smoke test + 3 cihaz manuel test | 10 |

### Faz 3b — Polish (1 hafta)
- Server cache aktif, rate limiting, Langfuse, SSE streaming, cold start blend, KVKK sil butonu

### V2 (tez sonrası)
- Web scraping, pgvector RAG, multi-model A/B, vLLM, online A/B

---

## Dosya Bazında Değişiklik Haritası

### Yeni Dosyalar — Supabase
```
supabase/migrations/20260513_001_enable_pgvector.sql
supabase/migrations/20260513_002_events_table.sql
supabase/migrations/20260513_003_users_add_columns.sql
supabase/migrations/20260513_004_cached_suggestions.sql
supabase/migrations/20260513_005_user_feedback.sql
supabase/seed/events_istanbul_ankara.sql
supabase/functions/recommend/index.ts
supabase/functions/recommend/prompt.ts
supabase/functions/recommend/cache.ts
supabase/functions/recommend/llm_self_host.ts
supabase/functions/recommend/llm_claude.ts
supabase/functions/recommend/parser.ts
supabase/functions/recommend/types.ts
supabase/functions/recommend/langfuse.ts
```

### Yeni Dosyalar — Flutter
```
lib/data/services/llm_service.dart
lib/data/services/feedback_service.dart
lib/data/services/events_service.dart
lib/data/repositories/feedback_repository.dart
lib/data/repositories/events_repository.dart
lib/domain/models/event_model.dart
lib/domain/models/user_feedback.dart
lib/ui/onboarding/widgets/interests_selection_screen.dart
lib/ui/onboarding/widgets/consent_screen.dart
lib/ui/home/widgets/rationale_chip_row.dart
lib/ui/suggestion/widgets/suggestion_actions_bar.dart
```

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `lib/domain/models/suggestion_model.dart` | `rationaleSignals`, `eventId`, `ticketUrl`, `matchScore` |
| `lib/domain/models/user_model.dart` | `interests`, `consentGivenAt` |
| `lib/domain/models/llm_context_payload.dart` | stub → gerçek (nearbyEvents, userInterests, dismissed, liked) |
| `lib/utils/llm_prompt_builder.dart` | stub → gerçek prompt |
| `lib/data/repositories/suggestion_repository.dart` | mock → LlmService çağrısı |
| `lib/data/services/context_service.dart` | mock suggestion bloğu silinir |
| `lib/data/services/auth_service.dart` | consent + interests write |
| `lib/di/providers.dart` | yeni provider'lar |
| `lib/ui/home/widgets/recommendation_card.dart` | RationaleChipRow + ActionsBar |
| `lib/ui/onboarding/widgets/onboarding_screen.dart` | 2 yeni ekran |
| `lib/routing/app_router.dart` | onboarding sub-routes |

---

## Sprint 1 (Hafta 1) — Gün Gün

| Gün | İş |
|---|---|
| 1 | Migration'ları yaz → Supabase Studio'da çalıştır → 30-50 seed gir |
| 2 | RTX 3080: Ollama kur → Mistral Nemo 12B çek → curl smoke test → Cloudflare Tunnel |
| 3 | `recommend` Edge Function minimal "echo" → Flutter'dan çağrı çalışıyor |
| 4 | LLM gerçek çağrı + JSON parse + validate; system prompt + few-shot |
| 5 | `LlmContextPayload` + `LlmPromptBuilder` gerçek implementasyon |
| 6 | `SuggestionRepository` mock→gerçek; `EventsRepository` + events SQL sorgu |
| 7 | Dashboard'da gerçek LLM çıktısı; smoke test; Sentry breadcrumb |

---

## Verification Plan

1. İstanbul Kadıköy 18:30 açık hava → ≥1 outdoor öneri
2. Ankara 22:00 yağmurlu → outdoor olmamalı
3. Yeni kullanıcı "doğa+sanat" seçti → bu kategorilerden öneri
4. Kalp/X → `user_feedback` satırı yazılıyor mu?
5. Ollama durdur → Claude fallback devreye giriyor mu?
6. Consent olmadan onboarding bitiş engelleniyor mu?
7. Her kartta 2-4 chip, Türkçe, <18 karakter mi?
8. Langfuse'da her LLM çağrısı izlenebiliyor mu?

---

## Açık Sorular

- **Persona contract:** Arkadaşın CatBoost çıktısı yukarıdaki şemayla birebir mi? → `docs/persona_contract.md` ile teyit.
- **Cloudflare hesap:** Var mı? Yoksa `*.trycloudflare.com` ücretsiz subdomain yeterli.
- **Throughput:** 3080'de 12B Q4 yavaş kalırsa → Llama 3.3 8B'ye geç (~50% daha hızlı).
- **Demo kullanıcı sayısı:** Jüri için n=1 mi n=3 mü? Yük testi gerekli mi?
- **Faz 1 önce mi sonra mı:** app_sessions/screen_events olmadan ML sinyalleri eksik kalır. Tezde "Faz 1 V2'ye ertelendi" notu yeterli mi?

---

## Sprint V2 — Branch: `feature/faz3-llm-pipeline-v2`

**Tarih:** 2026-05-25
**Durum:** Aktif geliştirme — Edge Function v6 deployed, canlı.

Bu sprint Faz 3a'nın üzerine inşa edilmiştir. Tüm çalışmalar `feature/faz3-llm-pipeline-v2` branch'inde, commit `206dbd3` ile tamamlanmıştır.

---

### Sprint V2 — Tamamlananlar

#### 1. Google Places API → LLM Pipeline Entegrasyonu

**Problem:** `PlacesRepository` ve `LlmService` birbirinden kopuktu; Edge Function yakındaki mekanları göremiyordu.

**Yapılanlar:**

*Flutter tarafı (`lib/data/services/llm_service.dart`):*
- `PlacesRepository` 4. constructor bağımlılığı olarak eklendi
- Weather ve places fetching paralel hale getirildi (`Future.wait` benzeri pattern)
- Nearby places serialize edilerek Edge Function request body'sine `nearby_places` field'ı olarak eklendi
- `lib/di/providers.dart`: `llmServiceProvider` → `placesRepositoryProvider` 4. argüman olarak geçiliyor

*Edge Function tarafı:*
- `supabase/functions/recommend/types.ts`:
  - `NearbyPlace` interface eklendi (`id, name, types, distance_m, address?, rating?, price_level?`)
  - `RecommendRequest`'e `nearby_places?: NearbyPlace[]` eklendi
- `supabase/functions/recommend/index.ts`:
  - `body.nearby_places ?? []` alınıp `buildUserMessage()`'a geçiliyor
  - Liked categories fetching `Promise.all` ile dismissed titles ile paralel hale getirildi
- `supabase/functions/recommend/prompt.ts`:
  - `buildUserMessage()` fonksiyonuna 4. parametre olarak `places: NearbyPlace[]` eklendi
  - User message template'e `NEARBY PLACES (N):` bloğu eklendi (name, primary type, distance, rating, price_level)

**Sonuç:** LLM artık hem yakın DB etkinliklerini hem de Google Places API'dan gelen gerçek zamanlı yakın mekanları görüyor ve öneri üretirken bu veriyi kullanıyor.

---

#### 2. Tam İngilizce Geçiş

**Karar:** Uygulamanın tek dili İngilizce — Türkçe string kalmayacak.

**Yapılanlar:**

*Edge Function (`supabase/functions/recommend/prompt.ts`):*
- System prompt: tamamı İngilizce
- Few-shot örnekler: İngilizce
- User message template: `"USER CONTEXT:"`, `"NEARBY EVENTS:"`, `"NEARBY PLACES:"`, `"Generate 3 suggestions."` — tamamı İngilizce
- Day names: `["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]`
- Persona fallback label: `"New user — no persona"`

*Flutter (`lib/ui/onboarding/widgets/onboarding_screen.dart`):*
- Consent sayfası metni İngilizce
- Interest kategorileri İngilizce: `Sports & Activity | Food & Drink | Arts & Culture | Nature & Outdoors | Entertainment & Nightlife | Education & Workshops | Music & Concerts | Family & Kids | Calm & Solo`
- CTA butonlar: "Continue", "Get Started"
- Validation mesajı: "Select at least 3 interests"

*Flutter (`lib/ui/home/widgets/recommendation_card.dart`):*
- Tooltip'ler: "Like" / "Liked" / "Dismiss"

---

#### 3. Kocaeli Seed Verisi

**Problem:** Ankara seed verisi kullanılıyordu; projenin hedef şehri Kocaeli.

**Yapılanlar (`supabase/seed/events_istanbul_ankara.sql`):**
- Ankara etkinlikleri (14 satır) Supabase'den silindi
- Kocaeli etkinlikleri üretildi ve Supabase'e yüklendi (14 satır)
- Tüm 42 seed etkinliği (28 İstanbul + 14 Kocaeli) İngilizce olacak şekilde güncellendi
- Kocaeli mekanları: Seka Park, Sapanca Gölü, Kartepe Kayak Merkezi, Körfez Marina, Kocaeli Müzesi, İzmit Körfezi kıyı yolu, vb.

**Smoke test (`test/places_api_smoke_test.dart`):**
- Koordinatlar: `lat = 40.7654, lon = 29.9408` (İzmit merkezi)
- Radius: 1000m → 1500m
- Yorum: `// Kocaeli (İzmit) coordinates`

---

#### 4. Kritik Bug Düzeltmeleri

**Bug #1 — `SuggestionCategoryX` Yanlış Kategori Adları**

*Dosya:* `lib/domain/models/suggestion_category.dart`

*Problem:* Extension, eski `movement | recharge | learning | social | health` kategorilerini map ediyordu. LLM `music | sports | culture | food | outdoor | workshop | family` çıktısı üretiyor. Tüm kartlar fallback icon (`Icons.auto_awesome`) ve aynı mor gradyan (hue 250) gösteriyordu.

*Düzeltme:*
```dart
// Eski (yanlış):
case 'movement': return Icons.directions_walk_outlined;  // hue 150
case 'recharge': return Icons.local_cafe_outlined;       // hue 30
case 'learning': return Icons.menu_book_outlined;        // hue 270
case 'social':   return Icons.people_outline;            // hue 210
case 'health':   return Icons.favorite_outline;          // hue 340

// Yeni (doğru — LLM çıktısıyla eşleşiyor):
case 'music':    return Icons.music_note_outlined;       // hue 280
case 'sports':   return Icons.directions_run_outlined;   // hue 150
case 'culture':  return Icons.museum_outlined;           // hue 220
case 'food':     return Icons.restaurant_outlined;       // hue 30
case 'outdoor':  return Icons.park_outlined;             // hue 120
case 'workshop': return Icons.build_outlined;            // hue 45
case 'family':   return Icons.family_restroom_outlined;  // hue 200
```

**Bug #2 — Onboarding İlgi Alanı Etiketleri ≠ DB Kategori Slug'ları**

*Dosya:* `supabase/functions/recommend/index.ts`

*Problem:* `nearby_events` RPC'de sıralama `case when category = any(p_interests) then 0 else 1 end` ile yapılıyor. Ancak `p_interests` `"Music & Concerts"` içerirken `category` kolonu `"music"` tutuyor — hiçbir zaman eşleşme olmuyordu, interests-first sıralama hiç çalışmıyordu.

*Düzeltme:* `normalizeInterest()` fonksiyonu eklendi:
```typescript
function normalizeInterest(label: string): string {
  const map: Record<string, string> = {
    "music & concerts":        "music",
    "sports & activity":       "sports",
    "arts & culture":          "culture",
    "food & drink":            "food",
    "nature & outdoors":       "outdoor",
    "education & workshops":   "workshop",
    "family & kids":           "family",
    "entertainment & nightlife": "music",
    "calm & solo":             "culture",
  };
  return map[label.toLowerCase()] ?? label.toLowerCase();
}
```
`userInterests` artık RPC'ye geçmeden önce `rawInterests.map(normalizeInterest)` ile normalize ediliyor.

---

### Sprint V2 — Mevcut Sistem Durumu

```
Flutter App
  LlmService(supabase, location, weather, places)  ← places entegre
      ↓ POST /functions/v1/recommend (JWT)
      body: { lat, lng, city, weather_*, hour, dow, motion,
              user_interests[], nearby_places[] }   ← places gönderiliyor

Edge Function v6 (ACTIVE, deployed 2026-05-25)
  normalizeInterest() → userInterests (slug'lar)
  → nearby_events RPC (interests-first sıralama ÇALIŞIYOR)
  → buildUserMessage(req, persona, nearbyEvents, nearbyPlaces)
  → LLM (self-host Mistral / fallback Claude)
  → parser → hard constraints → cache → response

SuggestionCategoryX
  music    → Icons.music_note_outlined    (hue 280)
  sports   → Icons.directions_run_outlined (hue 150)
  culture  → Icons.museum_outlined        (hue 220)
  food     → Icons.restaurant_outlined    (hue 30)
  outdoor  → Icons.park_outlined          (hue 120)
  workshop → Icons.build_outlined         (hue 45)
  family   → Icons.family_restroom_outlined (hue 200)

Seed Data
  28 Istanbul + 14 Kocaeli events (tümü İngilizce)
  Edge Function URL: /functions/v1/recommend
```

---

### Sprint V2 — Kalan / Sonraki Adımlar

Aşağıdaki işler Faz 3b ve V2 roadmap'ine göre sıralıdır. Yeni bir chat'te buradan devam edilecek.

#### Faz 3b — Polish (Kısa Vadeli, ~1 Hafta)

| # | İş | Dosya / Konum | Notlar |
|---|---|---|---|
| 1 | **Server cache aktif + invalidation logic** | `supabase/functions/recommend/index.ts`, `cached_suggestions` tablosu | Cache key zaten üretiliyor, SELECT/UPSERT zaten var; eksik: Flutter tarafında konum delta >500m ve hava değişimi cache invalidation tetikleyicisi |
| 2 | **Rate limiting** | `index.ts` başına kullanıcı bazlı sayaç | Son 1 saatte ≤10 LLM çağrısı; aşılınca cached veya 429 |
| 3 | **Langfuse entegrasyonu** | `supabase/functions/recommend/langfuse.ts` | Her LLM çağrısı için trace: provider, latency, prompt/completion tokens, user_id. Bitirme savunması için screenshot hazır olacak. Ücretsiz tier yeterli. |
| 4 | **SSE Streaming (Edge Function → Flutter)** | `index.ts` + `lib/data/services/llm_service.dart` | Self-host LLM yanıt ~18-23s; streaming ile ilk kart 3-4s'de görünür. Flutter'da `Stream<SuggestionModel>` ile kart kart render. |
| 5 | **Cold start blend logic** | `index.ts` veya Flutter `SuggestionRepository` | İlk 14 gün: `weight_ml = days/14`, `weight_manual = 1 - weight_ml`. Persona yoksa manuel interests %100. |
| 6 | **KVKK "Verilerimi sil" butonu** | `lib/ui/profile/` | Supabase cascading delete: `users` → tüm bağlı tablolar. Profile ekranında dialog. |
| 7 | **Golden set + LLM-as-judge eval** | `docs/eval_golden_set.json` (10 senaryo) | Claude API ile haftalık offline değerlendirme. Ortalama ≥7/10 hedefi. |

#### V2 — Uzun Vadeli (Tez Sonrası / Extension)

| # | İş | Dal | Detay |
|---|---|---|---|
| 1 | **Web Scraping Pipeline** | Dal 1 | Biletinial + Mobilet + biletimGO. Headless Playwright, dakikada 1 req. Dedupe: title+venue+starts_at hash. `source='scraped'`. Biletix/Passo ertelendi (anti-bot). |
| 2 | **pgvector RAG Aktivasyonu** | Dal 3 | Eşik: events >300 satır VEYA scraping aktif VEYA çoklu şehir. `embedding vector(1024)` kolonu zaten şemada var (boş). Embedding job: yeni event → Supabase trigger → `embed-events` Edge Function. Embedding model: `cohere-embed-multilingual-v3`. Query: cosine + BM25 hybrid + RRF. |
| 3 | **Multi-Model A/B Testi** | Dal 2 | Mistral Nemo 12B vs Llama 3.3 8B vs Claude Sonnet — kalite/hız/maliyet karşılaştırması. Langfuse'dan A/B metrics. |
| 4 | **Ollama → vLLM Migrasyonu** | Dal 2 | vLLM: batching, daha yüksek throughput (2-3x), OpenAI-uyumlu API aynı kalır. `SELF_HOST_MODEL` env var'ı değişmez. |
| 5 | **Online A/B + Diversity Optimization** | Dal 6 | CTR = open/view. Diversity score = 3 önerinin kategori entropisi. Persona-fit: visit_confirmed/like ile traits korelasyonu. |
| 6 | **Persona Blend Tuning** | Dal 7 | Explicit (onboarding) vs implicit (ML) signal füzyonu. 1000+ feedback sonrası LoRA fine-tune opsiyonu (stil, bilgi değil). |
| 7 | **Çoklu Şehir Desteği** | Dal 1 | Şu an İstanbul + Kocaeli. V2'de tüm büyük şehirler. Scraping tetikleyicisi. |

---

### Yeni Chat için Başlangıç Kontrol Listesi

Yeni bir chat açıldığında bu dosyayı okuttuktan sonra şu adımlarla devam edilebilir:

1. **Mevcut branch:** `feature/faz3-llm-pipeline-v2`
2. **Edge Function:** `recommend` v6, Supabase project `oovocuwnkewmwmgmcmip` üzerinde deployed ve aktif
3. **Seed data:** 28 İstanbul + 14 Kocaeli eventi Supabase'de mevcut (tümü İngilizce)
4. **Öncelikli sonraki iş:** Faz 3b #3 Langfuse entegrasyonu VEYA #4 SSE Streaming
5. **Dikkat:** `nearby_events` RPC `p_interests` parametresi artık normalize slug alıyor (`"music"` gibi) — onboarding'den gelen ham label'ları Edge Function'a göndermeden önce normalize etme artık `index.ts`'de yapılıyor
6. **Dikkat:** `SuggestionCategoryX` artık doğru kategorileri map ediyor — yeni bir kategori LLM'den gelirse `suggestion_category.dart`'a eklenmeli
