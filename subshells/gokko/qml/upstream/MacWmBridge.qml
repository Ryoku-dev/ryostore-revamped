import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// Compatibility layer while MacShell's direct compositor code is migrated.
// The provider, not an environment variable, defines window identity.
Scope {
    id: bridge

    readonly property bool ready: Wm.ready
    readonly property string provider: Wm.provider
    readonly property var caps: Wm.caps
    signal rawEvent(var event)

    readonly property var outputRows: {
        const outputs = Wm.outputs || []
        const rows = []
        for (let i = 0; i < outputs.length; i++) {
            const o = outputs[i]
            const ws = String(o.activeWorkspace || "")
            rows.push({
                id: i, name: o.name, x: Number(o.x || 0), y: Number(o.y || 0),
                width: Number(o.width || 0), height: Number(o.height || 0),
                scale: Number(o.scale || 1),
                activeWorkspace: { id: ws, name: ws },
                specialWorkspace: { id: 0 },
                lastIpcObject: null
            })
        }
        for (let i = 0; i < rows.length; i++) {
            const m = rows[i]
            m.lastIpcObject = {
                id: m.id, name: m.name, x: m.x, y: m.y,
                width: m.width, height: m.height, scale: m.scale,
                activeWorkspace: m.activeWorkspace,
                specialWorkspace: m.specialWorkspace
            }
        }
        return rows
    }
    readonly property var monitorRows: bridge.outputRows
    readonly property var monitors: ({ values: bridge.monitorRows })

    function monitorFor(screen) {
        if (!screen) return null
        const name = typeof screen === "string" ? screen : screen.name
        for (const mon of bridge.monitorRows) if (mon.name === name) return mon
        return null
    }

    readonly property var focusedMonitor: bridge.monitorFor(Wm.focusedOutput)

    readonly property var workspaceRows: {
        const source = Wm.workspaces || []
        const rows = []
        for (const w of source) {
            const wsid = String(w.id || w.name || "")
            rows.push({
                id: wsid, name: w.name || wsid, active: w.active === true,
                output: w.output || "", fullscreen: w.fullscreen === true,
                toplevels: { values: Wm.windowsOnWorkspace(wsid) }
            })
        }
        return rows
    }
    readonly property var workspaces: ({ values: bridge.workspaceRows })
    readonly property var focusedWorkspace: {
        const value = Wm.focusedWorkspace
        if (!value) return null
        for (const w of bridge.workspaceRows) if (String(w.id) === String(value.id)) return w
        return null
    }

    readonly property var clientRows: {
        const wins = Wm.windows || []
        const mons = bridge.monitorRows
        const rows = []
        for (const w of wins) {
            let index = -1
            for (let i = 0; i < mons.length; i++) if (mons[i].name === w.output) { index = i; break }
            const address = String(w.id)
            rows.push({
                address: address, "class": w.appId || "", title: w.title || "",
                at: [Number(w.x || 0), Number(w.y || 0)],
                size: [Number(w.width || 0), Number(w.height || 0)],
                monitor: index, workspace: { id: String(w.workspace || "") },
                floating: w.floating === true,
                fullscreen: !!(w.toplevel && w.toplevel.fullscreen),
                mapped: true, hidden: false
            })
        }
        return rows
    }
    // Provider-neutral active-window data for MacBar's application menus.
    readonly property var focusedClient: {
        const focused = Wm.focusedWindow
        if (!focused) return null
        const id = String(focused.id)
        for (const row of bridge.clientRows)
            if (String(row.address) === id) return row
        return null
    }
    readonly property string keyboardLayout: Wm.keyboardLayout
    readonly property var keyboardLayouts: Wm.keyboardLayouts
    function cycleKeyboardLayout() { Wm.cycleKeyboardLayout() }

    readonly property var toplevelRows: {
        const wins = Wm.windows || []
        const rows = []
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i]
            rows.push({
                address: String(w.id), appId: w.appId || "", title: w.title || "",
                wayland: w.toplevel || null, lastIpcObject: bridge.clientRows[i]
            })
        }
        return rows
    }
    readonly property var toplevels: ({ values: bridge.toplevelRows })

    function refreshToplevels() {}
    function refreshMonitors() {}
    function refreshWorkspaces() {}

    function dispatch(command) {
        const expr = String(command || "")
        const named = expr.match(/(?:window\s*=\s*["']address:)([^"']+)/)
        const id = named ? named[1] : (Wm.focusedWindow ? String(Wm.focusedWindow.id) : "")
        if (expr.includes("hl.dsp.window.close")) {
            if (id) Wm.closeWindow(id)
        } else if (expr.includes("hl.dsp.window.float")) {
            if (named) Wm.floatWindow(id)
            else console.warn("[macshell-wm] float requires an explicit window ID")
        } else if (expr.includes("hl.dsp.workspace.toggle_special")) {
            const m = expr.match(/toggle_special\s*\(\s*["']([^"']+)/)
            if (m) Wm.toggleSpecialWorkspace(m[1])
        } else if (expr.includes("hl.dsp.focus")) {
            const ws = expr.match(/workspace\s*=\s*["']([^"']+)/)
            if (ws) Wm.focusWorkspace(ws[1])
            else if (id) Wm.focusWindow(id)
        } else {
            // Deliberately not translated: unknown Lua must not become an
            // unsafe or incorrect window action on niri or Mango.
            console.warn("[macshell-wm] unsupported action:", expr)
        }
    }

    Connections {
        target: Wm
        function onWindowsChanged() { bridge.rawEvent({ name: "movewindowv2", data: "" }) }
        function onWorkspacesChanged() { bridge.rawEvent({ name: "workspacev2", data: "" }) }
        function onOutputsChanged() { bridge.rawEvent({ name: "focusedmonv2", data: "" }) }
        function onFocusedOutputChanged() { bridge.rawEvent({ name: "focusedmonv2", data: "" }) }
    }
}
