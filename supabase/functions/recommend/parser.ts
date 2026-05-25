import type { Suggestion } from "./types.ts";

export function extractSuggestions(raw: string): Suggestion[] {
  const jsonStr = extractJsonBlock(raw);
  if (!jsonStr) {
    throw new Error(`No <json> block found in LLM output. Raw: ${raw.slice(0, 200)}`);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (e) {
    throw new Error(`JSON parse failed: ${e}. Block: ${jsonStr.slice(0, 300)}`);
  }

  if (
    typeof parsed !== "object" ||
    parsed === null ||
    !Array.isArray((parsed as Record<string, unknown>).suggestions)
  ) {
    throw new Error("LLM output missing 'suggestions' array");
  }

  const raw_suggestions = (parsed as { suggestions: unknown[] }).suggestions;
  return raw_suggestions.map((s, i) => validateSuggestion(s, i));
}

function extractJsonBlock(text: string): string | null {
  // Primary: <json>...</json>
  const tagMatch = text.match(/<json>([\s\S]*?)<\/json>/);
  if (tagMatch) return tagMatch[1].trim();

  // Fallback: first {...} block
  const braceMatch = text.match(/\{[\s\S]*\}/);
  if (braceMatch) return braceMatch[0];

  return null;
}

function validateSuggestion(s: unknown, index: number): Suggestion {
  if (typeof s !== "object" || s === null) {
    throw new Error(`Suggestion[${index}] is not an object`);
  }
  const obj = s as Record<string, unknown>;

  const title = String(obj.title ?? "").trim();
  const category = String(obj.category ?? "").trim();
  const rationale = String(obj.rationale ?? "").trim();

  if (!title) throw new Error(`Suggestion[${index}] missing title`);
  if (!category) throw new Error(`Suggestion[${index}] missing category`);
  if (!rationale) throw new Error(`Suggestion[${index}] missing rationale`);

  const validCategories = ["music", "sports", "culture", "food", "outdoor", "workshop", "family"];
  const normalizedCategory = validCategories.includes(category) ? category : "culture";

  const rawSignals = Array.isArray(obj.rationale_signals) ? obj.rationale_signals : [];
  const rationale_signals = rawSignals
    .map((sig) => String(sig).slice(0, 18))
    .slice(0, 4);

  return {
    id: String(obj.id ?? `s${index + 1}`),
    title,
    category: normalizedCategory,
    rationale,
    rationale_signals,
    match_score: clamp(Number(obj.match_score ?? 0.7), 0, 1),
    distance_m: obj.distance_m != null ? Number(obj.distance_m) : undefined,
    venue_name: obj.venue_name ? String(obj.venue_name) : undefined,
    event_id: obj.event_id && obj.event_id !== "null" ? String(obj.event_id) : undefined,
    ticket_url: obj.ticket_url ? String(obj.ticket_url) : undefined,
  };
}

export function applyHardConstraints(
  suggestions: Suggestion[],
  weatherCondition: string,
  hour: number,
  dismissedTitles: string[],
): Suggestion[] {
  const isRainyOrSnowy = ["rain", "snow", "drizzle", "thunderstorm"].some((w) =>
    weatherCondition.toLowerCase().includes(w)
  );

  return suggestions.filter((s) => {
    if (isRainyOrSnowy && s.category === "outdoor") return false;
    if (dismissedTitles.some((d) => d.toLowerCase() === s.title.toLowerCase())) return false;
    return true;
  });
}

function clamp(val: number, min: number, max: number): number {
  return Math.min(Math.max(val, min), max);
}
