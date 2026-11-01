// Everything the app does with GitHub, independent of any screen.
// Long operations report their progress step by step so screens can show a timeline.
import * as SecureStore from "expo-secure-store";
import * as FileSystem from "expo-file-system";
import * as IntentLauncher from "expo-intent-launcher";
import {
  pushFile,
  pushBase64File,
  listWorkflowRuns,
  latestRunId,
  getFileText,
  getFailureLog,
  listDir,
  deleteFolder,
  triggerWorkflow,
  findAppApkAsset,
  getAssetDownloadInfo,
} from "./github";
import { REPO } from "./config";
import { LANGS, LANG_ORDER, Lang, detectLang } from "./langs";
import PERM_RULES from "./permissions.json";

export type StepState = "pending" | "active" | "done" | "error";
export type Report = (step: string, state: StepState, detail?: string) => void;

export type AppInfo = { name: string; lang: Lang };

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function cleanName(n: string) {
  return n.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
}

async function waitForRun(prevId: number, workflow: string, minutes: number) {
  const started = Date.now();
  while (Date.now() - started < minutes * 60 * 1000) {
    await sleep(5000);
    const runs = await listWorkflowRuns(REPO, workflow);
    const run = runs.find((r: any) => r.id > prevId);
    if (run && run.status === "completed") return run;
  }
  return null;
}

async function failWithLog(runId: number, message: string): Promise<never> {
  const tail = await getFailureLog(REPO, runId);
  throw new Error(tail ? `${message}\n${tail}` : message);
}

export async function listApps(): Promise<AppInfo[]> {
  const names = await listDir(REPO, "apps");
  const langs = await Promise.all(names.map((n) => detectLang(REPO, n)));
  return names.map((name, i) => ({ name, lang: langs[i] }));
}

export async function appExists(name: string): Promise<Lang | null> {
  for (const l of LANG_ORDER) {
    if (await getFileText(REPO, LANGS[l].mainFile(name))) return l;
  }
  return null;
}

// Steps: send -> ai -> save
export async function generateApp(
  opts: { name: string; lang: Lang; text: string; kind: "create" | "edit"; related?: string },
  report: Report
) {
  const { name, lang, text, kind } = opts;
  const info = LANGS[lang];
  const mainFile = info.mainFile(name);

  report("send", "active");
  if (kind === "edit" && !(await getFileText(REPO, mainFile))) {
    report("send", "error");
    throw new Error("التطبيق ده مش موجود. اعمل إنشاء الأول.");
  }
  const related = opts.related && opts.related !== name && (await appExists(opts.related)) ? opts.related : "";
  const prevId = await latestRunId(REPO, info.generateWorkflow);
  const model = lang !== "html" ? (await SecureStore.getItemAsync("GEMINI_MODEL")) ?? "" : "";
  const content =
    `${name}\n` +
    (related ? `@related: ${related}\n` : "") +
    (model ? `@model: ${model}\n` : "") +
    `${text}\n\n(request id: ${Date.now()})\n`;
  await pushFile(REPO, info.requestFile, content, `${kind === "edit" ? "Edit" : "Create"}: ${name}`);
  report("send", "done", related ? `مرتبط بـ ${related}` : undefined);

  report("ai", "active");
  const run = await waitForRun(prevId, info.generateWorkflow, 8);
  if (!run) {
    report("ai", "error");
    throw new Error("أخذ وقت أطول من المتوقع. افتح التطبيق من تطبيقاتي بعد شوية.");
  }
  if (run.conclusion !== "success") {
    report("ai", "error");
    await failWithLog(run.id, "فشل إنشاء الكود.");
  }
  report("ai", "done");

  report("save", "active");
  if (!(await getFileText(REPO, mainFile))) {
    report("save", "error");
    throw new Error("نجح، لكن الملف ما ظهر لسه. جرّب بعد شوية.");
  }
  report("save", "done", mainFile);
  return mainFile;
}

