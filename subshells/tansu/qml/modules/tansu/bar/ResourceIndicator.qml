import QtQuick
import QtQuick.Layouts
import "../../../modules/common"
import "../../../modules/common/widgets"

// Pure UI (no Quickshell imports): Status_Bar.qml feeds this the two
// numbers from ResourceSource.qml. Two small badges — CPU and RAM,
// same "icon + text" shape as BatteryIndicator.qml — sitting inside
// one Pill so they read as one widget rather than two separate ones.
// Click opens ResourcePopup.qml with the fuller breakdown.
Item {
    id: root

    property real cpuPercent: 0
    property real memPercent: 0
    property string memUsedLabel: "--"
    property string memTotalLabel: "--"

    property bool vertical: false

    signal clicked()

    readonly property bool cpuHot: cpuPercent >= 90
    readonly property bool memHot: memPercent >= 90

    readonly property string cpuGlyphName: {
        var p = root.cpuPercent
        if (p < 15) return "clock_loader_10"
        if (p < 30) return "clock_loader_20"
        if (p < 50) return "clock_loader_40"
        if (p < 70) return "clock_loader_60"
        if (p < 85) return "clock_loader_80"
        return "clock_loader_90"
    }

    readonly property string memGlyphName: "memory"

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        fillColor: Theme.chipFill
        pressed: area.pressed
        ringWidth: 6
        implicitWidth: root.vertical ? pill.barVWidth : row.implicitWidth + (pill.capsule ? 20 : 24)
        implicitHeight: root.vertical
            ? vcol.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
            : Theme.pillHeight + Theme.shadowOffset

        Column {
            id: vcol
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 6

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.cpuGlyphName
                    size: 18
                    color: root.cpuHot ? Theme.tierMax : Theme.chipInk
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.cpuPercent + "%"
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.memGlyphName
                    size: 18
                    color: root.memHot ? Theme.tierMax : Theme.chipInk
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.memPercent + "%"
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        RowLayout {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 10

            RowLayout {
                spacing: 5
                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: root.cpuGlyphName
                    size: 18
                    color: root.cpuHot ? Theme.tierMax : Theme.chipInk
                }
                Text {
                    text: root.cpuPercent + "%"
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }

            RowLayout {
                spacing: 5
                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: root.memGlyphName
                    size: 18
                    color: root.memHot ? Theme.tierMax : Theme.chipInk
                }
                Text {
                    text: root.memPercent + "%"
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
