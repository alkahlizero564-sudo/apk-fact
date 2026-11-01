"""The Android package name (application id) of a generated app — what Google Play knows it by.

The owner can choose one per app (apps/<app>/package.txt, e.g. com.alwardshop.app). Without it the app keeps
the generated default, so apps that are already installed keep updating. Google Play never lets an app change
its package name after it is published.

    python scripts/app_id.py get APP [LANG]           -> prints the package name
    python scripts/app_id.py gradle FILE APP [LANG]   -> sets applicationId (and SDK 36) in a Flutter build.gradle(.kts)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILE = "package.txt"
TARGET_SDK = 36  # Google Play: new apps and updates must target Android 16 (API 36) since Aug 31, 2026
JAVA_WORDS = {
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
    "default", "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "goto", "if",
    "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "package", "private",
    "protected", "public", "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this",
    "throw", "throws", "transient", "try", "void", "volatile", "while", "true", "false", "null",
}


def valid(pkg):
    parts = (pkg or "").split(".")
    return (len(parts) >= 2 and len(pkg) <= 100
            and all(re.fullmatch(r"[a-z][a-z0-9_]*", p) and p not in JAVA_WORDS for p in parts))


def detect_lang(app):
    d = ROOT / "apps" / app
    if (d / "lib" / "main.dart").exists():
        return "flutter"
    if (d / "main.py").exists():
        return "python"
    if (d / "MainActivity.kt").exists():
        return "kotlin"
    return "html"


def default(app, lang):
    # The ids every build used before package.txt existed: keep them, or installed apps stop updating.
    if lang == "html":
        return "com.generated.a" + re.sub(r"[^a-z0-9]", "", app)
    return "com.generated.app_" + app.replace("-", "_")


def get(app, lang=None):
    if not re.fullmatch(r"[a-z0-9-]+", app):
        raise SystemExit("bad app name")
    p = ROOT / "apps" / app / FILE
    chosen = p.read_text(encoding="utf-8").strip() if p.exists() else ""
    if chosen and not valid(chosen):
        print(f"::warning::apps/{app}/{FILE} is not a valid package name ({chosen}); using the default", file=sys.stderr)
        chosen = ""
    return chosen or default(app, lang or detect_lang(app))


def patch_gradle(path, app, lang="flutter"):
    """Flutter projects: our applicationId, and at least SDK 36 for Google Play."""
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    pkg = get(app, lang)
    text, n = re.subn(r'(applicationId\s*=?\s*)"[^"]*"', rf'\g<1>"{pkg}"', text, count=1)
    if not n:
        raise SystemExit(f"applicationId not found in {path}")
    for key in ("compileSdk", "targetSdk"):
        text = re.sub(rf"({key}\s*=\s*)flutter\.{key}Version\b", rf"\g<1>maxOf(flutter.{key}Version, {TARGET_SDK})", text)
    p.write_text(text, encoding="utf-8")
    print(f"Package name: {pkg}")


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "get" and a:
        print(get(a[0], a[1] if len(a) > 1 else None))
    elif cmd == "gradle" and len(a) >= 2:
        patch_gradle(a[0], a[1], a[2] if len(a) > 2 else "flutter")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
