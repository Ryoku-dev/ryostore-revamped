pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../modules/common"
import "."

// The audio tap for the end4-style visualizers: the bar's media pill (dots / wave,
// VisualizerService.pillStyle) and the desktop visualizer's end4 styles. Same as
// end4-pC's cava feed: cava with scripts/cava/cava-pc.conf (50 bands, 0..1000).
//
// ONE cava for both. The desktop widget used to start a second cava with the very same
// config next to this one whenever the pill and a desktop end4 style were on together
// (two processes, two 60 fps streams, same numbers). Now the widget asks for the tap with
// `demand(+1)` / `demand(-1)` (VisualizerWidget.qml, `tapDemand`) and reads `raw`; this
// service runs cava while the pill wants it OR any widget does.
//   points  the last frame scaled by the sensitivity (what the pill reads); only filled
//           while the pill itself wants the tap, so a widget-only tap repaints no bar
//   raw     the last frame as cava sent it (what the widget's engine reads, it applies the
//           sensitivity itself); a fresh array per line while a widget wants it, as the
//           widget's own cava gave it, and empty otherwise
Singleton {
    id: root

    property var points: []
    property var raw: []

    property int widgetDemand: 0

    function demand(delta) {
        root.widgetDemand = Math.max(0, root.widgetDemand + delta)
    }

    readonly property bool anyPlaying: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true
        }
        return false
    }

    readonly property bool pillWanted: VisualizerService.loaded && VisualizerService.pillStyle !== "none" && root.anyPlaying

    onPillWantedChanged: {
        if (!root.pillWanted)
            root.points = []
    }

    onWidgetDemandChanged: {
        if (root.widgetDemand <= 0)
            root.raw = []
    }

    readonly property bool wanted: (root.pillWanted || root.widgetDemand > 0)
        && !GameModeService.enabled && !LockState.desktopAsleep

    readonly property string conf: Directories.script("cava/cava-pc.conf")

    Process {
        id: cava
        running: root.wanted
        command: ["nice", "-n", "5", "cava", "-p", root.conf]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";")
                const bands = []
                for (let i = 0; i < parts.length; i++) {
                    const v = parseFloat(parts[i])
                    if (!isNaN(v))
                        bands.push(v)
                }
                if (root.widgetDemand > 0)
                    root.raw = bands
                if (!root.pillWanted)
                    return
                const s = VisualizerService.sensitivity
                const out = new Array(bands.length)
                for (let i = 0; i < bands.length; i++)
                    out[i] = Math.min(1000, bands[i] * s)
                const last = root.points
                let same = last.length === out.length
                for (let i = 0; same && i < out.length; i++) {
                    if (last[i] !== out[i])
                        same = false
                }
                if (!same)
                    root.points = out
            }
        }

        onRunningChanged: {
            if (!cava.running) {
                root.points = []
                root.raw = []
            }
        }
    }
}
