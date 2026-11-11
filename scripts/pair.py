"""Create a pair of connected apps (customer + admin) on Supabase, with the sign-in the owner chose, and push.

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
    # A new pair always starts with the default package names (Firebase registers the apps under them).
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


# The owner decides sign-in in the description (same rules as services/login.ts). APK Fact adds the apps the owner
# picked as "LOGIN: customer=<mode> admin=<mode>". The sheet offers: phone_password (name + phone + password),
# phone_email_code (name + phone + email + email code + password), email_password (name + email + password), none.
# code, password and password_code are the modes of pairs made before.
MODES = ("none", "phone_password", "phone_email_code", "email_password", "code", "password", "password_code")
SENDS_EMAIL = {"code", "password_code", "phone_email_code"}  # needs working SMTP
VIA_FUNCTION = {"phone_password", "email_password"}  # accounts made by the <p>-auth Edge Function
LOGIN_NO = re.compile(r"(بدون|بلا|من غير|ما في|مافي|ما يحتاج|لا يحتاج|مش محتاج|ما فيه|without|no)\s+(أي\s+|اي\s+)?(تسجيل|login|log in|sign)", re.I)
LOGIN_YES = re.compile(r"تسجيل\s*(ال)?دخول|دخول\s*(بال)?(بريد|ايميل|إيميل)|login|log ?in|sign ?in|sign ?up|إنشاء حساب|انشاء حساب|"
                       r"حساب جديد|كلم[ةه]\s*(ال)?(مرور|سر)|password|رمز\s*(ال)?تحقق|\botp\b", re.I)
LOGIN_PASSWORD = re.compile(r"كلم[ةه]\s*(ال)?(مرور|سر)|باسورد|password", re.I)
LOGIN_CODE = re.compile(r"(رمز|كود)\s*(ال)?(تحقق|تأكيد|دخول)|(رمز|كود)\s*من\s*(6|٦|ستة|سته)|(رمز|كود)\s*(يوصل|يجي|بالبريد|على البريد)|"
                        r"\botp\b|verification code|one.time code", re.I)


def login_from_text(text):
    text = text or ""
    if LOGIN_NO.search(text) or not LOGIN_YES.search(text):
        return "none"
    pwd, code = bool(LOGIN_PASSWORD.search(text)), bool(LOGIN_CODE.search(text))
    return "password_code" if pwd and code else "password" if pwd else "code"


def login_modes(text):
    """{"customer": mode, "admin": mode} from the LOGIN line, else the same mode for both apps from the words."""
    m = re.search(r"^LOGIN:(.*)$", text or "", re.M)
    if m:
        pairs = dict(re.findall(r"(customer|admin)=(\w+)", m.group(1)))
        if pairs:
            return {r: pairs.get(r) if pairs.get(r) in MODES else "none" for r in ROLES}
        one = m.group(1).strip()
        mode = "code" if one == "email" else one if one in MODES else "none"
        return {r: mode for r in ROLES}
    mode = login_from_text(text)
    return {r: mode for r in ROLES}


def state_login(st):
    """Sign-in of each app; pairs created before this choice existed use email codes."""
    v = st.get("login")
    if isinstance(v, dict):
        return {r: v.get(r, "code") for r in ROLES}
    return {r: ("none" if v == "none" else "code") for r in ROLES}


def cmd_backend(a):
    ref, token = need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN")
    description = Path(a.description_file).read_text(encoding="utf-8").strip()
    p = sb.prefix_of(a.base)
    login = login_modes(description)
    admins = [e.strip() for e in a.admins.split(",") if "@" in e]
    if login["admin"] not in ("none", "phone_password") and not admins:
        raise SystemExit("Add at least one admin email")
    print(f"Sign-in: customer app {login['customer']}, admin app {login['admin']}"
          + (" (admin app opens with the admin PIN)" if login["admin"] in ("none", "phone_password") else ""), flush=True)
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
        "admins": admins, "description": description, "login": login,
        "supabase": {"url": url, "anonKey": anon, "ref": ref},
        "schemaSql": sql, "contract": contract,
        "apps": {r: {"name": app_name(a.base, r), "packageId": package_id(app_name(a.base, r), a.lang)} for r in ROLES},
    })
    print(f"Backend ready: {len(tables)} business tables for {p}", flush=True)


def cmd_auth(a):
    ref, token = need("SUPABASE_PROJECT_REF"), need("SUPABASE_ACCESS_TOKEN")
    st = load_state(a.base)
    login = state_login(st)
    modes = set(login.values())
    if "none" in modes:
        sb.configure_anonymous(ref, token)
        print("Apps without sign-in: each install gets an invisible account", flush=True)
    if modes == {"none"}:
        return
    smtp = sb.env_smtp()
    if modes & SENDS_EMAIL:
        # The apps send emails (codes): check now that the mail server accepts the login, not when a customer tries.
        if not smtp:
            print("::warning::No custom SMTP set: Supabase's built-in mailer sends only a few emails per hour and only "
                  "to your team's addresses. Add SMTP in APK Fact > الإعدادات > Supabase for real customers.")
        else:
            check_smtp(smtp)
    # Only an app that confirms the email with a code needs confirmation on; the other accounts are made confirmed
    # by the <p>-auth function.
    sb.configure_email_otp(ref, token, smtp, autoconfirm=modes.isdisjoint(SENDS_EMAIL))
    if modes & VIA_FUNCTION:
        deploy_auth(st, ref)
        save_state(a.base, st)
        auth_selftest(st)
    print("Sign-in is on: " + ", ".join(f"{r} {m}" for r, m in login.items()), flush=True)


def check_smtp(smtp):
    """Logs in to the mail server with the saved SMTP settings (sends nothing). A wrong app password otherwise
    shows up only when a customer waits for a code that never comes."""
    import smtplib
    import ssl
    host, port = smtp["host"], int(smtp.get("port") or 587)
    pwd = str(smtp.get("pass", "")).replace(" ", "") if "gmail" in host else smtp.get("pass", "")
    try:
        if port == 465:
            s = smtplib.SMTP_SSL(host, port, timeout=30, context=ssl.create_default_context())
        else:
            s = smtplib.SMTP(host, port, timeout=30)
            s.starttls(context=ssl.create_default_context())
        s.login(smtp.get("user", ""), pwd)
        s.quit()
        print(f"Mail server OK: {host} accepts the login of {smtp.get('user', '')}", flush=True)
    except smtplib.SMTPAuthenticationError as e:
        raise SystemExit(
            f"The mail server {host} refused the SMTP login ({e.smtp_code}): the email codes would never arrive. "
            "For Gmail use an App Password (Google account > Security > 2-Step Verification > App passwords), "
            "then save it in APK Fact > الإعدادات > Supabase > SMTP and create the pair again.")
    except Exception as e:  # network errors: do not block, but say it
        print(f"::warning::Could not check the mail server {host}:{port} ({e})", flush=True)


def deploy_auth(st, ref):
    """Deploys the pair's <p>-auth Edge Function (accounts with a phone or an email and a password, no code)."""
    p = st["prefix"]
    modes = set(state_login(st).values())
    fn = f"{p.replace('_', '-')}-auth"
    src = ((ROOT / "scripts" / "templates" / "auth_function.ts").read_text(encoding="utf-8")
           .replace("__PREFIX__", p)
           .replace("__ALLOW_PHONE__", "true" if "phone_password" in modes else "false")
           .replace("__ALLOW_EMAIL__", "true" if "email_password" in modes else "false"))
    with tempfile.TemporaryDirectory() as tmp:
        fdir = Path(tmp) / "supabase" / "functions" / fn
        fdir.mkdir(parents=True)
        (fdir / "index.ts").write_text(src, encoding="utf-8")
        print(f"Deploying the {fn} Edge Function (sign-up and sign-in)…", flush=True)
        supabase_cli(["functions", "deploy", fn, "--project-ref", ref, "--no-verify-jwt", "--use-api"], cwd=tmp)
    st["authFunction"] = fn


