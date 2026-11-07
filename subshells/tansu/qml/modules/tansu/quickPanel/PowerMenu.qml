import QtQuick
import "../../../services"
import "../../../modules/common"

Item {
    id: root

    property bool open: false

    property real renderScale: 1

    // While open, PowerBusyService looks for a package manager or a download that
    // a reboot / shutdown would interrupt (see below: a badge and a note).
    onOpenChanged: PowerBusyService.watching = root.open
    Component.onDestruction: PowerBusyService.watching = false

    signal powerOffRequested()
    signal rebootRequested()
    signal logoutRequested()
    signal lockRequested()
    signal sleepRequested()
    signal hibernateRequested()
    signal firmwareRequested()
    signal systemMonitorRequested()
    signal dismissRequested()

    readonly property var rows: [
        "power_settings_circle",
        "restart_alt",
        "exit_to_app",
        "lock",
        "moon_stars",
        "hotel",
        "settings_b_roll",
        "monitor_heart"
    ]

    // One pill's footprint and the gap between row centers, both design
    // units scaled by whatever this item's own `scale` ends up being
    // (QuickPanel.qml sets it to `fit`). This is also what sizes the
    // rail's window/hit-box in QuickPanel.qml (railStaticBounds), so it
    // has to cover the *largest* a pill ever gets, not just its resting
    // size — otherwise a hovered pill's extra shadow gets clipped at
    // the window edge instead of drawn.
    //
    // Resting (elevated, unhovered): 73 (round cap) + 1 (litP's max
    // +1) + 11 (shadow's max dx: 3 + 2 + hover's 6) = 85 wide,
    // 73 + 6 (shadow's max dy: 1 + 1 + hover's 4) = 79 tall. A few
    // pixels of headroom on top of that.
    readonly property real pillWidth: 90
    readonly property real pillHeight: 82
    readonly property real rowSpacing: Theme.quickFlat ? 89 : 83

    readonly property real pillFixedRight: 79

    implicitWidth: pillWidth
    implicitHeight: rows.length > 0 ? (rows.length - 1) * rowSpacing + pillHeight : 0

    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: root.open ? 120 : 260 }
    }

    readonly property real canvasMargin: 20
    readonly property real canvasLeft: pillFixedRight - pillWidth - canvasMargin
    readonly property real canvasTop: -canvasMargin
    readonly property real canvasWidth: pillWidth + canvasMargin * 2
    readonly property real canvasHeight: root.implicitHeight + canvasMargin * 2

    Item {
        id: canvas
        x: root.canvasLeft
        y: root.canvasTop
        width: root.canvasWidth
        height: root.canvasHeight

        layer.enabled: root.visible
        layer.smooth: true
        layer.samples: 8
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * root.renderScale * 2),
                                    Math.ceil(height * root.renderScale * 2))

        Item {
            id: content
            x: -root.canvasLeft
            y: -root.canvasTop

            Repeater {
                model: root.rows

                delegate: QuickToggle {
                    id: item
                    flatShadow: Theme.quickFlat

                    required property string modelData
                    required property int index

                    kind: "round"
                    icon: modelData
                    elevated: true
                    hoverLights: true
                    hoverElevates: true
                    anchorRight: true
                    x: 0
                    y: index * root.rowSpacing

                    property real popT: 0

                    visible: opacity > 0.02
                    opacity: popT
                    transform: [
                        Scale {
                            origin.x: item.width / 2
                            origin.y: item.height / 2
                            xScale: 0.35 + 0.65 * item.popT
                            yScale: 0.35 + 0.65 * item.popT
                        },
                        Translate {
                            x: (1 - item.popT) * -56
                            y: Math.sin(item.popT * Math.PI) * (1 - item.popT)
                               * (item.index % 2 === 0 ? 18 : -18)
                        }
                    ]

                    SequentialAnimation {
                        id: popAnim
                        PauseAnimation { duration: item.index * 45 }
                        NumberAnimation {
                            target: item
                            property: "popT"
                            to: 1
                            duration: 340
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.7
                        }
                    }

                    SequentialAnimation {
                        id: hideAnim
                        PauseAnimation { duration: (root.rows.length - 1 - item.index) * 30 }
                        NumberAnimation {
                            target: item
                            property: "popT"
                            to: 0
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                    }

                    Connections {
                        target: root
                        function onOpenChanged() {
                            if (root.open) {
                                hideAnim.stop()
                                popAnim.restart()
                            } else {
                                popAnim.stop()
                                hideAnim.restart()
                            }
                        }
                    }

                    readonly property bool warned: item.index <= 1 && PowerBusyService.busy

                    Rectangle {
                        visible: item.warned
                        x: item.width - 21
                        y: -3
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ff9f1c"
                        border.width: 2
                        border.color: Theme.colBorder
                        antialiasing: true
                        z: 5

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            color: Theme.colBorder
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Black
                        }
                    }

                    // The note: on the phone's side of the pill, while hovered.
                    Rectangle {
                        visible: item.warned && item.hovered
                        z: 6
                        anchors.right: parent.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 10
                        color: "#ff9f1c"
                        border.width: 2
                        border.color: Theme.colBorder
                        width: noteText.implicitWidth + 20
                        height: noteText.implicitHeight + 14

                        Text {
                            id: noteText
                            anchors.centerIn: parent
                            text: (item.index === 0 ? "Shut down" : "Reboot") + " will cut it off: "
                                  + PowerBusyService.note
                            color: Theme.colBorder
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }

                    onClicked: {
                        switch (item.index) {
                        case 0: root.powerOffRequested(); break
                        case 1: root.rebootRequested(); break
                        case 2: root.logoutRequested(); break
                        case 3: root.lockRequested(); break
                        case 4: root.sleepRequested(); break
                        case 5: root.hibernateRequested(); break
                        case 6: root.firmwareRequested(); break
                        case 7: root.systemMonitorRequested(); break
                        }
                        root.dismissRequested()
                    }
                }
            }
        }
    }
}
