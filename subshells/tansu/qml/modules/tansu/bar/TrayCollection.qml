import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../modules/common"
import "../../../modules/common/widgets"

// The "Tray Collection" capsule from Figma: navy fill, white ring,
// navy outline, hard shadow — same three-layer Pill as Weather and
// Clock — holding one icon per tray app.
//
// Used twice:
//   - the dropdown under the tray button (the apps that aren't pinned),
//     50px tall
//   - the pinned widget in the bar (the pinned apps *and* the dropdown's
//     arrow button, one pill), `compact`, 36px tall so it sits level
//     with Weather and Clock
//
// Pure UI apart from IconImage / ScriptModel (Quickshell's own icon
// widget, which understands the icon strings tray items publish, and
// a list model that keeps existing icons in place when the list
// changes). It never calls the tray items itself: it says what was
// clicked and lets Bar.qml / TrayPopups.qml decide what that means.
//
// Motion:
//   - when `present` turns true the room opens up first (the capsule's
//     `shownWidth` glides — consumers size it with that, not with
//     implicitWidth) and then the capsule pops in; when it turns false
//     it pops out and then the room closes. It glides to its new width
//     when icons come and go.
//   - a new icon eases in (no bounce); icons after a removed one slide over
//   - `leavingItem` (an app that's about to be pinned / unpinned)
//     shrinks away before it actually leaves the list
//   - `activeItem` (the app whose right-click menu is open) stays
//     lifted so you can see which icon the menu belongs to
Pill {
    id: root

    property var model: []
    property bool compact: false

    property bool vertical: false

    property bool present: true

    // False: every size change, the pop and every arriving icon snap
    // instead of animating. The dropdown keeps this off while it's closed and for a
    // moment after it opens, so it appears fully formed instead of
    // gliding / popping into shape (a hidden window only lays itself out
    // once it's shown, which would otherwise play as an animation).
    property bool animated: true

    property var activeItem: null
    property var leavingItem: null

    signal itemClicked(var item, int button, Item icon)
    signal itemScrolled(var item, real delta, bool horizontal)

    property bool scrollEnabled: true

    readonly property int iconSize: compact ? (root.capsule ? 16 : 18) : 22
    readonly property int iconGap: compact ? 10 : 18
    readonly property int padX: vertical ? (root.capsule ? Math.max(8, (Theme.capVChip - iconSize) / 2) : 8) : (compact ? (root.capsule ? ((empty && showToggle) ? 3 : 8) : ((empty && showToggle) ? 2 : 12)) : 21)
    readonly property int padY: vertical ? 8 : (compact ? 3 : 8)
    readonly property int maxPerRow: 6

    readonly property int count: model ? model.length : 0
    readonly property bool empty: count === 0

    ringWidth: root.capsule ? 0 : 6
    fillColor: Theme.chipFill

    property bool showToggle: false
    property bool toggleOpen: false
    property bool toggleAttention: false
    property real glyphRotation: 0
    property real texel: 1
    signal toggleRequested()
    readonly property Item toggleItem: toggleCell

    readonly property real toggleSize: iconSize
    readonly property real toggleW: showToggle ? toggleSize : 0
    readonly property real toggleGap: (showToggle && !empty) ? iconGap : 0

    readonly property real bodyWidth: empty ? (showToggle ? 0 : emptyLabel.implicitWidth) : grid.implicitWidth
    readonly property real bodyHeight: empty ? (showToggle ? 0 : emptyLabel.implicitHeight) : grid.implicitHeight

    readonly property real contentWidth: vertical
        ? Math.max(bodyWidth, toggleW)
        : bodyWidth + toggleGap + toggleW
    readonly property real contentHeight: vertical
        ? bodyHeight + toggleGap + toggleW
        : Math.max(bodyHeight, toggleW)

    readonly property real fullWidth: contentWidth + padX * 2 + ringWidth * 2
    readonly property real minWidth: iconSize + padX * 2 + ringWidth * 2
    readonly property real minHeight: iconSize + padY * 2 + ringWidth * 2 + Theme.shadowOffset

    implicitWidth: fullWidth
    implicitHeight: Math.max(contentHeight + padY * 2, Theme.pillHeight - ringWidth * 2)
        + ringWidth * 2 + Theme.shadowOffset

    // The capsule appears and goes in two steps, so it never sweeps
    // open or shut while it is visible:
    //   appear: the room opens up first (neighbours glide aside, the
    //           capsule itself is still invisible), then it pops in
    //           (scale + fade) in the space that's there.
    //   go:     it pops out first, then the room closes up (neighbours
    //           glide back).
    // `slotOpen` is "there's room for it" and `popT` is the pop, 0..1.
    // Both follow `present` (the handler below plays the two steps).
    property bool slotOpen: present
    property real popT: present ? 1 : 0

    property real keptWidth: fullWidth
    property real keptHeight: implicitHeight
    onFullWidthChanged: {
        if (present)
            keptWidth = fullWidth
        if (ready && present && animated && popT > 0.99)
            bumpAnim.restart()
    }
    onImplicitHeightChanged: if (present) keptHeight = implicitHeight

    property bool ready: false
    Component.onCompleted: ready = true

    onPresentChanged: {
        if (!ready)
            return
        popInAnim.stop()
        popOutAnim.stop()
        if (!animated) {
            slotOpen = present
            popT = present ? 1 : 0
        } else if (present) {
            slotOpen = true
            popInAnim.restart()
        } else {
            popOutAnim.restart()
        }
    }

    SequentialAnimation {
        id: popInAnim
        PauseAnimation { duration: 70 }
        NumberAnimation { target: root; property: "popT"; to: 1; duration: 170
            easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    SequentialAnimation {
        id: popOutAnim
        NumberAnimation { target: root; property: "popT"; to: 0; duration: 120; easing.type: Easing.InCubic }
        ScriptAction { script: root.slotOpen = false }
    }

    property real shownWidth: slotOpen ? (present ? fullWidth : keptWidth) : 0
    Behavior on shownWidth {
        enabled: root.animated
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    property real shownHeight: slotOpen ? (present ? implicitHeight : keptHeight) : 0
    Behavior on shownHeight {
        enabled: root.animated
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    readonly property real reveal: vertical
        ? Math.max(0, Math.min(1, shownHeight / minHeight))
        : Math.max(0, Math.min(1, shownWidth / minWidth))

    property real bump: 1
    NumberAnimation {
        id: bumpAnim
        target: root
        property: "bump"
        from: 0.95
        to: 1
        duration: 170
        easing.type: Easing.OutBack
        easing.overshoot: 2.0
    }

    opacity: Math.min(1, popT * 2)
    scale: (0.8 + 0.2 * popT) * bump

    cornerRadius: Math.min(compact ? Theme.radiusBadge : 25, (height - Theme.shadowOffset) / 2)

    ScrollHint {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -6
        anchors.rightMargin: -6
        active: root.compact && root.scrollEnabled && !root.empty && !root.capsule
    }

    // Everything inside is clipped to the fill, so icons don't spill out
    // of a capsule that's still growing.
    Item {
        id: clipper
        anchors.fill: parent
        clip: true

        Text {
            id: emptyLabel
            anchors.centerIn: parent
            visible: root.empty && !root.showToggle && (!root.compact || root.present)
            text: "Nothing here"
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Grid {
            id: grid
            x: root.padX
            y: (root.vertical && root.showToggle) ? root.padY : (clipper.height - height) / 2
            visible: !root.empty
            columns: root.vertical ? 1 : Math.max(1, Math.min(root.count, root.maxPerRow))
            columnSpacing: root.iconGap
            rowSpacing: root.vertical ? root.iconGap : 12

            Repeater {
                model: ScriptModel { values: root.model }

                delegate: Item {
                    id: tile

                    required property var modelData

                    readonly property bool leaving: root.leavingItem !== null && tile.modelData === root.leavingItem
                    readonly property bool active: root.activeItem !== null && tile.modelData === root.activeItem

                    width: root.iconSize
                    height: root.iconSize

                    property bool arrived: !root.animated
                    Timer {
                        interval: 30
                        running: true
                        onTriggered: tile.arrived = true
                    }

                    property real presence: (tile.arrived && !tile.leaving) ? 1 : 0
                    Behavior on presence {
                        enabled: root.animated
                        NumberAnimation {
                            duration: tile.leaving ? 110 : 190
                            easing.type: tile.leaving ? Easing.InCubic : Easing.OutBack
                            easing.overshoot: 1.6
                        }
                    }

                    property real lift: area.pressed ? 0.85 : ((area.containsMouse || tile.active) ? 1.12 : 1.0)
                    Behavior on lift {
                        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }

                    opacity: Math.min(1, tile.presence)
                    scale: (0.4 + 0.6 * tile.presence) * tile.lift

                    IconImage {
                        anchors.fill: parent
                        source: tile.modelData?.icon ?? ""
                    }

                    readonly property bool attention: tile.modelData?.status === "NeedsAttention"
                    Rectangle {
                        visible: tile.attention
                        width: 9
                        height: 9
                        radius: 4.5
                        x: parent.width - 6
                        y: -3
                        color: Theme.tierMax
                        border.width: 2
                        border.color: Theme.chipFill
                        antialiasing: true

                        SequentialAnimation on scale {
                            running: tile.attention
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: area
                        // A little bigger than the icon so it's easy to hit
                        // (half the gap on each side, so tiles never overlap).
                        anchors.fill: parent
                        anchors.margins: -root.iconGap / 2 + 1
                        enabled: !tile.leaving
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => root.itemClicked(tile.modelData, mouse.button, tile)
                        onWheel: wheel => {
                            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                            const d = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
                            if (!root.scrollEnabled || d === 0) {
                                wheel.accepted = false
                                return
                            }
                            root.itemScrolled(tile.modelData, d, horizontal)
                        }
                    }
                }
            }
        }

        Item {
            id: toggleCell
            opacity: root.showToggle ? 1 : 0
            enabled: root.showToggle
            width: root.toggleSize
            height: root.toggleSize
            x: root.vertical
                ? (clipper.width - width) / 2
                : clipper.width - root.padX - width
            y: root.vertical
                ? clipper.height - root.padY - height
                : (clipper.height - height) / 2

            property real lift: toggleArea.pressed ? 0.85 : ((toggleArea.containsMouse || root.toggleOpen) ? 1.12 : 1.0)
            Behavior on lift {
                enabled: root.animated
                NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }
            scale: lift

            Item {
                anchors.centerIn: parent
                width: 28
                height: 28
                rotation: root.glyphRotation

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "arrow_drop_down"
                    size: 28
                    fill: 1
                    color: Theme.chipInk
                    rotation: root.toggleOpen ? 180 : 0
                    Behavior on rotation {
                        enabled: root.animated
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                visible: root.toggleAttention
                width: 9
                height: 9
                radius: 4.5
                x: parent.width - 6
                y: -3
                color: Theme.tierMax
                border.width: 2
                border.color: Theme.chipFill
                antialiasing: true

                SequentialAnimation on scale {
                    running: root.toggleAttention
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                anchors.margins: -root.iconGap / 2 + 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
        }
    }
}