// Steps: send -> ai
export async function makeAiPreview(name: string, lang: Lang, report: Report) {
  const info = LANGS[lang];
  report("send", "active");
  const prevId = await latestRunId(REPO, info.generateWorkflow);
  await pushFile(REPO, info.requestFile, `${name}\n@preview\n\n(request id: ${Date.now()})\n`, `Preview: ${name}`);
  report("send", "done");
  report("ai", "active");
  const run = await waitForRun(prevId, info.generateWorkflow, 6);
  if (!run) {
    report("ai", "error");
    throw new Error("المعاينة أخذت وقت طويل. جرّب بعد شوية.");
  }
  if (run.conclusion !== "success") {
    report("ai", "error");
    await failWithLog(run.id, "فشل تجهيز المعاينة.");
  }
  report("ai", "done");
}

export async function uploadCode(name: string, lang: Lang, code: string, report: Report) {
  report("upload", "active");
  await pushFile(REPO, LANGS[lang].mainFile(name), code.trim() + "\n", `Upload code: ${name}`);
  report("upload", "done");
  if (LANGS[lang].hasAiPreview) await makeAiPreview(name, lang, report);
}

/** The name under the app icon on the phone (can be Arabic). Applied by the next build. */
export function cleanLabel(n: string) {
  return n.replace(/[<>&"'`\\$@?#%;|{}\[\]\n\r\t]/g, "").replace(/\s+/g, " ").trim().slice(0, 40);
}

export async function getDisplayName(name: string): Promise<string> {
  try {
    return cleanLabel((await getFileText(REPO, `apps/${name}/display-name.txt`)) ?? "");
  } catch {
    return "";
  }
}

export async function setDisplayName(name: string, label: string) {
  await pushFile(REPO, `apps/${name}/display-name.txt`, cleanLabel(label) + "\n", `App name: ${name}`);
}

/**
 * Android permissions (apps/<name>/perms.txt) = the ones the owner approved. Generation saves the ones the
 * description asks for; before a build the app asks the owner about any other permission the code uses.
 * Rules shared with scripts/perms.py in services/permissions.json.
 */
export const PERMISSIONS: { key: string; label: string }[] = PERM_RULES.keys.map((k) => ({ key: k.key, label: k.label }));

export function permissionLabels(keys: string[]) {
  return keys.map((k) => PERMISSIONS.find((p) => p.key === k)?.label ?? k).join("، ");
}

export async function getPermissions(name: string): Promise<string[]> {
  try {
    const text = (await getFileText(REPO, `apps/${name}/perms.txt`)) ?? "";
    const words: string[] = text.toUpperCase().match(/[A-Z_]+/g) ?? [];
    return PERMISSIONS.map((p) => p.key).filter((k) => words.includes(k));
  } catch {
    return [];
  }
}

/** The permissions the app's code uses that the owner has not approved yet. */
export async function neededPermissions(name: string, lang: Lang): Promise<string[]> {
  const file = LANGS[lang].mainFile(name);
  const rules = (PERM_RULES.code as Record<string, Record<string, string>>)[file.slice(`apps/${name}/`.length)] ?? {};
  const code = (await getFileText(REPO, file)) ?? "";
  const have = await getPermissions(name);
  return Object.entries(rules)
    .filter(([key, rx]) => !have.includes(key) && new RegExp(rx).test(code))
    .map(([key]) => key);
}

export async function approvePermissions(name: string, add: string[]) {
  const have = await getPermissions(name);
  const keys = PERMISSIONS.map((p) => p.key).filter((k) => have.includes(k) || add.includes(k));
  await pushFile(REPO, `apps/${name}/perms.txt`, keys.map((k) => k + "\n").join("") || "\n", `Permissions: ${name}`);
}

export async function uploadIcon(name: string, base64: string) {
  await pushBase64File(REPO, `apps/${name}/icon.png`, base64, `Set icon: ${name}`);
}

export async function loadPreview(name: string): Promise<{ html: string; lang: Lang; ai: boolean }> {
  const lang = await detectLang(REPO, name);
  const html = await getFileText(REPO, lang === "html" ? `apps/${name}/index.html` : `apps/${name}/preview.html`);
  if (!html) {
    throw new Error(
      lang === "html" ? "ملف التطبيق مش موجود." : "لسه ما في معاينة. اضغط \"معاينة جديدة بالذكاء الاصطناعي\"."
    );
  }
  return { html, lang, ai: lang !== "html" };
}

export async function deleteApp(name: string) {
  await deleteFolder(REPO, `apps/${name}`);
}

async function triggerWithRetry(workflow: string, inputs: Record<string, string>) {
  for (let i = 0; i < 5; i++) {
    try {
      await triggerWorkflow(REPO, workflow, inputs);
      return;
    } catch (e) {
      if (i === 4) throw e;
      await sleep(5000);
    }
  }
}

/** Starts the build of one app; `notes` is the text the installed app shows in its update message. */
export async function startBuild(name: string, lang: Lang, notes = ""): Promise<number> {
  const workflow = LANGS[lang].buildWorkflow;
  const prevId = await latestRunId(REPO, workflow);
  await triggerWithRetry(workflow, notes ? { app: name, notes: notes.slice(0, 500) } : { app: name });
  return prevId;
}

/** Waits for the build of `name` started after `prevId` (several apps can build at the same time). */
export async function waitForBuild(name: string, lang: Lang, prevId: number) {
  const workflow = LANGS[lang].buildWorkflow;
  const started = Date.now();
  while (Date.now() - started < 50 * 60 * 1000) {
    await sleep(15000);
    const runs = await listWorkflowRuns(REPO, workflow);
    // Runs are named "Build <app>"; older runs without that name still match the first newer run.
    const r = runs.find((x: any) => x.id > prevId && (x.title === `Build ${name}` || !String(x.title || "").startsWith("Build ")));
    if (r && r.status === "completed") {
      if (r.conclusion !== "success") await failWithLog(r.id, `فشل بناء ${name}.`);
      return r;
    }
  }
  throw new Error(`بناء ${name} أخذ وقت طويل. شوف GitHub Actions.`);
}

// Steps: start -> build -> download -> install
export async function buildAndInstall(name: string, lang: Lang, report: Report) {
  report("start", "active");
  const prevId = await startBuild(name, lang);
  report("start", "done");

  report("build", "active");
  try {
    await waitForBuild(name, lang, prevId);
  } catch (e) {
    report("build", "error");
    throw e;
  }
  report("build", "done");

  report("download", "active");
  const asset = await findAppApkAsset(REPO, name);
  if (!asset) {
    report("download", "error");
    throw new Error("ما لقيت ملف APK في الإصدارات.");
  }
  const info = await getAssetDownloadInfo(REPO, asset.id);
  const dest = FileSystem.cacheDirectory + `${name}.apk`;
  const dl = await FileSystem.downloadAsync(info.url, dest, { headers: info.headers });
  if (dl.status !== 200) {
    report("download", "error");
    throw new Error(`فشل التنزيل (${dl.status})`);
  }
  report("download", "done");

  report("install", "active");
  const contentUri = await FileSystem.getContentUriAsync(dl.uri);
  await IntentLauncher.startActivityAsync("android.intent.action.VIEW", {
    data: contentUri,
    flags: 1,
    type: "application/vnd.android.package-archive",
  });
  report("install", "done");
}

export type ToolRun = { id: number; status: string; conclusion: string | null; createdAt: string; htmlUrl: string };

export async function listToolBuilds(): Promise<ToolRun[]> {
  return listWorkflowRuns(REPO, "main.yml");
}

export async function buildTool() {
  await triggerWorkflow(REPO, "main.yml", { platform: "android" });
}
