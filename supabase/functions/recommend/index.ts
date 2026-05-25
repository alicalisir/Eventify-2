import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { RecommendRequest, NearbyEvent, PersonaJson, RecommendResponse, Suggestion } from "./types.ts";
import { SYSTEM_PROMPT, buildUserMessage } from "./prompt.ts";
import { callSelfHost, callSelfHostStream, isSelfHostHealthy } from "./llm_self_host.ts";
import { callClaude, callClaudeStream } from "./llm_claude.ts";
import { applyHardConstraints, StreamingJsonParser } from "./parser.ts";
import { buildCacheKeySync } from "./cache.ts";

const SELF_HOST_URL = Deno.env.get("MISTRAL_URL") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ALLOW_CLOUD_FALLBACK = Deno.env.get("ALLOW_CLOUD_FALLBACK") === "true";
const CACHE_TTL_MINUTES = 30;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, accept",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Maps onboarding interest labels → event DB categories used in nearby_events RPC. */
function normalizeInterest(label: string): string {
  const map: Record<string, string> = {
    "music & concerts": "music",
    "sports & activity": "sports",
    "arts & culture": "culture",
    "food & drink": "food",
    "nature & outdoors": "outdoor",
    "education & workshops": "workshop",
    "family & kids": "family",
    "entertainment & nightlife": "music",
    "calm & solo": "culture",
  };
  return map[label.toLowerCase()] ?? label.toLowerCase();
}

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

// ─── Request setup ────────────────────────────────────────────────────────────

interface Setup {
  supabase: ReturnType<typeof createClient>;
  userId: string;
  body: RecommendRequest;
  enrichedBody: RecommendRequest;
  persona: PersonaJson | null;
  cacheKey: string;
  userMessage: string;
  dismissedTitles: string[];
  selfHostAvailable: boolean;
  llmProvider: string;
  start: number;
}

async function handleRequest(req: Request): Promise<Response> {
  const acceptsSse = req.headers.get("Accept")?.includes("text/event-stream") ?? false;

  // ── Auth ──────────────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse("Missing Authorization header", 401);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return errorResponse("Unauthorized", 401);
  const userId = user.id;

  // ── Parse body ────────────────────────────────────────────────────────────
  let body: RecommendRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  if (!body.lat || !body.lng || !body.city) {
    return errorResponse("lat, lng, city are required", 400);
  }

  // ── Persona ───────────────────────────────────────────────────────────────
  const { data: userData } = await supabase
    .from("users")
    .select("persona_json, persona_updated_at, interests")
    .eq("id", userId)
    .single();

  const persona: PersonaJson | null = userData?.persona_json ?? null;
  const personaVersion = persona?.model_version ?? "no-persona";
  const rawInterests: string[] = userData?.interests ?? body.user_interests ?? [];
  const userInterests = rawInterests.map(normalizeInterest);

  // ── Cache check ───────────────────────────────────────────────────────────
  const cacheKey = buildCacheKeySync(userId, body, personaVersion);
  const { data: cached } = await supabase
    .from("cached_suggestions")
    .select("payload, llm_provider")
    .eq("cache_key", cacheKey)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (cached) {
    console.log(`[recommend] cache HIT key=${cacheKey}`);
    const cacheData = {
      suggestions: cached.payload.suggestions as Suggestion[],
      llm_provider: cached.llm_provider as string,
    };
    if (acceptsSse) return sseFromCache(cacheData);
    return jsonResponse({
      suggestions: cacheData.suggestions,
      llm_provider: cacheData.llm_provider,
      cache_hit: true,
      latency_ms: 0,
    } as RecommendResponse);
  }

  // ── Nearby events ─────────────────────────────────────────────────────────
  const { data: events } = await supabase.rpc("nearby_events", {
    p_city: body.city,
    p_interests: userInterests,
    p_limit: 15,
  }) as { data: NearbyEvent[] | null };
  const nearbyEvents: NearbyEvent[] = events ?? [];

  // ── Dismissed / liked (parallel) ──────────────────────────────────────────
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();

  const [{ data: dismissedRows }, { data: likedRows }] = await Promise.all([
    supabase
      .from("user_feedback")
      .select("suggestion_snapshot")
      .eq("user_id", userId)
      .eq("action", "dismiss")
      .gt("created_at", sevenDaysAgo),
    supabase
      .from("user_feedback")
      .select("suggestion_snapshot")
      .eq("user_id", userId)
      .eq("action", "like")
      .gt("created_at", thirtyDaysAgo),
  ]);

  const dismissedTitles: string[] = (dismissedRows ?? [])
    .map((r: { suggestion_snapshot: Record<string, unknown> }) =>
      String(r.suggestion_snapshot?.title ?? "")
    )
    .filter(Boolean);

  const likedCategories: string[] = [
    ...new Set(
      (likedRows ?? [])
        .map((r: { suggestion_snapshot: Record<string, unknown> }) =>
          String(r.suggestion_snapshot?.category ?? "")
        )
        .filter(Boolean),
    ),
  ];

  const enrichedBody: RecommendRequest = {
    ...body,
    user_interests: userInterests,
    recent_dismissed_titles: dismissedTitles,
    recent_liked_categories: likedCategories,
  };

  // ── Build prompt ──────────────────────────────────────────────────────────
  const nearbyPlaces = body.nearby_places ?? [];
  const userMessage = buildUserMessage(enrichedBody, persona, nearbyEvents, nearbyPlaces);

  // ── Provider selection ────────────────────────────────────────────────────
  const selfHostAvailable = SELF_HOST_URL
    ? await isSelfHostHealthy(SELF_HOST_URL)
    : false;

  let llmProvider: string;
  if (selfHostAvailable) {
    llmProvider = "mistral-nemo-12b";
  } else if (ALLOW_CLOUD_FALLBACK && ANTHROPIC_API_KEY) {
    llmProvider = "claude-sonnet-4-6";
  } else {
    return errorResponse("LLM unavailable", 503);
  }

  const setup: Setup = {
    supabase,
    userId,
    body,
    enrichedBody,
    persona,
    cacheKey,
    userMessage,
    dismissedTitles,
    selfHostAvailable,
    llmProvider,
    start: Date.now(),
  };

  // ── Branch ────────────────────────────────────────────────────────────────
  return acceptsSse ? buildSseStream(setup) : buildJsonResponse(setup);
}

