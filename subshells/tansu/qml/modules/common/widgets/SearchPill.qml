import QtQuick
import "../../../modules/common"

Item {
    id: root

    property alias text: input.text
    property string placeholder: "Search"
    readonly property bool focused: input.activeFocus

    signal leave()

    property bool stepKeys: false
    signal stepped(int direction)

    width: 240
    height: 40

    function begin(seed) {
        input.forceActiveFocus();
        if (seed && seed.length > 0)
            input.text = input.text + seed;
        input.cursorPosition = input.text.length;
    }

    function clear() {
        input.text = "";
    }

    Rectangle {
        x: Theme.shadowOffset - 1
        y: Theme.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accentCyan
            visible: input.activeFocus
            antialiasing: true
        }

        MaterialIcon {
            id: glass
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 22
            weight: 550
            color: Theme.ink
        }

        Text {
            visible: input.text.length === 0
            anchors.left: glass.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: ScrapbookTheme.inkSoft
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        TextInput {
            id: input
            anchors.left: glass.right
            anchors.leftMargin: 8
            anchors.right: clearBtn.visible ? clearBtn.left : parent.right
            anchors.rightMargin: clearBtn.visible ? 6 : 16
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15

            Keys.onEscapePressed: event => {
                if (input.text.length > 0) {
                    input.text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onReturnPressed: root.leave()
            Keys.onEnterPressed: root.leave()
            Keys.onDownPressed: root.stepKeys ? root.stepped(1) : root.leave()
            Keys.onUpPressed: event => {
                if (root.stepKeys)
                    root.stepped(-1)
                else
                    event.accepted = false
            }
        }

        Rectangle {
            id: clearBtn
            visible: input.text.length > 0
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: clearArea.containsMouse ? Theme.surfaceTint : Theme.surfaceDivider

            MaterialIcon {
                anchors.centerIn: parent
                name: "close"
                size: 15
                weight: 600
                color: Theme.ink
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
        }
    }
}
