import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { RecommendRequest, NearbyEvent, PersonaJson, RecommendResponse } from "./types.ts";
import { SYSTEM_PROMPT, buildUserMessage } from "./prompt.ts";
import { callSelfHost, isSelfHostHealthy } from "./llm_self_host.ts";
import { callClaude } from "./llm_claude.ts";
import { applyHardConstraints } from "./parser.ts";
import { buildCacheKeySync } from "./cache.ts";

const SELF_HOST_URL = Deno.env.get("MISTRAL_URL") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ALLOW_CLOUD_FALLBACK = Deno.env.get("ALLOW_CLOUD_FALLBACK") === "true";
const CACHE_TTL_MINUTES = 30;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    return await handleRequest(req);
  } catch (e) {
    console.error("[recommend] Uncaught error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});

async function handleRequest(req: Request): Promise<Response> {

  // --- Auth ---
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return errorResponse("Missing Authorization header", 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return errorResponse("Unauthorized", 401);
  }
  const userId = user.id;

  // --- Parse body ---
  let body: RecommendRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.lat || !body.lng || !body.city) {
    return errorResponse("lat, lng, city are required", 400);
  }

  // --- Load persona ---
  const { data: userData } = await supabase
    .from("users")
    .select("persona_json, persona_updated_at, interests")
    .eq("id", userId)
    .single();

  const persona: PersonaJson | null = userData?.persona_json ?? null;
  const personaVersion = persona?.model_version ?? "no-persona";
  const userInterests: string[] = userData?.interests ?? body.user_interests ?? [];

  // --- Cache check ---
  const cacheKey = buildCacheKeySync(userId, body, personaVersion);
  const { data: cached } = await supabase
    .from("cached_suggestions")
    .select("payload, llm_provider")
    .eq("cache_key", cacheKey)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (cached) {
    console.log(`[recommend] cache HIT key=${cacheKey}`);
    const response: RecommendResponse = {
      suggestions: cached.payload.suggestions,
      llm_provider: cached.llm_provider,
      cache_hit: true,
      latency_ms: 0,
    };
    return jsonResponse(response);
  }

  // --- Load nearby events ---
  const { data: events } = await supabase.rpc("nearby_events", {
    p_city: body.city,
    p_interests: userInterests,
    p_limit: 15,
  }) as { data: NearbyEvent[] | null };

  const nearbyEvents: NearbyEvent[] = events ?? [];

  // --- Recent dismissed titles ---
  const { data: dismissedRows } = await supabase
    .from("user_feedback")
    .select("suggestion_snapshot")
    .eq("user_id", userId)
    .eq("action", "dismiss")
    .gt("created_at", new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString());

  const dismissedTitles: string[] = (dismissedRows ?? [])
    .map((r: { suggestion_snapshot: Record<string, unknown> }) => String(r.suggestion_snapshot?.title ?? ""))
    .filter(Boolean);

  const enrichedBody: RecommendRequest = {
    ...body,
    user_interests: userInterests,
    recent_dismissed_titles: dismissedTitles,
  };

  // --- Build prompt ---
  const userMessage = buildUserMessage(enrichedBody, persona, nearbyEvents);

  // --- LLM call ---
  let llmProvider = "unknown";
  let result: Awaited<ReturnType<typeof callSelfHost>>;

  const selfHostAvailable = SELF_HOST_URL
    ? await isSelfHostHealthy(SELF_HOST_URL)
    : false;

  if (selfHostAvailable) {
    try {
      console.log("[recommend] calling self-host LLM");
      result = await callSelfHost(SELF_HOST_URL, SYSTEM_PROMPT, userMessage);
      llmProvider = "mistral-nemo-12b";
    } catch (e) {
      console.error("[recommend] self-host failed:", e);
      if (!ALLOW_CLOUD_FALLBACK || !ANTHROPIC_API_KEY) {
        return errorResponse("LLM unavailable", 503);
      }
      console.log("[recommend] falling back to Claude");
      result = await callClaude(ANTHROPIC_API_KEY, SYSTEM_PROMPT, userMessage);
      llmProvider = "claude-sonnet-4-6";
    }
  } else if (ALLOW_CLOUD_FALLBACK && ANTHROPIC_API_KEY) {
    console.log("[recommend] self-host offline, using Claude fallback");
    result = await callClaude(ANTHROPIC_API_KEY, SYSTEM_PROMPT, userMessage);
    llmProvider = "claude-sonnet-4-6";
  } else {
    return errorResponse("Self-host LLM offline and cloud fallback disabled", 503);
  }

  // --- Hard constraints ---
  const filtered = applyHardConstraints(
    result.suggestions,
    body.weather_condition,
    body.hour,
    dismissedTitles,
  );

  const suggestions = filtered.slice(0, 3);

  // --- Write cache ---
  const expiresAt = new Date(Date.now() + CACHE_TTL_MINUTES * 60 * 1000).toISOString();
  await supabase.from("cached_suggestions").upsert({
    cache_key: cacheKey,
    user_id: userId,
    payload: { suggestions },
    llm_provider: llmProvider,
    prompt_tokens: result.tokens.prompt,
    completion_tokens: result.tokens.completion,
    latency_ms: result.latency_ms,
    expires_at: expiresAt,
  });

  // --- Write feedback log (view event) ---
  if (suggestions.length > 0) {
    const feedbackRows = suggestions.map((s) => ({
      user_id: userId,
      suggestion_id: s.id,
      event_id: s.event_id ?? null,
      action: "view",
      suggestion_snapshot: s,
      context_snapshot: {
        lat: Math.round(body.lat * 1000) / 1000,
        lng: Math.round(body.lng * 1000) / 1000,
        city: body.city,
        weather: body.weather_condition,
        temp_c: body.weather_temp_c,
        hour: body.hour,
        dow: body.day_of_week,
        motion: body.motion_state,
      },
      llm_provider: llmProvider,
    }));
    await supabase.from("user_feedback").insert(feedbackRows);
  }

  console.log(
    `[recommend] done provider=${llmProvider} suggestions=${suggestions.length} latency=${result.latency_ms}ms`,
  );

  const response: RecommendResponse = {
    suggestions,
    llm_provider: llmProvider,
    cache_hit: false,
    latency_ms: result.latency_ms,
  };
  return jsonResponse(response);
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}
