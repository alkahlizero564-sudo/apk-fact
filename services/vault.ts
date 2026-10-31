// The private vault: a private GitHub repo (apk-fact-vault) that keeps, for every app, its permanent
// signing key, its source and its details. Build workflows read it (through the VAULT_TOKEN secret and
// the VAULT_REPO variable) so every APK of an app is signed with the same key and updates install.
import nacl from "tweetnacl";
import * as Crypto from "expo-crypto";
import { githubApi, githubToken, latestRunId, listWorkflowRuns, getFailureLog, triggerWorkflow } from "./github";
import { REPO } from "./config";
import { encryptSecret, fromBase64 } from "./sealedBox";
import type { Report } from "./appActions";

export const VAULT_NAME = "apk-fact-vault";

nacl.setPRNG((x, n) => {
  const bytes = Crypto.getRandomBytes(n);
  for (let i = 0; i < n; i++) x[i] = bytes[i];
});

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function check(res: Response, what: string) {
  if (res.ok) return res;
  const body = await res.text();
  if (res.status === 403 || res.status === 404) {
    throw new Error(
      `${what}: مفتاح GitHub ما عنده صلاحية كافية (${res.status}). ` +
        "استخدم Personal Access Token (classic) بصلاحية repo و workflow، أو مفتاح fine-grained بصلاحيات " +
        "Administration و Contents و Secrets و Variables و Actions."
    );
  }
  throw new Error(`${what} (${res.status}): ${body.slice(0, 200)}`);
}

export type VaultStatus = { ready: boolean; repo: string | null };

export async function vaultStatus(): Promise<VaultStatus> {
  const res = await githubApi(`/repos/${REPO}/actions/variables/VAULT_REPO`);
  if (!res.ok) return { ready: false, repo: null };
  const repo = (await res.json()).value as string;
  const exists = await githubApi(`/repos/${repo}`);
  return { ready: exists.ok, repo };
}

// Steps: repo -> secret -> variable
export async function setupVault(report: Report): Promise<string> {
  report("repo", "active");
  const me = await (await check(await githubApi("/user"), "قراءة حساب GitHub")).json();
  const repo = `${me.login}/${VAULT_NAME}`;
  const found = await githubApi(`/repos/${repo}`);
  if (found.ok) {
    if (!(await found.json()).private) throw new Error(`المستودع ${repo} موجود لكنه عام. خلّيه خاص أو احذفه أولاً.`);
    report("repo", "done", `${repo} (موجود)`);
  } else {
    await check(
      await githubApi("/user/repos", {
        method: "POST",
        body: {
          name: VAULT_NAME,
          private: true,
          auto_init: true,
          description: "APK Fact vault: signing keys, source and details of each app",
        },
      }),
      "إنشاء المستودع الخاص"
    );
    report("repo", "done", `${repo} (خاص)`);
  }

  report("secret", "active");
  const key = await (await check(await githubApi(`/repos/${REPO}/actions/secrets/public-key`), "قراءة مفتاح التشفير")).json();
  await check(
    await githubApi(`/repos/${REPO}/actions/secrets/VAULT_TOKEN`, {
      method: "PUT",
      body: { encrypted_value: encryptSecret(await githubToken(), key.key), key_id: key.key_id },
    }),
    "حفظ مفتاح الخزنة كسرّ مشفّر"
  );
  report("secret", "done", "VAULT_TOKEN مشفّر في أسرار المستودع");

  report("variable", "active");
  const created = await githubApi(`/repos/${REPO}/actions/variables`, {
    method: "POST",
    body: { name: "VAULT_REPO", value: repo },
  });
  if (created.status === 409) {
    await check(
      await githubApi(`/repos/${REPO}/actions/variables/VAULT_REPO`, { method: "PATCH", body: { name: "VAULT_REPO", value: repo } }),
      "ربط الخزنة"
    );
  } else {
    await check(created, "ربط الخزنة");
  }
  report("variable", "done", "كل بناء جاي بيتوقّع بمفتاح التطبيق الدائم");
  return repo;
}

export type VaultApp = { name: string; lang?: string; savedAt?: string; packageId?: string; sha256?: string };

/** Apps saved in the vault, with the details from apps/<name>/app.json. */
export async function listVaultApps(repo: string): Promise<VaultApp[]> {
  const res = await githubApi(`/repos/${repo}/contents/vault-index.json?t=${Date.now()}`);
  if (!res.ok) return [];
  const data = await res.json();
  const bytes = fromBase64(String(data.content));
  const json = JSON.parse(decodeURIComponent(escape(String.fromCharCode(...Array.from(bytes)))));
  return (json.apps ?? []) as VaultApp[];
}

// Steps: send -> save
export async function saveToVault(app: string, notes: string, report: Report) {
  report("send", "active");
  const prevId = await latestRunId(REPO, "vault-save.yml");
  await triggerWorkflow(REPO, "vault-save.yml", { app, notes: notes.slice(0, 900) });
  report("send", "done");
  report("save", "active");
  const started = Date.now();
  while (Date.now() - started < 8 * 60 * 1000) {
    await sleep(5000);
    const run = (await listWorkflowRuns(REPO, "vault-save.yml")).find((r: any) => r.id > prevId);
    if (run && run.status === "completed") {
      if (run.conclusion === "success") {
        report("save", "done");
        return;
      }
      report("save", "error");
      const tail = await getFailureLog(REPO, run.id);
      throw new Error("فشل الحفظ في الخزنة." + (tail ? "\n" + tail : ""));
    }
  }
  report("save", "error");
  throw new Error("الحفظ أخذ وقت طويل. شوف حالة الخزنة بعد شوية.");
}
