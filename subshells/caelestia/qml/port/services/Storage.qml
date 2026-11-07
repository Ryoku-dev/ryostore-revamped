pragma Singleton

import QtQml
import Quickshell
import shell.services as Ryoku

Singleton {
    id: root

    // StatsFeed reports `/` in GiB; Caelestia consumers pass DiskInfo.used/total to Units.formatKibUsage.
    readonly property real _kibPerGib: 1048576

    readonly property var disks: Ryoku.StatsFeed.diskTotalGiB > 0 ? [rootDisk] : []
    property DiskInfo manualPrimaryDisk: null
    readonly property DiskInfo primaryDisk: manualPrimaryDisk ?? (Ryoku.StatsFeed.diskTotalGiB > 0 ? rootDisk : null)
    readonly property real percentage: rootDisk.perc
    readonly property int updateInterval: 30000

    function ref(owner: var): void {
        Ryoku.StatsFeed.setActive(owner, true);
    }

    function unref(owner: var): void {
        Ryoku.StatsFeed.setActive(owner, false);
    }

    DiskInfo {
        id: rootDisk

        mount: "/"
        used: Ryoku.StatsFeed.diskUsedGiB * root._kibPerGib
        total: Ryoku.StatsFeed.diskTotalGiB * root._kibPerGib
        hasRoot: true
    }
}
