import QtQuick
import "../quickPanel"

// An on/off setting, drawn as a leaning tile (TansuTile): a diamond badge
// with the icon, the name, and ON / OFF under it. It lights up with a wipe
// of the accent gradient when it's on, pushes into its shadow when you press
// it, and pulses by itself when the setting changes some other way.
//
//   SettingToggle {
//       icon: "cloud"; label: "Weather"
//       checked: SettingsService.flag("bar.weather")
//       onToggled: SettingsService.toggle("bar.weather")
//   }
//
// The tile's width is the page's `tileWidth` (three across a card) unless set.
TansuTile {
    id: root

    property bool checked: false
    property string detail: ""

    signal toggled()

    function ancestorTileWidth() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.tileWidth !== undefined && p !== root)
                return p.tileWidth
        }
        return 300
    }

    tileWidth: ancestorTileWidth()
    lit: checked
    subtitle: detail !== "" ? detail : (checked ? "ON" : "OFF")
    onClicked: toggled()
}
