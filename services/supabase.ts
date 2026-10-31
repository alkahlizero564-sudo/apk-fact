import * as SecureStore from "expo-secure-store";

const MGMT_API = "https://api.supabase.com/v1";

async function getManagementToken(): Promise<string> {
  const token = await SecureStore.getItemAsync("SUPABASE_ACCESS_TOKEN");
  if (!token) {
    throw new Error(
      "SUPABASE_ACCESS_TOKEN missing. This is a Personal Access Token from supabase.com → Account → Access Tokens (different from the project's anon key)."
    );
  }
  return token;
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

export async function runSql(query: string): Promise<any> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}/database/query`, {
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
