"""Shared settings for the native app languages (Flutter and Python/Flet)."""

FLET_VERSION = "1.0.5"

LANGS = {
    "flutter": {
        "title": "Flutter",
        "request_file": "request-flutter.txt",
        "code_file": "lib/main.dart",
        "code_key": "main_dart",
        "fence": "dart",
        "deps_file": "packages.txt",
        # Well-known, pure-Dart (or federated, no extra setup) pub.dev packages.
        "allowed_deps": [
            "provider", "shared_preferences", "http", "intl", "google_fonts",
            "fl_chart", "url_launcher", "flutter_animate", "uuid", "path_provider",
            "sqflite", "go_router", "cached_network_image", "flutter_svg",
        ],
        "rules": (
            "Write a Flutter app in a single file lib/main.dart, with Material 3 (useMaterial3: true), "
            "a modern ColorScheme.fromSeed theme with both light and dark themes, null safety, "
            "and clean widget structure (StatelessWidget/StatefulWidget classes, no giant build methods). "
            "You MAY use these pub.dev packages when they clearly help, and only these: {deps}. "
            "List every package you import in \"deps\". Never import any other package. "
            "If the description is Arabic, make the UI RTL (Directionality / locale) and texts Arabic."
        ),
    },
    "python": {
        "title": "Python (Flet)",
        "request_file": "request-python.txt",
        "code_file": "main.py",
        "code_key": "main_py",
        "fence": "python",
        "deps_file": "requirements.txt",
        "allowed_deps": ["requests", "python-dateutil", "pytz"],
        "rules": (
            f"Write a mobile app in Python using Flet {FLET_VERSION} (the Flet 1.x API), in a single file main.py. "
            "Rules for the Flet 1.x API: start the app with `ft.run(main)` where `def main(page: ft.Page)`; "
            "use `ft.Colors.X` and `ft.Icons.X` (capitalized enums); use `ft.Button`, `ft.FilledButton`, "
            "`ft.OutlinedButton`, `ft.TextButton`, `ft.IconButton` (there is NO ElevatedButton); "
            "use `ft.NavigationBar` with `ft.NavigationBarDestination` for tabs; call `page.update()` after changes. "
            "Use Material 3 with `page.theme = ft.Theme(color_scheme_seed=...)` and set `page.theme_mode`. "
            "Store data with `page.client_storage` or sqlite3 from the standard library. "
            "Besides flet and the standard library you MAY use only these PyPI packages: {deps}. "
            "List every one you import in \"deps\". "
            "If the description is Arabic, set `page.rtl = True` and write Arabic texts."
        ),
    },
}


def gemini_keys(environ):
    return [k for k in (environ.get("GEMINI_API_KEY"), environ.get("GEMINI_API_KEY_2"),
                        environ.get("GEMINI_API_KEY_3")) if k]


def clean_deps(lang, deps):
    """Keep only allowed packages, in a stable order, without duplicates."""
    allowed = LANGS[lang]["allowed_deps"]
    wanted = {str(d).strip().lower() for d in (deps or [])}
    return [d for d in allowed if d in wanted]


def write_deps(lang, app_dir, deps):
    path = app_dir / LANGS[lang]["deps_file"]
    if lang == "python":
        lines = [f"flet=={FLET_VERSION}"] + deps
    else:
        lines = deps
    path.write_text("".join(f"{line}\n" for line in lines), encoding="utf-8")


def read_deps(lang, app_dir):
    path = app_dir / LANGS[lang]["deps_file"]
    if not path.exists():
        return []
    names = [l.strip().split("==")[0].lower() for l in path.read_text(encoding="utf-8").splitlines()]
    return clean_deps(lang, names)
