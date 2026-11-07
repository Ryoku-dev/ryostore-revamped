#!/usr/bin/env python3
"""Measure what each installed subshell and bar style costs over Orpheus and write its record.

Run it inside a Ryoku desktop (a lab container, never a desktop someone is using) as the desktop
user. For Orpheus first, then every installed catalogue item, it selects the item with
`ryoku-shell barstyle <id>`, waits until shells.json reports it active and in use, lets it settle,
then samples the shell for a window:

- PSS from smaps_rollup and GPU memory (VRAM + GTT, by DRM client) from the fdinfo of the `qs -c
  shell` process and its helper processes that live through the window;
- CPU from utime + stime and wakeups from the context switches of every thread, same processes;
- launches: processes that appear under the shell or the daemon during the window.

After switching to the next item it waits `--linger` seconds and records every process the
previous item started (a descendant of its shell, or an orphan left in the shell's cgroup) that is
still running. Each item's record goes to `measurements/<id>.json` with its delta over Orpheus and
the tier from `ryostore_tools.measurements.tier_for`. The selection in use before the run is
restored at the end.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from typing import Any, Callable, Iterable

from ryostore_tools import measurements


REPO_ROOT = Path(__file__).resolve().parent.parent
HZ = os.sysconf("SC_CLK_TCK")
PROC = Path("/proc")


# --- /proc readers --------------------------------------------------------------------------------

def _read(path: Path | str) -> str:
    try:
        with open(path, errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


@dataclass(frozen=True)
class Stat:
    pid: int
    ppid: int
    ticks: int  # utime + stime
    start: int  # clock ticks after boot


def stat(pid: int) -> Stat | None:
    text = _read(PROC / str(pid) / "stat")
    if not text or ")" not in text:
        return None
    rest = text[text.rindex(")") + 2:].split()
    try:
        return Stat(pid, int(rest[1]), int(rest[11]) + int(rest[12]), int(rest[19]))
    except (IndexError, ValueError):
        return None


def argv(pid: int) -> list[str]:
    return [part for part in _read(PROC / str(pid) / "cmdline").split("\0") if part]


def is_thread(pid: int) -> bool:
    for line in _read(PROC / str(pid) / "status").splitlines():
        if line.startswith("Tgid:"):
            return line.split()[1] != str(pid)
    return False


def user_processes(uid: int) -> dict[int, Stat]:
    table: dict[int, Stat] = {}
    for name in os.listdir(PROC):
        if not name.isdigit():
            continue
        try:
            if os.stat(PROC / name).st_uid != uid:
                continue
        except OSError:
            continue
        entry = stat(int(name))
        if entry is not None:
            table[entry.pid] = entry
    return table


def context_switches(pid: int) -> int:
    total = 0
    try:
        tasks = os.listdir(PROC / str(pid) / "task")
    except OSError:
        return 0
    for tid in tasks:
        for line in _read(PROC / str(pid) / "task" / tid / "status").splitlines():
            if line.startswith(("voluntary_ctxt_switches", "nonvoluntary_ctxt_switches")):
                total += int(line.split()[1])
    return total


def pss_kb(pid: int) -> int:
    for line in _read(PROC / str(pid) / "smaps_rollup").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "Pss:" and parts[1].isdigit():
            return int(parts[1])
    return 0


def drm_clients(pid: int) -> dict[str, int]:
    """DRM client id -> VRAM + GTT KiB, from the process's fdinfo (one client may hold several fds)."""
    clients: dict[str, int] = {}
    try:
        fds = os.listdir(PROC / str(pid) / "fdinfo")
    except OSError:
        return clients
    for fd in fds:
        text = _read(PROC / str(pid) / "fdinfo" / fd)
        if "drm-client-id" not in text:
            continue
        fields = dict(
            (key.strip(), value.strip())
            for key, _, value in (line.partition(":") for line in text.splitlines())
        )

        def kib(key: str) -> int:
            parts = fields.get(key, "0 KiB").split()
            if not parts or not parts[0].isdigit():
                return 0
            scale = {"KiB": 1, "MiB": 1024, "GiB": 1024 * 1024}.get(parts[1] if len(parts) > 1 else "KiB", 1)
            return int(parts[0]) * scale

        clients[fields["drm-client-id"]] = kib("drm-memory-vram") + kib("drm-memory-gtt")
    return clients


def cgroup(pid: int) -> str:
    for line in _read(PROC / str(pid) / "cgroup").splitlines():
        if line.startswith("0::"):
            return line[3:]
    return ""


