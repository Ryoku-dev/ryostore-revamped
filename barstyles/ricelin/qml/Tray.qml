pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import shell.services as Shell
import shell.barkit as BarKit
import "Singletons"

// The daemon owns SNI registration and removal, as it does for Obi and Nacre.
// Render its current frame instead of retaining dead QML items or blacklisting
// application IDs (which would also hide a restarted instance of the app).
Item {
    id: tray

    property real s: 1
    property var barWindow

    /**
     * Tray folding. The tray starts folded behind an arrow button; clicking the
     * arrow slides the icons out inline. It folds again on another arrow click,
     * or once the pointer has stayed off the tray for `autoFoldMs`. Clicking an
     * icon never folds it, and neither does an open tray menu.
     */
    property bool expanded: false
    property int autoFoldMs: 3000

    /** 0 = folded, 1 = fully out. Drives the width, fade and arrow rotation together. */
    property real reveal: expanded ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Motion.morph
            easing.type: Motion.easeMorph
            easing.bezierCurve: Motion.morphCurve
        }
    }

    readonly property real arrowW: 20 * tray.s
    readonly property real gap: 4 * tray.s
    /**
     * Context-menu hold. A tray menu is its own popup surface, so the moment it
     * opens the pointer leaves the pill and the pill would drop back to its rest
     * form. `menuHeld` tells the pill to stay expanded while a menu is up.
     *
     * It is set by the right-click itself, and released when the menu reports it
     * closed (watched below, only on a real open -> close transition), when the
     * pointer comes back to the pill, or after `menuHoldMs` as a last resort.
     */
    property bool menuPending: false
    property int menuHoldMs: 10000
    property bool menuSeenOpen: false
    readonly property bool menuHeld: menuPending

    function holdForMenu() {
        menuSeenOpen = false;
        menuPending = true;
        pendingTimer.restart();
    }

    function releaseMenu() {
        menuPending = false;
        menuSeenOpen = false;
        pendingTimer.stop();
    }

    Timer {
        id: pendingTimer
        interval: tray.menuHoldMs
        onTriggered: tray.releaseMenu()
    }

    // Whatever this menu type calls "closed". Unknown signals are ignored, and a
    // `visible` that never changes (always true) never counts as a transition.
    Connections {
        target: trayMenu
        ignoreUnknownSignals: true
        function onVisibleChanged() { tray.menuStateChanged(trayMenu.visible); }
        function onOpenedChanged() { tray.menuStateChanged(trayMenu.opened); }
        function onClosed() { if (tray.menuPending) tray.releaseMenu(); }
        function onMenuClosed() { if (tray.menuPending) tray.releaseMenu(); }
    }

    function menuStateChanged(open) {
        if (open === true)
            menuSeenOpen = true;
        else if (menuSeenOpen && menuPending)
            releaseMenu();
    }

    // The pill leaving its expanded form (rest, a surface, osd...) puts the tray
    // away with it; if a menu is holding the pill open, wait for the menu.
    onEnabledChanged: if (!enabled && !menuHeld) expanded = false
    onMenuHeldChanged: if (!menuHeld && !enabled) expanded = false

    visible: Shell.Tray.items.length > 0
    implicitWidth: visible ? arrowW + reveal * (row.implicitWidth + gap) : 0
    implicitHeight: 24 * tray.s

    function itemSource(item) {
        if (item.iconPath)
            return item.iconPath.indexOf("/") === 0 ? "file://" + item.iconPath : item.iconPath;
        return Quickshell.iconPath(item.iconName || "application-x-executable-symbolic", true);
    }

    HoverHandler {
        id: trayHover
        // Pointer back on the tray means any earlier menu is gone.
        onHoveredChanged: if (hovered && tray.menuPending) tray.releaseMenu()
    }

    Timer {
        interval: tray.autoFoldMs
        running: tray.expanded && !trayHover.hovered && !tray.menuHeld
        onTriggered: tray.expanded = false
    }

    // The arrow: a quiet chevron button in the same frame style as the icons.
    Item {
        id: arrowBtn
        width: tray.arrowW
        height: 24 * tray.s
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: 6 * tray.s
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.frameBorder
            opacity: arrowArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        GlyphIcon {
            id: chevron
            anchors.centerIn: parent
            width: 14 * tray.s
            height: 14 * tray.s
            name: "chevron-right"
            stroke: 2
            color: arrowArea.containsMouse ? Theme.cream : Theme.subtle
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            // Turns around as the tray comes out; on hover it leans a hair in
            // the direction it will move, like a page about to turn.
            rotation: 180 * tray.reveal
            transform: Translate {
                x: arrowArea.containsMouse ? (tray.expanded ? -1.5 : 1.5) * tray.s : 0
                Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            }
        }

        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tray.expanded = !tray.expanded
        }

        Tooltip {
            s: tray.s
            placement: "below"
            title: tray.expanded ? "Hide tray" : "Show tray"
            show: arrowArea.containsMouse
        }
    }

    // The icons. Wiped out from the arrow's right edge. Clipping only while the
    // reveal is moving, so the per-icon tooltips are never cut off at rest.
    Item {
        id: iconsClip
        x: tray.arrowW + tray.gap * tray.reveal
        width: tray.reveal * row.implicitWidth
        height: parent.height
        visible: tray.reveal > 0.001
        opacity: Math.min(1, tray.reveal * 1.6)
        clip: tray.reveal > 0.001 && tray.reveal < 0.999

        RowLayout {
            id: row
            x: -(1 - tray.reveal) * 8 * tray.s
            height: parent.height
            spacing: 2 * tray.s

            Repeater {
                model: Shell.Tray.items

                delegate: Item {
                    id: slot
                    required property var modelData

                    Layout.preferredWidth: 24 * tray.s
                    Layout.preferredHeight: 24 * tray.s

                    Rectangle {
                        anchors.fill: parent
                        radius: 6 * tray.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder
                        opacity: area.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    Image {
                        anchors.centerIn: parent
                        source: tray.itemSource(slot.modelData)
                        sourceSize.width: 32
                        sourceSize.height: 32
                        width: 16 * tray.s
                        height: 16 * tray.s
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            const item = slot.modelData;
                            const point = slot.mapToGlobal(0, slot.height);
                            if (event.button === Qt.RightButton || item.itemIsMenu) {
                                tray.holdForMenu();
                                if (item.menu)
                                    trayMenu.openFor(item, slot);
                                else
                                    Shell.Tray.contextMenu(item.service, Math.round(point.x), Math.round(point.y));
                            } else {
                                Shell.Tray.activate(item.service, Math.round(point.x), Math.round(point.y));
                            }
                        }
                        onWheel: wheel => Shell.Tray.scroll(slot.modelData.service, wheel.angleDelta.y, "vertical")
                    }

                    Tooltip {
                        s: tray.s
                        placement: "below"
                        title: (slot.modelData.tooltip && slot.modelData.tooltip.title) || slot.modelData.title || slot.modelData.id
                        show: area.containsMouse
                    }
                }
            }
        }

    }

    BarKit.TrayMenu {
        id: trayMenu
        edge: "top"
    }
}
