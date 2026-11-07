from __future__ import annotations

import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))

from ryostore_tools.catalogue import CatalogueError, build, generate_category


TEMPLATE_IDS = {"subshell": "example-subshell", "barstyle": "example-barstyle", "profile": "example-profile"}
CATEGORY_TEMPLATES = {"subshells": "subshell", "barstyles": "barstyle", "profiles": "profile"}


def webp(width: int, height: int) -> bytes:
    bits = (width - 1) | ((height - 1) << 14)
    chunk = b"VP8L" + struct.pack("<I", 5) + bytes([0x2F]) + bits.to_bytes(4, "little") + b"\x00"
    body = b"WEBP" + chunk
    return b"RIFF" + struct.pack("<I", len(body)) + body


class CatalogueTree:
    def __init__(self, root: Path) -> None:
        self.root = root
        shutil.copytree(REPO_ROOT / "schema", root / "schema")

    def add(self, category: str, item_id: str) -> Path:
        template = CATEGORY_TEMPLATES[category]
        destination = self.root / category / item_id
        shutil.copytree(REPO_ROOT / "templates" / template, destination)
        item = destination / "item.toml"
        item.write_text(item.read_text(encoding="utf-8").replace(f'id = "{TEMPLATE_IDS[template]}"', f'id = "{item_id}"', 1), encoding="utf-8")
        profile = destination / "profile.json"
        if profile.is_file():
            value = json.loads(profile.read_text(encoding="utf-8"))
            value["id"] = item_id
            profile.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return destination


def write(path: Path, text: str, mode: int = 0o644) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    path.chmod(mode)
    return path


def edit_toml(item: Path, top: str = "", tail: str = "") -> None:
    path = item / "item.toml"
    text = path.read_text(encoding="utf-8")
    if top:
        text = text.replace("\npreview =", f"\n{top}\npreview =", 1)
    path.write_text(text + tail, encoding="utf-8")


def prepend(path: Path, text: str) -> None:
    path.write_text(text + path.read_text(encoding="utf-8"), encoding="utf-8")


class TreeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.tree = CatalogueTree(self.root)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def registry(self, category: str) -> dict:
        return json.loads(generate_category(self.root, category)[self.root / category / "registry.json"])

    def assertFails(self, category: str, pattern: str) -> None:
        with self.assertRaisesRegex(CatalogueError, pattern):
            generate_category(self.root, category)


class TemplateTests(TreeTest):
    def test_every_template_builds(self) -> None:
        for category in CATEGORY_TEMPLATES:
            self.tree.add(category, f"sample-{category}")
        written = build(self.root, [], check=False)
        self.assertIn(self.root / "profiles/registry.json", written)
        self.assertEqual(build(self.root, [], check=True), [])

    def test_manifest_and_registry_envelope(self) -> None:
        self.tree.add("barstyles", "sample-bar")
        build(self.root, ["barstyles/sample-bar"], check=False)
        manifest = json.loads((self.root / "barstyles/sample-bar/manifest.json").read_text())
        registry = json.loads((self.root / "barstyles/registry.json").read_text())
        self.assertEqual(manifest["destination"], "ryoku/barstyles/sample-bar")
        self.assertEqual(manifest["shell"]["entry"], "qml/Scene.qml")
        self.assertNotIn("manifest.json", [row["source"] for row in manifest["files"]])
        self.assertEqual(set(registry), {"schema", "barstyles"})
        self.assertEqual(registry["barstyles"][0]["path"], "barstyles/sample-bar")

    def test_check_reports_stale_generated_file(self) -> None:
        self.tree.add("subshells", "sample-shell")
        with self.assertRaisesRegex(CatalogueError, "subshells/sample-shell/manifest.json: generated file is stale"):
            build(self.root, ["subshells/sample-shell"], check=True)

    def test_errors_from_every_item_are_reported(self) -> None:
        for item_id in ("first-bar", "second-bar"):
            write(self.tree.add("barstyles", item_id) / "stray.txt", "x")
        with self.assertRaises(CatalogueError) as caught:
            generate_category(self.root, "barstyles")
        self.assertIn("barstyles/first-bar/stray.txt", str(caught.exception))
        self.assertIn("barstyles/second-bar/stray.txt", str(caught.exception))


