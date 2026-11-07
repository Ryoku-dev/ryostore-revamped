pragma Singleton
import QtQuick
import Quickshell
import "."

Singleton {
    id: root

    readonly property var names: ["top", "right", "bottom", "left"]

    readonly property string position: {
        const name = SettingsService.get("bar.position", "top")
        return root.names.indexOf(name) >= 0 ? name : "top"
    }

    readonly property int index: Math.max(0, root.names.indexOf(root.position))

    readonly property bool vertical: root.position === "left" || root.position === "right"

    // How thick a bar on the given edge is, in design pixels (before the
    // per-monitor scale). Bar.qml asks for its own edge's value (a bar
    // window never changes edge once it exists, see Scene.qml), so a bar
    // that is on its way out can't be resized by the new position.
    function thicknessFor(name) {
        return (name === "left" || name === "right") ? 74 : 63
    }

    readonly property int thickness: root.thicknessFor(root.position)

    readonly property bool loaded: SettingsService.loaded

    function setPosition(name) {
        if (root.names.indexOf(name) >= 0)
            SettingsService.set("bar.position", name)
    }

    function cycle() {
        root.setPosition(root.names[(root.index + 1) % root.names.length])
    }
}