def _post(url, body, headers):
    req = urllib.request.Request(url, method="POST", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw or "{}")
        except ValueError:
            return e.code, {"error": raw[:300]}


def auth_selftest(st):
    """Makes a test account the way the apps will (sign-up, then sign-in), then removes it. A broken sign-in stops
    here, before the apps reach a customer."""
    p, url, anon = st["prefix"], st["supabase"]["url"], st["supabase"]["anonKey"]
    fn = f"{url}/functions/v1/{st['authFunction']}"
    modes = set(state_login(st).values())
    hdr = {"apikey": anon}
    tag = secrets.token_hex(4)
    tests = []
    if "phone_password" in modes:
        tests.append(("phone", {"full_name": "APK Fact test", "phone": "00999" + str(int(tag, 16))[:8].rjust(8, "0")}))
    if "email_password" in modes:
        tests.append(("email", {"full_name": "APK Fact test", "email": f"apkfact-test-{tag}@example.com"}))
    for kind, who in tests:
        pwd = secrets.token_urlsafe(12)
        status, out = 0, {}
        for attempt in range(6):  # a just-deployed function can take a few seconds to answer
            status, out = _post(fn, {"action": "signup", "password": pwd, **who}, hdr)
            if status not in (404, 502, 503, 546):
                break
            time.sleep(5)
        if status != 200:
            raise SystemExit(f"Sign-in self-test failed: sign-up with {kind} -> {status} {out}")
        if kind == "phone":
            status, out = _post(fn, {"action": "login", "phone": who["phone"], "password": pwd}, hdr)
        else:
            status, out = _post(f"{url}/auth/v1/token?grant_type=password", {"email": who["email"], "password": pwd}, hdr)
        uid = (out.get("user") or {}).get("id")
        if uid:
            run_sql(f"delete from auth.users where id = '{uid}';")
        if status != 200 or not out.get("access_token"):
            raise SystemExit(f"Sign-in self-test failed: sign-in with {kind} -> {status} {out}")
        print(f"Sign-in self-test OK: an account with {kind} + password signs up and signs in", flush=True)


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


