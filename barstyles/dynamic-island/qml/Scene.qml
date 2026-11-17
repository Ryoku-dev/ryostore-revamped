pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

// The Ryoku bar product entry: the shell instantiates this scene once per
// screen (modelData is that screen). Each scene hosts its island overlay;
// the shared singletons arm once on the primary.
Item {
    id: scene

    property var modelData: null
    width: 0
    height: 0

    readonly property bool primary: modelData !== null && Quickshell.screens.length > 0
        && modelData.name === Quickshell.screens[0].name

    IslandWindow {
        modelData: scene.modelData
    }

    Loader {
        active: scene.primary && Hub.settingsOpen
        sourceComponent: SettingsWindow {}
    }

    Component.onCompleted: if (scene.primary) {
        // touch the singletons so the services start immediately
        Hub.armed;
        Notifs.ready;
        Theme.dark;
    }
}
