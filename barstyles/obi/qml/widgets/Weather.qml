pragma ComponentBehavior: Bound

import QtQuick
import shell.services as Ryoku
import shell.barkit as Pill
import "../shared" as Shared
import "../popouts" as Popouts
import "../Format.js" as Format

// Obi weather: the current condition glyph and temperature, mirroring iNiR's
// bar readout against Ryoku's daemon-fed Weather singleton. Hidden until a
// frame loads. WMO code -> the shell's own weather-*-symbolic glyph set.
// Hovering opens a detail card with the current conditions and a daily strip.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26

    readonly property var cur: Ryoku.Weather.current
    visible: Ryoku.Weather.available && Ryoku.Weather.temp.length > 0

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.cur ? Format.weatherIcon(root.cur.code, root.cur.isDay) : "weather-unknown"
            size: 18
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

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        Popouts.WeatherPopout {}
    }
}
