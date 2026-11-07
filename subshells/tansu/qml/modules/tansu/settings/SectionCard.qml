import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../phone"

Item {
    id: root

    property string title: ""
    property string icon: ""
    property real inset: 26
    width: parent ? parent.width : 600
    property real gap: 16
    default property alias content: flow.data

    readonly property real innerWidth: card.width - inset * 2

    readonly property bool isSectionCard: true
    property int slot: 0

    Component.onCompleted: {
        if (!parent)
            return
        let n = 0
        for (let i = 0; i < parent.children.length; i++) {
            const c = parent.children[i]
            if (c === root)
                break
            if (c.isSectionCard === true)
                n++
        }
        slot = n
    }

    readonly property color accent: Theme.attributeColors[slot % Theme.attributeColors.length]

    readonly property var iconFor: ({
        "look": "palette", "shell": "widgets", "bar": "toast", "desktop widgets": "dashboard",
        "time & alerts": "schedule", "quick panel": "instant_mix", "launcher & lock": "lock",
        "modules": "extension", "utility keys": "keyboard", "size": "aspect_ratio",
        "wallpaper": "wallpaper", "widgets": "dashboard", "dock": "dock_to_bottom", "effects": "auto_awesome",
        "one-time setup": "rocket_launch", "gaps & borders": "border_style", "windows": "select_window",
        "animations": "animation", "workspaces & layout": "grid_view", "input & display": "mouse",
        "hyprland": "grid_view", "this shell": "info", "update": "system_update_alt",
        "what's new": "campaign", "credits": "favorite"
    })
    readonly property string shownIcon: icon !== "" ? icon : (iconFor[title.toLowerCase()] || "star")

    implicitHeight: 30 + flow.implicitHeight + 30 + 4

    Rectangle {
        x: Theme.quickFlat ? 0 : 5
        y: 4
        width: card.width
        height: card.height
        radius: 30
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        width: root.width - 5
        height: root.height - 4
        radius: 30
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true

        DotField {
            x: card.width - width - 16
            y: card.height - height - 16
            width: 300
            height: 110
            corner: "br"
            spacing: 16
            maxRadius: 3
            dotColor: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.07)
        }

        Flow {
            id: flow
            x: root.inset
            y: 30
            width: card.width - root.inset * 2
            spacing: root.gap
        }
    }

    TansuKey {
        id: plate

        x: 34
        y: -22
        capW: 18 + 36 + 10 + tagText.implicitWidth + 38
        capH: 44
        skew: 0.3 * Theme.settingsLean
        radius: 15
        shadowBaseX: 3
        shadowBaseY: 3
        flatShadow: Theme.quickFlat
        idleColor: root.accent

        Rectangle {
            x: 40
            y: (plate.capH - height) / 2
            width: 28
            height: 28
            radius: 8
            rotation: 45
            color: Theme.colBg
            border.width: 2.5
            border.color: Theme.pLine
            antialiasing: true
        }

        MaterialIcon {
            x: 40 + 14 - 11
            y: (plate.capH - height) / 2
            size: 22
            name: root.shownIcon
            weight: Theme.settingsIconWeight
            color: Theme.colBorder
        }

        Text {
            id: tagText
            x: 40 + 28 + 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 21
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    Repeater {
        model: 3

        delegate: Slant {
            required property int index

            x: card.width - 108 + index * 22
            y: -13
            width: 30
            height: 27
            skew: 0.55
            radius: 3
            color: Theme.attributeColors[(root.slot + 1 + index) % Theme.attributeColors.length]
        }
    }
}
