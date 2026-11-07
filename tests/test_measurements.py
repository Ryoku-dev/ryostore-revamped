from __future__ import annotations

from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS = REPO_ROOT / "tools"
sys.path.insert(0, str(TOOLS))

from ryostore_tools import measurements
from ryostore_tools.catalogue import CatalogueError, build, generate_category
from ryostore_tools.measurements import MeasurementError, tier_for
from measurement_fixture import BASELINE, MACHINE, sample, write_measurement


def load_measure():
    spec = importlib.util.spec_from_file_location("ryostore_measure", TOOLS / "measure.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules["ryostore_measure"] = module
    spec.loader.exec_module(module)
    return module


measure = load_measure()


def delta(pss: float = 0, cpu: float = 0, launches: float = 0) -> dict[str, float]:
    return {"pssMB": pss, "gpuMB": 0.0, "cpuPct": cpu, "wakeupsPerSec": 0.0, "launchesPerMin": launches}


class TierRuleTests(unittest.TestCase):
    def test_light_needs_every_limit(self) -> None:
        self.assertEqual(tier_for(delta()), "light")
        self.assertEqual(tier_for(delta(pss=30, cpu=0.1, launches=0)), "light")
        self.assertEqual(tier_for(delta(pss=-12, cpu=-0.05)), "light")
        self.assertEqual(tier_for(delta(pss=30.1)), "standard")
        self.assertEqual(tier_for(delta(cpu=0.11)), "standard")
        self.assertEqual(tier_for(delta(launches=0.1)), "standard")

    def test_standard_limits(self) -> None:
        self.assertEqual(tier_for(delta(pss=80, cpu=0.5, launches=10)), "standard")
        self.assertEqual(tier_for(delta(pss=80.1)), "heavy")
        self.assertEqual(tier_for(delta(cpu=0.51)), "heavy")
        self.assertEqual(tier_for(delta(launches=10.1)), "heavy")

    def test_gpu_and_wakeups_do_not_move_the_tier(self) -> None:
        heavy_gpu = delta() | {"gpuMB": 500.0, "wakeupsPerSec": 40.0}
        self.assertEqual(tier_for(heavy_gpu), "light")


class RecordTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_record_from_fixture_samples(self) -> None:
        path = write_measurement(self.root, "thin-bar", "1.2.0", pssMB=45.25, gpuMB=12.0, cpuPct=0.2, wakeupsPerSec=3.04, launchesPerMin=2)
        self.assertEqual(path, self.root / "measurements/thin-bar.json")
        value = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(value["id"], "thin-bar")
        self.assertEqual(value["version"], "1.2.0")
        self.assertEqual(value["baseline"], "orpheus")
        self.assertEqual(value["delta"], {"pssMB": 45.2, "gpuMB": 12.0, "cpuPct": 0.2, "wakeupsPerSec": 3.0, "launchesPerMin": 2.0})
        self.assertEqual(value["tier"], "standard")
        self.assertEqual(value["machine"], MACHINE)
        self.assertEqual(value["absolute"]["baseline"], BASELINE)
        self.assertEqual(value["leftoverProcesses"], [])
        self.assertTrue(path.read_text(encoding="utf-8").endswith("}\n"))
        self.assertEqual(measurements.load(self.root, "thin-bar"), value)

    def test_negative_zero_is_written_as_zero(self) -> None:
        value = measurements.record(
            item_id="same", version="1.0.0", measured_at=datetime(2026, 1, 1, tzinfo=timezone.utc), ryoku="x",
            machine=MACHINE, item=dict(BASELINE), baseline=dict(BASELINE), leftovers=[], window={},
        )
        self.assertEqual(json.dumps(value["delta"]["cpuPct"]), "0.0")

    def test_hand_edited_tier_is_rejected(self) -> None:
        path = write_measurement(self.root, "edited", "1.0.0", pssMB=200)
        value = json.loads(path.read_text(encoding="utf-8"))
        value["tier"] = "light"
        path.write_text(json.dumps(value), encoding="utf-8")
        with self.assertRaisesRegex(MeasurementError, "tier: the delta makes it 'heavy'"):
            measurements.load(self.root, "edited")

    def test_record_shape_is_validated(self) -> None:
        path = write_measurement(self.root, "shape", "1.0.0")
        value = json.loads(path.read_text(encoding="utf-8"))
        for broken, pattern in (
            ({**value, "extra": 1}, "extra: unknown field"),
            ({**value, "delta": {"pssMB": 1}}, "delta: expected exactly"),
            ({**value, "baseline": "kairos"}, "baseline: expected 'orpheus'"),
            ({**value, "version": "one"}, "version: expected"),
            ({**value, "id": "other"}, "id: must equal the file name"),
        ):
            path.write_text(json.dumps(broken), encoding="utf-8")
            with self.assertRaisesRegex(MeasurementError, pattern):
                measurements.load(self.root, "shape")

    def test_problems_for_missing_stale_newer_and_leftovers(self) -> None:
        self.assertEqual(measurements.problems("barstyles/x", "1.0.0", None, required=False), [])
        self.assertRegex(measurements.problems("barstyles/x", "1.0.0", None, required=True)[0], "missing measurement for barstyles/x")
        record = json.loads(write_measurement(self.root, "x", "1.0.0").read_text())
        self.assertEqual(measurements.problems("barstyles/x", "1.0.0", record, required=True), [])
        self.assertRegex(measurements.problems("barstyles/x", "1.0.1", record, required=True)[0], "older than its version 1.0.1")
        self.assertRegex(measurements.problems("barstyles/x", "0.9.0", record, required=True)[0], "newer than its version 0.9.0")
        self.assertRegex(measurements.problems("barstyles/x", "1.0.0-rc.1", record, required=True)[0], "newer than")
        leaked = json.loads(write_measurement(self.root, "x", "1.0.0", leftovers=["bluetoothctl show"]).read_text())
        self.assertRegex(measurements.problems("barstyles/x", "1.0.0", leaked, required=True)[0], "left processes running.*bluetoothctl show")


class MeasureSampleTests(unittest.TestCase):
    def test_summarize_counts_processes_alive_for_the_whole_window(self) -> None:
        shell, helper, transient = (100, 5), (200, 9), (300, 50)
        start = measure.Snapshot(
            ticks={shell: 1000, helper: 10}, switches={shell: 5000, helper: 100},
            pss_kb={shell: 300000, helper: 2048}, gpu_kb={"7": 200000},
        )
        end = measure.Snapshot(
            ticks={shell: 1006, helper: 10, transient: 3}, switches={shell: 5600, helper: 160, transient: 9},
            pss_kb={shell: 301000, helper: 2048, transient: 4096}, gpu_kb={"7": 204800, "8": 1024},
        )
        metrics = measure.summarize(start, end, elapsed=60.0, launches=3, unseen=1)
        self.assertEqual(metrics["pssMB"], round((301000 + 2048) / 1024, 1))
        self.assertEqual(metrics["gpuMB"], round((204800 + 1024) / 1024, 1))
        self.assertAlmostEqual(metrics["cpuPct"], round(6 / measure.HZ / 60 * 100, 3))
        self.assertEqual(metrics["wakeupsPerSec"], 11.0)
        self.assertEqual(metrics["launchesPerMin"], 3.0)
        self.assertEqual(metrics["processes"], 2)
        self.assertEqual(metrics["unseenPidsPerMin"], 1.0)

    def test_record_written_from_summarized_samples(self) -> None:
        def shot(pss_kb: int, ticks: int, switches: int) -> measure.Snapshot:
            return measure.Snapshot(ticks={(1, 1): ticks}, switches={(1, 1): switches}, pss_kb={(1, 1): pss_kb}, gpu_kb={"1": 240 * 1024})

        baseline = measure.summarize(shot(292 * 1024, 0, 0), shot(292 * 1024, 6, 498), 60.0, 0, 0)
        item = measure.summarize(shot(350 * 1024, 0, 0), shot(350 * 1024, 24, 900), 60.0, 12, 0)
        with tempfile.TemporaryDirectory() as temp:
            value = measurements.record(
                item_id="poll-bar", version="2.0.0", measured_at=datetime(2026, 11, 7, tzinfo=timezone.utc), ryoku="v2.0.0",
                machine=MACHINE, item=item, baseline=baseline, leftovers=["sh -c sleep 600"], window={"sampleSeconds": 60},
            )
            path = measurements.write_record(Path(temp), value)
            written = json.loads(path.read_text())
        self.assertEqual(written["delta"]["pssMB"], 58.0)
        self.assertEqual(written["delta"]["launchesPerMin"], 12.0)
        self.assertEqual(written["tier"], "heavy")
        self.assertEqual(written["leftoverProcesses"], ["sh -c sleep 600"])

    def test_leftovers_need_the_same_start_time(self) -> None:
        alive = {10: measure.Stat(10, 1, 0, 500), 11: measure.Stat(11, 1, 0, 999)}
        owned = {(10, 500), (11, 600), (12, 700)}
        self.assertEqual(measure.leftovers(owned, alive, lambda pid: f"cmd {pid}"), ["cmd 10"])

    def test_launch_counter_walks_new_pids_across_wrap(self) -> None:
        counter = measure.LaunchCounter.__new__(measure.LaunchCounter)
        counter.pid_max = 100
        counter.last = 97
        self.assertEqual(counter._new_pids(99), [98, 99])
        self.assertEqual(counter._new_pids(2), [98, 99, 100, 1, 2])

    def test_shell_and_daemon_command_lines(self) -> None:
        self.assertTrue(measure.is_shell(["qs", "-c", "shell"]))
        self.assertTrue(measure.is_shell(["/usr/bin/qs", "-c", "shell", "-n"]))
        self.assertFalse(measure.is_shell(["qs", "-c", "hub"]))
        self.assertTrue(measure.is_daemon(["/usr/bin/ryoku-shell", "daemon"]))
        self.assertFalse(measure.is_daemon(["ryoku-shell", "barstyle", "x"]))

    def test_active_and_in_use(self) -> None:
        index = {"active": "sumi", "items": [{"id": "sumi", "inUse": True}, {"id": "obi", "inUse": False}]}
        self.assertTrue(measure.active_and_in_use(index, "sumi"))
        self.assertFalse(measure.active_and_in_use(index, "obi"))
        self.assertFalse(measure.active_and_in_use({"active": "sumi", "items": []}, "sumi"))


class RegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(REPO_ROOT / "schema", self.root / "schema")
        for category in ("subshells", "profiles"):
            (self.root / category).mkdir()
        self.item = self.root / "barstyles/thin-bar"
        shutil.copytree(REPO_ROOT / "templates/barstyle", self.item)
        toml = self.item / "item.toml"
        toml.write_text(toml.read_text().replace('id = "example-barstyle"', 'id = "thin-bar"'))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def row(self) -> dict:
        notes: list[str] = []
        registry = generate_category(self.root, "barstyles", notes)[self.root / "barstyles/registry.json"]
        self.notes = notes
        return json.loads(registry)["barstyles"][0]

    def test_current_measurement_becomes_registry_metadata(self) -> None:
        write_measurement(self.root, "thin-bar", "0.1.0", pssMB=12, cpuPct=0.05)
        row = self.row()
        self.assertEqual(row["metadata"], {
            "resourceTier": "light",
            "resourceDelta": {"pssMB": 12.0, "gpuMB": 0.0, "cpuPct": 0.05, "wakeupsPerSec": 0.0, "launchesPerMin": 0.0},
        })
        self.assertEqual(self.notes, [])
        build(self.root, [], check=False)
        self.assertEqual(build(self.root, [], check=True), [])

    def test_missing_or_stale_measurement_fails_check_only(self) -> None:
        self.assertNotIn("metadata", self.row())
        self.assertRegex(self.notes[0], "missing measurement for barstyles/thin-bar")
        notes: list[str] = []
        build(self.root, [], check=False, notes=notes)
        self.assertEqual(len(notes), 1)
        with self.assertRaisesRegex(CatalogueError, "missing measurement"):
            build(self.root, [], check=True)
        write_measurement(self.root, "thin-bar", "0.0.9")
        self.assertNotIn("metadata", self.row())
        build(self.root, [], check=False)
        with self.assertRaisesRegex(CatalogueError, "older than its version 0.1.0"):
            build(self.root, [], check=True)

    def test_unlisted_and_paused_items_need_no_measurement(self) -> None:
        toml = self.item / "item.toml"
        original = toml.read_text()
        toml.write_text(original.replace("\npreview =", "\nlisted = false\npreview =", 1))
        build(self.root, [], check=False)
        self.assertEqual(build(self.root, [], check=True), [])
        toml.write_text(original.replace("\npreview =", '\ndownloadPaused = true\ndownloadPauseReason = "Later."\npreview =', 1))
        build(self.root, [], check=False)
        self.assertEqual(build(self.root, [], check=True), [])

    def test_orphan_and_leaking_records_fail(self) -> None:
        write_measurement(self.root, "thin-bar", "0.1.0")
        write_measurement(self.root, "gone-bar", "1.0.0")
        with self.assertRaisesRegex(CatalogueError, "measurements/gone-bar.json: no subshell or bar style 'gone-bar'"):
            build(self.root, [], check=False)
        (self.root / "measurements/gone-bar.json").unlink()
        write_measurement(self.root, "thin-bar", "0.1.0", leftovers=["bluetoothctl show"])
        build(self.root, [], check=False)
        with self.assertRaisesRegex(CatalogueError, "left processes running after it was switched away from: bluetoothctl show"):
            build(self.root, [], check=True)


if __name__ == "__main__":
    unittest.main()
