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
import * as SecureStore from "expo-secure-store";

export type GeminiModel = { id: string; displayName: string };

export async function listGeminiModels(): Promise<GeminiModel[]> {
  let apiKey = "";
  for (const k of ["GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3"]) {
    const v = await SecureStore.getItemAsync(k);
    if (v) {
      apiKey = v;
      break;
    }
  }
  if (!apiKey) throw new Error("أضف مفتاح Gemini واحفظه الأول.");

  const out: GeminiModel[] = [];
  let pageToken = "";
  do {
    const url =
      "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000" +
      (pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : "");
    const res = await fetch(url, { headers: { "x-goog-api-key": apiKey } });
    if (!res.ok) throw new Error(`فشل جلب النماذج (${res.status})`);
    const data = await res.json();
    for (const m of data.models ?? []) {
      if ((m.supportedGenerationMethods ?? []).includes("generateContent")) {
        out.push({
          id: String(m.name).replace(/^models\//, ""),
          displayName: m.displayName ?? String(m.name),
        });
      }
    }
    pageToken = data.nextPageToken ?? "";
  } while (pageToken);

  return out.sort((a, b) => a.id.localeCompare(b.id));
} 
