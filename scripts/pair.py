"""Create a pair of connected apps (customer + admin) on Supabase, with email-code login and push.

Run as separate workflow steps (generate-pair.yml), sharing state in apps/<base>-customer/pair.json:
  python scripts/pair.py backend  --base B --lang L --admins "a@x.com,b@y.com" --push true --description-file F
  python scripts/pair.py auth     --base B
  python scripts/pair.py firebase --base B
  python scripts/pair.py generate --base B --role customer|admin

Env: SUPABASE_ACCESS_TOKEN, SUPABASE_PROJECT_REF, optional SUPABASE_SMTP (JSON), FIREBASE_SERVICE_ACCOUNT
(JSON, for push), GEMINI_API_KEY[_2|_3].
"""
import argparse
import base64
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

import pair_backend as sb
from gemini_client import call_gemini
from native_langs import parse_reply

ROOT = Path(__file__).resolve().parent.parent
MODEL = os.environ.get("GEMINI_MODEL") or "gemini-3.8-flash"
ROLES = {"customer": "customer", "admin": "admin"}


def keys():
    k = [os.environ.get(n) for n in ("GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3")]
    k = [x for x in k if x]
    if not k:
        raise SystemExit("No Gemini API key in repository secrets")
    return k


def need(name):
    v = os.environ.get(name, "").strip()
    if not v:
        raise SystemExit(f"{name} is missing. Open APK Fact > الإعدادات and fill Supabase (and Firebase for notifications), then try again.")
    return v


def app_name(base, role):
    return f"{base}-{role}"


def package_id(name, lang):
    # Must match the build workflows (and scripts/vault.py).
    return "com.generated.a" + re.sub(r"[^a-z0-9]", "", name) if lang == "html" else "com.generated.app_" + name.replace("-", "_")


def state_paths(base):
    return [ROOT / "apps" / app_name(base, r) / "pair.json" for r in ROLES]


def load_state(base):
    return json.loads(state_paths(base)[0].read_text(encoding="utf-8"))