def boot_ticks() -> int:
    return int(time.clock_gettime(time.CLOCK_BOOTTIME) * HZ)


def is_shell(args: list[str]) -> bool:
    if not args or os.path.basename(args[0]) != "qs":
        return False
    return any(args[index] == "-c" and args[index + 1] == "shell" for index in range(len(args) - 1))


def is_daemon(args: list[str]) -> bool:
    return len(args) >= 2 and os.path.basename(args[0]) == "ryoku-shell" and args[1] == "daemon"


def find(table: dict[int, Stat], predicate: Callable[[list[str]], bool], since: int = -1) -> Stat | None:
    found = [entry for entry in table.values() if entry.start >= since and predicate(argv(entry.pid))]
    return max(found, key=lambda entry: entry.start) if found else None


def descendants(table: dict[int, Stat], root: int) -> set[int]:
    children: dict[int, list[int]] = {}
    for entry in table.values():
        children.setdefault(entry.ppid, []).append(entry.pid)
    found: set[int] = set()
    stack = [root]
    while stack:
        for child in children.get(stack.pop(), []):
            if child not in found:
                found.add(child)
                stack.append(child)
    return found


# --- sampling -------------------------------------------------------------------------------------

@dataclass
class Snapshot:
    """Per-process counters for the shell and its helpers at one instant."""
    ticks: dict[tuple[int, int], int] = field(default_factory=dict)  # (pid, start) -> utime + stime
    switches: dict[tuple[int, int], int] = field(default_factory=dict)
    pss_kb: dict[tuple[int, int], int] = field(default_factory=dict)
    gpu_kb: dict[str, int] = field(default_factory=dict)  # DRM client id -> KiB


def snapshot(processes: Iterable[Stat]) -> Snapshot:
    shot = Snapshot()
    for entry in processes:
        key = (entry.pid, entry.start)
        shot.ticks[key] = entry.ticks
        shot.switches[key] = context_switches(entry.pid)
        shot.pss_kb[key] = pss_kb(entry.pid)
        shot.gpu_kb.update(drm_clients(entry.pid))
    return shot


def summarize(start: Snapshot, end: Snapshot, elapsed: float, launches: int, unseen: int) -> dict[str, float]:
    """Metrics for the processes alive at both ends of the window (helpers that came and went are launches)."""
    stable = sorted(set(start.ticks) & set(end.ticks))
    ticks = sum(end.ticks[key] - start.ticks[key] for key in stable)
    switches = sum(end.switches[key] - start.switches[key] for key in stable)
    return {
        "pssMB": round(sum(end.pss_kb[key] for key in stable) / 1024, 1),
        "gpuMB": round(sum(end.gpu_kb.values()) / 1024, 1),
        "cpuPct": round(ticks / HZ / elapsed * 100, 3),
        "wakeupsPerSec": round(switches / elapsed, 1),
        "launchesPerMin": round(launches * 60 / elapsed, 1),
        "processes": len(stable),
        "unseenPidsPerMin": round(unseen * 60 / elapsed, 1),
    }


def child_faults(pid: int) -> int:
    """cminflt: minor faults of the process's reaped children; it grows whenever it reaps one that ran."""
    text = _read(PROC / str(pid) / "stat")
    if not text or ")" not in text:
        return -1
    try:
        return int(text[text.rindex(")") + 2:].split()[8])
    except (IndexError, ValueError):
        return -1


class LaunchCounter:
    """Counts processes that appear under the shell or the daemon.

    It watches the PID namespace's last allocated PID and looks at each new PID once. A PID that is
    already gone when it is looked at counts as a launch when a root reaped a child in the same poll
    (its children's minor-fault counter grew; a pipeline's processes are reaped by its `sh`, which a
    root reaps in turn), and as `unseen` otherwise."""

    LAST_PID = PROC / "sys" / "kernel" / "ns_last_pid"

    def __init__(self, roots: set[int]) -> None:
        self.roots = roots
        self.launches = 0
        self.unseen = 0
        self.seen: set[tuple[int, int]] = set()
        self.pid_max = int(_read(PROC / "sys" / "kernel" / "pid_max") or "4194304")
        self.last = self._last_pid()
        self.faults = {root: child_faults(root) for root in roots}

    def _last_pid(self) -> int:
        value = _read(self.LAST_PID).strip()
        return int(value) if value.isdigit() else -1

    def _under_roots(self, entry: Stat) -> bool:
        current: Stat | None = entry
        hops = 0
        while current is not None and hops < 64:
            if current.ppid in self.roots:
                return True
            if current.ppid <= 1:
                return False
            current = stat(current.ppid)
            hops += 1
        return False

    def _new_pids(self, last: int) -> list[int]:
        if last >= self.last:
            return list(range(self.last + 1, last + 1))
        return list(range(self.last + 1, self.pid_max + 1)) + list(range(1, last + 1))

    def _reaped(self) -> bool:
        grew = False
        for root in self.roots:
            faults = child_faults(root)
            if faults > self.faults.get(root, faults):
                grew = True
            self.faults[root] = faults
        return grew

    def poll(self) -> None:
        last = self._last_pid()
        if last < 0 or last == self.last:
            self._reaped()
            return
        gone = 0
        for pid in self._new_pids(last):
            entry = stat(pid)
            if entry is None:
                gone += 1
                continue
            if is_thread(pid) or (pid, entry.start) in self.seen:
                continue
            self.seen.add((pid, entry.start))
            if self._under_roots(entry):
                self.launches += 1
        if gone:
            if self._reaped():
                self.launches += gone
            else:
                self.unseen += gone
        else:
            self._reaped()
        self.last = last


