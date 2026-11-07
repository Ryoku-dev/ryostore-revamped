pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

// The shell's own on-screen keyboard (modules/tansu/keyboard/), as one shared
// state. The bar's keyboard button (UtilButtons.qml / UtilKeys.qml) and the
// Quick Panel's Keyboard tile (QuickSource.qml) both read `running` and call
// `toggle()` here, so they can never disagree. It replaces wvkbd-mobintl: the
// keyboard is drawn by OnScreenKeyboard.qml and every key press comes back here
// as a `wtype` command (send()).
//
// `open` is whether the keyboard is showing. It is not a process any more, so
// there is nothing to poll: refresh() stays only so QuickSource's calls to it
// keep working.
//
// Needs `wtype` (Wayland virtual-keyboard typing; `pacman -S wtype`). If it is
// missing, opening the keyboard shows a notification instead.
//
//   qs -c tansu ipc call keyboard toggle | show | hide
Singleton {
    id: root

    property bool open: false
    readonly property bool running: root.open

    property string targetMonitorName: ""

    readonly property string program: "wtype"

    function refresh() {}

    function show() {
        if (root.open || probe.running)
            return
        probe.running = true
    }

    function hide() {
        root.open = false
        root.queue = []
    }

    function toggle() {
        if (root.open)
            root.hide()
        else
            root.show()
    }

    property var queue: []

    function send(argv) {
        if (!argv || argv.length === 0)
            return
        // A runaway hold with a stuck wtype must not pile up for ever.
        if (root.queue.length >= 64)
            root.queue.shift()
        root.queue.push(argv)
        root.drain()
    }

    function drain() {
        if (runner.running || root.queue.length === 0)
            return
        runner.command = root.queue.shift()
        runner.running = true
    }

    Process {
        id: runner
        onExited: (exitCode, exitStatus) => Qt.callLater(root.drain)
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1 || exit 127", "sh", root.program]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.targetMonitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
                root.open = true
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "material:error",
                    "On-screen keyboard", "wtype is not installed, so the keyboard cannot type. Install it through your distribution's package manager and try again."])
            }
        }
    }

}
