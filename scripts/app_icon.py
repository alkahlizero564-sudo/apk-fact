"""The app icon (apps/<app>/icon.png) as real PNG launcher icons in every Android density.

Icons picked on the phone are often JPEG files named icon.png, and any size; Android needs real PNGs.

    python scripts/app_icon.py android RES_DIR APP   -> RES_DIR/mipmap-*/ic_launcher.png (skips when no icon)
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def android(res, app):
    src = ROOT / "apps" / app / "icon.png"
    if not src.exists():
        print("No custom icon, using the default")
        return False
    try:
        from PIL import Image
        with Image.open(src) as im:
            im = im.convert("RGBA")
            side = min(im.size)
            left, top = (im.width - side) // 2, (im.height - side) // 2
            square = im.crop((left, top, left + side, top + side))
            for density, px in SIZES.items():
                d = Path(res) / f"mipmap-{density}"
                d.mkdir(parents=True, exist_ok=True)
                square.resize((px, px), Image.LANCZOS).save(d / "ic_launcher.png", "PNG")
    except Exception as e:  # unreadable image: keep the default icon instead of failing the build
        print(f"::warning::The app icon could not be used ({e}); using the default icon")
        return False
    # An adaptive icon would win over the PNGs on Android 8+; the custom icon must be the one shown.
    for xml in Path(res).glob("mipmap-anydpi*/ic_launcher*.xml"):
        xml.unlink()
    print(f"Custom icon applied ({', '.join(f'{d} {p}px' for d, p in SIZES.items())})")
    return True


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "android" and len(a) == 2:
        android(a[0], a[1])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
