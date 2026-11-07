pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Blobs as Blobs
import Ryoku.Ui.Singletons as Ui
import shell.services as Ryoku
import shell.modules.stage.frame as Stage
import shell.barkit as BarKit

Scope {
    id: root

    property var modelData: null

    readonly property real frameBorderPx: Ryoku.Config.frameThickness
    readonly property real uiScale: Ui.Tokens.uiScaleFor(
        root.modelData ? root.modelData.name : "")
    readonly property bool barEnabled: Ui.Tokens.barEnabledFor(
        root.modelData ? root.modelData.name : "")
    readonly property var state: root.modelData
        ? Ryoku.ShellState.forScreen(root.modelData) : null
    readonly property bool revealed: root.state ? root.state.barRevealed : true

    function runBarAction(id) {
        switch (id) {
        case "lock": Ui.Spawn.run(["ryoku-shell", "lock"]); break;
        case "logout":
        case "reboot":
        case "shutdown":
            Ryoku.ShellState.askSessionAction(
                id, root.modelData ? root.modelData.name : "");
            break;
        case "screenshot": Ui.Spawn.run(["ryoku-cmd-ryoshot"]); break;
        case "wallpaper": Ui.Spawn.run(["ryogami", "wallpaper", "ui"]); break;
        case "color-picker": Ui.Spawn.run(["ryoku-cmd-color-picker"]); break;
        case "app-launcher":
            if (root.state)
                root.state.launcherOpen = !root.state.launcherOpen;
            break;
        default: return;
        }
    }

    function edgeRevealed(edge) {
        if (!root.revealed)
            return false;
        const rail = Ryoku.Config.normalizedFrameBars.rails[edge];
        return !!(rail && rail.reveal);
    }

    function edgeDrawRevealed(edge) {
        const screenName = root.modelData ? root.modelData.name : "";
        if (!Stage.StageFrame.framing(screenName))
            return root.edgeRevealed(edge);
        const rail = Ryoku.Config.normalizedFrameBars.rails[edge];
        return !!(rail && rail.reveal);
    }

    function edgeDrawReserve(edge) {
        if (!root.barEnabled)
            return 0;
        const rail = Ryoku.Config.normalizedFrameBars.rails[edge];
        if (!rail)
            return 0;
        if (!root.edgeDrawRevealed(edge))
            return 1;
        return ((rail.enabled && root.railHasWidgets(rail, edge))
            ? rail.size * root.uiScale : 1) + root.frameBorderPx;
    }

    function railHasWidgets(rail, edge) {
        if (!rail)
            return false;
        const zones = edge === "top" || edge === "bottom"
            ? ["start", "center", "end"] : ["top", "center", "bottom"];
        for (let i = 0; i < zones.length; ++i)
            if (Array.isArray(rail[zones[i]]) && rail[zones[i]].length > 0)
                return true;
        return false;
    }

    function edgeReserve(edge) {
        if (!root.barEnabled)
            return 0;
        const rail = Ryoku.Config.normalizedFrameBars.rails[edge];
        if (!rail)
            return 0;
        if (!root.edgeRevealed(edge))
            return 1;
        return ((rail.enabled && root.railHasWidgets(rail, edge))
            ? rail.size * root.uiScale : 1) + root.frameBorderPx;
    }

    function edgeRect(edge, thickness, width, height) {
        if (edge === "top")
            return { x: 0, y: 0, width: width, height: thickness };
        if (edge === "bottom")
            return { x: 0, y: height - thickness, width: width, height: thickness };
        if (edge === "left")
            return { x: 0, y: 0, width: thickness, height: height };
        if (edge === "right")
            return { x: width - thickness, y: 0, width: thickness, height: height };
        return { x: 0, y: 0, width: 0, height: 0 };
    }

    readonly property var sidebarRailClearances: !root.barEnabled ? ({
        top: 0, left: 0, bottom: 0, right: 0
    }) : ({
        top: overlay.railClearance("top"),
        left: overlay.railClearance("left"),
        bottom: overlay.railClearance("bottom"),
        right: overlay.railClearance("right")
    })

    function syncSidebarRailClearances() {
        if (root.modelData)
            Ryoku.SidebarState.setRailClearances(
                root.modelData, root.sidebarRailClearances);
    }

    onSidebarRailClearancesChanged: root.syncSidebarRailClearances()
    Component.onCompleted: {
        Ryoku.Shells.activeBarEdge = "top";
        Qt.callLater(root.syncSidebarRailClearances);
    }

    Scope {
        BarKit.FrameEdge {
            edge: "top"
            screen: root.modelData
            reserve: root.edgeReserve("top")
        }
        BarKit.FrameEdge {
            edge: "bottom"
            screen: root.modelData
            reserve: root.edgeReserve("bottom")
        }
        BarKit.FrameEdge {
            edge: "left"
            screen: root.modelData
            reserve: root.edgeReserve("left")
        }
        BarKit.FrameEdge {
            edge: "right"
            screen: root.modelData
            reserve: root.edgeReserve("right")
        }
    }

    PanelWindow {
        id: overlay

        readonly property real s: Ryoku.Screens.monitorScale(
            root.modelData,
            Ui.Wm.outputScale(root.modelData ? root.modelData.name : ""))
            * Math.max(0.7, Math.min(1.6, Ryoku.Config.fontScale))
            * root.uiScale
        readonly property var frameBars: Ryoku.Config.normalizedFrameBars
        readonly property var rails: overlay.frameBars.rails
        readonly property real frameLip: root.frameBorderPx
        readonly property var edgeReveal: ({
            top: root.edgeDrawRevealed("top"),
            bottom: root.edgeDrawRevealed("bottom"),
            left: root.edgeDrawRevealed("left"),
            right: root.edgeDrawRevealed("right")
        })
        readonly property var topRailRect: root.edgeRect(
            "top", overlay.railThickness("top"), width, height)
        readonly property var leftRailRect: root.edgeRect(
            "left", overlay.railThickness("left"), width, height)
        readonly property var bottomRailRect: root.edgeRect(
            "bottom", overlay.railThickness("bottom"), width, height)
        readonly property var rightRailRect: root.edgeRect(
            "right", overlay.railThickness("right"), width, height)
        // The frame chrome is a full-output surface, so its framed layer keeps
        // the same extent and only maps the painted edges into the Stage card.
        function framedRect(rect) {
            return frameLayer.maskRect(rect.x, rect.y, rect.width, rect.height);
        }
        readonly property rect framedTopRailRect: overlay.framedRect(overlay.topRailRect)
        readonly property rect framedLeftRailRect: overlay.framedRect(overlay.leftRailRect)
        readonly property rect framedBottomRailRect: overlay.framedRect(overlay.bottomRailRect)
        readonly property rect framedRightRailRect: overlay.framedRect(overlay.rightRailRect)
        readonly property rect framedTopHoverRect: frameLayer.maskRect(0, 0, overlay.width, 1)
        readonly property rect framedBottomHoverRect: frameLayer.maskRect(0, overlay.height - 1, overlay.width, 1)
        readonly property rect framedLeftHoverRect: frameLayer.maskRect(0, 0, 1, overlay.height)
        readonly property rect framedRightHoverRect: frameLayer.maskRect(overlay.width - 1, 0, 1, overlay.height)
        function railRecord(edge) { return overlay.rails[edge] || ({ size: 0, enabled: false }); }
        function railThickness(edge) { return Math.max(0, root.edgeDrawReserve(edge) - root.frameBorderPx); }
        function railEnabled(edge) {
            return root.barEnabled && overlay.railRecord(edge).enabled === true;
        }
        // Clearance from the screen edge to the inside of each rail, per edge: the
        // reserve when the edge carries a bar, else the frame lip. Feeds the menu
        // manager (bodies clear their own rail) and the record island's dock.
        function railClearance(edge) {
            const reserve = root.edgeReserve(edge);
            return reserve > 0 ? reserve : overlay.frameLip;
        }

        // Right-edge input reserve: a 2px sliver (the hidden-bar trick) so the
        // frame reveals on hover there without the region eating clicks; off
        // while a fullscreen window owns the monitor.
        readonly property bool rightDropOn: !overlay.monFullscreen
        readonly property real rightDropW: Math.max(root.edgeReserve("right"), 2)

        // True when this monitor's active workspace holds a fullscreen window;
        // the frame then unmaps its input and hides so the window is unobstructed.
        readonly property bool monFullscreen: Ui.Wm.outputHasFullscreen(
            root.modelData ? root.modelData.name : "")

        onMonFullscreenChanged: if (monFullscreen) frameMenus.closeAll()

        screen: root.modelData
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: frameMenus.keyboardMode === "exclusive" ? WlrKeyboardFocus.Exclusive
            : frameMenus.keyboardMode === "ondemand" ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-frame"
        anchors { top: true; left: true; right: true; bottom: true }

        // Input catches the drawn rails and their 1px hover strips, plus every
        // open menu's trigger and body, the record island, and the right-edge
        // stash drop strip; everything else clicks through to the desktop. A
        // dragging island or any visible menu widens the mask to the whole
        // surface so the pointer never slips off its rect mid-interaction.
        mask: overlay.monFullscreen ? hiddenRegion
            : frameMenus.anyVisible ? fullRegion
            : railRegion

        Region { id: hiddenRegion }
        Region {
            id: fullRegion
            width: overlay.width
            height: overlay.height
        }
        Region {
            id: railRegion
            Region { x: overlay.framedTopRailRect.x; y: overlay.framedTopRailRect.y; width: overlay.railEnabled("top") ? overlay.framedTopRailRect.width : 0; height: overlay.railEnabled("top") ? overlay.framedTopRailRect.height : 0 }
            Region { x: overlay.framedLeftRailRect.x; y: overlay.framedLeftRailRect.y; width: overlay.railEnabled("left") ? overlay.framedLeftRailRect.width : 0; height: overlay.railEnabled("left") ? overlay.framedLeftRailRect.height : 0 }
            Region { x: overlay.framedBottomRailRect.x; y: overlay.framedBottomRailRect.y; width: overlay.railEnabled("bottom") ? overlay.framedBottomRailRect.width : 0; height: overlay.railEnabled("bottom") ? overlay.framedBottomRailRect.height : 0 }
            Region { x: overlay.framedRightRailRect.x; y: overlay.framedRightRailRect.y; width: overlay.railEnabled("right") ? overlay.framedRightRailRect.width : 0; height: overlay.railEnabled("right") ? overlay.framedRightRailRect.height : 0 }
            // The reveal lips follow the card too; leaving them at the physical
            // edge makes a hidden rail impossible to reach in the editor.
            Region { x: overlay.framedTopHoverRect.x; y: overlay.framedTopHoverRect.y; width: overlay.railEnabled("top") ? overlay.framedTopHoverRect.width : 0; height: overlay.railEnabled("top") ? overlay.framedTopHoverRect.height : 0 }
            Region { x: overlay.framedBottomHoverRect.x; y: overlay.framedBottomHoverRect.y; width: overlay.railEnabled("bottom") ? overlay.framedBottomHoverRect.width : 0; height: overlay.railEnabled("bottom") ? overlay.framedBottomHoverRect.height : 0 }
            Region { x: overlay.framedLeftHoverRect.x; y: overlay.framedLeftHoverRect.y; width: overlay.railEnabled("left") ? overlay.framedLeftHoverRect.width : 0; height: overlay.railEnabled("left") ? overlay.framedLeftHoverRect.height : 0 }
            Region { x: overlay.framedRightHoverRect.x; y: overlay.framedRightHoverRect.y; width: overlay.railEnabled("right") ? overlay.framedRightHoverRect.width : 0; height: overlay.railEnabled("right") ? overlay.framedRightHoverRect.height : 0 }
            // frame menus: each open menu unions its trigger (owner) and body
            // rects so the click target and the open body keep catching input;
            // idle anchors stay zero-size and click through.
            Region { x: frameMenus.masks["top"].tx; y: frameMenus.masks["top"].ty; width: frameMenus.masks["top"].tw; height: frameMenus.masks["top"].th }
            Region { x: frameMenus.masks["top"].bx; y: frameMenus.masks["top"].by; width: frameMenus.masks["top"].bw; height: frameMenus.masks["top"].bh }
            Region { x: frameMenus.masks["top-left"].tx; y: frameMenus.masks["top-left"].ty; width: frameMenus.masks["top-left"].tw; height: frameMenus.masks["top-left"].th }
            Region { x: frameMenus.masks["top-left"].bx; y: frameMenus.masks["top-left"].by; width: frameMenus.masks["top-left"].bw; height: frameMenus.masks["top-left"].bh }
            Region { x: frameMenus.masks["top-right"].tx; y: frameMenus.masks["top-right"].ty; width: frameMenus.masks["top-right"].tw; height: frameMenus.masks["top-right"].th }
            Region { x: frameMenus.masks["top-right"].bx; y: frameMenus.masks["top-right"].by; width: frameMenus.masks["top-right"].bw; height: frameMenus.masks["top-right"].bh }
            Region { x: frameMenus.masks["left"].tx; y: frameMenus.masks["left"].ty; width: frameMenus.masks["left"].tw; height: frameMenus.masks["left"].th }
            Region { x: frameMenus.masks["left"].bx; y: frameMenus.masks["left"].by; width: frameMenus.masks["left"].bw; height: frameMenus.masks["left"].bh }
            Region { x: frameMenus.masks["right"].tx; y: frameMenus.masks["right"].ty; width: frameMenus.masks["right"].tw; height: frameMenus.masks["right"].th }
            Region { x: frameMenus.masks["right"].bx; y: frameMenus.masks["right"].by; width: frameMenus.masks["right"].bw; height: frameMenus.masks["right"].bh }
            Region { x: frameMenus.masks["bottom"].tx; y: frameMenus.masks["bottom"].ty; width: frameMenus.masks["bottom"].tw; height: frameMenus.masks["bottom"].th }
            Region { x: frameMenus.masks["bottom"].bx; y: frameMenus.masks["bottom"].by; width: frameMenus.masks["bottom"].bw; height: frameMenus.masks["bottom"].bh }
            Region { x: frameMenus.masks["bottom-left"].tx; y: frameMenus.masks["bottom-left"].ty; width: frameMenus.masks["bottom-left"].tw; height: frameMenus.masks["bottom-left"].th }
            Region { x: frameMenus.masks["bottom-left"].bx; y: frameMenus.masks["bottom-left"].by; width: frameMenus.masks["bottom-left"].bw; height: frameMenus.masks["bottom-left"].bh }
            Region { x: frameMenus.masks["bottom-right"].tx; y: frameMenus.masks["bottom-right"].ty; width: frameMenus.masks["bottom-right"].tw; height: frameMenus.masks["bottom-right"].th }
            Region { x: frameMenus.masks["bottom-right"].bx; y: frameMenus.masks["bottom-right"].by; width: frameMenus.masks["bottom-right"].bw; height: frameMenus.masks["bottom-right"].bh }
            // right edge stays masked so a file drag lands on the DropArea below.
            Region { x: overlay.width - overlay.rightDropW; y: 0; width: overlay.rightDropOn ? overlay.rightDropW : 0; height: overlay.rightDropOn ? overlay.height : 0 }
            // centred plugin popout: no edge anchor, so its body rides here.
            Region { x: frameMenus.pluginMask.x; y: frameMenus.pluginMask.y; width: frameMenus.pluginMask.w; height: frameMenus.pluginMask.h }
        }


        BarKit.FrameSurfaceLifecycle {
            id: surfaceLifecycle
            keyring: Ryoku.Keyring
            polkit: Ryoku.Polkit
            onFocusRestored: Ryoku.ShellState.restoreFocus()
        }

        // Outside-click closes whatever is open: a press that reaches the
        // backdrop, outside the bars and the open panel, dismisses. Presses on
        // rails and content never reach here; they hit the items above.
        MouseArea {
            anchors.fill: parent
            enabled: frameMenus.anyOpen
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                for (const a in frameMenus.masks) {
                    const m = frameMenus.masks[a];
                    if (!m) continue;
                    if (m.tw > 0 && mouse.x >= m.tx && mouse.x < m.tx + m.tw
                        && mouse.y >= m.ty && mouse.y < m.ty + m.th) return;
                    if (m.bw > 0 && mouse.x >= m.bx && mouse.x < m.bx + m.bw
                        && mouse.y >= m.by && mouse.y < m.by + m.bh) return;
                }
                if (mouse.x < root.edgeReserve("left") || mouse.y < root.edgeReserve("top")
                    || mouse.x >= overlay.width - root.edgeReserve("right")
                    || mouse.y >= overlay.height - root.edgeReserve("bottom"))
                    return;
                frameMenus.closeAll();
            }
        }

        FocusScope {
            id: focusScope
            anchors.fill: parent
            focus: frameMenus.anyOpen
            visible: !overlay.monFullscreen
            Keys.onEscapePressed: if (frameMenus.keyboardMode === "exclusive") frameMenus.closeAll()


            Blobs.BlobGroup {
                id: blobGroup
                color: Ryoku.Theme.surface
                borderWidth: 0
                smoothing: 0
                shadowStrength: 0
                shadowSize: 0
            }

            Loader {
                active: root.barEnabled
                sourceComponent: Rectangle {
                    x: frameMenus.chromePanel.x
                    y: frameMenus.chromePanel.y
                    width: frameMenus.chromePanel.w
                    height: frameMenus.chromePanel.h
                    radius: Math.min(
                        Ryoku.Config.frameCorner, width / 2, height / 2)
                    color: Ryoku.Theme.surface
                    border.width: Ryoku.Theme.borderWidth
                    border.color: Ryoku.Theme.outline
                    opacity: Ryoku.Theme.windowOpacity
                        * (frameMenus.chromeSide ? frameMenus.chromeOpacity : 1)
                    visible: !overlay.monFullscreen
                        && Ryoku.Config.frameEnabled
                        && width > 0 && height > 0
                }
            }

            Stage.StageFramedLayer {
                id: frameLayer
                interactive: false
                screenName: overlay.screen?.name ?? ""
                edge: "top"
                restThickness: overlay.screen?.height ?? 1080
                screenWidth: overlay.screen?.width ?? 1920
                screenHeight: overlay.screen?.height ?? 1080
            }

            Loader {
                parent: frameLayer.rest
                anchors.fill: parent
                active: root.barEnabled
                sourceComponent: Item {
                    BarKit.FrameChrome {
                        anchors.fill: parent
                        reserveTop: root.edgeDrawReserve("top")
                        reserveBottom: root.edgeDrawReserve("bottom")
                        reserveLeft: root.edgeDrawReserve("left")
                        reserveRight: root.edgeDrawReserve("right")
                        holeRadius: Ryoku.Config.frameCorner
                        surface: Ryoku.Theme.surface
                        outline: Ryoku.Theme.outline
                        strokeWidth: Ryoku.Theme.borderWidth
                        opacity: Ryoku.Theme.windowOpacity
                        visible: !overlay.monFullscreen
                            && Ryoku.Config.frameEnabled
                    }

                    BarKit.Bar {
                        anchors.fill: parent
                        z: 1
                        visible: !overlay.monFullscreen
                        railScale: root.uiScale
                        revealState: overlay.edgeReveal
                        frameBars: overlay.frameBars
                        style: ({ group: blobGroup })
                        onMenuRequested: (id, ownerRect) =>
                            frameMenus.openSurface(id, ownerRect, "")
                        onSurfaceRequested: (id, ownerRect) =>
                            frameMenus.openSurface(id, ownerRect, "")
                        onActionRequested: id => root.runBarAction(id)
                    }
                }
            }

            BarKit.FrameMenuManager {
                id: frameMenus
                z: 2
                monitorName: root.modelData ? root.modelData.name : ""
                scale: overlay.s
                group: blobGroup
                topBar: !root.barEnabled
                barEdge: Ryoku.Shells.activeBarEdge
                railClearances: root.sidebarRailClearances
                active: !overlay.monFullscreen
                onSurfaceClosed: (id, context) =>
                    surfaceLifecycle.handleClosed(id, context)

                Connections {
                    target: Ryoku.ShellState

                    function onSurfaceRequested(id, mon, ctx) {
                        if (mon !== ""
                            && mon !== (root.modelData ? root.modelData.name : ""))
                            return;
                        if (id === "wallpaper") {
                            Ui.Spawn.run(["ryogami", "wallpaper", "ui"]);
                            return;
                        }
                        const anchorRect = ctx && ctx.ownerRect
                            ? ctx.ownerRect : null;
                        frameMenus.openSurface(id, anchorRect, mon, ctx);
                    }
                    function onSurfaceClosed(id, mon) {
                        frameMenus.closeSurface(id, mon);
                    }
                    function onKeyringPromptChanged(pid) {
                        frameMenus.retireKeyringPrompt(pid);
                    }
                }
            }

            // No compositor focus grab here. A modal surface already takes the
            // layer's exclusive keyboard focus, and the compositor clears a grab
            // the moment that focus moves to the grabbing layer: the two together
            // closed every surface a few milliseconds after it opened. The mask
            // plus the backdrop press above dismisses a click outside, and Escape
            // closes through the FocusScope.

        }
    }

}
