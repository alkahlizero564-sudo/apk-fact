// GitHub Actions secrets and variables of the APK Fact repo, written from the phone with the user's token.
import nacl from "tweetnacl";
import * as Crypto from "expo-crypto";
import { githubApi } from "./github";
import { REPO } from "./config";
import { encryptSecret } from "./sealedBox";

nacl.setPRNG((x, n) => {
  const bytes = Crypto.getRandomBytes(n);
  for (let i = 0; i < n; i++) x[i] = bytes[i];
});

export async function checkGithub(res: Response, what: string) {
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

let publicKey: { key: string; key_id: string } | null = null;

/** Store an encrypted Actions secret (libsodium sealed box, as GitHub requires). */
export async function setRepoSecret(name: string, value: string) {
  if (!publicKey) {
    publicKey = await (await checkGithub(await githubApi(`/repos/${REPO}/actions/secrets/public-key`), "قراءة مفتاح التشفير")).json();
  }
  await checkGithub(
    await githubApi(`/repos/${REPO}/actions/secrets/${name}`, {
      method: "PUT",
      body: { encrypted_value: encryptSecret(value, publicKey!.key), key_id: publicKey!.key_id },
    }),
    `حفظ السرّ ${name}`
  );
}

export async function setRepoVariable(name: string, value: string) {
  const created = await githubApi(`/repos/${REPO}/actions/variables`, { method: "POST", body: { name, value }, retry: true }) // a repeat answers 409;
  if (created.status === 409) {
    await checkGithub(
      await githubApi(`/repos/${REPO}/actions/variables/${name}`, { method: "PATCH", body: { name, value } }),
      `حفظ المتغيّر ${name}`
    );
  } else {
    await checkGithub(created, `حفظ المتغيّر ${name}`);
  }
}
