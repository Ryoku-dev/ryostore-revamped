import ".."
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string text: ""
    property alias font: baseText.font
    property color baseColor: Appearance.colors.colSubtext
    property color glowColor: Appearance.colors.colOnLayer1
    property bool running: false
    property color restColor: root.glowColor
    property real phase: -1

    implicitWidth: baseText.implicitWidth
    implicitHeight: baseText.implicitHeight

    property int colorDuration: Appearance.animation.elementMoveFast.duration

    StyledText {
        id: baseText
        anchors.fill: parent
        text: root.text
        color: root.running ? root.baseColor : root.restColor
        Behavior on color {
            ColorAnimation {
                duration: root.colorDuration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.running

        StyledText {
            id: glowText
            anchors.fill: parent
            text: root.text
            font: baseText.font
            color: root.glowColor
        }

        layer.enabled: root.running
        layer.effect: OpacityMask {
            maskSource: Item {
                width: root.width
                height: root.height
                Rectangle {
                    id: band
                    width: Math.max(24, root.width * 0.45)
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: "white" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    property real loopX: -band.width
                    x: root.phase >= 0
                        ? -band.width + Math.min(1, root.phase) * (root.width + band.width)
                        : band.loopX
                    Behavior on x {
                        enabled: root.phase >= 0
                        NumberAnimation { duration: 90 }
                    }
                    NumberAnimation on loopX {
                        running: root.running && root.visible && root.phase < 0
                        loops: Animation.Infinite
                        from: -band.width
                        to: root.width
                        duration: 1400
                    }
                }
            }
        }
    }
}