class MetadataTests(TreeTest):
    def test_unlisted_item_gets_manifest_but_no_registry_row(self) -> None:
        item = self.tree.add("barstyles", "waiting-bar")
        edit_toml(item, top="listed = false")
        outputs = generate_category(self.root, "barstyles")
        self.assertIn(item / "manifest.json", outputs)
        self.assertEqual(json.loads(outputs[self.root / "barstyles/registry.json"])["barstyles"], [])

    def test_download_pause_is_copied_to_registry(self) -> None:
        item = self.tree.add("subshells", "paused-shell")
        edit_toml(item, top='downloadPaused = true\ndownloadPauseReason = "Waiting for an upstream fix."')
        row = self.registry("subshells")["subshells"][0]
        self.assertTrue(row["downloadPaused"])
        self.assertEqual(row["downloadPauseReason"], "Waiting for an upstream fix.")

    def test_download_pause_needs_reason(self) -> None:
        item = self.tree.add("subshells", "paused-shell")
        edit_toml(item, top="downloadPaused = true")
        self.assertFails("subshells", r"item.toml:downloadPauseReason: required")

    def test_owns_accepts_every_surface(self) -> None:
        item = self.tree.add("barstyles", "close-bar")
        path = item / "item.toml"
        surfaces = '"notifications", "notificationSound", "osd", "polkit", "dock", "widgets", "cheatsheet", "windowClose"'
        path.write_text(path.read_text().replace("owns = []", f"owns = [{surfaces}]"))
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)
        path.write_text(path.read_text().replace('"windowClose"', '"launcher"'))
        self.assertFails("barstyles", r"shell.owns: unsupported surface 'launcher'")

    def test_owns_setting_is_validated_and_emitted(self) -> None:
        item = self.tree.add("barstyles", "quiet-bar")
        path = item / "item.toml"
        base = path.read_text().replace("owns = []", 'owns = ["notifications"]')
        path.write_text(base + '\n[shell.ownsSetting]\nnotifications = "quiet.general.notifications"\n')
        manifest = json.loads(generate_category(self.root, "barstyles")[item / "manifest.json"])
        self.assertEqual(manifest["shell"]["ownsSetting"], {"notifications": "quiet.general.notifications"})
        path.write_text(base + '\n[shell.ownsSetting]\nosd = "quiet.general.osd"\n')
        self.assertFails("barstyles", r"shell.ownsSetting.osd: surface is not listed in shell.owns")
        path.write_text(base + '\n[shell.ownsSetting]\nnotifications = "notifications"\n')
        self.assertFails("barstyles", r"shell.ownsSetting.notifications: expected a dotted shell.json key")

    def test_shell_env_is_validated_and_emitted(self) -> None:
        item = self.tree.add("barstyles", "env-bar")
        path = item / "item.toml"
        base = path.read_text()
        path.write_text(base + '\n[shell.env]\nOMARCHY_PATH = "$XDG_DATA_HOME/ryoku/nomarchy"\nTHEME_DIR = "$RYOKU_ITEM_DIR/data"\n')
        manifest = json.loads(generate_category(self.root, "barstyles")[item / "manifest.json"])
        self.assertEqual(manifest["shell"]["env"], {"OMARCHY_PATH": "$XDG_DATA_HOME/ryoku/nomarchy", "THEME_DIR": "$RYOKU_ITEM_DIR/data"})

    def test_shell_env_defaults_to_empty(self) -> None:
        item = self.tree.add("barstyles", "plain-bar")
        manifest = json.loads(generate_category(self.root, "barstyles")[item / "manifest.json"])
        self.assertEqual(manifest["shell"]["env"], {})

    def test_shell_env_rejects_protected_keys(self) -> None:
        item = self.tree.add("barstyles", "env-bar")
        path = item / "item.toml"
        base = path.read_text()
        for key in ("PATH", "LC_ALL", "QML_IMPORT_PATH", "XDG_DATA_HOME", "RYOKU_ITEM_ID", "DISPLAY"):
            path.write_text(base + f'\n[shell.env]\n{key} = "x"\n')
            self.assertFails("barstyles", rf"shell.env.{key}: protected variable")
        path.write_text(base + '\n[shell.env]\nlower = "x"\n')
        self.assertFails("barstyles", r"shell.env.lower: expected a name matching")
        path.write_text(base + '\n[shell.env]\nLEVEL = 3\n')
        self.assertFails("barstyles", r"shell.env.LEVEL: expected a string")

    def test_shell_env_rejects_unknown_variables(self) -> None:
        item = self.tree.add("barstyles", "env-bar")
        path = item / "item.toml"
        base = path.read_text()
        for value in ("$USER/x", "${HOME}/x", "$HOMEDIR", "cost $5"):
            path.write_text(base + f'\n[shell.env]\nTARGET = "{value}"\n')
            self.assertFails("barstyles", r"shell.env.TARGET: only \$HOME, \$XDG_DATA_HOME")

    def test_entries_live_in_qml_and_scripts_in_bin(self) -> None:
        item = self.tree.add("barstyles", "place-bar")
        write(item / "data/Scene.qml", "import QtQuick\nItem {}\n")
        path = item / "item.toml"
        path.write_text(path.read_text().replace('entry = "qml/Scene.qml"', 'entry = "data/Scene.qml"'))
        self.assertFails("barstyles", r"shell.entry: must be inside qml/")
        path.write_text(path.read_text().replace('entry = "data/Scene.qml"', 'entry = "qml/Scene.qml"'))
        write(item / "data/activate", "#!/bin/sh\n", 0o755)
        edit_toml(item, tail='\n[lifecycle]\nactivate = "data/activate"\n')
        self.assertFails("barstyles", r"lifecycle.activate: must be inside bin/")

    def test_preview_must_be_1920x1080_webp(self) -> None:
        item = self.tree.add("barstyles", "small-bar")
        (item / "preview.webp").write_bytes(webp(640, 360))
        self.assertFails("barstyles", r"preview must be 1920x1080, got 640x360")


