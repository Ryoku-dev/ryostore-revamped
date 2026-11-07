import QtQuick
import Quickshell
import "../../../services"

SettingsPage {
    id: page

    SectionCard {
        title: "Time & alerts"

        SettingToggle {
            icon: "schedule"
            label: "24-hour time"
            checked: SettingsService.flag("time.use24h")
            onToggled: SettingsService.toggle("time.use24h")
        }

        SettingToggle {
            icon: "vibration"
            label: "Buzz on arrival"
            detail: "The phone shakes when a notification comes in"
            checked: SettingsService.flag("notify.buzz")
            onToggled: SettingsService.toggle("notify.buzz")
        }

        SettingAction {
            icon: "clear_all"
            label: "Clear all"
            detail: page.host && page.host.notificationSource
                ? (page.host.notificationSource.count === 0 ? "Nothing waiting" : page.host.notificationSource.count + " waiting") : ""
            onActivated: if (page.host && page.host.notificationSource) page.host.notificationSource.clearAll()
        }
    }

    SectionCard {
        title: "Quick Panel"

        SettingToggle {
            icon: "swipe_up"
            label: "Hot edge"
            detail: SettingsService.flag("panel.hotEdge") ? "Bottom centre" : "OFF"
            checked: SettingsService.flag("panel.hotEdge")
            onToggled: SettingsService.toggle("panel.hotEdge")
        }

        SettingToggle {
            icon: "touch_app"
            label: "Click outside closes it"
            detail: SettingsService.flag("panel.clickOutside") ? "Phone and launcher" : "OFF"
            checked: SettingsService.flag("panel.clickOutside")
            onToggled: SettingsService.toggle("panel.clickOutside")
        }

        SettingStepper {
            icon: "timer"
            label: "Edge delay"
            from: 40
            to: 800
            step: 20
            suffix: " ms"
            value: SettingsService.get("panel.hotDwell")
            onMoved: v => SettingsService.set("panel.hotDwell", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "vertical_align_top"
            label: "How much of the phone shows"
            from: 40
            to: 100
            step: 2
            suffix: "%"
            value: SettingsService.get("panel.peek")
            onMoved: v => SettingsService.set("panel.peek", v)
        }

        SettingToggle {
            icon: "keyboard"
            label: "Type to search apps"
            detail: SettingsService.flag("panel.typeToSearch") ? "A letter opens Apps" : "OFF"
            checked: SettingsService.flag("panel.typeToSearch")
            onToggled: SettingsService.toggle("panel.typeToSearch")
        }

        SettingChoice {
            label: "Avatar & banner picker"
            sublabel: "The window that opens when you pick a picture"
            current: SettingsService.get("files.chooser")
            options: [
                { id: "auto", label: "Auto", icon: "auto_awesome" },
                { id: "kdialog", label: "KDE", icon: "folder_open" },
                { id: "zenity", label: "GTK / system", icon: "desktop_windows" },
                { id: "yad", label: "yad", icon: "folder" }
            ]
            onPicked: id => SettingsService.set("files.chooser", id)
        }
    }

    SectionCard {
        title: "Hot corners"

        SettingToggle {
            icon: "north_west"
            label: "Top left"
            detail: "Hover to open the phone"
            checked: SettingsService.flag("panel.hotCornerTopLeft")
            onToggled: SettingsService.toggle("panel.hotCornerTopLeft")
        }

        SettingToggle {
            icon: "north_east"
            label: "Top right"
            detail: "Hover to open the phone"
            checked: SettingsService.flag("panel.hotCornerTopRight")
            onToggled: SettingsService.toggle("panel.hotCornerTopRight")
        }

        SettingToggle {
            icon: "south_west"
            label: "Bottom left"
            detail: "Hover to open the phone"
            checked: SettingsService.flag("panel.hotCornerBottomLeft")
            onToggled: SettingsService.toggle("panel.hotCornerBottomLeft")
        }

        SettingToggle {
            icon: "south_east"
            label: "Bottom right"
            detail: "Hover to open the phone"
            checked: SettingsService.flag("panel.hotCornerBottomRight")
            onToggled: SettingsService.toggle("panel.hotCornerBottomRight")
        }

        SettingToggle {
            icon: "open_in_full"
            label: "Open near the corner"
            detail: SettingsService.flag("panel.hotCornerFollow")
                ? "The phone comes up from the corner that called it" : "Always the bottom centre"
            checked: SettingsService.flag("panel.hotCornerFollow")
            onToggled: SettingsService.toggle("panel.hotCornerFollow")
        }
    }

    SectionCard {
        title: "Shell"

        SettingAction {
            icon: "refresh"
            label: "Reload shell"
            detail: "Rebuild every window"
            onActivated: Quickshell.reload(true)
        }

        SettingAction {
            icon: "restart_alt"
            label: "Reset settings"
            detail: SettingsService.changedCount === 0 ? "Nothing changed"
                : SettingsService.changedCount + (SettingsService.changedCount === 1 ? " change" : " changes")
            onActivated: SettingsService.reset()
        }
    }
}
