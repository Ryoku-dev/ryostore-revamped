import QtQuick
import QtQuick.Effects
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

Item {
    id: root

    property bool vertical: false
    property string barPosition: "top"
    property bool allowed: true

    property bool inCall: false
    property bool needsAuth: false
    property bool authorizing: false
    property string channelName: ""
    property var participants: []
    property bool muted: false
    property bool deafened: false

    property bool leftOpensPanel: true
    property bool panelOpen: false

    signal muteRequested()
    signal deafenRequested()
    signal authorizeRequested()
    signal panelRequested()

    readonly property color blurple: "#5865f2"
    readonly property color danger: "#ed4245"

    readonly property bool live: allowed && (inCall || needsAuth)

    property real reveal: live ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.55 + 0.45 * reveal

    property var shownParticipants: []
    property string shownChannel: ""
    property bool shownAuth: false
    function refreshShown() {
        if (inCall) {
            shownParticipants = participants
            shownChannel = channelName
            shownAuth = false
        } else if (needsAuth) {
            shownAuth = true
        }
    }
    onParticipantsChanged: refreshShown()
    onChannelNameChanged: refreshShown()
    onNeedsAuthChanged: refreshShown()
    onInCallChanged: refreshShown()
    Component.onCompleted: refreshShown()

    readonly property int avatarCount: Math.min(3, shownParticipants.length)
    readonly property int avatarSize: root.vertical ? 24 : 20
    readonly property int avatarStep: root.vertical ? 16 : 13
    readonly property real stackWidth: avatarCount > 0
        ? avatarSize + (avatarCount - 1) * avatarStep + 4 : avatarSize

    readonly property string countText: shownParticipants.length === 1 ? "1" : String(shownParticipants.length)
    readonly property string labelText: shownAuth
        ? (authorizing ? "Waiting for Discord…" : "Link Discord")
        : (shownChannel !== "" ? shownChannel : "Voice") + " · " + countText

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: avatarMask
        width: root.avatarSize - 4
        height: width
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: vertical ? 6 : 8
        capKeepsFill: true
        fillColor: root.blurple
        pressed: area.pressed || (root.panelOpen && !root.shownAuth)

        implicitWidth: root.vertical ? pill.barVWidth
                                     : row.implicitWidth + 2 * ringWidth + 14
        implicitHeight: root.vertical ? col.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
                                      : Theme.pillHeight + Theme.shadowOffset

        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 7

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: root.shownAuth ? glyphComp : stackComp
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                text: root.labelText
                elide: Text.ElideRight
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: !root.shownAuth
                visible: active
                sourceComponent: badgeComp
            }
        }

        Column {
            id: col
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 4

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: root.shownAuth ? glyphComp : (root.avatarCount > 0 ? soloComp : glyphComp)
            }

            Text {
                visible: !root.shownAuth
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.countText
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                active: !root.shownAuth
                visible: active
                sourceComponent: badgeComp
            }
        }
    }

    Component {
        id: glyphComp
        MaterialIcon {
            name: "headset"
            size: 18
            color: Theme.textWhite
        }
    }

    Component {
        id: stackComp
        Item {
            width: root.stackWidth
            height: root.avatarSize

            Repeater {
                model: root.avatarCount

                delegate: Avatar {
                    required property int index
                    user: root.shownParticipants[index]
                    base: root.blurple
                    diameter: root.avatarSize
                    mask: avatarMask
                    x: index * root.avatarStep
                    z: index
                }
            }
        }
    }

    Component {
        id: soloComp
        Item {
            width: root.avatarSize
            height: root.avatarSize
            readonly property var who: {
                const list = root.shownParticipants
                const talker = list.find(p => p && p.speaking === true)
                return talker || list[0]
            }
            Avatar {
                user: parent.who
                base: root.blurple
                diameter: root.avatarSize
                mask: avatarMask
            }
        }
    }

    Component {
        id: badgeComp
        MaterialIcon {
            name: root.deafened ? "headset_off" : (root.muted ? "mic_off" : "mic")
            size: 18
            color: Theme.textWhite
            opacity: root.muted || root.deafened ? 1 : 0.8
        }
    }

    // One avatar in a ring: lit white while this person is talking, the
    // pill's own colour otherwise (so it reads as a gap between neighbours).
    // (An inline component does not see this file's ids, so everything it
    // needs comes in as a property.)
    component Avatar: Item {
        id: av
        property var user: null
        property color base: "#5865f2"
        property real diameter: 24
        property Item mask: null
        readonly property bool talking: user ? user.speaking === true : false
        width: diameter
        height: diameter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: av.base
            border.width: 2
            border.color: av.talking ? Theme.textWhite : av.base
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: av.diameter - 4
            height: width
            radius: width / 2
            color: Qt.lighter(av.base, 1.3)
            visible: img.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: av.user ? String(av.user.nick || "?").charAt(0).toUpperCase() : "?"
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        Image {
            id: img
            anchors.centerIn: parent
            width: av.diameter - 4
            height: width
            source: DiscordVoiceService.avatarUrl(av.user, 64)
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: img
            source: img
            visible: img.status === Image.Ready
            maskEnabled: av.mask !== null
            maskSource: av.mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (root.shownAuth)
                root.authorizeRequested()
            else if (mouse.button === Qt.RightButton)
                root.deafenRequested()
            else if (mouse.button === Qt.MiddleButton)
                root.muteRequested()
            else if (root.leftOpensPanel)
                root.panelRequested()
            else
                root.muteRequested()
        }
    }

    readonly property string tipText: {
        if (root.shownAuth)
            return root.authorizing ? "Accept the request in Discord" : "Link Discord once to see your calls here"
        const lines = [(root.shownChannel !== "" ? root.shownChannel : "Voice channel")
            + " — " + root.shownParticipants.length + " in call"]
        for (const p of root.shownParticipants.slice(0, 8)) {
            if (!p)
                continue
            const state = p.deaf === true ? " (deafened)" : (p.mute === true ? " (muted)" : "")
            lines.push((p.speaking === true ? "● " : "   ") + (p.nick || "?") + state)
        }
        if (root.shownParticipants.length > 8)
            lines.push("   +" + (root.shownParticipants.length - 8) + " more")
        const muteWord = root.muted ? "unmute" : "mute"
        const deafWord = root.deafened ? "undeafen" : "deafen"
        lines.push(root.leftOpensPanel
            ? "Click: open · Middle: " + muteWord + " · Right: " + deafWord
            : "Click: " + muteWord + " · Right-click: " + deafWord)
        return lines.join("\n")
    }

    BarTip {
        shown: area.containsMouse && !root.panelOpen
        text: root.tipText
        barPosition: root.barPosition
    }
}
