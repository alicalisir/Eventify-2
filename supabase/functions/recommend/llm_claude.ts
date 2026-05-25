import type { Suggestion } from "./types.ts";
import { extractSuggestions } from "./parser.ts";

const CLAUDE_MODEL = "claude-sonnet-4-6";

export async function callClaude(
  apiKey: string,
  systemPrompt: string,
  userMessage: string,
): Promise<{ suggestions: Suggestion[]; tokens: { prompt: number; completion: number }; latency_ms: number }> {
  const start = Date.now();

  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 1024,
      system: systemPrompt,
      messages: [{ role: "user", content: userMessage }],
    }),
  });

  if (!resp.ok) {
    throw new Error(`Claude API error: ${resp.status} ${await resp.text()}`);
  }

  const data = await resp.json();
  const latency_ms = Date.now() - start;
  const raw = data.content?.[0]?.text ?? "";

  return {
    suggestions: extractSuggestions(raw),
    tokens: {
      prompt: data.usage?.input_tokens ?? 0,
      completion: data.usage?.output_tokens ?? 0,
    },
    latency_ms,
  };
}

/** Streaming variant — yields individual text tokens from Claude as they arrive. */
export async function* callClaudeStream(
  apiKey: string,
  systemPrompt: string,
  userMessage: string,
): AsyncGenerator<string> {
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 1024,
      stream: true,
      system: systemPrompt,
      messages: [{ role: "user", content: userMessage }],
    }),
  });

  if (!resp.ok) {
    throw new Error(`Claude stream error: ${resp.status} ${await resp.text()}`);
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

      try {
        const json = JSON.parse(trimmed.slice(6));
        if (json.type === "content_block_delta" && json.delta?.type === "text_delta") {
          yield json.delta.text as string;
        }
      } catch {
        // skip malformed lines
      }
    }
  }
}
