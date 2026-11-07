import Quickshell
import QtQuick
import shell.services as Ryoku
import "."

// The system side of the resource indicator, fed by Ryoku's Sysinfo singleton
// (the same CPU / memory sampler the shell's own system monitor uses). Only
// polled while this bar shows the module or its popup is open, so an unseen
// indicator costs nothing.
Scope {
    id: root

    property bool wanted: true
    onWantedChanged: Ryoku.Sysinfo.setActive("tansu-resource", root.wanted)
    Component.onCompleted: Ryoku.Sysinfo.setActive("tansu-resource", root.wanted)

    readonly property int cpuPercent: Math.round(Ryoku.Sysinfo.cpu * 100)
    readonly property int memPercent: Math.round(Ryoku.Sysinfo.mem * 100)
    readonly property string memUsedLabel: Ryoku.Sysinfo.memUsedGiB.toFixed(1)
    readonly property string memTotalLabel: Ryoku.Sysinfo.memTotalGiB.toFixed(1)
}
