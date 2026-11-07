pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../modules/common"
import "../modules/common/functions/KeyBinds.js" as KB
import "."

// Settings > Keys: which key each Tansu action is on, and changing it.
//
// Reads `hyprctl -j binds` (what Hyprland really has) and the saved state (the
// block in the override file, KeyBinds.js), and turns both into `rows`. A change
// writes the block (scripts/hyprland/keybinds.sh) and reloads Hyprland, which
// applies exactly what the file says; then everything is read again. See
// KeyBinds.js for why a change is never applied with live hyprctl calls.
//
// Recording a new combination pauses every shortcut (pause / resume), so that
// pressing SUPER + A reaches the panel instead of opening Apps. Escape always
// ends the pause: it is the one bind of the empty submap, so even a panel that
// lost the keyboard can't leave the shortcuts dead. The service notices Escape
// (the submap event) and says so through `paused`.
//
//   KeybindService.rows             one row per action (KeyBinds.rows)
//   KeybindService.setKeys(id, combo, taken)   combo null = no key
//   KeybindService.reset(id) / resetAll()
Singleton {
    id: root

    // "lua" or "conf" (hyprland.conf), and whether that config loads our file.
    property string mode: "lua"
    property bool linked: true
    readonly property bool niri: NiriWorkspaces.running
    readonly property bool available: !root.niri && root.linked

    property var binds: []
    property var state: ({})
    property bool loaded: false
    property bool busy: false

    readonly property var rows: KB.rows(root.binds, root.state)
    readonly property int changedCount: KB.changedCount(root.state)

    property bool paused: false

    readonly property string script: Directories.script("hyprland/keybinds.sh")

    function row(id) {
        const list = root.rows
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i]
        return null
    }

    function conflict(combo, selfId) {
        return KB.conflict(root.binds, combo, selfId, root.rows)
    }

    function refresh() {
        if (root.niri)
            return
        if (!checker.running)
            checker.running = true
        if (!bindReader.running)
            bindReader.running = true
    }

    Process {
        id: checker
        command: ["sh", root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.mode = text.indexOf("mode=conf") >= 0 ? "conf" : "lua"
                root.linked = text.indexOf("linked=no") < 0
                if (!stateReader.running)
                    stateReader.running = true
            }
        }
    }

    Process {
        id: stateReader
        command: ["sh", root.script, "read"]
        stdout: StdioCollector {
            onStreamFinished: root.state = KB.readState(text)
        }
    }

    Process {
        id: bindReader
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text)
                    root.binds = Array.isArray(list) ? list : []
                    root.loaded = true
                } catch (e) {
                    console.warn("KeybindService: couldn't read hyprctl binds (" + e + ")")
                }
            }
        }
    }

    // Hyprland's own reload (by hand, or ours) changes the binds: read them again.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.busy = false
                rereadSoon.restart()
            } else if (event.name === "submap" && root.paused && event.data !== KB.SUBMAP) {
                root.paused = false
            }
        }
    }

    Timer {
        id: rereadSoon
        interval: 150
        onTriggered: root.refresh()
    }

    function save(next) {
        root.state = next
        root.busy = true
        writer.exec(["sh", root.script, "write", KB.block(next, root.mode)])
        // If Hyprland never reports the reload (it was already reloading), read anyway.
        busyGuard.restart()
    }

    function setKeys(id, combo, taken) {
        root.save(KB.edit(root.state, root.rows, id, combo, taken || null))
    }

    function reset(id) {
        root.save(KB.reset(root.state, id))
    }

    function resetAll() {
        root.save({})
    }

    Process {
        id: writer
        // The file is written: reload, so Hyprland applies it now.
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("KeybindService: couldn't write the override file (exit " + code + ")")
            Quickshell.execDetached(["sh", root.script, "reload"])
        }
    }

    Timer {
        id: busyGuard
        interval: 2500
        onTriggered: {
            root.busy = false
            root.refresh()
        }
    }

    function pause() {
        if (root.niri || root.paused)
            return
        root.paused = true
        Quickshell.execDetached(["sh", root.script, "call"].concat(
            KB.pauseCalls(root.mode).map(c => c.join("\x1f"))))
    }

    function resume() {
        if (!root.paused)
            return
        root.paused = false
        Quickshell.execDetached(["sh", root.script, "call"].concat(
            KB.resumeCalls(root.mode).map(c => c.join("\x1f"))))
    }

    Component.onCompleted: root.refresh()
}
