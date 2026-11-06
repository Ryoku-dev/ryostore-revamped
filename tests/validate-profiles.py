#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import sys
from typing import Any


MAX_FILES = 2048
MAX_FILE_SIZE = 256 * 1024 * 1024
MAX_PRODUCT_SIZE = 512 * 1024 * 1024
HEX_PATTERN = re.compile(r"^[0-9a-f]{64}$")
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,30}$")
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")
ALLOWED_PACKAGE_MANAGERS = {"pacman", "dnf", "xbps"}
ALLOWED_PERMISSIONS = {"audio", "devices", "virtualization", "containers"}
ALLOWED_REPOS = {"blackarch"}
ALLOWED_GROUPS = {"wireshark"}
ALLOWED_CAPABILITIES = {
    "nmap": "cap_net_raw,cap_net_admin,cap_net_bind_service=eip",
}
ALLOWED_HOST_SUFFIXES = {"htb", "thm", "vl"}
FORBIDDEN_ENV = {"PATH", "HOME", "USER", "XDG_RUNTIME_DIR"}
MANIFEST_FIELDS = {"schema", "id", "category", "version", "destination", "files"}
FILE_FIELDS = {"source", "destination", "sha256", "mode", "size", "install"}
REGISTRY_REQUIRED = {
    "id",
    "name",
    "version",
    "path",
    "author",
    "summary",
    "description",
    "tags",
    "screenshots",
    "accent",
    "surface",
    "preview",
    "manifest",
    "manifestSha256",
    "official",
    "packageManagers",
    "packageManagersReason",
    "upstream",
}
REGISTRY_OPTIONAL = {
    "previewRaw",
    "tagline",
    "icon",
    "hosts",
    "lastUpdated",
    "downloadPaused",
    "downloadPauseReason",
    "windowManager",
    "windowManagerReason",
    "discord",
}
LOAD_FAILED = object()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def reject_json_constant(value: str) -> None:
    raise ValueError(f"invalid numeric constant {value}")


def load_json(path: Path, errors: list[str], label: str) -> object:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            parse_constant=reject_json_constant,
        )
    except FileNotFoundError:
        errors.append(f"{label}: missing")
    except (OSError, UnicodeError, ValueError) as error:
        errors.append(f"{label}: invalid JSON: {error}")
    return LOAD_FAILED


