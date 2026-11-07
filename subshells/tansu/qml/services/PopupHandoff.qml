pragma Singleton
import QtQuick
import Quickshell
import "."

Singleton {
    id: root

    property int serial: 0

    function opening() {
        root.serial++
    }
}
