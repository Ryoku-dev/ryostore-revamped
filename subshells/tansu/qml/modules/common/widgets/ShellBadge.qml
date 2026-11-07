import QtQuick
import "../../../modules/common"
import "../functions/NotifyKinds.js" as NK

Item {
    id: root

    property string glyph: ""
    property real size: 56

    readonly property int kind: NK.index(root.glyph)
    readonly property color fillColor: Theme.attributeColors[root.kind]
    readonly property color ink: Theme.mono ? Theme.colBorder : "#555473"
    readonly property real outline: Math.max(2, root.size * 0.055)
    readonly property real glyphSize: Math.round(root.size * 0.6)

    width: root.size
    height: root.size

    Rectangle {
        x: Math.round(root.size * 0.05)
        y: Math.round(root.size * 0.05)
        width: root.size
        height: root.size
        radius: root.size * 0.34
        color: root.ink
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.34
        color: root.fillColor
        border.width: root.outline
        border.color: root.ink
        antialiasing: true
    }

    Rectangle {
        x: root.size * 0.17
        y: root.size * 0.13
        width: root.size * 0.30
        height: root.size * 0.13
        radius: height / 2
        rotation: -24
        color: Qt.rgba(1, 1, 1, 0.5)
        antialiasing: true
    }

    Repeater {
        model: 8

        delegate: MaterialIcon {
            required property int index

            readonly property real a: index * Math.PI / 4
            readonly property real r: Math.max(1.4, root.glyphSize * 0.055)

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.cos(a) * r
            anchors.verticalCenterOffset: Math.sin(a) * r
            size: root.glyphSize
            width: root.glyphSize + 12
            height: root.glyphSize + 12
            fill: 1
            weight: 600
            color: root.ink
            name: root.glyph
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: root.glyphSize
        width: root.glyphSize + 12
        height: root.glyphSize + 12
        fill: 1
        weight: 600
        color: "#ffffff"
        name: root.glyph
    }
}
