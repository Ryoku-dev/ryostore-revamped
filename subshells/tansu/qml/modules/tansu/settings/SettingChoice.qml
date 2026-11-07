import QtQuick
import "../../../modules/common"

Item {
    id: root

    property string label: ""
    property string sublabel: ""
    property var options: []
    property string current: ""
    property real labelWidth: 196

    signal picked(string id)

    width: parent ? parent.width : 600
    height: Math.max(labelColumn.implicitHeight, chips.implicitHeight)

    Column {
        id: labelColumn
        y: Math.max(0, (root.height - implicitHeight) / 2)
        width: root.labelWidth - 14
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.sublabel !== ""
            width: parent.width
            text: root.sublabel
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    Flow {
        id: chips
        x: root.labelWidth
        width: root.width - root.labelWidth
        spacing: 12

        Repeater {
            model: root.options

            delegate: SettingChip {
                required property var modelData

                label: modelData.label || ""
                icon: modelData.icon || ""
                swatch: modelData.swatch || []
                glyphEdge: modelData.edge || ""
                glyphVariant: modelData.variant || ""
                selected: root.current === modelData.id
                onClicked: root.picked(modelData.id)
            }
        }
    }
}