def safe_relative(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return (
        not path.is_absolute()
        and path.as_posix() == value
        and all(
            part not in ("", ".", "..") and not part.startswith(".ryostore-")
            for part in path.parts
        )
    )


def path_has_symlink(root: Path, relative: str) -> bool:
    current = root
    for part in PurePosixPath(relative).parts:
        current /= part
        if current.is_symlink():
            return True
    return False


def product_path(product: Path, relative: object) -> Path | None:
    if not safe_relative(relative):
        return None
    value = str(relative)
    if path_has_symlink(product, value):
        return None
    candidate = product.joinpath(*PurePosixPath(value).parts)
    try:
        candidate.resolve().relative_to(product.resolve())
    except (OSError, ValueError):
        return None
    return candidate


def _schema_type_matches(value: object, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return type(value) is int
    if expected == "number":
        return (type(value) is int) or isinstance(value, float)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return False

def _json_equal(left: object, right: object) -> bool:
    if isinstance(left, bool) or isinstance(right, bool):
        return type(left) is type(right) and left == right
    return left == right



def _resolve_ref(root_schema: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValueError(f"unsupported schema reference {reference!r}")
    current: object = root_schema
    for raw in reference[2:].split("/"):
        key = raw.replace("~1", "/").replace("~0", "~")
        if not isinstance(current, dict) or key not in current:
            raise ValueError(f"unresolved schema reference {reference!r}")
        current = current[key]
    if not isinstance(current, dict):
        raise ValueError(f"schema reference is not an object: {reference!r}")
    return current


def validate_schema(
    value: object,
    schema: dict[str, Any],
    path: str = "$",
    root_schema: dict[str, Any] | None = None,
) -> list[str]:
    root_schema = schema if root_schema is None else root_schema
    errors: list[str] = []
    if "$ref" in schema:
        try:
            target = _resolve_ref(root_schema, schema["$ref"])
        except ValueError as error:
            return [f"{path}: {error}"]
        return validate_schema(value, target, path, root_schema)

    expected = schema.get("type")
    if isinstance(expected, str) and not _schema_type_matches(value, expected):
        return [f"{path}: expected {expected}"]
    if "const" in schema and not _json_equal(value, schema["const"]):
        errors.append(f"{path}: expected {schema['const']!r}")
    choices = schema.get("enum")
    if isinstance(choices, list) and not any(_json_equal(value, choice) for choice in choices):
        errors.append(f"{path}: value is not allowed")

    if isinstance(value, dict):
        required = schema.get("required", [])
        if isinstance(required, list):
            for name in required:
                if name not in value:
                    errors.append(f"{path}: missing property {name}")
        properties = schema.get("properties", {})
        if isinstance(properties, dict):
            if schema.get("additionalProperties") is False:
                for name in sorted(set(value) - set(properties)):
                    errors.append(f"{path}: unknown property {name}")
            for name, child in properties.items():
                if name in value and isinstance(child, dict):
                    errors.extend(
                        validate_schema(value[name], child, f"{path}.{name}", root_schema)
                    )

    if isinstance(value, list):
        minimum = schema.get("minItems")
        if type(minimum) is int and len(value) < minimum:
            errors.append(f"{path}: expected at least {minimum} items")
        maximum = schema.get("maxItems")
        if type(maximum) is int and len(value) > maximum:
            errors.append(f"{path}: expected at most {maximum} items")
        if schema.get("uniqueItems") is True:
            seen: set[str] = set()
            for index, item in enumerate(value):
                encoded = json.dumps(item, sort_keys=True, separators=(",", ":"))
                if encoded in seen:
                    errors.append(f"{path}[{index}]: duplicate item")
                seen.add(encoded)
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                errors.extend(
                    validate_schema(item, item_schema, f"{path}[{index}]", root_schema)
                )

    if isinstance(value, str):
        minimum = schema.get("minLength")
        if type(minimum) is int and len(value) < minimum:
            errors.append(f"{path}: string is too short")
        maximum = schema.get("maxLength")
        if type(maximum) is int and len(value) > maximum:
            errors.append(f"{path}: string is too long")
        pattern = schema.get("pattern")
        if isinstance(pattern, str):
            try:
                matches = re.search(pattern, value) is not None
            except re.error as error:
                errors.append(f"{path}: invalid schema pattern: {error}")
            else:
                if not matches:
                    errors.append(f"{path}: value does not match {pattern}")

    if type(value) is int:
        minimum = schema.get("minimum")
        if type(minimum) in (int, float) and value < minimum:
            errors.append(f"{path}: value is below {minimum}")
        maximum = schema.get("maximum")
        if type(maximum) in (int, float) and value > maximum:
            errors.append(f"{path}: value is above {maximum}")
    return errors


def webp_dimensions(path: Path) -> tuple[int, int]:
    size = path.stat().st_size
    with path.open("rb") as source:
        header = source.read(12)
        if len(header) != 12 or header[:4] != b"RIFF" or header[8:] != b"WEBP":
            raise ValueError("missing RIFF/WEBP header")
        if struct.unpack("<I", header[4:8])[0] != size - 8:
            raise ValueError("RIFF size does not match the file")
        while source.tell() < size:
            chunk_header = source.read(8)
            if len(chunk_header) != 8:
                raise ValueError("truncated chunk header")
            kind = chunk_header[:4]
            chunk_size = struct.unpack("<I", chunk_header[4:])[0]
            payload_start = source.tell()
            if chunk_size > size - payload_start:
                raise ValueError("chunk extends past the file")
            if kind == b"VP8X":
                payload = source.read(min(chunk_size, 10))
                if chunk_size < 10 or len(payload) < 10:
                    raise ValueError("truncated VP8X header")
                width = 1 + int.from_bytes(payload[4:7], "little")
                height = 1 + int.from_bytes(payload[7:10], "little")
                return width, height
            if kind == b"VP8 ":
                payload = source.read(min(chunk_size, 10))
                if chunk_size < 10 or len(payload) < 10 or payload[3:6] != b"\x9d\x01\x2a":
                    raise ValueError("invalid VP8 frame header")
                width = int.from_bytes(payload[6:8], "little") & 0x3FFF
                height = int.from_bytes(payload[8:10], "little") & 0x3FFF
                return width, height
            if kind == b"VP8L":
                payload = source.read(min(chunk_size, 5))
                if chunk_size < 5 or len(payload) < 5 or payload[0] != 0x2F:
                    raise ValueError("invalid VP8L frame header")
                bits = int.from_bytes(payload[1:5], "little")
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
            source.seek(payload_start + chunk_size + (chunk_size & 1))
    raise ValueError("missing VP8, VP8L or VP8X image chunk")


def _walk_product(product: Path) -> tuple[dict[str, Path], list[str], list[str]]:
    files: dict[str, Path] = {}
    symlinks: list[str] = []
    special: list[str] = []
    pending = [product]
    while pending:
        directory = pending.pop()
        try:
            entries = sorted(os.scandir(directory), key=lambda entry: entry.name)
        except OSError:
            continue
        for entry in entries:
            relative = Path(entry.path).relative_to(product).as_posix()
            if ".git" in PurePosixPath(relative).parts:
                continue
            if entry.is_symlink():
                symlinks.append(relative)
            elif entry.is_dir(follow_symlinks=False):
                pending.append(Path(entry.path))
            elif entry.is_file(follow_symlinks=False):
                files[relative] = Path(entry.path)
            else:
                special.append(relative)
    return files, symlinks, special


def _validate_registry_row(entry: object, errors: list[str]) -> tuple[str, str] | None:
    if not isinstance(entry, dict):
        errors.append("profiles/?: registry row must be an object")
        return None
    product_id = entry.get("id")
    label = f"profiles/{product_id if isinstance(product_id, str) else '?'}"
    missing = sorted(REGISTRY_REQUIRED - set(entry))
    for field in missing:
        errors.append(f"{label}: missing registry field {field}")
    for field in sorted(set(entry) - REGISTRY_REQUIRED - REGISTRY_OPTIONAL):
        errors.append(f"{label}: unknown registry field {field}")
    if not isinstance(product_id, str) or not ID_PATTERN.fullmatch(product_id):
        errors.append(f"{label}: invalid id")
        return None
    version = entry.get("version")
    if not isinstance(version, str) or not SEMVER_PATTERN.fullmatch(version):
        errors.append(f"{label}: invalid version")
    for field in ("name", "author", "summary", "description", "packageManagersReason", "upstream"):
        if not isinstance(entry.get(field), str) or not entry[field]:
            errors.append(f"{label}: {field} must be a non-empty string")
    for field in ("tags", "screenshots"):
        value = entry.get(field)
        if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
            errors.append(f"{label}: {field} must be an array of non-empty strings")
    for field in ("accent", "surface"):
        value = entry.get(field)
        if not isinstance(value, str) or not COLOR_PATTERN.fullmatch(value):
            errors.append(f"{label}: {field} must be a six-digit hex colour")
    if entry.get("official") is not True:
        errors.append(f"{label}: official profiles must set official true")
    managers = entry.get("packageManagers")
    if not isinstance(managers, list) or not managers or not all(
        isinstance(manager, str) and manager in ALLOWED_PACKAGE_MANAGERS
        for manager in managers
    ):
        errors.append(f"{label}: packageManagers contains an unknown manager")
    elif "pacman" not in managers:
        errors.append(f"{label}: packageManagers must include pacman")
    expected_path = f"profiles/{product_id}"
    if entry.get("path") != expected_path:
        errors.append(f"{label}: path must be {expected_path}")
    if entry.get("manifest") != "manifest.json":
        errors.append(f"{label}: manifest must be manifest.json")
    if entry.get("preview") != "assets/preview.webp":
        errors.append(f"{label}: preview must be assets/preview.webp")
    for field in ("screenshots",):
        value = entry.get(field)
        if isinstance(value, list):
            for item in value:
                if not safe_relative(item):
                    errors.append(f"{label}: invalid {field} path {item!r}")
    digest = entry.get("manifestSha256")
    if not isinstance(digest, str) or not HEX_PATTERN.fullmatch(digest):
        errors.append(f"{label}: manifestSha256 must be lowercase SHA-256")
    return product_id, version if isinstance(version, str) else ""


def _source_allowed(source: str) -> bool:
    return source == "profile.json" or source.startswith("home/") or source.startswith("assets/")


def _validate_manifest(
    root: Path,
    product: Path,
    entry: dict[str, Any],
    schema: dict[str, Any],
    errors: list[str],
) -> None:
    product_id = entry["id"]
    label = f"profiles/{product_id}"
    manifest_path = product / "manifest.json"
    if manifest_path.is_symlink():
        errors.append(f"{label}: manifest.json must not be a symlink")
        return
    manifest = load_json(manifest_path, errors, f"{label}/manifest.json")
    if manifest is LOAD_FAILED:
        return
    expected_hash = entry.get("manifestSha256")
    if isinstance(expected_hash, str) and HEX_PATTERN.fullmatch(expected_hash):
        try:
            actual_hash = sha256(manifest_path)
        except OSError as error:
            errors.append(f"{label}: cannot hash manifest: {error}")
        else:
            if actual_hash != expected_hash:
                errors.append(f"{label}: manifest hash mismatch")
    if not isinstance(manifest, dict):
        errors.append(f"{label}: manifest must be an object")
        return
    for field in sorted(set(manifest) - MANIFEST_FIELDS):
        errors.append(f"{label}: unknown manifest field {field}")
    for field in sorted(MANIFEST_FIELDS - set(manifest)):
        errors.append(f"{label}: missing manifest field {field}")
    expected = {
        "schema": 1,
        "id": product_id,
        "category": "profiles",
        "version": entry.get("version"),
        "destination": f"ryoku/profiles/{product_id}",
    }
    for field, value in expected.items():
        if manifest.get(field) != value or (field == "schema" and type(manifest.get(field)) is not int):
            errors.append(f"{label}: manifest {field} does not match the registry")

    rows = manifest.get("files")
    if not isinstance(rows, list) or not rows:
        errors.append(f"{label}: manifest files must be a non-empty array")
        return
    if len(rows) > MAX_FILES:
        errors.append(f"{label}: manifest has more than {MAX_FILES} files")
    declared: dict[str, dict[str, Any]] = {}
    destinations: set[str] = set()
    total_size = 0
    previous_source = ""
    for index, row in enumerate(rows):
        row_label = f"{label}: files[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{row_label} must be an object")
            continue
        for field in sorted(set(row) - FILE_FIELDS):
            errors.append(f"{row_label}: unknown field {field}")
        for field in sorted(FILE_FIELDS - set(row)):
            errors.append(f"{row_label}: missing field {field}")
        source = row.get("source")
        destination = row.get("destination")
        if not safe_relative(source) or not _source_allowed(str(source)):
            errors.append(f"{row_label}: invalid source {source!r}")
            continue
        source = str(source)
        if source <= previous_source:
            errors.append(f"{row_label}: sources must be sorted and unique")
        previous_source = source
        if destination != source or not safe_relative(destination):
            errors.append(f"{row_label}: destination must equal source")
        if source in declared:
            errors.append(f"{row_label}: duplicate source {source}")
        if isinstance(destination, str):
            if destination in destinations:
                errors.append(f"{row_label}: duplicate destination {destination}")
            for existing in destinations:
                if existing.startswith(destination + "/") or destination.startswith(existing + "/"):
                    errors.append(f"{row_label}: destination collision {destination}")
                    break
            destinations.add(destination)
        if row.get("install") is not True:
            errors.append(f"{row_label}: install must be true")
        mode = row.get("mode")
        if mode not in ("0644", "0755"):
            errors.append(f"{row_label}: invalid mode {mode!r}")
        size = row.get("size")
        if type(size) is not int or size < 0 or size > MAX_FILE_SIZE:
            errors.append(f"{row_label}: invalid size {size!r}")
            size = 0
        total_size += size
        digest = row.get("sha256")
        if not isinstance(digest, str) or not HEX_PATTERN.fullmatch(digest):
            errors.append(f"{row_label}: invalid sha256")
        declared[source] = row
    if total_size > MAX_PRODUCT_SIZE:
        errors.append(f"{label}: declared product exceeds {MAX_PRODUCT_SIZE} bytes")

    actual_files, symlinks, special = _walk_product(product)
    for relative in symlinks:
        errors.append(f"{label}: symlink forbidden: {relative}")
    for relative in special:
        errors.append(f"{label}: special file forbidden: {relative}")
    payload_files = {name: path for name, path in actual_files.items() if name != "manifest.json"}
    for relative in sorted(set(payload_files) - set(declared)):
        errors.append(f"{label}: undeclared payload {relative}")
    for relative in sorted(set(declared) - set(payload_files)):
        errors.append(f"{label}: declared source missing: {relative}")
    for relative in sorted(set(declared) & set(payload_files)):
        row = declared[relative]
        path = payload_files[relative]
        try:
            details = path.stat()
        except OSError as error:
            errors.append(f"{label}: cannot inspect {relative}: {error}")
            continue
        if details.st_size != row.get("size"):
            errors.append(f"{label}: size mismatch: {relative}")
        digest = row.get("sha256")
        if isinstance(digest, str) and HEX_PATTERN.fullmatch(digest):
            try:
                actual_digest = sha256(path)
            except OSError as error:
                errors.append(f"{label}: cannot hash {relative}: {error}")
            else:
                if actual_digest != digest:
                    errors.append(f"{label}: sha256 mismatch: {relative}")
        expected_mode = "0755" if details.st_mode & 0o111 else "0644"
        if row.get("mode") != expected_mode:
            errors.append(f"{label}: mode mismatch: {relative}")

    profile_path = payload_files.get("profile.json")
    if profile_path is None:
        errors.append(f"{label}: profile.json is missing from the payload")
    else:
        profile = load_json(profile_path, errors, f"{label}/profile.json")
        if profile is not LOAD_FAILED:
            schema_errors = validate_schema(profile, schema)
            errors.extend(f"{label}/profile.json: {issue}" for issue in schema_errors)
            if isinstance(profile, dict):
                _validate_profile_semantics(product, entry, profile, errors)

    preview_path = product / "assets" / "preview.webp"
    if preview_path.is_symlink() or not preview_path.is_file():
        errors.append(f"{label}: assets/preview.webp is missing or is a symlink")
    else:
        try:
            dimensions = webp_dimensions(preview_path)
        except (OSError, ValueError) as error:
            errors.append(f"{label}: unreadable preview.webp: {error}")
        else:
            if dimensions != (1920, 1080):
                errors.append(
                    f"{label}: preview.webp must be 1920x1080, got {dimensions[0]}x{dimensions[1]}"
                )


def _validate_profile_semantics(
    product: Path,
    entry: dict[str, Any],
    profile: dict[str, Any],
    errors: list[str],
) -> None:
    label = f"profiles/{entry['id']}/profile.json"
    for field in ("id", "version", "name"):
        if profile.get(field) != entry.get(field):
            errors.append(f"{label}: {field} does not match the registry")
    requires = profile.get("requires")
    if isinstance(requires, dict):
        managers = requires.get("packageManagers")
        if isinstance(managers, list):
            if any(manager not in ALLOWED_PACKAGE_MANAGERS for manager in managers):
                errors.append(f"{label}: requires.packageManagers contains an unknown manager")
            if "pacman" not in managers:
                errors.append(f"{label}: requires.packageManagers must include pacman")
    account = profile.get("account")
    if isinstance(account, dict):
        permissions = account.get("permissions")
        if isinstance(permissions, list) and any(value not in ALLOWED_PERMISSIONS for value in permissions):
            errors.append(f"{label}: account.permissions contains a forbidden permission")
        groups = account.get("groups")
        if isinstance(groups, list) and any(value not in ALLOWED_GROUPS for value in groups):
            errors.append(f"{label}: account.groups contains a forbidden group")
    repos = profile.get("repos")
    if isinstance(repos, list) and any(value not in ALLOWED_REPOS for value in repos):
        errors.append(f"{label}: repos contains a forbidden repository")
    hosts = profile.get("hosts")
    if isinstance(hosts, dict):
        suffixes = hosts.get("suffixes")
        if isinstance(suffixes, list) and any(value not in ALLOWED_HOST_SUFFIXES for value in suffixes):
            errors.append(f"{label}: hosts.suffixes contains a forbidden suffix")

    components = profile.get("components")
    names: set[str] = set()
    command_detects: set[str] = set()
    if isinstance(components, list):
        for component in components:
            if not isinstance(component, dict):
                continue
            name = component.get("name")
            if isinstance(name, str):
                if name in names:
                    errors.append(f"{label}: duplicate component {name}")
                names.add(name)
            detect = component.get("detect")
            if isinstance(detect, str) and not detect.startswith("/"):
                command_detects.add(detect)
    capabilities = profile.get("capabilities")
    seen_tools: set[str] = set()
    if isinstance(capabilities, list):
        for capability in capabilities:
            if not isinstance(capability, dict):
                continue
            tool = capability.get("tool")
            caps = capability.get("caps")
            if tool in seen_tools:
                errors.append(f"{label}: duplicate capability tool {tool}")
            if isinstance(tool, str):
                seen_tools.add(tool)
            if not isinstance(tool, str) or ALLOWED_CAPABILITIES.get(tool) != caps:
                errors.append(f"{label}: capability {tool!r} is not allowed")
            elif tool not in command_detects:
                errors.append(f"{label}: capability tool {tool} is not a component command")

    env = profile.get("env")
    seen_env: set[str] = set()
    if isinstance(env, list):
        for variable in env:
            if not isinstance(variable, dict):
                continue
            key = variable.get("key")
            if isinstance(key, str):
                if key in seen_env:
                    errors.append(f"{label}: duplicate environment key {key}")
                seen_env.add(key)
                if key in FORBIDDEN_ENV or key.startswith("LD_"):
                    errors.append(f"{label}: environment key {key} is forbidden")
            value = variable.get("value")
            if isinstance(value, str) and ("\n" in value or "\r" in value):
                errors.append(f"{label}: environment value for {key} must be one line")

    first_run = profile.get("firstRun")
    if isinstance(first_run, dict):
        message = first_run.get("message")
        if isinstance(message, str) and ("\n" in message or "\r" in message):
            errors.append(f"{label}: firstRun.message must be one line")
        command = first_run.get("command")
        if isinstance(command, list):
            for argument in command:
                if isinstance(argument, str) and ("\n" in argument or "\r" in argument):
                    errors.append(f"{label}: firstRun.command arguments must be one line")
                    break

    for field in ("expand", "seedOnce"):
        values = profile.get(field)
        if not isinstance(values, list):
            continue
        for value in values:
            target = product_path(product / "home", value)
            if target is None or not target.is_file() or target.is_symlink():
                errors.append(f"{label}: {field} file does not exist: {value}")
    rice = profile.get("rice")
    if isinstance(rice, str):
        relative = f".config/ryoku/rices/{rice}/rice.json"
        target = product_path(product / "home", relative)
        if target is None or not target.is_file() or target.is_symlink():
            errors.append(f"{label}: rice does not exist: {rice}")


def validate_tree(root: Path) -> list[str]:
    root = Path(root).absolute()
    errors: list[str] = []
    schema_path = root / "schema" / "profile.schema.json"
    if schema_path.is_symlink():
        errors.append("schema/profile.schema.json: symlink forbidden")
        return errors
    schema_value = load_json(schema_path, errors, "schema/profile.schema.json")
    if not isinstance(schema_value, dict):
        if schema_value is not LOAD_FAILED:
            errors.append("schema/profile.schema.json: root must be an object")
        return errors
    registry_path = root / "profiles" / "registry.json"
    if registry_path.is_symlink():
        errors.append("profiles/registry.json: symlink forbidden")
        return errors
    registry = load_json(registry_path, errors, "profiles/registry.json")
    if registry is LOAD_FAILED:
        return errors
    if not isinstance(registry, dict):
        errors.append("profiles/registry.json: root must be an object")
        return errors
    if set(registry) != {"schema", "profiles"}:
        errors.append("profiles/registry.json: invalid registry envelope")
        return errors
    if type(registry.get("schema")) is not int or registry["schema"] != 1:
        errors.append("profiles/registry.json: unsupported schema")
    entries = registry.get("profiles")
    if not isinstance(entries, list):
        errors.append("profiles/registry.json: profiles must be an array")
        return errors
    seen: set[str] = set()
    for entry in entries:
        identity = _validate_registry_row(entry, errors)
        if identity is None or not isinstance(entry, dict):
            continue
        product_id, _ = identity
        if product_id in seen:
            errors.append(f"profiles/{product_id}: duplicate id")
            continue
        seen.add(product_id)
        relative = f"profiles/{product_id}"
        if path_has_symlink(root, relative):
            errors.append(f"profiles/{product_id}: product path contains a symlink")
            continue
        product = root / "profiles" / product_id
        if not product.is_dir():
            errors.append(f"profiles/{product_id}: product directory is missing")
            continue
        _validate_manifest(root, product, entry, schema_value, errors)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate Ryoku installable profiles")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args(argv)
    errors = validate_tree(args.root)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"{len(errors)} profile catalogue error(s) found", file=sys.stderr)
        return 1
    print("profile catalogue OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
