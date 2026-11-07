import QtQuick
import "../../../modules/common"

Item {
    id: root

    property bool open: false
    signal dismissRequested()

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: root.open ? 120 : 260 }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.phoneScreenInset
        radius: Theme.phoneCornerRadius - Theme.phoneScreenInset
        color: Theme.scrim
        opacity: root.open ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissRequested()
        }
        antialiasing: true
    }
}
