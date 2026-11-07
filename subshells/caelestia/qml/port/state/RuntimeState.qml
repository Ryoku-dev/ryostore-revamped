pragma Singleton

import QtQuick
import Quickshell
import shell.services as Ryoku

Singleton {
    id: root

    property bool syncing: false
    property bool gameMode: Ryoku.Flags.gameMode
    property bool inhibitIdle: Ryoku.Flags.keepAwake
    readonly property real inhibitingIdleSince: Ryoku.Flags.keepAwakeSince

    onGameModeChanged: {
        if (!syncing && Ryoku.Flags.gameMode !== gameMode)
            Ryoku.Flags.gameMode = gameMode;
    }
    onInhibitIdleChanged: {
        if (!syncing && Ryoku.Flags.keepAwake !== inhibitIdle)
            Ryoku.Flags.keepAwake = inhibitIdle;
    }

    Connections {
        target: Ryoku.Flags
        function onGameModeChanged(): void {
            root.syncing = true;
            root.gameMode = Ryoku.Flags.gameMode;
            root.syncing = false;
        }
        function onKeepAwakeChanged(): void {
            root.syncing = true;
            root.inhibitIdle = Ryoku.Flags.keepAwake;
            root.syncing = false;
        }
    }
}
