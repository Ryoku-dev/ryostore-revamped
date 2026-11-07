from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))

from ryostore_tools.behaviour import _mask_c_like, _strip_hash_comments, compositor_findings, timer_process_findings
from ryostore_tools.catalogue import CatalogueError, build, generate_category
from measurement_fixture import write_measurement


def qml(text: str) -> list[tuple[str, str, str, str]]:
    code, masked = _mask_c_like(text)
    return [("qml/Thing.qml", "qml", code, masked)]


def script(text: str, name: str = "bin/start") -> list[tuple[str, str, str, str]]:
    return [(name, "script", _strip_hash_comments(text), _strip_hash_comments(text))]


def keys(findings) -> list[tuple[str, str]]:
    return [(finding.check, finding.key) for finding in findings]


class LexerTests(unittest.TestCase):
    def test_comments_go_strings_stay_and_offsets_hold(self) -> None:
        text = 'a: "x // y" // hyprctl\n/* niri msg\n */ b: /"/.test(s)\n'
        code, masked = _mask_c_like(text)
        self.assertEqual(len(code), len(text))
        self.assertEqual(code.count("\n"), text.count("\n"))
        self.assertIn('"x // y"', code)
        self.assertNotIn("hyprctl", code)
        self.assertNotIn("niri", code)
        self.assertNotIn("x // y", masked)
        self.assertIn("b: /", masked)


class CompositorTests(unittest.TestCase):
    def test_direct_calls_by_family(self) -> None:
        self.assertEqual(keys(compositor_findings(qml('Process { command: ["hyprctl", "-j", "clients"] }'))), [("compositor", "hyprland")])
        self.assertEqual(keys(compositor_findings(qml("import QtQuick\nimport Quickshell.Hyprland\nItem {}\n"))), [("compositor", "hyprland")])
        self.assertEqual(keys(compositor_findings(qml('Process { command: ["niri", "msg", "-j", "outputs"] }'))), [("compositor", "niri")])
        self.assertEqual(keys(compositor_findings(script("#!/bin/sh\nwf-msg list\n"))), [("compositor", "wayfire")])
        self.assertEqual(keys(compositor_findings(script("#!/bin/sh\nswaymsg -t get_tree\n"))), [("compositor", "sway")])

    def test_one_finding_per_family_and_file(self) -> None:
        found = compositor_findings(qml('X { a: ["hyprctl"]; b: ["hyprctl"]; c: ["niri", "msg"] }'))
        self.assertEqual(sorted(keys(found)), [("compositor", "hyprland"), ("compositor", "niri")])

    def test_comments_and_words_are_not_calls(self) -> None:
        self.assertEqual(compositor_findings(qml("// hyprctl dispatch\n/* niri msg */\nText { text: \"niri\" }\n")), [])
        self.assertEqual(compositor_findings(script("#!/bin/sh\n# hyprctl reload\necho done\n")), [])
        self.assertEqual(compositor_findings(qml("Item { readonly property string hint: \"Hyprland or niri\" }\n")), [])


class TimerTests(unittest.TestCase):
    def timers(self, body: str) -> list[str]:
        return [finding.detail for finding in timer_process_findings(qml(f"Item {{\n{body}\n}}\n")) if finding.check == "timer"]

    def test_running_true_repeat_is_flagged(self) -> None:
        self.assertEqual(len(self.timers("Timer { interval: 60000; repeat: true; running: true }")), 1)

    def test_one_shot_and_stopped_timers_pass(self) -> None:
        self.assertEqual(self.timers("Timer { interval: 50; running: true }"), [])
        self.assertEqual(self.timers("Timer { id: t; interval: 50; repeat: true }"), [])
        self.assertEqual(self.timers("Timer { interval: 50; repeat: true; running: false }"), [])

    def test_short_interval_needs_an_activity_gate(self) -> None:
        self.assertEqual(len(self.timers("Timer { interval: 250; repeat: true; running: root.ready }")), 1)
        self.assertEqual(self.timers("Timer { interval: 250; repeat: true; running: root.visible && root.ready }"), [])
        self.assertEqual(self.timers("Timer { interval: 250; repeat: true; running: popup.opened }"), [])
        self.assertEqual(self.timers("Timer { interval: 5 * 60 * 1000; repeat: true; running: root.ready }"), [])
        self.assertEqual(self.timers("Timer { interval: Config.minutes * 60000; repeat: true; running: root.ready }"), [])

    def test_default_and_ternary_intervals(self) -> None:
        self.assertEqual(len(self.timers("Timer { repeat: true; running: root.ready }")), 1)
        self.assertEqual(len(self.timers("Timer { interval: fast ? (hot ? 16 : 200) : 5000; repeat: true; running: root.ready }")), 1)

    def test_running_continued_on_next_line(self) -> None:
        body = "Timer {\n    interval: 100\n    repeat: true\n    running: root.ready\n        && root.panelVisible\n}"
        self.assertEqual(self.timers(body), [])

    def test_nested_object_properties_are_not_the_timers(self) -> None:
        body = "Timer {\n    interval: 100\n    repeat: true\n    running: root.visible\n    property Item probe: Item { running: true }\n}"
        self.assertEqual(self.timers(body), [])

    def test_keys_use_the_id_or_ordinal(self) -> None:
        found = timer_process_findings(qml("Item {\nTimer { repeat: true; running: true }\nTimer { id: tick; repeat: true; running: true }\n}\n"))
        self.assertEqual([(f.key, f.line) for f in found], [("Timer@1", 2), ("tick", 3)])


