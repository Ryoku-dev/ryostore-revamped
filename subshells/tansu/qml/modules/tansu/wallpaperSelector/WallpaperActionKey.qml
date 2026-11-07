import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string doneLabel: "Applied"
    property bool done: false
    property real capW: 422
    property real capH: 76

    signal clicked(bool all)

    implicitWidth: capW + 8
    implicitHeight: capH + 6

    TansuKey {
        id: key

        capW: root.capW
        capH: root.capH
        radius: 26
        lit: root.done || area.containsMouse
        hovered: area.containsMouse
        pressed: area.pressed
        ringExtra: 6

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.inkOnAccent.r, Theme.inkOnAccent.g, Theme.inkOnAccent.b, litP))

        Row {
            anchors.centerIn: parent
            spacing: 14

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                name: root.done ? "check" : root.icon
                color: key.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.done ? root.doneLabel : root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 25
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked((mouse.modifiers & Qt.ShiftModifier) !== 0)
    }
}
