import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

Item {
    id: root

    property bool open: false
    property var networks: []
    property bool scanning: false
    property bool manualScanning: false
    property string connectingSsid: ""
    property string errorText: ""

    signal closeRequested()
    signal scanRequested()
    signal advancedRequested()
    signal connectRequested(string ssid, string password)
    signal disconnectRequested(string ssid)

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 140 : 220
        }
    }

    property string expandedSsid: ""
    onOpenChanged: if (!open) expandedSsid = ""
    onNetworksChanged: {
        if (expandedSsid !== "" && !networks.some(n => n.ssid === expandedSsid))
            expandedSsid = ""
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
            text: "Wi-Fi"
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
                text: root.manualScanning ? "Scanning…" : "Scan"
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

        WheelScroll { scroller: list }
        ListView {
            id: list
            x: 14
            y: errorLabel.visible ? 92 : 68
            width: card.width - 28
            height: card.height - y - 14
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.networks
            onContentYChanged: PanelActivity.touch()

            delegate: Item {
                id: row

                required property var modelData

                readonly property bool expanded: root.expandedSsid === modelData.ssid
                readonly property bool busy: root.connectingSsid === modelData.ssid

                onExpandedChanged: if (expanded) Qt.callLater(() => passInput.forceActiveFocus())

                width: list.width
                height: 64 + (expanded ? 64 : 0)
                Behavior on height {
                    NumberAnimation {
                        duration: 140
                    }
                }

                Rectangle {
                    y: 2
                    width: parent.width
                    height: 60
                    radius: 20
                    color: mainArea.containsMouse ? Theme.pSurfaceHover : "transparent"
                    antialiasing: true
                }

                Row {
                    x: 14
                    y: 20
                    spacing: 3

                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            readonly property bool lit: row.modelData.signal >= (index + 1) * 33
                            width: 5
                            height: 8 + index * 6
                            anchors.bottom: parent.bottom
                            radius: 1.5
                            color: lit ? Theme.pInk : Theme.pSurfaceDivider
                            antialiasing: true
                        }
                    }
                }

                Text {
                    x: 46
                    y: 10
                    width: parent.width - 46 - 40
                    elide: Text.ElideRight
                    text: row.modelData.ssid
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    x: 46
                    y: 34
                    text: row.busy ? "Connecting…"
                        : row.modelData.connected ? "Connected — tap to disconnect"
                        : row.modelData.secured ? "Secured"
                        : "Open"
                    color: Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                MaterialIcon {
                    visible: row.modelData.secured
                    x: parent.width - 40
                    y: 20
                    size: 20
                    name: "lock"
                }

                MouseArea {
                    id: mainArea
                    y: 2
                    width: parent.width
                    height: 60
                    hoverEnabled: true
                    enabled: !row.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.connected) {
                            root.disconnectRequested(row.modelData.ssid)
                        } else if (row.modelData.secured) {
                            root.expandedSsid = row.expanded ? "" : row.modelData.ssid
                        } else {
                            root.connectRequested(row.modelData.ssid, "")
                        }
                    }
                }

                Item {
                    visible: row.expanded
                    x: 46
                    y: 64
                    width: parent.width - 46 - 14
                    height: 52

                    Rectangle {
                        id: passField
                        width: parent.width - 90
                        height: 44
                        radius: 22
                        color: Theme.pSurfaceHover
                        border.width: 2
                        border.color: passInput.activeFocus ? Theme.pLine : "transparent"

                        TextInput {
                            id: passInput
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            clip: true
                            focus: row.expanded
                            Keys.onReturnPressed: connectButton.go()
                            Keys.onEscapePressed: root.expandedSsid = ""

                            Text {
                                visible: passInput.text === "" && !passInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                color: Theme.pInkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                            }
                        }
                        antialiasing: true
                    }

                    Rectangle {
                        id: connectButton
                        anchors.left: passField.right
                        anchors.leftMargin: 8
                        width: 82
                        height: 44
                        radius: 22
                        color: connectArea.containsMouse ? Theme.accentMint : Theme.pSurface
                        border.width: 2
                        border.color: Theme.pLine

                        function go() {
                            root.connectRequested(row.modelData.ssid, passInput.text)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: connectArea.containsMouse ? Theme.colBorder : Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: connectArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectButton.go()
                        }
                        antialiasing: true
                    }
                }
            }

            TansuScrollBar {}
        }

        Text {
            visible: root.networks.length === 0 && !root.scanning
            anchors.centerIn: list
            text: "No networks found"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
        antialiasing: true
    }
}
