pragma Singleton
import QtQuick
import Quickshell
import "."

Singleton {
    id: root

    readonly property var names: ["float", "straight", "transparent", "capsule"]

    readonly property string style: {
        const name = SettingsService.get("bar.style", "transparent")
        return root.names.indexOf(name) >= 0 ? name : "transparent"
    }

    readonly property int index: Math.max(0, root.names.indexOf(root.style))

    function setStyle(name) {
        if (root.names.indexOf(name) >= 0)
            SettingsService.set("bar.style", name)
    }

    function cycle() {
        root.setStyle(root.names[(root.index + 1) % root.names.length])
    }
}
