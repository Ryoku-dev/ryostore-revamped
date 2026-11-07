pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "services"
import "modules/tansu/bar"
import "modules/tansu/quickPanel"

Scope {
    id: root

    property var modelData: null

    readonly property var screen: root.modelData
    // The phone is one window: it lives on the first screen that has a bar.
    readonly property bool isPrimary: {
        if (!root.screen)
            return false
        for (const s of Quickshell.screens) {
            if (s && s.name && Tokens.barEnabledFor(s.name))
                return s.name === root.screen.name
        }
        return false
    }
    readonly property var phone: PhoneLink.panel

    // The one bar to build (Variants, below), carrying the edge it is on.
    // Moving the bar (Settings -> Bar -> Position) does not re-anchor and
    // resize a live layer-shell window — which left the bar, the space it
    // reserves and the popups out of step until the shell was restarted — it
    // builds a fresh window on the new edge and drops the old one: exactly what
    // a restart does. The entry changes only when the edge or the bar's
    // visibility does, so an unrelated setting doesn't rebuild the window.
    // Nothing is built until the saved edge has been read, so startup doesn't
    // create a "top" bar only to move it a moment later.
    readonly property var barModels: {
        if (!root.screen || !BarPositionService.loaded || !SettingsService.flag("bar.visible"))
            return []
        return [{ screen: root.screen, position: BarPositionService.position }]
    }

    TraySource {
        id: trayState
    }

    QuickSource {
        id: quickState
        active: !!root.phone && (root.phone.open || root.phone.settingsShown)
        targetScreen: root.phone ? root.phone.targetScreen : root.screen
    }

    NotificationSource {
        id: notificationState
        doNotDisturb: !quickState.notificationsOn
        quietWhenFullscreen: false
        popupsSuppressed: !!root.phone && root.phone.open
    }

    MediaSource {
        id: mediaState
    }

    Loader {
        id: panelLoader
        active: root.isPrimary
        sourceComponent: Component {
            QuickPanel {
                source: quickState
                notificationSource: notificationState
                mediaSource: mediaState
                picker: wallpaperEntry
            }
        }
        onLoaded: PhoneLink.panel = item
        onActiveChanged: if (!active) PhoneLink.panel = null
    }

    QtObject {
        id: wallpaperEntry

        function openOn(screen, which) {
            if (PhoneLink.panel)
                PhoneLink.panel.openWallpapers(screen, which)
        }

        function toggleOn(screen, which) {
            if (PhoneLink.panel)
                PhoneLink.panel.toggleWallpapersOn(screen, which)
        }
    }

    Variants {
        model: root.barModels

        delegate: Component {
            Bar {
                traySource: trayState
                quickPanel: PhoneLink.panel
                picker: PhoneLink.panel ? wallpaperEntry : null
            }
        }
    }
}
