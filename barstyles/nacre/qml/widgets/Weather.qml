import QtQuick
import shell.services as Ryoku
import shell.barkit as Pill
import "../Format.js" as Format

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)
    readonly property var current: Ryoku.Weather.current

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Ryoku.Weather.available && Ryoku.Weather.temp.length > 0

    TapHandler {
        onTapped: root.popupRequested("weather",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.current ? Format.weatherIcon(root.current.code, root.current.isDay) : "weather-unknown"
            size: 17
            color: Ryoku.Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Ryoku.Weather.temp
            color: Ryoku.Theme.onSurface
            font.family: Ryoku.Theme.fontPrimary
            font.pixelSize: Ryoku.Theme.fontSm
        }
    }

}