# --- desktop control ------------------------------------------------------------------------------

def state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")


def shells_index() -> dict[str, Any]:
    try:
        return json.loads(_read(state_home() / "ryoku" / "store" / "shells.json") or "{}")
    except json.JSONDecodeError:
        return {}


def active_and_in_use(index: dict[str, Any], item_id: str) -> bool:
    return index.get("active") == item_id and any(
        row.get("id") == item_id and row.get("inUse") for row in index.get("items", [])
    )


def run(command: list[str], timeout: float = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)


def in_container() -> bool:
    if Path("/run/systemd/container").is_file() or Path("/run/host/container-manager").is_file():
        return True
    detect = shutil.which("systemd-detect-virt")
    return bool(detect) and run([detect, "--container", "--quiet"], timeout=10).returncode == 0


def machine_info(shell_pid: int) -> dict[str, Any]:
    gpu = "unknown"
    for fd in os.listdir(PROC / str(shell_pid) / "fdinfo"):
        text = _read(PROC / str(shell_pid) / "fdinfo" / fd)
        if "drm-driver" not in text:
            continue
        fields = dict((k.strip(), v.strip()) for k, _, v in (line.partition(":") for line in text.splitlines()))
        gpu = fields.get("drm-driver", "unknown")
        pdev = fields.get("drm-pdev", "")
        if pdev and shutil.which("lspci"):
            name = run(["lspci", "-s", pdev], timeout=10).stdout.strip()
            gpu = f"{gpu}: {name.split(': ', 1)[-1]}" if name else gpu
        break
    outputs: list[str] = []
    scale = 1.0
    if os.environ.get("NIRI_SOCKET") and shutil.which("niri"):
        data = json.loads(run(["niri", "msg", "--json", "outputs"], timeout=10).stdout or "{}")
        rows = data.values() if isinstance(data, dict) else data
        for row in rows:
            logical = row.get("logical") or {}
            mode = next((m for m in row.get("modes", []) if m.get("is_preferred")), (row.get("modes") or [{}])[0])
            outputs.append(f"{row.get('name')} {mode.get('width')}x{mode.get('height')}")
            scale = float(logical.get("scale", scale))
    elif os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") and shutil.which("hyprctl"):
        for row in json.loads(run(["hyprctl", "-j", "monitors"], timeout=10).stdout or "[]"):
            outputs.append(f"{row.get('name')} {row.get('width')}x{row.get('height')}")
            scale = float(row.get("scale", scale))
    return {"gpu": gpu, "outputs": outputs, "scale": scale}


def wait_until(condition: Callable[[], bool], timeout: float, step: float = 0.25) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if condition():
            return True
        time.sleep(step)
    return condition()


@dataclass
class Selection:
    item_id: str
    shell: Stat
    owned: set[tuple[int, int]] = field(default_factory=set)  # processes it started
    shell_cgroup: str = ""


