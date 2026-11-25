"""Writes lib/backend.dart into a Flutter app of a connected pair (from scripts/templates/backend.dart).

The AI used to write the whole connection by hand in every app (sign-in, session, REST calls, inbox, push, sync):
2000+ lines in one go, and it often came out as a moving copy of the design with data typed into the code, a
sign-in that only flipped a flag and a cut Supabase key (the diala pair). Now that part is this one fixed, tested
file; the AI writes the screens and calls it (API: api_doc()).

    python scripts/flutter_backend.py APP   -> writes apps/APP/lib/backend.dart
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
TEMPLATE = HERE / "templates" / "backend.dart"


def bucket(prefix):
    return prefix.replace("_", "-") + "-files"


def table_consts(st):
    """(dart name, table) for every table of the pair: T.products -> '<p>_products'."""
    p = st["prefix"]
    names = [str(t.get("name", "")) for t in (st.get("contract") or {}).get("tables", [])]
    out, seen = [("profiles", f"{p}_profiles"), ("notifications", f"{p}_notifications")], {"profiles", "notifications"}
    for full in names:
        if not full.startswith(p + "_"):
            continue
        short = full[len(p) + 1:]
        parts = [x for x in re.split(r"[^a-z0-9]+", short.lower()) if x]
        if not parts:
            continue
        dart = parts[0] + "".join(x.capitalize() for x in parts[1:])
        if dart[0].isdigit() or dart in seen or dart in ("new", "class", "default", "in", "is", "do", "if"):
            dart = "t" + dart[0].upper() + dart[1:]
        seen.add(dart)
        out.append((dart, full))
    return out


def render(st, role):
    import pair
    p = st["prefix"]
    src = TEMPLATE.read_text(encoding="utf-8")
    if not (st.get("push") and st["lang"] == "flutter"):
        src = re.sub(r"[ \t]*// @push-begin\n.*?// @push-end\n", "", src, flags=re.S)
    else:
        src = re.sub(r"[ \t]*// @push-(begin|end)\n", "", src)
    tables = "\n".join(f"  static const String {d} = '{t}';" for d, t in table_consts(st))
    def q(v):
        return str(v).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    for k, v in {
        "__URL__": q(st["supabase"]["url"]),
        "__ANON__": q(st["supabase"]["anonKey"]),
        "__PREFIX__": q(p),
        "__ROLE__": role,
        "__MODE__": pair.state_login(st)[role],
        "__AUTH_FN__": p.replace("_", "-") + "-auth",
        "__BUCKET__": bucket(p),
        "__TABLES__": tables,
    }.items():
        src = src.replace(k, v)
    return src


def write(app):
    d = ROOT / "apps" / app
    st = json.loads((d / "pair.json").read_text(encoding="utf-8"))
    if st["lang"] != "flutter":
        return None
    path = d / "lib" / "backend.dart"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render(st, st["role"]), encoding="utf-8")
    # The ready sign-in screens (same for every app; colors from the app's Theme).
    (d / "lib" / "auth_screens.dart").write_text((HERE / "templates" / "auth_screens.dart").read_text(encoding="utf-8"),
                                                 encoding="utf-8")
    ensure_deps(d)
    return path


def ensure_deps(app_dir):
    """Adds the packages backend.dart imports to apps/<app>/packages.txt."""
    app_dir = Path(app_dir)
    st = json.loads((app_dir / "pair.json").read_text(encoding="utf-8"))
    deps = app_dir / "packages.txt"
    have = deps.read_text(encoding="utf-8").split() if deps.exists() else []
    need = ["http", "shared_preferences"] + (["firebase_core", "firebase_messaging"] if st.get("push") else [])
    if any(n not in have for n in need):
        deps.write_text("\n".join(have + [n for n in need if n not in have]) + "\n", encoding="utf-8")


def signin_doc(mode, role):
    """Which Backend calls make THIS app's sign-in screens (the screens themselves are the AI's job)."""
    if mode == "none":
        return ("NO sign-in screens: Backend.init() makes an invisible session by itself. Never show email, password "
                "or code screens.")
    common = ("Backend.sendPasswordReset(email) then Backend.resetPassword(email, code, newPassword) for 'نسيت كلمة "
              "المرور'. Backend.signOut() in the profile/settings screen.")
    if mode == "phone_password":
        return ("Sign-up screen 'حساب جديد': الاسم الكامل, رقم الهاتف, كلمة المرور + تأكيدها -> "
                "await Backend.signUp(fullName: name, phone: phone, password: pw) (signs in by itself).\n"
                "Sign-in screen: رقم الهاتف + كلمة المرور -> await Backend.signIn(phone: phone, password: pw).\n"
                "'نسيت كلمة المرور؟' only shows 'تواصل مع الإدارة عشان تغيّر كلمة المرور' (no SMS)."
                + (" The admin app has 'تغيير كلمة مرور زبون': Backend.setCustomerPassword(phone, newPassword)."
                   if role == "admin" else ""))
    if mode == "email_password":
        return ("Sign-up: الاسم الكامل, البريد الإلكتروني, كلمة المرور + تأكيدها -> await Backend.signUp(fullName: name, "
                "email: email, password: pw) (signs in by itself).\nSign-in: await Backend.signIn(email: email, "
                f"password: pw).\n{common}")
    if mode == "code":
        return ("Sign-in with a code, no password: email field -> await Backend.sendLoginCode(email); then a 6-digit "
                "code screen (resend button with a 60 s countdown) -> await Backend.verifyLoginCode(email, code).\n"
                "Backend.signOut() in the profile/settings screen.")
    fields = "الاسم الكامل, " + ("رقم الهاتف, " if mode == "phone_email_code" else "") + "البريد الإلكتروني, كلمة المرور + تأكيدها"
    phone_arg = "phone: phone, " if mode == "phone_email_code" else ""
    return (f"Sign-up 'حساب جديد': {fields} -> final r = await Backend.signUp(fullName: name, {phone_arg}email: email, "
            "password: pw); if r == SignUpResult.needsCode open a 6-digit code screen ('بعتنا رمز على بريدك', resend "
            "after 60 s: Backend.resendSignUpCode(email)) -> await Backend.verifySignUpCode(email, code).\n"
            "Sign-in: await Backend.signIn(email: email, password: pw); on a BackendException with e.needsCode == true "
            f"call Backend.resendSignUpCode(email) and open the code screen.\n{common}")


def api_doc(st, role):
    """The part of the generation prompt that replaces the hand-written REST / sign-in rules for Flutter pairs."""
    import pair
    mode = pair.state_login(st)[role]
    consts = "\n".join(f"  T.{d} = '{t}'" for d, t in table_consts(st))
    return f"""
