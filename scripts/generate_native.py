"""Generate (or edit) a Flutter or Python/Flet app and its AI preview.

Usage: python scripts/generate_native.py flutter|python

Reads request-flutter.txt / request-python.txt:
    line 1          app name
    @related: x     optional, another app of the same project to stay consistent with
    @model: x       optional Gemini model
    @preview        optional, only (re)build preview.html from the current code
    rest            description of the app, or of the change
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import fix_memory
from fix_native import fix
from gemini_client import call_gemini
from native_langs import DESIGN_BRIEF, LANGS, rules_for, clean_deps, gemini_keys, parse_reply, read_deps, reply_format, write_deps

DEFAULT_MODEL = "gemini-3.8-flash"
HERE = Path(__file__).resolve().parent

PREVIEW_RULES = (
    "the preview: one self-contained HTML file (inline CSS and JS, no external resources) that "
    "imitates this exact app inside a phone-sized layout, with the same screens, texts, colors, icons "
    "(use emoji or inline SVG) and working behavior (navigation, buttons, forms, lists, local state), "
    "so it can be shown in a WebView as a faithful live preview."
)


# The build adds the Android permissions the request asks for and the code uses (scripts/perms.py).
PERMISSIONS_RULE = (
    "Device features: when the owner asks for the camera, location, microphone, notifications, photos/files, "
    "vibration, calls or SMS, really implement them (not a placeholder). The Android permissions are added to "
    "the manifest automatically; ask for the permission at runtime right before the feature is used, and show "
    "a clear message with a retry when the user refuses. Never ask for permissions the app does not use."
)


def parse_request(text):
    lines = text.splitlines()
    name = re.sub(r"[^a-z0-9-]", "", lines[0].strip().lower())
    related, model, preview_only, body = "", "", False, []
    for line in lines[1:]:
        if line.startswith("@related:"):
            related = re.sub(r"[^a-z0-9-]", "", line.split(":", 1)[1].strip().lower())
        elif line.startswith("@model:"):
            model = line.split(":", 1)[1].strip()
        elif line.strip() == "@preview":
            preview_only = True
        elif line.startswith("(request id:"):
            continue
        else:
            body.append(line)
    return name, related, model, preview_only, "\n".join(body).strip()


def read_app_code(app):
    for lang in LANGS.values():
        p = Path("apps") / app / lang["code_file"]
        if p.exists():
            return p.read_text(encoding="utf-8")[:20000]
    p = Path("apps") / app / "index.html"
    return p.read_text(encoding="utf-8")[:20000] if p.exists() else ""



def pair_edit_rules(name):
    """Contract of a connected pair app, so AI updates keep both apps working together."""
    if not (Path("apps") / name / "pair.json").exists():
        return ""
    r = subprocess.run([sys.executable, str(HERE / "pair.py"), "contract", name], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def record_history(base, name, lang, kind, request):
    """apps/<name>/meta.json keeps the description and every requested change (copied to the vault)."""
    import datetime
    path = base / "meta.json"
    meta = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"name": name, "lang": lang, "history": []}
    meta.setdefault("history", []).append({
        "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kind": kind,
        "request": request,
    })
    path.write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def python_problems(code_path):
    """Run the Flet static check, applying its sure fixes; returns the remaining errors, or "" when clean."""
    r = subprocess.run([sys.executable, str(HERE / "check_python.py"), "--fix", str(code_path)],
                       capture_output=True, text=True)
    return "" if r.returncode == 0 else (r.stdout + r.stderr).strip()


def check_flutter_app(app_dir):
    """Analyze (and fix) the Flutter app with the SDK when it is installed; never fails generation."""
    if not shutil.which("flutter"):
        print("Flutter SDK not installed here; the build step will check the code")
        return
    with tempfile.TemporaryDirectory() as tmp:
        proj = Path(tmp) / "app"
        r = subprocess.run(["flutter", "create", "--platforms=android", "--project-name", "app_check", str(proj)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print("Warning: flutter create failed, the build step will check the code")
            return
        r = subprocess.run([sys.executable, str(HERE / "check_flutter.py"), str(app_dir), str(proj), "--rounds", "2"])
        if r.returncode != 0:
            print("Warning: still not clean, the build step will try again")


def missing_requirements(model, keys, cfg, task, code, is_edit):
    """Ask the AI which concrete requirements of the owner's request the code does not implement."""
    what = "the CHANGE the owner asked for" if is_edit else "the owner's request"
    prompt = (f"You review a {cfg['title']} app against {what}. List every concrete requirement in it (features, "
              "screens, fields, buttons, texts, names, numbers, rules) that the code does NOT implement, or "
              "implements differently from what was asked. Ignore style details the owner did not mention. "
              'Reply with JSON only: {"missing": ["..."]} (an empty list when everything is done).\n\n'
              f"OWNER'S REQUEST:\n{task}\n\nCODE:\n```{cfg['fence']}\n{code}\n```\n")
    try:
        text = call_gemini(model, prompt, keys, temperature=0.1, json_mode=True)
        data = json.loads(re.sub(r"^[^{]*|[^}]*$", "", text))
        return [m.strip() for m in data.get("missing", []) if isinstance(m, str) and m.strip()][:15]
    except Exception as e:
        print(f"Request check skipped ({e})")
        return []


