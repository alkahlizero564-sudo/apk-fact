"""Makes sure both apps of a connected pair are really connected: the pieces the contract asks for are in the code.

The AI sometimes writes only half of the connection (found in the almadrar pair: both apps sent notifications but
neither had an inbox that reads them, and neither asked Android 13+ for the notification permission, so the
phone blocked every push silently). This runs after a pair app is generated and before every build of one:
  1. sure fixes without AI (Flutter: ask for the notification permission before reading the push token);
  2. a check for every piece; what is missing is added by the AI following the pair contract;
  3. the result must still compile/check (Flutter analyze, Python check, HTML check), else it is not kept.

    python scripts/pair_wiring.py check APP   -> lists what is missing (exit 1 when something is)
    python scripts/pair_wiring.py fix APP     -> sure fixes, then AI for the rest (needs GEMINI_API_KEY)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

CODE_FILE = {"flutter": "lib/main.dart", "python": "main.py", "html": "index.html", "react": "index.html"}
FENCE = {"flutter": "dart", "python": "python", "html": "html", "react": "html"}


def state(app):
    p = ROOT / "apps" / app / "pair.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def code_path(app, st):
    return ROOT / "apps" / app / CODE_FILE[st["lang"]]


def uses_backend(app, st):
    """A Flutter pair app on the fixed lib/backend.dart (scripts/flutter_backend.py)."""
    return st["lang"] == "flutter" and (ROOT / "apps" / app / "lib" / "backend.dart").exists()


def backend_required(st):
    """What main.dart must call when the connection is lib/backend.dart."""
    import pair
    import flutter_backend
    role, mode = st["role"], pair.state_login(st)[st["role"]]
    req = [
        ("`import 'backend.dart';` at the top of main.dart — it is the app's only connection to the server",
         r"import\s+['\"]backend\.dart['\"]"),
        ("`await Backend.init();` in main() before runApp", r"Backend\.init\b"),
        ("MaterialApp(scaffoldMessengerKey: Backend.messengerKey, ...)", r"scaffoldMessengerKey:\s*Backend\.messengerKey"),
        ("`import 'auth_screens.dart';` and MaterialApp(home: AuthGate(brand: AuthBrand(...), home: <main screen>)) — "
         "the ready sign-in screens; no sign-in screens of its own", r"AuthGate\s*\("),
        ("a notifications inbox screen: LiveQuery with Backend.inbox(), tap -> Backend.markRead(id)",
         r"Backend\.inbox\b"),
        ("the unread badge on a bell: ValueListenableBuilder<int>(valueListenable: Backend.unread, ...)",
         r"Backend\.unread\b"),
        ("Backend.notify(toRole: ... / toUser: ...) after every write the other app must know about",
         r"Backend\.notify\b"),
        ("every list / record on screen through LiveQuery (live: refreshes every 15 s, on a push and after writes)",
         r"LiveQuery<"),
    ]
    if mode != "none":
        req.append(("a sign-out button: Backend.signOut()", r"Backend\.signOut\b"))
    if mode == "phone_password" and role == "admin":
        req.append(("'تغيير كلمة مرور زبون' (customer phone + new password): Backend.setCustomerPassword(phone, pw)",
                    r"Backend\.setCustomerPassword\b"))
    # Every table this app works with must really be read or written on its screens.
    personal = re.compile(r"favou?rite|wishlist|cart|bookmark", re.I)
    by_name = {t.get("name"): t for t in (st.get("contract") or {}).get("tables", [])}
    for dart, table in flutter_backend.table_consts(st)[2:]:
        t = by_name.get(table, {})
        owner = str(t.get("owner", "")).lower()
        if role == "customer" and owner == "admin":
            continue
        if role == "admin" and owner == "customer" and personal.search(table):
            continue
        req.append((f"real screens for {table} ({t.get('purpose', '')}): read it with Backend.list(T.{dart}) in a "
                    f"LiveQuery and write it with Backend.insert/update/delete(T.{dart}, ...) where this app changes it",
                    rf"\bT\.{dart}\b"))
    return req


# Things a backend.dart app must not do itself (the diala apps: data typed into the code, a sign-in that only set a
# flag, their own REST client with a cut key, buttons that do nothing).
OWN_SERVER = ("its own connection to the server: main.dart must NOT import package:http or contain a Supabase URL, "
              "key, /rest/v1 or /auth/v1 path; every call goes through Backend.* from backend.dart")
REDEFINED = ("a second copy of backend.dart / auth_screens.dart: do not define class Backend, T, LiveQuery, "
             "BackendException, AuthGate or AuthBrand in main.dart; import the files and use them")
FLAG_SIGNIN = ("a sign-in flag of its own (isLoggedIn / isAuthenticated / signedIn = true): the signed-in state is "
               "ONLY Backend.session / Backend.signedIn, set by a real Backend sign-in")
BACKEND_FORBIDDEN = [
    (OWN_SERVER, r"package:http/|/rest/v1|/auth/v1|supabase\.co"),
    (REDEFINED, r"(?m)^\s*class\s+(Backend|T|LiveQuery|BackendException|AuthGate|AuthBrand)\b"),
    (FLAG_SIGNIN, r"(?i)\b_?(is_?)?(logged_?in|signed_?in|authenticated|loggedin)\w*\s*=\s*true\b"),
]

# Business data typed into the code instead of read from the tables.
DATA_KEYS = re.compile(r"""['"](price|total|amount|qty|quantity|status|customer\w*|phone|email|stock|sales|balance|"""
                       r"""address|sku|rating|order\w*|date|created_at|cost|paid|due)['"]\s*:""", re.I)
