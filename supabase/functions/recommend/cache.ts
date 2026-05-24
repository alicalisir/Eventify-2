import type { RecommendRequest, Suggestion } from "./types.ts";

export function buildCacheKey(userId: string, req: RecommendRequest, personaVersion: string): string {
  const bucket = {
    user_id: userId,
    persona_version: personaVersion,
    lat_3dec: Math.round(req.lat * 1000) / 1000,
    lng_3dec: Math.round(req.lng * 1000) / 1000,
    hour_block: Math.floor(req.hour / 2),
    weather_condition: req.weather_condition,
    day_of_week: req.day_of_week,
  };

  const str = JSON.stringify(bucket);
  return sha256Hex(str);
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Sync version using a simple hash for cache key (crypto.subtle is async)
// We call this synchronously but the real SHA is computed async below
export function buildCacheKeySync(userId: string, req: RecommendRequest, personaVersion: string): string {
  const bucket = JSON.stringify({
    u: userId,
    pv: personaVersion,
    la: Math.round(req.lat * 1000),
    ln: Math.round(req.lng * 1000),
    hb: Math.floor(req.hour / 2),
    wc: req.weather_condition,
    dw: req.day_of_week,
  });
  // Simple djb2 hash — good enough for cache key, not cryptographic
  let h = 5381;
  for (let i = 0; i < bucket.length; i++) {
    h = ((h << 5) + h) ^ bucket.charCodeAt(i);
    h = h >>> 0;
  }
  return `${userId.slice(0, 8)}_${h.toString(16)}`;
}

export interface CachedPayload {
  suggestions: Suggestion[];
  llm_provider: string;
}
