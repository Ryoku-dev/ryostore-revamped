import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property string text: ""
    property color tabColor: Theme.chipFill
    property color inkColor: Theme.chipInk
    property color gemColor: Theme.dark ? Theme.accentMint : Theme.colBorder

    implicitWidth: Math.ceil(label.implicitWidth + 40 + tab.lean)
    implicitHeight: 24

    Slant {
        id: tab
        anchors.fill: parent
        skew: 0.22
        radius: 8
        color: root.tabColor
        borderColor: Theme.line
        borderWidth: 2
    }

    DiamondDot {
        x: tab.lean / 2 + 10
        y: (root.height - height) / 2
        size: 7
        lit: true
        litColor: root.gemColor
        lineColor: root.tabColor
    }

    Text {
        id: label
        x: tab.lean / 2 + 26
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        color: root.inkColor
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 1.2
    }
}
