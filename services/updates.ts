// Updating an app that is already installed on phones:
//   1. the AI applies the change (one app, or both apps of a connected pair) and the user previews it;
//   2. "تم" builds a new version; the build publishes apps/<app>/version.json;
//   3. the installed app reads that file when it opens and shows "تحديث جديد متوفر" with an update button.
// Before the first AI change we keep a snapshot of the code so "تراجع" can put it back.
import { getFileText, pushFile } from "./github";
import { REPO } from "./config";
import { LANGS, Lang } from "./langs";
import { generateApp, startBuild, waitForBuild, Report } from "./appActions";

export type Target = { name: string; lang: Lang };
export type Snapshot = { path: string; content: string }[];
export type PublishedVersion = { version: number; versionName?: string; notes?: string; at?: string };
export type PairInfo = { role: "customer" | "admin"; partner: string; lang: Lang; prefix: string; ref: string };

const DEPS_FILE: Record<Lang, string | null> = { html: null, flutter: "packages.txt", python: "requirements.txt", kotlin: null };

function codeFiles(t: Target) {
  const files = [LANGS[t.lang].mainFile(t.name)];
  if (t.lang !== "html") files.push(`apps/${t.name}/preview.html`);
  const deps = DEPS_FILE[t.lang];
  if (deps) files.push(`apps/${t.name}/${deps}`);
  return files;
}

export async function publishedVersion(name: string): Promise<PublishedVersion | null> {
  try {
    const text = await getFileText(REPO, `apps/${name}/version.json`);
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

export async function pairInfo(name: string): Promise<PairInfo | null> {
  try {
    const text = await getFileText(REPO, `apps/${name}/pair.json`);
    if (!text) return null;
    const st = JSON.parse(text);
    const role = st.role === "admin" ? "admin" : "customer";
    const other = role === "admin" ? "customer" : "admin";
    const partner = st.apps?.[other]?.name;
    return partner
      ? { role, partner, lang: st.lang as Lang, prefix: String(st.prefix ?? ""), ref: String(st.supabase?.ref ?? "") }
      : null;
  } catch {
    return null;
  }
}

export async function snapshot(targets: Target[]): Promise<Snapshot> {
  const snap: Snapshot = [];
  for (const t of targets) {
    for (const path of codeFiles(t)) {
      const content = await getFileText(REPO, path);
      if (content !== null) snap.push({ path, content });
    }
  }
  return snap;
}

export async function restore(snap: Snapshot) {
  for (const f of snap) {
    const now = await getFileText(REPO, f.path);
    if (now !== f.content) await pushFile(REPO, f.path, f.content, `Undo update: ${f.path}`);
  }
}

/** AI applies `text` to every target; the second app of a pair reads the first for consistency. Steps: ai:<name> */
export async function applyUpdate(targets: Target[], text: string, report: Report) {
  for (const t of targets) {
    const key = `ai:${t.name}`;
    report(key, "active");
    const other = targets.find((x) => x.name !== t.name)?.name;
    try {
      await generateApp(
        { name: t.name, lang: t.lang, text, kind: "edit", related: other },
        (step, state) => state === "error" && report(key, "error")
      );
    } catch (e) {
      report(key, "error");
      throw e;
    }
    report(key, "done");
  }
}

/** Builds a new version of every target at the same time. Steps: build:<name> */
export async function publishUpdate(targets: Target[], notes: string, report: Report) {
  const started: { t: Target; prevId: number }[] = [];
  for (const t of targets) {
    report(`build:${t.name}`, "active");
    started.push({ t, prevId: await startBuild(t.name, t.lang, notes) });
  }
  const results = await Promise.allSettled(
    started.map(async ({ t, prevId }) => {
      try {
        await waitForBuild(t.name, t.lang, prevId);
        const v = await publishedVersion(t.name);
        report(`build:${t.name}`, "done", v ? `الإصدار ${v.versionName ?? v.version}` : undefined);
      } catch (e) {
        report(`build:${t.name}`, "error");
        throw e;
      }
    })
  );
  const failed = results.find((r) => r.status === "rejected") as PromiseRejectedResult | undefined;
  if (failed) throw failed.reason;
}
