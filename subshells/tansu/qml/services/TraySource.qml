import QtQuick
import Quickshell
import shell.services as Ryoku
import "."

// The tray as the bar sees it: Ryoku's daemon owns the StatusNotifier host and
// streams the items, and this wraps each one with the click / menu intents the
// Tansu UI calls. Decorated items are memoised per service so a reference stays
// stable while the item's own properties change (the tray capsules animate on
// identity).
Scope {
    id: root

    property var pinnedIds: []

    property var _cache: ({})

    function iconOf(it) {
        if (it.iconPath)
            return "file://" + it.iconPath
        if (it.iconName)
            return Quickshell.iconPath(it.iconName, true)
        return ""
    }

    function decorate(it) {
        const service = it.service || it.id || ""
        let item = root._cache[service]
        if (!item) {
            item = {
                service: service,
                id: it.id || service,
                title: "",
                tooltip: null,
                status: "Active",
                icon: "",
                hasMenu: false,
                onlyMenu: false,
                activate: function() { Ryoku.Tray.activate(service) },
                secondaryActivate: function() { Ryoku.Tray.contextMenu(service, 0, 0) },
                scroll: function(delta, horizontal) {
                    Ryoku.Tray.scroll(service, delta, horizontal ? "horizontal" : "vertical")
                }
            }
            root._cache[service] = item
        }
        item.title = it.title || ""
        item.tooltip = it.tooltip || null
        item.status = it.status || "Active"
        item.icon = root.iconOf(it)
        item.hasMenu = !!it.menu
        item.onlyMenu = it.itemIsMenu === true
        return item
    }

    readonly property var items: {
        const list = Ryoku.Tray.items || []
        const out = []
        for (let i = 0; i < list.length; i++)
            out.push(root.decorate(list[i]))
        return out
    }

    function isPinned(item) {
        return item !== null && root.pinnedIds.indexOf(item.service) !== -1
    }

    readonly property var pinnedItems: root.items.filter(i => root.isPinned(i))
    readonly property var unpinnedItems: root.items.filter(i => !root.isPinned(i))
    readonly property bool unpinnedAttention: root.unpinnedItems.some(i => i.status === "NeedsAttention")

    function togglePinned(item) {
        if (item === null)
            return
        const ids = root.pinnedIds.slice()
        const at = ids.indexOf(item.service)
        if (at >= 0)
            ids.splice(at, 1)
        else
            ids.push(item.service)
        root.pinnedIds = ids
    }

    function menuTreeFor(item) {
        if (item === null)
            return null
        const list = Ryoku.Tray.items || []
        for (let i = 0; i < list.length; i++)
            if ((list[i].service || "") === item.service)
                return list[i].menu || null
        return null
    }
}
