"""Behaviour checks: direct compositor calls, ungated repeating Timers and self-restarting Processes.

The checks read the item's QML, JavaScript and scripts without running anything. A finding is a
problem unless the item declares the matching `requires.windowManager` (compositor calls only) or
`tools/behaviour-allowlist.json` lists it with a reviewed reason.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any


ALLOWLIST = Path("tools") / "behaviour-allowlist.json"
SHORT_INTERVAL_MS = 1000
DEFAULT_INTERVAL_MS = 1000

_SCANNED_DIRS = ("qml", "bin")
_C_LIKE = {".qml", ".js", ".mjs", ".cjs"}
_HASH_COMMENT = {".sh", ".bash", ".zsh", ".py"}
_SHEBANG = re.compile(r"^#!")

# sway has no Ryoku provider so an item driving it can only declare it and stay unavailable
# the literal is a cheap check that skips the regex on most files
COMPOSITOR_PATTERNS: dict[str, tuple[tuple[str, str, re.Pattern[str]], ...]] = {
    "hyprland": (
        ("hyprctl", "hyprctl", re.compile(r"\bhyprctl\b")),
        ("import Quickshell.Hyprland", "Quickshell.Hyprland", re.compile(r"^[ \t]*import[ \t]+Quickshell\.Hyprland\b", re.MULTILINE)),
        ("HYPRLAND_INSTANCE_SIGNATURE", "HYPRLAND_INSTANCE_SIGNATURE", re.compile(r"\bHYPRLAND_INSTANCE_SIGNATURE\b")),
        ("Hyprland socket", ".sock", re.compile(r"\.socket2?\.sock\b")),
    ),
    "niri": (
        ("niri msg", "niri", re.compile(r"\bniri\b[\"'\s,]+msg\b")),
        ("NIRI_SOCKET", "NIRI_SOCKET", re.compile(r"\bNIRI_SOCKET\b")),
    ),
    "wayfire": (
        ("WAYFIRE_SOCKET", "WAYFIRE_SOCKET", re.compile(r"\bWAYFIRE_SOCKET\b")),
        ("wf-msg", "wf-msg", re.compile(r"\bwf-msg\b")),
        ("wayfire IPC", "ayfire", re.compile(r"\b[Ww]ayfire[-_.]?ipc\b")),
    ),
    "sway": (
        ("swaymsg", "swaymsg", re.compile(r"\bswaymsg\b")),
        ("SWAYSOCK", "SOCK", re.compile(r"\b(?:SWAYSOCK|I3SOCK)\b")),
        ("import Quickshell.I3", "Quickshell.I3", re.compile(r"^[ \t]*import[ \t]+Quickshell\.I3\b", re.MULTILINE)),
    ),
}

GATE_WORDS = (
    "visible", "hidden", "open", "shown", "show", "active", "expand", "hover", "containsmouse",
    "playing", "focus", "pressed", "drag", "moving", "animating", "recording", "loading", "busy",
    "pending", "inuse", "running", "count", "length", "needed", "want", "users", "pop",
)
# a restart guarded only by these loops for as long as the command keeps failing
EXIT_STATUS_WORDS = frozenset({
    "exitCode", "exitStatus", "code", "status", "Process", "NormalExit", "CrashExit", "QProcess",
    "undefined", "null", "true", "false",
})

_OBJECT = re.compile(r"(?<![\w.$])(?:[A-Za-z_]\w*\.)*(Timer|Process)\s*\{")
_STATEMENT = re.compile(
    r"^\s*(?:(?:readonly|required|default)\s+)*(?:property\s+[\w.<>]+\s+)?(?P<name>[A-Za-z_][\w.]*)\s*:(?P<value>.*)$",
    re.DOTALL,
)
_IDENT = re.compile(r"[A-Za-z_$][\w$]*")
_ARITHMETIC = re.compile(r"^[\d\s.+\-*/()%]+$")
_IF = re.compile(r"\bif\s*\(")
_EARLY_RETURN = re.compile(r"\bif\s*\((?P<cond>[^;{}]*)\)\s*return\b")


class BehaviourError(ValueError):
    pass


@dataclass(frozen=True)
class Finding:
    check: str  # "compositor", "timer" or "process"
    file: str  # item-relative path
    key: str  # compositor family, or the object's id / "Timer@<n>" / "Process@<n>"
    line: int
    detail: str


_C_TOKENS = re.compile(
    r"(?P<line>//[^\n]*)"
    r"|(?P<block>/\*.*?(?:\*/|\Z))"
    r"|(?P<string>\"(?:\\.|[^\"\\\n])*\"?|'(?:\\.|[^'\\\n])*'?|`(?:\\.|[^`\\])*`?)"
    # a regex literal follows an operator or an opening bracket, never a value
    r"|(?<=[(,=:\[!&|?{};])(?P<regex>[ \t]*/(?![/*])(?:\\.|\[(?:\\.|[^\]\\\n])*\]|[^/\\\n\[])+/)",
    re.DOTALL,
)
_NOT_NEWLINE = re.compile(r"[^\n]")


def _mask_c_like(text: str) -> tuple[str, str]:
    """Return (code, masked): comments blanked in both; string and regex bodies also blanked in masked.

    Newlines and offsets are preserved, so positions in either map to lines in the source."""
    code: list[str] = []
    masked: list[str] = []
    position = 0
    for match in _C_TOKENS.finditer(text):
        start, end = match.span()
        between = text[position:start]
        code.append(between)
        masked.append(between)
        token = match.group(0)
        if match.lastgroup in {"line", "block"}:
            blank = _NOT_NEWLINE.sub(" ", token)
            code.append(blank)
            masked.append(blank)
        else:
            opener = token.index(token.lstrip()[0]) + 1 if match.lastgroup == "regex" else 1
            closes = token.endswith(token[opener - 1]) and len(token) > opener
            inner_end = len(token) - 1 if closes else len(token)
            code.append(token)
            masked.append(token[:opener] + _NOT_NEWLINE.sub(" ", token[opener:inner_end]) + token[inner_end:])
        position = end
    code.append(text[position:])
    masked.append(text[position:])
    return "".join(code), "".join(masked)


def _strip_hash_comments(text: str) -> str:
    lines: list[str] = []
    for line in text.split("\n"):
        quote = ""
        cut = len(line)
        for index, ch in enumerate(line):
            if quote:
                if ch == "\\" and quote == '"':
                    continue
                if ch == quote:
                    quote = ""
            elif ch in "\"'":
                quote = ch
            elif ch == "#" and (index == 0 or line[index - 1].isspace()) and not line.startswith("#!"):
                cut = index
                break
        lines.append(line[:cut])
    return "\n".join(lines)


def _line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


_NEEDLES = tuple({needle for patterns in COMPOSITOR_PATTERNS.values() for _label, needle, _pattern in patterns} | {"Timer", "Process"})


def scanned_files(item_dir: Path, files: list[tuple[str, Path]]) -> list[tuple[str, str, str, str]]:
    """(relative, kind, code, masked) for every QML, JavaScript and script file under qml/ and bin/
    that mentions a compositor or a Timer or Process (no other file can produce a finding)."""
    result: list[tuple[str, str, str, str]] = []
    for relative, path in files:
        if relative.split("/", 1)[0] not in _SCANNED_DIRS:
            continue
        suffix = path.suffix.lower()
        if suffix not in _C_LIKE and suffix not in _HASH_COMMENT and suffix:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        if not any(needle in text for needle in _NEEDLES):
            continue
        if suffix in _C_LIKE:
            code, masked = _mask_c_like(text)
            result.append((relative, "qml" if suffix == ".qml" else "js", code, masked))
        elif suffix in _HASH_COMMENT or _SHEBANG.match(text):
            code = _strip_hash_comments(text)
            result.append((relative, "script", code, code))
    return result


def compositor_findings(sources: list[tuple[str, str, str, str]]) -> list[Finding]:
    findings: list[Finding] = []
    for relative, _kind, code, _masked in sources:
        for family, patterns in COMPOSITOR_PATTERNS.items():
            for label, needle, pattern in patterns:
                if needle not in code:
                    continue
                match = pattern.search(code)
                if match is not None:
                    findings.append(Finding("compositor", relative, family, _line(code, match.start()), label))
                    break
    return findings


@dataclass
class _Object:
    type: str
    start: int  # offset of the type name
    body: tuple[int, int]  # offsets inside the braces
    props: dict[str, str]  # top-level `name: value` statements, comment-free source text


def _matching(masked: str, open_index: int) -> int:
    depth = 0
    for index in range(open_index, len(masked)):
        ch = masked[index]
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
            if depth == 0:
                return index
    return len(masked)


_CONTINUES = tuple("&|+-*/%=<>?:,.!")


def _statements(code: str, masked: str, start: int, end: int) -> dict[str, str]:
    """Top-level `name: value` statements of an object body. A newline ends a statement unless the
    line ends in an operator or the next line starts with one (a binding split over lines)."""
    props: dict[str, str] = {}
    depth = 0
    begin = start
    for index in range(start, end + 1):
        ch = masked[index] if index < end else "\n"
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif depth == 0 and ch in "\n;":
            text = masked[begin:index]
            if ch == "\n" and index < end:
                following = masked[index + 1:end].lstrip()
                if text.rstrip().endswith(_CONTINUES) or following.startswith(_CONTINUES):
                    if text.strip():
                        continue
            match = _STATEMENT.match(text)
            if match is not None:
                props.setdefault(match.group("name"), code[begin + match.start("value"):index].strip())
            begin = index + 1
    return props


def qml_objects(code: str, masked: str) -> list[_Object]:
    objects: list[_Object] = []
    for match in _OBJECT.finditer(masked):
        open_index = match.end() - 1
        close = _matching(masked, open_index)
        objects.append(_Object(match.group(1), match.start(1), (open_index + 1, close),
                               _statements(code, masked, open_index + 1, close)))
    return objects


def _literal(value: str | None) -> str | None:
    return None if value is None else value.strip().rstrip(";").strip()


def _evaluate(expression: str) -> float | None:
    if not _ARITHMETIC.fullmatch(expression.strip() or "x") or "**" in expression:
        return None
    try:
        value = eval(compile(ast.parse(expression.strip(), mode="eval"), "<interval>", "eval"), {"__builtins__": {}}, {})
    except (SyntaxError, ZeroDivisionError, TypeError, ValueError):
        return None
    return float(value) if isinstance(value, (int, float)) else None


def _branches(expression: str) -> list[str]:
    """Split `a ? b : c` (nested on either side) into its value branches; anything else is one branch."""
    expression = expression.strip()
    _code, masked = _mask_c_like(expression)
    if masked.startswith("(") and _matching(masked, 0) == len(masked) - 1:
        return _branches(expression[1:-1])
    depth = 0
    question = -1
    for index, ch in enumerate(masked):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "?" and depth == 0 and masked[index + 1:index + 2] not in {"?", "."}:
            question = index
            break
    if question < 0:
        return [expression]
    depth = 0
    nested = 0
    for index in range(question + 1, len(masked)):
        ch = masked[index]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif depth == 0 and ch == "?":
            nested += 1
        elif depth == 0 and ch == ":":
            if nested:
                nested -= 1
                continue
            return _branches(expression[question + 1:index]) + _branches(expression[index + 1:])
    return [expression]


def _min_interval(value: str | None) -> float | None:
    """The shortest interval the expression can take, when its branches are plain arithmetic."""
    if value is None:
        return DEFAULT_INTERVAL_MS
    values = [number for branch in _branches(_literal(value) or "") if (number := _evaluate(branch)) is not None]
    return min(values) if values else None


def _gated(expression: str) -> bool:
    return any(word in ident.lower() for ident in _IDENT.findall(expression) for word in GATE_WORDS)


def _key(obj: _Object, ordinal: int) -> str:
    identifier = _literal(obj.props.get("id"))
    return identifier if identifier and _IDENT.fullmatch(identifier) else f"{obj.type}@{ordinal}"


def _starts(handler: str, target: str | None, *, bare: bool) -> list[int]:
    """Offsets in `handler` where it starts `target` (its id), or itself through a bare `running = true`."""
    patterns: list[str] = []
    if bare:
        patterns.append(r"(?<![\w.])running\s*=\s*true\b")
    if target:
        name = re.escape(target)
        patterns.append(rf"\b{name}\.running\s*=\s*true\b")
        patterns.append(rf"\b{name}\.(?:exec|startDetached)\s*\(")
    return [match.start() for pattern in patterns for match in re.finditer(pattern, handler)]


def _timer_starts(handler: str, timer: str) -> list[int]:
    name = re.escape(timer)
    return [match.start() for match in re.finditer(rf"\b{name}\.(?:start|restart)\s*\(|\b{name}\.running\s*=\s*true\b", handler)]


def _statement_end(masked: str, start: int) -> int:
    if start < len(masked) and masked[start] == "{":
        return _matching(masked, start)
    depth = 0
    for index in range(start, len(masked)):
        ch = masked[index]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth == 0:
                return index
            depth -= 1
        elif depth == 0 and ch in ";\n":
            return index
    return len(masked)


def _guards(handler: str, offset: int) -> list[str]:
    """Conditions in `handler` that the statement at `offset` runs under."""
    code, masked = _mask_c_like(handler)
    guards: list[str] = []
    for match in _IF.finditer(masked, 0, offset):
        open_paren = match.end() - 1
        close = _matching(masked, open_paren)
        condition = code[open_paren + 1:close]
        body = close + 1
        while body < len(masked) and masked[body].isspace():
            body += 1
        end = _statement_end(masked, body)
        if body <= offset <= end:
            guards.append(condition)
            continue
        rest = end + 1
        while rest < len(masked) and masked[rest].isspace():
            rest += 1
        if masked.startswith("else", rest):
            other = rest + 4
            while other < len(masked) and masked[other].isspace():
                other += 1
            if other <= offset <= _statement_end(masked, other):
                guards.append(condition)
    guards.extend(match.group("cond") for match in _EARLY_RETURN.finditer(code, 0, offset))
    start = max(masked.rfind(mark, 0, offset) for mark in ";{}\n")
    prefix = masked[start + 1:offset]
    if "?" in prefix or "&&" in prefix or "||" in prefix:
        guards.append(code[start + 1:offset])
    return guards


def _unguarded(guards: list[str]) -> bool:
    """True when nothing but the exit status decides the restart."""
    return all(set(_IDENT.findall(guard)) <= EXIT_STATUS_WORDS for guard in guards)


def timer_process_findings(sources: list[tuple[str, str, str, str]]) -> list[Finding]:
    findings: list[Finding] = []
    for relative, kind, code, masked in sources:
        if kind != "qml":
            continue
        objects = qml_objects(code, masked)
        ordinals = {"Timer": 0, "Process": 0}
        keyed: list[tuple[_Object, str]] = []
        for obj in objects:
            ordinals[obj.type] += 1
            keyed.append((obj, _key(obj, ordinals[obj.type])))
        timers = {
            identifier: obj.props.get("onTriggered", "")
            for obj, _ in keyed
            if obj.type == "Timer" and (identifier := _literal(obj.props.get("id")))
        }
        for obj, key in keyed:
            line = _line(code, obj.start)
            if obj.type == "Timer":
                detail = _timer_problem(obj)
                if detail:
                    findings.append(Finding("timer", relative, key, line, detail))
                continue
            detail = _restart_problem(obj, timers)
            if detail:
                findings.append(Finding("process", relative, key, line, detail))
    return findings


def _restart_problem(obj: _Object, timers: dict[str, str]) -> str:
    own = _literal(obj.props.get("id"))
    for handler_name in ("onExited", "onRunningChanged", "onFinished"):
        handler = obj.props.get(handler_name, "")
        if not handler:
            continue
        if any(_unguarded(_guards(handler, offset)) for offset in _starts(handler, own, bare=True)):
            return f"{handler_name} starts the Process again with no condition but its exit status"
        for timer, trigger in timers.items():
            if not own:
                break
            restarts = [offset for offset in _timer_starts(handler, timer) if _unguarded(_guards(handler, offset))]
            if restarts and any(_unguarded(_guards(trigger, offset)) for offset in _starts(trigger, own, bare=False)):
                return f"{handler_name} restarts it through Timer {timer} with no condition but its exit status"
    return ""


def _timer_problem(obj: _Object) -> str:
    repeat = _literal(obj.props.get("repeat"))
    if repeat is None or repeat == "false":
        return ""
    running = _literal(obj.props.get("running"))
    if running is None or running == "false":
        return ""
    if running == "true":
        return "repeating Timer with running: true"
    interval = _min_interval(obj.props.get("interval"))
    if interval is not None and interval <= SHORT_INTERVAL_MS and not _gated(running):
        return f"repeating {interval:g} ms Timer whose running ({running}) is not bound to visibility or activity"
    return ""


def load_allowlist(repo_root: Path) -> list[dict[str, Any]]:
    path = repo_root / ALLOWLIST
    if not path.is_file():
        return []
    label = ALLOWLIST.as_posix()
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise BehaviourError(f"{label}: cannot read JSON: {error}") from error
    if not isinstance(value, dict) or set(value) != {"schema", "entries"} or value["schema"] != 1 or not isinstance(value["entries"], list):
        raise BehaviourError(f"{label}: expected {{\"schema\": 1, \"entries\": [...]}}")
    seen: set[tuple[str, str, str, str]] = set()
    for index, entry in enumerate(value["entries"]):
        field = f"{label}:entries[{index}]"
        if not isinstance(entry, dict) or set(entry) != {"item", "check", "file", "key", "reason"}:
            raise BehaviourError(f"{field}: expected exactly item, check, file, key and reason")
        if any(not isinstance(entry[name], str) or not entry[name].strip() for name in entry):
            raise BehaviourError(f"{field}: every field is a non-empty string")
        if entry["check"] not in {"compositor", "timer", "process"}:
            raise BehaviourError(f"{field}.check: expected compositor, timer or process")
        identity = (entry["item"], entry["check"], entry["file"], entry["key"])
        if identity in seen:
            raise BehaviourError(f"{field}: duplicate entry")
        seen.add(identity)
    return value["entries"]


def behaviour_problems(label: str, window_manager: str, findings: list[Finding], allowlist: list[dict[str, Any]]) -> list[str]:
    """Problems for one item; `label` is `<category>/<id>`. Allowlist entries for it that match nothing are problems too."""
    entries = {(entry["check"], entry["file"], entry["key"]): entry for entry in allowlist if entry["item"] == label}
    used: set[tuple[str, str, str]] = set()
    problems: list[str] = []
    for finding in findings:
        identity = (finding.check, finding.file, finding.key)
        if finding.check == "compositor" and finding.key == window_manager:
            continue
        if identity in entries:
            used.add(identity)
            continue
        where = f"{label}/{finding.file}:{finding.line}"
        if finding.check == "compositor":
            problems.append(
                f"{where}: calls {finding.key} directly ({finding.detail}); declare requires.windowManager = \"{finding.key}\", "
                f"use the Wm facade, or gate the call on the running compositor and list "
                f"{{\"item\": \"{label}\", \"check\": \"compositor\", \"file\": \"{finding.file}\", \"key\": \"{finding.key}\"}} "
                f"with a reason in {ALLOWLIST.as_posix()}"
            )
        else:
            noun = "Timer" if finding.check == "timer" else "Process"
            problems.append(
                f"{where}: {finding.detail}; gate it on visibility or activity, or list "
                f"{{\"item\": \"{label}\", \"check\": \"{finding.check}\", \"file\": \"{finding.file}\", \"key\": \"{finding.key}\"}} "
                f"with a reason in {ALLOWLIST.as_posix()} ({noun} {finding.key})"
            )
    for identity in sorted(set(entries) - used):
        check, file, key = identity
        problems.append(f"{ALLOWLIST.as_posix()}: entry {label} {check} {file} {key} matches nothing; remove it")
    return problems


def unknown_allowlist_items(allowlist: list[dict[str, Any]], labels: set[str]) -> list[str]:
    return [
        f"{ALLOWLIST.as_posix()}: entry names {entry['item']!r}, which is not a subshell or bar style in this catalogue"
        for entry in allowlist if entry["item"] not in labels
    ]
