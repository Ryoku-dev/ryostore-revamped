from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re


PLATFORM_FILE = Path(__file__).resolve().parent.parent / "platform.json"
_PLATFORM = json.loads(PLATFORM_FILE.read_text(encoding="utf-8"))
PLATFORM_MODULES = frozenset(_PLATFORM["modules"])
PLATFORM_PREFIXES = tuple(_PLATFORM["prefixes"])
PLATFORM_EXPORTS = {uri: frozenset(names) for uri, names in _PLATFORM["exports"].items()}
RESERVED_MODULE = _PLATFORM["reserved"]

_URI = r"[A-Za-z_][A-Za-z0-9_.]*"
_QML_IMPORT = re.compile(rf"^\s*import\s+(?:(?P<quote>[\"'])(?P<path>[^\"']*)(?P=quote)|(?P<uri>{_URI}))(?P<rest>.*)$")
_JS_DIRECTIVE = re.compile(rf"^\s*\.import\s+(?:(?P<quote>[\"'])(?P<path>[^\"']*)(?P=quote)|(?P<uri>{_URI}))")
_ES_FROM = re.compile(r"^\s*(?:import|export|\}).*?\bfrom\s+(?P<quote>[\"'])(?P<path>[^\"']+)(?P=quote)")
_ES_BARE = re.compile(r"^\s*import\s+(?P<quote>[\"'])(?P<path>[^\"']+)(?P=quote)")
_QMLDIR_IMPORT = re.compile(rf"^\s*(?:optional\s+|default\s+)?import\s+(?P<uri>{_URI})")
_QMLDIR_MODULE = re.compile(rf"^\s*module\s+(?P<uri>{_URI})\s*$")
_QUALIFIER = re.compile(r"\bas\s+[A-Za-z_]")
_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
_COMMENTS = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)


def reserved(uri: str) -> bool:
    return uri == RESERVED_MODULE or uri.startswith(RESERVED_MODULE + ".")


def _own_module(item_dir: Path, modules: list[str], uri: str) -> bool:
    # A module root is linked as <moduleRoot>/<module>, so every URI under it maps to a folder in qml/.
    roots = {module.replace("/", ".") for module in modules}
    inside = any(uri == root or uri.startswith(root + ".") for root in roots)
    return inside and (item_dir / "qml" / Path(*uri.split("."))).is_dir()


def _platform(uri: str) -> bool:
    return uri in PLATFORM_MODULES or uri.startswith(PLATFORM_PREFIXES)


def _qml_types(directory: Path) -> set[str]:
    return {path.stem for path in directory.glob("*.qml") if path.is_file()} if directory.is_dir() else set()


@dataclass(frozen=True)
class _QmlImport:
    line: int
    uri: str | None
    path: str | None
    qualified: bool


def _qml_header(text: str) -> list[_QmlImport]:
    imports: list[_QmlImport] = []
    in_comment = False
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if in_comment:
            in_comment = "*/" not in stripped
            continue
        if stripped.startswith("/*"):
            in_comment = "*/" not in stripped
            continue
        # QML imports precede the root object; later "import" lines are string content.
        if stripped and not stripped.startswith(("//", "import", "pragma")):
            break
        match = _QML_IMPORT.match(line)
        if match is not None:
            qualified = bool(_QUALIFIER.search(match.group("rest")))
            imports.append(_QmlImport(number, match.group("uri"), match.group("path"), qualified))
    return imports


class ImportGate:
    def __init__(self, item_dir: Path, modules: list[str], extra_modules: list[str]) -> None:
        self.item_dir = item_dir
        self.item_root = item_dir.resolve()
        self.modules = modules
        self.extra = set(extra_modules)

    def _module(self, uri: str) -> str | None:
        if reserved(uri):
            return f"QML module {uri!r} is reserved by Quickshell for the shell config root"
        if _platform(uri) or uri in self.extra or _own_module(self.item_dir, self.modules, uri):
            return None
        return f"QML module {uri!r} is not a platform module, a folder under one of [shell] modules, or listed in requires.qmlModules"

    def _relative(self, source: Path, target: str, kind: str) -> str | None:
        if target.startswith("/") or _SCHEME.match(target):
            return f"{kind} {target!r} must be relative to the item"
        try:
            (source.parent / target).resolve(strict=False).relative_to(self.item_root)
        except ValueError:
            return f"{kind} {target!r} leaves the item folder"
        return None

    def _collisions(self, label: str, source: Path, text: str, imports: list[_QmlImport]) -> list[str]:
        unqualified = [entry for entry in imports if entry.uri in PLATFORM_EXPORTS and not entry.qualified]
        if not unqualified:
            return []
        local = _qml_types(source.parent)
        for entry in imports:
            if entry.path is not None and not entry.qualified and not entry.path.endswith(".js"):
                local |= _qml_types(source.parent / entry.path)
        lines = _COMMENTS.sub(lambda match: "\n" * match.group(0).count("\n"), text).splitlines()
        header_end = imports[-1].line
        found: list[str] = []
        for entry in unqualified:
            for name in sorted(local & PLATFORM_EXPORTS[entry.uri]):
                pattern = re.compile(rf"\b{re.escape(name)}\b")
                used = next((index for index, line in enumerate(lines[header_end:], start=header_end + 1) if pattern.search(line)), None)
                if used is not None:
                    found.append(f"{label}:{used}: '{name}' is both a local type and a {entry.uri} export; import {entry.uri} as Ryoku")
        return found

    def _qml(self, label: str, source: Path, text: str) -> list[str]:
        imports = _qml_header(text)
        found: list[str] = []
        for entry in imports:
            if entry.uri is None:
                problem = self._relative(source, entry.path or "", "relative import")
            else:
                problem = self._module(entry.uri)
            if problem is not None:
                found.append(f"{label}:{entry.line}: {problem}")
        return found + self._collisions(label, source, text, imports)

    def _js_line(self, source: Path, line: str) -> str | None:
        match = _JS_DIRECTIVE.match(line)
        if match is not None:
            if match.group("uri") is None:
                return self._relative(source, match.group("path"), ".js include")
            return self._module(match.group("uri"))
        match = _ES_FROM.match(line) or _ES_BARE.match(line)
        if match is None:
            return None
        target = match.group("path")
        if target.startswith("."):
            return self._relative(source, target, "JavaScript import")
        if target.startswith("/") or target.lower().startswith("file:"):
            return f"JavaScript import {target!r} must be relative to the item"
        return None

    def _qmldir_line(self, source: Path, line: str) -> str | None:
        match = _QMLDIR_MODULE.match(line)
        if match is not None and reserved(match.group("uri")):
            return f"module name {match.group('uri')!r} is reserved by Quickshell"
        match = _QMLDIR_IMPORT.match(line)
        if match is not None:
            return self._module(match.group("uri"))
        return None

    def problems(self, label: str, source: Path, text: str) -> list[str]:
        if source.suffix == ".qml":
            return self._qml(label, source, text)
        if source.name == "qmldir":
            check = self._qmldir_line
        elif source.suffix in {".js", ".mjs"}:
            check = self._js_line
        else:
            return []
        return [
            f"{label}:{number}: {problem}"
            for number, line in enumerate(text.splitlines(), start=1)
            if (problem := check(source, line)) is not None
        ]
