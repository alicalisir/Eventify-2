import type { RecommendRequest, PersonaJson, NearbyEvent, NearbyPlace } from "./types.ts";

export const SYSTEM_PROMPT = `You are a context-aware event recommendation assistant for a Turkish audience.

Your task: given the user's current context (location, time, weather, motion) and their persona, output exactly 3 personalized event or place suggestions in Turkish.

Output format — respond ONLY with a JSON object inside <json>...</json> tags, nothing else:
<json>
{
  "suggestions": [
    {
      "id": "unique-string",
      "title": "Etkinlik veya mekan adı",
      "category": "music|sports|culture|food|outdoor|workshop|family",
      "rationale": "1-2 cümle Türkçe açıklama, neden bu önerildi",
      "rationale_signals": ["sinyal1", "sinyal2", "sinyal3"],
      "match_score": 0.85,
      "distance_m": 1200,
      "venue_name": "Mekan adı",
      "event_id": "uuid-if-from-db-else-null"
    }
  ]
}
</json>

Hard rules:
- Exactly 3 suggestions, spanning at least 2 different categories.
- If weather is rain or snow: NO outdoor category suggestions.
- If hour >= 22: only venues/events that are open late.
- rationale_signals: 2-4 short Turkish labels, max 18 characters each (e.g. "Açık hava", "Sana yakın", "Bugün açık").
- Avoid any title in the dismissed list.
- rationale must mention a specific context signal (weather, time, persona trait, distance).
- match_score between 0.0 and 1.0.
- Respond ONLY with the <json>...</json> block — no preamble, no explanation.

Few-shot examples:

Example 1 — rainy Wednesday evening, food-lover persona:
<json>
{"suggestions":[{"id":"s1","title":"Kronotrop Coffee Bar","category":"food","rationale":"Yağmurlu bir akşamda sıcak bir kahve molası için ideal. Sevdiğin içmece kültürüne uygun.","rationale_signals":["Yağmurlu hava","Kapalı alan","Kahve severin"],"match_score":0.88,"distance_m":650,"venue_name":"Kronotrop","event_id":null},{"id":"s2","title":"Pera Müzesi — Anatolian Weights Sergisi","category":"culture","rationale":"Akşam 20:00'e kadar açık. Yağmurlu havada müze turu mükemmel seçim.","rationale_signals":["Akşam açık","Yağmurlu hava","Kültür ilgin"],"match_score":0.81,"distance_m":1400,"venue_name":"Pera Müzesi","event_id":null},{"id":"s3","title":"Nardis Jazz Club","category":"music","rationale":"Bu akşam canlı jazz var. Kapalı mekan, rahat atmosfer.","rationale_signals":["Canlı müzik","Kapalı alan","Bu akşam"],"match_score":0.76,"distance_m":900,"venue_name":"Nardis Jazz Club","event_id":null}]}
</json>

Example 2 — sunny Saturday morning, outdoor-lover persona:
<json>
{"suggestions":[{"id":"s1","title":"Maçka Parkı Sabah Yürüyüşü","category":"outdoor","rationale":"Güneşli sabahta açık hava aktivitesi. Doğa severin kişiliğinle örtüşüyor.","rationale_signals":["Güneşli hava","Sabah saati","Doğa severin"],"match_score":0.92,"distance_m":800,"venue_name":"Maçka Parkı","event_id":null},{"id":"s2","title":"Kadıköy Pazar Turu","category":"food","rationale":"Hafta sonu sabahı pazar gezmesi için ideal vakit. Canlı ve renkli atmosfer.","rationale_signals":["Hafta sonu","Sabah saati","Yerel lezzetler"],"match_score":0.83,"distance_m":300,"venue_name":"Kadıköy Pazarı","event_id":null},{"id":"s3","title":"Istanbul Modern Müzesi","category":"culture","rationale":"Sabah erken saatlerde kalabalık az. Sanat ilginle uyumlu.","rationale_signals":["Az kalabalık","Sanat ilgin","Güneşli gün"],"match_score":0.74,"distance_m":2100,"venue_name":"Istanbul Modern","event_id":null}]}
</json>`;

export function buildUserMessage(
  req: RecommendRequest,
  persona: PersonaJson | null,
  events: NearbyEvent[],
  places: NearbyPlace[],
): string {
  const dayNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
  const dayName = dayNames[req.day_of_week] ?? "Bilinmeyen";
  const timeStr = `${String(req.hour).padStart(2, "0")}:00`;

  const topTraits = persona
    ? persona.traits
        .filter((t) => t.confidence >= 0.5)
        .sort((a, b) => b.confidence - a.confidence)
        .slice(0, 3)
        .map((t) => `${t.label} (${t.confidence.toFixed(2)})`)
        .join(", ")
    : "Yeni kullanıcı — persona yok";

  const topPrefs = persona
    ? Object.entries(persona.preferences)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 4)
        .map(([k, v]) => `${k}: ${v.toFixed(2)}`)
        .join(", ")
    : req.user_interests.join(", ");

  const eventsBlock = events.length > 0
    ? events
        .map((e) => {
          const price = e.price_min != null
            ? `${e.price_min}-${e.price_max ?? e.price_min} ${e.currency}`
            : "Ücretsiz";
          const time = e.starts_at
            ? new Date(e.starts_at).toLocaleString("tr-TR", { dateStyle: "short", timeStyle: "short" })
            : "Süregelen";
          return `- [${e.event_id}] ${e.title} | ${e.category} | ${e.venue_name ?? "-"} | ${e.distance_m}m | ${time} | ${price}`;
        })
        .join("\n")
    : "Yakın etkinlik bulunamadı.";

  const dismissedBlock = req.recent_dismissed_titles.length > 0
    ? req.recent_dismissed_titles.join(", ")
    : "Yok";

  const placesBlock = places.length > 0
    ? places
        .map((p) => {
          const primaryType = p.types[0] ?? "place";
          const rating = p.rating != null ? ` | ★${p.rating.toFixed(1)}` : "";
          const price = p.price_level ? ` | ${p.price_level}` : "";
          return `- [${p.id}] ${p.name} | ${primaryType} | ${Math.round(p.distance_m)}m${rating}${price}`;
        })
        .join("\n")
    : "Yakın mekan bulunamadı.";

  return `KULLANICI DURUMU:
- Saat: ${timeStr} ${dayName}
- Konum: ${req.city}
- Hava: ${req.weather_temp_c}°C, ${req.weather_condition}
- Hareket: ${req.motion_state}
- Persona: ${persona ? `${persona.segment_label} — ${topTraits}` : "Yeni kullanıcı"}
- Tercihler: ${topPrefs}
- İlgi alanları: ${req.user_interests.join(", ") || "Belirtilmemiş"}
- Son beğenilen kategoriler: ${req.recent_liked_categories.join(", ") || "Yok"}
- Son kapatılan öneriler: ${dismissedBlock}

YAKIN ETKİNLİKLER (${events.length}):
${eventsBlock}

YAKIN MEKANLAR (${places.length}):
${placesBlock}

3 öneri üret.`;
}