MONEY = re.compile(r"""['"][^'"\n]*?\d[\d,٬.]*\s*(ج\.?\s?س|جنيه|SDG|EGP|ج\.م|ريال|ر\.س|درهم|دينار|USD|\$)[^'"\n]*['"]""")
EMPTY_ACTION = re.compile(r"(onPressed|onTap|onChanged|onSubmitted|onLongPress)\s*:\s*\([^)]*\)\s*(\{\s*\}|=>\s*(\{\s*\}|null))")


def _list_literals(code):
    """Yields the text of each list literal that starts with a map: [ {...}, ... ]."""
    for m in re.finditer(r"\[\s*(const\s*)?\{", code):
        depth, i = 0, m.start()
        while i < len(code):
            c = code[i]
            if c in "[{(":
                depth += 1
            elif c in "]})":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield code[m.start():i + 1]


def fake_data(code):
    """Descriptions of typed-in business data / dead buttons found in the code (empty when it is clean)."""
    gaps = []
    # Two or more maps carrying at least two different business fields (a status filter list has only 'status').
    lists = [l for l in _list_literals(code)
             if l.count("{") >= 2 and len({k.lower() for k in DATA_KEYS.findall(l)}) >= 2]
    if lists:
        first = next((x.strip() for x in lists[0].split("\n") if ":" in x), lists[0])[:80]
        gaps.append(f"business data typed into the code ({len(lists)} list(s), e.g. `{first}`): remove these lists; "
                    f"read the rows from the tables with Backend.list(...) in a LiveQuery (empty state when none)")
    money = sorted(set(m.group(0) for m in MONEY.finditer(code)))
    if money:
        gaps.append(f"made-up amounts written in the code ({', '.join(money[:4])}): every amount, price, fee and "
                    f"total must come from the tables (or be computed from their rows)")
    empty = EMPTY_ACTION.findall(code)
    if empty:
        gaps.append(f"{len(empty)} button(s)/field(s) with an empty action (onPressed: () {{}}): give each its real "
                    f"action (Backend insert/update/delete, navigation, a file picker) or remove it")
    return gaps


