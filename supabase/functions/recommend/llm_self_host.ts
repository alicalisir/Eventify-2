import type { Suggestion } from "./types.ts";
import { extractSuggestions } from "./parser.ts";

const MODEL = Deno.env.get("SELF_HOST_MODEL") ?? "mistral-nemo:12b-instruct-q4_k_m";
const TIMEOUT_MS = 30_000;

const COMMON_HEADERS = {
  "Content-Type": "application/json",
  "ngrok-skip-browser-warning": "true",
};

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
      headers: COMMON_HEADERS,
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

/** Streaming variant — yields individual text tokens from the LLM as they arrive. */
export async function* callSelfHostStream(
  baseUrl: string,
  systemPrompt: string,
  userMessage: string,
): AsyncGenerator<string> {
  const resp = await fetch(`${baseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: COMMON_HEADERS,
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userMessage },
      ],
      temperature: 0.7,
      max_tokens: 1024,
      stream: true,
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });

  if (!resp.ok) {
    throw new Error(`Self-host LLM stream error: ${resp.status} ${await resp.text()}`);
  }

  const reader = resp.body!.getReader();
  const decoder = new TextDecoder();
  let leftover = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    leftover += decoder.decode(value, { stream: true });
    const lines = leftover.split("\n");
    leftover = lines.pop() ?? "";

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data: ")) continue;
      const data = trimmed.slice(6);
      if (data === "[DONE]") return;

      try {
        const json = JSON.parse(data);
        const content = json.choices?.[0]?.delta?.content;
        if (content) yield content as string;
      } catch {
        // skip malformed lines
      }
    }
  }
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
