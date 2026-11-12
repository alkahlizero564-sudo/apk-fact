// Speed: the interactive Gemini calls (preview, design, understand, chat) are generation tasks that do NOT need
// the model's slow "thinking" phase, so we ask the model to skip it. If a particular model rejects the option
// (400), we remember that and never send it again for that model — so nothing ever breaks, and supported models
// stay fast. The result is remembered in memory for the session and persisted so later sessions start fast too.
import AsyncStorage from "@react-native-async-storage/async-storage";

const unsupported: Record<string, boolean> = {};
const KEY = (model: string) => `gemini-think-unsupported:${model}`;

/** The generationConfig fragment that turns thinking off, or null when this model is known not to support it. */
export async function thinkingConfigFor(model: string): Promise<Record<string, unknown> | null> {
  if (unsupported[model]) return null;
  if (!(model in unsupported)) {
    try {
      if ((await AsyncStorage.getItem(KEY(model))) === "1") {
        unsupported[model] = true;
        return null;
      }
    } catch {
      // storage unavailable: just try the fast path
    }
    unsupported[model] = false;
  }
  return { thinkingConfig: { thinkingBudget: 0 } };
}

/** Called when a request that disabled thinking came back 400: this model doesn't support it, so stop sending it. */
export async function markThinkingUnsupported(model: string): Promise<void> {
  unsupported[model] = true;
  try {
    await AsyncStorage.setItem(KEY(model), "1");
  } catch {
    // best effort
  }
}