// ─── JSON path (original behaviour) ──────────────────────────────────────────

async function buildJsonResponse(s: Setup): Promise<Response> {
  let result: Awaited<ReturnType<typeof callSelfHost>>;

  if (s.selfHostAvailable) {
    try {
      console.log("[recommend] calling self-host LLM (JSON)");
      result = await callSelfHost(SELF_HOST_URL, SYSTEM_PROMPT, s.userMessage);
    } catch (e) {
      console.error("[recommend] self-host failed:", e);
      if (!ALLOW_CLOUD_FALLBACK || !ANTHROPIC_API_KEY) {
        return errorResponse("LLM unavailable", 503);
      }
      console.log("[recommend] falling back to Claude (JSON)");
      result = await callClaude(ANTHROPIC_API_KEY, SYSTEM_PROMPT, s.userMessage);
      s.llmProvider = "claude-sonnet-4-6";
    }
  } else {
    console.log("[recommend] self-host offline, using Claude (JSON)");
    result = await callClaude(ANTHROPIC_API_KEY, SYSTEM_PROMPT, s.userMessage);
  }

  const filtered = applyHardConstraints(
    result.suggestions,
    s.body.weather_condition,
    s.body.hour,
    s.dismissedTitles,
  );
  const suggestions = filtered.slice(0, 3);

  await writeCacheAndFeedback(s, suggestions, result.tokens, result.latency_ms);

  console.log(
    `[recommend] JSON done provider=${s.llmProvider} suggestions=${suggestions.length} latency=${result.latency_ms}ms`,
  );

  return jsonResponse({
    suggestions,
    llm_provider: s.llmProvider,
    cache_hit: false,
    latency_ms: result.latency_ms,
  } as RecommendResponse);
}

// ─── SSE path ─────────────────────────────────────────────────────────────────

function sseFromCache(cached: { suggestions: Suggestion[]; llm_provider: string }): Response {
  const enc = new TextEncoder();
  const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();
  const writer = writable.getWriter();

  (async () => {
    try {
      for (let i = 0; i < cached.suggestions.length; i++) {
        await writer.write(enc.encode(sseEvent("suggestion", {
          suggestion: cached.suggestions[i],
          index: i,
          llm_provider: cached.llm_provider,
          cache_hit: true,
        })));
      }
      await writer.write(enc.encode(sseEvent("done", {
        latency_ms: 0,
        cache_hit: true,
        total: cached.suggestions.length,
      })));
    } finally {
      writer.close();
    }
  })();

  return new Response(readable, { headers: sseHeaders() });
}

