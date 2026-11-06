pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string label: service ? service.barText : qsTr("no vpn")
    readonly property bool tunnelUp: service ? service.tunnelUp : false

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25c6"
            color: root.tunnelUp ? Theme.accent : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.widthBudget > 0
                ? Math.min(implicitWidth, Math.max(40 * root.s, root.widthBudget - 20 * root.s))
                : implicitWidth
            text: root.label
            color: root.tunnelUp ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.pluginApi || !root.service)
                return;
            if (mouse.button === Qt.RightButton) {
                if (root.pluginApi.togglePanel)
                    root.pluginApi.togglePanel();
                return;
            }
            root.service.copyPreferred();
        }
    }
}
