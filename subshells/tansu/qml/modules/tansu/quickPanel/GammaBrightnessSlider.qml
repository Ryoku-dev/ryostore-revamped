import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

Item {
    id: root

    property real gamma: 100
    property real brightness: 100
    property real gammaMin: 10

    property real sliderWidth: 514
    property real gammaWidth: 176

    signal gammaMoved(real value)
    signal brightnessMoved(real value)

    implicitWidth: sliderWidth
    implicitHeight: 56

    readonly property real edge: 20
    readonly property real trackWidth: sliderWidth - edge * 2
    readonly property real brightnessWidth: trackWidth - gammaWidth

    property bool dragging: false
    property string dragSide: ""
    property real dragGamma: -1
    property real dragBrightness: -1
    readonly property real shownGamma: dragging && dragGamma >= 0 ? dragGamma : gamma
    readonly property real shownBrightness: dragging && dragBrightness >= 0 ? dragBrightness : brightness

    readonly property color ink: Theme.pInk
    readonly property color inkSub: Qt.rgba(ink.r, ink.g, ink.b, 0.667)

    Item {
        id: gammaHead
        x: root.edge
        width: root.gammaWidth - 12
        height: 32

        MaterialIcon {
            id: gammaGlyph
            x: 0
            y: (32 - height) / 2
            size: 24
            color: root.ink
            name: "contrast"
        }
        Text {
            id: gammaPct
            anchors.left: gammaGlyph.right
            anchors.leftMargin: 8
            y: (32 - height) / 2
            text: Math.round(root.shownGamma) + "%"
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    Item {
        id: brightHead
        x: root.edge + root.gammaWidth + 12
        width: root.brightnessWidth - 12
        height: 32

        MaterialIcon {
            id: brightGlyph
            x: 0
            y: (32 - height) / 2
            size: 24
            color: root.ink
            name: "light_mode"
        }
        Text {
            id: brightPct
            anchors.left: brightGlyph.right
            anchors.leftMargin: 8
            y: (32 - height) / 2
            text: Math.round(root.shownBrightness) + "%"
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    Rectangle {
        id: track
        x: root.edge
        y: 42
        width: root.trackWidth
        height: 14
        radius: 7
        color: Theme.pSurfaceDivider
        antialiasing: true

        Rectangle {
            width: root.gammaWidth * Math.max(0, Math.min(1, root.shownGamma / 100))
            height: parent.height
            radius: 7
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        Rectangle {
            x: root.gammaWidth
            width: root.brightnessWidth * Math.max(0, Math.min(1, root.shownBrightness / 100))
            height: parent.height
            radius: 7
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        Rectangle {
            x: root.gammaWidth - 1.5
            y: -3
            width: 3
            height: parent.height + 6
            radius: 1.5
            color: root.ink
            opacity: 0.55
            antialiasing: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFromX(mx) {
                const side = mx < root.gammaWidth ? "gamma" : "brightness"
                if (root.dragSide !== "" && side !== root.dragSide) {
                    if (root.dragSide === "gamma") {
                        root.dragGamma = 100
                        root.gammaMoved(100)
                    } else {
                        root.dragBrightness = 0
                        root.brightnessMoved(0)
                    }
                }
                root.dragSide = side
                if (side === "gamma") {
                    const p = Math.max(0, Math.min(1, mx / root.gammaWidth))
                    root.dragGamma = Math.max(root.gammaMin, p * 100)
                    root.gammaMoved(root.dragGamma)
                } else {
                    const p = Math.max(0, Math.min(1, (mx - root.gammaWidth) / root.brightnessWidth))
                    root.dragBrightness = p * 100
                    root.brightnessMoved(root.dragBrightness)
                }
                PanelActivity.touch()
            }

            function endDrag() {
                root.dragging = false
                root.dragSide = ""
                root.dragGamma = -1
                root.dragBrightness = -1
            }

            onPressed: mouse => {
                root.dragSide = ""
                root.dragGamma = -1
                root.dragBrightness = -1
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: endDrag()
            onCanceled: endDrag()
        }
    }
}
