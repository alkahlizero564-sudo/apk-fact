"""Android permissions of a generated app, kept in apps/<app>/perms.txt (one key per line, e.g. CAMERA).

perms.txt holds the permissions the owner approved:
  - generation saves the ones the app's description asks for;
  - before a build, APK Fact compares them with what the code uses and asks the owner to approve any
    missing one ("this app needs the camera, OK?"), then adds it to perms.txt.
Builds add exactly the approved permissions (plus INTERNET). The rules (keys, Android names, the words a
description uses, what code uses) live in services/permissions.json, shared with the app.

    python scripts/perms.py list APP                 -> the approved keys
    python scripts/perms.py needs APP                -> the keys the code uses that are not approved
    python scripts/perms.py save APP [REQUEST_FILE]  -> adds what the description asks for to perms.txt
    python scripts/perms.py manifest APP FILE        -> adds <uses-permission> lines to AndroidManifest.xml
    python scripts/perms.py flet APP                 -> prints --android-permissions arguments for flet build
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILE = "perms.txt"
RULES = json.loads((ROOT / "services" / "permissions.json").read_text(encoding="utf-8"))

ANDROID = {k["key"]: k["android"] for k in RULES["keys"]}
ALWAYS = RULES["always"]
REQUEST_WORDS = RULES["request"]  # case-insensitive
CODE_USES = RULES["code"]  # per code file, case-sensitive


def app_dir(app):
    if not re.fullmatch(r"[a-z0-9-]+", app):
        raise SystemExit("bad app name")
    return ROOT / "apps" / app


def approved(app):
    """The keys in perms.txt (unknown words are ignored)."""
    p = app_dir(app) / FILE
    if not p.exists():
        return []
    words = re.findall(r"[A-Z_]+", p.read_text(encoding="utf-8").upper())
    return [w for w in dict.fromkeys(words) if w in ANDROID]


def from_code(app):
    d = app_dir(app)
    found = []
    for rel, rules in CODE_USES.items():
        f = d / rel
        if f.exists():
            code = f.read_text(encoding="utf-8", errors="ignore")
            found += [k for k, rx in rules.items() if re.search(rx, code)]
    return list(dict.fromkeys(found))


def from_request(text):
    return [k for k, rx in REQUEST_WORDS.items() if re.search(rx, text or "", re.I)]


def needs(app):
    have = approved(app)
    return [k for k in from_code(app) if k not in have]


def android_names(app):
    names = list(ALWAYS)
    for k in approved(app):
        names += ANDROID[k]
    return list(dict.fromkeys(names))


def warn_unapproved(app):
    missing = needs(app)
    if missing:
        print("::warning::The code uses permissions that are not approved, so the app cannot use them: "
              + ", ".join(missing) + ". Build from APK Fact to approve them.", file=sys.stderr)


def save(app, request=""):
    ks = list(dict.fromkeys(approved(app) + from_request(request)))
    p = app_dir(app) / FILE
    if ks or p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("".join(k + "\n" for k in ks), encoding="utf-8")
    print("Permissions from the description: " + (", ".join(ks) or "none"))
    return ks


def manifest(app, path):
    p = Path(path)
    xml = p.read_text(encoding="utf-8")
    add = []
    for n in android_names(app):
        if f'"android.permission.{n}"' not in xml:
            add.append(f'    <uses-permission android:name="android.permission.{n}" />')
    ks = approved(app)
    # A permission alone would hide the app from phones without the hardware; make it optional.
    if "CAMERA" in ks and '"android.hardware.camera"' not in xml:
        add.append('    <uses-feature android:name="android.hardware.camera" android:required="false" />')
    if any(k in ks for k in ("LOCATION", "BACKGROUND_LOCATION")) and '"android.hardware.location.gps"' not in xml:
        add.append('    <uses-feature android:name="android.hardware.location.gps" android:required="false" />')
    if add:
        xml = re.sub(r"(\s*)<application\b", lambda m: "\n" + "\n".join(add) + m.group(1) + "<application", xml, count=1)
        p.write_text(xml, encoding="utf-8")
    print("Android permissions: " + ", ".join(sorted(set(re.findall(r'"android\.permission\.([A-Z_]+)"', xml)))))
    warn_unapproved(app)


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "list" and a:
        print("\n".join(approved(a[0])))
    elif cmd == "needs" and a:
        print("\n".join(needs(a[0])))
    elif cmd == "save" and a:
        req = Path(a[1]).read_text(encoding="utf-8") if len(a) > 1 and Path(a[1]).exists() else ""
        save(a[0], req)
    elif cmd == "manifest" and len(a) == 2:
        manifest(a[0], a[1])
    elif cmd == "flet" and a:
        warn_unapproved(a[0])
        print(" ".join(f"android.permission.{n}=true" for n in android_names(a[0])))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
