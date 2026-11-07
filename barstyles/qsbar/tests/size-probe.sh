#!/usr/bin/env bash
# qsbar-size-probe: a stored QS Bar scale changes its live shell height.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="${RYOKU_REPO:-$(cd "$here/../../../.." && pwd)/ryoku}"
src="$repo/ryoku/shell/quickshell/shell"
# The probe runs the real bar on Ryoku's platform QML; catalogue CI has neither.
# Quickshell aborts without a PipeWire session, so that is required too.
if ! command -v qs >/dev/null 2>&1 || [[ ! -d "$src" ]] \
    || [[ ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/pipewire-0" ]]; then
    echo "qsbar-size-probe: skipped, needs qs, a PipeWire session and a Ryoku checkout (set RYOKU_REPO)"
    exit 0
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/shell/modules" "$work/cfg/ryoku"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
for child in "$src"/*; do
    name="$(basename "$child")"
    [[ "$name" == modules ]] && continue
    ln -s "$child" "$work/shell/$name"
done
for child in "$src/modules"/*; do
    ln -s "$child" "$work/shell/modules/$(basename "$child")"
done
# Quickshell refuses imports from outside the config root, so the probe and
# the item sit side by side inside it.
ln -s "$(cd "$here/.." && pwd)/qml" "$work/shell/qsbar"
cp "$here/size-probe.qml" "$work/shell/probe.qml"

cat >"$work/cfg/ryoku/shell.json" <<'JSON'
{"qsbar":{"barScale":1.5}}
JSON

QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$work/cfg" \
QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
timeout 20 qs -p "$work/shell/probe.qml" >"$work/probe.log" 2>&1 || true

if ! grep -q QSBAR-SIZE-PROBE-PASS "$work/probe.log"; then
    echo "qsbar-size-probe: FAILED" >&2
    sed -n '1,120p' "$work/probe.log" >&2
    exit 1
fi

echo "qsbar-size-probe: persisted scale changes the live bar height"
