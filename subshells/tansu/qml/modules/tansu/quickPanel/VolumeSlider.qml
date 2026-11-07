import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

// A draggable volume slider, sized to sit where a "wide" QuickToggle
// would (200px wide) — just a little taller, to fit a track under the
// label. There's no Figma frame for this one (a slider didn't exist in
// the mockup): sized to match its neighbors and drawn from the same
// pieces everything else here uses (Theme's colors, the progress-bar
// look ResourcePopup.qml already established), the same way the bar
// extras (resources/battery/keyboard layout) were fit in pragmatically
// rather than traced from a frame.
//
// Pure UI (no Quickshell imports): QuickPanelFace.qml feeds it `value`
// (0-100, the real system volume, from QuickSource.qml) and reads
// changes back out through `moved` while the user drags or taps the
// track. Clicking anywhere on the cap — not the track — is a separate
// click, wired to `iconClicked` (the existing mute toggle); it doesn't
// fight the drag. Right-clicking the cap is a third, separate signal
// (`rightClicked`) — QuickPanelFace wires it to VolumeMixerDialog.qml:
// a compact default-device dropdown plus a per-app volume mixer,
// rather than the plain device list Network/Bluetooth get.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property bool muted: false
    property real value: 0

    property bool simple: false

    property real sliderWidth: 200

    signal moved(real value)
    signal iconClicked()
    signal rightClicked()

    implicitWidth: sliderWidth
    implicitHeight: root.simple ? 56 : 97

    property bool flatShadow: false

    property bool dragging: false
    property real dragValue: 0
    readonly property real shownValue: dragging ? dragValue : value

    property real litP: root.muted ? 0 : 1

    readonly property color inkNow: root.simple
        ? Theme.pInk
        : Qt.tint(Theme.pInk, Qt.rgba(Theme.inkOnAccent.r, Theme.inkOnAccent.g, Theme.inkOnAccent.b, litP))
    readonly property color inkSubNow: Qt.rgba(inkNow.r, inkNow.g, inkNow.b, 0.667)
    Behavior on litP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    property bool keyPulse: false
    property bool suppressPulse: false

    onMutedChanged: {
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
        visible: !root.simple
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.sliderWidth + shadowDx
        height: 73 + shadowDy
        cornerRadius: 40
        borderWidth: 3 + 2 * root.litP
        ringWidth: 3 + 11 * root.litP
        shadowDx: root.flatShadow ? 0 : 3 + 2 * root.litP
        shadowDy: root.flatShadow ? 3 + root.litP : 1 + root.litP

        pressed: buttonArea.pressed || root.keyPulse

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

        Item {
            id: capBox
            x: -cap.ringWidth
            y: -cap.ringWidth
            width: cap.capWidth
            height: cap.capHeight

            MaterialIcon {
                color: root.inkNow
                id: glyph
                x: 20
                size: 24
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                opacity: root.muted ? 0.4 : 1
            }

            Text {
                id: nameLabel
                anchors.left: glyph.right
                anchors.leftMargin: 12
                anchors.right: pctLabel.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.label
                color: root.muted ? Theme.pInkSub : root.inkNow
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                id: pctLabel
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.muted ? "MUTE" : Math.round(root.shownValue) + "%"
                color: root.inkSubNow
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }
    }

    // simple: true's whole header — just the icon, the label, and the
    // current value, sitting where the Pill button would otherwise be.
    // No fill/border/shadow, no press state, nothing clickable: there's
    // nothing for a click here to do, so it doesn't invite one. It only
    // exists to name the slider underneath it.
    Item {
        visible: root.simple
        x: 0
        y: 0
        width: root.sliderWidth
        height: 32

        MaterialIcon {
            color: root.inkNow
            id: simpleGlyph
            x: 20
            size: 24
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
        }

        Text {
            anchors.left: simpleGlyph.right
            anchors.leftMargin: 12
            anchors.right: simplePct.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.label
            color: root.inkNow
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            id: simplePct
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.shownValue) + "%"
            color: root.inkSubNow
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    MouseArea {
        id: buttonArea
        visible: !root.simple
        enabled: !root.simple
        x: 0
        y: 0
        width: root.sliderWidth + 5
        height: 75
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.suppressPulse = true
        }
        onReleased: mouse => {
            if (mouse.button === Qt.LeftButton)
                suppressGrace.restart()
        }
        onCanceled: suppressGrace.restart()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.iconClicked()
        }
    }

    Rectangle {
        id: track
        x: 20
        y: root.simple ? (32 + 10) : (73 + 2 + 8)
        width: parent.width - 40
        height: 14
        radius: 7
        color: Theme.pSurfaceDivider

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.shownValue / 100))
            height: parent.height
            radius: 7
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.muted ? Theme.pInkSub : Theme.accentMint }
                GradientStop { position: 1.0; color: root.muted ? Theme.pInkSub : Theme.accentCyan }
            }
            opacity: root.muted ? 0.5 : 1
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation {
                    duration: 150
                }
            }
            antialiasing: true
        }

        MouseArea {
            id: trackArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFromX(mx) {
                const p = Math.max(0, Math.min(1, mx / track.width))
                root.dragValue = p * 100
                root.moved(root.dragValue)
                PanelActivity.touch()
            }

            onPressed: mouse => {
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: root.dragging = false
            onCanceled: root.dragging = false
        }
        antialiasing: true
    }
}
