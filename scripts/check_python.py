"""Fast static check for a generated Flet app, run before the slow APK build.

Usage: python check_python.py [--fix] path/to/main.py

Finds what would fail the build or crash the app when it opens:
- syntax errors;
- `ft.Something` that does not exist in the installed Flet (e.g. the pre-1.0 API);
- unknown keyword arguments, e.g. `ft.Button(text=...)` (1.x: `content=`);
- `page.something` that the Flet 1.x Page does not have, e.g. `page.open(dialog)`.
Each problem comes with the correct name when one can be found. With --fix,
unambiguous corrections are written back to the file first, so only real
problems are left for the AI.
"""
import ast
import dataclasses
import difflib
import inspect
import re
import sys
from pathlib import Path

# Names Flet 1.0 removed, with their replacement.
RENAMED = {"ElevatedButton": "Button"}
# Keyword arguments renamed in 1.0; the first one the target accepts is used.
KWARG_RENAMED = {"text": ["content", "label"], "on_change": ["on_select"]}
# Page members renamed in 1.0: (replacement, safe to rewrite automatically).
PAGE_RENAMED = {
    "open": ("show_dialog", True),
    "show_snack_bar": ("show_dialog", True),
    "on_resized": ("on_resize", True),
    "close": ("pop_dialog() (takes no argument)", False),
    "go": ("page.run_task(page.push_route, ...) (push_route is async)", False),
    "snack_bar": ("page.show_dialog(ft.SnackBar(...))", False),
    "dialog": ("page.show_dialog(dialog)", False),
    "client_storage": ("sqlite3/json under FLET_APP_STORAGE_DATA", False),
}


def checkable(obj):
    # Modules, classes, and lazy proxies such as ft.Icons.
    return inspect.ismodule(obj) or inspect.isclass(obj) or type(obj).__name__.endswith("Proxy")


def camel(name):
    return "".join(p[:1].upper() + p[1:] for p in name.split("_"))


def attr_chain(node):
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
        return list(reversed(parts))
    return None


def accepted_kwargs(obj):
    """Keyword names a Flet class or function accepts, or None when unknown/open-ended."""
    try:
        params = inspect.signature(obj).parameters
    except (TypeError, ValueError):
        params = None
    if params is not None and not any(p.kind == p.VAR_KEYWORD for p in params.values()):
        return set(params)
    if inspect.isclass(obj) and dataclasses.is_dataclass(obj):
        return {f.name for f in dataclasses.fields(obj) if f.init}
    return None


def suggest_attr(flet, chain, i, parent):
    """Return (correct dotted name, sure) for chain[i] missing on parent, or (None, False)."""
    part = chain[i]
    if i == 1 and part in RENAMED:
        return ".".join([chain[0], RENAMED[part]] + chain[2:]), True
    # Flet 1.0 moved helpers from modules to classes: ft.padding.only -> ft.Padding.only,
    # ft.alignment.center -> ft.Alignment.CENTER, ft.border_radius.all -> ft.BorderRadius.all.
    if inspect.ismodule(parent) and i == 2:
        new = camel(chain[1])
        cls = getattr(flet, new, None)
        if cls is not None and checkable(cls):
            for name in (part, part.upper(), part.lower()):
                if hasattr(cls, name):
                    return ".".join([chain[0], new, name] + chain[i + 1:]), True
    return close_match(part, [n for n in dir(parent) if not n.startswith("_")],
                       lambda m: ".".join(chain[:i] + [m] + chain[i + 1:]))


def close_match(part, names, build):
    by_case = [n for n in names if n.lower() == part.lower()]
    if len(by_case) == 1:
        return build(by_case[0]), True
    # A shortened enum name: BETWEEN -> SPACE_BETWEEN.
    by_suffix = [n for n in names if n.upper().endswith("_" + part.upper())]
    if len(by_suffix) == 1:
        return build(by_suffix[0]), True
    close =difflib.get_close_matches(part, names, n=2, cutoff=0.6)
    if not close:
        close = [n for n in names if part.upper() in n.upper()][:2]
    if close:
        sure = len(close) == 1 and difflib.SequenceMatcher(None, part, close[0]).ratio() >= 0.75
        return build(close[0]), sure
    return None, False


def problem(line, wrong, fixed, sure, edit):
    # edit: (line, col, old text, new text) applied by --fix when sure.
    return {"line": line, "wrong": wrong, "fixed": fixed, "sure": sure, "edit": edit}