=== THE BACKEND IS ALREADY WRITTEN: lib/backend.dart (do NOT write it, do NOT copy it, do NOT change it) ===
`import 'backend.dart';` at the top of main.dart. It is the ONLY way this app talks to the server:
never import package:http, never write a Supabase URL, key, /rest/v1 or /auth/v1 path in main.dart.

main():
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();          // restores the session, Firebase/push, 15-second live sync
  runApp(const MyApp());

THE SIGN-IN SCREENS ARE ALSO READY: lib/auth_screens.dart (sign-in, new account, 6-digit code, forgotten password,
admin PIN — polished, tested, Arabic, colors from YOUR Theme). Do NOT write any sign-in / sign-up / code / password /
PIN screen yourself. `import 'auth_screens.dart';` and make AuthGate the home:
  MaterialApp(
    scaffoldMessengerKey: Backend.messengerKey,
    theme: <the design's light theme>, darkTheme: <its dark theme>,
    home: AuthGate(
      brand: AuthBrand(name: '<app name from the design>', tagline: '<its short tagline>', icon: Icons.<the design's logo icon>),
      home: const <the main screen of the app, e.g. the one with the bottom navigation>(),
    ),
  )
AuthGate shows the sign-in screens while signed out and the home once signed in (in the admin app: once an admin),
and switches back by itself on sign out. Put a sign-out button (Backend.signOut) in the profile / settings screen.
Make the Theme carry the design's colors (ColorScheme.fromSeed(seedColor: <primary>) or a full ColorScheme) and font:
the sign-in screens take them from it.{(" " + signin_doc(mode, role)) if (mode == "phone_password" and role == "admin") else ""}
Every Backend call can throw BackendException: catch it and show e.message (already Arabic) with Backend.toast(e.message)
or under the form. NEVER count the user as signed in any other way (no demo / offline / fallback mode).

Data — table names ONLY through these constants:
{consts}
  Backend.list(T.x, filters: {{'status': 'eq.pending', 'customer_id': 'eq.${{Backend.userId}}'}}, order: 'created_at.desc')
  Backend.byId(T.x, id)   Backend.count(T.x, filters: ...)
  Backend.insert(T.x, {{...}}) -> the saved row     Backend.insertMany(T.x, [ ... ])
  Backend.update(T.x, id, {{...}})   Backend.delete(T.x, id)   Backend.rpc('fn', {{...}})
  Backend.uploadFile(bytes, extension: 'jpg') -> public URL (pictures, receipts, documents; save it in a column)
  Backend.userId, Backend.fullName, Backend.phone, Backend.profile, Backend.updateProfile({{'full_name': ..}})
  Filters are PostgREST: eq., neq., gt., gte., lt., lte., ilike.*text*, in.(a,b), is.null.

EVERY list / record on screen comes from these tables through LiveQuery (in backend.dart), which loads, shows a
spinner, an error with retry, an empty state, and refreshes by itself every 15 s, on a push and after every write:
  LiveQuery<List<Map<String, dynamic>>>(
    load: () => Backend.list(T.x),
    empty: (rows) => rows.isEmpty, emptyText: 'لا توجد ... بعد',
    builder: (context, rows) => ListView.builder(...),
  )
NO business data in the code: no lists of products / orders / customers / prices / names, no made-up numbers or
totals ('4,850,000 ج.س', 'مرحباً د. طارق'): counts and totals are computed from the rows; names come from the
profile. Catalog items exist in the database already (the admin adds more from the admin app).
Every button does its real action (insert / update / delete / navigate / pick a file). No empty onPressed.

Notifications: an inbox screen (LiveQuery with Backend.inbox(), tap -> Backend.markRead(n['id']), a 'قراءة الكل'
button -> Backend.markAllRead()) and a bell with the badge ValueListenableBuilder<int>(valueListenable:
Backend.unread, ...). When something happens that the other app must know, after the write call
Backend.notify(toRole: 'admin', ...) (customer -> admins) or Backend.notify(toUser: row['customer_id'], ...)
(admin -> that customer). Push and live sync are already handled by backend.dart.
"""


if __name__ == "__main__":
    if len(sys.argv) != 2 or not re.fullmatch(r"[a-z0-9-]+", sys.argv[1]):
        raise SystemExit(__doc__)
    print(write(sys.argv[1]) or "not a Flutter pair app")
