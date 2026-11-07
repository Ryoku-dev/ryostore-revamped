pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"
import "."

Singleton {
    id: root

    property bool loaded: false

    property bool shown: false

    property string style: "tansu"
    readonly property var styles: ["tansu", "bars", "aurora", "ring", "dots", "mirror", "tide", "ribbons", "scope", "pulse"]
    readonly property bool isTansu: root.style === "tansu"
    readonly property bool isRing: root.style === "ring"
    readonly property bool isBand: root.style === "bars" || root.style === "aurora"
        || root.style === "dots" || root.style === "mirror" || root.style === "tide" || root.style === "ribbons" || root.style === "scope" || root.style === "pulse"
    property real bandY: -1
    property bool vertical: false
    property real bandX: -1
    property string pillStyle: "none"

    property int colorMode: 0
    readonly property int colorModeCount: 3
    property int sizeIndex: 1
    property bool stayWhenPaused: true
    readonly property int sizeCount: 4
    // 0.5 .. 2.5: how hard the lanes are driven (and how easily notes spawn).
    property real sensitivity: 1.0
    // Off: cava (the audio tap) only runs while a media player (MPRIS) is
    // playing. On: it always runs while the card is shown, so games and other
    // apps that don't speak MPRIS drive it too (costs a little CPU).
    property bool alwaysListen: false
    // On: the note analyzer (scripts/cava/tansu_analyzer.py, needs python3 + numpy)
    // is the audio tap and tells kick / snare / hat / bass / a held lead tone
    // apart. Off: plain cava bands, with the older band-based note guessing.
    // The widget also drops back to cava by itself if the analyzer won't start.
    property bool analyzer: true
    property bool useAubio: true

    property int perf: 0
    readonly property int perfCount: 3
    readonly property real frameGap: root.perf >= 2 ? 0.05 : (root.perf === 1 ? 0.036 : 0.028)

    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    property real posScale: 0
    property string screenName: ""

    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        if (root.isBand) {
            if (root.vertical)
                root.bandX = x
            else
                root.bandY = y
        } else {
            root.posX = x
            root.posY = y
        }
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    function setStyle(value) {
        const v = String(value).toLowerCase()
        if (root.styles.indexOf(v) < 0)
            return
        root.style = v
        root.persist()
    }

    function cycleStyle() {
        root.setStyle(root.styles[(root.styles.indexOf(root.style) + 1) % root.styles.length])
    }

    function setPillStyle(value) {
        const v = String(value).toLowerCase()
        if (v !== "none" && v !== "dots" && v !== "wave")
            return
        root.pillStyle = v
        root.persist()
    }

    function setColorMode(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, n))
        root.persist()
    }

    function setVertical(value) {
        root.vertical = value === true
        root.persist()
    }

    function toggleVertical() {
        root.setVertical(!root.vertical)
    }

    function setSize(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, n))
        root.persist()
    }

    function cycleSize() {
        root.setSize((root.sizeIndex + 1) % root.sizeCount)
    }

    function setSensitivity(value) {
        const v = Number(value)
        if (!isFinite(v))
            return
        root.sensitivity = Math.max(0.5, Math.min(2.5, v))
        root.persist()
    }

    function setStayWhenPaused(value) {
        root.stayWhenPaused = value === true
        root.persist()
    }

    function setAlwaysListen(value) {
        root.alwaysListen = value === true
        root.persist()
    }

    function setUseAubio(value) {
        root.useAubio = value === true
        root.persist()
    }

    function setPerf(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.perf = Math.max(0, Math.min(root.perfCount - 1, n))
        root.persist()
    }

    function setAnalyzer(value) {
        root.analyzer = value === true
        root.persist()
    }

    readonly property string script: Directories.script("state/visualizer-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            style: root.style,
            bandY: root.bandY,
            bandX: root.bandX,
            vertical: root.vertical,
            pillStyle: root.pillStyle,
            colors: root.colorMode,
            size: root.sizeIndex,
            sensitivity: root.sensitivity,
            stayWhenPaused: root.stayWhenPaused,
            alwaysListen: root.alwaysListen,
            analyzer: root.analyzer,
            useAubio: root.useAubio,
            perf: root.perf
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown !== false
            if (s.style === "confetti")
                root.style = "ribbons"
            else if (typeof s.style === "string" && root.styles.indexOf(s.style) >= 0)
                root.style = s.style
            if (typeof s.bandY === "number")
                root.bandY = s.bandY
            if (typeof s.bandX === "number")
                root.bandX = s.bandX
            root.vertical = s.vertical === true
            if (s.pillStyle === "none" || s.pillStyle === "dots" || s.pillStyle === "wave")
                root.pillStyle = s.pillStyle
            if (typeof s.colors === "number")
                root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, Math.round(s.colors)))
            if (typeof s.size === "number")
                root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, Math.round(s.size)))
            if (typeof s.sensitivity === "number")
                root.sensitivity = Math.max(0.5, Math.min(2.5, s.sensitivity))
            root.stayWhenPaused = s.stayWhenPaused !== false
            root.alwaysListen = s.alwaysListen === true
            root.analyzer = s.analyzer !== false
            root.useAubio = s.useAubio !== false
            if (typeof s.perf === "number")
                root.perf = Math.max(0, Math.min(root.perfCount - 1, Math.round(s.perf)))
        } catch (e) {
        }
        console.log("VisualizerService: restored shown=" + root.shown + " colors=" + root.colorMode
            + " size=" + root.sizeIndex)
        root.loaded = true
    }

    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
