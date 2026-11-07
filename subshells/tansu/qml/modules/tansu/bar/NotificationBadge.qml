import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property int count: 0
    property bool doNotDisturb: false

    signal clicked()

    implicitWidth: Theme.pillHeight
    implicitHeight: Theme.pillHeight + Theme.shadowOffset

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: 8
        fillColor: root.doNotDisturb ? Theme.surface : Theme.accentCyan
        pressed: area.pressed

        MaterialIcon {
            color: pill.capsule ? Theme.capInk : (root.doNotDisturb ? Theme.ink : Theme.colBorder)
            anchors.centerIn: parent
            size: 18
            name: root.doNotDisturb ? "notifications_off" : "notifications_active"
        }

        Rectangle {
            visible: !root.doNotDisturb && root.count > 0
            anchors {
                top: parent.top
                right: parent.right
                topMargin: -2
                rightMargin: -2
            }
            radius: 8
            color: Theme.tierMax
            border.width: 2
            border.color: Theme.ringWhite
            implicitWidth: Math.max(16, countLabel.implicitWidth + 8)
            implicitHeight: 16

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: root.count > 9 ? "9+" : root.count
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
            antialiasing: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
