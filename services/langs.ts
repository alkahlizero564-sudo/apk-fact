import { getFileText } from "./github";

export type Lang = "html" | "flutter" | "python" | "kotlin";

type LangInfo = {
  label: string;
  tools: string;
  // Files and workflows in the repo for this language.
  mainFile: (app: string) => string;
  requestFile: string;
  generateWorkflow: string;
  buildWorkflow: string;
  hasAiPreview: boolean;
  pasteLabel: string;
};

export const LANGS: Record<Lang, LangInfo> = {
  html: {
    label: "HTML",
    tools: "HTML · CSS · JavaScript · معاينة حيّة",
    mainFile: (app) => `apps/${app}/index.html`,
    requestFile: "request.txt",
    generateWorkflow: "generate.yml",
    buildWorkflow: "build-app.yml",
    hasAiPreview: false,
    pasteLabel: "الكود (HTML كامل)",
  },
  flutter: {
    label: "Flutter",
    tools: "Material 3 · provider · http · fl_chart · go_router · sqflite",
    mainFile: (app) => `apps/${app}/lib/main.dart`,
    requestFile: "request-flutter.txt",
    generateWorkflow: "generate-flutter.yml",
    buildWorkflow: "build-flutter.yml",
    hasAiPreview: true,
    pasteLabel: "الكود (main.dart كامل)",
  },
  python: {
    label: "Python",
    tools: "Flet 1.0 · Material 3 · requests · sqlite3",
    mainFile: (app) => `apps/${app}/main.py`,
    requestFile: "request-python.txt",
    generateWorkflow: "generate-python.yml",
    buildWorkflow: "build-python.yml",
    hasAiPreview: true,
    pasteLabel: "الكود (main.py كامل بـ Flet)",
  },
  kotlin: {
    label: "Kotlin",
    tools: "Jetpack Compose · Material 3 · Navigation · Coroutines · OkHttp · Coil",
    mainFile: (app) => `apps/${app}/MainActivity.kt`,
    requestFile: "request-kotlin.txt",
    generateWorkflow: "generate-kotlin.yml",
    buildWorkflow: "build-kotlin.yml",
    hasAiPreview: true,
    pasteLabel: "الكود (MainActivity.kt كامل بـ Jetpack Compose)",
  },
};

export const LANG_ORDER: Lang[] = ["html", "flutter", "kotlin", "python"];

/** Languages a connected pair (customer + admin) can be built in. */
export const PAIR_LANGS: Lang[] = ["html", "flutter", "python"];

/** Which language an app in apps/<name> is written in. */
export async function detectLang(repo: string, app: string): Promise<Lang> {
  for (const lang of ["flutter", "kotlin", "python"] as const) {
    try {
      if (await getFileText(repo, LANGS[lang].mainFile(app))) return lang;
    } catch {
      // treat unreadable as missing
    }
  }
  return "html";
}