class ProcessTests(unittest.TestCase):
    def processes(self, body: str) -> list[str]:
        return [finding.key for finding in timer_process_findings(qml(f"Item {{\n{body}\n}}\n")) if finding.check == "process"]

    def test_exit_handler_restart_is_flagged(self) -> None:
        self.assertEqual(self.processes("Process { id: watch; running: true; onExited: running = true }"), ["watch"])
        self.assertEqual(self.processes("Process { id: watch; onExited: (code) => { if (code !== 0) watch.running = true } }"), ["watch"])

    def test_restart_through_a_timer_is_flagged(self) -> None:
        body = "Process { id: watch; onExited: again.restart() }\nTimer { id: again; interval: 2000; onTriggered: watch.running = true }"
        self.assertEqual(self.processes(body), ["watch"])

    def test_queued_work_and_wanted_guards_pass(self) -> None:
        self.assertEqual(self.processes("Process { id: saver; onExited: { if (saver.pending !== null) saver.exec([\"true\"]) } }"), [])
        body = "Process { id: cava; onExited: if (root.wanted) again.restart() }\nTimer { id: again; interval: 1500; onTriggered: cava.running = true }"
        self.assertEqual(self.processes(body), [])
        body = "Process { id: watch; onExited: { if (++root.exits <= 5) again.restart() } }\nTimer { id: again; interval: 2000; onTriggered: watch.running = true }"
        self.assertEqual(self.processes(body), [])


class GateTests(unittest.TestCase):
    """The checks inside `tools/build.py`: declaring the compositor or a reviewed allowlist entry."""

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(REPO_ROOT / "schema", self.root / "schema")
        for category in ("subshells", "profiles"):
            (self.root / category).mkdir()
        self.item = self.root / "barstyles/hypr-bar"
        shutil.copytree(REPO_ROOT / "templates/barstyle", self.item)
        self.toml = self.item / "item.toml"
        self.toml.write_text(self.toml.read_text().replace('id = "example-barstyle"', 'id = "hypr-bar"'))
        self.scene = self.item / "qml/Scene.qml"
        self.scene.write_text(self.scene.read_text().replace(
            'color: "transparent"', 'color: "transparent"\n    Process { id: probe; command: ["hyprctl", "-j", "monitors"] }', 1))
        write_measurement(self.root, "hypr-bar", "0.1.0")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def allow(self, *entries: dict) -> None:
        path = self.root / "tools/behaviour-allowlist.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps({"schema": 1, "entries": list(entries)}), encoding="utf-8")

    def entry(self, **fields: str) -> dict:
        return {"item": "barstyles/hypr-bar", "check": "compositor", "file": "qml/Scene.qml", "key": "hyprland", "reason": "Gated on the provider."} | fields

    def test_undeclared_compositor_call_fails_with_the_fix(self) -> None:
        with self.assertRaisesRegex(CatalogueError, r"barstyles/hypr-bar/qml/Scene.qml:\d+: calls hyprland directly \(hyprctl\); declare requires.windowManager = \"hyprland\""):
            generate_category(self.root, "barstyles")

    def test_declared_window_manager_passes_and_reaches_the_registry(self) -> None:
        self.toml.write_text(self.toml.read_text().replace("\n[shell]", '\n[requires]\nwindowManager = "hyprland"\n\n[shell]', 1))
        row = json.loads(generate_category(self.root, "barstyles")[self.root / "barstyles/registry.json"])["barstyles"][0]
        self.assertEqual(row["windowManager"], "hyprland")

    def test_declaring_another_window_manager_still_fails(self) -> None:
        self.toml.write_text(self.toml.read_text().replace("\n[shell]", '\n[requires]\nwindowManager = "niri"\n\n[shell]', 1))
        with self.assertRaisesRegex(CatalogueError, "calls hyprland directly"):
            generate_category(self.root, "barstyles")

    def test_allowlist_entry_passes_and_stale_entries_fail(self) -> None:
        self.allow(self.entry())
        build(self.root, [], check=False)
        self.assertEqual(build(self.root, [], check=True), [])
        self.allow(self.entry(), self.entry(check="timer", key="Timer@1", reason="Clock."))
        with self.assertRaisesRegex(CatalogueError, "entry barstyles/hypr-bar timer qml/Scene.qml Timer@1 matches nothing; remove it"):
            generate_category(self.root, "barstyles")
        self.allow(self.entry(), self.entry(item="barstyles/gone"))
        with self.assertRaisesRegex(CatalogueError, "names 'barstyles/gone', which is not a subshell or bar style"):
            build(self.root, [], check=False)

    def test_allowlist_entries_need_a_reason(self) -> None:
        self.allow(self.entry(reason=" "))
        with self.assertRaisesRegex(CatalogueError, r"entries\[0\]: every field is a non-empty string"):
            generate_category(self.root, "barstyles")

    def test_ungated_timer_fails_until_gated(self) -> None:
        self.allow(self.entry())
        self.scene.write_text(self.scene.read_text().replace(
            'color: "transparent"', 'color: "transparent"\n    Timer { interval: 100; repeat: true; running: true }', 1))
        with self.assertRaisesRegex(CatalogueError, r"repeating Timer with running: true; gate it on visibility or activity"):
            generate_category(self.root, "barstyles")
        self.scene.write_text(self.scene.read_text().replace("running: true }", "running: parent.visible }", 1))
        generate_category(self.root, "barstyles")


if __name__ == "__main__":
    unittest.main()
