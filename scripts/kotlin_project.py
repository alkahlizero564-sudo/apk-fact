"""Builds the Android project of a Kotlin (Jetpack Compose) app from scripts/templates/kotlin.

    python scripts/kotlin_project.py prepare APP_DIR PROJ_DIR APP [VERSION]
        copies the template (once), the app's MainActivity.kt, name, icon, package id and version.
    python scripts/kotlin_project.py sample PROJ_DIR
        the same with scripts/templates/kotlin/sample (self-test).

The generated app is one file, MainActivity.kt, in `package app.main`; versions of Gradle, the Android
plugin, Kotlin, Compose and every library are fixed by the template so they always fit together.
"""
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "templates" / "kotlin"
CODE_REL = Path("app/src/main/java/app/main")


def package_id(app):
    # apps/<app>/package.txt or the default; same as scripts/vault.py and the other builds.
    sys.path.insert(0, str(HERE))
    import app_id
    return app_id.get(app, "kotlin") if re.fullmatch(r"[a-z0-9-]+", app) else app_id.default(app, "kotlin")


def launcher_png(src, dest):
    """The icon as a real 192x192 PNG: icons picked on the phone are often JPEG files named icon.png, which
    Android's resource compiler rejects ("file failed to compile")."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image
        with Image.open(src) as im:
            im = im.convert("RGBA")
            side = min(im.size)
            left, top = (im.width - side) // 2, (im.height - side) // 2
            im.crop((left, top, left + side, top + side)).resize((192, 192), Image.LANCZOS).save(dest, "PNG")
        return True
    except ImportError:
        if src.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n":
            shutil.copy(src, dest)
            return True
        print("Warning: icon.png is not a PNG and Pillow is not installed; using the default icon")
    except Exception as e:  # unreadable image: build with the default icon instead of failing
        print(f"Warning: icon could not be used ({e}); using the default icon")
    return False


def prepare(app_dir, proj, app, version=1):
    app_dir, proj = Path(app_dir), Path(proj)
    if not (proj / "settings.gradle.kts").exists():
        shutil.copytree(TEMPLATE, proj, ignore=shutil.ignore_patterns("sample"), dirs_exist_ok=True)
    gradle = proj / "app" / "build.gradle.kts"
    orig = proj / "app" / "build.gradle.kts.orig"
    if not orig.exists():
        shutil.copy(gradle, orig)
    text = orig.read_text(encoding="utf-8")
    text = (text.replace("__APP_ID__", package_id(app))
                .replace("__VERSION_CODE__", str(int(version)))
                .replace("__VERSION_NAME__", f"1.0.{int(version)}"))
    gradle.write_text(text, encoding="utf-8")

    code_dir = proj / CODE_REL
    code_dir.mkdir(parents=True, exist_ok=True)
    for old in code_dir.glob("*.kt"):
        old.unlink()
    code = (app_dir / "MainActivity.kt").read_text(encoding="utf-8")
    # The template's package is fixed; make sure the code uses it.
    if re.search(r"^\s*package\s+[\w.]+", code, re.M):
        code = re.sub(r"^\s*package\s+[\w.]+", "package app.main", code, count=1, flags=re.M)
    else:
        code = "package app.main\n\n" + code
    (code_dir / "MainActivity.kt").write_text(code, encoding="utf-8")

    res = proj / "app" / "src" / "main" / "res"
    sys.path.insert(0, str(HERE))
    import app_label
    app_label.android(res, app)

    manifest = proj / "app" / "src" / "main" / "AndroidManifest.xml"
    xml = manifest.read_text(encoding="utf-8")
    icon = app_dir / "icon.png"
    if icon.exists() and launcher_png(icon, res / "mipmap-xxxhdpi" / "ic_launcher.png"):
        if "android:icon" not in xml:
            xml = xml.replace('android:label="@string/app_name"',
                              'android:icon="@mipmap/ic_launcher"\n        android:label="@string/app_name"', 1)
    manifest.write_text(xml, encoding="utf-8")
    import perms  # the Android permissions the owner approved (perms.txt)
    perms.manifest(app, manifest)
    return code_dir / "MainActivity.kt"


def main():
    cmd, *args = sys.argv[1:] or ["help"]
    if cmd == "prepare":
        app_dir, proj, app = args[:3]
        prepare(app_dir, proj, app, int(args[3]) if len(args) > 3 else 1)
    elif cmd == "sample":
        prepare(TEMPLATE / "sample", args[0], "kotlin-sample", 1)
    else:
        raise SystemExit(__doc__)
    print("Kotlin project ready")


if __name__ == "__main__":
    main()
