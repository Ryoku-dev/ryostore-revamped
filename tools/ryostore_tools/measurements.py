"""Resource measurements: the tier rule, the committed record format and its checks.

A record is `measurements/<id>.json`, written by `tools/measure.py` in a Ryoku desktop. Its
`delta` is the item's cost over the Orpheus baseline; `tier` follows from the delta by
`tier_for`. `tools/build.py` copies tier and delta into the registry and fails `--check` when a
listed item has no current record.
"""

from __future__ import annotations

from datetime import datetime
import json
from pathlib import Path
import re
from typing import Any


DIRECTORY = "measurements"
BASELINE = "orpheus"
TIERS = ("light", "standard", "heavy")
DELTA_KEYS = ("pssMB", "gpuMB", "cpuPct", "wakeupsPerSec", "launchesPerMin")
MACHINE_KEYS = ("gpu", "outputs", "scale")
REQUIRED_KEYS = {"id", "version", "measuredAt", "ryoku", "machine", "baseline", "delta", "leftoverProcesses", "tier"}
OPTIONAL_KEYS = {"absolute", "window"}

# Main's tier rule: Light = delta PSS <= 30 MB, delta CPU <= 0.1 % and no launches;
# Standard = delta PSS <= 80 MB, delta CPU <= 0.5 % and <= 10 launches a minute; Heavy otherwise.
LIGHT = {"pssMB": 30.0, "cpuPct": 0.1, "launchesPerMin": 0.0}
STANDARD = {"pssMB": 80.0, "cpuPct": 0.5, "launchesPerMin": 10.0}

_SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")


class MeasurementError(ValueError):
    pass


def tier_for(delta: dict[str, float]) -> str:
    def within(limits: dict[str, float]) -> bool:
        return all(float(delta[key]) <= limit for key, limit in limits.items())

    if within(LIGHT):
        return "light"
    if within(STANDARD):
        return "standard"
    return "heavy"


def rounded_delta(item: dict[str, float], baseline: dict[str, float]) -> dict[str, float]:
    """Item minus baseline, rounded the way records store it (MB to 0.1, CPU to 0.01 %, rates to 0.1)."""
    places = {"pssMB": 1, "gpuMB": 1, "cpuPct": 2, "wakeupsPerSec": 1, "launchesPerMin": 1}
    return {key: round(float(item[key]) - float(baseline[key]), places[key]) + 0.0 for key in DELTA_KEYS}


def record(
    *, item_id: str, version: str, measured_at: datetime, ryoku: str, machine: dict[str, Any],
    item: dict[str, float], baseline: dict[str, float], leftovers: list[str], window: dict[str, float],
) -> dict[str, Any]:
    """The committed record for one item from its and the baseline's sampled metrics."""
    delta = rounded_delta(item, baseline)
    return {
        "id": item_id,
        "version": version,
        "measuredAt": measured_at.astimezone().isoformat(timespec="seconds"),
        "ryoku": ryoku,
        "machine": {key: machine[key] for key in MACHINE_KEYS},
        "baseline": BASELINE,
        "delta": delta,
        "leftoverProcesses": sorted(leftovers),
        "tier": tier_for(delta),
        "absolute": {"item": dict(item), "baseline": dict(baseline)},
        "window": dict(window),
    }


def write_record(directory: Path, value: dict[str, Any]) -> Path:
    validate(value, f"{DIRECTORY}/{value.get('id')}.json")
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{value['id']}.json"
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)
    return path


