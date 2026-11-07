import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property bool hasWindow: false
    property string app: ""
    property string title: ""
    property string icon: ""
    property int workspace: 1
    property string barPosition: "left"

    implicitWidth: Theme.pillHeight
    implicitHeight: Theme.pillHeight + Theme.shadowOffset

    readonly property string tipText: !root.hasWindow
        ? "Workspace " + root.workspace
        : (root.title !== "" && root.title.toLowerCase() !== root.app.toLowerCase()
            ? root.app + " \u2014 " + root.title.replace(/\s+/g, " ")
            : root.app)

    readonly property bool iconReady: root.hasWindow && root.icon !== "" && iconImage.status === Image.Ready
    readonly property string letter: !root.hasWindow
        ? String(root.workspace)
        : (root.app !== "" ? root.app.charAt(0).toUpperCase() : "?")

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: 8
        pressed: area.pressed
        fillGradient: Gradient {
            GradientStop { position: 0.0; color: Theme.accentMint }
            GradientStop { position: 1.0; color: Theme.accentCyan }
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: root.hasWindow ? root.icon : ""
            asynchronous: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            visible: root.iconReady
        }

        Text {
            anchors.centerIn: parent
            visible: !root.iconReady
            text: root.letter
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    BarTip {
        shown: area.containsMouse
        text: root.tipText
        barPosition: root.barPosition
    }
}
