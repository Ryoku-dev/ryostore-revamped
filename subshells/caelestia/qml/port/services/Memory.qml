pragma Singleton

import Quickshell
import shell.services as Ryoku

Singleton {
    id: root

    // Sysinfo reports GiB; Caelestia consumers pass Memory.used/total to Units.formatKibUsage.
    readonly property real _kibPerGib: 1048576

    readonly property real used: Ryoku.Sysinfo.memUsedGiB * _kibPerGib
    readonly property real total: Ryoku.Sysinfo.memTotalGiB > 0 ? Ryoku.Sysinfo.memTotalGiB * _kibPerGib : 1
    readonly property real percentage: Ryoku.Sysinfo.mem
    readonly property int updateInterval: 1500

    function ref(owner: var): void {
        Ryoku.Sysinfo.setActive(owner, true);
    }

    function unref(owner: var): void {
        Ryoku.Sysinfo.setActive(owner, false);
    }
}
