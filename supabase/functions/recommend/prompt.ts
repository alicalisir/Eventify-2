import type { RecommendRequest, PersonaJson, NearbyEvent, NearbyPlace } from "./types.ts";

export const SYSTEM_PROMPT = `You are a context-aware event recommendation assistant.

Your task: given the user's current context (location, time, weather, motion) and their persona, output exactly 3 personalized event or place suggestions in English.

Output format — respond ONLY with a JSON object inside <json>...</json> tags, nothing else:
<json>
{
  "suggestions": [
    {
      "id": "unique-string",
      "title": "Event or venue name",
      "category": "music|sports|culture|food|outdoor|workshop|family",
      "rationale": "1-2 sentence explanation of why this was recommended",
      "rationale_signals": ["signal1", "signal2", "signal3"],
      "match_score": 0.85,
      "distance_m": 1200,
      "venue_name": "Venue name",
      "event_id": "uuid-if-from-db-else-null"
    }
  ]
}
</json>

Hard rules:
- Exactly 3 suggestions, spanning at least 2 different categories.
- If weather is rain or snow: NO outdoor category suggestions.
- If hour >= 22: only venues/events that are open late.
- rationale_signals: 2-4 short English labels, max 18 characters each (e.g. "Open air", "Nearby", "Open today").
- Avoid any title in the dismissed list.
- rationale must mention a specific context signal (weather, time, persona trait, distance).
- match_score between 0.0 and 1.0.
- Respond ONLY with the <json>...</json> block — no preamble, no explanation.

Few-shot examples:

Example 1 — rainy Wednesday evening, food-lover persona:
<json>
{"suggestions":[{"id":"s1","title":"Kronotrop Coffee Bar","category":"food","rationale":"A perfect indoor stop on a rainy evening. Matches your love for coffee culture.","rationale_signals":["Rainy weather","Indoors","Coffee lover"],"match_score":0.88,"distance_m":650,"venue_name":"Kronotrop","event_id":null},{"id":"s2","title":"Pera Museum — Anatolian Weights Exhibition","category":"culture","rationale":"Open until 20:00. A museum visit is an ideal choice on a rainy evening.","rationale_signals":["Open late","Rainy weather","Culture interest"],"match_score":0.81,"distance_m":1400,"venue_name":"Pera Museum","event_id":null},{"id":"s3","title":"Nardis Jazz Club","category":"music","rationale":"Live jazz tonight. Cozy indoor venue with a relaxed atmosphere.","rationale_signals":["Live music","Indoors","Tonight"],"match_score":0.76,"distance_m":900,"venue_name":"Nardis Jazz Club","event_id":null}]}
</json>

Example 2 — sunny Saturday morning, outdoor-lover persona:
<json>
{"suggestions":[{"id":"s1","title":"Maçka Park Morning Walk","category":"outdoor","rationale":"Sunny morning, perfect for outdoor activity. Aligns with your nature-lover profile.","rationale_signals":["Sunny weather","Morning","Nature lover"],"match_score":0.92,"distance_m":800,"venue_name":"Maçka Park","event_id":null},{"id":"s2","title":"Kadıköy Market Tour","category":"food","rationale":"Weekend morning is the ideal time to browse the local market. Vibrant atmosphere.","rationale_signals":["Weekend","Morning","Local flavors"],"match_score":0.83,"distance_m":300,"venue_name":"Kadıköy Market","event_id":null},{"id":"s3","title":"Istanbul Modern Museum","category":"culture","rationale":"Less crowded in the early morning. Great match for your interest in art.","rationale_signals":["Less crowded","Art interest","Sunny day"],"match_score":0.74,"distance_m":2100,"venue_name":"Istanbul Modern","event_id":null}]}
</json>`;

export function buildUserMessage(
  req: RecommendRequest,
  persona: PersonaJson | null,
  events: NearbyEvent[],
  places: NearbyPlace[],
): string {
  const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
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
            : "Free";
          const time = e.starts_at
            ? new Date(e.starts_at).toLocaleString("en-GB", { dateStyle: "short", timeStyle: "short" })
            : "Ongoing";
          return `- [${e.event_id}] ${e.title} | ${e.category} | ${e.venue_name ?? "-"} | ${e.distance_m}m | ${time} | ${price}`;
        })
        .join("\n")
    : "No nearby events found.";

  const dismissedBlock = req.recent_dismissed_titles.length > 0
    ? req.recent_dismissed_titles.join(", ")
    : "None";

  const placesBlock = places.length > 0
    ? places
        .map((p) => {
          const primaryType = p.types[0] ?? "place";
          const rating = p.rating != null ? ` | ★${p.rating.toFixed(1)}` : "";
          const price = p.price_level ? ` | ${p.price_level}` : "";
          return `- [${p.id}] ${p.name} | ${primaryType} | ${Math.round(p.distance_m)}m${rating}${price}`;
        })
        .join("\n")
    : "No nearby places found.";

  return `USER CONTEXT:
- Time: ${timeStr} ${dayName}
- Location: ${req.city}
- Weather: ${req.weather_temp_c}°C, ${req.weather_condition}
- Motion: ${req.motion_state}
- Persona: ${persona ? `${persona.segment_label} — ${topTraits}` : "New user — no persona"}
- Preferences: ${topPrefs}
- Interests: ${req.user_interests.join(", ") || "Not specified"}
- Recently liked categories: ${req.recent_liked_categories.join(", ") || "None"}
- Recently dismissed: ${dismissedBlock}

NEARBY EVENTS (${events.length}):
${eventsBlock}

NEARBY PLACES (${places.length}):
${placesBlock}

Generate 3 suggestions.`;
}
