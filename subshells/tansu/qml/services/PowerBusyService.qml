pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// "Is something still working?" for the Power menu: a package manager (pacman,
// paru, yay, apt, dnf, flatpak...) or a download (wget, aria2c, yt-dlp, rsync...)
// that a reboot or shutdown would cut off half way. PowerMenu.qml puts a small
// warning on its Power off and Reboot pills while `busy` is true, and a note
// that says what is running when the pointer is on one.
//
// It looks only while the menu is open (`watching`), every 3 seconds and once at
// the start, so nothing runs in the background otherwise. A tool that is not
// installed simply never matches. Not in the list on purpose: curl (this shell's
// weather and image-search calls use it), and torrent clients / sync daemons
// (they run all day, so they would warn all day).
//
// A `checkupdates` run (the bar's update badge) uses pacman for a moment and will
// show as "pacman" while it does.
Singleton {
    id: root

    property bool watching: false

    property var running: []
    readonly property bool busy: root.running.length > 0

    readonly property var packageTools:
        "apt,apt-get,dpkg,flatpak,nix,snap,zypper,pacman,paru,yay,dnf".split(",")
    readonly property var downloadTools: ["wget", "aria2c", "axel", "yt-dlp", "rsync"]

    readonly property string pattern:
        root.packageTools.concat(root.downloadTools).join("|")

    // "pacman is running" / "pacman and wget are running" for the note.
    readonly property string note: {
        const n = root.running
        if (n.length === 0)
            return ""
        const kind = n.some(x => root.packageTools.indexOf(x) >= 0)
            ? (n.some(x => root.packageTools.indexOf(x) < 0) ? "an install and a download" : "an install or update")
            : "a download"
        return n.slice(0, 3).join(", ") + " is running (" + kind + ")"
    }

    onWatchingChanged: {
        if (watching)
            root.look()
        else
            root.running = []
    }

    function look() {
        if (!looker.running)
            looker.exec(["pgrep", "-lx", root.pattern])
    }

    Timer {
        running: root.watching
        interval: 3000
        repeat: true
        onTriggered: root.look()
    }

    Process {
        id: looker
        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                for (const line of text.split("\n")) {
                    const name = line.trim().split(/\s+/)[1]
                    if (name && names.indexOf(name) < 0)
                        names.push(name)
                }
                if (root.watching)
                    root.running = names
            }
        }
    }
}
