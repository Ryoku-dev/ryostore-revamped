pragma Singleton
import QtQuick
import Quickshell
import "."

Singleton {
    id: root

    readonly property var modules: [
        { id: "workspaces", label: "Workspaces", icon: "grid_view" },
        { id: "activeWindow", label: "Active window", icon: "web_asset" },
        { id: "media", label: "Media", icon: "music_note" },
        { id: "privacy", label: "Privacy", icon: "shield_with_heart" },
        { id: "updates", label: "Updates", icon: "system_update_alt" },
        { id: "utilButtons", label: "Utility keys", icon: "construction" },
        { id: "resources", label: "CPU & RAM", icon: "memory" },
        { id: "status", label: "Wi-Fi, Bluetooth & sound", icon: "wifi" },
        { id: "battery", label: "Battery", icon: "battery_android_full" },
        { id: "keyboardLayout", label: "Keyboard layout", icon: "keyboard_alt" },
        { id: "notifications", label: "Notification bell", icon: "notifications" },
        { id: "tray", label: "Tray", icon: "apps" },
        { id: "weather", label: "Weather", icon: "partly_cloudy_day" },
        { id: "date", label: "Date", icon: "calendar_month" },
        { id: "clock", label: "Clock", icon: "schedule" }
    ]

    readonly property var zoneNames: ["left", "center", "right"]

    readonly property var defaults: ({
        left: ["activeWindow", "media", "tray"],
        center: ["status", "weather", "workspaces", "clock", "date"],
        right: ["utilButtons", "resources", "battery", "keyboardLayout", "privacy", "updates", "notifications"]
    })

    readonly property var layout: root.normalize(SettingsService.get("bar.layout", root.defaults))

    readonly property bool perMonitor: SettingsService.flag("bar.perMonitor")

    readonly property var screenLayouts: root.normalizeScreens(SettingsService.get("bar.screens", ({})))

    readonly property var defaultOrder: {
        const out = []
        for (const z of root.zoneNames)
            for (const id of root.defaults[z])
                out.push(id)
        return out
    }

    function labelOf(id) {
        const m = root.modules.find(x => x.id === id)
        return m ? m.label : id
    }

    function iconOf(id) {
        const m = root.modules.find(x => x.id === id)
        return m ? m.icon : "widgets"
    }

    function ownFor(name) {
        if (!root.perMonitor || !name)
            return null
        return root.screenLayouts[name] ?? null
    }

    function layoutFor(name) {
        return root.ownFor(name) ?? root.layout
    }

    function offFor(name) {
        const o = root.ownFor(name)
        return o ? o.off : []
    }

    function isOn(id, name) {
        return SettingsService.flag("bar." + id) && root.offFor(name).indexOf(id) < 0
    }

    function modulesFor(name) {
        const off = root.offFor(name)
        const out = {}
        for (const m of root.modules)
            out[m.id] = SettingsService.flag("bar." + m.id) && off.indexOf(m.id) < 0
        return out
    }

    function zoneOf(id, name) {
        const lay = root.layoutFor(name)
        for (const z of root.zoneNames) {
            if ((lay[z] || []).indexOf(id) >= 0)
                return z
        }
        return "right"
    }

    function orderOf(id) {
        const i = root.defaultOrder.indexOf(id)
        return i < 0 ? root.defaultOrder.length : i
    }

    function normalize(raw) {
        const known = root.modules.map(m => m.id)
        const seen = {}
        const out = { left: [], center: [], right: [] }
        for (const z of root.zoneNames) {
            const list = raw && Array.isArray(raw[z]) ? raw[z] : []
            for (const id of list) {
                if (known.indexOf(id) >= 0 && !seen[id]) {
                    seen[id] = true
                    out[z].push(id)
                }
            }
        }
        for (const z of root.zoneNames) {
            for (const id of root.defaults[z]) {
                if (seen[id])
                    continue
                seen[id] = true
                out[z].push(id)
            }
        }
        for (const z of root.zoneNames)
            out[z].sort((a, b) => root.orderOf(a) - root.orderOf(b))
        return out
    }

    function normalizeScreens(raw) {
        const out = {}
        if (!raw || typeof raw !== "object")
            return out
        const known = root.modules.map(m => m.id)
        for (const name of Object.keys(raw)) {
            const entry = root.normalize(raw[name])
            const off = raw[name] && Array.isArray(raw[name].off) ? raw[name].off : []
            entry.off = off.filter((id, i) => known.indexOf(id) >= 0 && off.indexOf(id) === i)
            out[name] = entry
        }
        return out
    }

    function payload() {
        const out = { left: root.layout.left, center: root.layout.center, right: root.layout.right }
        if (Object.keys(root.screenLayouts).length > 0)
            out.screens = root.screenLayouts
        return out
    }

    function applyPayload(raw) {
        if (!raw || typeof raw !== "object")
            return
        SettingsService.set("bar.layout", (raw.left || raw.center || raw.right)
            ? root.normalize(raw) : root.normalize(root.defaults))
        SettingsService.set("bar.screens", root.normalizeScreens(raw.screens))
    }

    function copyFor(name) {
        const src = root.layoutFor(name)
        return {
            left: (src.left || []).slice(),
            center: (src.center || []).slice(),
            right: (src.right || []).slice(),
            off: (src.off ?? []).slice()
        }
    }

    function commit(name, next) {
        const clean = root.normalize(next)
        clean.off = (next.off || []).filter(id => root.modules.some(m => m.id === id))
        if (root.editsOwn(name)) {
            const all = Object.assign({}, SettingsService.get("bar.screens", ({})))
            all[name] = clean
            SettingsService.set("bar.screens", all)
        } else {
            SettingsService.set("bar.layout", { left: clean.left, center: clean.center, right: clean.right })
        }
    }

    function editsOwn(name) {
        return root.perMonitor && !!name
    }

    function moveTo(id, zone, screenName) {
        if (root.zoneNames.indexOf(zone) < 0 || !root.modules.some(m => m.id === id))
            return
        const name = screenName || ""
        const next = root.copyFor(name)
        for (const z of root.zoneNames)
            next[z] = next[z].filter(x => x !== id)
        next[zone].push(id)
        root.commit(name, next)
    }

    // Takes a module off the bar of a monitor (`off` true) or puts it back.
    // With separate bars that is only this monitor's bar; otherwise it is the
    // Settings switch (Bar -> Modules), the same one as always.
    //
    // A module that the Settings switch has turned off everywhere stays off on
    // the other monitors when it is put back on this one, so editing one bar
    // never changes another.
    function setOff(id, off, screenName) {
        if (!root.modules.some(m => m.id === id))
            return
        const name = screenName || ""
        if (!root.editsOwn(name)) {
            SettingsService.set("bar." + id, !off)
            return
        }
        const wasOnEverywhere = SettingsService.flag("bar." + id)
        const next = root.copyFor(name)
        next.off = next.off.filter(x => x !== id)
        if (off)
            next.off.push(id)
        const all = Object.assign({}, SettingsService.get("bar.screens", ({})))
        all[name] = next
        if (!off && !wasOnEverywhere) {
            for (const s of Quickshell.screens) {
                if (s.name === name)
                    continue
                const other = root.copyFor(s.name)
                if (other.off.indexOf(id) < 0)
                    other.off.push(id)
                all[s.name] = other
            }
            SettingsService.set("bar." + id, true)
        }
        SettingsService.set("bar.screens", all)
    }

    function reset(screenName) {
        const name = screenName || ""
        const next = root.normalize(root.defaults)
        next.off = root.copyFor(name).off
        root.commit(name, next)
    }

    function customizedFor(name) {
        const lay = root.layoutFor(name)
        return JSON.stringify({ left: lay.left, center: lay.center, right: lay.right })
            !== JSON.stringify(root.defaults)
    }
}
