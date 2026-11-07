pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common/functions/EventMath.js" as EM
import "../modules/common"
import "."

// The desktop calendar card's state — the events and deadlines, where the card
// sits and whether it's shown — kept as its own singleton (like
// WeatherCardService.qml, TodoService.qml) so anything else can add an event
// without touching CalendarCardWidget.qml:
//
//   import "../services"
//   ...
//   CalendarCardService.add({ title: "Rehearsal", date: "2026-10-23", time: "14:00" })
//
// CalendarCardWidget.qml is the only thing that draws it. The events are yours,
// like the To-Do's tasks: they are not part of a desktop preset, and nothing
// here deletes one behind your back (no expiry). All the rules about what an
// event is — a real day, a title, a 24 h time, a colour 0..4, a deadline you can
// tick off — are in modules/common/functions/EventMath.js.
//
// `events` is a plain array that is replaced on every change (never edited in
// place), so everything that reads it re-reads it, and `byDay` — the same events
// grouped by date, for the month grid — is rebuilt with it.
//
// Persistence is the same convention as TodoService: a tiny shell script
// (calendarcard-state.sh) run as a Process. Position is saved straight away, the
// events are debounced.
Singleton {
    id: root

    property var events: []
    property var byDay: ({})
    readonly property int count: root.events.length
    readonly property bool full: root.events.length >= EM.MAX_EVENTS

    property bool loaded: false

    // Off until you add it (Edit Desktop, Settings -> Desktop, or the ipc): a
    // shell update must not put a new card over your desktop by itself.
    property bool shown: false

    property string size: "full"
    readonly property bool small: root.size === "2x2"
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    property real posScale: 0
    // The monitor (output name, e.g. "DP-1") the card was last dropped on.
    // Empty = never dropped yet (the widget uses the first screen).
    property string screenName: ""

    function setEvents(list) {
        const s = EM.sorted(list)
        root.events = s
        root.byDay = EM.byDay(s)
    }

    function find(id) {
        for (const e of root.events) {
            if (e.id === id)
                return e
        }
        return null
    }

    // Adds one event ({ title, date, time?, note?, color?, kind? }). Returns its
    // id, or "" when it is not an event (no title, not a real day) or the list
    // is full.
    function add(fields) {
        if (!root.loaded || root.full)
            return ""
        const c = EM.clean(fields)
        if (!c)
            return ""
        c.id = EM.newId(root.events)
        root.setEvents(root.events.concat([c]))
        root.persist()
        return c.id
    }

    function update(id, fields) {
        const old = root.find(id)
        if (!old)
            return false
        const next = EM.changed(old, fields)
        if (!next)
            return false
        root.setEvents(root.events.map(e => e.id === id ? next : e))
        root.persist()
        return true
    }

    function setDone(id, done) {
        return root.update(id, { done: done === true })
    }

    function remove(id) {
        if (!root.find(id))
            return false
        root.setEvents(root.events.filter(e => e.id !== id))
        root.persist()
        return true
    }

    // ===== card =====
    // Saved straight away (no wait): a refresh or reload right after you drop
    // the card must not be able to beat the save.
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

    readonly property string script: Directories.script("state/calendarcard-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            size: root.size,
            events: root.events
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
            root.size = s.size === "2x2" ? "2x2" : "full"
            root.setEvents(EM.parseAll(s.events))
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
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an
    // in-flight save rather than dropping it, so the *last* state is what
    // ends up on disk (same reasoning as TodoService's `saver`).
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
