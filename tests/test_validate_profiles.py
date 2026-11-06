from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
VALIDATOR_PATH = Path(__file__).with_name("validate-profiles.py")
SPEC = importlib.util.spec_from_file_location("validate_profiles", VALIDATOR_PATH)
assert SPEC and SPEC.loader
validate_profiles = importlib.util.module_from_spec(SPEC)
PACKER_PATH = REPO_ROOT / "tools" / "pack-profile.py"
PACKER_SPEC = importlib.util.spec_from_file_location("pack_profile", PACKER_PATH)
assert PACKER_SPEC and PACKER_SPEC.loader
pack_profile = importlib.util.module_from_spec(PACKER_SPEC)
PACKER_SPEC.loader.exec_module(pack_profile)

SPEC.loader.exec_module(validate_profiles)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def webp_chunk(kind: bytes, payload: bytes) -> bytes:
    chunk = kind + struct.pack("<I", len(payload)) + payload
    if len(payload) & 1:
        chunk += b"\0"
    return b"RIFF" + struct.pack("<I", len(chunk) + 4) + b"WEBP" + chunk


def vp8x(width: int, height: int) -> bytes:
    payload = b"\0\0\0\0" + (width - 1).to_bytes(3, "little") + (height - 1).to_bytes(3, "little")
    return webp_chunk(b"VP8X", payload)


def vp8(width: int, height: int) -> bytes:
    payload = b"\0\0\0" + b"\x9d\x01\x2a" + struct.pack("<HH", width, height)
    return webp_chunk(b"VP8 ", payload)


def vp8l(width: int, height: int) -> bytes:
    bits = (width - 1) | ((height - 1) << 14)
    return webp_chunk(b"VP8L", b"\x2f" + bits.to_bytes(4, "little"))


class ProfileTree:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.product = root / "profiles" / "hacker"
        (root / "schema").mkdir(parents=True)
        shutil.copyfile(
            REPO_ROOT / "schema" / "profile.schema.json",
            root / "schema" / "profile.schema.json",
        )
        write_json(self.product / "home/.config/obsidian/obsidian.json", {})
        write_json(self.product / "home/.config/ryoku/rices/hacker/rice.json", {"schema": 1})
        start = self.product / "home/notes/Start here.md"
        start.parent.mkdir(parents=True, exist_ok=True)
        start.write_text("# Start here\n", encoding="utf-8")
        preview = self.product / "assets/preview.webp"
        preview.parent.mkdir(parents=True, exist_ok=True)
        preview.write_bytes(vp8x(1920, 1080))
        self.profile = {
            "schema": 1,
            "id": "hacker",
            "version": "1.0.0",
            "name": "Hacker",
            "requires": {
                "profileApi": 1,
                "packageManagers": ["pacman"],
                "capabilities": [],
            },
            "account": {
                "suggestedName": "hacker",
                "fullName": "Hacker",
                "role": "standard",
                "permissions": ["audio", "devices"],
                "groups": ["wireshark"],
                "shell": "/bin/bash",
            },
            "repos": ["blackarch"],
            "components": [
                {
                    "type": "package",
                    "name": "nmap",
                    "detect": "nmap",
                    "tier": "core",
                    "group": "Recon",
                    "summary": "Port scanner.",
                    "desktopEntries": [],
                }
            ],
            "capabilities": [
                {
                    "tool": "nmap",
                    "caps": "cap_net_raw,cap_net_admin,cap_net_bind_service=eip",
                }
            ],
            "wordlists": {
                "links": [{"name": "seclists", "target": "/usr/share/seclists"}],
                "extract": [
                    {
                        "archive": "/usr/share/seclists/Passwords/rockyou.txt.tar.gz",
                        "member": "rockyou.txt",
                        "name": "rockyou.txt",
                    }
                ],
            },
            "hosts": {"suffixes": ["htb", "thm", "vl"]},
            "env": [{"key": "WORDLISTS", "value": "/usr/share/wordlists"}],
            "path": ["@PROFILE_BIN@", "@HOME@/go/bin"],
            "launcher": {"allow": []},
            "expand": [".config/obsidian/obsidian.json"],
            "seedOnce": ["notes/Start here.md"],
            "userData": ["notes", "engagements", "vpn", ".BurpSuite"],
            "rice": "hacker",
            "firstRun": {
                "command": ["obsidian", "obsidian://open?vault=notes&file=Start%20here"],
                "message": "Hacker is ready.",
            },
        }
        self.entry = {
            "id": "hacker",
            "name": "Hacker",
            "version": "1.0.0",
            "path": "profiles/hacker",
            "author": "Ryoku Team",
            "summary": "a separate account for labs",
            "description": "A focused lab account.",
            "tags": ["htb", "tryhackme", "ctf"],
            "screenshots": [],
            "accent": "#66735B",
            "surface": "#101010",
            "preview": "assets/preview.webp",
            "manifest": "manifest.json",
            "manifestSha256": "0" * 64,
            "official": True,
            "packageManagers": ["pacman"],
            "packageManagersReason": "Profiles need Arch or CachyOS.",
            "upstream": "https://github.com/ryoku-dev/ryostore-revamped/tree/main/profiles/hacker",
        }
        self.pack()

    def pack(self) -> None:
        write_json(self.product / "profile.json", self.profile)
        files = []
        for path in sorted(self.product.rglob("*")):
            if not path.is_file() or path.name == "manifest.json":
                continue
            relative = path.relative_to(self.product).as_posix()
            if relative != "profile.json" and not relative.startswith(("home/", "assets/")):
                continue
            details = path.stat()
            files.append(
                {
                    "source": relative,
                    "destination": relative,
                    "sha256": file_sha256(path),
                    "mode": "0755" if details.st_mode & 0o111 else "0644",
                    "size": details.st_size,
                    "install": True,
                }
            )
        manifest = {
            "schema": 1,
            "id": "hacker",
            "category": "profiles",
            "version": self.profile["version"],
            "destination": "ryoku/profiles/hacker",
            "files": files,
        }
        manifest_path = self.product / "manifest.json"
        write_json(manifest_path, manifest)
        self.entry["version"] = self.profile["version"]
        self.entry["manifestSha256"] = file_sha256(manifest_path)
        self.write_registry()

    def write_registry(self) -> None:
        write_json(self.root / "profiles/registry.json", {"schema": 1, "profiles": [self.entry]})


class ValidateProfilesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.tree = ProfileTree(Path(self.temp.name))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def errors(self) -> list[str]:
        return validate_profiles.validate_tree(self.tree.root)

    def test_valid_profile_tree(self) -> None:
        self.assertEqual([], self.errors())

    def test_schema_rejects_unknown_nested_field(self) -> None:
        self.tree.profile["account"]["rootScript"] = "install.sh"
        self.tree.pack()
        self.assertTrue(any("unknown property rootScript" in error for error in self.errors()))

    def test_allowlists_reject_admin_permission(self) -> None:
        self.tree.profile["account"]["permissions"].append("admin")
        self.tree.pack()
        errors = self.errors()
        self.assertTrue(any("value is not allowed" in error for error in errors))
        self.assertTrue(any("forbidden permission" in error for error in errors))

    def test_absolute_detect_path_is_valid(self) -> None:
        self.tree.profile["components"].append(
            {
                "type": "package",
                "name": "seclists",
                "detect": "/usr/share/seclists",
                "tier": "core",

                "group": "Wordlists",
                "summary": "Security testing wordlists.",
                "desktopEntries": [],
            }
        )
        self.tree.pack()
        self.assertEqual([], self.errors())

    def test_packer_output_is_deterministic(self) -> None:
        pack_profile.pack(self.tree.root, "hacker", False)
        manifest_path = self.tree.product / "manifest.json"
        registry_path = self.tree.root / "profiles/registry.json"
        first = (manifest_path.read_bytes(), registry_path.read_bytes())
        pack_profile.pack(self.tree.root, "hacker", False)
        second = (manifest_path.read_bytes(), registry_path.read_bytes())
        self.assertEqual(first, second)

    def test_expand_file_must_exist(self) -> None:
        self.tree.profile["expand"].append(".config/missing.json")
        self.tree.pack()
        self.assertTrue(any("expand file does not exist" in error for error in self.errors()))

    def test_symlink_is_rejected(self) -> None:
        link = self.tree.product / "home/link"
        link.symlink_to("notes")
        self.assertTrue(any("symlink forbidden: home/link" in error for error in self.errors()))

    def test_manifest_mode_must_match_source(self) -> None:
        manifest_path = self.tree.product / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        row = next(item for item in manifest["files"] if item["source"] == "profile.json")
        row["mode"] = "0755"
        write_json(manifest_path, manifest)
        self.tree.entry["manifestSha256"] = file_sha256(manifest_path)
        self.tree.write_registry()
        self.assertTrue(any("mode mismatch: profile.json" in error for error in self.errors()))

    def test_registry_requires_official_profile(self) -> None:
        self.tree.entry["official"] = False
        self.tree.write_registry()
        self.assertTrue(any("official profiles must set official true" in error for error in self.errors()))

    def test_webp_dimension_headers(self) -> None:
        cases = {
            "vp8.webp": vp8(1920, 1080),
            "vp8l.webp": vp8l(1920, 1080),
            "vp8x.webp": vp8x(1920, 1080),
        }
        for name, data in cases.items():
            with self.subTest(name=name):
                path = self.tree.root / name
                path.write_bytes(data)
                self.assertEqual((1920, 1080), validate_profiles.webp_dimensions(path))

    def test_webp_rejects_wrong_riff_size(self) -> None:
        path = self.tree.root / "bad.webp"
        data = bytearray(vp8x(1920, 1080))
        data[4:8] = struct.pack("<I", 1)
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "RIFF size"):
            validate_profiles.webp_dimensions(path)


if __name__ == "__main__":
    unittest.main()
