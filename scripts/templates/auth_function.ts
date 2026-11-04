// Supabase Edge Function "<prefix>-auth", deployed by scripts/pair.py for one pair of apps whose sign-in is
// «الاسم + رقم الهاتف + كلمة مرور» or «الاسم + البريد + كلمة مرور». It makes accounts that need no email code
// (so the project can still confirm emails with a code for an app that asks for it), signs in with the phone
// number, and lets an admin set a new password for a customer who forgot it (there is no SMS).
//   POST {action: "signup", full_name, phone?, email?, password}  -> {ok: true}
//   POST {action: "login", phone, password}                        -> the Supabase session
//   POST {action: "set_password", phone, password} + admin token  -> {ok: true}
// Errors: {error: "<Arabic message>"} with a 4xx status. Runs on Deno; web standards only.

const PREFIX = "__PREFIX__";
const ALLOW_PHONE: boolean = "__ALLOW_PHONE__" === "true";
const ALLOW_EMAIL: boolean = "__ALLOW_EMAIL__" === "true";

type Env = { url: string; anon: string; service: string };
type Fetch = typeof fetch;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const fail = (error: string, status = 400) => json({ error }, status);

/** Digits only (Arabic-Indic and Persian digits too), without a leading 00. */
export function phoneDigits(phone: unknown): string {
  const s = String(phone ?? "")
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x6f0))
    .replace(/\D/g, "");
  return s.replace(/^00/, "");
}

/** The hidden email of a phone account (the phone is the login; users never see it). */
export const phoneEmail = (digits: string) => `${digits}@phone.${PREFIX.replace(/_/g, "-")}.app`;

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function arabic(msg: string, phone: boolean): string {
  const m = msg.toLowerCase();
  if (m.includes("already") || m.includes("exists") || m.includes("registered"))
    return phone ? "رقم الهاتف ده مسجّل قبل كده. سجّل دخول." : "البريد ده مسجّل قبل كده. سجّل دخول.";
  if (m.includes("invalid login") || m.includes("invalid credentials") || m.includes("invalid_grant"))
    return phone ? "رقم الهاتف أو كلمة المرور غلط." : "البريد أو كلمة المرور غلط.";
  if (m.includes("password")) return "كلمة المرور ضعيفة: 6 أحرف أو أكتر.";
  if (m.includes("rate")) return "محاولات كتير. استنى شوية وجرّب تاني.";
  return msg || "حصل خطأ من السيرفر";
}

async function readJson(r: Response) {
  const t = await r.text();
  try {
    return JSON.parse(t || "{}");
  } catch {
    return { msg: t };
  }
}
const errText = (o: any) => String(o?.msg ?? o?.message ?? o?.error_description ?? o?.error ?? "");

async function phoneTaken(env: Env, digits: string, f: Fetch) {
  const r = await f(`${env.url}/rest/v1/${PREFIX}_profiles?select=id&phone=eq.${digits}&limit=1`, {
    headers: { apikey: env.service, Authorization: `Bearer ${env.service}` },
  });
  const rows = r.ok ? await r.json() : [];
  return Array.isArray(rows) && rows.length > 0;
}

export async function handle(req: Request, env: Env, f: Fetch = fetch): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail("POST only", 405);
  let b: any;
  try {
    b = await req.json();
  } catch {
    return fail("الطلب ناقص");
  }
  const action = String(b?.action ?? "");
  const password = String(b?.password ?? "");
  const digits = phoneDigits(b?.phone);

  if (action === "signup") {
    const name = String(b?.full_name ?? "").trim();
    const email = String(b?.email ?? "").trim().toLowerCase();
    if (!name) return fail("اكتب الاسم");
    if (password.length < 6) return fail("كلمة المرور لازم تكون 6 أحرف أو أكتر");
    if (email ? !ALLOW_EMAIL : !ALLOW_PHONE) return fail("طريقة التسجيل دي مقفولة في التطبيق ده", 403);
    if (email && !EMAIL.test(email)) return fail("البريد مكتوب غلط");
    if (!email && (digits.length < 8 || digits.length > 15)) return fail("رقم الهاتف مكتوب غلط");
    if (digits && (await phoneTaken(env, digits, f))) return fail("رقم الهاتف ده مسجّل قبل كده. سجّل دخول.", 409);
    const r = await f(`${env.url}/auth/v1/admin/users`, {
      method: "POST",
      headers: { apikey: env.service, Authorization: `Bearer ${env.service}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: email || phoneEmail(digits),
        password,
        email_confirm: true,
        user_metadata: { full_name: name, phone: digits || null },
      }),
    });
    if (!r.ok) return fail(arabic(errText(await readJson(r)), !email), r.status === 422 ? 409 : 400);
    return json({ ok: true });
  }

  if (action === "login") {
    if (!ALLOW_PHONE) return fail("طريقة الدخول دي مقفولة في التطبيق ده", 403);
    if (!digits || !password) return fail("اكتب رقم الهاتف وكلمة المرور");
    const r = await f(`${env.url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: env.anon, "Content-Type": "application/json" },
      body: JSON.stringify({ email: phoneEmail(digits), password }),
    });
    const o = await readJson(r);
    if (!r.ok || !o.access_token) return fail(arabic(errText(o), true), 400);
    return json(o);
  }

  if (action === "set_password") {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const me = await f(`${env.url}/auth/v1/user`, { headers: { apikey: env.anon, Authorization: `Bearer ${token}` } });
    const user = me.ok ? await me.json() : null;
    if (!user?.id) return fail("سجّل دخول تاني", 401);
    const prof = await f(`${env.url}/rest/v1/${PREFIX}_profiles?select=role&id=eq.${user.id}`, {
      headers: { apikey: env.service, Authorization: `Bearer ${env.service}` },
    });
    const rows = prof.ok ? await prof.json() : [];
    if (rows?.[0]?.role !== "admin") return fail("الإدارة بس تقدر تغيّر كلمة مرور زبون", 403);
    if (password.length < 6) return fail("كلمة المرور لازم تكون 6 أحرف أو أكتر");
    const t = await f(`${env.url}/rest/v1/${PREFIX}_profiles?select=id&phone=eq.${digits}&limit=1`, {
      headers: { apikey: env.service, Authorization: `Bearer ${env.service}` },
    });
    const target = (t.ok ? await t.json() : [])?.[0]?.id;
    if (!digits || !target) return fail("ما في حساب بالرقم ده", 404);
    const r = await f(`${env.url}/auth/v1/admin/users/${target}`, {
      method: "PUT",
      headers: { apikey: env.service, Authorization: `Bearer ${env.service}`, "Content-Type": "application/json" },
      body: JSON.stringify({ password }),
    });
    if (!r.ok) return fail(arabic(errText(await readJson(r)), true));
    return json({ ok: true });
  }

  return fail("action غير معروف");
}

// Deno (Supabase) entry point; skipped when the file is imported by a test.
const D: any = (globalThis as any).Deno;
if (D?.serve) {
  D.serve((req: Request) =>
    handle(req, {
      url: D.env.get("SUPABASE_URL"),
      anon: D.env.get("SUPABASE_ANON_KEY"),
      service: D.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    })
  );
}