class LayoutTests(TreeTest):
    def test_shell_item_layout_is_fixed(self) -> None:
        item = self.tree.add("barstyles", "tidy-bar")
        write(item / "data/theme.json", "{}")
        write(item / "NOTICE", "credit\n")
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)
        write(item / "themes/dark.json", "{}")
        write(item / "notes.txt", "x")
        with self.assertRaises(CatalogueError) as caught:
            generate_category(self.root, "barstyles")
        self.assertIn("barstyles/tidy-bar/themes/: folder is not part of the item layout", str(caught.exception))
        self.assertIn("barstyles/tidy-bar/notes.txt: file is not part of the item layout", str(caught.exception))

    def test_profile_assets_need_a_reference(self) -> None:
        item = self.tree.add("profiles", "asset-profile")
        (item / "assets").mkdir()
        (item / "assets/logo.webp").write_bytes(webp(64, 64))
        self.assertFails("profiles", r"profiles/asset-profile/assets/: folder is not part of the item layout")
        profile_path = item / "profile.json"
        profile = json.loads(profile_path.read_text())
        profile["firstRun"]["message"] = "See assets/logo.webp"
        profile_path.write_text(json.dumps(profile))
        self.assertFails("profiles", r"assets/: folder is not part")
        profile["firstRun"]["command"] = ["xdg-open", "assets/logo.webp"]
        profile_path.write_text(json.dumps(profile))
        self.assertEqual(len(self.registry("profiles")["profiles"]), 1)


class ImportGateTests(TreeTest):
    def setUp(self) -> None:
        super().setUp()
        self.item = self.tree.add("barstyles", "gate-bar")
        self.scene = self.item / "qml/Scene.qml"

    def test_qt_and_platform_modules_pass(self) -> None:
        prepend(self.scene, "import QtQml\nimport Qt5Compat.GraphicalEffects\nimport Qt.labs.platform\nimport Ryoku.FrameBars\nimport shell.barkit\n")
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)

    def test_unknown_module_fails_with_file_and_line(self) -> None:
        prepend(self.scene, "import QtQuick\nimport org.kde.syntaxhighlighting\n")
        self.assertFails("barstyles", r"barstyles/gate-bar/qml/Scene.qml:2: QML module 'org.kde.syntaxhighlighting' is not a platform module")
        edit_toml(self.item, tail='\n[requires]\nqmlModules = ["org.kde.syntaxhighlighting"]\n')
        self.assertEqual(self.registry("barstyles")["barstyles"][0]["requiresQmlModules"], ["org.kde.syntaxhighlighting"])

    def test_removed_and_reserved_modules_fail(self) -> None:
        prepend(self.scene, "import shell.Ui\nimport qs.Commons\n")
        with self.assertRaises(CatalogueError) as caught:
            generate_category(self.root, "barstyles")
        self.assertIn("Scene.qml:1: QML module 'shell.Ui' is not a platform module", str(caught.exception))
        self.assertIn("Scene.qml:2: QML module 'qs.Commons' is reserved by Quickshell", str(caught.exception))

    def test_module_named_qs_fails(self) -> None:
        write(self.item / "qml/qs/qmldir", "module qs\n")
        path = self.item / "item.toml"
        path.write_text(path.read_text().replace("modules = []", 'modules = ["qs"]'))
        self.assertFails("barstyles", r"shell.modules\[0\]: 'qs' is reserved")

    def test_own_module_folders_pass(self) -> None:
        write(self.item / "qml/kit/qmldir", "module kit\n")
        write(self.item / "qml/kit/style/Palette.qml", "import QtQuick\nQtObject {}\n")
        path = self.item / "item.toml"
        path.write_text(path.read_text().replace("modules = []", 'modules = ["kit"]'))
        prepend(self.scene, "import kit\nimport kit.style\n")
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)
        prepend(self.scene, "import kit.missing\n")
        self.assertFails("barstyles", r"Scene.qml:1: QML module 'kit.missing' is not a platform module")

    def test_relative_imports_stay_inside_the_item(self) -> None:
        prepend(self.scene, 'import "../../other-bar/qml"\n')
        self.assertFails("barstyles", r"Scene.qml:1: relative import '../../other-bar/qml' leaves the item folder")

    def test_url_imports_fail(self) -> None:
        prepend(self.scene, 'import "file:///home/user/qml"\n')
        self.assertFails("barstyles", r"Scene.qml:1: relative import 'file:///home/user/qml' must be relative to the item")

    def test_js_includes_stay_inside_the_item(self) -> None:
        write(self.item / "qml/lib/util.js", '.pragma library\n.import "../../../shared.js" as Shared\n')
        self.assertFails("barstyles", r"qml/lib/util.js:2: .js include '../../../shared.js' leaves the item folder")

    def test_es_imports_stay_inside_the_item(self) -> None:
        write(self.item / "tests/logic.test.mjs", 'import test from "node:test";\nimport { x } from "../../../tools/x.mjs";\n')
        self.assertFails("barstyles", r"tests/logic.test.mjs:2: JavaScript import '../../../tools/x.mjs' leaves the item folder")

    def test_import_text_after_the_root_object_is_ignored(self) -> None:
        self.scene.write_text(self.scene.read_text() + 'property string code: "\nimport sys\n"\n')
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)

    def test_runtime_file_urls_are_allowed(self) -> None:
        self.scene.write_text(self.scene.read_text().replace('color: "#101010"', 'color: "#101010"\n        property url art: "file://" + "/tmp/a.png"', 1))
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)


