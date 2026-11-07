import QtQuick
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

TansuPopup {
    id: root

    property real cpuPercent: 0
    property real memPercent: 0
    property string memUsedLabel: "--"
    property string memTotalLabel: "--"

    readonly property int pad: 16
    readonly property int innerW: 304
    readonly property real halfW: (root.innerW - 10) / 2

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    function tierOf(p) {
        if (p >= 90) return 4
        if (p >= 75) return 3
        if (p >= 50) return 2
        if (p >= 20) return 1
        return 0
    }

    readonly property var words: ["CHILL", "STEADY", "BUSY", "HEAVY", "MAXED"]
    readonly property var tierFill: [Theme.tierQuiet, Theme.tierQuiet, Theme.tierWarn, Theme.tierHigh, Theme.tierMax]

    readonly property int cpuTier: root.tierOf(root.cpuPercent)
    readonly property int memTier: root.tierOf(root.memPercent)
    readonly property bool cpuHot: root.cpuTier === 4
    readonly property bool memHot: root.memTier === 4

    readonly property string cpuGlyph: {
        var p = root.cpuPercent
        if (p < 15) return "clock_loader_10"
        if (p < 30) return "clock_loader_20"
        if (p < 50) return "clock_loader_40"
        if (p < 70) return "clock_loader_60"
        if (p < 85) return "clock_loader_80"
        return "clock_loader_90"
    }

    function plateTop(tier) {
        return tier <= 1 ? Theme.accentMint : Qt.lighter(root.tierFill[tier], 1.16)
    }

    function plateBottom(tier) {
        return tier <= 1 ? Theme.accentCyan : root.tierFill[tier]
    }

    function plateInkFor(tier) {
        return tier === 4 ? Theme.textWhite : Theme.colBorder
    }

    property real fillWave: 1
    property real shakeX: 0

    NumberAnimation {
        id: fillAnim
        target: root
        property: "fillWave"
        from: 0
        to: 1
        duration: 650
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -6; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 6; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -4; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 3; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 60 }
    }

    onOpenChanged: {
        if (open && root.reveal < 0.35) {
            fillAnim.restart()
            if (root.cpuHot || root.memHot)
                shakeAnim.restart()
        }
    }

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 10

        Row {
            width: root.innerW
            spacing: 10

            LoadPlate {
                width: root.halfW
                label: "CPU"
                glyph: root.cpuGlyph
                pct: root.cpuPercent
                colorTop: root.plateTop(root.cpuTier)
                colorBottom: root.plateBottom(root.cpuTier)
                ink: root.plateInkFor(root.cpuTier)
            }

            LoadPlate {
                width: root.halfW
                label: "RAM"
                glyph: "memory"
                pct: root.memPercent
                colorTop: root.plateTop(root.memTier)
                colorBottom: root.plateBottom(root.memTier)
                ink: root.plateInkFor(root.memTier)
            }
        }

        LoadGauge {
            width: root.innerW
            title: "Processor"
            pct: root.cpuPercent
            word: root.words[root.cpuTier]
            tint: root.tierFill[root.cpuTier]
            plain: root.cpuTier >= 2
            hot: root.cpuHot
            wave: root.fillWave
            shake: root.cpuHot ? root.shakeX : 0
        }

        LoadGauge {
            width: root.innerW
            title: "Memory"
            pct: root.memPercent
            word: root.words[root.memTier]
            tint: root.tierFill[root.memTier]
            plain: root.memTier >= 2
            hot: root.memHot
            wave: root.fillWave
            shake: root.memHot ? root.shakeX : 0
        }

        Item {
            id: readout
            width: root.innerW
            height: 50

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Pill {
                    width: Math.max(52, usedText.implicitWidth + 26)
                    height: 46
                    shadowDy: 4
                    cornerRadius: 14
                    ringWidth: 4
                    fillGradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.accentMint }
                        GradientStop { position: 1.0; color: Theme.accentCyan }
                    }

                    Text {
                        id: usedText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: root.memUsedLabel
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: "of"
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Pill {
                    width: Math.max(52, totalText.implicitWidth + 26)
                    height: 46
                    shadowDy: 4
                    cornerRadius: 14
                    ringWidth: 4
                    fillColor: Theme.chipFill

                    Text {
                        id: totalText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: root.memTotalLabel
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    leftPadding: 6
                    spacing: 1

                    Text {
                        text: "GB in use"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                    Text {
                        text: "right now"
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
