pragma ComponentBehavior: Bound

import QtQuick
import shell.services as Ryoku
import shell.barkit as Pill
import "../shared" as Shared
import "../popouts" as Popouts
import "../Format.js" as Format

// Obi battery: freedesktop battery-level glyph (charging variant on AC) plus the
// percentage in mono. Self-hides without a battery; goes error-red when low.
// Hovering opens a card with the level, charge/time, health, and a power-profile picker.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26
    visible: Ryoku.Battery.present

    readonly property bool charging: Ryoku.Battery.charging || Ryoku.Battery.full
    readonly property color tint: Ryoku.Battery.low ? Ryoku.Theme.error : Ryoku.Theme.onSurface

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Format.batteryGlyph(Ryoku.Battery.pct, root.charging)
            size: 18
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Ryoku.Battery.pct + "%"
            color: root.tint
            font.family: Ryoku.Theme.mono
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
        Popouts.BatteryPopout {}
    }
}
