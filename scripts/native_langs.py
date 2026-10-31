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
            # Checked together with `flutter analyze` on Flutter 3.47. google_fonts 9 is left out:
            # it fails to compile there (TextTheme type mismatch) and needs the network at runtime.
            "provider", "shared_preferences", "http", "intl",
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
            "In Flet 1.x the helpers are classes, not modules: `ft.Padding.all/only/symmetric`, `ft.Margin.only`, "
            "`ft.Border.all`, `ft.BorderRadius.all`, `ft.Alignment.CENTER` / `ft.Alignment.TOP_LEFT` (NOT "
            "`ft.padding.only`, `ft.alignment.center`, `ft.border_radius.all`); "
            "`ft.MainAxisAlignment.SPACE_BETWEEN` (there is no BETWEEN). "
            "Buttons take `content=` (there is no `text=`), `ft.Tab(label=...)`, `ft.Dropdown(on_select=...)`; "
            "show dialogs and snack bars with `page.show_dialog(x)` and close them with `page.pop_dialog()` "
            "(there is no page.open/page.close/page.snack_bar). "
            "Use Material 3 with `page.theme = ft.Theme(color_scheme_seed=...)` and set `page.theme_mode`. "
            "Store data with sqlite3 or json from the standard library, in the app's writable folder: "
            "`os.path.join(os.getenv(\"FLET_APP_STORAGE_DATA\", \".\"), \"app.db\")` (never a bare relative path). "
            "Besides flet and the standard library you MAY use only these PyPI packages: {deps}. "
            "List every one you import in \"deps\". "
            "If the description is Arabic, set `page.rtl = True` and write Arabic texts."
        ),
    },
}


def reply_format(blocks):
    """Instructions for a reply made of fenced code blocks and a DEPS line (no JSON to escape)."""
    lines = [f"{i}. one ```{fence} code block with {what}" for i, (fence, what) in enumerate(blocks, start=1)]
    lines.append(f"{len(blocks) + 1}. a last line: `DEPS: ` followed by the allowed packages the code uses, "
                 "comma separated, or `DEPS: none`")
    return "Reply in exactly this format, nothing else:\n" + "\n".join(lines)


def parse_reply(text):
    """Return ({fence language: code}, deps list or None) from a reply in reply_format."""
    import json
    import re

    blocks = {}
    for m in re.finditer(r"```([\w+-]*)[ \t]*\n(.*?)\n```", text, re.S):
        blocks.setdefault(m.group(1).lower(), m.group(2).strip())
    rest = re.sub(r"```.*?```", "", text, flags=re.S)
    deps = None
    m = re.search(r"^\s*`?DEPS:\s*(.*?)`?\s*$", rest, re.M | re.I)
    if m:
        value = m.group(1).strip()
        deps = [] if value.lower() in ("", "none") else [d.strip() for d in value.split(",") if d.strip()]
    if not blocks:
        # Older JSON-style reply.
        try:
            data = json.loads(re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip()))
            for key, value in data.items():
                if key == "deps":
                    deps = value
                elif isinstance(value, str):
                    blocks[{"main_dart": "dart", "main_py": "python", "preview_html": "html"}.get(key, key)] = value
        except (ValueError, AttributeError):
            pass
    return blocks, deps


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
