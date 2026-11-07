import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

// One button of the Quick Panel, drawn natively on Pill.qml from the
// Figma frames (Wi-Fi ON / Bluetooth OFF / Keep Awake ON Button Min /
// Power OFF Hover / Unhover ...), so it presses exactly like the
// workspace badges and the media pill: it pushes down onto its own hard
// shadow on mouse-down and springs back on release.
//
// Pure UI (no Quickshell imports): QuickPanelFace.qml feeds it state
// through plain properties and turns clicked() into an action.
//
//   kind: "wide"    200x73 pill (or `wideWidth`), icon + two lines of text (Wi-Fi, ...)
//         "round"   74x73 icon-only pill (Keep Awake, Notifications)
//         "square"  73x73, corner radius 30 (Edit, Power in the header)
//
// The two looks, straight from Figma:
//   OFF  white, 3px outline, shadow 3px right / 1px down
//   ON   cyan-mint gradient inside a 9px white ring, 5px outline,
//        shadow 5px right / 2px down
// Switching between them slides everything from one to the other rather
// than snapping. For the header buttons, hoverLights makes hovering show
// the ON look (the "Hover" frames) without changing `on`.
//
// `on` is a live reflection of the real state (owned by QuickSource), so
// when it flips without a click — a mute key, another app toggling
// Bluetooth — the button pulses by itself, the same trick the workspace
// badges, tray button and media pill use.
Item {
    id: root

    property string kind: "wide"
    property real wideWidth: 200
    property real roundWidth: 74
    property bool on: false
    property bool hoverLights: false
    property string label: ""
    property string subtitle: ""
    property string icon: ""
    property bool iconFilled: false

    // Locks the cap's border/ring/shadow at the same magnitude as the
    // ON look (see shadowLitP below) without touching the ON look's
    // other half — the gradient fill, which still only shows once
    // litP itself says lit. Used by pills that don't have a real
    // on/off state (the Power menu's action rail) but should still
    // read as raised further off the surface, like a lit or hovered
    // tile does.
    property bool elevated: false

    property bool hoverElevates: false
    property real hoverShadowExtraX: 6
    property real hoverShadowExtraY: 4

    // Which side of the cap stays put while the other does the moving.
    // false (everywhere but the Power rail): pinned to the left, same as
    // it's always been — the cap's own left edge never moves, growth
    // (the OFF->ON shadow, and hoverElevates on top of it) all spills
    // out to the right. true (the Power rail, see PowerMenu.qml): pinned
    // to the right instead, so a pill popping out — bigger shadow, bigger
    // cap — grows to the left, toward the phone it spilled out of,
    // rather than further out over open space.
    property bool anchorRight: false

    property bool flatShadow: false

    signal clicked()

    signal rightClicked()

    readonly property bool hovered: area.containsMouse
    readonly property bool lit: on || (hoverLights && hovered)

    readonly property color inkNow: Qt.tint(Theme.classicFor(root) ? Theme.pInk : Theme.ink, Qt.rgba(Theme.inkOnAccent.r, Theme.inkOnAccent.g, Theme.inkOnAccent.b, litP))
    readonly property color inkSubNow: Qt.rgba(inkNow.r, inkNow.g, inkNow.b, 0.667)

    property real litP: lit ? 1 : 0
    Behavior on litP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    readonly property real capW: kind === "wide" ? wideWidth : roundWidth - 1 + litP
    readonly property real capH: 73

    property real lineHeightPx: 0
    readonly property real titleLine: 20
    readonly property real subLine: 17

    // Drives border/ring/shadow only. Normally just litP, but `elevated`
    // floors it at the ON magnitude — the container is already sized for
    // litP's max (see implicitWidth/Height below), so this never grows
    // past what they account for.
    readonly property real shadowLitP: elevated ? Math.max(litP, 1) : litP

    property real hoverBoostP: (hoverElevates && hovered) ? 1 : 0
    Behavior on hoverBoostP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: (kind === "wide" ? wideWidth : roundWidth) + 5
    implicitHeight: flatShadow ? 77 : 75

    property bool keyPulse: false
    property bool suppressPulse: false

    onOnChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600
        onTriggered: root.suppressPulse = false
    }

    Pill {
        id: cap
        anchors.left: root.anchorRight ? undefined : parent.left
        anchors.right: root.anchorRight ? parent.right : undefined
        anchors.bottom: parent.bottom

        width: root.capW + shadowDx
        height: root.capH + shadowDy

        cornerRadius: root.kind === "square" ? 30 : 40
        borderWidth: 3 + 2 * root.shadowLitP
        ringWidth: 3 + 11 * root.shadowLitP
        shadowDx: root.flatShadow ? 0 : 3 + 2 * root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraX
        shadowDy: root.flatShadow ? 3 + root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraY
                                  : 1 + root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraY

        pressed: area.pressed || root.keyPulse

        // The white base is Pill's own default fillColor (Theme.colBg) —
        // always there, nothing drawn over it. This gradient is the ON
        // look, fading IN on top as the button lights up, rather than a
        // white sheet fading OUT over an always-on gradient underneath,
        // which is how this used to work: OFF pills — litP 0 — used
        // to show a thin ring of the gradient color around their edge
        // even at rest: two opaque, identically-shaped rounded rects
        // stacked on top of each other don't fully cancel at their
        // antialiased edge, since each one's own edge softening lets a
        // little of what's beneath it show through, and stacking two
        // of those compounds rather than hiding it. A single layer that
        // simply isn't drawn at all when litP is 0 doesn't have that
        // problem — there's nothing there to leak.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            opacity: root.litP
            antialiasing: true
        }

        // Everything below is positioned in the cap's own coordinates
        // (top-left of the outline), which is why this box is pulled out
        // by the ring width — `fill`, where children of a Pill land, is
        // inset by it.
        Item {
            id: capBox
            x: -cap.ringWidth
            y: -cap.ringWidth
            width: cap.capWidth
            height: cap.capHeight

            MaterialIcon {
                id: glyph
                size: 24
                x: root.kind === "wide" ? 28 - 8 * root.litP : (parent.width - width) / 2
                y: (parent.height - height) / 2
                name: root.icon
                fill: root.iconFilled ? 1 : Theme.iconFill
                color: root.inkNow
            }

            Column {
                visible: root.kind === "wide"
                x: 62 - 8 * root.litP
                width: root.wideWidth - 73
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.label
                    color: root.inkNow
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    lineHeight: root.lineHeightPx > 0 ? root.lineHeightPx : root.titleLine
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.subtitle
                    color: root.inkSubNow
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Normal
                    lineHeight: root.lineHeightPx > 0 ? root.lineHeightPx : root.subLine
                    lineHeightMode: Text.FixedHeight
                }
            }
        }
    }

    // Deliberately a sibling of the Pill, not inside it (same reason as
    // the workspace badges and tray button): the cap moves while
    // pressed, and a MouseArea riding along with it would slide out from
    // under a click on the button's edge. This one never moves.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                return
            root.suppressPulse = true
        }
        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                return
            suppressGrace.restart()
        }
        onCanceled: {
            suppressGrace.restart()
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked()
                return
            }
            root.clicked()
        }
    }
}