def save_state(base, state):
    for role, path in zip(ROLES, state_paths(base)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({**state, "role": role}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def run_sql(sql):
    if os.environ.get("PAIR_TEST_PSQL"):  # tests: a local Postgres with a Supabase stand-in
        r = subprocess.run(os.environ["PAIR_TEST_PSQL"].split() + ["-v", "ON_ERROR_STOP=1", "-q"], input=sql,
                           text=True, capture_output=True)
        if r.returncode:
            raise RuntimeError(r.stderr.strip())
        return
    sb.run_sql(need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN"), sql)


# ---------------- backend ----------------

SCHEMA_PROMPT = """You design the PostgreSQL schema (Supabase) for the business part of a pair of mobile apps:
a CUSTOMER app and an ADMIN app for the same business.

Business description (from the owner):
{description}

These already exist (do NOT create them again):
- auth.users(id uuid, email text)
- public.{p}_profiles(id uuid = auth.users.id, email text, full_name text, phone text, role text 'customer'|'admin')
- public.{p}_is_admin() returns boolean  -- true when the signed-in user is an admin
- public.{p}_notifications(to_user uuid, to_role text, title, body, data jsonb)

Rules:
- Prefix EVERY new table with {p}_ . Use `create table if not exists`, uuid or bigint identity primary keys,
  created_at timestamptz default now(). Rows that belong to a customer have
  `customer_id uuid not null default auth.uid() references auth.users(id) on delete cascade`.
- Enable row level security on every table. Before each `create policy` write `drop policy if exists`.
  Customers: read/insert/update only their own rows (customer_id = auth.uid()). Catalog-like tables
  (products, services, menu, slots...) are readable by every authenticated user and writable only by admins.
  Admins (public.{p}_is_admin()) can do everything on every table. Policies are `to authenticated`.
- Use only standard PostgreSQL 15 (no extensions), and add a few realistic sample rows to catalog tables
  (with `on conflict do nothing` or a guard so running the script twice is safe).

Reply in exactly this format, nothing else:
1. one ```sql code block with the full script
2. one ```json code block: {{"tables": [{{"name": "...", "purpose": "...", "columns": ["col type", ...], "owner": "customer|catalog|admin"}}],
   "events": [{{"when": "what happens in which app", "notify": "admin|customer", "title": "notification title in the app's language"}}]}}
"""


def design_digest(app, limit=6000):
    """The visible text of an approved design (screens, labels, fields), short enough for a prompt."""
    path = ROOT / "apps" / app / "design.html"
    if not path.exists():
        return ""
    html = path.read_text(encoding="utf-8")
    html = re.sub(r"(?is)<(script|style|svg)\b.*?</\1>", " ", html)
    html = re.sub(r"(?is)<(input|textarea|select)\b([^>]*)>", lambda m: " [field " + " ".join(
        re.findall(r'(?:placeholder|name|type|aria-label)="([^"]*)"', m.group(2))) + "] ", html)
    text = re.sub(r"(?s)<[^>]+>", " ", html)
    text = re.sub(r"[ \t]+", " ", re.sub(r"\s*\n\s*", "\n", text)).strip()
    return text[:limit]


def designs_note(base):
    parts = []
    for role in ROLES:
        d = design_digest(app_name(base, role))
        if d:
            parts.append(f"--- {role.upper()} app (approved design: screens, labels and fields) ---\n{d}")
    if not parts:
        return ""
    return ("\nThe owner already approved the design of both apps. The tables must store every piece of data these "
            "screens show or collect (same names and meaning), so the apps can be built exactly like the design:\n"
            + "\n".join(parts) + "\n")


def cmd_backend(a):
    ref, token = need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN")
    description = Path(a.description_file).read_text(encoding="utf-8").strip()
    p = sb.prefix_of(a.base)
    admins = [e.strip() for e in a.admins.split(",") if e.strip()]
    if not admins:
        raise SystemExit("Add at least one admin email")
    url, anon = (os.environ.get("PAIR_TEST_URL"), "test-anon") if os.environ.get("PAIR_TEST_PSQL") else sb.api_keys(ref, token)

    print("Creating accounts, roles, devices and notifications tables…", flush=True)
    run_sql(sb.base_sql(p, admins))

    print("Designing the business tables with AI…", flush=True)
    blocks, _ = parse_reply(call_gemini(MODEL, SCHEMA_PROMPT.format(description=description, p=p) + designs_note(a.base),
                                        keys(), temperature=0.3, json_mode=False))
    sql, contract = blocks.get("sql", ""), json.loads(blocks.get("json") or "{}")
    for attempt in range(4):
        try:
            run_sql(sql)
            break
        except RuntimeError as e:
            if attempt == 3:
                raise SystemExit(f"The business schema still fails after 3 AI fixes: {e}")
            print(f"Schema error, asking AI to fix it: {str(e)[:300]}", flush=True)
            blocks, _ = parse_reply(call_gemini(
                MODEL, f"This PostgreSQL script failed on Supabase with:\n{e}\n\nFix it (keep the same tables and rules) "
                       f"and reply with ONE ```sql code block only.\n\n```sql\n{sql}\n```", keys(), temperature=0.2,
                json_mode=False))
            sql = blocks.get("sql", sql)

    tables = [t["name"] for t in contract.get("tables", []) if str(t.get("name", "")).startswith(p + "_")]
    run_sql(sb.realtime_sql(tables + [f"{p}_notifications"]))
    save_state(a.base, {
        "pair": a.base, "prefix": p, "lang": a.lang, "push": a.push == "true" and a.lang != "python",
        "admins": admins, "description": description,
        "supabase": {"url": url, "anonKey": anon, "ref": ref},
        "schemaSql": sql, "contract": contract,
        "apps": {r: {"name": app_name(a.base, r), "packageId": package_id(app_name(a.base, r), a.lang)} for r in ROLES},
    })
    print(f"Backend ready: {len(tables)} business tables for {p}", flush=True)


def cmd_auth(a):
    ref, token = need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN")
    sb.configure_email_otp(ref, token, sb.env_smtp())
    if not sb.env_smtp():
        print("::warning::No custom SMTP set: Supabase's built-in mailer sends only a few emails per hour and only "
              "to your team's addresses. Add SMTP in APK Fact > الإعدادات > Supabase for real customers.")
    print("Email sign-in with a 6-digit code is on", flush=True)


# ---------------- firebase ----------------

def google_token(sa):
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request
    creds = service_account.Credentials.from_service_account_info(
        sa, scopes=["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/firebase"])
    try:
        creds.refresh(Request())
    except Exception as e:  # google.auth.exceptions.RefreshError and network errors
        text = str(e)
        hint = ""
        if "account not found" in text or "invalid_grant" in text:
            hint = (" The Firebase service account key is no longer valid (the key was deleted or the service "
                    "account removed). In Firebase console > Project settings > Service accounts, press "
                    "'Generate new private key' and paste the whole new JSON in APK Fact > الإعدادات > Firebase.")
        raise SystemExit(f"Firebase sign-in failed for {sa.get('client_email', '?')}: {text}.{hint}")
    return creds.token


def fb(method, path, token, body=None):
    req = urllib.request.Request(
        f"https://firebase.googleapis.com/v1beta1/{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        msg = e.read().decode()[:500]
        if e.code == 403:
            raise SystemExit(
                f"Firebase refused ({msg}). In Google Cloud > IAM, give the service account the role "
                "'Firebase Admin', then try again.")
        raise SystemExit(f"Firebase {method} {path} -> {e.code}: {msg}")


def register_android_app(project, package, display, token):
    apps = fb("GET", f"projects/{project}/androidApps?pageSize=100", token).get("apps", [])
    found = next((x for x in apps if x.get("packageName") == package), None)
    if not found:
        op = fb("POST", f"projects/{project}/androidApps", token, {"packageName": package, "displayName": display})
        for _ in range(30):
            if op.get("done"):
                break
            time.sleep(2)
            op = fb("GET", op["name"], token)
        found = op.get("response") or {}
        if not found.get("appId"):
            raise SystemExit(f"Firebase did not finish registering {package}: {op}")
    cfg = fb("GET", f"projects/{project}/androidApps/{found['appId']}/config", token)
    return base64.b64decode(cfg["configFileContents"]).decode()


def flutter_options(google_services, package):
    gs = json.loads(google_services)
    client = next(c for c in gs["client"] if c["client_info"]["android_client_info"]["package_name"] == package)
    return (
        "// Generated from google-services.json by APK Fact. Use: Firebase.initializeApp(options: firebaseOptions)\n"
        "import 'package:firebase_core/firebase_core.dart';\n\n"
        "const firebaseOptions = FirebaseOptions(\n"
        f"  apiKey: '{client['api_key'][0]['current_key']}',\n"
        f"  appId: '{client['client_info']['mobilesdk_app_id']}',\n"
        f"  messagingSenderId: '{gs['project_info']['project_number']}',\n"
        f"  projectId: '{gs['project_info']['project_id']}',\n"
        f"  storageBucket: '{gs['project_info'].get('storage_bucket', '')}',\n"
        ");\n"
    )


def cmd_firebase(a):
    st = load_state(a.base)
    if not st["push"]:
        print("Notifications are off for this pair (or not supported for Python apps)")
        return
    ref, token = need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN")
    sa_raw = need("FIREBASE_SERVICE_ACCOUNT")
    sa = json.loads(sa_raw)
    gtoken = google_token(sa)
    p = st["prefix"]

    for role in ROLES:
        app = st["apps"][role]
        print(f"Registering {app['packageId']} in Firebase project {sa['project_id']}…", flush=True)
        gs = register_android_app(sa["project_id"], app["packageId"], app["name"], gtoken)
        d = ROOT / "apps" / app["name"]
        d.mkdir(parents=True, exist_ok=True)
        (d / "google-services.json").write_text(gs, encoding="utf-8")
        if st["lang"] == "flutter":
            (d / "lib").mkdir(exist_ok=True)
            (d / "lib" / "firebase_config.dart").write_text(flutter_options(gs, app["packageId"]), encoding="utf-8")

    fn = f"{p.replace('_', '-')}-push"
    secret = secrets.token_urlsafe(32)
    with tempfile.TemporaryDirectory() as tmp:
        fdir = Path(tmp) / "supabase" / "functions" / fn
        fdir.mkdir(parents=True)
        src = (ROOT / "scripts" / "templates" / "push_function.ts").read_text(encoding="utf-8")
        (fdir / "index.ts").write_text(src.replace("__PREFIX__", p), encoding="utf-8")
        env_file = Path(tmp) / "secrets.env"
        env_file.write_text(f"FIREBASE_SERVICE_ACCOUNT={json.dumps(sa)}\nPUSH_SECRET_{p.upper()}={secret}\n", encoding="utf-8")
        print(f"Deploying the {fn} Edge Function…", flush=True)
        subprocess.run(["supabase", "secrets", "set", "--project-ref", ref, "--env-file", str(env_file)], cwd=tmp, check=True)
        subprocess.run(["supabase", "functions", "deploy", fn, "--project-ref", ref, "--no-verify-jwt", "--use-api"],
                       cwd=tmp, check=True)
    run_sql("create extension if not exists pg_net;\n" +
            sb.push_sql(p, f"{st['supabase']['url']}/functions/v1/{fn}", secret))
    st["pushFunction"] = fn
    save_state(a.base, st)
    print("Push notifications are connected", flush=True)


# ---------------- generate ----------------

def contract_text(st, role):
    p, url, anon = st["prefix"], st["supabase"]["url"], st["supabase"]["anonKey"]
    lang, push = st["lang"], st["push"]
    other = "admin" if role == "customer" else "customer"
    tables = json.dumps(st.get("contract", {}), ensure_ascii=False, indent=1)
    push_rules = {
        "html": (
            "Push notifications (Capacitor, Android): when `window.Capacitor` exists use `const { PushNotifications } = "
            "Capacitor.Plugins;` -> `await PushNotifications.requestPermissions()` -> `await PushNotifications.register()`; "
            "on the 'registration' event call the RPC below with the token; on 'pushNotificationReceived' show an in-app "
            "toast and refresh the inbox; on 'pushNotificationActionPerformed' open the inbox. Skip all of this when "
            "Capacitor is missing (browser preview)."
        ),
        "flutter": (
            "Push notifications (Firebase): add packages firebase_core and firebase_messaging (put them in DEPS). "
            "`import 'firebase_config.dart';` (it exists next to main.dart and defines `firebaseOptions`). In main(): "
            "`WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: firebaseOptions); "
            "FirebaseMessaging.onBackgroundMessage(_bg);` where `_bg` is a top-level `@pragma('vm:entry-point')` "
            "function that also calls Firebase.initializeApp(options: firebaseOptions). After sign-in: "
            "`await FirebaseMessaging.instance.requestPermission(); final t = await FirebaseMessaging.instance.getToken();` "
            "then call the RPC below; `FirebaseMessaging.onMessage.listen` shows a SnackBar and refreshes the inbox."
        ),
        "python": "",
    }[lang]
    return f"""
=== CONNECTED PAIR CONTRACT (follow exactly) ===
This is the {role.upper()} app of a pair; the {other} app is built separately against the SAME backend.

Backend: Supabase.
  SUPABASE_URL = "{url}"
  SUPABASE_ANON_KEY = "{anon}"
Call the REST API directly over HTTPS (no Supabase SDK):
  headers: apikey: SUPABASE_ANON_KEY, Authorization: Bearer <access_token of the signed-in user>,
           Content-Type: application/json, Prefer: return=representation (for insert/update)
  The key may be a publishable key (sb_publishable_...): send it ONLY as the apikey header, never as
  "Authorization: Bearer"; before sign-in send no Authorization header at all.
  read:   GET  {url}/rest/v1/<table>?select=*&<column>=eq.<value>&order=created_at.desc
  insert: POST {url}/rest/v1/<table>   update: PATCH {url}/rest/v1/<table>?id=eq.<id>   delete: DELETE …?id=eq.<id>
  rpc:    POST {url}/rest/v1/rpc/<function>  with a JSON body of named arguments

Sign-in with a 6-digit email code (no passwords), on a polished first screen:
  1. email field -> POST {url}/auth/v1/otp  body {{"email": email, "create_user": true}}  (headers: apikey only)
     then show a 6-digit code input with a resend button (60 s cooldown) and "check your inbox" text.
  2. POST {url}/auth/v1/verify  body {{"type": "email", "email": email, "token": code}}
     -> {{access_token, refresh_token, expires_in, user: {{id, email}}}}. Save the session on the device.
  3. When a request returns 401, refresh: POST {url}/auth/v1/token?grant_type=refresh_token body {{"refresh_token": rt}};
     if that fails, go back to sign-in. Provide sign out (forget the session).
  4. After sign-in read the profile: GET {p}_profiles?id=eq.<user.id>  (role is 'customer' or 'admin').
     {("The role comes from the app used to sign in: right after a successful sign-in (and at start-up with a saved "
       "session) the ADMIN app calls rpc " + p + "_claim_admin with an empty JSON body {} (user's token; returns true or "
       "false), then reads the profile again. If it is still not 'admin' (the owner set a secret admin PIN) show a "
       "'دخول الإدارة' screen: a hidden field 'رمز الإدارة', a button that calls rpc " + p + "_claim_admin "
       "{\"pin\": pin} and on true opens the admin home, on false shows 'رمز الإدارة غير صحيح', and a sign out button. "
       "The CUSTOMER app never calls it.") if role == "admin" else "Let the customer fill full_name and phone in a profile screen (PATCH " + p + "_profiles?id=eq.<id>)."}

Tables (all names start with {p}_; row level security already limits what each user can see):
{tables}
Also: {p}_profiles(id, email, full_name, phone, role) and
  {p}_notifications(id, to_user uuid, to_role 'customer'|'admin', title, body, data jsonb, created_by, read_at, created_at).

Notifications:
  - Inbox screen with an unread badge: {"GET " + p + "_notifications?or=(to_user.eq.<uid>,to_role.eq.admin)&order=created_at.desc" if role == "admin" else "GET " + p + "_notifications?or=(to_user.eq.<uid>,to_role.eq.customer)&order=created_at.desc"};
    mark read: PATCH {p}_notifications?id=eq.<id> body {{"read_at": "<now ISO>"}}.
  - Send one whenever an event from the contract happens in THIS app:
    POST {p}_notifications body {{"to_role": "admin", "title": …, "body": …, "data": {{…ids…}}}} (customer -> admins)
    or {{"to_user": "<customer uuid>", …}} (admin -> one customer). The backend delivers it as a push notification.
  - Register this device after sign-in: rpc {p}_register_device {{"device_token": token, "app_name": "{role}"}}.
  {push_rules if push else ("Push is not available here: refresh the inbox every 30 seconds while the app is open and show new ones as an in-app banner." if lang == "python" else "Push notifications are off for this pair: refresh the inbox when the app opens.")}

Build the complete {role} experience for this business with real screens backed by these tables
(the admin app manages everything and changes statuses; the customer app browses, creates and follows its own records).
"""


def cmd_generate(a):
    st = load_state(a.base)
    role, lang = a.role, st["lang"]
    name = st["apps"][role]["name"]
    title = "تطبيق الزبون" if role == "customer" else "تطبيق الإدارة"
    mine = "الزبون" if role == "customer" else "الإدارة"
    other = "الإدارة" if role == "customer" else "الزبون"
    scope = (f"\n(This is the {mine} app only: build every requirement marked «{mine}:» or «الاثنين:». "
             f"Items marked «{other}:» belong to the other app and are only context; do not build them here.)\n"
             if "=== المواصفات" in st["description"] else "")
    request = f"{title} لهذا المشروع:\n{st['description']}\n{scope}{contract_text(st, role)}"
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as f:
        related = f"@related: {st['apps']['customer']['name']}\n" if role == "admin" else ""
        f.write(f"{name}\n{related}{request}\n\n(request id: {int(time.time())})\n")
        req = f.name
    env = {**os.environ, "REQUEST_FILE": req}
    if lang == "html":
        subprocess.run(["node", str(ROOT / "generate.js")], cwd=ROOT, env=env, check=True)
    else:
        subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_native.py"), lang], cwd=ROOT, env=env, check=True)
    print(f"Generated {name}", flush=True)


def edit_rules(app):
    """Extra instructions for AI edits of one app of a pair, so an update never breaks the connection."""
    path = ROOT / "apps" / app / "pair.json"
    if not path.exists():
        return ""
    st = json.loads(path.read_text(encoding="utf-8"))
    return (
        "\nIMPORTANT: this app is one of a connected pair (customer + admin) that share a Supabase backend. "
        "Keep the backend URL and key, the email-code sign-in, the table and column names, the device "
        "registration and the notifications exactly as they work now, unless the requested change is about them. "
        "If the change needs data the other app also uses, use the existing tables.\n"
        + contract_text(st, st["role"])
    )


def main():
    if sys.argv[1:2] == ["contract"]:  # python scripts/pair.py contract APP -> edit rules for a pair app ("" otherwise)
        print(edit_rules(sys.argv[2]) if len(sys.argv) > 2 else "")
        return
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["backend", "auth", "firebase", "generate"])
    ap.add_argument("--base", required=True)
    ap.add_argument("--lang", default="html", choices=["html", "flutter", "python"])
    ap.add_argument("--admins", default="")
    ap.add_argument("--push", default="true")
    ap.add_argument("--description-file")
    ap.add_argument("--role", choices=list(ROLES))
    a = ap.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,30}", a.base):
        raise SystemExit("Project name: lowercase English letters, digits and -, starting with a letter")
    {"backend": cmd_backend, "auth": cmd_auth, "firebase": cmd_firebase, "generate": cmd_generate}[a.command](a)


if __name__ == "__main__":
    main()
