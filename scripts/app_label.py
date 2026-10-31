"""The name shown under the app icon (can be Arabic), kept in apps/<app>/display-name.txt.

    python scripts/app_label.py get APP            -> prints the name (the folder name when none is set)
    python scripts/app_label.py set APP NAME       -> writes display-name.txt
    python scripts/app_label.py android RES APP    -> puts it in RES/values/strings.xml (app_name)
    python scripts/app_label.py manifest FILE      -> makes AndroidManifest.xml use @string/app_name
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILE = "display-name.txt"


def clean(name):
    # Characters that would need escaping in Android resources or shell commands are dropped.
    name = re.sub(r"[<>&\"'`\\$@?#%;|{}\[\]\n\r\t]", "", name or "")
    return re.sub(r"\s+", " ", name).strip()[:40]


def get(app):
    p = ROOT / "apps" / app / FILE
    name = clean(p.read_text(encoding="utf-8")) if p.exists() else ""
    return name or app


def set_name(app, name):
    name = clean(name)
    p = ROOT / "apps" / app / FILE
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(name + "\n", encoding="utf-8")
    return name


def android(res, app):
    name = get(app)
    values = Path(res) / "values"
    values.mkdir(parents=True, exist_ok=True)
    strings = values / "strings.xml"
    xml = strings.read_text(encoding="utf-8") if strings.exists() else '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n'
    for key in ("app_name", "title_activity_main"):
        line = f'<string name="{key}">{name}</string>'
        if re.search(rf'<string name="{key}"[^>]*>.*?</string>', xml, re.S):
            xml = re.sub(rf'<string name="{key}"[^>]*>.*?</string>', line, xml, flags=re.S)
        elif key == "app_name":
            xml = xml.replace("</resources>", f"    {line}\n</resources>")
    strings.write_text(xml, encoding="utf-8")
    print(f"App name on the phone: {name}")


def manifest(path):
    p = Path(path)
    xml = p.read_text(encoding="utf-8")
    xml = re.sub(r'(<application\b[^>]*?android:label=")[^"]*(")', r"\1@string/app_name\2", xml, count=1, flags=re.S)
    p.write_text(xml, encoding="utf-8")


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "get":
        print(get(a[0]))
    elif cmd == "set":
        print(set_name(a[0], a[1]))
    elif cmd == "android":
        android(a[0], a[1])
    elif cmd == "manifest":
        manifest(a[0])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
