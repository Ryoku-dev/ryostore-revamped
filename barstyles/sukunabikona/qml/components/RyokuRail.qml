pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: rail

    required property var controller
    required property var windowData
    required property bool compact

    x: 18
    y: 18
    width: 348
    height: 1404
    transformOrigin: Item.TopLeft
    scale: Math.min(1, Math.max(0.62, (parent.height - 36) / 1404))
    opacity: compact ? 0 : 1
    visible: opacity > 0

    Behavior on opacity { NumberAnimation { duration: 220 } }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(rail.controller.bg.r, rail.controller.bg.g, rail.controller.bg.b, 0.975)
        border.color: rail.controller.hairline
        border.width: 1
    }

    Rectangle {
        x: 22
        y: 20
        width: 18
        height: 2
        radius: 1
        color: rail.controller.accentQuiet
    }

    Text {
        x: 30
        y: 29
        text: "力"
        color: rail.controller.accent
        font.family: rail.controller.fontJp
        font.weight: Font.Bold
        font.pixelSize: 20
        renderType: Text.NativeRendering
    }

    Text {
        x: 60
        y: 30
        text: "RYOKU"
        color: rail.controller.ivory
        font.family: rail.controller.fontUi
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 1.4
    }

    Text {
        x: 294
        y: 30
        text: "↗"
        color: closeArea.containsMouse ? rail.controller.ivory : rail.controller.soft
        font.family: rail.controller.fontUi
        font.pixelSize: 16

        MouseArea {
            id: closeArea
            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rail.controller.toggleRail()
        }
    }

    Rectangle { x: 30; y: 74; width: 286; height: 1; color: rail.controller.hairline }

    Item {
        x: 30
        y: 76
        width: 286
        height: 112

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(rail.controller.now, "HH:mm")
            color: rail.controller.ivory
            font.family: rail.controller.fontUi
            font.weight: Font.Light
            font.pixelSize: 68
            font.letterSpacing: -2.2
        }
    }

    Rectangle { x: 30; y: 190; width: 286; height: 1; color: rail.controller.hairline }

    Row {
        x: 30
        y: 208
        spacing: 8

        Text {
            text: "作業"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "WORKSPACES"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 32
        y: 208
        text: rail.windowData.workspace ? rail.controller.workspaceDisplay : "--"
        color: rail.controller.mutedText
        font.family: rail.controller.fontMono
        font.pixelSize: 8
    }

    Rectangle {
        x: 30
        y: 232
        width: 286
        height: 40
        radius: 8
        color: rail.controller.raised
        border.color: rail.controller.hairline
        border.width: 1
        clip: true

        Repeater {
            model: 5

            Rectangle {
                required property int index
                readonly property int workspaceId: index + 1
                readonly property bool active: rail.windowData.workspace
                    && Number(rail.windowData.workspace.id) === workspaceId

                x: index * 57.2
                width: 57.2
                height: parent.height
                color: active
                    ? rail.controller.bone
                    : workspaceArea.containsMouse
                        ? rail.controller.tint10
                        : "transparent"

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: parent.index < 4 ? rail.controller.lineSoft : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: String(parent.workspaceId).padStart(2, "0")
                    color: parent.active ? rail.controller.inkOnBone : rail.controller.soft
                    font.family: rail.controller.fontMono
                    font.weight: parent.active ? Font.DemiBold : Font.Normal
                    font.pixelSize: 9
                }

                MouseArea {
                    id: workspaceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rail.controller.focusWorkspace(index)
                }

                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }

    Rectangle { x: 30; y: 290; width: 286; height: 1; color: rail.controller.lineSoft }

    Row {
        x: 30
        y: 308
        spacing: 8

        Text {
            text: "音楽"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "NOW PLAYING"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Rectangle {
        x: 30
        y: 336
        width: 76
        height: 76
        radius: 8
        color: rail.controller.raised
        border.color: rail.controller.hairline
        border.width: 1
        clip: true

        Image {
            id: cover
            anchors.fill: parent
            anchors.margins: 3
            source: rail.controller.mediaPlayer ? rail.controller.mediaPlayer.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            text: "音"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.pixelSize: 18
            visible: cover.status !== Image.Ready
        }
    }

    Text {
        x: 122
        y: 338
        width: 194
        text: rail.controller.mediaPlayer
            ? rail.controller.trim(rail.controller.mediaPlayer.trackTitle, "NOTHING PLAYING")
            : "NOTHING PLAYING"
        color: rail.controller.ivory
        font.family: rail.controller.fontUi
        font.weight: Font.DemiBold
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Text {
        x: 122
        y: 365
        width: 194
        text: rail.controller.mediaPlayer
            ? rail.controller.trim(rail.controller.mediaPlayer.trackArtist, "UNKNOWN ARTIST")
            : "START A PLAYER"
        color: rail.controller.soft
        font.family: rail.controller.fontUi
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    Row {
        x: 122
        y: 390
        spacing: 20

        Repeater {
            model: ["󰒮", rail.controller.mediaPlayer && rail.controller.mediaPlayer.isPlaying ? "󰏤" : "󰐊", "󰒭"]

            Item {
                required property string modelData
                required property int index
                width: 22
                height: 22

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: signalButton.containsMouse ? rail.controller.ivory : rail.controller.soft
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: signalButton
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    enabled: rail.controller.mediaPlayer !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (index === 0 && rail.controller.mediaPlayer.canGoPrevious) rail.controller.mediaPlayer.previous()
                        if (index === 1 && rail.controller.mediaPlayer.canTogglePlaying) rail.controller.mediaPlayer.togglePlaying()
                        if (index === 2 && rail.controller.mediaPlayer.canGoNext) rail.controller.mediaPlayer.next()
                    }
                }
            }
        }
    }

    Item {
        x: 30
        y: 426
        width: 286
        height: 44

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: rail.controller.lineSoft
        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 3

            Repeater {
                model: rail.controller.cavaValues

                Rectangle {
                    required property var modelData
                    width: 8
                    height: Math.max(2, Math.min(40, Number(modelData) * 0.40))
                    anchors.bottom: parent.bottom
                    radius: 1
                    color: rail.controller.accentQuiet
                    Behavior on height { NumberAnimation { duration: 70 } }
                }
            }
        }
    }

    Rectangle { x: 30; y: 487; width: 286; height: 1; color: rail.controller.lineSoft }

    Row {
        x: 30
        y: 506
        spacing: 8

        Text {
            text: "状態"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "SYSTEM INFORMATION"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Row {
        x: 30
        y: 538
        spacing: 11

        Repeater {
            model: [
                { label: "CPU", value: rail.controller.cpuPercent },
                { label: "RAM", value: rail.controller.memoryPercent },
                { label: "GPU", value: rail.controller.gpuPercent },
                { label: "DSK", value: rail.controller.diskPercent }
            ]

            Item {
                required property var modelData
                width: 63
                height: 138

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(modelData.value).padStart(2, "0")
                    color: rail.controller.ivory
                    font.family: rail.controller.fontMono
                    font.pixelSize: 14
                }

                Rectangle {
                    x: 27
                    y: 28
                    width: 8
                    height: 78
                    radius: 4
                    color: rail.controller.raised

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * Math.min(100, modelData.value) / 100
                        radius: 4
                        color: rail.controller.ivory
                        opacity: 0.88
                        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                }

                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        x: 18
                        y: 28 + index * 19.5
                        width: 5
                        height: 1
                        color: rail.controller.hairline
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 120
                    text: modelData.label
                    color: rail.controller.mutedText
                    font.family: rail.controller.fontMono
                    font.pixelSize: 8
                    font.letterSpacing: 1.0
                }
            }
        }
    }

    Rectangle { x: 30; y: 692; width: 286; height: 1; color: rail.controller.lineSoft }

    Row {
        x: 30
        y: 711
        spacing: 8

        Text {
            text: "演算"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "PC INFORMATION"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Rectangle {
        x: 30
        y: 740
        width: 286
        height: 124
        radius: 8
        color: rail.controller.raised
        border.color: rail.controller.hairline
        border.width: 1

        Text {
            x: 14
            y: 11
            text: "RYOKU HOST"
            color: rail.controller.mutedText
            font.family: rail.controller.fontMono
            font.pixelSize: 8
            font.letterSpacing: 1.0
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 11
            text: "UP " + rail.controller.uptimeText
            color: rail.controller.mutedText
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }

        Rectangle { x: 14; y: 30; width: 258; height: 1; color: rail.controller.lineSoft }

        Text {
            x: 14
            y: 40
            text: "01"
            color: rail.controller.soft
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }

        Text {
            x: 42
            y: 37
            width: 178
            text: rail.controller.cpuName
            color: rail.controller.ivory
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 40
            text: rail.controller.cpuTemperature > 0 ? rail.controller.cpuTemperature + "°" : rail.controller.cpuPercent + "%"
            color: rail.controller.mutedText
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }

        Rectangle { x: 14; y: 61; width: 258; height: 1; color: rail.controller.lineSoft }

        Text {
            x: 14
            y: 71
            text: "02"
            color: rail.controller.soft
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }

        Text {
            x: 42
            y: 68
            width: 178
            text: rail.controller.gpuName
            color: rail.controller.ivory
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 71
            text: rail.controller.gpuPowerWatts > 0 ? Math.round(rail.controller.gpuPowerWatts) + "W" : rail.controller.gpuPercent + "%"
            color: rail.controller.mutedText
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }

        Rectangle { x: 14; y: 92; width: 258; height: 1; color: rail.controller.lineSoft }

        Text {
            x: 14
            y: 101
            width: 150
            text: rail.controller.osName
            color: rail.controller.mutedText
            font.family: rail.controller.fontUi
            font.pixelSize: 8
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 101
            text: rail.controller.ramTotalGiB.toFixed(0) + "G RAM"
            color: rail.controller.mutedText
            font.family: rail.controller.fontMono
            font.pixelSize: 8
        }
    }

    Rectangle { x: 30; y: 883; width: 286; height: 1; color: rail.controller.lineSoft }

    Row {
        x: 30
        y: 902
        spacing: 8

        Text {
            text: "操作"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "QUICK SETTINGS"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Rectangle {
        x: 30
        y: 931
        width: 286
        height: 180
        radius: 8
        color: rail.controller.raised
        border.color: rail.controller.hairline
        border.width: 1
        clip: true

        Repeater {
            model: [
                { jp: "接続", label: "Connections", icon: "󰤨", detail: rail.controller.networkName, command: ["ryoku-shell", "hub", "open", "connections"] },
                { jp: "画面", label: "Displays", icon: "󰍹", detail: "Layout & scale", command: ["ryoku-shell", "hub", "open", "displays"] },
                { jp: "電源", label: "Power", icon: "󰓅", detail: "Graphics & idle", command: ["ryoku-shell", "hub", "open", "gpu"] },
                { jp: "外観", label: "Appearance", icon: "󰏘", detail: "Wallpaper & theme", command: ["ryogami", "wallpaper", "ui"] }
            ]

            Rectangle {
                required property var modelData
                required property int index
                x: 0
                y: index * 45
                width: 286
                height: 45
                color: controlArea.containsMouse ? rail.controller.bone : "transparent"

                Rectangle {
                    anchors.bottom: parent.bottom
                    x: 14
                    width: 258
                    height: 1
                    color: parent.index < 3 ? rail.controller.lineSoft : "transparent"
                }

                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    text: modelData.jp
                    color: controlArea.containsMouse ? rail.controller.inkOnBoneDim : rail.controller.mutedText
                    font.family: rail.controller.fontJp
                    font.weight: Font.DemiBold
                    font.pixelSize: 9
                    renderType: Text.NativeRendering
                }

                Text {
                    x: 54
                    y: 8
                    width: 130
                    text: modelData.label
                    color: controlArea.containsMouse ? rail.controller.inkOnBone : rail.controller.ivory
                    font.family: rail.controller.fontUi
                    font.weight: Font.DemiBold
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    x: 54
                    y: 24
                    width: 158
                    text: modelData.detail
                    color: controlArea.containsMouse ? rail.controller.inkOnBoneDim : rail.controller.mutedText
                    font.family: rail.controller.fontUi
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.icon
                    color: controlArea.containsMouse ? rail.controller.inkOnBone : rail.controller.soft
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }

                MouseArea {
                    id: controlArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rail.controller.execCommand(modelData.command)
                }

                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }
    }

    Item {
        x: 30
        y: 1137
        width: 286
        height: 92

        Row {
            spacing: 8

            Text {
                text: "固定"
                color: rail.controller.mutedText
                font.family: rail.controller.fontJp
                font.weight: Font.DemiBold
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }

            Text {
                text: "PINNED APPS"
                color: rail.controller.soft
                font.family: rail.controller.fontUi
                font.weight: Font.DemiBold
                font.pixelSize: 9
                font.letterSpacing: 1.15
            }
        }

        Rectangle {
            y: 28
            width: 286
            height: 58
            radius: 8
            color: rail.controller.raised
            border.color: rail.controller.hairline
            border.width: 1
            clip: true

            Repeater {
                model: [
                    { icon: "󰀻", label: "Launcher", command: ["ryoku-shell", "launcher"] },
                    { icon: "󰆍", label: "Terminal", command: ["ryoku-app", "terminal"] },
                    { icon: "󰉋", label: "Files", command: ["ryoku-app", "files"] },
                    { icon: "󰈹", label: "Browser", command: ["ryoku-app", "browser"] }
                ]

                Rectangle {
                    required property var modelData
                    required property int index
                    x: index * 71.5
                    width: 71.5
                    height: 58
                    color: pinnedArea.containsMouse ? rail.controller.bone : "transparent"

                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: parent.index < 3 ? rail.controller.lineSoft : "transparent"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 9
                        text: modelData.icon
                        color: pinnedArea.containsMouse ? rail.controller.inkOnBone : rail.controller.soft
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 34
                        width: 64
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.label
                        color: pinnedArea.containsMouse ? rail.controller.inkOnBoneDim : rail.controller.mutedText
                        font.family: rail.controller.fontUi
                        font.pixelSize: 7
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: pinnedArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.controller.execCommand(modelData.command)
                    }

                    Behavior on color { ColorAnimation { duration: 130 } }
                }
            }
        }
    }

    // Bottom furniture: useful session actions first, then one quiet Ryoku
    // register mark. This intentionally occupies the old dead margin without
    // turning it into another telemetry panel.
    Row {
        x: 30
        y: 1246
        spacing: 8

        Text {
            text: "セッション"
            color: rail.controller.mutedText
            font.family: rail.controller.fontJp
            font.weight: Font.DemiBold
            font.pixelSize: 9
            renderType: Text.NativeRendering
        }

        Text {
            text: "SESSION"
            color: rail.controller.soft
            font.family: rail.controller.fontUi
            font.weight: Font.DemiBold
            font.pixelSize: 9
            font.letterSpacing: 1.15
        }
    }

    Rectangle {
        x: 30
        y: 1273
        width: 286
        height: 54
        radius: 8
        color: rail.controller.raised
        border.color: rail.controller.hairline
        border.width: 1
        clip: true

        Repeater {
            model: [
                { icon: "󰌾", label: "Lock", command: ["ryoku-shell", "lock"] },
                { icon: "󰐥", label: "Power", command: ["ryoku-shell", "quicksettings"] }
            ]

            Rectangle {
                required property var modelData
                required property int index
                x: index * 143
                width: 143
                height: 54
                color: sessionArea.containsMouse ? rail.controller.bone : "transparent"

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: parent.index === 0 ? rail.controller.lineSoft : "transparent"
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 9

                    Text {
                        text: parent.parent.modelData.icon
                        color: sessionArea.containsMouse ? rail.controller.inkOnBone : rail.controller.soft
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        text: parent.parent.modelData.label
                        color: sessionArea.containsMouse ? rail.controller.inkOnBone : rail.controller.ivory
                        font.family: rail.controller.fontUi
                        font.weight: Font.DemiBold
                        font.pixelSize: 9
                    }
                }

                MouseArea {
                    id: sessionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rail.controller.execCommand(modelData.command)
                }

                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }
    }

    Rectangle {
        x: 30
        y: 1352
        width: 286
        height: 1
        color: rail.controller.lineSoft
    }

    Text {
        x: 30
        y: 1364
        text: "RYOKU 緑"
        color: rail.controller.mutedText
        font.family: rail.controller.fontUi
        font.pixelSize: 7
        font.letterSpacing: 1.2
    }

    Row {
        x: 242
        y: 1367
        spacing: 3

        Repeater {
            model: [8, 2, 5, 11, 3, 7, 2, 9, 4]
            Rectangle {
                required property var modelData
                width: modelData % 3 === 0 ? 2 : 1
                height: 10
                color: rail.controller.mutedText
                opacity: 0.55
            }
        }
    }

}
