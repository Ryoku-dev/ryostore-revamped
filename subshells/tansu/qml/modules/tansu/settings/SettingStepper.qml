import QtQuick
import "../../../modules/common/widgets"
import "../quickPanel"

TansuTile {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    property real specialValue: NaN
    property string specialText: ""

    signal moved(real value)

    function ancestorTileWidth() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.tileWidth !== undefined && p !== root)
                return p.tileWidth
        }
        return 300
    }

    function nudge(dir) {
        const v = Math.max(root.from, Math.min(root.to, Number((root.value + dir * root.step).toFixed(6))))
        if (v !== root.value)
            root.moved(v)
    }

    readonly property string valueText: (!isNaN(specialValue) && Math.abs(value - specialValue) < 1e-6 && specialText !== "")
        ? specialText : value.toFixed(decimals) + suffix

    tileWidth: ancestorTileWidth()
    clickable: false
    subtitle: valueText
    textRightPad: 118

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        SettingRoundButton {
            icon: "remove"
            size: 40
            autoRepeat: true
            onClicked: root.nudge(-1)
        }

        SettingRoundButton {
            icon: "add"
            size: 40
            autoRepeat: true
            onClicked: root.nudge(1)
        }
    }
}