def required(st):
    """(description for the AI, regex that must match the code)."""
    p, lang, role = st["prefix"], st["lang"], st["role"]
    req = [
        (f"an in-app notifications inbox screen (with an unread badge) that READS {p}_notifications "
         f"(GET {p}_notifications?or=(to_user.eq.<uid>,to_role.eq.{role})&order=created_at.desc) and marks them read",
         rf"{p}_notifications\?"),
        (f"sending a notification (POST {p}_notifications with to_role / to_user) whenever an event of the contract "
         f"happens in this app",
         r"to_(role|user)"),
        # Live sync: both apps must re-fetch data on a short repeating interval, else a change in one app only
        # appears in the other on a manual refresh (the almadrar complaint: weak send/receive between the pair).
        ("keeping the two apps in sync: a repeating timer that, every ~15 seconds while signed in, re-fetches the "
         "notifications inbox AND the lists the current screen shows (cancelled on dispose / sign out) — so a record "
         "or a status change in one app appears in the other within seconds, not only on a manual refresh",
         {"flutter": r"Timer\.periodic\(\s*(?:const\s+)?Duration\(seconds:\s*(?!1\b)\d+",
          "html": r"setInterval\(",
          "react": r"setInterval\(",
          "python": r"(Timer\.periodic|run_task|asyncio\.sleep|threading\.Timer)"}[lang]),
    ]
    if role == "admin":
        req.append((f"after sign-in / session start, calling rpc {p}_claim_admin (and the admin PIN screen when it "
                    f"returns false)", rf"{p}_claim_admin"))
    import pair
    mode, fn = pair.state_login(st)[role], f"{p.replace('_', '-')}-auth"
    # (An old rule here required an is_admin_email check while ADMIN_OPEN below forbids it: no AI fix could ever
    # satisfy both, so shauager-admin and diala-admin always ended "still misses". The admin app is open.)
    if mode in pair.VIA_FUNCTION:
        req.append((f"the sign-up of the contract: POST <SUPABASE_URL>/functions/v1/{fn} with action \"signup\" "
                    f"(name, {'phone' if mode == 'phone_password' else 'email'}, password)", rf"{fn}"))
    if mode == "phone_password":
        req.append((f"signing in with the phone and the password: POST .../functions/v1/{fn} body "
                    "{\"action\": \"login\", \"phone\": phone, \"password\": password}", r"[\"']login[\"']"))
    if mode == "phone_email_code":
        req.append(("confirming the email with the 6-digit code: POST /auth/v1/verify with type \"signup\"",
                    r"auth/v1/verify"))
    if role == "admin" and pair.state_login(st)["customer"] == "phone_password":
        req.append((f"'تغيير كلمة مرور زبون' in the admin app: POST .../functions/v1/{fn} with action \"set_password\"",
                    r"set_password"))
    if st.get("push") and lang != "python":
        req.append((f"registering this device for push after sign-in: rpc {p}_register_device", rf"{p}_register_device"))
        if lang == "flutter":
            req.append(("asking for the notification permission (Android 13+) before reading the token: "
                        "await FirebaseMessaging.instance.requestPermission()", r"requestPermission\("))
            req.append(("showing a push that arrives while the app is open: FirebaseMessaging.onMessage.listen(...) "
                        "shows a SnackBar/banner and refreshes the inbox", r"onMessage\b"))
        if lang in ("html", "react"):
            req.append(("asking for the notification permission: PushNotifications.requestPermissions() before "
                        "PushNotifications.register()", r"requestPermissions\("))
    return req


# Things that must NOT be in a pair app. Found in almadrar: when the sign-in code was wrong or the request failed,
# the app signed in anyway ("demo fallback") with a random user id, and the admin app also made itself admin and
# sent "123456" when the code box was empty. Anyone could open the admin app; and with no real session every
# order and notification was silently refused by the database.
FAKE_SIGNIN = (
    "a fake / demo / offline sign-in: the app must NEVER count the user as signed in (or as admin) without a real "
    "access_token from Supabase. Remove every fallback that sets the user signed in, makes a random user id "
    "(Uuid().v4()) or sets admin after a failed or skipped verify/sign-in, and any default code like \"123456\". "
    "On failure show the server's error message in Arabic and stay on the same screen"
)
# The admin app must be OPEN: any email signs in and becomes admin (via claim_admin). The AI sometimes "helpfully"
# re-adds an email gate that blocks non-admin emails ("غير مخوّل") — that is forbidden; remove it.
ADMIN_OPEN = (
    "an admin email gate: the admin app must let ANY email sign in and become admin (via claim_admin). Remove every "
    "check that verifies the email is an admin before/after sign-in (any call to an is_admin_email RPC) and every "
    "«غير مخوّل لدخول الإدارة» / 'not authorized' refusal — sign in exactly like the customer app"
)
FORBIDDEN = [
    (FAKE_SIGNIN, r"(?i)(demo|offline|fallback)[^\n]{0,80}\n?[^\n]{0,200}(isAuthenticated|_isLoggedIn|loggedIn|signedIn)\s*=\s*true"),
    (FAKE_SIGNIN, r"(?i)(_?user_?id|uid)\s*=\s*(const\s+)?Uuid\(\)\.v4\(\)"),
    (FAKE_SIGNIN, r"[\"']123456[\"']"),
    (FAKE_SIGNIN, r"(?i)(demo|offline)\s*(mode|fallback)"),
    (ADMIN_OPEN, r"is_admin_email|مخوّل لدخول الإدارة"),
]


