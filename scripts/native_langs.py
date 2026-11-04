"""Shared settings for the native app languages (Flutter, Python/Flet and Kotlin/Compose)."""

from pathlib import Path

FLET_VERSION = "1.0.5"

# One design bar for every language, shared with generate.js and the app (services/designBrief.ts).
def _design_brief():
    import json
    src = (Path(__file__).resolve().parent.parent / "services" / "designBrief.ts").read_text(encoding="utf-8")
    return json.loads(src.split("export const DESIGN_BRIEF = ", 1)[1].rsplit(";", 1)[0])


DESIGN_BRIEF = _design_brief()

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
            # Push for connected app pairs (initialized from lib/firebase_config.dart, no Gradle plugin).
            "firebase_core", "firebase_messaging",
            # Camera / gallery and location; they ask Android for the permission themselves (scripts/perms.py adds
            # it to the manifest).
            "image_picker", "geolocator",
        ],
        "rules": (
            "Write a Flutter app in a single file lib/main.dart, with Material 3 (useMaterial3: true), "
            "a modern ColorScheme.fromSeed theme with both light and dark themes, null safety, "
            "and clean widget structure (StatelessWidget/StatefulWidget classes, no giant build methods). "
            "You MAY use these pub.dev packages when they clearly help, and only these: {deps}. "
            "List every package you import in \"deps\". Never import any other package. "
            "If the description is Arabic, make the UI RTL (Directionality / locale) and texts Arabic. "
            "Phone permissions are asked at the moment a feature needs them, never all at start-up: photos with "
            "image_picker (ImagePicker().pickImage(source: ImageSource.camera or .gallery) shows Android's own "
            "permission prompt); location with geolocator (Geolocator.checkPermission() then "
            "Geolocator.requestPermission(); handle denied and deniedForever with an Arabic message and a button "
            "that opens Geolocator.openAppSettings()); notifications with FirebaseMessaging.instance."
            "requestPermission(). When the user refuses, the app keeps working and explains in Arabic what needs it."
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
    "kotlin": {
        "title": "Kotlin (Jetpack Compose)",
        "request_file": "request-kotlin.txt",
        "code_file": "MainActivity.kt",
        "code_key": "main_kt",
        "fence": "kotlin",
        "deps_file": None,  # every library below is already in the project (scripts/templates/kotlin)
        "allowed_deps": [],
        "rules": (
            "Write a native Android app in Kotlin with Jetpack Compose and Material 3, in a single file "
            "MainActivity.kt whose first line is `package app.main`. "
            "`class MainActivity : ComponentActivity()` overrides `onCreate(savedInstanceState: Bundle?)`, calls "
            "`super.onCreate(savedInstanceState)`, then `enableEdgeToEdge()`, then `setContent { AppTheme { App() } }`. "
            "The project already contains exactly these libraries (Compose BOM 2024.12, Kotlin 2.0) and NOTHING else: "
            "androidx.compose.ui / foundation / animation / material3, androidx.compose.material.icons (core and "
            "extended: Icons.Filled.X, Icons.Outlined.X, Icons.Rounded.X, Icons.AutoMirrored.Filled.ArrowBack), "
            "androidx.activity.compose, androidx.navigation.compose (NavHost, composable, rememberNavController), "
            "androidx.lifecycle.viewmodel.compose and lifecycle-runtime-compose, kotlinx.coroutines, okhttp3, "
            "org.json, coil.compose.AsyncImage, and the Android SDK. Do NOT use Room, Hilt, kapt, ksp, "
            "kotlinx.serialization, Retrofit, Gson, Accompanist, AppCompat, XML layouts or any R.drawable/R.string "
            "resource. Experimental Material 3 / foundation APIs are already opted in (no @OptIn needed). "
            "Write every import explicitly (no wildcard imports) and only import what you use. "
            "Build the theme yourself: `@Composable fun AppTheme(content: @Composable () -> Unit)` with "
            "lightColorScheme/darkColorScheme from your palette and isSystemInDarkTheme(). "
            "State: remember / mutableStateOf / mutableStateListOf (with `import androidx.compose.runtime.getValue` and "
            "`setValue` when using `by`), or a ViewModel. Save data with SharedPreferences (JSON strings via org.json) "
            "so it survives restarts. Network calls only inside coroutines on Dispatchers.IO. "
            "Use Scaffold with TopAppBar/CenterAlignedTopAppBar, NavigationBar + NavigationBarItem for tabs, "
            "LazyColumn/LazyVerticalGrid for lists, Card, ElevatedCard, OutlinedTextField, FilterChip, "
            "AlertDialog, ModalBottomSheet, SnackbarHost. Use Modifier.padding(innerPadding) from the Scaffold. "
            "If the description is Arabic, wrap the app in "
            "`CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl)` and write Arabic texts."
        ),
    },
}


def rules_for(lang):
    """The language rules with the allowed packages filled in. Plain replace, not str.format: the Kotlin
    rules contain code with { } braces."""
    cfg = LANGS[lang]
    return cfg["rules"].replace("{deps}", ", ".join(cfg["allowed_deps"]) or "none")


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
    if not LANGS[lang]["deps_file"]:
        return
    path = app_dir / LANGS[lang]["deps_file"]
    if lang == "python":
        lines = [f"flet=={FLET_VERSION}"] + deps
    else:
        lines = deps
    path.write_text("".join(f"{line}\n" for line in lines), encoding="utf-8")


def read_deps(lang, app_dir):
    if not LANGS[lang]["deps_file"]:
        return []
    path = app_dir / LANGS[lang]["deps_file"]
    if not path.exists():
        return []
    names = [l.strip().split("==")[0].lower() for l in path.read_text(encoding="utf-8").splitlines()]
    return clean_deps(lang, names)
