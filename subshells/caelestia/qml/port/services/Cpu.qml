pragma Singleton

import Quickshell
import shell.services as Ryoku

Singleton {
    readonly property string name: ""
    readonly property real percentage: Ryoku.Sysinfo.cpu
    readonly property real temperature: Ryoku.Sysinfo.tempC
    readonly property int updateInterval: 1500

    function ref(owner: var): void {
        Ryoku.Sysinfo.setActive(owner, true);
    }

    function unref(owner: var): void {
        Ryoku.Sysinfo.setActive(owner, false);
    }
}
