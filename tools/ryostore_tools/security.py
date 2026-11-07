from __future__ import annotations

import os
from pathlib import Path, PurePosixPath
import re
import stat

from .imports import ImportGate


MAX_FILES = 2048
MAX_FILE_SIZE = 256 * 1024 * 1024
MAX_PRODUCT_SIZE = 512 * 1024 * 1024

_SCRIPT_EXTENSIONS = {".sh", ".bash", ".zsh"}
_TEXT_EXTENSIONS = {".qml", ".js", ".mjs", ".cjs", ".py"} | _SCRIPT_EXTENSIONS
_BINARY_MAGIC = (
    b"\x7fELF",
    b"MZ",
    b"\xfe\xed\xfa\xce",
    b"\xfe\xed\xfa\xcf",
    b"\xce\xfa\xed\xfe",
    b"\xcf\xfa\xed\xfe",
)
_SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----"),
    re.compile(r"\b(?:AKIA|ASIA|AGPA|AIDA|AROA|ANPA|AIPA)[0-9A-Z]{16}\b"),
    re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b"),
    re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{10,}\b"),
    re.compile(r"\b(?:sk|rk)_live_[0-9A-Za-z]{20,}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    re.compile(r"\bpypi-AgEIcHlwaS[0-9A-Za-z_-]{40,}\b"),
)
_PRIVILEGE = re.compile(r"(?:^|[;&|]\s*|\b(?:then|do)\s+)(?:sudo|doas|su|pkexec)(?:\s|$)")
_SHELL_SHEBANG = re.compile(rb"^#!\s*\S*(?:/|env\s+)(?:ba|z|da)?sh\b")


class SecurityError(ValueError):
    pass


def safe_relative(value: str) -> bool:
    if not value or value == "." or "\\" in value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and path.as_posix() == value and all(part not in ("", ".", "..") for part in path.parts)


def payload_files(item_dir: Path, label: str) -> list[tuple[str, Path]]:
    files: list[tuple[str, Path]] = []
    total = 0
    for current, dir_names, file_names in os.walk(item_dir, followlinks=False):
        base = Path(current)
        for name in sorted(dir_names) + sorted(file_names):
            candidate = base / name
            relative = candidate.relative_to(item_dir).as_posix()
            mode = candidate.lstat().st_mode
            if stat.S_ISLNK(mode):
                raise SecurityError(f"{label}/{relative}: symlink is forbidden")
            if stat.S_ISDIR(mode):
                continue
            if not stat.S_ISREG(mode):
                raise SecurityError(f"{label}/{relative}: special file is forbidden")
            if relative == "manifest.json":
                continue
            size = candidate.stat().st_size
            if size > MAX_FILE_SIZE:
                raise SecurityError(f"{label}/{relative}: file exceeds {MAX_FILE_SIZE} bytes")
            total += size
            files.append((relative, candidate))
    if not files:
        raise SecurityError(f"{label}: item has no payload files")
    if len(files) > MAX_FILES:
        raise SecurityError(f"{label}: item exceeds {MAX_FILES} files")
    if total > MAX_PRODUCT_SIZE:
        raise SecurityError(f"{label}: item exceeds {MAX_PRODUCT_SIZE} bytes")
    return sorted(files)


def screen_item(item_dir: Path, label: str, files: list[tuple[str, Path]], modules: tuple[list[str], list[str]] | None) -> None:
    """`modules` is (shell modules, requires.qmlModules) for shell items; profiles pass None and skip the import gate."""
    gate = ImportGate(item_dir, *modules) if modules is not None else None
    problems: list[str] = []
    for relative, path in files:
        display = f"{label}/{relative}"
        data = path.read_bytes()
        if any(data.startswith(magic) for magic in _BINARY_MAGIC):
            problems.append(f"{display}: compiled executable or object is forbidden")
            continue
        suffix = path.suffix.lower()
        is_script = suffix in _SCRIPT_EXTENSIONS or bool(_SHELL_SHEBANG.match(data))
        if suffix not in _TEXT_EXTENSIONS and path.name != "qmldir" and not is_script:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as error:
            problems.append(f"{display}: source file is not UTF-8: {error}")
            continue
        if any(pattern.search(text) for pattern in _SECRET_PATTERNS):
            problems.append(f"{display}: credential or private key material is forbidden")
        if is_script and _PRIVILEGE.search(text):
            problems.append(f"{display}: item scripts may not escalate privileges")
        if gate is not None:
            problems.extend(gate.problems(display, path, text))
    if problems:
        raise SecurityError("\n".join(problems))
