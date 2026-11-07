"""A committed-style measurement record for catalogue trees built in tests."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from ryostore_tools import measurements


BASELINE = {"pssMB": 292.0, "gpuMB": 240.0, "cpuPct": 0.1, "wakeupsPerSec": 8.3, "launchesPerMin": 0.0}
MACHINE = {"gpu": "amdgpu: test iGPU", "outputs": ["HEADLESS-1 1920x1080"], "scale": 1.0}


def sample(**delta: float) -> dict[str, float]:
    """Absolute item metrics: the baseline plus `delta` (missing keys add nothing)."""
    return {key: BASELINE[key] + float(delta.get(key, 0.0)) for key in measurements.DELTA_KEYS}


def write_measurement(root: Path, item_id: str, version: str, leftovers: list[str] | None = None, **delta: float) -> Path:
    value = measurements.record(
        item_id=item_id, version=version, measured_at=datetime(2026, 11, 7, 12, 0, tzinfo=timezone.utc),
        ryoku="v2.0.0-test", machine=MACHINE, item=sample(**delta), baseline=dict(BASELINE),
        leftovers=leftovers or [], window={"settleSeconds": 90, "sampleSeconds": 60, "lingerSeconds": 10},
    )
    return measurements.write_record(root / measurements.DIRECTORY, value)
