"""Flutter apps built screen by screen, in several files, instead of one 2000-3000 line lib/main.dart.

One giant file written in a single reply was where most quality was lost: the model ran out of attention half way
(screens copied from the design with sample data, half-wired buttons) and every later fix rewrote the whole file.
Now (connected-pair Flutter apps, new ones):
  1. plan   — the screens: file, class, constructor, purpose, tables, bottom-nav entry, where each one leads;
  2. shell  — lib/main.dart (theme, MaterialApp, AuthGate, bottom navigation) + lib/ui.dart (shared widgets);
  3. screens — one reply per screen, lib/screens/<name>.dart, several at the same time;
  4. checks and fixes work per file: only the files with a problem are sent back and rewritten.
Files APK Fact writes itself (backend.dart, auth_screens.dart, firebase_config.dart, apkfact_update.dart) are
never written by the AI.

Multi-file replies use this format (FILES_REPLY):
    === FILE: lib/screens/home_screen.dart ===
    ```dart
    <the complete file>
    ```
"""
import json
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

FIXED = {"backend.dart", "auth_screens.dart", "ui_kit.dart", "firebase_config.dart", "apkfact_update.dart"}
FILE_RE = re.compile(r"===\s*FILE:\s*([\w./\-]+?\.dart)\s*===\s*```(?:dart)?\s*\n(.*?)```", re.S)

FILES_REPLY = (
    "Reply with ONLY the files you write or change, each one exactly like this (the COMPLETE file, never a part):\n"
    "=== FILE: lib/<path>.dart ===\n```dart\n<the complete file>\n```\n"
    "and, as the very last line, `DEPS: ` with every pub.dev package the app's files import, comma separated. "
    "Never write backend.dart, auth_screens.dart or firebase_config.dart (they exist and are not yours)."
)


def is_multi(app_dir):
    """True for an app built screen by screen (it has lib/screens/*.dart)."""
    d = Path(app_dir) / "lib" / "screens"
    return d.is_dir() and any(d.glob("*.dart"))


def own_files(app_dir):
    """{'lib/main.dart': code, 'lib/screens/x.dart': code, ...} — the files the AI writes, sorted."""
    app_dir = Path(app_dir)
    out = {}
    for f in sorted((app_dir / "lib").rglob("*.dart")):
        if f.name in FIXED:
            continue
        out[f.relative_to(app_dir).as_posix()] = f.read_text(encoding="utf-8")
    return out


def bundle(files):
    return "\n".join(f"=== FILE: {p} ===\n```dart\n{c.rstrip()}\n```\n" for p, c in files.items())


def all_code(app_dir):
    """All the AI's code as one text (for the checks that read the whole app)."""
    return "\n\n".join(own_files(app_dir).values())


def safe_path(rel):
    rel = rel.strip().lstrip("./")
    if not rel.startswith("lib/") or ".." in rel or not rel.endswith(".dart"):
        return None
    if Path(rel).name in FIXED:
        return None
    return rel


def parse(reply):
    """{path: code} from a multi-file reply (unsafe or fixed paths dropped)."""
    files = {}
    for m in FILE_RE.finditer(reply or ""):
        rel = safe_path(m.group(1))
        if rel and m.group(2).strip():
            files[rel] = m.group(2).rstrip() + "\n"
    return files


def write(app_dir, files):
    for rel, code in files.items():
        p = Path(app_dir) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(code, encoding="utf-8")


def snapshot(app_dir):
    return own_files(app_dir)


def restore(app_dir, snap):
    """Puts the AI's files back exactly as in snap (removes files added since)."""
    for rel in own_files(app_dir):
        if rel not in snap:
            (Path(app_dir) / rel).unlink()
    write(app_dir, snap)


def ask_files(call, prompt):
    """Runs one model call that answers with files. Returns ({path: code}, deps or None)."""
    from native_langs import parse_reply
    text = call(prompt)
    files = parse(text)
    _, deps = parse_reply(text)
    return files, deps


# ------------------------------------------------------------------ create

PLAN = """{rules}

You are the lead Flutter engineer of a top app studio. Plan this app as separate screen files before any code.
{contract}
APP REQUEST:
{task}
{design}
Reply with JSON only:
{{"theme": {{"seed": "#RRGGBB primary color from the design", "notes": "fonts, corner radius, card style, spacing"}},
 "screens": [{{"file": "lib/screens/<snake_case>_screen.dart", "class": "<PascalCase>Screen",
   "args": "constructor arguments, e.g. `required Map<String, dynamic> product` or empty",
   "title": "Arabic title", "purpose": "what the user does here, in detail",
   "tables": ["T.x read / written here"], "nav": {{"label": "Arabic", "icon": "Icons.x_rounded"}} or null,
   "opens": ["<Class> of screens it navigates to"]}}],
 "shared": ["widgets and helpers every screen should reuse, e.g. ProductCard, StatusBadge, money()"]}}
Rules: every screen of the design and of the request is in the list (sign-in screens are NOT: AuthGate has them);
3-5 screens have "nav" (the bottom navigation, in order); include the notifications inbox and a profile/settings
screen with sign-out; detail / form screens are opened from others with their args."""

