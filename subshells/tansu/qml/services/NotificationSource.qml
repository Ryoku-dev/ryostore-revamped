import QtQuick
import Quickshell
import shell.services as Ryoku
import "."

// The notification list the phone shows, fed by Ryoku's Notifs singleton (the
// shell already owns the org.freedesktop.Notifications daemon). This shapes the
// daemon's live notifications into the entry objects QuickPanelFace reads:
// { key, app, title, body, time, icon, urgency }.
Scope {
    id: root

    // Scene binds this to the Quick tile's state; Notifs.dnd is the single
    // source of truth, so this never writes back and cannot loop.
    property bool doNotDisturb: false
    property bool quietWhenFullscreen: false
    property bool popupsSuppressed: false
    property string alertStyle: "phone"
    property var popupLeft: ({})
    property var popupHeld: ({})
    property int maxPopups: 4
    property int maxEntries: 100
    property string popupMonitor: ""
    property int maxPopupsPerApp: 3

    readonly property var history: Ryoku.Notifs.history
    readonly property var popupList: Ryoku.Notifs.popups

    readonly property var entries: {
        const list = root.history
        const out = []
        for (let i = 0; i < list.length; i++)
            out.push(root.entryFor(list[i]))
        return out
    }

    readonly property int count: root.entries.length

    readonly property var toast: root.popupList.length > 0 ? root.entryFor(root.popupList[0]) : null
    readonly property bool toastActive: root.popupList.length > 0

    readonly property bool loaded: true
    readonly property bool held: Ryoku.Notifs.dnd

    signal alerted(var entry)

    property string _lastPopupId: ""
    Connections {
        target: Ryoku.Notifs
        function onPopupsChanged() {
            const top = Ryoku.Notifs.popups.length > 0 ? Ryoku.Notifs.popups[0] : null
            if (top && String(top.id) !== root._lastPopupId) {
                root._lastPopupId = String(top.id)
                root.alerted(root.entryFor(top))
            }
        }
    }

    function setDnd(on) { Ryoku.Notifs.dnd = on === true }

    function iconFor(n) {
        if (n.image)
            return n.image
        if (n.appIcon) {
            const a = String(n.appIcon)
            if (a.indexOf("/") >= 0 || a.indexOf("file:") === 0 || a.indexOf("http") === 0)
                return a
            return "material:notifications"
        }
        return "material:notifications"
    }

    function urgencyOf(n) {
        if (n.urgency === 2)
            return 2
        if (n.urgency === 0)
            return 0
        return 1
    }

    function entryFor(n) {
        return {
            key: String(n.id),
            app: n.appName || "",
            title: n.summary || "",
            body: n.body || "",
            time: Ryoku.Notifs.timeLabel(n),
            icon: root.iconFor(n),
            urgency: root.urgencyOf(n)
        }
    }

    function liveFor(key) {
        const all = (Ryoku.Notifs.tracked || []).concat(Ryoku.Notifs.popups || [])
        for (let i = 0; i < all.length; i++)
            if (String(all[i].id) === String(key))
                return all[i]
        return null
    }

    function canActivate(key) {
        const n = root.liveFor(key)
        return !!(n && n.actions && n.actions.length > 0)
    }

    function activate(key) {
        const n = root.liveFor(key)
        if (!n || !n.actions)
            return false
        for (let i = 0; i < n.actions.length; i++) {
            const a = n.actions[i]
            if (a.identifier === "default" || i === 0) {
                if (typeof a.invoke === "function")
                    a.invoke()
                return true
            }
        }
        return false
    }

    function dismiss(key) {
        const n = root.liveFor(key)
        if (n) {
            Ryoku.Notifs.removePopup(n)
            Ryoku.Notifs.dismiss(n)
        }
    }

    function dismissMany(keys) {
        for (let i = 0; i < keys.length; i++)
            root.dismiss(keys[i])
    }

    function clearAll() {
        Ryoku.Notifs.clearAll()
    }

    function hideToast() {
        if (root.popupList.length > 0)
            Ryoku.Notifs.removePopup(root.popupList[0])
    }

    function showToast(entry) {}
    function pushPopup(entry) {}
    function closePopups(keys) {}
    function closePopup(key) {}
    function clearPopups() { Ryoku.Notifs.popups = [] }
    function holdPopup(key, held) {}
    function tickPopups() {}
    function setQuietWhenFullscreen(on) { root.quietWhenFullscreen = on === true }
    function reportFullscreen(on) {}
}
