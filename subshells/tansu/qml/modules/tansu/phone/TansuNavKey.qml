import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    property bool badge: false
    property real minWidth: 50

    signal clicked()

    readonly property bool hovered: area.containsMouse

    readonly property real capH: 46
    readonly property real capW: Math.max(minWidth, row.implicitWidth + 24)

    implicitWidth: capW + 7
    implicitHeight: capH + 4

    TansuKey {
        id: key

        capW: root.capW
        capH: root.capH
        skew: 0.24 * Theme.settingsLean
        radius: 17
        lit: root.selected
        hovered: root.hovered
        pressed: area.pressed
        flatShadow: Theme.quickFlat
        ringExtra: 5

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.inkOnAccent.r, Theme.inkOnAccent.g, Theme.inkOnAccent.b, litP))

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 9

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                name: root.icon
                fill: Theme.iconFill
                color: key.ink
            }

            Text {
                visible: root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Rectangle {
            visible: root.badge
            x: key.capW - 22
            y: -5
            width: 15
            height: 15
            radius: 7.5
            color: ScrapbookTheme.accentPink
            border.width: 2.5
            border.color: Theme.pLine
            antialiasing: true
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.capW
        height: root.capH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
