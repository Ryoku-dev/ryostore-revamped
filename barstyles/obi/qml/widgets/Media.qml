pragma ComponentBehavior: Bound

import QtQuick
import shell.services as Ryoku
import "../shared" as Shared
import "../popouts" as Popouts
import shell.barkit as Pill

// Obi media chip: a small rounded album thumbnail and an elided "title · artist"
// line. Hovering opens a now-playing control card with larger art, a seek line,
// and prev/play/next transport. Self-hides until a real player reports a track.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26
    visible: Ryoku.Media.present

    // Claim the shared cava feed only while the chip is shown, like the rail
    // music widget, so a playerless desktop never runs the analyser.
    onVisibleChanged: Ryoku.AudioBars.setActive(root, visible)
    Component.onCompleted: Ryoku.AudioBars.setActive(root, visible)
    Component.onDestruction: Ryoku.AudioBars.setActive(root, false)

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 6
            clip: true
            color: Qt.rgba(Ryoku.Theme.onSurface.r, Ryoku.Theme.onSurface.g, Ryoku.Theme.onSurface.b, 0.08)

            Image {
                id: art
                anchors.fill: parent
                source: Ryoku.Media.player ? (Ryoku.Media.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Pill.MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: Ryoku.Theme.iconSm
                color: Ryoku.Theme.onSurfaceVariant
                visible: art.status !== Image.Ready || art.source === ""
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            text: Ryoku.Media.line
            elide: Text.ElideRight
            color: Ryoku.Theme.onSurface
            font.family: Ryoku.Theme.fontPrimary
            font.pixelSize: Ryoku.Theme.fontSm
        }

        Pill.MusicBars {
            anchors.verticalCenter: parent.verticalCenter
            orient: "vertical"
            bands: 9
            s: 1.1
            width: 32
            height: 16
            running: Ryoku.Media.playing
            opacity: Ryoku.Media.playing ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Ryoku.Motion.standard; easing.type: Ryoku.Motion.easeStandard } }
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
        Popouts.MediaPopout {}
    }
}
