pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    readonly property string indexPath: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/ryogami/wallpaper/index.json"

    property var index: ({})
    property var entries: []
    property bool loaded: false

    property string directory: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    readonly property bool ready: true
    readonly property bool perMonitor: false
    readonly property bool separateLock: true
    readonly property bool customFolder: false
    readonly property bool folderPicking: false

    property string appliedPath: ""

    readonly property string directoryShort: {
        const home = Quickshell.env("HOME")
        const d = root.directory
        if (home !== "" && d === home)
            return "~"
        return (home !== "" && d.indexOf(home + "/") === 0) ? "~" + d.slice(home.length) : d
    }

    readonly property string directoryUrl: "file://" + root.directory.split("/").map(encodeURIComponent).join("/")

    FileView {
        id: indexFile
        path: root.indexPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.readIndex(indexFile.text())
        onFileChanged: indexFile.reload()
    }

    function readIndex(text) {
        let data = {}
        try {
            data = JSON.parse(text)
        } catch (e) {
            data = {}
        }
        const list = []
        const map = {}
        const counts = {}
        for (const key in data) {
            const v = data[key]
            if (!v || !v.path)
                continue
            const rec = {
                path: v.path,
                name: v.name || v.key || "",
                type: v.type || "static",
                thumb: v.thumb || "",
                thumbSm: v.thumb_sm || "",
                favourite: v.favourite === 1
            }
            list.push(rec)
            map[rec.path] = rec
            const at = rec.path.lastIndexOf("/")
            if (at > 0) {
                const d = rec.path.slice(0, at)
                counts[d] = (counts[d] || 0) + 1
            }
        }
        root.index = map
        root.entries = list
        const preferred = Quickshell.env("HOME") + "/Pictures/Wallpapers"
        let best = ""
        let bestCount = 0
        for (const d in counts) {
            if (counts[d] > bestCount || (counts[d] === bestCount && (best === "" || d === preferred))) {
                best = d
                bestCount = counts[d]
            }
        }
        if (best !== "")
            root.directory = best
        root.loaded = true
    }

    function isVideo(path) {
        const rec = root.index[path]
        if (rec)
            return rec.type === "video"
        return /\.(mp4|webm|mkv|mov|avi)$/i.test(path || "")
    }

    function thumbUrl(path) {
        if (!path)
            return ""
        const rec = root.index[path]
        if (rec) {
            const t = rec.thumbSm !== "" ? rec.thumbSm : rec.thumb
            if (t !== "")
                return "file://" + t
        }
        return root.isVideo(path) ? "" : "file://" + path
    }

    function pathFor(name) { return root.appliedPath }
    function lockPathFor(name) { return root.appliedPath }
    readonly property string currentPath: root.appliedPath
    readonly property string lockCurrentPath: root.appliedPath

    function setWallpaper(path, screenName) {
        if (!path || path.length === 0)
            return
        root.appliedPath = path
        const args = ["ryogami", "wallpaper", "set"]
        if (screenName)
            args.push("--screen", screenName)
        args.push(path)
        Quickshell.execDetached(args)
    }

    function setLockWallpaper(path, screenName) {
        if (path && path.length > 0)
            root.setWallpaper(path, screenName)
        Quickshell.execDetached(["ryoku-shell", "hub", "open", "lockscreen"])
    }

    function setSeparateLock(on) {}
    function setPerMonitor(on) {}
    function adoptMain() {}
    function adoptMainLock() {}
    function pinMissing() {}
    function forgetScreenPicks() {}
    function forgetLockScreenPicks() {}
    function seedLock() {}
    function ensureDefault(path) {}

    function pickFolder(reopen) {
        Quickshell.execDetached(["xdg-open", root.directory])
    }

    function resetFolder() {}

    function random(screenName) {
        const list = root.entries.filter(e => e.path !== root.appliedPath)
        if (list.length === 0)
            return
        const pick = list[Math.floor(Math.random() * list.length)]
        root.setWallpaper(pick.path, screenName || "")
    }

    readonly property string transitionSetting: "fade"
    readonly property int transitionDuration: 900
    readonly property int transitionEasing: Easing.InOutQuad
    property string switchStyleRolled: "fade"
    property string lockStyleRolled: "fade"
    property string transitionStyle: "fade"
    function styleForSwitch() { return "fade" }
    function rollLockStyle() {}
    property bool restacking: false
    property bool restackingLow: false
    function restackWidgets() {}

    signal transitionStarted(string from, string to)
}