def check(source):
    tree = ast.parse(source)
    aliases = {a.asname or "flet" for n in ast.walk(tree) if isinstance(n, ast.Import)
               for a in n.names if a.name == "flet"}
    if not aliases:
        return [problem(1, "import flet", "import flet as ft", False, None)]

    import flet

    problems = []
    inner = {id(c) for n in ast.walk(tree) if isinstance(n, ast.Attribute)
             for c in ast.iter_child_nodes(n) if isinstance(c, ast.Attribute)}

    def resolve(chain, node):
        """Walk ft.A.B..., report the first missing name; return the object or None."""
        obj = flet
        for i, part in enumerate(chain[1:], start=1):
            # Only modules, classes and proxies are checked; instance attributes are left alone.
            if not checkable(obj):
                return None
            if not hasattr(obj, part):
                if id(node) not in inner:
                    fixed, sure = suggest_attr(flet, chain, i, obj)
                    problems.append(problem(node.lineno, ".".join(chain[: i + 1]), fixed, sure,
                                            (node.lineno, None, ".".join(chain), fixed)))
                return None
            obj = getattr(obj, part)
        return obj

    # 1. ft.X names
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and id(node) not in inner:
            chain = attr_chain(node)
            if chain and chain[0] in aliases:
                resolve(chain, node)

    # 2. keyword arguments of ft.X(...) calls
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        chain = attr_chain(node.func)
        if not chain or chain[0] not in aliases or len(chain) < 2:
            continue
        obj = flet
        for part in chain[1:]:
            obj = getattr(obj, part, None)
            if obj is None:
                break
        names = accepted_kwargs(obj) if obj is not None else None
        if not names:
            continue
        for kw in node.keywords:
            if kw.arg is None or kw.arg in names:
                continue
            target = ".".join(chain)
            renamed = next((n for n in KWARG_RENAMED.get(kw.arg, []) if n in names), None)
            if renamed:
                fixed, sure = renamed, True
            else:
                fixed, sure = close_match(kw.arg, sorted(names), lambda m: m)
                sure = sure and fixed is not None
            problems.append(problem(kw.lineno, f"{target}({kw.arg}=...)", fixed and f"{fixed}=", sure,
                                    (kw.lineno, kw.col_offset, kw.arg, fixed)))

    # 3. page.X on the Flet Page (parameters annotated ft.Page, or named `page`)
    page_names = {"page"}
    for node in ast.walk(tree):
        if isinstance(node, ast.arg) and node.annotation is not None:
            ann = attr_chain(node.annotation)
            if ann and len(ann) == 2 and ann[0] in aliases and ann[1] == "Page":
                page_names.add(node.arg)
    page_attrs = set(dir(flet.Page)) | {f.name for f in dataclasses.fields(flet.Page)}
    seen = set()
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name)
                and node.value.id in page_names):
            continue
        if node.attr in page_attrs or node.attr.startswith("_"):
            continue
        key = (node.lineno, node.attr)
        if key in seen:
            continue
        seen.add(key)
        full = f"{node.value.id}.{node.attr}"
        if node.attr in PAGE_RENAMED:
            new, sure = PAGE_RENAMED[node.attr]
            fixed = f"{node.value.id}.{new}" if sure else new
        else:
            fixed, sure = close_match(node.attr, sorted(page_attrs),
                                      lambda m, n=node.value.id: f"{n}.{m}")
        problems.append(problem(node.lineno, full, fixed, sure, (node.lineno, None, full, fixed)))

    return problems


def apply_fixes(path, source, problems):
    lines = source.split("\n")
    changed = 0
    # Right-most edits first so column offsets on the same line stay valid.
    edits = sorted((p["edit"] for p in problems if p["sure"] and p["fixed"] and p["edit"]),
                   key=lambda e: (e[0], e[1] if e[1] is not None else -1), reverse=True)
    for lineno, col, old, new in edits:
        line = lines[lineno - 1]
        if col is not None:
            # A keyword argument: `old=` starting exactly at col (in characters).
            if line[col:col + len(old)] == old:
                lines[lineno - 1] = line[:col] + new + line[col + len(old):]
                changed += 1
            continue
        pattern = r"(?<![\w.])" + re.escape(old) + r"(?!\w)"
        updated = re.sub(pattern, new, line)
        if updated != line:
            lines[lineno - 1] = updated
            changed += 1
    if changed:
        path.write_text("\n".join(lines), encoding="utf-8")
    return changed


def main():
    args = sys.argv[1:]
    fix = "--fix" in args
    path = Path([a for a in args if a != "--fix"][0])
    source = path.read_text(encoding="utf-8")
    try:
        problems = check(source)
        if fix and problems:
            changed = apply_fixes(path, source, problems)
            if changed:
                print(f"Auto-fixed {changed} place(s) to the Flet 1.x API")
                problems = check(path.read_text(encoding="utf-8"))
    except SyntaxError as e:
        print("error: Flet check failed:")
        print(f"error: SyntaxError line {e.lineno}: {e.msg}")
        sys.exit(1)

    if problems:
        import flet
        print("error: Flet check failed:")
        shown = set()
        for p in sorted(problems, key=lambda p: p["line"]):
            if (p["line"], p["wrong"]) in shown:
                continue
            shown.add((p["line"], p["wrong"]))
            hint = f" (use `{p['fixed']}`)" if p["fixed"] else ""
            print(f"error: line {p['line']}: `{p['wrong']}` does not exist in Flet {flet.__version__}{hint}")
        sys.exit(1)
    print("Flet check passed")


if __name__ == "__main__":
    main()
