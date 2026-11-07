import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services as Ryoku

PanelWindow {
    required property var modelData

    screen: modelData
    color: "transparent"
    implicitHeight: 40
    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#101010"
    }

    Component.onCompleted: Ryoku.Shells.activeBarEdge = "top"
}
