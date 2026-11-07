import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property string layoutCode: ""

    signal clicked()

    visible: layoutCode !== ""
    implicitWidth: layoutCode !== "" ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        fillColor: Theme.chipFill
        pressed: area.pressed
        implicitWidth: label.implicitWidth + (pill.capsule ? 20 : 28)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.layoutCode
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
