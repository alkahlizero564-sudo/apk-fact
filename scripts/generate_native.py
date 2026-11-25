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

# The design prototype is shown to the owner inside a phone frame and with a top bar that switches between screens.
# Both exist only for the review: the installed app must not copy them (they showed up as a duplicate top bar).
NO_REVIEW_CHROME = (
    "IMPORTANT - the real installed app is NOT a preview: do NOT build a phone frame or device mockup around it "
    "(no rounded outer border, shadow, margin or max-width card), and do NOT build any top bar, tab strip or row of "
    "chips that switches between screens (the design prototype has them only so the owner can review the screens). "
    "The app fills the whole screen edge to edge, and its screens are reached only through the app's own navigation "
    "(ONE bottom navigation bar and/or a drawer), never a second navigation bar at the top. This rule is about the "
    "native app code only; the html preview may stay inside a phone-sized layout."
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


def design_gaps(model, keys, cfg, design_html, code):
    """Ask the AI where the built app would LOOK different from the approved design the owner signed off on.

    Fidelity to the approved design.html is what the user sees when the app is installed; without this check the
    native code only loosely follows the prototype and drifts (the reported 'installed app is not like the preview').
    """
    prompt = (f"The owner reviewed and APPROVED the design prototype below (an HTML clickable mock). A {cfg['title']} "
              "app was then built to match it. List every difference the user WOULD SEE when the app is installed: "
              "screens that are in the design but missing or clearly different in the app; and differences in layout, "
              "structure, colors, typography, spacing, corner radius, icons, components, texts and navigation. Ignore "
              "tiny pixel differences, and do NOT report as a difference that the app lacks the prototype's phone frame "
              "or its top bar that switches between screens: those exist only for the review and the app must not have "
              "them. Also report, as a difference to remove, any phone frame around the app or any top bar that "
              "switches between screens that appears in the APP CODE (the app uses one bottom navigation only). "
              "Be concrete "
              "(name the screen and what differs). Reply with JSON only: {\"diffs\": [\"...\"]} (empty list when the "
              "app already looks like the design).\n\n"
              f"APPROVED DESIGN:\n```html\n{design_html}\n```\n\nAPP CODE:\n```{cfg['fence']}\n{code}\n```\n")
    try:
        text = call_gemini(model, prompt, keys, temperature=0.1, json_mode=True)
        data = json.loads(re.sub(r"^[^{]*|[^}]*$", "", text))
        return [d.strip() for d in data.get("diffs", []) if isinstance(d, str) and d.strip()][:15]
    except Exception as e:
        print(f"Design-fidelity check skipped ({e})")
        return []


def qa_preview_html(base, model, keys):
    """Quality gate on the preview the owner reviews: run it in a headless browser, press its controls and check
    its screens for dead buttons / broken layout / errors, and ask the AI to fix what it finds. Best-effort: it
    skips silently when no browser (or node) is available, and never stops generation."""
    import subprocess
    pv = base / "preview.html"
    if not pv.exists():
        return
    def check():
        try:
            r = subprocess.run(["node", str(HERE / "qa_gate.js"), str(pv)], capture_output=True, text=True, timeout=180)
            return r.returncode, (r.stdout + r.stderr)
        except Exception as e:
            print(f"Preview QA skipped ({e})", flush=True)
            return None, ""
    rc, out = check()
    if rc is None:
        return
    print(out.strip()[-1500:], flush=True)
    if rc != 1:  # 0 = clean, 2 = usage, None = skipped; only 1 means problems were found
        return
    problems = "\n".join(l for l in out.splitlines() if l.strip().startswith("- "))
    if not problems or not keys:
        return
    prompt = ("This is the HTML PREVIEW of a mobile app (the owner reviews it before building). A UI check ran the "
              "preview and pressed its controls and found these problems — fix every one and keep everything else "
              "(screens, design, texts, data) exactly the same:\n" + problems + "\n\n"
              "Reply with ONLY the complete fixed preview inside one ```html code block.\n\n"
              f"CURRENT PREVIEW:\n```html\n{pv.read_text(encoding='utf-8')}\n```\n")
    try:
        fixed = parse_reply(call_gemini(model, prompt, keys, temperature=0.2, json_mode=False))[0].get("html", "")
    except (Exception, SystemExit) as e:
        print(f"Preview QA: could not get a fix ({e})", flush=True)
        return
    if fixed and len(fixed) > len(pv.read_text(encoding="utf-8")) * 0.5:
        pv.write_text(fixed.rstrip() + "\n", encoding="utf-8")
        rc2, _ = check()
        print("Preview QA: " + ("fixed and clean now" if rc2 == 0 else "fixed (some issues may remain)"), flush=True)


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
    design_html = ""  # set in the create branch when an approved design.html exists (used for the fidelity pass)

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
        qa_preview_html(base, model, keys)
        print(f"Wrote apps/{name}/preview.html")
        return

    deps_text = ", ".join(cfg["allowed_deps"])
    reply_fmt = reply_format([(cfg["fence"], f"the complete {cfg['code_file']}"), ("html", PREVIEW_RULES)])
    prompt = f"""{rules_for(lang)}

{DESIGN_BRIEF}

{PERMISSIONS_RULE}

{NO_REVIEW_CHROME}

{reply_fmt}

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
            design_html = design.read_text(encoding="utf-8")[:90000]
            prompt += (f"\nAPPROVED DESIGN - the owner reviewed and approved this clickable design prototype. Build the "
                       f"real {cfg['title']} app so it looks exactly like it: the same screens, navigation, layout, colors, "
                       f"typography, spacing, corner radius, icons, texts and components (map them to the closest "
                       f"{cfg['title']} widgets). Do NOT drop, merge or restyle any screen, and do not substitute a "
                       f"generic layout — the installed app must match this design screen for screen. {NO_REVIEW_CHROME} "
                       f"Make every "
                       f"screen fully functional with real state and stored data.\n"
                       + ("The names, people, products, prices, numbers, totals and records shown in the design are "
                          "SAMPLE data that only show the layout: never copy them into the code; show the real rows "
                          "from the backend (lib/backend.dart) in exactly that layout, and an empty state when there "
                          "are none yet.\n" if (base / "lib" / "backend.dart").exists() else "")
                       + 
                       f"```html\n{design_html}\n```\n")

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

    # Fidelity to the approved design: on a fresh build (not an edit), make the installed app match the prototype
    # the owner signed off on — the reported 'it looked different once installed'. One repair round fixes the gaps.
    if design_html and not existing:
        diffs = design_gaps(model, keys, cfg, design_html, code)
        if diffs:
            print("Differs from the approved design:\n- " + "\n- ".join(diffs), flush=True)
            fixup = (f"{rules_for(lang)}\n\nThe {cfg['title']} app below was built from the APPROVED design, but a "
                     f"reviewer found these VISIBLE differences from it. Fix every one so the installed app matches the "
                     f"design exactly (same screens, layout, colors, typography, spacing, corner radius, icons, texts and "
                     f"components), and keep everything else — all features and stored data — working:\n- "
                     + "\n- ".join(diffs) +
                     f"\n\n{NO_REVIEW_CHROME}\n\n{reply_fmt}\n\n"
                     f"APPROVED DESIGN:\n```html\n{design_html}\n```\n\n"
                     f"CURRENT {cfg['code_file']}:\n```{cfg['fence']}\n{code}\n```\n")
            try:
                blocks3, deps3 = parse_reply(call_gemini(model, fixup, keys, temperature=0.3, json_mode=False))
                if blocks3.get(cfg["fence"]):
                    code = blocks3[cfg["fence"]]
                    preview = blocks3.get("html") or preview
                    deps = deps3 if deps3 is not None else deps
                    print("Brought the app closer to the approved design", flush=True)
            except Exception as e:  # keep the current version
                print(f"Warning: could not apply the design fixes ({e})")
        else:
            print("Design check: the app matches the approved design", flush=True)

    code_path.parent.mkdir(parents=True, exist_ok=True)
    code_path.write_text(code + "\n", encoding="utf-8")
    record_history(base, name, lang, "edit" if existing else "create", raw_task)
    (base / "preview.html").write_text(preview + "\n", encoding="utf-8")
    qa_preview_html(base, model, keys)
    deps = clean_deps(lang, deps) or (read_deps(lang, base) if existing else [])
    write_deps(lang, base, deps)
    if (base / "lib" / "backend.dart").exists():  # a pair app: the packages backend.dart needs stay listed
        import flutter_backend
        flutter_backend.ensure_deps(base)
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