class Desktop:
    def __init__(self) -> None:
        self.uid = os.getuid()

    def table(self) -> dict[int, Stat]:
        return user_processes(self.uid)

    def daemon(self) -> Stat | None:
        return find(self.table(), is_daemon)

    def select(self, item_id: str, timeout: float) -> Selection:
        before = shells_index().get("active")
        since = boot_ticks()
        result = run(["ryoku-shell", "barstyle", item_id])
        if result.returncode != 0:
            raise RuntimeError(f"ryoku-shell barstyle {item_id}: {(result.stderr or result.stdout).strip()}")
        fresh = since if before != item_id else -1

        def ready() -> bool:
            return active_and_in_use(shells_index(), item_id) and find(self.table(), is_shell, fresh) is not None

        if not wait_until(ready, timeout):
            raise RuntimeError(f"{item_id}: shells.json did not report it active and in use within {timeout:g} s")
        shell = find(self.table(), is_shell, fresh)
        assert shell is not None
        return Selection(item_id, shell, shell_cgroup=cgroup(shell.pid))

    def track(self, selection: Selection, since: int) -> None:
        """Remember the processes the selection has started: its shell's descendants, and orphans in its cgroup."""
        table = self.table()
        for pid in descendants(table, selection.shell.pid):
            selection.owned.add((pid, table[pid].start))
        if not selection.shell_cgroup:
            return
        parents = {1, self.manager(table)}
        for entry in table.values():
            if entry.start >= since and entry.pid != selection.shell.pid and entry.ppid in parents:
                if cgroup(entry.pid) == selection.shell_cgroup:
                    selection.owned.add((entry.pid, entry.start))

    @staticmethod
    def manager(table: dict[int, Stat]) -> int:
        manager = find(table, lambda args: bool(args) and os.path.basename(args[0]) == "systemd" and "--user" in args)
        return manager.pid if manager else -1


def leftovers(owned: set[tuple[int, int]], alive: dict[int, Stat], describe: Callable[[int], str]) -> list[str]:
    """Command lines of owned processes still running (same PID and start time)."""
    return sorted({describe(pid) for pid, start in owned if pid in alive and alive[pid].start == start})


def describe(pid: int) -> str:
    return " ".join(argv(pid))[:200] or f"pid {pid}"


def settle(desktop: Desktop, selection: Selection, seconds: float, since: int) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        desktop.track(selection, since)
        time.sleep(min(1.0, max(0.0, deadline - time.monotonic())))


def sample(desktop: Desktop, selection: Selection, seconds: float, poll: float, since: int) -> dict[str, float]:
    daemon = desktop.daemon()
    roots = {selection.shell.pid} | ({daemon.pid} if daemon else set())

    def members() -> list[Stat]:
        table = desktop.table()
        return [table[pid] for pid in {selection.shell.pid} | descendants(table, selection.shell.pid) if pid in table]

    counter = LaunchCounter(roots)
    start = snapshot(members())
    began = time.monotonic()
    next_track = began + 1.0
    while (now := time.monotonic()) - began < seconds:
        counter.poll()
        if now >= next_track:
            desktop.track(selection, since)
            next_track = now + 1.0
        time.sleep(poll)
    counter.poll()
    elapsed = time.monotonic() - began
    end = snapshot(members())
    desktop.track(selection, since)
    return summarize(start, end, elapsed, counter.launches, counter.unseen)


# --- items ----------------------------------------------------------------------------------------

def installed_items(index: dict[str, Any]) -> list[dict[str, Any]]:
    return [row for row in index.get("items", []) if row.get("source") != "shipped" and row.get("id") != measurements.BASELINE]


def listed_items(root: Path) -> list[tuple[str, str, str]]:
    """(category, id, version) of every listed shell item whose downloads are not paused."""
    rows: list[tuple[str, str, str]] = []
    for category in ("subshells", "barstyles"):
        registry = json.loads(_read(root / category / "registry.json") or "{}")
        rows.extend((category, row["id"], row["version"]) for row in registry.get(category, []) if not row.get("downloadPaused"))
    return rows


def install_missing(root: Path, index: dict[str, Any]) -> None:
    """Install every listed item that is missing, or installed at another version than the catalogue's."""
    have = {row.get("id"): str(row.get("version", "")) for row in index.get("items", []) if row.get("source") != "shipped"}
    for category, item_id, version in listed_items(root):
        if have.get(item_id) == version:
            continue
        print(f"installing {category}/{item_id} {version}", flush=True)
        result = run(["ryostore", "install", category, item_id], timeout=600)
        if result.returncode != 0:
            print(f"  failed: {(result.stderr or result.stdout).strip()}", file=sys.stderr)


