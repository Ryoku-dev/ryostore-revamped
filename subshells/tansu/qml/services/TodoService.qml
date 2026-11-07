pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"
import "."

// The desktop To-Do widget's state — tasks and where the card sits — kept
// as its own singleton (like PinnedAppsService.qml, WallpaperService.qml)
// rather than widget-local state, so anything else can add a task without
// touching TodoWidget.qml:
//
//   import "../services"
//   ...
//   TodoService.add("water the plants")
//
// TodoWidget.qml is the only thing that draws it.
//
// Tasks live in a ListModel (not a plain JS array) on purpose: editing or
// checking one task changes just that row, so the list keeps its scroll
// position and a half-typed edit isn't thrown away by an unrelated change.
//
// Persistence follows the same convention as PinnedAppsService: a tiny
// shell script (todo-state.sh) run as a Process. Saves are debounced, so
// dragging or typing doesn't hit the disk on every change.
Singleton {
    id: root

    property alias items: listModel

    property int total: 0
    property int doneCount: 0

    property bool loaded: false

    property bool shown: false       // off until you add it: ipc todo toggle / Edit Desktop (a first run shows only the clock)

    // The card's size. "full" is the card as it has always been; "2x2" is the footprint the
    // clock, user card and weather card share (320 x 276), so the cards line up as a set.
    // Remembered across restarts. Switch it in Settings -> Desktop, with the size key that
    // shows on the card while it is selected in Edit Desktop, or `ipc call todo size 2x2|full`.
    property string size: "full"
    readonly property bool small: root.size === "2x2"
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    property real posScale: 0

    ListModel { id: listModel }

    function recount() {
        let d = 0
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).done)
                d++
        }
        root.total = listModel.count
        root.doneCount = d
    }

    function touch() {
        root.recount()
        root.persist()
    }

    function add(title) {
        const t = String(title).trim()
        if (t === "")
            return false
        listModel.append({ title: t, done: false })
        root.touch()
        return true
    }

    function edit(index, title) {
        const t = String(title).trim()
        if (t === "" || index < 0 || index >= listModel.count)
            return
        listModel.setProperty(index, "title", t)
        root.touch()
    }

    function toggle(index) {
        if (index < 0 || index >= listModel.count)
            return
        listModel.setProperty(index, "done", !listModel.get(index).done)
        root.touch()
    }

    function remove(index) {
        if (index < 0 || index >= listModel.count)
            return
        listModel.remove(index)
        root.touch()
    }

    // Moves one task to a new position (drag-to-reorder in TodoWidget).
    // Returns whether anything moved. Only the order changes, so no recount.
    // Not saved here: a drag can hop many times, so TodoWidget calls
    // commitOrder() once, when the task is dropped.
    function move(from, to) {
        if (from === to || from < 0 || to < 0
                || from >= listModel.count || to >= listModel.count)
            return false
        listModel.move(from, to, 1)
        return true
    }

    function commitOrder() {
        root.persist()
    }

    function clearDone() {
        for (let i = listModel.count - 1; i >= 0; i--) {
            if (listModel.get(i).done)
                listModel.remove(i)
        }
        root.touch()
    }

    function setPosition(x, y, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
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

    readonly property string script: Directories.script("state/todo-state.sh")

    function snapshot() {
        const items = []
        for (let i = 0; i < listModel.count; i++) {
            const it = listModel.get(i)
            items.push({ title: it.title, done: it.done })
        }
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            shown: root.shown,
            size: root.size,
            items: items
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
            root.shown = s.shown !== false
            root.size = s.size === "2x2" ? "2x2" : "full"
            listModel.clear()
            for (const it of (s.items ?? [])) {
                if (typeof it.title === "string" && it.title !== "")
                    listModel.append({ title: it.title, done: it.done === true })
            }
        } catch (e) {
        }
        root.recount()
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
