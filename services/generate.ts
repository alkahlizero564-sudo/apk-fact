import * as SecureStore from "expo-secure-store";

export type GeneratedFile = { path: string; content: string };
export type GenerationResult = {
  files: GeneratedFile[];
  sql: string | null;
  summary: string;
};

const SYSTEM_PROMPT = `You are a code generator. Given a description of an app or website, respond with ONLY valid JSON (no markdown fences, no prose) in this exact shape:
{
  "summary": "one-line description of what you built",
  "files": [{"path": "relative/path.ext", "content": "full file content"}],
  "sql": "CREATE TABLE ... (or null if no database needed)"
}
IMPORTANT: Regardless of whether this is described as a "website" or a "mobile app", always build it as a SINGLE self-contained index.html file using plain HTML/CSS/JavaScript only (no build step, no external framework files, no React Native). This file must be fully functional and renderable directly inside a mobile WebView — real working buttons, navigation, forms, local state, etc. For a "mobile app" request specifically, style it to look and behave like a native mobile app: full-screen layout, bottom tab bar or similar mobile navigation, large touch targets, smooth transitions via CSS — but it is still implemented as HTML/CSS/JS so it can actually run live, not just be displayed as source code. If Supabase is needed, call it directly from JavaScript using fetch() against the Supabase REST API (the anon key and project URL will be provided by the person separately — leave clearly marked placeholders like SUPABASE_URL and SUPABASE_ANON_KEY as JS constants at the top of the file for them to fill in).`;

function extractJson(text: string): string {
  const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  return fenceMatch ? fenceMatch[1].trim() : text.trim();
}

async function generateWithClaude(prompt: string): Promise<GenerationResult> {
  const apiKey = await SecureStore.getItemAsync("CLAUDE_API_KEY");
  if (!apiKey) throw new Error("CLAUDE_API_KEY missing. Set it in Settings first.");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 8000,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!res.ok) throw new Error(`Claude generation failed (${res.status}): ${await res.text()}`);
  const data = await res.json();
  const text = data.content?.[0]?.text ?? "";
  return JSON.parse(extractJson(text));
}

async function generateWithGemini(prompt: string): Promise<GenerationResult> {
  const apiKey = await SecureStore.getItemAsync("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY missing. Set it in Settings first.");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ parts: [{ text: prompt }] }],
      }),
    }
  );

  if (!res.ok) throw new Error(`Gemini generation failed (${res.status}): ${await res.text()}`);
  const data = await res.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return JSON.parse(extractJson(text));
}

const EDIT_SYSTEM_PROMPT = `You are a code editor. You will be given the current files of an app or website, plus an instruction describing a change to make. Respond with ONLY valid JSON (no markdown fences, no prose) in this exact shape:
{
  "summary": "one-line description of what you changed",
  "files": [{"path": "relative/path.ext", "content": "full NEW file content"}],
  "sql": "any additional SQL to run (or null)"
}
Return the FULL content of every file that changed (not a diff). Files that didn't need to change can be omitted. Keep the project as plain HTML/CSS/JavaScript only (no React Native, no build step) so it keeps running live inside a mobile WebView exactly as before — just apply the requested change.`;

export async function editCode(
  currentFiles: GeneratedFile[],
  instruction: string,
  provider: "claude" | "gemini"
): Promise<GenerationResult> {
  const filesBlock = currentFiles
    .map((f) => `--- ${f.path} ---\n${f.content}`)
    .join("\n\n");
  const prompt = `Current files:\n\n${filesBlock}\n\nInstruction: ${instruction}`;

  if (provider === "claude") {
    const apiKey = await SecureStore.getItemAsync("CLAUDE_API_KEY");
    if (!apiKey) throw new Error("CLAUDE_API_KEY missing. Set it in Settings first.");
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 8000,
        system: EDIT_SYSTEM_PROMPT,
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (!res.ok) throw new Error(`Claude edit failed (${res.status}): ${await res.text()}`);
    const data = await res.json();
    const text = data.content?.[0]?.text ?? "";
    const parsed = JSON.parse(extractJson(text));
    return mergeEdit(currentFiles, parsed);
  } else {
    const apiKey = await SecureStore.getItemAsync("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY missing. Set it in Settings first.");
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: EDIT_SYSTEM_PROMPT }] },
          contents: [{ parts: [{ text: prompt }] }],
        }),
      }
    );
    if (!res.ok) throw new Error(`Gemini edit failed (${res.status}): ${await res.text()}`);
    const data = await res.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const parsed = JSON.parse(extractJson(text));
    return mergeEdit(currentFiles, parsed);
  }
}

function mergeEdit(currentFiles: GeneratedFile[], parsed: GenerationResult): GenerationResult {
  const merged = [...currentFiles];
  for (const updated of parsed.files) {
    const idx = merged.findIndex((f) => f.path === updated.path);
    if (idx >= 0) merged[idx] = updated;
    else merged.push(updated);
  }
  return { files: merged, sql: parsed.sql ?? null, summary: parsed.summary };
}

export async function generateCode(
  description: string,
  kind: "app" | "website",
  provider: "claude" | "gemini"
): Promise<GenerationResult> {
  const prompt = `Build this ${kind === "app" ? "mobile app" : "website"}: ${description}`;
  const result = provider === "claude" ? await generateWithClaude(prompt) : await generateWithGemini(prompt);

  if (!result.files || !Array.isArray(result.files)) {
    throw new Error("النموذج رجّع رد مش بالصيغة المتوقعة. جرب تاني أو بصياغة مختلفة.");
  }
  return result;
}
