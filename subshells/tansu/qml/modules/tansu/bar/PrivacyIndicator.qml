import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

// The privacy pill: appears on the bar while the microphone is live or the
// screen is being shared. Pure UI: Bar.qml feeds it PrivacyService's state.
//
//   [ mic ] [ screen ]
//
// Only the icons are on the bar, so nothing about what you are doing is
// readable at a glance by someone looking at your screen. The icons that apply
// light up in the warning pink; hover the pill to see the details (which app
// has the microphone, who is watching the screen) in a small tag.
// It grows in and shrinks away (`reveal`, 0 -> 1) rather than popping: the
// pill scales and fades while its slot in the bar opens or closes (Status_Bar
// reads `reveal` to do that), and the icons stay on it until it has gone.
// Nothing is drawn while nothing is in use: the module takes no room
// (`visible` is false once it has finished shrinking).
Item {
    id: root

    property bool vertical: false
    property string barPosition: "top"
    property bool micLive: false
    property bool screenLive: false
    property string detailText: ""

    readonly property bool live: micLive || screenLive

    property real reveal: live ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.55 + 0.45 * reveal

    property bool micShown: false
    property bool screenShown: false
    function refreshShown() {
        if (micLive || screenLive) {
            micShown = micLive
            screenShown = screenLive
        }
    }
    onMicLiveChanged: refreshShown()
    onScreenLiveChanged: refreshShown()
    Component.onCompleted: refreshShown()

    readonly property color warn: Theme.tierMax

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: vertical ? 6 : 8
        capKeepsFill: true   // Capsule bar: the warning colour is the point, keep it
        fillColor: root.warn

        implicitWidth: root.vertical ? pill.barVWidth
                                     : row.implicitWidth + 2 * ringWidth + 14
        implicitHeight: root.vertical ? col.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
                                      : Theme.pillHeight + Theme.shadowOffset

        SequentialAnimation on opacity {
            running: root.live
            loops: Animation.Infinite
            NumberAnimation { to: 0.82; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }

        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                visible: root.micShown
                anchors.verticalCenter: parent.verticalCenter
                name: "mic"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
            MaterialIcon {
                visible: root.screenShown
                anchors.verticalCenter: parent.verticalCenter
                name: "screen_record"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
        }

        Column {
            id: col
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                visible: root.micShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: "mic"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
            MaterialIcon {
                visible: root.screenShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: "screen_record"
                size: 16
                fill: 1
                color: Theme.colBorder
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
    }
    BarTip {
        shown: area.containsMouse
        text: root.detailText
        barPosition: root.barPosition
    }
}
