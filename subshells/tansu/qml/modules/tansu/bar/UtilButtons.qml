import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import shell.services as Ryoku
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

// The bar's utility buttons, joined into one long pill (same
// radiusBadge corners and hard shadow as the other bar widgets) with a
// flat glyph cell per button. Left to right:
//
//   Screen snip        grim + slurp, saved to ~/Pictures/Screenshots
//                      and copied to the clipboard (wl-copy)
//   Color picker       hyprpicker -a (hex goes straight to the clipboard)
//   Mic                mute / unmute the default mic (lit = muted)
//   Night light        flips Ryoku's night light
//   Performance        cycles power-saver -> balanced -> performance
//                      (power-profiles-daemon through Ryoku's service)
//   Record screen      pick a region, record it with wf-recorder to
//                      ~/Videos/Recordings; click again to stop (lit
//                      while recording)
//   Wallpapers         opens the wallpaper picker
//
// If a tool isn't installed the button just does nothing — same
// "missing tool doesn't stop the shell" rule QuickSource.qml follows.
Item {
    id: root

    property bool vertical: false

    property bool compact: false
    property bool popupOpen: false
    readonly property Item toggleItem: bar
    signal toggleRequested()

    implicitWidth: bar.width
    implicitHeight: bar.height

    signal wallpapersRequested()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }
    readonly property var micAudio: Pipewire.defaultAudioSource?.audio ?? null
    readonly property bool micMuted: micAudio ? micAudio.muted : false

    function toggleMic() {
        if (micAudio)
            micAudio.muted = !micAudio.muted
    }

    readonly property bool nightLightOn: Ryoku.Nightlight.on

    function toggleNightLight() {
        Ryoku.Nightlight.toggle()
    }

    readonly property string performanceProfile: Ryoku.PowerProfiles.profile
    readonly property bool performanceOn: root.performanceProfile === "performance"
    readonly property string profileIcon: root.performanceProfile === "power-saver"
        ? "energy_savings_leaf"
        : (root.performanceProfile === "performance" ? "speed" : "balance")

    function cycleProfile() {
        const list = Ryoku.PowerProfiles.profiles
        if (list.length === 0)
            return
        const at = list.indexOf(root.performanceProfile)
        Ryoku.PowerProfiles.setProfile(list[(at + 1) % list.length])
    }


    property string recordFile: ""
    readonly property bool recording: recorder.running

    Process {
        id: recorder
        onRunningChanged: {
            if (!running && root.recordFile !== "") {
                Quickshell.execDetached(["bash", "-c",
                    "[ -s \"$1\" ] && notify-send -a tansu -i material:videocam \"Recording saved\" \"$1\"",
                    "bash", root.recordFile])
                root.recordFile = ""
            }
        }
    }

    function toggleRecording() {
        if (recorder.running) {
            recorder.signal(2)
            return
        }
        const dir = Quickshell.env("HOME") + "/Videos/Recordings"
        root.recordFile = dir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4"
        recorder.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; g=$(slurp) || exit 0; exec wf-recorder -g \"$g\" -f \"$1\"",
            "bash", root.recordFile]
        recorder.running = true
    }

    function screenshotRegion() {
        const script = [
            "dir=\"$HOME/Pictures/Screenshots\"",
            "mkdir -p \"$dir\"",
            "f=\"$dir/$(date +%Y-%m-%d_%H-%M-%S).png\"",
            "grim -g \"$(slurp)\" \"$f\" && wl-copy < \"$f\" && notify-send -a tansu -i material:photo_camera \"Screenshot saved\" \"$f\""
        ].join("; ")
        Quickshell.execDetached(["bash", "-c", script])
    }

    function pickColor() {
        Quickshell.execDetached(["hyprpicker", "-a"])
    }

    readonly property Item content: root.compact ? toolKey : row

    Pill {
        id: bar
        width: root.vertical ? bar.barVWidth : root.content.implicitWidth + 2 * ringWidth + 2 * 4
        height: root.vertical
            ? root.content.implicitHeight + (bar.capsule ? 4 : 2 * ringWidth) + 2 * 4 + Theme.shadowOffset
            : Theme.pillHeight + Theme.shadowOffset
        cornerRadius: Theme.radiusBadge
        ringWidth: 6
        fillColor: Theme.chipFill

        UtilKeys {
            id: row
            anchors.centerIn: parent
            visible: !root.compact
            src: root
            columns: root.vertical ? 1 : 100
        }

        UtilKey {
            id: toolKey
            anchors.centerIn: parent
            visible: root.compact
            label: "Utility keys"
            icon: "construction"
            active: root.popupOpen
            onClicked: root.toggleRequested()
        }
    }
}
