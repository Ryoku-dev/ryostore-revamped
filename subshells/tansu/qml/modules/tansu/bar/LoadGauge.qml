import QtQuick
import "BatteryMath.js" as BM
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property string title: ""
    property real pct: 0
    property string word: ""
    property color tint: Theme.accentMint
    property bool plain: false
    property bool hot: false
    property real wave: 1
    property real shake: 0

    implicitHeight: head.height + col.spacing + track.height
    height: implicitHeight

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    onWordChanged: stampPop.restart()

    Column {
        id: col
        width: root.width
        spacing: 8

        Item {
            id: head
            width: root.width
            height: 26

            SectionTab {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
            }

            Text {
                id: stampProbe
                visible: false
                text: root.word
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                font.letterSpacing: 0.6
            }

            Pill {
                id: stamp
                width: stampProbe.implicitWidth + 26
                height: 26
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                shadowDy: 3
                cornerRadius: 10
                ringWidth: 3
                rotation: 4
                transformOrigin: Item.Center
                scale: stampPopValue
                fillColor: Theme.chipFill

                property real stampPopValue: 1

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: root.word
                    color: root.hot ? Theme.tierMax
                                      : (Theme.dark ? Theme.accentMint : Theme.colBorder)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 0.6
                }
            }

            NumberAnimation {
                id: stampPop
                target: stamp
                property: "stampPopValue"
                from: 1.25
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }
        }

        Rectangle {
            id: track
            width: root.width
            height: 68
            radius: 18
            color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.28)
            border.width: 2
            border.color: Theme.line
            antialiasing: true

            Item {
                id: gauge
                x: 10 + root.shake
                y: 6
                width: track.width - 20
                height: 42

                readonly property int n: 10
                readonly property real segH: 36
                readonly property real skew: 0.2
                readonly property real lean: gauge.segH * gauge.skew
                readonly property real segW: 24 + gauge.lean
                readonly property real pitch: (gauge.width - gauge.segW) / (gauge.n - 1)

                Repeater {
                    model: gauge.n

                    delegate: Item {
                        id: seg
                        required property int index
                        x: seg.index * gauge.pitch
                        y: 3
                        width: gauge.segW
                        height: gauge.segH

                        readonly property real f: BM.segmentFill(root.pct, seg.index, gauge.n)
                        readonly property real t: BM.clamp01((root.wave * 650 - seg.index * 45) / 250)

                        Item {
                            anchors.fill: parent
                            scale: 0.8 + 0.2 * BM.outBack(seg.t, 2.2)
                            opacity: Math.min(1, seg.t * 3)

                            Slant {
                                anchors.fill: parent
                                skew: gauge.skew
                                radius: 9
                                color: Theme.surfaceHover
                                borderColor: Theme.line
                                borderWidth: 3
                            }

                            Slant {
                                height: parent.height
                                width: seg.f >= 1 ? parent.width
                                    : gauge.lean + Math.max(12, (parent.width - gauge.lean) * seg.f)
                                skew: gauge.skew
                                radius: 9
                                color: root.hot ? Theme.tierMax : (root.plain ? root.tint : "transparent")
                                gradient: (root.hot || root.plain) ? null : accentGradient
                                borderColor: Theme.line
                                borderWidth: 3
                                opacity: seg.f > 0 ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 160 }
                                }
                                Behavior on width {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: [ { v: "0", at: 0 }, { v: "50", at: 0.5 }, { v: "100", at: 1 } ]

                delegate: Text {
                    required property var modelData
                    x: 10 + modelData.at * (track.width - 20) - width * modelData.at
                    y: 51
                    text: modelData.v
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }
    }
}