def supabase_cli(args, cwd):
    """Runs the Supabase CLI without questions. Newer versions ask for a confirmation that CI cannot give
    ("Re-run with --yes"); older ones do not know --yes. Try with it, and without it if it is unknown."""
    r = subprocess.run(["supabase", *args, "--yes"], cwd=cwd, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 and re.search(r"unknown (flag|shorthand flag).*yes", out):
        r = subprocess.run(["supabase", *args], cwd=cwd, capture_output=True, text=True)
        out = (r.stdout or "") + (r.stderr or "")
    print(out.strip(), flush=True)
    if r.returncode != 0:
        raise SystemExit(f"supabase {' '.join(args[:2])} failed (exit {r.returncode})")


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

    deploy_push(st, ref, token, sa)
    save_state(a.base, st)
    print("Push notifications are connected", flush=True)


def deploy_push(st, ref, token, sa):
    """Deploys (or redeploys) the pair's push Edge Function, its secrets and the database trigger."""
    p = st["prefix"]
    fn = f"{p.replace('_', '-')}-push"
    secret = secrets.token_urlsafe(32)
    with tempfile.TemporaryDirectory() as tmp:
        fdir = Path(tmp) / "supabase" / "functions" / fn
        fdir.mkdir(parents=True)
        src = (ROOT / "scripts" / "templates" / "push_function.ts").read_text(encoding="utf-8")
        (fdir / "index.ts").write_text(src.replace("__PREFIX__", p), encoding="utf-8")
        print("Saving the notification secrets in Supabase…", flush=True)
        sb.set_function_secrets(ref, token, {"FIREBASE_SERVICE_ACCOUNT": json.dumps(sa), f"PUSH_SECRET_{p.upper()}": secret})
        print(f"Deploying the {fn} Edge Function…", flush=True)
        supabase_cli(["functions", "deploy", fn, "--project-ref", ref, "--no-verify-jwt", "--use-api"], cwd=tmp)
    run_sql("create extension if not exists pg_net;\n" +
            sb.push_sql(p, f"{st['supabase']['url']}/functions/v1/{fn}", secret))
    st["pushFunction"] = fn


def cmd_push(a):
    """Redeploy the push function of an existing pair (after a fix to scripts/templates/push_function.ts)."""
    st = load_state(a.base)
    if not st.get("push"):
        raise SystemExit("Notifications are off for this pair")
    ref = st["supabase"]["ref"]
    os.environ["SUPABASE_PROJECT_REF"] = ref  # run_sql() works on the pair's own project
    token = need("SUPABASE_ACCESS_TOKEN")
    sa = json.loads(need("FIREBASE_SERVICE_ACCOUNT"))
    deploy_push(st, ref, token, sa)
    print(f"Push function of {a.base} redeployed in project {ref}", flush=True)


# ---------------- generate ----------------

NO_FAKE_SIGNIN = (
    "\n  NEVER fake the sign-in: no demo, offline or fallback mode. The user counts as signed in ONLY with a real "
    "access_token returned by Supabase; never make a random user id, never set signed-in or admin after a failed or "
    "skipped request, never use a default code. When a request fails, stay on the same screen and show a message "
    "that matches WHICH request failed: a failed send of a code (otp / signup / resend / recover) is NEVER 'wrong "
    "code' — 'rate limit' means 'اتبعتت رسائل كتير، استنى دقايق', 'sending' / 'smtp' means 'ما قدرنا نرسل البريد'; "
    "only a failed verify means a wrong or expired code; otherwise show the server's own message (its error, msg, "
    "message or error_description field)."
)


def signin_rules(st, role):
    """How THIS app signs in: the mode the owner picked for it (none, code, password, password_code)."""
    return _signin_rules(st, role) + NO_FAKE_SIGNIN


def _signin_rules(st, role):
    p, url = st["prefix"], st["supabase"]["url"]
    mode = state_login(st)[role]
    refresh = (f"When a request returns 401, refresh: POST {url}/auth/v1/token?grant_type=refresh_token body "
               '{"refresh_token": rt}; ')
    if role == "admin":
        after = ("ADMIN LOGIN IS OPEN: ANY email may sign in to the admin app and becomes an admin. Sign in exactly "
                 "like the customer app — do NOT check whether the email belongs to an admin, NEVER call an "
                 f"is_admin_email RPC, and NEVER show a 'not authorized' / «غير مخوّل» message or block any email. "
                 "Right after the session is ready (and at start-up with a saved session) the ADMIN app calls rpc "
                 f"{p}_claim_admin with an empty JSON body {{}} (user's token; returns true or false), then reads the "
                 "profile again. If it is still not 'admin' (only happens when the owner set a secret PIN), show a "
                 f"'دخول الإدارة' screen with a hidden field 'رمز الإدارة' and a button that calls rpc {p}_claim_admin "
                 "{\"pin\": pin}; on true open the admin home (and never ask again on this device), on false show "
                 "'رمز الإدارة غير صحيح'.")
    else:
        after = ("The CUSTOMER app never calls " + p + "_claim_admin. " +
                 ("When the customer creates a record that needs their name or phone, ask for them in that form and keep "
                  f"them with PATCH {p}_profiles?id=eq.<id> so they are filled in next time." if mode == "none" else
                  f"Let the customer fill full_name and phone in a profile screen (PATCH {p}_profiles?id=eq.<id>)."))
    if role == "admin" and state_login(st)["customer"] == "phone_password":
        after += (f" Customers sign in with their phone and there is no SMS, so the admin app has 'تغيير كلمة مرور زبون' "
                  f"(phone + new password) -> POST {url}/functions/v1/{p.replace('_', '-')}-auth body "
                  '{"action": "set_password", "phone": phone, "password": new} with the admin\'s access token.')
    profile = f"Read the profile: GET {p}_profiles?id=eq.<user.id>  (role is 'customer' or 'admin'). {after}"
    session = "-> {access_token, refresh_token, expires_in, user: {id, email}}. Save the session on the device."
    if mode == "none":
        return (
            "No sign-in screen in THIS app: the owner did not ask for one, so never show email, password, code or account screens.\n"
            f"  1. On first launch create an invisible session: POST {url}/auth/v1/signup  body {{}}  (headers: apikey only)\n"
            "     -> {access_token, refresh_token, expires_in, user: {id}}. Save it on the device and reuse it on every launch.\n"
            f"  2. {refresh}if that fails, create a new invisible session as in step 1.\n"
            f"  3. {profile}\n"
            "  Wherever these rules say 'after sign-in', it means 'after the session is ready'.")
    fn = f"{url}/functions/v1/{p.replace('_', '-')}-auth"
    fields = ("Sign-up fields (Arabic labels, a clear error under each wrong field): الاسم الكامل (required), ")
    pwd_rule = "كلمة المرور (6+ characters, with show/hide) and تأكيد كلمة المرور (must match)"
    if mode == "phone_password":
        return (
            "Sign-in with the name, the PHONE NUMBER and a password (no email anywhere, no codes), on polished screens:\n"
            f"  1. 'حساب جديد': {fields}رقم الهاتف (phone keyboard, required), {pwd_rule} -> POST {fn} body "
            '{"action": "signup", "full_name": name, "phone": phone, "password": password} (headers: apikey only) '
            "-> {\"ok\": true}; then sign in right away with step 2 using the same phone and password.\n"
            f"  2. 'تسجيل الدخول': رقم الهاتف + كلمة المرور -> POST {fn} body "
            '{"action": "login", "phone": phone, "password": password} (headers: apikey only) '
            f"{session}\n"
            "  Errors of these two calls come as {\"error\": \"<Arabic message>\"}: show that text as it is.\n"
            "  3. 'نسيت كلمة المرور؟': there is no SMS; show 'تواصل مع الإدارة عشان تغيّر كلمة المرور' (the admin app can set "
            "a new one).\n"
            f"  4. {refresh}if that fails, go back to sign-in. Provide sign out (forget the session).\n"
            f"  5. After sign-in: {profile} Show the name and phone from the profile.")
    if mode == "email_password":
        return (
            "Sign-in with the name, the EMAIL and a password (no codes), on polished screens:\n"
            f"  1. 'حساب جديد': {fields}البريد الإلكتروني (required), {pwd_rule} -> POST {fn} body "
            '{"action": "signup", "full_name": name, "email": email, "password": password} (headers: apikey only) '
            "-> {\"ok\": true} (errors come as {\"error\": \"<Arabic message>\"}: show it as it is); then sign in right "
            "away with step 2.\n"
            f"  2. 'تسجيل الدخول': POST {url}/auth/v1/token?grant_type=password body {{\"email\": email, \"password\": "
            f"password}} {session}\n"
            f"  3. 'نسيت كلمة المرور': POST {url}/auth/v1/recover body {{\"email\": email}}, then a 6-digit code input -> "
            f"POST {url}/auth/v1/verify body {{\"type\": \"recovery\", \"email\": email, \"token\": code}} (gives a "
            f"session), then a new password -> PUT {url}/auth/v1/user body {{\"password\": new}} with the session token.\n"
            f"  4. {refresh}if that fails, go back to sign-in. Provide sign out (forget the session).\n"
            f"  5. After sign-in: {profile}")
    if mode == "phone_email_code":
        return (
            "Sign-in with the name, the phone, the EMAIL confirmed by a 6-digit code, and a password (polished screens):\n"
            f"  1. 'حساب جديد': {fields}رقم الهاتف (required), البريد الإلكتروني (required), {pwd_rule} -> POST "
            f"{url}/auth/v1/signup body {{\"email\": email, \"password\": password, \"data\": {{\"full_name\": name, "
            "\"phone\": phone}} (headers: apikey only).\n"
            "     Then a 6-digit code screen ('بعتنا رمز على بريدك'; resend after 60 s: POST "
            f"{url}/auth/v1/resend body {{\"type\": \"signup\", \"email\": email}}) -> POST {url}/auth/v1/verify body "
            f"{{\"type\": \"signup\", \"email\": email, \"token\": code}} {session}\n"
            f"  2. 'تسجيل الدخول': البريد + كلمة المرور -> POST {url}/auth/v1/token?grant_type=password body "
            f"{{\"email\": email, \"password\": password}} {session} If the error says the email is not confirmed, "
            "resend the code and open the code screen.\n"
            f"  3. 'نسيت كلمة المرور': POST {url}/auth/v1/recover body {{\"email\": email}}, then a 6-digit code input -> "
            f"POST {url}/auth/v1/verify body {{\"type\": \"recovery\", \"email\": email, \"token\": code}} (gives a "
            f"session), then a new password -> PUT {url}/auth/v1/user body {{\"password\": new}} with the session token.\n"
            f"  4. {refresh}if that fails, go back to sign-in. Provide sign out (forget the session).\n"
            f"  5. After sign-in: {profile}")
    if mode == "code":
        return (
            "Sign-in with the email and a 6-digit code (no passwords), on a polished first screen:\n"
            f"  1. email field -> POST {url}/auth/v1/otp  body {{\"email\": email, \"create_user\": true}}  (headers: apikey only)\n"
            "     then show a 6-digit code input with a resend button (60 s cooldown) and 'check your inbox' text.\n"
            f"  2. POST {url}/auth/v1/verify  body {{\"type\": \"email\", \"email\": email, \"token\": code}}\n"
            f"     {session}\n"
            f"  3. {refresh}if that fails, go back to sign-in. Provide sign out (forget the session).\n"
            f"  4. After sign-in: {profile}")
    confirm = mode == "password_code"
    return (
        "Sign-in with the email and a password (polished screens; Arabic messages under each wrong field):\n"
        f"  1. 'حساب جديد': email, password (6+ characters, with show/hide), confirm password -> POST {url}/auth/v1/signup "
        "body {\"email\": email, \"password\": password}  (headers: apikey only).\n"
        + (f"     The owner wants the email confirmed with a code: show a 6-digit code input (resend after 60 s: POST "
           f"{url}/auth/v1/resend body {{\"type\": \"signup\", \"email\": email}}), then POST {url}/auth/v1/verify body "
           f"{{\"type\": \"signup\", \"email\": email, \"token\": code}} {session}\n"
           if confirm else
           f"     The reply already has the session (no email code): {session}\n"
           "     If the reply has no access_token, sign in right away with step 2.\n")
        + f"  2. 'تسجيل الدخول': POST {url}/auth/v1/token?grant_type=password body {{\"email\": email, \"password\": password}} "
        f"{session}" + (" If the error says the email is not confirmed, resend the code and open the code screen." if confirm else "")
        + "\n"
        f"  3. 'نسيت كلمة المرور': POST {url}/auth/v1/recover body {{\"email\": email}}, then a 6-digit code input -> POST "
        f"{url}/auth/v1/verify body {{\"type\": \"recovery\", \"email\": email, \"token\": code}} (gives a session), then a "
        f"new password -> PUT {url}/auth/v1/user body {{\"password\": new}} with the session token.\n"
        f"  4. {refresh}if that fails, go back to sign-in. Provide sign out (forget the session).\n"
        f"  5. After sign-in: {profile}")


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
            "toast and re-fetch BOTH the inbox and the data of the current screen; on 'pushNotificationActionPerformed' "
            "open the inbox. Skip all of this when Capacitor is missing (browser preview)."
        ),
        "flutter": (
            "Push notifications (Firebase): add packages firebase_core and firebase_messaging (put them in DEPS). "
            "`import 'firebase_config.dart';` (it exists next to main.dart and defines `firebaseOptions`). In main(): "
            "`WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: firebaseOptions); "
            "FirebaseMessaging.onBackgroundMessage(_bg);` where `_bg` is a top-level `@pragma('vm:entry-point')` "
            "function that also calls Firebase.initializeApp(options: firebaseOptions). After sign-in: "
            "`await FirebaseMessaging.instance.requestPermission(); final t = await FirebaseMessaging.instance.getToken();` "
            "then call the RPC below; `FirebaseMessaging.onMessage.listen` shows a SnackBar and re-fetches BOTH the inbox "
            "and the data of the current screen (the status/record it is about), so the change shows at once."
        ),
        "python": "",
    }[("html" if lang == "react" else lang)]  # React ships as a Capacitor/JS app, same as HTML
    signin = signin_rules(st, role)
    live_hint = {
        "flutter": "start a Timer.periodic(const Duration(seconds: 15), ...) after sign-in, in a StatefulWidget, and "
                   "cancel it in dispose() and on sign out; also refresh in didChangeAppLifecycleState when the app "
                   "resumes (WidgetsBindingObserver)",
        "html": "use setInterval(..., 15000) while signed in (store the id and clearInterval it on sign out) — in React, "
                "from a useEffect that returns the clearInterval — and also refresh on the 'visibilitychange'/'focus' "
                "event when the page comes back to the foreground",
        "python": "run a repeating refresh (e.g. page.run_task with asyncio.sleep(15) in a loop, or threading.Timer) "
                  "while signed in, and stop it on sign out",
    }[("html" if lang == "react" else lang)]
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

