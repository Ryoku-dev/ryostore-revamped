import QtQuick
import QtQuick.Layouts
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

TansuPopup {
    id: root

    property var source: null

    readonly property int pad: 16
    readonly property int columns: 4
    readonly property real innerW: Math.max(keys.implicitWidth, tab.implicitWidth)

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 8

        SectionTab {
            id: tab
            text: "utility keys"
        }

        UtilKeys {
            id: keys
            x: (stack.width - width) / 2
            src: root.source
            columns: root.columns
            keyWidth: 44
            keyHeight: 36
            iconSize: 24
            onCloseRequested: root.closeRequested()
        }

        Text {
            width: stack.width
            height: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: keys.hint !== "" ? keys.hint : "Utility keys"
            opacity: keys.hint !== "" ? 1 : 0.55
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }
}
