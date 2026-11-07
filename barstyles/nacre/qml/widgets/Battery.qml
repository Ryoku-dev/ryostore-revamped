import QtQuick
import shell.services as Ryoku
import shell.barkit as Pill
import "../Format.js" as Format

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)
    readonly property bool charging: Ryoku.Battery.charging || Ryoku.Battery.full

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Ryoku.Battery.present

    TapHandler {
        onTapped: root.popupRequested("battery",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Format.batteryGlyph(Ryoku.Battery.pct, root.charging)
            size: 17
            color: Ryoku.Battery.low ? Ryoku.Theme.error : Ryoku.Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Ryoku.Battery.pct + "%"
            color: Ryoku.Battery.low ? Ryoku.Theme.error : Ryoku.Theme.onSurfaceVariant
            font.family: Ryoku.Theme.mono
            font.pixelSize: Ryoku.Theme.fontSm
        }
    }

}