def _number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def validate(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise MeasurementError(f"{label}: expected an object")
    missing = sorted(REQUIRED_KEYS - set(value))
    if missing:
        raise MeasurementError(f"{label}:{missing[0]}: missing required field")
    unknown = sorted(set(value) - REQUIRED_KEYS - OPTIONAL_KEYS)
    if unknown:
        raise MeasurementError(f"{label}:{unknown[0]}: unknown field")
    for key in ("id", "version", "measuredAt", "ryoku"):
        if not isinstance(value[key], str) or not value[key].strip():
            raise MeasurementError(f"{label}:{key}: expected a non-empty string")
    if not _SEMVER.fullmatch(value["version"]):
        raise MeasurementError(f"{label}:version: expected the measured item's semantic version")
    try:
        datetime.fromisoformat(value["measuredAt"])
    except ValueError as error:
        raise MeasurementError(f"{label}:measuredAt: expected an ISO 8601 timestamp") from error
    if value["baseline"] != BASELINE:
        raise MeasurementError(f"{label}:baseline: expected {BASELINE!r}")
    machine = value["machine"]
    if not isinstance(machine, dict) or set(machine) != set(MACHINE_KEYS):
        raise MeasurementError(f"{label}:machine: expected exactly {', '.join(MACHINE_KEYS)}")
    if not isinstance(machine["gpu"], str) or not isinstance(machine["outputs"], list) or not _number(machine["scale"]):
        raise MeasurementError(f"{label}:machine: gpu is a string, outputs an array, scale a number")
    delta = value["delta"]
    if not isinstance(delta, dict) or set(delta) != set(DELTA_KEYS) or not all(_number(delta[key]) for key in DELTA_KEYS):
        raise MeasurementError(f"{label}:delta: expected exactly the numbers {', '.join(DELTA_KEYS)}")
    leftovers = value["leftoverProcesses"]
    if not isinstance(leftovers, list) or any(not isinstance(entry, str) for entry in leftovers):
        raise MeasurementError(f"{label}:leftoverProcesses: expected an array of command lines")
    if value["tier"] not in TIERS:
        raise MeasurementError(f"{label}:tier: expected one of {', '.join(TIERS)}")
    expected = tier_for(delta)
    if value["tier"] != expected:
        raise MeasurementError(f"{label}:tier: the delta makes it {expected!r}, not {value['tier']!r}")
    return value


def _version_key(version: str) -> tuple[int, int, int, int, str]:
    match = _SEMVER.fullmatch(version)
    if match is None:
        return (0, 0, 0, 0, version)
    major, minor, patch, pre = match.groups()
    # A release sorts after its pre-releases.
    return (int(major), int(minor), int(patch), 0 if pre else 1, pre or "")


def load(repo_root: Path, item_id: str) -> dict[str, Any] | None:
    path = repo_root / DIRECTORY / f"{item_id}.json"
    if not path.is_file():
        return None
    label = f"{DIRECTORY}/{item_id}.json"
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise MeasurementError(f"{label}: cannot read JSON: {error}") from error
    validate(value, label)
    if value["id"] != item_id:
        raise MeasurementError(f"{label}:id: must equal the file name {item_id!r}")
    return value


def problems(label: str, version: str, value: dict[str, Any] | None, *, required: bool) -> list[str]:
    """Problems with an item's record; `label` is `<category>/<id>`. A missing record is a problem
    only when `required` (listed shell items whose downloads are not paused)."""
    item_id = label.rsplit("/", 1)[-1]
    path = f"{DIRECTORY}/{item_id}.json"
    rerun = "run python3 tools/measure.py in a Ryoku desktop and commit the record"
    if value is None:
        return [f"{path}: missing measurement for {label}; {rerun}"] if required else []
    found: list[str] = []
    measured = _version_key(value["version"])
    current = _version_key(version)
    if measured < current:
        found.append(f"{path}: measured {label} {value['version']}, older than its version {version}; {rerun}")
    elif measured > current:
        found.append(f"{path}: measured {label} {value['version']}, newer than its version {version}")
    if value["leftoverProcesses"]:
        found.append(
            f"{path}: {label} left processes running after it was switched away from: "
            + "; ".join(value["leftoverProcesses"])
        )
    return found


def registry_metadata(value: dict[str, Any]) -> dict[str, Any]:
    return {"resourceTier": value["tier"], "resourceDelta": {key: value["delta"][key] for key in DELTA_KEYS}}


def orphans(repo_root: Path, item_ids: set[str]) -> list[str]:
    directory = repo_root / DIRECTORY
    if not directory.is_dir():
        return []
    return [
        f"{DIRECTORY}/{path.name}: no subshell or bar style {path.stem!r} in this catalogue"
        for path in sorted(directory.iterdir())
        if path.suffix == ".json" and path.stem not in item_ids
    ] + [
        f"{DIRECTORY}/{path.name}: only <id>.json records belong here"
        for path in sorted(directory.iterdir())
        if path.suffix != ".json"
    ]
