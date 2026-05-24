import type { Suggestion } from "./types.ts";
import { extractSuggestions } from "./parser.ts";

const MODEL = Deno.env.get("SELF_HOST_MODEL") ?? "mistral-nemo:12b-instruct-q4_k_m";
const TIMEOUT_MS = 30_000;

export async function callSelfHost(
  baseUrl: string,
  systemPrompt: string,
  userMessage: string,
): Promise<{ suggestions: Suggestion[]; tokens: { prompt: number; completion: number }; latency_ms: number }> {
  const start = Date.now();

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  let resp: Response;
  try {
    resp = await fetch(`${baseUrl}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // ngrok free tier requires this header to skip browser warning page
        "ngrok-skip-browser-warning": "true",
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userMessage },
        ],
        temperature: 0.7,
        max_tokens: 1024,
        stream: false,
      }),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }

  if (!resp.ok) {
    throw new Error(`Self-host LLM error: ${resp.status} ${await resp.text()}`);
  }

  const data = await resp.json();
  const latency_ms = Date.now() - start;
  const raw = data.choices?.[0]?.message?.content ?? "";

  return {
    suggestions: extractSuggestions(raw),
    tokens: {
      prompt: data.usage?.prompt_tokens ?? 0,
      completion: data.usage?.completion_tokens ?? 0,
    },
    latency_ms,
  };
}

export async function isSelfHostHealthy(baseUrl: string): Promise<boolean> {
  try {
    const resp = await fetch(`${baseUrl}/api/tags`, {
      headers: { "ngrok-skip-browser-warning": "true" },
      signal: AbortSignal.timeout(3_000),
    });
    return resp.ok;
  } catch {
    return false;
  }
}
