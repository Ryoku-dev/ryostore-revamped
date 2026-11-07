import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../phone"
import "../quickPanel"

Item {
    id: root

    property string label: ""
    property string icon: ""
    property var swatch: []
    property string glyphEdge: ""
    property string glyphVariant: ""
    property bool selected: false
    property real minWidth: 0

    signal clicked()

    readonly property bool hovered: area.containsMouse

    property real capH: 46
    property real fontSize: 18
    readonly property real capW: Math.max(minWidth, row.implicitWidth + 50)

    implicitWidth: capW + 7
    implicitHeight: capH + 4

    property bool keyPulse: false
    property bool suppressPulse: false

    onSelectedChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600
        onTriggered: root.suppressPulse = false
    }

    TansuKey {
        id: key

        capW: root.capW
        capH: root.capH
        skew: 0.24 * Theme.settingsLean
        radius: 17
        lit: root.selected
        hovered: root.hovered
        pressed: area.pressed || root.keyPulse
        flatShadow: Theme.quickFlat
        ringExtra: 5

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 9

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                name: root.icon
                weight: Theme.settingsIconWeight
                fill: Theme.iconFill
                color: key.ink
            }

            ScreenGlyph {
                visible: root.glyphEdge !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 22
                edge: root.glyphEdge !== "" ? root.glyphEdge : "top"
                variant: root.glyphVariant
                color: key.ink
            }

            Item {
                visible: root.swatch.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 18 + (root.swatch.length - 1) * 11
                height: 18

                Repeater {
                    model: root.swatch

                    delegate: Rectangle {
                        required property int index
                        required property color modelData

                        x: index * 11
                        width: 18
                        height: 18
                        radius: 9
                        color: modelData
                        border.width: 2
                        border.color: Theme.pRingWhite
                        antialiasing: true
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
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
        onPressed: root.suppressPulse = true
        onReleased: suppressGrace.restart()
        onCanceled: suppressGrace.restart()
        onClicked: root.clicked()
    }
}
