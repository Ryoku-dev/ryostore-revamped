import QtQuick
import "../quickPanel"

TansuTile {
    id: root

    property string detail: ""
    property bool busy: false

    signal activated()

    function ancestorTileWidth() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.tileWidth !== undefined && p !== root)
                return p.tileWidth
        }
        return 300
    }

    tileWidth: ancestorTileWidth()
    hoverLights: true
    lit: busy
    subtitle: detail
    onClicked: activated()
}
