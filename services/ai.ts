import * as SecureStore from "expo-secure-store";

async function getKey(name: "GEMINI_API_KEY" | "CLAUDE_API_KEY"): Promise<string> {
  const key = await SecureStore.getItemAsync(name);
  if (!key) throw new Error(`${name} missing. Set it in Settings first.`);
  return key;
}

export async function testGeminiConnection(): Promise<{ modelCount: number }> {
  const apiKey = await getKey("GEMINI_API_KEY");
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`
  );
  if (!res.ok) {
    throw new Error(`Gemini auth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return { modelCount: (data.models || []).length };
}

export async function testClaudeConnection(): Promise<{ reply: string }> {
  const apiKey = await getKey("CLAUDE_API_KEY");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 10,
      messages: [{ role: "user", content: "ok" }],
    }),
  });
  if (!res.ok) {
    throw new Error(`Claude auth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return { reply: data.content?.[0]?.text ?? "" };
}
