from __future__ import annotations

from pathlib import Path


CREDIT_FILES = {"LICENSE", "NOTICE", "PROVENANCE.txt"}
SHELL_FILES = {"item.toml", "README.md", "preview.webp", "manifest.json"} | CREDIT_FILES
SHELL_DIRS = {"screenshots", "qml", "bin", "data", "tests"}
PROFILE_FILES = {"item.toml", "profile.json", "README.md", "preview.webp", "manifest.json"} | CREDIT_FILES
PROFILE_DIRS = {"screenshots", "home"}


def _references_assets(value: object) -> bool:
    if isinstance(value, str):
        return value.startswith("assets/")
    if isinstance(value, dict):
        return any(_references_assets(child) for child in value.values())
    if isinstance(value, list):
        return any(_references_assets(child) for child in value)
    return False


def layout_problems(category: str, item_dir: Path, label: str, profile: object = None) -> list[str]:
    if category == "profiles":
        files, dirs = PROFILE_FILES, set(PROFILE_DIRS)
        if _references_assets(profile):
            dirs.add("assets")
    else:
        files, dirs = SHELL_FILES, SHELL_DIRS
    problems: list[str] = []
    for entry in sorted(item_dir.iterdir(), key=lambda path: path.name):
        if entry.is_symlink():
            continue
        if entry.is_dir():
            if entry.name not in dirs:
                problems.append(f"{label}/{entry.name}/: folder is not part of the item layout; allowed: {', '.join(sorted(dirs))}")
        elif entry.name not in files:
            problems.append(f"{label}/{entry.name}: file is not part of the item layout; allowed: {', '.join(sorted(files))}")
    return problems