def check_kotlin_app(app_dir, name):
    """Compile (and fix) the Kotlin app with Gradle when it is installed; never fails generation."""
    if not shutil.which("gradle"):
        print("Gradle not installed here; the build step will check the code")
        return
    with tempfile.TemporaryDirectory() as tmp:
        r = subprocess.run([sys.executable, str(HERE / "check_kotlin.py"), str(app_dir), str(Path(tmp) / "proj"),
                            "--rounds", "2", "--app", name])
        if r.returncode != 0:
            print("Warning: still not clean, the build step will try again")


def main():
    lang = sys.argv[1]
    cfg = LANGS[lang]
    name, related, model, preview_only, task = parse_request(
        Path(os.environ.get("REQUEST_FILE") or cfg["request_file"]).read_text(encoding="utf-8"))
    if not name or not (task or preview_only):
        raise SystemExit("Bad request file")
    # The lines meant only for the build (permissions, sign-in mode) stay out of what the AI reads, so they never
    # end up on a screen; the raw task is kept for the history and the permissions (scripts/perms.py).
    raw_task = task
    task = re.sub(r"(?m)^\s*(ANDROID_PERMISSIONS|LOGIN):.*$", "", task).strip()

    keys = gemini_keys(os.environ)
    if not keys:
        raise SystemExit("No Gemini API key in repository secrets")
    model = model or os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL

    base = Path("apps") / name
    code_path = base / cfg["code_file"]
    existing = code_path.read_text(encoding="utf-8") if code_path.exists() else ""

    if preview_only:
        if not existing:
            raise SystemExit(f"apps/{name}/{cfg['code_file']} does not exist")
        prompt = (f"Here is a {cfg['title']} app. Reply with exactly one ```html code block with "
                  f"{PREVIEW_RULES}\n\nApp code:\n```{cfg['fence']}\n{existing}\n```\n")
        if task:
            prompt += f"\nNotes from the user about the preview:\n{task}\n"
        preview = parse_reply(call_gemini(model, prompt, keys, temperature=0.3, json_mode=False))[0].get("html", "")
        if not preview:
            raise SystemExit("Model returned no preview_html")
        (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
        print(f"Wrote apps/{name}/preview.html")
        return

    deps_text = ", ".join(cfg["allowed_deps"])
    prompt = f"""{rules_for(lang)}

{DESIGN_BRIEF}

{PERMISSIONS_RULE}

{reply_format([(cfg['fence'], f"the complete {cfg['code_file']}"), ("html", PREVIEW_RULES)])}

App name: {name}
"""
    context = read_app_code(related) if related and related != name else ""
    if context:
        prompt += f"\nA related app (same project) for reference, keep data and style consistent:\n{context}\n"
    if existing:
        prompt += (f"\nThis is the CURRENT {cfg['code_file']}. Apply the requested change to it and "
                   f"return the full updated files:\n{existing}\n\nRequested change:\n{task}\n")
        prompt += pair_edit_rules(name)
    else:
        prompt += f"\nDescription of the app to create:\n{task}\n"
        design = base / "design.html"
        if design.exists():
            prompt += (f"\nAPPROVED DESIGN - the owner reviewed and approved this clickable design prototype. Build the "
                       f"real {cfg['title']} app so it looks exactly like it: the same screens, navigation, layout, colors, "
                       f"typography, spacing, corner radius, icons, texts and components (map them to the closest "
                       f"{cfg['title']} widgets). Ignore the prototype's top 'screens' switcher (id apkfact-screens): it "
                       f"is only for reviewing. Make every screen fully functional with real state and stored data.\n"
                       f"```html\n{design.read_text(encoding='utf-8')[:60000]}\n```\n")

    blocks, deps = parse_reply(call_gemini(model, prompt, keys, temperature=0.4, json_mode=False))
    code = blocks.get(cfg["fence"], "")
    preview = blocks.get("html", "")
    if not code or not preview:
        raise SystemExit(f"Model did not return both the {cfg['fence']} code and the html preview")

    # Make sure the app does everything the owner asked; one more round adds what is missing.
    missing = missing_requirements(model, keys, cfg, task, code, bool(existing))
    if missing:
        print("Missing from the request:\n- " + "\n- ".join(missing), flush=True)
        retry = (f"{prompt}\n\nYour previous answer is below, but it does not do all of what the owner asked. "
                 f"Missing or different:\n- " + "\n- ".join(missing) +
                 f"\n\nReturn the complete files again with ALL of these implemented exactly as asked, keeping "
                 f"everything else.\n\nPREVIOUS {cfg['code_file']}:\n```{cfg['fence']}\n{code}\n```\n")
        try:
            blocks2, deps2 = parse_reply(call_gemini(model, retry, keys, temperature=0.3, json_mode=False))
            if blocks2.get(cfg["fence"]):
                code = blocks2[cfg["fence"]]
                preview = blocks2.get("html") or preview
                deps = deps2 if deps2 is not None else deps
                print("Added what was missing", flush=True)
        except Exception as e:  # keep the first version
            print(f"Warning: could not add the missing parts ({e})")
    else:
        print("Request check: everything asked for is implemented", flush=True)

    code_path.parent.mkdir(parents=True, exist_ok=True)
    code_path.write_text(code + "\n", encoding="utf-8")
    record_history(base, name, lang, "edit" if existing else "create", raw_task)
    (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
    deps = clean_deps(lang, deps) or (read_deps(lang, base) if existing else [])
    write_deps(lang, base, deps)
    try:  # Android permissions the description asks for (apps/<name>/perms.txt)
        import perms
        perms.save(name, raw_task)
    except Exception as e:
        print(f"Warning: permissions not saved ({e})")

    if lang == "python":
        problems = python_problems(code_path)
        if problems:
            print("Generated code has problems:\n" + problems)
            before = code_path.read_text(encoding="utf-8")
            used = fix_memory.apply("python", code_path, problems)
            if used:
                after = python_problems(code_path)
                if after and after.count("error:") >= problems.count("error:"):
                    code_path.write_text(before, encoding="utf-8")
                    fix_memory.forget("python", used)
                else:
                    problems = after
        if problems:
            print("Asking AI to fix what is left")
            try:
                fix("python", code_path, problems, use_memory=False)
            except (Exception, SystemExit) as e:  # keep the generated app; the build step fixes again
                print(f"Warning: AI fix failed ({e}), the build step will try again")
            still = python_problems(code_path)
            if still:
                print("Warning: still not clean, the build step will try again:\n" + still)
    elif lang == "kotlin":
        check_kotlin_app(base, name)
    else:
        check_flutter_app(base)

    print(f"Wrote apps/{name}/{cfg['code_file']} and preview.html ({', '.join(deps) or 'no extra packages'})")


if __name__ == "__main__":
    main()