def main(argv_: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("items", nargs="*", metavar="<id>", help="items to measure; default: every installed catalogue item")
    parser.add_argument("--ryoku", required=True, help="the Ryoku build under test, e.g. $(git -C <ryoku checkout> describe --always --dirty)")
    parser.add_argument("--settle", type=float, default=90, help="seconds after an item is active before sampling (default 90)")
    parser.add_argument("--window", type=float, default=60, help="sampling window in seconds (default 60)")
    parser.add_argument("--linger", type=float, default=10, help="seconds after switching away before leftovers are read (default 10)")
    parser.add_argument("--poll", type=float, default=0.01, help="launch poll interval in seconds (default 0.01)")
    parser.add_argument("--timeout", type=float, default=180, help="seconds to wait for an item to become active (default 180)")
    parser.add_argument("--out", type=Path, default=REPO_ROOT / measurements.DIRECTORY, help="directory for <id>.json records (default: the catalogue's measurements/)")
    parser.add_argument("--install", action="store_true", help="first install every listed, downloadable item that is not installed")
    parser.add_argument("--allow-host", action="store_true", help="run outside a container (it switches the desktop's bar style for minutes)")
    args = parser.parse_args(argv_)

    if not args.allow_host and not in_container():
        print("measure.py switches bar styles for many minutes; run it in a lab container or pass --allow-host", file=sys.stderr)
        return 2
    desktop = Desktop()
    table = desktop.table()
    if find(table, is_shell) is None or find(table, is_daemon) is None:
        print("no running `qs -c shell` and `ryoku-shell daemon` for this user; start the Ryoku desktop first", file=sys.stderr)
        return 2
    if args.install:
        install_missing(REPO_ROOT, shells_index())
    index = shells_index()
    original = index.get("active") or measurements.BASELINE
    rows = installed_items(index)
    if args.items:
        known = {row["id"]: row for row in rows}
        missing = [item for item in args.items if item not in known]
        if missing:
            print(f"not installed: {', '.join(missing)}", file=sys.stderr)
            return 2
        rows = [known[item] for item in args.items]
    if not rows:
        print("no installed catalogue items to measure", file=sys.stderr)
        return 2

    window = {"settleSeconds": args.settle, "sampleSeconds": args.window, "lingerSeconds": args.linger}
    sequence = [measurements.BASELINE] + [row["id"] for row in rows]
    versions = {row["id"]: str(row.get("version", "")) for row in rows}
    results: dict[str, dict[str, float]] = {}
    found_leftovers: dict[str, list[str]] = {}
    failures: dict[str, str] = {}
    machine: dict[str, Any] | None = None
    previous: Selection | None = None

    def close(previous_selection: Selection | None) -> None:
        if previous_selection is None:
            return
        time.sleep(args.linger)
        found_leftovers[previous_selection.item_id] = leftovers(previous_selection.owned, desktop.table(), describe)

    for item_id in sequence:
        print(f"== {item_id} {datetime.now().strftime('%H:%M:%S')}", flush=True)
        since = boot_ticks()
        try:
            selection = desktop.select(item_id, args.timeout)
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            failures[item_id] = str(error)
            print(f"  {error}", file=sys.stderr)
            close(previous)
            previous = None
            if item_id == measurements.BASELINE:
                break
            continue
        close(previous)
        if machine is None:
            machine = machine_info(selection.shell.pid)
        settle(desktop, selection, max(0.0, args.settle - (args.linger if previous else 0.0)), since)
        results[item_id] = sample(desktop, selection, args.window, args.poll, since)
        print(f"  {json.dumps(results[item_id])}", flush=True)
        previous = selection
    try:
        run(["ryoku-shell", "barstyle", original])
    finally:
        close(previous)

    if measurements.BASELINE not in results:
        print(f"baseline {measurements.BASELINE} could not be measured: {failures.get(measurements.BASELINE)}", file=sys.stderr)
        return 1
    measured_at = datetime.now(timezone.utc)
    for item_id in sequence[1:]:
        if item_id not in results:
            continue
        value = measurements.record(
            item_id=item_id, version=versions[item_id], measured_at=measured_at, ryoku=args.ryoku,
            machine=machine or {"gpu": "unknown", "outputs": [], "scale": 1.0},
            item=results[item_id], baseline=results[measurements.BASELINE],
            leftovers=found_leftovers.get(item_id, []), window=window,
        )
        path = measurements.write_record(args.out, value)
        delta = value["delta"]
        print(f"{item_id:14} {value['tier']:9} dPSS {delta['pssMB']:+7.1f} MB  dGPU {delta['gpuMB']:+7.1f} MB  "
              f"dCPU {delta['cpuPct']:+6.2f} %  dWake {delta['wakeupsPerSec']:+6.1f}/s  dLaunch {delta['launchesPerMin']:+6.1f}/min  "
              f"leftovers {len(value['leftoverProcesses'])}  -> {path}")
    for item_id, error in failures.items():
        print(f"{item_id}: not measured: {error}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
