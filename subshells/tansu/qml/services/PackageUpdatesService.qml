pragma Singleton
import QtQuick
import Quickshell
import shell.services as Ryoku
import "."

// Pending updates for the bar badge, read from Ryoku's Updates singleton (the
// daemon checks ryoku status in the background, so the bar never polls). The
// update itself is the same action the shell's update widget runs: open the Hub
// on its Updates page, which owns the run.
Singleton {
    id: root

    readonly property int repoCount: Ryoku.Updates.pending
    readonly property int aurCount: 0
    readonly property int total: Ryoku.Updates.pending
    readonly property var packages: Ryoku.Updates.packages
    readonly property string status: Ryoku.Updates.available ? "ok" : "idle"
    readonly property double checkedAt: 0

    readonly property bool enabled: true
    readonly property int nudgeAt: 0
    readonly property bool nudging: false
    readonly property bool upgrading: false
    readonly property bool manual: false

    readonly property bool loadingBadge: !Ryoku.Updates.available && Ryoku.Updates.pending === 0

    readonly property string breakdown: {
        if (!Ryoku.Updates.available)
            return "up to date"
        if (Ryoku.Updates.pending === 0)
            return "up to date"
        return Ryoku.Updates.pending + (Ryoku.Updates.pending === 1 ? " update" : " updates")
    }

    function refresh(byUser) { Ryoku.Updates.check() }

    function runUpdate() {
        Quickshell.execDetached(["ryoku-shell", "hub", "open", "updates"])
    }
}