{signin}

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

Live data — the two apps MUST stay in sync; this is the whole point of a connected pair:
  - Always read from the backend, never trust a stale local copy: right after every insert/update/delete THIS app
    makes, re-read the affected list so the screen shows the saved server state, not a guess.
  - A repeating sync while the app is open and signed in: every 15 seconds re-fetch the notifications inbox AND the
    list(s) the CURRENT screen shows. To do that, {live_hint}.
  - When a notification arrives, refresh the data of the current screen too, not only the inbox (see Notifications).
  So the admin sees a new customer record, and the customer sees the admin's status change, within seconds and
  without anyone pressing refresh. Keep each refresh quiet (no full-screen spinner, no flicker, keep scroll position).

Build the complete {role} experience for this business with real screens backed by these tables
(the admin app manages everything and changes statuses; the customer app browses, creates and follows its own records).
"""


def for_app(text, role):
    """The description for one app of the pair: without the other app's items («الزبون:» / «الإدارة:»), and
    without LOGIN (the contract has the sign-in rules). Same rules as forApp() in services/understand.ts."""
    other = "الإدارة" if role == "customer" else "الزبون"
    keep = [l for l in (text or "").split("\n")
            if not re.match(r"^\s*LOGIN:", l) and not re.match(rf"^\s*-\s*«?\s*{other}\s*(:\s*»|»\s*:|:)", l)]
    return "\n".join(keep).strip()


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
    request = f"{title} لهذا المشروع:\n{for_app(st['description'], role)}\n{scope}{contract_text(st, role)}"
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as f:
        related = f"@related: {st['apps']['customer']['name']}\n" if role == "admin" else ""
        f.write(f"{name}\n{related}{request}\n\n(request id: {int(time.time())})\n")
        req = f.name
    env = {**os.environ, "REQUEST_FILE": req}
    if lang in ("html", "react"):
        # React, like HTML, is one self-contained index.html built by generate.js (React via CDN).
        if lang == "react":
            env["GEN_FRAMEWORK"] = "react"
        subprocess.run(["node", str(ROOT / "generate.js")], cwd=ROOT, env=env, check=True)
    else:
        subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_native.py"), lang], cwd=ROOT, env=env, check=True)
    print(f"Generated {name}", flush=True)
    # The two apps must really be connected: every piece of the contract in the code (scripts/pair_wiring.py).
    import pair_wiring
    pair_wiring.fix(name)


def edit_rules(app):
    """Extra instructions for AI edits of one app of a pair, so an update never breaks the connection."""
    path = ROOT / "apps" / app / "pair.json"
    if not path.exists():
        return ""
    st = json.loads(path.read_text(encoding="utf-8"))
    return (
        "\nIMPORTANT: this app is one of a connected pair (customer + admin) that share a Supabase backend. "
        "Keep the backend URL and key, the sign-in (or no sign-in) as it is, the table and column names, the device "
        "registration and the notifications exactly as they work now, unless the requested change is about them. "
        "If the change needs data the other app also uses, use the existing tables.\n"
        + contract_text(st, st["role"])
    )


def main():
    if sys.argv[1:2] == ["contract"]:  # python scripts/pair.py contract APP -> edit rules for a pair app ("" otherwise)
        print(edit_rules(sys.argv[2]) if len(sys.argv) > 2 else "")
        return
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["backend", "auth", "firebase", "generate", "push"])
    ap.add_argument("--base", required=True)
    ap.add_argument("--lang", default="html", choices=["html", "react", "flutter", "python"])
    ap.add_argument("--admins", default="")
    ap.add_argument("--push", default="true")
    ap.add_argument("--description-file")
    ap.add_argument("--role", choices=list(ROLES))
    a = ap.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,30}", a.base):
        raise SystemExit("Project name: lowercase English letters, digits and -, starting with a letter")
    {"backend": cmd_backend, "auth": cmd_auth, "firebase": cmd_firebase, "generate": cmd_generate, "push": cmd_push}[a.command](a)


if __name__ == "__main__":
    main()
