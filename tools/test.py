#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import subprocess
import sys

from ryostore_tools.catalogue import CATEGORIES, ID_PATTERN, item_directories


REPO_ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class TestCommand:
    label: str
    argv: list[str]


def resolve_items(root: Path, selectors: list[str]) -> list[Path]:
    available = [directory for category in CATEGORIES for directory in item_directories(root, category)]
    if not selectors:
        return available
    resolved: list[Path] = []
    for selector in selectors:
        parts = PurePosixPath(selector).parts
        if len(parts) == 2 and parts[0] in CATEGORIES and ID_PATTERN.fullmatch(parts[1]):
            matches = [root / parts[0] / parts[1]]
        elif len(parts) == 1 and ID_PATTERN.fullmatch(parts[0]):
            matches = [path for path in available if path.name == parts[0]]
        else:
            raise ValueError(f"invalid item selector {selector!r}")
        matches = [path for path in matches if (path / "item.toml").is_file()]
        if not matches:
            raise ValueError(f"unknown item {selector!r}")
        if len(matches) > 1:
            raise ValueError(f"ambiguous item {selector!r}; use <category>/<id>")
        if matches[0] not in resolved:
            resolved.append(matches[0])
    return resolved


def commands_for(item: Path) -> list[TestCommand]:
    tests = item / "tests"
    if not tests.is_dir():
        return []
    commands: list[TestCommand] = []
    node_tests = sorted(str(path) for path in tests.rglob("*.test.mjs") if path.is_file())
    if node_tests:
        commands.append(TestCommand("node", ["node", "--test", *node_tests]))
    for path in sorted(tests.rglob("test_*.py")):
        if path.is_file():
            commands.append(TestCommand(path.name, ["python3", str(path)]))
    for path in sorted(tests.rglob("*.sh")):
        if path.is_file():
            commands.append(TestCommand(path.name, ["bash", str(path)]))
    return commands


def run(root: Path, selectors: list[str]) -> int:
    items = resolve_items(root, selectors)
    failed = 0
    for item in items:
        label = item.relative_to(root).as_posix()
        commands = commands_for(item)
        if not commands:
            print(f"{label}: no tests")
            continue
        item_failed = False
        for command in commands:
            print(f"{label}: {command.label}")
            result = subprocess.run(command.argv, cwd=item, check=False)
            if result.returncode != 0:
                item_failed = True
        if item_failed:
            failed += 1
            print(f"{label}: failed")
        else:
            print(f"{label}: passed")
    print(f"{len(items) - failed} passed, {failed} failed")
    return 1 if failed else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run tests shipped with catalogue items.")
    parser.add_argument("items", nargs="*", metavar="<item>")
    args = parser.parse_args(argv)
    try:
        return run(REPO_ROOT, args.items)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
