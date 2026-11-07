import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ITEM = Path(__file__).resolve().parents[1]
RUNTIME = ITEM / "data" / "runtime"
BIN = ITEM / "bin"
ARCHIVE = os.environ.get("SHIMA_TEST_ARCHIVE")


class ShimaPinnedSourceTest(unittest.TestCase):
    def test_source_and_runtime_integrity(self):
        meta = json.loads((RUNTIME / "upstream.json").read_text())
        self.assertEqual(meta["version"], "2.33.0")
        self.assertEqual(meta["runtime_files"], 2409)
        self.assertEqual(len(meta["revision"]), 40)
        self.assertEqual(
            hashlib.sha256((RUNTIME / "runtime.patch").read_bytes()).hexdigest(),
            meta["patch_sha256"],
        )
        self.assertEqual(
            hashlib.sha256((RUNTIME / "shima-overview-terminal.patch").read_bytes()).hexdigest(),
            meta["overview_patch_sha256"],
        )

    def test_item_layout(self):
        self.assertTrue((ITEM / "qml/inir/ShellIrisPanels.qml").is_file())
        self.assertTrue((ITEM / "qml/Scene.qml").is_file())
        self.assertTrue((ITEM / "bin/runtime-wanted").is_file())
        self.assertTrue((ITEM / "bin/runtime-install").is_file())
        self.assertTrue((ITEM / "bin/runtime-start").is_file())

    def test_upstream_services_are_not_installed(self):
        files = (RUNTIME / "runtime-files.txt").read_text().splitlines()
        self.assertEqual(len(files), 2403)
        self.assertEqual(len(set(files)), 2403)
        self.assertFalse(any(name.endswith(".service") for name in files))

    def test_runtime_selection_gate(self):
        env = os.environ.copy()
        env.pop("RYOKU_SHIMA_UPSTREAM", None)
        env.pop("NIRI_SOCKET", None)
        wanted = str(BIN / "runtime-wanted")
        self.assertNotEqual(subprocess.run([wanted], env=env).returncode, 0)
        env["RYOKU_SHIMA_UPSTREAM"] = "1"
        env["NIRI_SOCKET"] = "/tmp/niri-test.sock"
        self.assertEqual(subprocess.run([wanted], env=env).returncode, 0)

    def test_required_integration_patches(self):
        patch = (RUNTIME / "runtime.patch").read_text()
        for expected in (
            "RyokuHost.qml",
            "RyokuTokens.qml",
            "RyokuVisualizerPalette.qml",
            "modules/pill/PillSettings.qml",
            "modules/overview/OverviewNiriWidget.qml",
            'id: ryokuLauncher; target: "launcher"',
        ):
            self.assertIn(expected, patch)

    @unittest.skipUnless(ARCHIVE, "Set SHIMA_TEST_ARCHIVE for source installation")
    def test_verified_offline_install(self):
        with tempfile.TemporaryDirectory(prefix="shima-pinned-test-") as directory:
            root = Path(directory)
            env = os.environ.copy()
            for key in (
                "HOME",
                "XDG_CONFIG_HOME",
                "XDG_DATA_HOME",
                "XDG_CACHE_HOME",
                "XDG_STATE_HOME",
            ):
                folder = root / key.lower()
                folder.mkdir()
                env[key] = str(folder)
            env["RYOKU_ITEM_DIR"] = str(ITEM)
            installer = str(BIN / "runtime-install")

            def run(*args):
                return subprocess.run(
                    [installer, *args],
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=90,
                )

            bad = root / "invalid.tar.gz"
            bad.write_bytes(b"invalid archive bytes")
            result = run("install", "--archive", str(bad))
            self.assertNotEqual(result.returncode, 0)
            current = root / "xdg_data_home/ryoku/shima/current"
            self.assertFalse(current.exists())
            result = run("install", "--archive", ARCHIVE)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(run("verify").returncode, 0)
            self.assertTrue((current / "shell.qml").is_file())
            self.assertTrue((current / "ShellWafflePanels.qml").is_file())
            self.assertTrue((current / "ShimaOverviewBackdrop.qml").is_file())
            self.assertIn(
                "overview_patch_sha256",
                json.loads((current / "runtime.json").read_text()),
            )
            self.assertIn(
                "ryoku-overview-backdrop",
                (current / "ShimaOverviewBackdrop.qml").read_text(),
            )
            self.assertIn(
                "property bool enableTerminal: false",
                (current / "modules/common/Config.qml").read_text(),
            )
            launcher = subprocess.run(
                [str(BIN / "runtime-start"), "--version"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(launcher.returncode, 0, launcher.stderr)
            self.assertIn("2.33.0", launcher.stdout)
            self.assertNotEqual(
                subprocess.run(
                    [str(BIN / "runtime-start")],
                    env=env,
                    capture_output=True,
                ).returncode,
                0,
            )
            env["https_proxy"] = "http://127.0.0.1:1"
            self.assertEqual(run().returncode, 0)
            self.assertEqual(run("verify").returncode, 0)


if __name__ == "__main__":
    unittest.main()