SHELL = """{rules}

Write the SHELL of this Flutter app: lib/main.dart and lib/ui.dart. The screens are written separately, by other
engineers, from the plan below — import them, use their constructors exactly as planned, never write them here.
lib/main.dart: imports ('backend.dart', 'auth_screens.dart', 'ui_kit.dart', 'ui.dart', every 'screens/<file>.dart'),
main() with Backend.init(), MaterialApp (theme: appTheme(seed: <the design's primary color>, fontFamily: ...),
darkTheme: appTheme(..., brightness: Brightness.dark), scaffoldMessengerKey: Backend.messengerKey),
home: AuthGate(brand: AuthBrand(...), home: const MainShell()), and MainShell = AppNavShell(tabs: [NavTab(...)]) with
the "nav" screens in order and badge: Backend.unread on the notifications tab.
lib/ui.dart: ONLY the app-specific pieces of the plan ("shared") that ui_kit.dart does not already have, composed
from ui_kit components (e.g. an OrderCard made of AppCard + InfoRow + StatusBadge). Do not re-create anything
ui_kit.dart has (buttons, fields, cards, badges, money, dateText...).
{contract}
PLAN:
{plan}
{design}
{files_reply}"""

SCREEN = """{rules}

Write ONE screen of this Flutter app: {file} with `class {cls}` ({args_note}). Other engineers write the other
screens from the same plan; main.dart and ui.dart are below — import and reuse them (`import '../backend.dart';`,
`import '../ui.dart';`, other screens as `import '<file>.dart';`) and open other screens with exactly their planned
constructors. This screen: {purpose}
Make it complete and polished like the best apps on the store, BUILT FROM ui_kit.dart ONLY (AppPage, AppButton,
AppField, AppCard, AppTile, ProductCard, StatCard, StatusBadge, EmptyState, SectionHeader, ChoiceRow, money()...;
`import '../ui_kit.dart';`), never raw buttons / fields / cards: real data through Backend / LiveQuery (loading,
empty and error states), every button doing its real action, forms with validation and a busy state, pull to
refresh, smooth navigation, RTL Arabic texts. No sample data, no TODOs, no empty onPressed.
{contract}
PLAN (all screens):
{plan}
SHELL ALREADY WRITTEN:
{shell}
{design}
{files_reply}
Write only {file}."""


def _design(design_html, limit=60000):
    if not design_html:
        return ""
    return ("APPROVED DESIGN (the owner signed it off; match its layout, colors, components and texts; its data is "
            f"only sample data):\n```html\n{design_html[:limit]}\n```\n")


def create(task, rules, contract, design_html, call_text, call_json, parallel=3):
    """Plans and writes the app. call_text(prompt) / call_json(prompt) run the model. Returns ({path: code}, deps)."""
    plan_text = call_json(PLAN.format(rules=rules, contract=contract, task=task, design=_design(design_html)))
    plan = json.loads(re.sub(r"^[^{]*|[^}]*$", "", plan_text))
    screens = []
    seen = set()
    for s in plan.get("screens", []):
        rel = safe_path(str(s.get("file", "")))
        cls = str(s.get("class", ""))
        if rel and rel.startswith("lib/screens/") and re.fullmatch(r"[A-Z]\w*", cls) and rel not in seen:
            seen.add(rel)
            screens.append({**s, "file": rel, "class": cls})
    if not screens:
        raise ValueError("the plan has no screens")
    plan["screens"] = screens
    plan_json = json.dumps(plan, ensure_ascii=False, indent=1)
    print(f"Plan: {len(screens)} screens: " + ", ".join(s["class"] for s in screens), flush=True)

    shell, deps = ask_files(call_text, SHELL.format(rules=rules, contract=contract, plan=plan_json,
                                                    design=_design(design_html), files_reply=FILES_REPLY))
    shell = {p: c for p, c in shell.items() if p in ("lib/main.dart", "lib/ui.dart")}
    if "lib/main.dart" not in shell:
        raise ValueError("the shell reply has no lib/main.dart")
    print("Shell written: " + ", ".join(shell), flush=True)
    shell_text = bundle(shell)
    all_deps = set(deps or [])

    def one(s):
        prompt = SCREEN.format(rules=rules, file=s["file"], cls=s["class"],
                               args_note=f"constructor: {s.get('args') or 'no arguments'}",
                               purpose=s.get("purpose", ""), contract=contract, plan=plan_json, shell=shell_text,
                               design=_design(design_html, 45000), files_reply=FILES_REPLY)
        for attempt in range(2):
            try:
                files, d = ask_files(call_text, prompt)
                code = files.get(s["file"]) or next((c for p, c in files.items() if p.startswith("lib/screens/")), None)
                if code and f"class {s['class']}" in code:
                    print(f"Screen written: {s['file']}", flush=True)
                    return s["file"], code, d or []
            except Exception as e:  # one screen failing must not lose the others
                print(f"Screen {s['file']}: attempt {attempt + 1} failed ({e})", flush=True)
        return s["file"], None, []

    files = dict(shell)
    with ThreadPoolExecutor(max_workers=parallel) as pool:
        for rel, code, d in pool.map(one, screens):
            if code:
                files[rel] = code
                all_deps.update(d)
    missing = [s["file"] for s in screens if s["file"] not in files]
    if missing:
        raise ValueError(f"screens not written: {', '.join(missing)}")
    return files, sorted(all_deps), plan


# ------------------------------------------------------------------ errors per file

ERROR_AT = re.compile(r"((?:lib/)[\w./\-]+\.dart)[:,]\s*(?:line\s*)?(\d+)")


def errors_by_file(problems):
    """Groups analyzer / build error lines by the lib/ file they point at."""
    out = {}
    for line in (problems or "").splitlines():
        m = ERROR_AT.search(line)
        if m:
            out.setdefault(m.group(1), []).append(line.strip())
    return out


FIX_FILES = """{rules}

This Flutter app (several files) does not compile. Fix every error below with the smallest changes, keeping the
app's screens, behavior and design. A file may need changes because of ANOTHER file (a wrong constructor, a missing
helper in ui.dart): change whichever files are needed.

ERRORS:
{errors}

PACKAGES DECLARED: {deps}

THE APP'S FILES (backend.dart and auth_screens.dart exist and are correct; their API is in the contract):
{files}

{contract}
{files_reply}"""
