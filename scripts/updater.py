"""In-app updates for the apps APK Fact builds.

Every build gets a version number (1, 2, 3, ...). The build copies a small update checker into the app
(it is not part of the app's code in the repo, so the AI never has to write it). When the app opens it
reads apps/<app>/version.json from this public repo; if a newer version is published there it shows
"تحديث جديد متوفر" and the button downloads the new APK, which installs over the old one because every
build of an app is signed with the same permanent key (private vault).

    python scripts/updater.py next APP                       -> prints the version this build gets
    python scripts/updater.py inject LANG DIR APP VERSION    -> adds the checker to the build copy
    python scripts/updater.py publish APP VERSION APK_URL    -> writes apps/APP/version.json (notes: UPDATE_NOTES)
"""
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = Path(__file__).resolve().parent / "templates"


def manifest_path(app):
    return ROOT / "apps" / app / "version.json"


def manifest_url(app):
    repo = os.environ.get("GITHUB_REPOSITORY") or "alkahlizero564-sudo/apk-fact"
    branch = os.environ.get("MANIFEST_BRANCH") or "main"
    return f"https://raw.githubusercontent.com/{repo}/{branch}/apps/{app}/version.json"


def current_version(app):
    p = manifest_path(app)
    try:
        v = json.loads(p.read_text(encoding="utf-8")).get("version", 0)
        return v if isinstance(v, int) and v >= 0 else 0
    except (OSError, ValueError):
        return 0


def fill(template, app, version):
    text = (TEMPLATES / template).read_text(encoding="utf-8")
    return text.replace("__APKFACT_VERSION__", str(version)).replace("__APKFACT_MANIFEST__", manifest_url(app))


def inject_html(d, app, version):
    index = d / "index.html"
    html = index.read_text(encoding="utf-8")
    if "apkfact-update.js" in html:
        return
    (d / "apkfact-update.js").write_text(fill("update_check.js", app, version), encoding="utf-8")
    tag = '<script src="apkfact-update.js"></script>'
    if re.search(r"</body>", html, re.I):
        html = re.sub(r"</body>", tag + "\n</body>", html, count=1, flags=re.I)
    else:
        html += "\n" + tag + "\n"
    index.write_text(html, encoding="utf-8")


def inject_flutter(proj, app, version):
    main = proj / "lib" / "main.dart"
    code = main.read_text(encoding="utf-8")
    if "apkfact_update.dart" in code:
        return
    if not re.search(r"\brunApp\(", code):
        print("No runApp( in main.dart; skipping the update checker")
        return
    (proj / "lib" / "apkfact_update.dart").write_text(fill("update_check.dart", app, version), encoding="utf-8")
    code = re.sub(r"\brunApp\(", "apkfactRunApp(", code, count=1)
    m = re.search(r"^\s*(import|export)\s", code, re.M)
    at = m.start() if m else 0
    code = code[:at] + "import 'apkfact_update.dart';\n" + code[at:]
    main.write_text(code, encoding="utf-8")
    if "url_launcher:" not in (proj / "pubspec.yaml").read_text(encoding="utf-8"):
        subprocess.run(["flutter", "pub", "add", "url_launcher"], cwd=proj, check=True)


def inject_python(proj, app, version):
    main = proj / "main.py"
    code = main.read_text(encoding="utf-8")
    if "apkfact_update" in code:
        return
    (proj / "apkfact_update.py").write_text(fill("update_check.py", app, version), encoding="utf-8")
    # Must run before main.py calls ft.run(...): keep a leading `from __future__` import first.
    lines = code.splitlines(keepends=True)
    at = 0
    for i, line in enumerate(lines):
        if line.startswith("from __future__"):
            at = i + 1
    lines.insert(at, "import apkfact_update  # in-app updates (added by the build)\n")
    main.write_text("".join(lines), encoding="utf-8")


def inject_kotlin(proj, app, version):
    code_dir = proj / "app" / "src" / "main" / "java" / "app" / "main"
    main = code_dir / "MainActivity.kt"
    code = main.read_text(encoding="utf-8")
    if "apkfactCheckForUpdate" in code:
        return
    m = re.search(r"super\.onCreate\([^)]*\)", code)
    if not m:
        print("No super.onCreate(...) in MainActivity.kt; skipping the update checker")
        return
    (code_dir / "ApkFactUpdate.kt").write_text(fill("update_check.kt", app, version), encoding="utf-8")
    main.write_text(code[:m.end()] + "\n        apkfactCheckForUpdate()" + code[m.end():], encoding="utf-8")


def publish(app, version, apk_url):
    notes = (os.environ.get("UPDATE_NOTES") or "").strip()[:500]
    data = {
        "app": app,
        "version": version,
        "versionName": f"1.0.{version}",
        "apk": apk_url,
        "notes": notes,
        "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    manifest_path(app).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Published {app} version {version}")


def main():
    cmd, *args = sys.argv[1:] or ["help"]
    if cmd == "next":
        print(current_version(args[0]) + 1)
    elif cmd == "inject":
        lang, d, app, version = args
        {"html": inject_html, "flutter": inject_flutter, "python": inject_python, "kotlin": inject_kotlin}[lang](Path(d), app, int(version))
        print(f"Update checker added ({lang}, version {version})")
    elif cmd == "publish":
        publish(args[0], int(args[1]), args[2])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
