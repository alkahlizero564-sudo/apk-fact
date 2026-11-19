import * as SecureStore from "expo-secure-store";
import { netFetch } from "./net";
import { tokenFor } from "./projects";

const MGMT_API = "https://api.supabase.com/v1";

// The default account's token, or the token of the client project the call is for (services/projects.ts).
async function getManagementToken(ref?: string): Promise<string> {
  return tokenFor(ref);
}

async function getProjectRef(): Promise<string> {
  const ref = await SecureStore.getItemAsync("SUPABASE_PROJECT_REF");
  if (!ref) {
    throw new Error("SUPABASE_PROJECT_REF missing. Set it in Settings (the short ID in your project URL).");
  }
  return ref;
}

export async function testSupabaseConnection(): Promise<{ name: string; status: string }> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    throw new Error(`Supabase auth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return { name: data.name, status: data.status };
}

/** `retry`: send again after a network drop; only for statements that are safe to run twice. */
export async function runSql(query: string, projectRef?: string, retry = false): Promise<any> {
  const token = await getManagementToken(projectRef);
  const ref = projectRef || (await getProjectRef());

  const res = await netFetch(`${MGMT_API}/projects/${ref}/database/query`, {
    retry,
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query }),
  });

  if (!res.ok) {
    throw new Error(`SQL execution failed (${res.status}): ${await res.text()}`);
  }
  return res.json();
}

export async function getSupabaseClientInfo(): Promise<{ url: string; anonKey: string }> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}/api-keys`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    throw new Error(`Fetching Supabase keys failed (${res.status}): ${await res.text()}`);
  }

  const keys = await res.json();
  const list: any[] = (Array.isArray(keys) ? keys : []).filter((k) => k && k.api_key);
  const key =
    list.find((k) => k.name === "anon") ||
    list.find((k) => k.type === "publishable");

  if (!key || !key.api_key) {
    throw new Error("ما لقيت مفتاح anon أو publishable للمشروع.");
  }

  return { url: `https://${ref}.supabase.co`, anonKey: key.api_key };
}

export type EmailCodeTest = { ok: boolean; status: number; reply: string; settings: string[] };

/** Sends a real sign-in code to `email` the way the generated apps do, and reports the mail settings. */
export async function testEmailCode(email: string): Promise<EmailCodeTest> {
  const token = await getManagementToken();
  const ref = await getProjectRef();
  const settings: string[] = [];
  const cfg = await fetch(`${MGMT_API}/projects/${ref}/config/auth`, { headers: { Authorization: `Bearer ${token}` } });
  if (cfg.ok) {
    const c = await cfg.json();
    settings.push(c.smtp_host ? `خادم البريد: ${c.smtp_host}:${c.smtp_port ?? ""}` : "خادم البريد: بريد Supabase المدمج (محدود جداً)");
    if (c.smtp_admin_email) settings.push(`المرسل: ${c.smtp_admin_email}`);
    if (c.smtp_user) settings.push(`مستخدم SMTP: ${c.smtp_user}`);
    settings.push(`حد الرسائل في الساعة: ${c.rate_limit_email_sent ?? "؟"}`);
    settings.push(`طول الرمز: ${c.mailer_otp_length ?? "؟"} · تأكيد البريد: ${c.mailer_autoconfirm ? "مقفول" : "مفعّل"}`);
    if (c.external_email_enabled === false) settings.push("⚠️ الدخول بالبريد مقفول في المشروع");
  } else {
    settings.push(`ما قدرنا نقرأ إعدادات البريد (${cfg.status})`);
  }
  const stored = ((await SecureStore.getItemAsync("SUPABASE_PUBLISHABLE_KEY")) ?? "").trim();
  const { url, anonKey } = stored ? { url: `https://${ref}.supabase.co`, anonKey: stored } : await getSupabaseClientInfo();
  const res = await fetch(`${url}/auth/v1/otp`, {
    method: "POST",
    headers: { apikey: anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, create_user: true }),
  });
  const reply = (await res.text()).slice(0, 600);
  return { ok: res.ok, status: res.status, reply, settings };
}

/**
 * Applies the SMTP fields saved in settings to the Supabase project right away (sign-in code emails),
 * so changing the sender account does not need the apps to be created again. Returns the host, or null
 * when no SMTP is set.
 */
// Logins of mail relays are not mailboxes: Brevo's SMTP login looks like "abc123@smtp-brevo.com", SendGrid's is
// "apikey". Used as the sender, the relay accepts the login but drops or refuses every code email.
const RELAY_LOGIN_DOMAINS = ["smtp-brevo.com"];

/** The sender address for the code emails; throws a clear message when it can't be one. */
export function smtpSender(from: string, user: string): string {
  const sender = (from || user).trim();
  const domain = sender.includes("@") ? sender.split("@").pop()!.toLowerCase() : "";
  if (!domain || RELAY_LOGIN_DOMAINS.includes(domain)) {
    throw new Error(
      `«${sender || "فارغ"}» مش عنوان مرسل، ده اسم الدخول لخادم البريد — رسائل الرمز ما بتوصل منه. ` +
        "اكتب في «SMTP: عنوان المرسل» بريدك الذي وثّقته في Brevo (Senders، Domains & Dedicated IPs ← Senders ← Add a sender، ثم أكّد من رسالة البريد)."
    );
  }
  return sender;
}

export async function applySmtpSettings(): Promise<string | null> {
  const get = async (k: string) => ((await SecureStore.getItemAsync(k)) ?? "").trim();
  const host = await get("SMTP_HOST");
  if (!host) return null;
  const user = await get("SMTP_USER");
  const rawPass = await get("SMTP_PASS");
  const body = {
    smtp_host: host,
    smtp_port: (await get("SMTP_PORT")) || "587",
    smtp_user: user,
    // Gmail shows app passwords in groups of 4 ("abcd efgh ..."); the spaces are not part of it.
    smtp_pass: /gmail/i.test(host) ? rawPass.replace(/\s+/g, "") : rawPass,
    smtp_admin_email: smtpSender(await get("SMTP_FROM"), user),
    smtp_sender_name: "APK Fact",
    rate_limit_email_sent: 100,
  };
  const token = await getManagementToken();
  const ref = await getProjectRef();
  const res = await fetch(`${MGMT_API}/projects/${ref}/config/auth`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`ما قدرنا نطبّق إعدادات البريد (${res.status}): ${(await res.text()).slice(0, 300)}`);
  return host;
}
