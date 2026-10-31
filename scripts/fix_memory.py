"""Remembered fixes: an error fixed once by the AI is fixed without AI the next time.

Rules live in fixes/<lang>.json at the repo root, e.g.
    {"old": "MainAxisAlignment.between", "new": "MainAxisAlignment.spaceBetween",
     "error": "There's no constant named 'between'...", "source": "seed", "uses": 3}

- apply(): before asking the AI, replace `old` with `new`, but only on the lines the
  analyzer / checker / build log reports, so healthy code is never touched.
- learn(): after an AI fix, each small one-line replacement it made on a reported
  line becomes a new rule.
- forget(): callers that re-check the code drop rules that did not help.
"""
import difflib
import json
import re
from pathlib import Path

FIXES_DIR = Path(__file__).resolve().parent.parent / "fixes"
MAX_RULES = 400
TOKEN = re.compile(r"\w+|[^\w\s]")
ERROR_LINE = re.compile(r"main\.(?:dart|py)\"?(?:, line |:)(\d+)|\bline (\d+)")


def _path(lang):
    return FIXES_DIR / f"{lang}.json"


def load(lang):
    try:
        return json.loads(_path(lang).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def save(lang, rules):
    FIXES_DIR.mkdir(exist_ok=True)
    _path(lang).write_text(json.dumps(rules[:MAX_RULES], ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def error_lines(log_text):
    """Line numbers of main.dart / main.py that the errors point at."""
    found = set()
    for m in ERROR_LINE.finditer(log_text):
        found.add(int(m.group(1) or m.group(2)))
    return found


def _pattern(old):
    # Word boundaries only where the rule starts/ends with a word character (`.caption` matches `t.caption`).
    left = r"(?<![\w])" if re.match(r"\w", old) else ""
    right = r"(?!\w)" if re.search(r"\w$", old) else ""
    return re.compile(left + re.escape(old) + right)


def apply(lang, code_path, log_text):
    """Apply remembered rules on the reported lines. Returns the `old` of each rule used."""
    lines_wanted = error_lines(log_text)
    rules = load(lang)
    if not lines_wanted or not rules:
        return []
    code_path = Path(code_path)
    lines = code_path.read_text(encoding="utf-8").split("\n")
    used = []
    for n in sorted(lines_wanted):
        if not 1 <= n <= len(lines):
            continue
        for rule in rules:
            new_line = _pattern(rule["old"]).sub(lambda _m, r=rule: r["new"], lines[n - 1])
            if new_line != lines[n - 1]:
                lines[n - 1] = new_line
                rule["uses"] = rule.get("uses", 0) + 1
                if rule["old"] not in used:
                    used.append(rule["old"])
    if used:
        code_path.write_text("\n".join(lines), encoding="utf-8")
        save(lang, rules)
        print(f"Fixed without AI using {len(used)} remembered rule(s): {', '.join(used)}", flush=True)
    return used


def forget(lang, olds):
    """Drop learned rules that did not help (seed rules are kept)."""
    rules = load(lang)
    kept = [r for r in rules if r["old"] not in olds or r.get("source") == "seed"]
    if len(kept) != len(rules):
        save(lang, kept)
        print(f"Forgot {len(rules) - len(kept)} rule(s) that did not help", flush=True)


def _balanced(text):
    return all(text.count(a) == text.count(b) for a, b in ("()", "[]", "{}")) and text.count('"') % 2 == 0 \
        and text.count("'") % 2 == 0


def _fragment(line, spans, a, b):
    if a >= b:
        return ""
    return line[spans[a][0]:spans[b - 1][1]]


def _rule_from_lines(old_line, new_line):
    """A small replacement that turns old_line into new_line, or None if it isn't a safe rule."""
    old_toks = [(m.group(), m.span()) for m in TOKEN.finditer(old_line)]
    new_toks = [(m.group(), m.span()) for m in TOKEN.finditer(new_line)]
    ops = [op for op in difflib.SequenceMatcher(None, [t for t, _ in old_toks], [t for t, _ in new_toks],
                                               autojunk=False).get_opcodes() if op[0] != "equal"]
    if len(ops) != 1 or ops[0][0] != "replace":
        return None
    _, a1, a2, b1, b2 = ops[0]
    # Widen to the left over `Name.` so the rule is specific: between -> MainAxisAlignment.between.
    steps = 0
    while a1 > 0 and b1 > 0 and steps < 4 and (old_toks[a1 - 1][0] == "." or old_toks[a1 - 1][0].isidentifier()):
        a1, b1, steps = a1 - 1, b1 - 1, steps + 1
        if old_toks[a1][0] != "." and (a1 == 0 or old_toks[a1 - 1][0] != "."):
            break
    # Keep a trailing `(` or `:` with the name so `primary:` / `foo(` stay specific.
    if a2 < len(old_toks) and b2 < len(new_toks) and old_toks[a2][0] in "(:" and new_toks[b2][0] == old_toks[a2][0]:
        a2, b2 = a2 + 1, b2 + 1
    old = _fragment(old_line, [s for _, s in old_toks], a1, a2)
    new = _fragment(new_line, [s for _, s in new_toks], b1, b2)
    if (not old or old == new or len(old) < 8 or not re.search(r"[A-Za-z]", old)
            or not _balanced(old) or not _balanced(new)):
        return None
    return old, new


def learn(lang, before, after, log_text):
    """Remember the AI's one-line fixes on reported lines. Returns how many rules were added."""
    wanted = error_lines(log_text)
    if not wanted:
        return 0
    old_lines, new_lines = before.rstrip("\n").split("\n"), after.rstrip("\n").split("\n")
    rules = load(lang)
    known = {r["old"] for r in rules}
    added = 0
    pairs = []
    sm = difflib.SequenceMatcher(None, old_lines, new_lines, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "replace":
            continue
        for i in range(i1, i2):
            if i + 1 not in wanted:
                continue
            # The changed line is the most similar one in the replaced block.
            best = max(range(j1, j2), key=lambda j: difflib.SequenceMatcher(None, old_lines[i], new_lines[j]).ratio())
            if difflib.SequenceMatcher(None, old_lines[i], new_lines[best]).ratio() >= 0.6:
                pairs.append((i, best))
    for i, j in pairs:
        rule = _rule_from_lines(old_lines[i], new_lines[j])
        if not rule or rule[0] in known:
            continue
        msg = next((l.strip() for l in log_text.splitlines() if re.search(rf"\b{i + 1}\b", l)), "")
        rules.append({"old": rule[0], "new": rule[1], "error": msg[:200], "source": "ai", "uses": 0})
        known.add(rule[0])
        added += 1
    if added:
        save(lang, rules)
        print(f"Learned {added} new fix rule(s); next time they are fixed without AI", flush=True)
    return added
