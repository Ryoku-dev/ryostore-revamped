pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int holdMs: 320

    readonly property bool busy: hold.running

    function touch() {
        hold.restart()
    }

    property Timer hold: Timer {
        interval: root.holdMs
    }
}
