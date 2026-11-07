pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"
import "../modules/common/functions/PaletteMath.js" as PM
import "."

// The Palette tool's state (modules/tansu/palette/PaletteTool.qml): the five colours
// being looked at, which of them are locked, where they came from, the saved
// favourites, and the theme that was worn before the last Apply.
//
// THE RULE: looking at a palette never changes the theme. Everything here
// (colors, shuffle, locks, favourites, copy) only changes THIS file's state, and the
// tool's live preview draws from `colors` through PaletteMath.toShell, never through
// ThemeService. The theme changes in exactly two functions, apply() and undo(), and
// the tool calls them only from the Apply and Undo buttons.
//
//   import "../services"
//   PaletteService.shuffle()
//   PaletteService.copy("#04feee")
//
// Persistence is the same convention as WeatherCardService: a tiny script
// (palette-state.sh) run as a Process, debounced.
Singleton {
    id: root

    property bool loaded: false
    property bool fresh: true

    property var colors: ["#555473", "#6e6d94", "#04feee", "#00ffcb", "#d9fff6"]
    property var locks: [false, false, false, false, false]
    property string source: "wallpaper"
    property string scheme: ""
    property var favorites: []
    property string prevTheme: ""

    readonly property bool isFavorite: PM.isFavorite(root.favorites, root.colors)
    readonly property bool applied: ThemeService.current === "custom"
        && PM.sameColors(ThemeService.customColors, root.colors)
    readonly property bool canUndo: ThemeService.current === "custom"
        && root.prevTheme !== "" && root.prevTheme !== "custom" && ThemeService.has(root.prevTheme)

    // ===== the desktop widget (modules/tansu/desktopWidgets/PaletteWidget.qml) =====
    // Off until you add it (Edit Desktop, Settings -> Desktop, or the ipc): a shell update
    // must not put a new card over your desktop by itself.
    property bool shown: false

    property string size: "full"
    readonly property bool small: root.size === "2x2"
    property real posX: -1           // -1 = never placed; the widget picks a default
    property real posY: -1
    property real posScale: 0
    property string screenName: ""
    property bool toolOpen: false

    signal openRequested()

    function requestOpen() {
        root.openRequested()
    }

    // ===== looking (these never touch the theme) =====
    function setSource(name) {
        if (name !== "wallpaper" && name !== "music" && name !== "random")
            return
        root.source = name
        root.persist()
    }

    function fillFrom(list, src) {
        const picked = PM.pick(list, PM.SLOTS)
        root.colors = PM.fill(root.colors, picked, root.locks)
        root.fresh = false
        root.scheme = ""
        if (src)
            root.source = src
        root.persist()
    }

    function shuffle() {
        const kept = []
        for (let i = 0; i < PM.SLOTS; i++)
            kept.push(root.locks[i] ? root.colors[i] : "")
        const r = PM.random({ locked: kept })
        root.colors = r.colors
        root.scheme = r.scheme
        root.source = "random"
        root.persist()
    }

    function toggleLock(i) {
        if (i < 0 || i >= PM.SLOTS)
            return
        const l = root.locks.slice()
        l[i] = !l[i]
        root.locks = l
        root.persist()
    }

    function saveFavorite() {
        root.favorites = PM.addFavorite(root.favorites, root.colors, root.source, 48)
        root.persist()
    }

    function removeFavorite(colors) {
        root.favorites = PM.removeFavorite(root.favorites, colors)
        root.persist()
    }

    function toggleFavorite() {
        if (root.isFavorite)
            root.removeFavorite(root.colors)
        else
            root.saveFavorite()
    }

    function useFavorite(colors) {
        const c = PM.parse(colors)
        if (!c)
            return
        root.colors = c
        root.locks = [false, false, false, false, false]
        root.scheme = ""
        root.persist()
    }

    function copy(hex) {
        const h = PM.norm(hex)
        if (h === "")
            return false
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", h])
        return true
    }

    function copyAll() {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root.colors.join(", ")])
    }

    // ===== the widget's place =====
    // Saved straight away (no wait): a reload right after you drop the card must not be
    // able to beat the save. None of this touches the theme.
    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
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

    function setSize(value) {
        const v = (value === "2x2" || value === "small") ? "2x2" : "full"
        if (v === root.size)
            return
        root.size = v
        root.persist()
    }

    function toggleSize() {
        root.setSize(root.small ? "full" : "2x2")
    }

    function apply() {
        if (root.applied)
            return
        if (ThemeService.current !== "custom")
            root.prevTheme = ThemeService.current
        ThemeService.applyPalette(root.colors)
        root.persist()
    }

    function undo() {
        if (!root.canUndo)
            return
        ThemeService.setTheme(root.prevTheme)
    }

    readonly property string script: Directories.script("state/palette-state.sh")

    function snapshot() {
        return JSON.stringify({
            v: 1,
            colors: root.colors,
            locks: root.locks,
            source: root.source,
            scheme: root.scheme,
            favorites: root.favorites,
            prev: root.prevTheme,
            fresh: root.fresh,
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            size: root.size
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            root.fresh = s.fresh === true
            const c = PM.parse(s.colors)
            if (c)
                root.colors = c
            if (Array.isArray(s.locks) && s.locks.length === PM.SLOTS)
                root.locks = s.locks.map(v => v === true)
            if (s.source === "wallpaper" || s.source === "music" || s.source === "random")
                root.source = s.source
            if (typeof s.scheme === "string")
                root.scheme = s.scheme
            root.favorites = PM.cleanFavorites(s.favorites)
            if (typeof s.prev === "string")
                root.prevTheme = s.prev
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown === true
            root.size = s.size === "2x2" ? "2x2" : "full"
        } catch (e) {
        }
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
        interval: 400
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
