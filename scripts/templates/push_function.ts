// Supabase Edge Function "<prefix>-push", deployed by scripts/pair.py for one pair of apps.
// Called by a database trigger for every new <prefix>_notifications row; sends it with Firebase Cloud
// Messaging (HTTP v1) to the right devices and removes devices that no longer exist.
// Runs on Deno (Supabase); written against web standards only, so it is tested in Node too.

const PREFIX = "__PREFIX__";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
type Env = { supabaseUrl: string; serviceKey: string; secret: string; sa: ServiceAccount };
type Fetch = typeof fetch;
type Notification = {
  id: number;
  to_user: string | null;
  to_role: "customer" | "admin" | null;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  created_by: string | null;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function b64url(data: ArrayBuffer | Uint8Array | string) {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** OAuth access token for FCM from the Firebase service account (RS256 JWT, Google token endpoint). */
export async function googleToken(sa: ServiceAccount, f: Fetch = fetch): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await f("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}&assertion=${header}.${claims}.${b64url(sig)}`,
  });
  if (!res.ok) throw new Error(`Google token ${res.status}: ${await res.text()}`);
  return (await res.json()).access_token;
}

async function rest(env: Env, f: Fetch, path: string, init: RequestInit = {}) {
  const res = await f(`${env.supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: env.serviceKey, Authorization: `Bearer ${env.serviceKey}`, "Content-Type": "application/json" },
  });
  if (!res.ok) throw new Error(`Supabase ${path} ${res.status}: ${await res.text()}`);
  return init.method === "DELETE" ? null : res.json();
}

/** Device tokens the notification goes to. */
export async function targetTokens(n: Notification, env: Env, f: Fetch = fetch): Promise<string[]> {
  if (n.to_user) {
    const rows = await rest(env, f, `${PREFIX}_device_tokens?select=token&user_id=eq.${n.to_user}`);
    return rows.map((r: { token: string }) => r.token);
  }
  if (!n.to_role) return [];
  if (n.to_role === "customer") {
    // Everyone who uses the customer app (also the owner testing it with an admin account).
    const rows = await rest(env, f, `${PREFIX}_device_tokens?select=token&app=eq.customer`);
    return rows.map((r: { token: string }) => r.token);
  }
  // The admin app: only the devices of real admins.
  const users = await rest(env, f, `${PREFIX}_profiles?select=id&role=eq.${n.to_role}`);
  // The sender is not dropped: tokens are only taken from the target app (app=eq.<role>), so an admin who places
  // an order from the customer app (the owner testing both apps with one account) still gets it on the admin app.
  const ids = users.map((u: { id: string }) => u.id);
  if (!ids.length) return [];
  const rows = await rest(env, f, `${PREFIX}_device_tokens?select=token&app=eq.${n.to_role}&user_id=in.(${ids.join(",")})`);
  return rows.map((r: { token: string }) => r.token);
}

export async function handle(req: Request, env: Env, f: Fetch = fetch): Promise<Response> {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!env.secret || req.headers.get("x-push-secret") !== env.secret) return json({ error: "forbidden" }, 403);
  const n = (await req.json()).record as Notification;
  const tokens = await targetTokens(n, env, f);
  if (!tokens.length) return json({ sent: 0, removed: 0 });

  const access = await googleToken(env.sa, f);
  const data: Record<string, string> = { notification_id: String(n.id) };
  for (const [k, v] of Object.entries(n.data ?? {})) data[k] = typeof v === "string" ? v : JSON.stringify(v);

  let sent = 0;
  const dead: string[] = [];
  for (const token of tokens) {
    const res = await f(`https://fcm.googleapis.com/v1/projects/${env.sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: n.title, body: n.body ?? "" },
          data,
          android: { priority: "high", notification: { sound: "default" } },
        },
      }),
    });
    if (res.ok) sent++;
    else {
      const err = await res.text();
      if (res.status === 404 || err.includes("UNREGISTERED") || err.includes("INVALID_ARGUMENT")) dead.push(token);
    }
  }
  if (dead.length) {
    const list = dead.map((t) => `"${t.replace(/"/g, '\\"')}"`).join(",");
    await rest(env, f, `${PREFIX}_device_tokens?token=in.(${encodeURIComponent(list)})`, { method: "DELETE" });
  }
  return json({ sent, removed: dead.length });
}

declare const Deno: any;
if (typeof Deno !== "undefined") {
  Deno.serve((req: Request) =>
    handle(req, {
      supabaseUrl: Deno.env.get("SUPABASE_URL"),
      serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      secret: Deno.env.get(`PUSH_SECRET_${PREFIX.toUpperCase()}`) ?? "",
      sa: JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}"),
    }).catch((e: Error) => json({ error: e.message }, 500))
  );
}
