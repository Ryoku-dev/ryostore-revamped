#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys


REPO_ROOT = Path(__file__).resolve().parent.parent
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,30}$")
MAX_FILES = 2048
MAX_FILE_SIZE = 256 * 1024 * 1024
MAX_PRODUCT_SIZE = 512 * 1024 * 1024


def reject_json_constant(value: str) -> None:
    raise ValueError(f"invalid numeric constant {value}")


def read_json(path: Path) -> object:
    return json.loads(
        path.read_text(encoding="utf-8"),
        parse_constant=reject_json_constant,
    )


def write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _walk_directory(product: Path, directory: Path) -> list[tuple[str, Path]]:
    files: list[tuple[str, Path]] = []
    pending = [directory]
    while pending:
        current = pending.pop()
        entries = sorted(os.scandir(current), key=lambda entry: entry.name, reverse=True)
        for entry in entries:
            relative = Path(entry.path).relative_to(product).as_posix()
            if ".git" in PurePosixPath(relative).parts:
                continue
            if entry.is_symlink():
                raise ValueError(f"symlink forbidden: {relative}")
            if entry.is_dir(follow_symlinks=False):
                pending.append(Path(entry.path))
            elif entry.is_file(follow_symlinks=False):
                files.append((relative, Path(entry.path)))
            else:
                raise ValueError(f"special file forbidden: {relative}")
    return files


def payload_files(product: Path) -> list[tuple[str, Path]]:
    profile = product / "profile.json"
    if profile.is_symlink():
        raise ValueError("symlink forbidden: profile.json")
    if not profile.is_file():
        raise ValueError("profile.json is missing")
    files = [("profile.json", profile)]
    for name in ("home", "assets"):
        directory = product / name
        if directory.is_symlink():
            raise ValueError(f"symlink forbidden: {name}")
        if not directory.is_dir():
            raise ValueError(f"{name}/ is missing")
        files.extend(_walk_directory(product, directory))
    files.sort(key=lambda item: item[0])
    return files


def build_manifest(product: Path, product_id: str, version: str) -> dict:
    rows = []
    total = 0
    files = payload_files(product)
    if not files or len(files) > MAX_FILES:
        raise ValueError(f"profile has {len(files)} files, maximum is {MAX_FILES}")
    for relative, path in files:
        details = path.stat()
        if details.st_size > MAX_FILE_SIZE:
            raise ValueError(f"{relative} exceeds {MAX_FILE_SIZE} bytes")
        total += details.st_size
        if total > MAX_PRODUCT_SIZE:
            raise ValueError(f"profile exceeds {MAX_PRODUCT_SIZE} bytes")
        rows.append(
            {
                "source": relative,
                "destination": relative,
                "sha256": sha256(path),
                "mode": "0755" if details.st_mode & 0o111 else "0644",
                "size": details.st_size,
                "install": True,
            }
        )
    return {
        "schema": 1,
        "id": product_id,
        "category": "profiles",
        "version": version,
        "destination": f"ryoku/profiles/{product_id}",
        "files": rows,
    }


def _registry(root: Path) -> tuple[dict, list[dict]]:
    path = root / "profiles" / "registry.json"
    value = read_json(path)
    if not isinstance(value, dict) or set(value) != {"schema", "profiles"}:
        raise ValueError("profiles/registry.json has an invalid envelope")
    if type(value.get("schema")) is not int or value["schema"] != 1:
        raise ValueError("profiles/registry.json has an unsupported schema")
    entries = value.get("profiles")
    if not isinstance(entries, list) or not all(isinstance(entry, dict) for entry in entries):
        raise ValueError("profiles/registry.json profiles must be an array of objects")
    return value, entries


def pack_profile(root: Path, product_id: str, entry: dict) -> dict:
    if not ID_PATTERN.fullmatch(product_id):
        raise ValueError(f"invalid profile id {product_id!r}")
    if entry.get("id") != product_id:
        raise ValueError(f"profiles/{product_id}: registry id mismatch")
    if entry.get("path") != f"profiles/{product_id}":
        raise ValueError(f"profiles/{product_id}: registry path is not canonical")
    if entry.get("manifest") != "manifest.json":
        raise ValueError(f"profiles/{product_id}: registry manifest must be manifest.json")
    product = root / "profiles" / product_id
    if product.is_symlink() or not product.is_dir():
        raise ValueError(f"profiles/{product_id}: product directory is missing or is a symlink")
    profile_path = product / "profile.json"
    if profile_path.is_symlink():
        raise ValueError(f"profiles/{product_id}/profile.json must not be a symlink")
    profile_value = read_json(profile_path)
    if not isinstance(profile_value, dict):
        raise ValueError(f"profiles/{product_id}/profile.json must be an object")
    if profile_value.get("id") != product_id:
        raise ValueError(f"profiles/{product_id}/profile.json id mismatch")
    version = profile_value.get("version")
    if not isinstance(version, str) or not version:
        raise ValueError(f"profiles/{product_id}/profile.json version is missing")
    entry["version"] = version
    manifest = build_manifest(product, product_id, version)
    manifest_path = product / "manifest.json"
    if manifest_path.is_symlink():
        raise ValueError(f"profiles/{product_id}/manifest.json must not be a symlink")
    write_json(manifest_path, manifest)
    entry["manifestSha256"] = sha256(manifest_path)
    return manifest


def pack(root: Path, selection: str | None, all_profiles: bool) -> list[tuple[str, dict]]:
    registry, entries = _registry(root)
    by_id: dict[str, dict] = {}
    for entry in entries:
        product_id = entry.get("id")
        if not isinstance(product_id, str):
            raise ValueError("registry row has no string id")
        if product_id in by_id:
            raise ValueError(f"duplicate profile id {product_id}")
        by_id[product_id] = entry
    if all_profiles:
        ids = sorted(by_id)
    else:
        if selection not in by_id:
            raise ValueError(f"unknown profile {selection!r}")
        ids = [str(selection)]
    packed = [(product_id, pack_profile(root, product_id, by_id[product_id])) for product_id in ids]
    write_json(root / "profiles" / "registry.json", registry)
    return packed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Build profile manifests and refresh their registry hashes",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("profile", nargs="?", help="profile id")
    group.add_argument("--all", action="store_true", help="pack every registered profile")
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="catalogue root",
    )
    args = parser.parse_args(argv)
    try:
        packed = pack(args.root.resolve(), args.profile, args.all)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"pack-profile: {error}", file=sys.stderr)
        return 1
    for product_id, manifest in packed:
        print(f"profiles/{product_id}: wrote manifest ({len(manifest['files'])} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
