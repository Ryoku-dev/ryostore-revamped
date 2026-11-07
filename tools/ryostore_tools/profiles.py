from __future__ import annotations

from pathlib import Path, PurePosixPath
import tomllib
from typing import Any

from .security import safe_relative


# Allowlists for permissions, groups, repos, host suffixes and capabilities live in
# schema/profile.schema.json; these are the rules a schema cannot express.
FORBIDDEN_ENV = {"PATH", "HOME", "USER", "XDG_RUNTIME_DIR"}


def _home_file(item_dir: Path, relative: object) -> bool:
    if not isinstance(relative, str) or not safe_relative(relative):
        return False
    target = item_dir.joinpath("home", *PurePosixPath(relative).parts)
    return target.is_file() and not target.is_symlink()


def _store_item_problem(repo_root: Path, row: dict[str, Any]) -> str | None:
    selector = f"{row['category']}/{row['id']}"
    path = repo_root / row["category"] / row["id"] / "item.toml"
    try:
        metadata = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError):
        return f"storeItems names {selector}, which is not an item in this catalogue"
    if metadata.get("listed", True) is not True:
        return f"storeItems names {selector}, which is not listed in the Store"
    return None


def profile_problems(repo_root: Path, item_dir: Path, label: str, metadata: dict[str, Any], profile: dict[str, Any]) -> list[str]:
    """Checks a schema-valid profile.json against item.toml, its home/ payload and the catalogue."""
    problems: list[str] = []

    def problem(field: str, message: str) -> None:
        problems.append(f"{label}:{field}: {message}")

    for field in ("id", "version", "name"):
        if profile.get(field) != metadata.get(field):
            problem(field, "must match item.toml")
    managers = profile["requires"]["packageManagers"]
    if "pacman" not in managers:
        problem("requires.packageManagers", "profiles currently need pacman (Arch or CachyOS)")
    if managers != metadata.get("requires", {}).get("packageManagers", []):
        problem("requires.packageManagers", "must match item.toml requires.packageManagers")

    names: set[str] = set()
    commands: set[str] = set()
    for index, component in enumerate(profile["components"]):
        if component["name"] in names:
            problem(f"components[{index}].name", f"duplicate component {component['name']}")
        names.add(component["name"])
        detect = component.get("detect")
        if isinstance(detect, str) and not detect.startswith("/"):
            commands.add(detect)

    tools: set[str] = set()
    for index, capability in enumerate(profile["capabilities"]):
        tool = capability["tool"]
        if tool in tools:
            problem(f"capabilities[{index}].tool", f"duplicate capability tool {tool}")
        tools.add(tool)
        if tool not in commands:
            problem(f"capabilities[{index}].tool", f"{tool} is not a component command")

    keys: set[str] = set()
    for index, variable in enumerate(profile["env"]):
        key = variable["key"]
        if key in keys:
            problem(f"env[{index}].key", f"duplicate environment key {key}")
        keys.add(key)
        if key in FORBIDDEN_ENV or key.startswith("LD_"):
            problem(f"env[{index}].key", f"environment key {key} is forbidden")

    for field in ("expand", "seedOnce"):
        for index, value in enumerate(profile[field]):
            if not _home_file(item_dir, value):
                problem(f"{field}[{index}]", f"home/{value} does not exist")
    rice = profile["rice"]
    if not _home_file(item_dir, f".config/ryoku/rices/{rice}/rice.json"):
        problem("rice", f"home/.config/ryoku/rices/{rice}/rice.json does not exist")

    for index, row in enumerate(profile.get("storeItems", [])):
        message = _store_item_problem(repo_root, row)
        if message:
            problem(f"storeItems[{index}]", message)
    return problems
