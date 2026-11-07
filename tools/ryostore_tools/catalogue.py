from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import tomllib
from typing import Any

from .behaviour import BehaviourError, behaviour_problems, compositor_findings, load_allowlist, scanned_files, timer_process_findings, unknown_allowlist_items
from .images import preview_problem
from .imports import reserved
from .jsonschema import SchemaError, validate as validate_schema
from .layout import layout_problems
from . import measurements
from .measurements import MeasurementError
from .profiles import profile_problems
from .security import SecurityError, payload_files, safe_relative, screen_item


CATEGORIES = ("subshells", "barstyles", "profiles")
SHELL_CATEGORIES = {"subshells", "barstyles"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,30}$")
WIDGET_ID_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")
SEMVER_PATTERN = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$")
SPDX_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+-]*(?: (?:AND|OR|WITH) [A-Za-z0-9][A-Za-z0-9.+-]*)*$")
COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")
URI_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_.]*$")
TOP_LEVEL_KEYS = {
    "id", "name", "version", "summary", "description", "license", "authors", "tags",
    "upstream", "accent", "surface", "preview", "screenshots", "official", "listed", "requires",
    "downloadPaused", "downloadPauseReason", "shell", "provides", "lifecycle", "runtime",
}
OWNED_SURFACES = {"notifications", "notificationSound", "osd", "polkit", "dock", "widgets", "cheatsheet", "windowClose"}
SETTING_KEY_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$")
HUB_EDITORS = {"", "frame-rails", "nacre", "obi"}
PACKAGE_MANAGERS = {"pacman", "dnf", "xbps"}
ENV_KEY_PATTERN = re.compile(r"^[A-Z][A-Z0-9_]*$")
PROTECTED_ENV = {"PATH", "HOME", "USER", "SHELL", "LANG", "DISPLAY"}
PROTECTED_ENV_PREFIXES = ("LC_", "LD_", "XDG_", "QT_", "QML", "WAYLAND_", "DBUS_", "RYOKU_", "MALLOC_")
ENV_EXPANDED = ("HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "RYOKU_ITEM_DIR")
ENV_REFERENCE = re.compile(r"\$(?:(" + "|".join(ENV_EXPANDED) + r")(?![A-Za-z0-9_]))?")


class CatalogueError(ValueError):
    pass


@dataclass(frozen=True)
class BuiltItem:
    category: str
    item_id: str
    directory: Path
    listed: bool
    manifest_bytes: bytes
    registry_entry: dict[str, Any]
    # Missing or stale resource measurements: warnings for a plain build, errors for --check.
    measurement_notes: tuple[str, ...] = ()


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def _error(path: str, field: str, message: str) -> CatalogueError:
    return CatalogueError(f"{path}:{field}: {message}")


class _Item:
    """Validation state for one item folder; every message names `<category>/<id>/<file>:<field>`."""

    def __init__(self, repo_root: Path, category: str, directory: Path) -> None:
        self.repo_root = repo_root
        self.category = category
        self.directory = directory
        self.label = f"{category}/{directory.name}"
        self.toml = f"{self.label}/item.toml"

    def table(self, owner: dict[str, Any], field: str, *, optional: bool = False) -> dict[str, Any]:
        value = owner.get(field)
        if value is None and optional:
            return {}
        if not isinstance(value, dict):
            raise _error(self.toml, field, "expected a table")
        return value

    def string(self, owner: dict[str, Any], field: str, *, optional: bool = False, default: str = "", label: str = "") -> str:
        name = f"{label}.{field}" if label else field
        if field not in owner and optional:
            return default
        value = owner.get(field)
        if not isinstance(value, str) or (not value.strip() and not optional):
            raise _error(self.toml, name, "expected a non-empty string")
        return value

    def strings(self, owner: dict[str, Any], field: str, *, optional: bool = False, label: str = "") -> list[str]:
        name = f"{label}.{field}" if label else field
        if field not in owner and optional:
            return []
        value = owner.get(field)
        if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
            raise _error(self.toml, name, "expected an array of non-empty strings")
        if len(value) != len(set(value)):
            raise _error(self.toml, name, "entries must be unique")
        return value

    def known_keys(self, value: dict[str, Any], allowed: set[str], field: str) -> None:
        unknown = sorted(set(value) - allowed)
        if unknown:
            raise _error(self.toml, f"{field}.{unknown[0]}" if field else unknown[0], "unknown field")

    def path(self, field: str, value: str, *, directory: bool = False, under: str = "") -> Path:
        if not safe_relative(value):
            raise _error(self.toml, field, "expected a safe path inside the item")
        if under and not value.startswith(f"{under}/"):
            raise _error(self.toml, field, f"must be inside {under}/")
        candidate = self.directory.joinpath(*PurePosixPath(value).parts)
        try:
            candidate.resolve(strict=False).relative_to(self.directory.resolve())
        except ValueError as error:
            raise _error(self.toml, field, "path leaves the item") from error
        if candidate.is_symlink():
            raise _error(self.toml, field, "symlinks are forbidden")
        if directory and not candidate.is_dir():
            raise _error(self.toml, field, f"directory does not exist: {value}")
        if not directory and not candidate.is_file():
            raise _error(self.toml, field, f"file does not exist: {value}")
        return candidate

    def load_toml(self) -> dict[str, Any]:
        source = self.directory / "item.toml"
        try:
            value = tomllib.loads(source.read_text(encoding="utf-8"))
        except FileNotFoundError as error:
            raise CatalogueError(f"{self.toml}: missing item.toml") from error
        except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
            raise CatalogueError(f"{self.toml}: cannot read TOML: {error}") from error
        self.known_keys(value, TOP_LEVEL_KEYS, "")
        return value

    def roster(self, field: str, relative: str) -> list[dict[str, Any]]:
        label = f"{self.label}/{relative}"
        try:
            records = json.loads(self.directory.joinpath(*PurePosixPath(relative).parts).read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise _error(self.toml, field, f"cannot read JSON: {error}") from error
        if not isinstance(records, list):
            raise CatalogueError(f"{label}: expected an array of records")
        for index, record in enumerate(records):
            if not isinstance(record, dict):
                raise _error(label, f"[{index}]", "expected an object")
            for name in ("id", "prefix", "label", "kind"):
                if not isinstance(record.get(name), str) or not record[name]:
                    raise _error(label, f"[{index}].{name}", "expected a non-empty string")
            if not WIDGET_ID_PATTERN.fullmatch(record["id"]):
                raise _error(label, f"[{index}].id", "expected ^[A-Za-z][A-Za-z0-9_-]*$")
            if not isinstance(record.get("sizes"), list):
                raise _error(label, f"[{index}].sizes", "expected an array")
        return records

    def contributions(self, metadata: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
        provides = self.table(metadata, "provides", optional=True)
        self.known_keys(provides, {"dock", "launcher", "desktopWidgets"}, "provides")
        result: dict[str, list[dict[str, Any]]] = {"dock": [], "launcher": [], "desktopWidgets": []}
        specifications = {
            "dock": ({"id", "name", "entry"}, {"id", "name", "entry"}),
            "launcher": ({"id", "name", "description", "entry", "preview"}, {"id", "name", "entry"}),
            "desktopWidgets": ({"id", "roster", "widget", "options"}, {"id", "roster", "widget"}),
        }
        for kind, (allowed, required) in specifications.items():
            rows = provides.get(kind, [])
            if not isinstance(rows, list):
                raise _error(self.toml, f"provides.{kind}", "expected an array of tables")
            seen: set[str] = set()
            for index, row in enumerate(rows):
                field = f"provides.{kind}[{index}]"
                if not isinstance(row, dict):
                    raise _error(self.toml, field, "expected a table")
                self.known_keys(row, allowed, field)
                missing = sorted(required - set(row))
                if missing:
                    raise _error(self.toml, f"{field}.{missing[0]}", "missing required field")
                for key in allowed - {"options"}:
                    if key in row:
                        self.string(row, key, label=field)
                contribution_id = row["id"]
                if not ID_PATTERN.fullmatch(contribution_id):
                    raise _error(self.toml, f"{field}.id", "invalid id")
                if contribution_id in seen:
                    raise _error(self.toml, f"{field}.id", "duplicate contribution id")
                seen.add(contribution_id)
                normalized = dict(row)
                for key in ("entry", "preview", "widget"):
                    if key in row:
                        self.path(f"{field}.{key}", row[key], under="qml")
                if "roster" in row:
                    self.path(f"{field}.roster", row["roster"])
                if "options" in row:
                    self.path(f"{field}.options", self.string(row, "options", label=field), directory=True, under="qml")
                if kind == "desktopWidgets":
                    normalized["rosterRecords"] = self.roster(f"{field}.roster", row["roster"])
                result[kind].append(normalized)
            result[kind].sort(key=lambda row: row["id"])
        return result

    def scripts(self, metadata: dict[str, Any], table_name: str, allowed: set[str]) -> dict[str, str]:
        table = self.table(metadata, table_name, optional=True)
        self.known_keys(table, allowed, table_name)
        result: dict[str, str] = {}
        for name in sorted(table):
            value = self.string(table, name, label=table_name)
            script = self.path(f"{table_name}.{name}", value, under="bin")
            if not os.access(script, os.X_OK):
                raise _error(self.toml, f"{table_name}.{name}", "script must be executable")
            result[name] = value
        return result

    def shell(self, metadata: dict[str, Any]) -> dict[str, Any]:
        shell = self.table(metadata, "shell")
        self.known_keys(shell, {"entry", "frameHost", "owns", "ownsSetting", "env", "modules", "settings"}, "shell")
        entry = self.string(shell, "entry", label="shell")
        self.path("shell.entry", entry, under="qml")
        frame_host = self.string(shell, "frameHost", label="shell")
        if frame_host not in {"each", "primary"}:
            raise _error(self.toml, "shell.frameHost", "expected 'each' or 'primary'")
        owns = self.strings(shell, "owns", label="shell")
        unknown_owns = sorted(set(owns) - OWNED_SURFACES)
        if unknown_owns:
            raise _error(self.toml, "shell.owns", f"unsupported surface {unknown_owns[0]!r}; allowed: {', '.join(sorted(OWNED_SURFACES))}")
        owns_setting = self.table(shell, "ownsSetting", optional=True)
        for surface in sorted(owns_setting):
            field = f"shell.ownsSetting.{surface}"
            if surface not in owns:
                raise _error(self.toml, field, "surface is not listed in shell.owns")
            key = owns_setting[surface]
            if not isinstance(key, str) or not SETTING_KEY_PATTERN.fullmatch(key):
                raise _error(self.toml, field, "expected a dotted shell.json key such as 'python.general.notifications'")
        env = self.table(shell, "env", optional=True)
        for key in sorted(env):
            field = f"shell.env.{key}"
            if not ENV_KEY_PATTERN.fullmatch(key):
                raise _error(self.toml, field, "expected a name matching ^[A-Z][A-Z0-9_]*$")
            if key in PROTECTED_ENV or key.startswith(PROTECTED_ENV_PREFIXES):
                raise _error(self.toml, field, "protected variable; Ryoku sets it")
            if not isinstance(env[key], str):
                raise _error(self.toml, field, "expected a string")
            for match in ENV_REFERENCE.finditer(env[key]):
                if match.group(1) is None:
                    raise _error(self.toml, field, f"only ${', $'.join(ENV_EXPANDED)} are expanded; '$' at offset {match.start()} is not one of them")
        modules = self.strings(shell, "modules", label="shell")
        for index, module in enumerate(modules):
            field = f"shell.modules[{index}]"
            if reserved(module):
                raise _error(self.toml, field, "'qs' is reserved by Quickshell; rename the module")
            module_dir = self.path(field, f"qml/{module}", directory=True)
            # A root may hold only submodules (nomarchy.Commons), each with its own qmldir.
            if not any(module_dir.rglob("qmldir")):
                raise _error(self.toml, field, f"qml/{module} has no qmldir")
        settings = self.table(shell, "settings", optional=True)
        self.known_keys(settings, {"ipc", "call", "args", "hubEditor"}, "shell.settings")
        normalized_settings: dict[str, Any] = {
            field: self.string(settings, field, optional=True, label="shell.settings")
            for field in ("ipc", "call", "hubEditor")
        }
        args = settings.get("args", [])
        if not isinstance(args, list) or any(not isinstance(arg, str) for arg in args):
            raise _error(self.toml, "shell.settings.args", "expected an array of strings")
        normalized_settings["args"] = args
        if bool(normalized_settings["ipc"]) != bool(normalized_settings["call"]):
            raise _error(self.toml, "shell.settings", "set ipc and call together")
        if normalized_settings["hubEditor"] not in HUB_EDITORS:
            raise _error(self.toml, "shell.settings.hubEditor", f"allowed: {', '.join(sorted(HUB_EDITORS - {''}))}")
        return {
            "entry": entry,
            "frameHost": frame_host,
            "owns": owns,
            "ownsSetting": dict(owns_setting),
            "env": dict(env),
            "modules": modules,
            "settings": normalized_settings,
            "provides": self.contributions(metadata),
            "lifecycle": self.scripts(metadata, "lifecycle", {"activate", "deactivate", "palette"}),
            "runtime": self.scripts(metadata, "runtime", {"check", "install", "start"}),
        }

    def profile(self, metadata: dict[str, Any]) -> list[str]:
        self.path("profile", "profile.json")
        label = f"{self.label}/profile.json"
        try:
            profile = json.loads((self.directory / "profile.json").read_text(encoding="utf-8"))
            schema = json.loads((self.repo_root / "schema" / "profile.schema.json").read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise CatalogueError(f"{label}: cannot read the profile or schema/profile.schema.json: {error}") from error
        try:
            validate_schema(profile, schema, label=label)
        except SchemaError as error:
            raise CatalogueError(str(error)) from error
        return profile_problems(self.repo_root, self.directory, label, metadata, profile)

    def raw_profile(self) -> object:
        try:
            return json.loads((self.directory / "profile.json").read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            return None

    def build(self) -> BuiltItem:
        problems = layout_problems(
            self.category, self.directory, self.label,
            self.raw_profile() if self.category == "profiles" else None,
        )
        try:
            built, more = self._build()
        except (CatalogueError, SecurityError, BehaviourError, MeasurementError) as error:
            raise CatalogueError("\n".join([*problems, str(error)])) from error
        problems.extend(more)
        if problems:
            raise CatalogueError("\n".join(problems))
        return built

    def _build(self) -> tuple[BuiltItem, list[str]]:
        metadata = self.load_toml()
        item_id = self.string(metadata, "id")
        if not ID_PATTERN.fullmatch(item_id):
            raise _error(self.toml, "id", "expected ^[a-z][a-z0-9-]{1,30}$")
        if self.directory.name != item_id:
            raise _error(self.toml, "id", f"must equal folder name {self.directory.name!r}")
        name = self.string(metadata, "name")
        version = self.string(metadata, "version")
        if not SEMVER_PATTERN.fullmatch(version):
            raise _error(self.toml, "version", "expected semantic version x.y.z")
        summary = self.string(metadata, "summary")
        description = self.string(metadata, "description")
        license_id = self.string(metadata, "license")
        if not SPDX_PATTERN.fullmatch(license_id):
            raise _error(self.toml, "license", "expected an SPDX license id or expression")
        authors = self.strings(metadata, "authors")
        if not authors:
            raise _error(self.toml, "authors", "expected at least one author")
        tags = self.strings(metadata, "tags")
        preview = self.string(metadata, "preview", optional=True, default="preview.webp")
        problem = preview_problem(self.path("preview", preview))
        if problem:
            raise _error(self.toml, "preview", problem)
        screenshots = self.strings(metadata, "screenshots", optional=True)
        for index, screenshot in enumerate(screenshots):
            self.path(f"screenshots[{index}]", screenshot, under="screenshots")
        accent = metadata.get("accent", "#7aa2f7")
        surface = metadata.get("surface", "#101010")
        for field, value in (("accent", accent), ("surface", surface)):
            if not isinstance(value, str) or not COLOR_PATTERN.fullmatch(value):
                raise _error(self.toml, field, "expected #rrggbb")
        upstream = self.string(metadata, "upstream", optional=True)
        if upstream and not upstream.startswith("https://"):
            raise _error(self.toml, "upstream", "expected an https:// URL")
        official = metadata.get("official", False)
        listed = metadata.get("listed", True)
        paused = metadata.get("downloadPaused", False)
        for field, value in (("official", official), ("listed", listed), ("downloadPaused", paused)):
            if not isinstance(value, bool):
                raise _error(self.toml, field, "expected true or false")
        pause_reason = self.string(metadata, "downloadPauseReason", optional=True)
        if paused and not pause_reason.strip():
            raise _error(self.toml, "downloadPauseReason", "required when downloadPaused = true")
        if pause_reason and not paused:
            raise _error(self.toml, "downloadPauseReason", "only used with downloadPaused = true")

        requires = self.table(metadata, "requires", optional=True)
        self.known_keys(requires, {"packageManagers", "windowManager", "reason", "qmlModules"}, "requires")
        package_managers = self.strings(requires, "packageManagers", optional=True, label="requires")
        invalid_managers = sorted(set(package_managers) - PACKAGE_MANAGERS)
        if invalid_managers:
            raise _error(self.toml, "requires.packageManagers", f"unsupported manager {invalid_managers[0]!r}")
        qml_modules = self.strings(requires, "qmlModules", optional=True, label="requires")
        for index, module in enumerate(qml_modules):
            if not URI_PATTERN.fullmatch(module):
                raise _error(self.toml, f"requires.qmlModules[{index}]", "invalid QML module URI")
            if reserved(module):
                raise _error(self.toml, f"requires.qmlModules[{index}]", "'qs' is reserved by Quickshell")
        window_manager = self.string(requires, "windowManager", optional=True, label="requires")
        reason = self.string(requires, "reason", optional=True, label="requires")

        shell_block: dict[str, Any] | None = None
        problems: list[str] = []
        if self.category in SHELL_CATEGORIES:
            shell_block = self.shell(metadata)
        else:
            for key in ("shell", "provides", "lifecycle", "runtime"):
                if key in metadata:
                    raise _error(self.toml, key, "profiles cannot declare shell fields")
            if qml_modules:
                raise _error(self.toml, "requires.qmlModules", "profiles carry no QML")
            if official is not True:
                raise _error(self.toml, "official", "profiles must set official = true")
            problems = self.profile(metadata)

        files = payload_files(self.directory, self.label)
        gate = (shell_block["modules"], qml_modules) if shell_block else None
        screen_item(self.directory, self.label, files, gate)
        if shell_block is not None:
            sources = scanned_files(self.directory, files)
            problems.extend(behaviour_problems(
                self.label, window_manager,
                compositor_findings(sources) + timer_process_findings(sources),
                load_allowlist(self.repo_root),
            ))
        manifest: dict[str, Any] = {
            "schema": 1,
            "id": item_id,
            "category": self.category,
            "version": version,
            "destination": f"ryoku/{self.category}/{item_id}",
            "files": [
                {
                    "source": relative,
                    "destination": relative,
                    "sha256": hashlib.sha256(file_path.read_bytes()).hexdigest(),
                    "mode": "0755" if file_path.stat().st_mode & 0o111 else "0644",
                    "size": file_path.stat().st_size,
                    "install": True,
                }
                for relative, file_path in files
            ],
        }
        if shell_block is not None:
            manifest["shell"] = shell_block
        manifest_raw = json_bytes(manifest)
        entry: dict[str, Any] = {
            "id": item_id,
            "name": name,
            "version": version,
            "path": self.label,
            "author": ", ".join(authors),
            "summary": summary,
            "description": description,
            "tags": tags,
            "screenshots": screenshots,
            "accent": accent,
            "surface": surface,
            "preview": preview,
            "manifest": "manifest.json",
            "manifestSha256": hashlib.sha256(manifest_raw).hexdigest(),
            "upstream": upstream,
        }
        if official:
            entry["official"] = True
        if paused:
            entry["downloadPaused"] = True
            entry["downloadPauseReason"] = pause_reason
        if window_manager:
            entry["windowManager"] = window_manager
            if reason:
                entry["windowManagerReason"] = reason
        if package_managers:
            entry["packageManagers"] = package_managers
            if reason:
                entry["packageManagersReason"] = reason
        if qml_modules:
            entry["requiresQmlModules"] = qml_modules
        if shell_block is not None:
            provided = {
                kind: [row["id"] for row in shell_block["provides"][kind]]
                for kind in ("dock", "launcher", "desktopWidgets")
                if shell_block["provides"][kind]
            }
            if provided:
                entry["provides"] = provided
        notes: list[str] = []
        if shell_block is not None:
            measured = measurements.load(self.repo_root, item_id)
            notes = measurements.problems(self.label, version, measured, required=listed and not paused)
            if measured is not None and measured["version"] == version and listed:
                entry["metadata"] = measurements.registry_metadata(measured)
        return BuiltItem(self.category, item_id, self.directory, listed, manifest_raw, entry, tuple(notes)), problems


def load_item(repo_root: Path, category: str, item_dir: Path) -> BuiltItem:
    return _Item(repo_root, category, item_dir).build()


def item_directories(repo_root: Path, category: str) -> list[Path]:
    category_dir = repo_root / category
    if not category_dir.is_dir():
        return []
    return sorted(
        (path for path in category_dir.iterdir() if path.is_dir() and (path / "item.toml").is_file()),
        key=lambda path: path.name,
    )


def generate_category(repo_root: Path, category: str, notes: list[str] | None = None) -> dict[Path, bytes]:
    """Generated files for one category. Measurement problems go to `notes` when given."""
    if category not in CATEGORIES:
        raise CatalogueError(f"unknown category {category!r}")
    built: list[BuiltItem] = []
    errors: list[str] = []
    for directory in item_directories(repo_root, category):
        try:
            built.append(load_item(repo_root, category, directory))
        except CatalogueError as error:
            errors.append(str(error))
    if errors:
        raise CatalogueError("\n".join(errors))
    if notes is not None:
        notes.extend(note for item in built for note in item.measurement_notes)
    outputs = {item.directory / "manifest.json": item.manifest_bytes for item in built}
    registry = {"schema": 1, category: [item.registry_entry for item in built if item.listed]}
    outputs[repo_root / category / "registry.json"] = json_bytes(registry)
    return outputs


def selected_categories(repo_root: Path, selectors: list[str]) -> list[str]:
    if not selectors:
        return list(CATEGORIES)
    categories: set[str] = set()
    for selector in selectors:
        parts = PurePosixPath(selector).parts
        if len(parts) != 2 or parts[0] not in CATEGORIES or not ID_PATTERN.fullmatch(parts[1]):
            raise CatalogueError(f"invalid item selector {selector!r}; expected <category>/<id>")
        if not (repo_root / parts[0] / parts[1] / "item.toml").is_file():
            raise CatalogueError(f"{selector}: item.toml is missing")
        categories.add(parts[0])
    return [category for category in CATEGORIES if category in categories]


def build(repo_root: Path, selectors: list[str], *, check: bool, notes: list[str] | None = None) -> list[Path]:
    """Validate and write generated files. Missing or stale measurements fail `check`; otherwise they
    are appended to `notes` and the registry row goes without resource metadata."""
    outputs: dict[Path, bytes] = {}
    errors: list[str] = []
    measurement_notes: list[str] = []
    for category in selected_categories(repo_root, selectors):
        try:
            outputs.update(generate_category(repo_root, category, measurement_notes))
        except CatalogueError as error:
            errors.append(str(error))
    if not selectors:
        labels = {f"{category}/{path.name}" for category in SHELL_CATEGORIES for path in item_directories(repo_root, category)}
        errors.extend(measurements.orphans(repo_root, {label.split("/", 1)[1] for label in labels}))
        try:
            errors.extend(unknown_allowlist_items(load_allowlist(repo_root), labels))
        except BehaviourError as error:
            errors.append(str(error))
    if errors:
        raise CatalogueError("\n".join(errors))
    stale = sorted(path for path, expected in outputs.items() if not path.is_file() or path.read_bytes() != expected)
    if check:
        problems = [
            f"{path.relative_to(repo_root)}: generated file is stale; run python3 tools/build.py" for path in stale
        ] + measurement_notes
        if problems:
            raise CatalogueError("\n".join(problems))
        return []
    if notes is not None:
        notes.extend(measurement_notes)
    for path in stale:
        path.write_bytes(outputs[path])
    return stale
