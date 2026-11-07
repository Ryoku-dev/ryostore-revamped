import QtQuick
import QtQuick.Layouts
import "../../../services"
import "../../../modules/common"

GridLayout {
    id: grid

    property var src: null

    property real keyWidth: 30
    property real keyHeight: 24
    property int iconSize: 20

    signal closeRequested()

    readonly property string hint: {
        for (let i = 0; i < grid.children.length; i++) {
            const k = grid.children[i]
            if (k.visible && k.hovered)
                return k.label
        }
        return ""
    }

    columnSpacing: 0
    rowSpacing: 0

    UtilKey {
        visible: SettingsService.flag("util.screenshot")
        label: "Screen snip"
        icon: "screenshot_region"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.screenshotRegion()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.colorPicker")
        label: "Color picker"
        icon: "colorize"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.pickColor()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.keyboard")
        label: "On-screen keyboard"
        icon: "keyboard"
        active: KeyboardService.running
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: KeyboardService.toggle()
    }

    UtilKey {
        visible: SettingsService.flag("util.mic")
        label: grid.src && grid.src.micMuted ? "Unmute mic" : "Mute mic"
        icon: grid.src && grid.src.micMuted ? "mic_off" : "mic"
        active: grid.src ? grid.src.micMuted : false
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.toggleMic()
    }

    UtilKey {
        visible: SettingsService.flag("util.darkMode")
        label: "Night light"
        icon: grid.src && grid.src.nightLightOn ? "bedtime" : "light_mode"
        active: grid.src ? grid.src.nightLightOn : false
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.toggleNightLight()
    }

    UtilKey {
        visible: SettingsService.flag("util.profile")
        label: "Power profile"
        icon: grid.src ? grid.src.profileIcon : "balance"
        active: grid.src ? grid.src.performanceOn : false
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.cycleProfile()
    }

    UtilKey {
        visible: SettingsService.flag("util.record")
        label: grid.src && grid.src.recording ? "Stop recording" : "Record screen"
        icon: grid.src && grid.src.recording ? "stop" : "screen_record"
        active: grid.src ? grid.src.recording : false
        activeFill: Theme.tierMax
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.toggleRecording()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.wallpapers")
        label: "Wallpapers"
        icon: "wallpaper"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.wallpapersRequested()
            grid.closeRequested()
        }
    }
}
