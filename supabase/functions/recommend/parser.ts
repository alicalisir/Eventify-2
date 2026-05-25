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
  const tagMatch = text.match(/<json>([\s\S]*?)<\/json>/);
  if (tagMatch) return tagMatch[1].trim();

  const braceMatch = text.match(/\{[\s\S]*\}/);
  if (braceMatch) return braceMatch[0];

  return null;
}

export function validateSuggestion(s: unknown, index: number): Suggestion {
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

/** Streaming parser: accumulates LLM token output and extracts Suggestion objects
 *  as soon as each JSON object is complete within the `"suggestions":[...]` array. */
export class StreamingJsonParser {
  private _buf = "";
  private _arrayStart = -1;
  private _cursor = 0;
  private _results: Suggestion[] = [];

  get suggestions(): Suggestion[] {
    return this._results;
  }

  /** Feed a new token chunk. Returns newly completed suggestions (0-N per call). */
  feed(token: string): Suggestion[] {
    this._buf += token;

    // Locate the start of the suggestions array on first match
    if (this._arrayStart === -1) {
      const marker = '"suggestions":[';
      const idx = this._buf.indexOf(marker);
      if (idx === -1) return [];
      this._arrayStart = idx + marker.length;
      this._cursor = this._arrayStart;
    }

    const newly: Suggestion[] = [];
    let s: Suggestion | null;
    while ((s = this._extractNext()) !== null) {
      newly.push(s);
    }
    return newly;
  }

  private _extractNext(): Suggestion | null {
    const text = this._buf;
    let pos = this._cursor;

    // Skip whitespace and commas between objects
    while (pos < text.length) {
      const c = text[pos];
      if (c === "," || c === " " || c === "\n" || c === "\r" || c === "\t") {
        pos++;
      } else {
        break;
      }
    }

    if (pos >= text.length) return null;
    if (text[pos] === "]") return null; // end of array

    if (text[pos] !== "{") {
      this._cursor = pos + 1;
      return null;
    }

    // Track brace depth to find the matching closing brace
    let depth = 0;
    let inString = false;
    let escape = false;
    const objStart = pos;

    for (let i = pos; i < text.length; i++) {
      const c = text[i];

      if (escape) { escape = false; continue; }
      if (c === "\\" && inString) { escape = true; continue; }
      if (c === '"') { inString = !inString; continue; }
      if (inString) continue;

      if (c === "{") {
        depth++;
      } else if (c === "}") {
        depth--;
        if (depth === 0) {
          // Complete JSON object found
          const objStr = text.slice(objStart, i + 1);
          this._cursor = i + 1;
          try {
            const parsed = JSON.parse(objStr);
            const suggestion = validateSuggestion(parsed, this._results.length);
            this._results.push(suggestion);
            return suggestion;
          } catch {
            return null;
          }
        }
      }
    }

    // Incomplete object — wait for more tokens
    return null;
  }
}

function clamp(val: number, min: number, max: number): number {
  return Math.min(Math.max(val, min), max);
}
