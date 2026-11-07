pragma Singleton

import QtQml
import Quickshell
import shell.services as Ryoku

Singleton {
    id: root

    readonly property int historyLength: 30
    readonly property int updateInterval: Ryoku.StatsFeed.pollMs
    readonly property real downloadSpeed: Ryoku.StatsFeed.downBps
    readonly property real uploadSpeed: Ryoku.StatsFeed.upBps
    readonly property real downloadTotal: 0
    readonly property real uploadTotal: 0

    readonly property QtObject downloadBuffer: QtObject {
        property int capacity: root.historyLength + 1
        readonly property var values: Ryoku.StatsFeed.netDownHist.slice(-capacity)
        readonly property int count: values.length
        readonly property real maximum: root._maxOf(values)

        function at(index: int): real {
            return index >= 0 && index < values.length ? values[index] : 0;
        }

        function push(value: real): void {}
        function clear(): void {}
    }

    readonly property QtObject uploadBuffer: QtObject {
        property int capacity: root.historyLength + 1
        readonly property var values: Ryoku.StatsFeed.netUpHist.slice(-capacity)
        readonly property int count: values.length
        readonly property real maximum: root._maxOf(values)

        function at(index: int): real {
            return index >= 0 && index < values.length ? values[index] : 0;
        }

        function push(value: real): void {}
        function clear(): void {}
    }

    function _maxOf(arr: var): real {
        let max = 0;
        for (let i = 0; i < arr.length; i++) {
            if (arr[i] > max)
                max = arr[i];
        }
        return max;
    }

    function ref(owner: var): void {
        Ryoku.StatsFeed.setActive(owner, true);
    }

    function unref(owner: var): void {
        Ryoku.StatsFeed.setActive(owner, false);
    }
}
