import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

Item {
    id: root

    property bool open: false
    property var devices: []
    property bool scanning: false
    property bool manualScanning: false
    property string connectingAddress: ""
    property string errorText: ""

    signal closeRequested()
    signal scanRequested()
    signal advancedRequested()
    signal connectRequested(string address)
    signal disconnectRequested(string address)

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 140 : 220
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.phoneScreenInset
        radius: Theme.phoneCornerRadius - Theme.phoneScreenInset
        color: Theme.scrim
        opacity: root.open ? 0.55 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
        antialiasing: true
    }

    Rectangle {
        x: 40 + (Theme.quickFlat ? 0 : 5)
        y: 200 + 4
        width: 575
        height: 940
        radius: 41
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        x: 40
        y: 200
        width: 575
        height: 940
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        clip: true

        MouseArea { anchors.fill: parent }

        Text {
            x: 28
            y: 26
            text: "Bluetooth"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Rectangle {
            id: scanButton
            x: card.width - 28 - width
            y: 22
            width: scanLabel.implicitWidth + 28
            height: 34
            radius: 17
            color: scanArea.containsMouse ? Theme.pSurfaceHover : "transparent"
            border.width: 2
            border.color: Theme.pLine
            opacity: root.manualScanning ? 0.5 : 1

            Text {
                id: scanLabel
                anchors.centerIn: parent
                text: root.manualScanning ? "Refreshing…" : "Refresh"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                enabled: !root.manualScanning
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scanRequested()
            }
            antialiasing: true
        }

        Rectangle {
            id: advancedButton
            x: scanButton.x - 10 - width
            y: 22
            width: advancedLabel.implicitWidth + 28
            height: 34
            radius: 17
            color: advancedArea.containsMouse ? Theme.pSurfaceHover : "transparent"
            border.width: 2
            border.color: Theme.pLine

            Text {
                id: advancedLabel
                anchors.centerIn: parent
                text: "Advanced"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: advancedArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.advancedRequested()
            }
            antialiasing: true
        }

        Text {
            id: errorLabel
            visible: root.errorText !== ""
            x: 28
            y: 62
            width: card.width - 56
            text: root.errorText
            wrapMode: Text.Wrap
            color: Theme.tierMax
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        Text {
            x: 28
            y: errorLabel.visible ? 90 : 66
            width: card.width - 56
            text: "Devices paired elsewhere show up here. New pairing isn't done from this panel."
            wrapMode: Text.Wrap
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        WheelScroll { scroller: list }
        ListView {
            id: list
            x: 14
            y: (errorLabel.visible ? 90 : 66) + 34
            width: card.width - 28
            height: card.height - y - 14
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.devices
            onContentYChanged: PanelActivity.touch()

            delegate: Item {
                id: row

                required property var modelData

                readonly property bool busy: root.connectingAddress === modelData.address

                width: list.width
                height: 64

                Rectangle {
                    y: 2
                    width: parent.width
                    height: 60
                    radius: 20
                    color: rowArea.containsMouse ? Theme.pSurfaceHover : "transparent"
                    antialiasing: true
                }

                MaterialIcon {
                    x: 16
                    y: 20
                    size: 22
                    name: row.modelData.connected ? "bluetooth_connected" : "bluetooth"
                }

                readonly property int battery: row.modelData.connected && row.modelData.battery !== undefined
                                               ? row.modelData.battery : -1
                readonly property bool hasBattery: row.battery >= 0
                readonly property color batteryTone: row.battery <= 20 ? Theme.tierMax : Theme.pInk

                Row {
                    id: batteryTag
                    visible: row.hasBattery
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    y: 21
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        color: row.batteryTone
                        name: {
                            if (row.battery >= 100)
                                return "battery_android_frame_full"
                            const bucket = Math.ceil(row.battery / (100 / 6))
                            return "battery_android_frame_" + Math.max(1, Math.min(6, bucket))
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.battery + "%"
                        color: row.batteryTone
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Text {
                    x: 50
                    y: 10
                    width: parent.width - 50 - 14 - (row.hasBattery ? batteryTag.width + 10 : 0)
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    x: 50
                    y: 34
                    text: row.busy ? (row.modelData.connected ? "Disconnecting…" : "Connecting…")
                        : row.modelData.connected ? "Connected — tap to disconnect"
                        : "Paired — tap to connect"
                    color: Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                MouseArea {
                    id: rowArea
                    y: 2
                    width: parent.width
                    height: 60
                    hoverEnabled: true
                    enabled: !row.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.connected)
                            root.disconnectRequested(row.modelData.address)
                        else
                            root.connectRequested(row.modelData.address)
                    }
                }
            }

            TansuScrollBar {}
        }

        Text {
            visible: root.devices.length === 0 && !root.scanning
            anchors.centerIn: list
            text: "No paired devices"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
        antialiasing: true
    }
}
