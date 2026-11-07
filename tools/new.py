#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys

from ryostore_tools.catalogue import CATEGORIES, ID_PATTERN


REPO_ROOT = Path(__file__).resolve().parent.parent
CATEGORY_ALIASES = {
    "subshell": "subshells",
    "subshells": "subshells",
    "barstyle": "barstyles",
    "barstyles": "barstyles",
    "profile": "profiles",
    "profiles": "profiles",
}
TEMPLATE_NAMES = {"subshells": "subshell", "barstyles": "barstyle", "profiles": "profile"}


def display_name(item_id: str) -> str:
    return " ".join(part.capitalize() for part in item_id.split("-"))


def scaffold(root: Path, category_arg: str, item_id: str) -> Path:
    category = CATEGORY_ALIASES.get(category_arg)
    if category not in CATEGORIES:
        raise ValueError(f"unknown category {category_arg!r}")
    if not ID_PATTERN.fullmatch(item_id):
        raise ValueError("id must match ^[a-z][a-z0-9-]{1,30}$")
    source = root / "templates" / TEMPLATE_NAMES[category]
    destination = root / category / item_id
    if destination.exists():
        raise ValueError(f"{category}/{item_id} already exists")
    shutil.copytree(source, destination)
    name = display_name(item_id)
    item_path = destination / "item.toml"
    item_text = item_path.read_text(encoding="utf-8")
    item_text = re.sub(r'^id = ".*"$', f'id = "{item_id}"', item_text, count=1, flags=re.MULTILINE)
    item_text = re.sub(r'^name = ".*"$', f'name = "{name}"', item_text, count=1, flags=re.MULTILINE)
    item_path.write_text(item_text, encoding="utf-8")
    readme = destination / "README.md"
    if readme.is_file():
        lines = readme.read_text(encoding="utf-8").splitlines()
        if lines and lines[0].startswith("# "):
            lines[0] = f"# {name}"
            readme.write_text("\n".join(lines) + "\n", encoding="utf-8")
    profile_path = destination / "profile.json"
    if profile_path.is_file():
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        profile["id"] = item_id
        profile["name"] = name
        profile_path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return destination


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create an item from a catalogue template.")
    parser.add_argument("category")
    parser.add_argument("id")
    args = parser.parse_args(argv)
    try:
        destination = scaffold(REPO_ROOT, args.category, args.id)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(destination.relative_to(REPO_ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
