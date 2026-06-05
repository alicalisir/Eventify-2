/** Langfuse LLM observability — fire-and-forget, errors are swallowed. */

const LANGFUSE_HOST = Deno.env.get("LANGFUSE_HOST") ?? "https://cloud.langfuse.com";

export interface LangfuseLog {
  traceId: string;
  userId: string;
  llmProvider: string;
  model: string;
  systemPrompt: string;
  userMessage: string;
  suggestions: unknown[];
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
  cacheHit: boolean;
  city: string;
  weatherCondition: string;
  hour: number;
}

/** Send one trace + one generation to Langfuse. Never throws. */
export async function logLangfuse(log: LangfuseLog): Promise<void> {
  const publicKey = Deno.env.get("LANGFUSE_PUBLIC_KEY");
  const secretKey = Deno.env.get("LANGFUSE_SECRET_KEY");

  if (!publicKey || !secretKey) return; // not configured — skip silently

  const endTime = new Date().toISOString();
  const startTime = new Date(Date.now() - log.latencyMs).toISOString();

  const batch = [
    {
      id: crypto.randomUUID(),
      type: "trace-create",
      timestamp: endTime,
      body: {
        id: log.traceId,
        name: "recommend",
        userId: log.userId,
        tags: [log.llmProvider, log.cacheHit ? "cache-hit" : "llm-call"],
        metadata: {
          city: log.city,
          weather: log.weatherCondition,
          hour: log.hour,
          cache_hit: log.cacheHit,
          provider: log.llmProvider,
          suggestions_count: log.suggestions.length,
        },
      },
    },
    {
      id: crypto.randomUUID(),
      type: "generation-create",
      timestamp: endTime,
      body: {
        id: crypto.randomUUID(),
        traceId: log.traceId,
        name: "llm-generation",
        model: log.model,
        startTime,
        endTime,
        // Truncate large payloads for readability in the Langfuse UI
        input: {
          system: log.systemPrompt.slice(0, 600),
          user: log.userMessage.slice(0, 1200),
        },
        output: log.suggestions,
        usage: {
          input: log.promptTokens,
          output: log.completionTokens,
          unit: "TOKENS",
        },
        metadata: {
          latency_ms: log.latencyMs,
          cache_hit: log.cacheHit,
        },
      },
    },
  ];

  try {
    const credentials = btoa(`${publicKey}:${secretKey}`);
    const resp = await fetch(`${LANGFUSE_HOST}/api/public/ingestion`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${credentials}`,
      },
      body: JSON.stringify({ batch }),
      signal: AbortSignal.timeout(5_000),
    });

    if (!resp.ok) {
      console.warn(`[langfuse] ingestion failed: ${resp.status}`);
    } else {
      console.log(`[langfuse] trace logged traceId=${log.traceId} provider=${log.llmProvider} latency=${log.latencyMs}ms`);
    }
  } catch (e) {
    console.warn("[langfuse] error:", e);
  }
}