def missing(app):
    st = state(app)
    if not st:
        return []
    import flutter_multi
    if flutter_multi.is_multi(ROOT / "apps" / app):  # built screen by screen: the checks read every file
        code = flutter_multi.all_code(ROOT / "apps" / app)
    else:
        code = code_path(app, st).read_text(encoding="utf-8", errors="ignore")
    if uses_backend(app, st):
        gaps = [d for d, rx in backend_required(st) if not re.search(rx, code)]
        for d, rx in BACKEND_FORBIDDEN + FORBIDDEN:
            if re.search(rx, code) and d not in gaps:
                gaps.append(d)
        return gaps + fake_data(code)
    gaps = [d for d, rx in required(st) if not re.search(rx, code)]
    for d, rx in FORBIDDEN:
        if re.search(rx, code) and d not in gaps:
            gaps.append(d)
    return gaps


def sure_fixes(app):
    """Fixes that need no AI. Returns True when the code changed."""
    st = state(app)
    if not st or st["lang"] != "flutter":
        return False
    f = code_path(app, st)
    code = f.read_text(encoding="utf-8")
    if "requestPermission(" in code or "FirebaseMessaging.instance.getToken()" not in code:
        return False
    # The token line is inside an async function (it is awaited), so an await before it is valid.
    new, n = re.subn(
        r"\n([ \t]*)((?:final|var|String\??)\s+\w+\s*=\s*)?await\s+FirebaseMessaging\.instance\.getToken\(\)",
        lambda m: f"\n{m.group(1)}await FirebaseMessaging.instance.requestPermission(); // Android 13+ shows pushes only "
                  f"after this\n{m.group(1)}{m.group(2) or ''}await FirebaseMessaging.instance.getToken()",
        code, count=1)
    if n:
        f.write_text(new, encoding="utf-8")
        print(f"{app}: added the notification permission request (Android 13+)", flush=True)
    return bool(n)


