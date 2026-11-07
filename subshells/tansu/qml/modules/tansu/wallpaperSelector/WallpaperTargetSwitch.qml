import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property string current: "desktop"
    signal picked(string id)

    readonly property bool lock: root.current === "lock"
    readonly property real slot: (root.width - 6) / 2

    property color thumbA: root.lock ? LockPalette.pink : Theme.accentCyan
    property color thumbB: root.lock ? LockPalette.mint : Theme.accentMint
    Behavior on thumbA { ColorAnimation { duration: 220 } }
    Behavior on thumbB { ColorAnimation { duration: 220 } }

    width: 292
    height: 40

    Rectangle {
        x: Theme.shadowOffset - 1
        y: Theme.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true
    }

    Rectangle {
        y: 3
        height: root.height - 6
        width: root.slot
        x: 3 + (root.lock ? root.slot : 0)
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.thumbA }
            GradientStop { position: 1.0; color: root.thumbB }
        }

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    Repeater {
        model: [
            { id: "desktop", label: "Desktop", icon: "desktop_windows" },
            { id: "lock", label: "Lockscreen", icon: "lock" }
        ]

        delegate: Item {
            id: seg
            required property var modelData
            required property int index
            readonly property bool on: seg.modelData.id === root.current

            x: 3 + seg.index * root.slot
            y: 0
            width: root.slot
            height: root.height

            Row {
                anchors.centerIn: parent
                spacing: 7

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.modelData.icon
                    size: 20
                    weight: 600
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyleBold
                    font.weight: Font.ExtraBold
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.id)
            }
        }
    }
}