class CollisionTests(TreeTest):
    def setUp(self) -> None:
        super().setUp()
        self.item = self.tree.add("barstyles", "clash-bar")
        write(self.item / "qml/widgets/Theme.qml", "import QtQuick\nItem {}\n")
        self.widget = write(self.item / "qml/widgets/Clock.qml", "import QtQuick\nimport shell.services\n\nText {\n    color: Theme.text\n}\n")

    def test_local_type_shadowing_an_export_fails(self) -> None:
        self.assertFails("barstyles", r"qml/widgets/Clock.qml:5: 'Theme' is both a local type and a shell.services export; import shell.services as Ryoku")

    def test_types_from_unqualified_directory_imports_count(self) -> None:
        self.widget.write_text("import QtQuick\nimport shell.services as Ryoku\n\nText {}\n")
        scene = self.item / "qml/Scene.qml"
        prepend(scene, 'import "widgets"\nimport shell.services\n')
        scene.write_text(scene.read_text().replace('color: "#101010"', "color: Theme.surface", 1))
        self.assertFails("barstyles", r"barstyles/clash-bar/qml/Scene.qml:\d+: 'Theme' is both a local type")

    def test_qualified_or_unused_names_pass(self) -> None:
        self.widget.write_text("import QtQuick\nimport shell.services as Ryoku\n\nText {\n    color: Ryoku.Theme.text\n}\n")
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)
        self.widget.write_text("import QtQuick\nimport shell.services\n\n// Theme lives in this folder\nText {\n    color: Config.accent\n}\n")
        self.assertEqual(len(self.registry("barstyles")["barstyles"]), 1)


class ProfileTests(TreeTest):
    def profile(self, item: Path) -> tuple[Path, dict]:
        path = item / "profile.json"
        return path, json.loads(path.read_text())

    def test_store_items_must_name_listed_catalogue_items(self) -> None:
        item = self.tree.add("profiles", "study-profile")
        path, profile = self.profile(item)
        profile["storeItems"] = [{"category": "barstyles", "id": "study-bar"}]
        path.write_text(json.dumps(profile))
        self.assertFails("profiles", r"storeItems\[0\]: storeItems names barstyles/study-bar, which is not an item")
        bar = self.tree.add("barstyles", "study-bar")
        self.assertEqual(json.loads(generate_category(self.root, "profiles")[item / "manifest.json"])["category"], "profiles")
        edit_toml(bar, top="listed = false")
        self.assertFails("profiles", r"which is not listed in the Store")

    def test_profile_environment_rules_apply(self) -> None:
        item = self.tree.add("profiles", "wide-profile")
        path, profile = self.profile(item)
        profile["env"] = [{"key": "LD_PRELOAD", "value": "x.so"}]
        path.write_text(json.dumps(profile))
        self.assertFails("profiles", r"profiles/wide-profile/profile.json:env\[0\].key: environment key LD_PRELOAD is forbidden")

    def test_profile_identity_and_rice_must_match(self) -> None:
        item = self.tree.add("profiles", "moved-profile")
        path, profile = self.profile(item)
        profile["version"] = "9.9.9"
        profile["rice"] = "missing"
        path.write_text(json.dumps(profile))
        with self.assertRaises(CatalogueError) as caught:
            generate_category(self.root, "profiles")
        self.assertIn("profile.json:version: must match item.toml", str(caught.exception))
        self.assertIn("home/.config/ryoku/rices/missing/rice.json does not exist", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