def problems(app, st):
    """Compile/check errors of the code (empty when clean or when no checker is available here)."""
    f = code_path(app, st)
    if st["lang"] == "python":
        r = subprocess.run([sys.executable, str(HERE / "check_python.py"), str(f)], capture_output=True, text=True)
        return "" if r.returncode == 0 else (r.stdout + r.stderr)[-3000:]
    if st["lang"] in ("html", "react"):
        r = subprocess.run(["node", str(HERE / "check_html.js"), str(f)], capture_output=True, text=True)
        return "" if r.returncode == 0 else (r.stdout + r.stderr)[-3000:]
    import shutil
    if not shutil.which("flutter"):
        return ""
    # check_flutter.py needs a project made by `flutter create` (like generate_native.check_flutter_app); it also
    # gets two AI rounds to fix compile errors in the added code instead of throwing the addition away.
    with tempfile.TemporaryDirectory() as tmp:
        proj = Path(tmp) / "app"
        r = subprocess.run(["flutter", "create", "--platforms=android", "--project-name", "app_check", str(proj)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return ""  # cannot check here; the build analyzes the code anyway
        # Quick mode (a build): only analyze, no extra AI rounds; the build checks and fixes the code right after.
        r = subprocess.run([sys.executable, str(HERE / "check_flutter.py"), str(f.parent.parent), str(proj),
                            "--rounds", "0" if QUICK else "2"], capture_output=True, text=True, cwd=str(HERE))
        return "" if r.returncode == 0 else (r.stdout + r.stderr)[-3000:]


# PAIR_FIX_QUICK=1 (set by the build workflows): the generation already tried the AI completion, so a build gives it
# one short try instead of two long ones. Builds of pair apps waited 5-15 minutes here on exhausted or stuck Gemini
# keys before compiling for 2 minutes.
QUICK = os.environ.get("PAIR_FIX_QUICK") == "1"


def ai_complete(app, gaps):
    import pair
    from gemini_client import call_gemini
    from native_langs import gemini_keys, parse_reply, LANGS, rules_for

    st = state(app)
    f = code_path(app, st)
    keys = gemini_keys(os.environ)
    if not keys:
        print("No Gemini key: cannot add the missing pieces", flush=True)
        return False
    import flutter_multi as fm
    app_dir = ROOT / "apps" / app
    if fm.is_multi(app_dir):  # several files: send them all, take back only the changed ones
        before = fm.snapshot(app_dir)
        files, _ = fm.ask_files(
            lambda p: call_gemini(os.environ.get("GEMINI_MODEL") or "gemini-3.8-flash", p, keys, temperature=0.2,
                                  json_mode=False),
            f"This is the {st['role'].upper()} app of a connected pair. FIX these so it is complete and really "
            f"connected, exactly as the contract below says, wired into the existing screens; keep everything else:\n- "
            + "\n- ".join(gaps) + f"\n\n{rules_for(st['lang'])}\n\n{pair.contract_text(st, st['role'])}\n\n"
            f"THE APP'S FILES:\n{fm.bundle(before)}\n{fm.FILES_REPLY}")
        if not files:
            print("The AI reply had no file: not used", flush=True)
            return False
        fm.write(app_dir, files)
        errs = problems(app, st)
        if errs:
            print(f"The completed code does not check clean, keeping the previous version:\n{errs[-1500:]}", flush=True)
            fm.restore(app_dir, before)
            return False
        return True
    model = os.environ.get("GEMINI_MODEL") or "gemini-3.8-flash"
    fence = FENCE[st["lang"]]
    rules = rules_for(st["lang"]) if st["lang"] in LANGS else ""
    prompt = (
        f"This is the {st['role'].upper()} app of a connected pair (customer + admin on one Supabase backend). It "
        f"does not do everything the pair contract asks, so the two apps are not really connected. FIX these "
        f"exactly as the contract below says (add what is missing, remove what is forbidden), wired into the existing "
        f"screens and navigation, and keep everything else (screens, design, texts, data) as it is:\n- " + "\n- ".join(gaps) +
        f"\n\n{rules}\n\n{pair.contract_text(st, st['role'])}\n\n"
        f"Reply with exactly one ```{fence} code block with the complete updated file"
        + (" and a last line `DEPS: ` with the packages used, comma separated" if st["lang"] != "html" else "") +
        f".\n\nCURRENT FILE:\n```{fence}\n{f.read_text(encoding='utf-8')}\n```\n"
    )
    blocks, _ = parse_reply(call_gemini(model, prompt, keys, temperature=0.2, json_mode=False,
                                       max_rounds=1 if QUICK else 5))
    new = blocks.get(fence, "")
    if len(new) < len(f.read_text(encoding="utf-8")) * 0.6:
        print("The AI reply was empty or much shorter than the app: not used", flush=True)
        return False
    before = f.read_text(encoding="utf-8")
    f.write_text(new.rstrip() + "\n", encoding="utf-8")
    sure_fixes(app)
    errs = problems(app, st)
    if errs:
        print(f"The completed code does not check clean, keeping the previous version:\n{errs[-1500:]}", flush=True)
        f.write_text(before, encoding="utf-8")
        return False
    return True


def fix(app, strict=False):
    """strict (generation): an app that still misses pieces after the AI tries is refused (exit 1), so it is never
    saved and handed over as if it worked."""
    st = state(app)
    if not st:
        print(f"{app} is not part of a connected pair")
        return 0
    sure_fixes(app)
    gaps = missing(app)
    if not gaps:
        print(f"{app}: connected — every piece of the pair contract is in the code", flush=True)
        return 0
    print(f"{app}: missing pieces of the connection:\n- " + "\n- ".join(gaps), flush=True)
    for attempt in range(1 if QUICK else 2):
        try:
            ai_complete(app, gaps)
        except (Exception, SystemExit) as e:
            print(f"Could not add them ({e})", flush=True)
        gaps = missing(app)
        if not gaps:
            print(f"{app}: connected now", flush=True)
            return 0
    if strict:
        print(f"::error::{app} is not a complete working app yet, so it was not saved. Still missing:\n- "
              + "\n- ".join(gaps), flush=True)
        raise SystemExit(f"التطبيق {app} لسه ناقص، فما اتحفظ عشان ما يوصلك تطبيق شكله جاهز وهو ما شغال. "
                         f"الناقص: " + "؛ ".join(g.split(":")[0] for g in gaps[:6]))
    print(f"::warning::{app} still misses: " + "; ".join(gaps), flush=True)
    return 0  # a build never fails here


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if not a or not re.fullmatch(r"[a-z0-9-]+", a[0]):
        raise SystemExit(__doc__)
    if cmd == "check":
        gaps = missing(a[0])
        print("\n".join(gaps) or "connected")
        raise SystemExit(1 if gaps else 0)
    if cmd == "fix":
        raise SystemExit(fix(a[0]))
    raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
