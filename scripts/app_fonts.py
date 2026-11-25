"""Bundles the app's professional Arabic font into the Flutter project before it is built.

The style the app uses (ui_kit.dart: appTheme(style: KitStyle.luxe|simple|modern)) picks the font:
  luxe   -> IBM Plex Sans Arabic (refined)     simple -> Almarai (very legible)     modern -> Tajawal (geometric)
The files come from Google Fonts' repository (OFL licence) and are cached between builds. They are registered as the
family 'AppFont', which ui_kit.dart's appTheme uses by default. Never fails a build: without the font, Flutter uses
the system font.

    python scripts/app_fonts.py <apps/APP> <flutter project dir>
"""
import re
import shutil
import sys
import urllib.request
from pathlib import Path

BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl"
FONTS = {
    "luxe": [("ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf", 400), ("ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf", 500),
             ("ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf", 600), ("ibmplexsansarabic/IBMPlexSansArabic-Bold.ttf", 700)],
    "simple": [("almarai/Almarai-Regular.ttf", 400), ("almarai/Almarai-Bold.ttf", 700), ("almarai/Almarai-ExtraBold.ttf", 800)],
    "modern": [("tajawal/Tajawal-Regular.ttf", 400), ("tajawal/Tajawal-Medium.ttf", 500), ("tajawal/Tajawal-Bold.ttf", 700),
               ("tajawal/Tajawal-ExtraBold.ttf", 800)],
}
CACHE = Path.home() / ".pub-cache" / "apkfact-fonts"  # ~/.pub-cache is cached by the build workflows


def style_of(app_dir):
    for f in sorted((Path(app_dir) / "lib").rglob("*.dart")):
        m = re.search(r"KitStyle\.(luxe|simple|modern)", f.read_text(encoding="utf-8", errors="ignore"))
        if m:
            return m.group(1)
    return "modern"


def bundle(app_dir, proj):
    app_dir, proj = Path(app_dir), Path(proj)
    if not (app_dir / "lib" / "ui_kit.dart").exists():
        return None  # only apps built on the design system ask for 'AppFont'
    style = style_of(app_dir)
    dest = proj / "assets" / "fonts"
    dest.mkdir(parents=True, exist_ok=True)
    entries = []
    for rel, weight in FONTS[style]:
        name = Path(rel).name
        cached = CACHE / name
        try:
            if not cached.exists():
                CACHE.mkdir(parents=True, exist_ok=True)
                with urllib.request.urlopen(f"{BASE}/{rel}", timeout=60) as r:
                    data = r.read()
                if len(data) < 10000:
                    raise ValueError("not a font file")
                cached.write_bytes(data)
            shutil.copy(cached, dest / name)
            entries.append((name, weight))
        except Exception as e:
            print(f"Font {name} not available ({e})", flush=True)
    if not entries:
        return None
    pubspec = proj / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    if "family: AppFont" not in text:
        block = "  fonts:\n    - family: AppFont\n      fonts:\n" + "".join(
            f"        - asset: assets/fonts/{n}\n" + (f"          weight: {w}\n" if w != 400 else "") for n, w in entries)
        if re.search(r"^flutter:\s*$", text, re.M):
            text = re.sub(r"^flutter:\s*$", "flutter:\n" + block.rstrip("\n"), text, count=1, flags=re.M)
        else:
            text = text.rstrip() + "\n\nflutter:\n" + block
        pubspec.write_text(text, encoding="utf-8")
    print(f"Font: {style} style -> {', '.join(n for n, _ in entries)}", flush=True)
    return style


if __name__ == "__main__":
    try:
        bundle(sys.argv[1], sys.argv[2])
    except Exception as e:  # never fails a build
        print(f"Fonts skipped ({e})")
