pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"
import "."

Singleton {
    id: root

    property var pinned: []
    property var presets: ({})
    property string activePreset: ""
    readonly property var presetNames: Object.keys(root.presets).sort()

    function kindOf(item) {
        return (item && item.type) ? item.type : "app"
    }

    function allApps() {
        const out = []
        for (const it of root.pinned) {
            const k = root.kindOf(it)
            if (k === "app")
                out.push(it)
            else if (k === "folder")
                for (const a of it.apps)
                    out.push(a)
        }
        return out
    }

    function isPinned(cls) {
        return root.allApps().some(a => a.class === cls)
    }

    function indexOfApp(cls) {
        return root.pinned.findIndex(it => root.kindOf(it) === "app" && it.class === cls)
    }

    function folderOf(cls) {
        return root.pinned.findIndex(it => root.kindOf(it) === "folder" && it.apps.some(a => a.class === cls))
    }

    function copy(list) {
        return JSON.parse(JSON.stringify(list))
    }

    function isHidden(cls) {
        return root.allApps().some(a => a.class === cls && a.hidden === true)
    }

    function setHidden(cls, hidden) {
        if (!root.isPinned(cls) || root.isHidden(cls) === (hidden === true))
            return
        const next = root.copy(root.pinned)
        const mark = a => {
            if (a.class !== cls)
                return
            if (hidden === true)
                a.hidden = true
            else
                delete a.hidden
        }
        for (const it of next) {
            const k = root.kindOf(it)
            if (k === "app")
                mark(it)
            else if (k === "folder")
                it.apps.forEach(mark)
        }
        root.commit(next)
    }

    function toggleHidden(cls) {
        root.setHidden(cls, !root.isHidden(cls))
    }

    function shownCount() {
        return root.allApps().filter(a => a.hidden !== true).length
    }

    function folderShown(item) {
        return root.kindOf(item) === "folder" && item.apps.some(a => a.hidden !== true)
    }

    readonly property var toolIds: ["search", "files", "clipboard", "shelf", "timer"]

    function hasTool(id) {
        return root.pinned.some(it => root.kindOf(it) === "tool" && it.id === id)
    }

    function addTool(id, at) {
        if (!root.toolIds.includes(id) || root.hasTool(id))
            return
        const next = root.copy(root.pinned)
        const i = (at === undefined || at < 0 || at > next.length) ? next.length : at
        next.splice(i, 0, { type: "tool", id: id })
        root.commit(next)
    }

    function removeTool(id) {
        const next = root.copy(root.pinned).filter(it => !(root.kindOf(it) === "tool" && it.id === id))
        root.commit(next)
    }

    function toggleTool(id) {
        if (root.hasTool(id))
            root.removeTool(id)
        else
            root.addTool(id)
    }

    property bool toolsSeeded: false

    function seedTools() {
        if (root.toolsSeeded || !root.layoutRead)
            return
        root.toolsSeeded = true
        const next = root.copy(root.pinned)
        const front = []
        const back = []
        for (const id of ["search", "files"])
            if (!root.hasTool(id))
                front.push({ type: "tool", id: id })
        for (const id of ["clipboard", "shelf", "timer"])
            if (!root.hasTool(id))
                back.push({ type: "tool", id: id })
        const out = front.concat(next)
        if (back.length > 0) {
            if (out.length > 0 && root.kindOf(out[out.length - 1]) !== "sep")
                out.push({ type: "sep" })
            for (const b of back)
                out.push(b)
        }
        root.commit(out)
    }

    property bool layoutRead: false

    function commit(next) {
        root.pinned = next
        root.persist()
    }

    function pin(cls, iconName, at) {
        if (cls === "" || root.isPinned(cls))
            return
        const next = root.copy(root.pinned)
        const item = { type: "app", class: cls, iconName: iconName }
        const i = (at === undefined || at < 0 || at > next.length) ? next.length : at
        next.splice(i, 0, item)
        root.commit(next)
    }

    function unpin(cls) {
        if (!root.isPinned(cls))
            return
        const next = []
        for (const it of root.copy(root.pinned)) {
            const k = root.kindOf(it)
            if (k === "app") {
                if (it.class !== cls)
                    next.push(it)
            } else if (k === "folder") {
                it.apps = it.apps.filter(a => a.class !== cls)
                if (it.apps.length > 0)
                    next.push(it)
            } else {
                next.push(it)
            }
        }
        root.commit(next)
    }

    function toggle(cls, iconName) {
        if (root.isPinned(cls))
            root.unpin(cls)
        else
            root.pin(cls, iconName)
    }

    function move(from, to) {
        const n = root.pinned.length
        if (from < 0 || from >= n || to < 0 || to >= n || from === to)
            return
        const next = root.copy(root.pinned)
        const item = next.splice(from, 1)[0]
        next.splice(to, 0, item)
        root.commit(next)
    }

    function addSeparator(at) {
        const next = root.copy(root.pinned)
        const i = (at === undefined || at < 0 || at > next.length) ? next.length : at
        next.splice(i, 0, { type: "sep" })
        root.commit(next)
    }

    function removeAt(index) {
        if (index < 0 || index >= root.pinned.length)
            return
        const next = root.copy(root.pinned)
        next.splice(index, 1)
        root.commit(next)
    }

    function createFolder(name, at, apps) {
        const cls = apps.map(a => a.class)
        let next = root.copy(root.pinned).filter(it => !(root.kindOf(it) === "app" && cls.includes(it.class)))
        for (const it of next)
            if (root.kindOf(it) === "folder")
                it.apps = it.apps.filter(a => !cls.includes(a.class))
        next = next.filter(it => root.kindOf(it) !== "folder" || it.apps.length > 0)
        const i = (at === undefined || at < 0 || at > next.length) ? next.length : at
        next.splice(i, 0, { type: "folder", name: name, apps: apps.map(a => ({ class: a.class, iconName: a.iconName })) })
        root.commit(next)
    }

    function addToFolder(folderIndex, cls, iconName) {
        const folder = root.pinned[folderIndex]
        if (!folder || root.kindOf(folder) !== "folder")
            return
        const name = folder.name
        let next = root.copy(root.pinned)
        next = next.filter(it => !(root.kindOf(it) === "app" && it.class === cls))
        for (const it of next)
            if (root.kindOf(it) === "folder")
                it.apps = it.apps.filter(a => a.class !== cls)
        const target = next.find(it => root.kindOf(it) === "folder" && it.name === name)
        if (!target)
            return
        target.apps.push({ class: cls, iconName: iconName })
        root.commit(next.filter(it => root.kindOf(it) !== "folder" || it.apps.length > 0))
    }

    function removeFromFolder(folderIndex, cls) {
        const next = root.copy(root.pinned)
        const folder = next[folderIndex]
        if (!folder || root.kindOf(folder) !== "folder")
            return
        const app = folder.apps.find(a => a.class === cls)
        if (!app)
            return
        folder.apps = folder.apps.filter(a => a.class !== cls)
        const out = { type: "app", class: app.class, iconName: app.iconName }
        if (app.hidden === true)
            out.hidden = true
        next.splice(folderIndex + 1, 0, out)
        root.commit(next.filter(it => root.kindOf(it) !== "folder" || it.apps.length > 0))
    }

    function deleteFolder(folderIndex) {
        const next = root.copy(root.pinned)
        const folder = next[folderIndex]
        if (!folder || root.kindOf(folder) !== "folder")
            return
        const apps = folder.apps.map(a => {
            const app = { type: "app", class: a.class, iconName: a.iconName }
            if (a.hidden === true)
                app.hidden = true
            return app
        })
        next.splice(folderIndex, 1, ...apps)
        root.commit(next)
    }

    function renameFolder(folderIndex, name) {
        const next = root.copy(root.pinned)
        const folder = next[folderIndex]
        if (!folder || root.kindOf(folder) !== "folder" || name.trim() === "")
            return
        folder.name = name.trim()
        root.commit(next)
    }

    function savePreset(name) {
        const n = String(name).trim()
        if (n === "")
            return
        const next = Object.assign({}, root.presets)
        next[n] = root.copy(root.pinned)
        root.presets = next
        root.activePreset = n
        root.persist()
    }

    function loadPreset(name) {
        if (!(name in root.presets))
            return
        root.pinned = root.copy(root.presets[name])
        root.activePreset = name
        root.persist()
    }

    function deletePreset(name) {
        if (!(name in root.presets))
            return
        const next = Object.assign({}, root.presets)
        delete next[name]
        root.presets = next
        if (root.activePreset === name)
            root.activePreset = ""
        root.persist()
    }

    function freshPresetName() {
        let n = root.presetNames.length + 1
        while (("Layout " + n) in root.presets)
            n++
        return "Layout " + n
    }

    property bool dockPinned: false

    function setDockPinned(value) {
        if (root.dockPinned === value)
            return
        root.dockPinned = value
        dockPinSaver.save(value)
    }

    function toggleDockPinned() {
        root.setDockPinned(!root.dockPinned)
    }

    readonly property string script: Directories.script("state/pinned-apps-state.sh")

    function restoreLayout(text) {
        try {
            const j = JSON.parse(text)
            if (Array.isArray(j.items))
                root.pinned = j.items
            if (j.presets && typeof j.presets === "object")
                root.presets = j.presets
            if (typeof j.active === "string")
                root.activePreset = j.active
            if (j.toolsSeeded === true)
                root.toolsSeeded = true
        } catch (e) {
            console.warn("PinnedAppsService: couldn't read the dock layout:", e)
        }
    }

    // Runs once, at startup: the layout file, or (never saved one yet) the old
    // one-app-per-line list.
    Process {
        running: true
        command: ["sh", root.script, "layout-load"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    root.restoreLayout(text)
                    root.layoutRead = true
                    root.seedTools()
                } else {
                    legacyLoad.running = true
                }
            }
        }
    }

    Process {
        id: legacyLoad
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pinned = text.split("\n")
                    .filter(line => line.length > 0)
                    .map(line => {
                        const tab = line.indexOf("\t")
                        return tab >= 0
                            ? { type: "app", class: line.slice(0, tab), iconName: line.slice(tab + 1) }
                            : { type: "app", class: line, iconName: line }
                    })
                root.layoutRead = true
                root.seedTools()
            }
        }
    }

    Process {
        running: true
        command: ["sh", root.script, "dock-load"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.dockPinned = text.trim() === "1"
                root.dockLoaded = true
                root.applyStartupPin()
            }
        }
    }

    property bool dockLoaded: false
    property bool startupApplied: false

    function applyStartupPin() {
        if (root.startupApplied || !root.dockLoaded || !SettingsService.loaded)
            return
        root.startupApplied = true
        if (SettingsService.flag("dock.pinOnStartup"))
            root.setDockPinned(true)
    }

    Connections {
        target: SettingsService
        function onLoadedChanged() {
            root.applyStartupPin()
        }
    }

    function persist() {
        saver.save(JSON.stringify({ version: 1, items: root.pinned, presets: root.presets, active: root.activePreset, toolsSeeded: root.toolsSeeded }))
    }

    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "layout-save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "layout-save", json])
            }
        }
    }

    Process {
        id: dockPinSaver

        property var pending: null

        function save(value) {
            if (dockPinSaver.running) {
                dockPinSaver.pending = value
                return
            }
            dockPinSaver.pending = null
            dockPinSaver.exec(["sh", root.script, "dock-save", value ? "1" : "0"])
        }

        onExited: {
            if (dockPinSaver.pending !== null) {
                const value = dockPinSaver.pending
                dockPinSaver.pending = null
                dockPinSaver.exec(["sh", root.script, "dock-save", value ? "1" : "0"])
            }
        }
    }
}