function buildSseStream(s: Setup): Response {
  const enc = new TextEncoder();
  const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();
  const writer = writable.getWriter();

  (async () => {
    try {
      const parser = new StreamingJsonParser();
      let sentCount = 0;
      const llmStart = Date.now();

      const tokenStream: AsyncGenerator<string> = s.selfHostAvailable
        ? callSelfHostStream(SELF_HOST_URL, SYSTEM_PROMPT, s.userMessage)
        : callClaudeStream(ANTHROPIC_API_KEY, SYSTEM_PROMPT, s.userMessage);

      console.log(`[recommend] SSE streaming provider=${s.llmProvider}`);

      for await (const token of tokenStream) {
        const newSuggestions = parser.feed(token);

        for (const suggestion of newSuggestions) {
          // Apply per-suggestion weather + dismissed constraints immediately
          const rainy = ["rain", "snow", "drizzle", "thunderstorm"].some((w) =>
            s.body.weather_condition.toLowerCase().includes(w)
          );
          if (rainy && suggestion.category === "outdoor") continue;
          if (s.dismissedTitles.some(
            (d) => d.toLowerCase() === suggestion.title.toLowerCase(),
          )) continue;

          await writer.write(enc.encode(sseEvent("suggestion", {
            suggestion,
            index: sentCount++,
            llm_provider: s.llmProvider,
            cache_hit: false,
          })));
        }
      }

      const latency_ms = Date.now() - llmStart;
      const allSuggestions = parser.suggestions;

      // Estimate tokens from accumulated buffer length (stream mode doesn't return usage)
      const approxTokens = Math.round(allSuggestions.reduce(
        (acc, sg) => acc + sg.title.length + sg.rationale.length,
        0,
      ) / 4);

      await writeCacheAndFeedback(
        s,
        allSuggestions.slice(0, 3),
        { prompt: 0, completion: approxTokens },
        latency_ms,
      );

      await writer.write(enc.encode(sseEvent("done", {
        latency_ms,
        llm_provider: s.llmProvider,
        total: sentCount,
      })));

      console.log(
        `[recommend] SSE done provider=${s.llmProvider} sent=${sentCount} latency=${latency_ms}ms`,
      );
    } catch (e) {
      console.error("[recommend] SSE error:", e);
      try {
        await writer.write(enc.encode(sseEvent("error", { error: String(e) })));
      } catch { /* writer may already be closed */ }
    } finally {
      writer.close();
    }
  })();

  return new Response(readable, { headers: sseHeaders() });
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

async function writeCacheAndFeedback(
  s: Setup,
  suggestions: Suggestion[],
  tokens: { prompt: number; completion: number },
  latency_ms: number,
) {
  const expiresAt = new Date(
    Date.now() + CACHE_TTL_MINUTES * 60 * 1000,
  ).toISOString();

  await s.supabase.from("cached_suggestions").upsert({
    cache_key: s.cacheKey,
    user_id: s.userId,
    payload: { suggestions },
    llm_provider: s.llmProvider,
    prompt_tokens: tokens.prompt,
    completion_tokens: tokens.completion,
    latency_ms,
    expires_at: expiresAt,
  });

  if (suggestions.length > 0) {
    const feedbackRows = suggestions.map((sg) => ({
      user_id: s.userId,
      suggestion_id: sg.id,
      event_id: sg.event_id ?? null,
      action: "view",
      suggestion_snapshot: sg,
      context_snapshot: {
        lat: Math.round(s.body.lat * 1000) / 1000,
        lng: Math.round(s.body.lng * 1000) / 1000,
        city: s.body.city,
        weather: s.body.weather_condition,
        temp_c: s.body.weather_temp_c,
        hour: s.body.hour,
        dow: s.body.day_of_week,
        motion: s.body.motion_state,
      },
      llm_provider: s.llmProvider,
    }));
    await s.supabase.from("user_feedback").insert(feedbackRows);
  }
}

function sseEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

function sseHeaders(): Record<string, string> {
  return {
    ...CORS_HEADERS,
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  };
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}
