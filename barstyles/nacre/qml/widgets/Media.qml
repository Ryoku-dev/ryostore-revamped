import QtQuick
import shell.services as Ryoku
import shell.barkit as Pill

Item {
    id: root

    property real barHeight: 40
    property bool mediaPresent: Ryoku.Media.present
    signal popupRequested(string name, real center, bool active, bool pinned)

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: root.mediaPresent

    onVisibleChanged: Ryoku.AudioBars.setActive(root, visible)
    Component.onCompleted: Ryoku.AudioBars.setActive(root, visible)
    Component.onDestruction: Ryoku.AudioBars.setActive(root, false)

    HoverHandler {
        id: hover
        onHoveredChanged: root.popupRequested("media",
            root.mapToItem(null, root.width / 2, root.height / 2).x, hovered, false)
    }
    TapHandler { onTapped: Ryoku.Media.toggle() }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "music_note"
            font.pixelSize: Ryoku.Theme.iconSm
            color: Ryoku.Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            text: Ryoku.Media.line
            elide: Text.ElideRight
            color: Ryoku.Theme.onSurface
            font.family: Ryoku.Theme.fontPrimary
            font.pixelSize: Ryoku.Theme.fontSm
        }
        Pill.MusicBars {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 14
            orient: "vertical"
            bands: 8
            running: Ryoku.Media.playing
        }
    }

}
