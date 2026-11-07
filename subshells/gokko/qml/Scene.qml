import QtQuick
import Quickshell
import "upstream" as Mac

Item {
    id: scene
    property var modelData: null

    width: 0
    height: 0

    readonly property bool isPrimary: {
        // The Store installs this Scene in a versioned path, not the shell tree.
        // Determine the primary physical monitor without importing a relative
        // shell-internal JavaScript file.
        const screens = Quickshell.screens;
        const first = screens.length > 0 ? screens[0] : null;
        return !!first && !!scene.modelData && first.name === scene.modelData.name
    }

    Loader {
        active: scene.isPrimary
        onLoaded: {
            if (Quickshell.env("RYOKU_MACSHELL_PROBE"))
                console.log("MACSHELL_NESTED_READY " + Quickshell.env("RYOKU_MACSHELL_PROBE"));
        }
        sourceComponent: Component {
            Item {
                width: 0
                height: 0
                Mac.MacRoot {}
            }
        }
    }
}
