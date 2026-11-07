from __future__ import annotations

import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS = REPO_ROOT / "tools"
sys.path.insert(0, str(TOOLS))


def load_tool(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


new_tool = load_tool("ryostore_new", "new.py")
test_tool = load_tool("ryostore_test", "test.py")

from ryostore_tools.catalogue import build
from measurement_fixture import write_measurement


class CommandTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(REPO_ROOT / "templates", self.root / "templates")
        shutil.copytree(REPO_ROOT / "schema", self.root / "schema")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_scaffold_fills_item_and_profile_identity(self) -> None:
        destination = new_tool.scaffold(self.root, "profile", "new-profile")
        item = (destination / "item.toml").read_text(encoding="utf-8")
        profile = (destination / "profile.json").read_text(encoding="utf-8")
        self.assertIn('id = "new-profile"', item)
        self.assertIn('name = "New Profile"', item)
        self.assertIn('"id": "new-profile"', profile)
        self.assertIn('"name": "New Profile"', profile)

    def test_scaffolded_items_pass_build(self) -> None:
        for category in ("subshell", "barstyle", "profile"):
            new_tool.scaffold(self.root, category, f"fresh-{category}")
        build(self.root, [], check=False)
        for item_id in ("fresh-subshell", "fresh-barstyle"):
            write_measurement(self.root, item_id, "0.1.0")
        build(self.root, [], check=False)
        self.assertEqual(build(self.root, [], check=True), [])

    def test_scaffold_refuses_existing_item(self) -> None:
        new_tool.scaffold(self.root, "barstyles", "twice")
        with self.assertRaisesRegex(ValueError, "already exists"):
            new_tool.scaffold(self.root, "barstyles", "twice")

    def test_runner_selects_supported_test_commands(self) -> None:
        item = self.root / "barstyles/sample/tests"
        item.mkdir(parents=True)
        (item.parent / "item.toml").write_text('id = "sample"\n', encoding="utf-8")
        (item / "logic.test.mjs").write_text("", encoding="utf-8")
        (item / "test_state.py").write_text("", encoding="utf-8")
        (item / "smoke.sh").write_text("", encoding="utf-8")
        commands = test_tool.commands_for(item.parent)
        self.assertEqual([command.argv[0] for command in commands], ["node", "python3", "bash"])

    @mock.patch.object(test_tool.subprocess, "run")
    def test_runner_reports_item_failure(self, run: mock.Mock) -> None:
        item = self.root / "barstyles/sample/tests"
        item.mkdir(parents=True)
        (item.parent / "item.toml").write_text('id = "sample"\n', encoding="utf-8")
        (item / "smoke.sh").write_text("", encoding="utf-8")
        run.return_value.returncode = 2
        self.assertEqual(test_tool.run(self.root, ["barstyles/sample"]), 1)


if __name__ == "__main__":
    unittest.main()
