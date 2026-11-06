pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real panelWidth: widthBudget > 0 ? widthBudget : 360

    implicitWidth: panelWidth
    implicitHeight: content.implicitHeight

    component CopyButton: Rectangle {
        id: button
        property bool actionEnabled: false
        signal triggered()

        implicitWidth: 58 * root.s
        implicitHeight: 26 * root.s
        radius: 6 * root.s
        color: hover.hovered && actionEnabled ? Theme.sheen : "transparent"
        border.width: 1
        border.color: actionEnabled ? Theme.lineStrong : Theme.hair
        opacity: actionEnabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            text: qsTr("COPY")
            color: button.actionEnabled ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4 * root.s
        }

        HoverHandler {
            id: hover
            cursorShape: button.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: button.actionEnabled
            onTapped: button.triggered()
        }
    }

    component DataRow: Item {
        id: dataRow
        property string label: ""
        property string value: ""
        property bool canCopy: false
        signal copyRequested()

        width: parent ? parent.width : 0
        height: 42 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 90 * root.s
            text: dataRow.label
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4 * root.s
            font.capitalization: Font.AllUppercase
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 96 * root.s
            anchors.right: copyButton.visible ? copyButton.left : parent.right
            anchors.rightMargin: copyButton.visible ? 10 * root.s : 0
            anchors.verticalCenter: parent.verticalCenter
            text: dataRow.value.length > 0 ? dataRow.value : qsTr("Not set")
            color: dataRow.value.length > 0 ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
            elide: Text.ElideRight
        }

        CopyButton {
            id: copyButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: dataRow.canCopy
            actionEnabled: dataRow.value.length > 0
            onTriggered: dataRow.copyRequested()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.hair
        }
    }

    Column {
        id: content
        width: root.panelWidth
        spacing: 0

        Item {
            width: parent.width
            height: 36 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("LAB STATUS")
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.8 * root.s
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6 * root.s
                    height: 6 * root.s
                    radius: 3 * root.s
                    color: root.service && root.service.tunnelUp ? Theme.accent : Theme.dim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service && root.service.tunnelUp ? qsTr("TUNNEL UP") : qsTr("NO VPN")
                    color: root.service && root.service.tunnelUp ? Theme.bright : Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2 * root.s
                }
            }
        }

        DataRow {
            label: qsTr("tun0 IPv4")
            value: root.service ? root.service.tunIPv4 : ""
            canCopy: true
            onCopyRequested: if (root.service) root.service.copyTunnel()
        }
        DataRow {
            label: qsTr("Target")
            value: root.service ? root.service.target : ""
            canCopy: true
            onCopyRequested: if (root.service) root.service.copyTarget()
        }
        DataRow {
            label: qsTr("Target name")
            value: root.service ? root.service.targetName : ""
        }

        Text {
            width: parent.width
            topPadding: 12 * root.s
            text: qsTr("Left-click the bar readout to copy the target, or tun0 when no target is set. Right-click it for this panel.")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }
    }
}
