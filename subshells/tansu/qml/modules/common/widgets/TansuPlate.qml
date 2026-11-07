import QtQuick
import Quickshell.Widgets
import "../../../modules/common"

Item {
    id: root

    property color colorTop: Theme.accentMint
    property color colorBottom: Theme.accentCyan
    property real cornerRadius: 16
    property real ringWidth: Theme.borderWidth + Theme.whiteLine
    property color dotColor: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.16)
    property color bandColor: Qt.rgba(1, 1, 1, 0.22)
    property string dotCorner: "tr"
    property real dotSpacing: 14
    property bool pressed: false

    readonly property color numberFill: Qt.darker(Theme.colBorder, 1.8)
    readonly property color numberRing: "#ffffff"

    readonly property real faceHeight: root.height - Theme.shadowOffset

    default property alias content: layer.data

    implicitHeight: 100 + Theme.shadowOffset

    Gradient {
        id: plateGradient
        GradientStop { position: 0.0; color: root.colorTop }
        GradientStop { position: 1.0; color: root.colorBottom }
    }

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        ringWidth: root.ringWidth
        fillGradient: plateGradient
        pressed: root.pressed

        ClippingRectangle {
            anchors.fill: parent
            radius: Math.max(0, root.cornerRadius - root.ringWidth)
            color: "transparent"

            DotField {
                anchors.fill: parent
                corner: root.dotCorner
                spacing: root.dotSpacing
                maxRadius: 3.4
                reach: 0.95
                dotColor: root.dotColor
            }
            Slant {
                x: parent.width * 0.56
                y: -8
                width: 46
                height: parent.height + 16
                skew: 0.22
                radius: 0
                color: root.bandColor
            }
            Slant {
                x: parent.width * 0.56 + 56
                y: -8
                width: 20
                height: parent.height + 16
                skew: 0.22
                radius: 0
                color: root.bandColor
            }
        }
    }

    Item {
        id: layer
        width: root.width
        height: root.faceHeight
    }
}
