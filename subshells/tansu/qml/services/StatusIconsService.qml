pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import shell.services as Ryoku
import "."

// What the bar's status pill shows: Wi-Fi / Ethernet, Bluetooth and the speaker,
// each with a glyph and a line of detail for the hover tag. Every value comes
// from Ryoku's own services (Network, Bluetooth, Audio), so the bar agrees with
// the rest of the shell and starts no nmcli / bluetoothctl subprocess.
Singleton {
    id: root

    readonly property bool networkShown: Ryoku.Network.wifiPresent || Ryoku.Network.wired.present
    readonly property string networkIcon: {
        if (Ryoku.Network.kind === "ethernet")
            return "settings_ethernet"
        if (Ryoku.Network.kind === "wifi")
            return "wifi"
        return Ryoku.Network.wifiRadio ? "wifi_find" : "wifi_off"
    }
    readonly property string networkState: {
        if (Ryoku.Network.kind !== "")
            return "on"
        return Ryoku.Network.wifiRadio ? "idle" : "off"
    }
    readonly property string networkDetail: {
        const parts = []
        if (Ryoku.Network.wifiConnectivity === "Connected" && Ryoku.Network.activeSsid !== "")
            parts.push("Wi-Fi: " + Ryoku.Network.activeSsid)
        if (Ryoku.Network.kind === "ethernet")
            parts.push("Ethernet: connected")
        if (parts.length > 0)
            return parts.join("   ·   ")
        return Ryoku.Network.wifiRadio ? "Wi-Fi: not connected" : "Wi-Fi: off"
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothShown: root.adapter !== null
    readonly property bool bluetoothOn: root.adapter !== null && root.adapter.enabled
    readonly property string bluetoothDevice: {
        if (!root.bluetoothOn || !Bluetooth.devices)
            return ""
        const list = Bluetooth.devices.values
        for (let i = 0; i < list.length; i++)
            if (list[i].connected)
                return list[i].name || list[i].address || ""
        return ""
    }

    readonly property string bluetoothIcon: !root.bluetoothOn ? "bluetooth_disabled"
        : (root.bluetoothDevice !== "" ? "bluetooth_connected" : "bluetooth")
    readonly property string bluetoothState: !root.bluetoothOn ? "off"
        : (root.bluetoothDevice !== "" ? "on" : "idle")
    readonly property string bluetoothDetail: !root.bluetoothOn ? "Bluetooth: off"
        : (root.bluetoothDevice !== "" ? "Bluetooth: " + root.bluetoothDevice
                                       : "Bluetooth: on, nothing connected")

    readonly property var sinkAudio: Ryoku.Audio.sink ? Ryoku.Audio.sink.audio : null
    readonly property bool speakerShown: root.sinkAudio !== null
    readonly property bool speakerMuted: root.sinkAudio ? root.sinkAudio.muted : false
    readonly property int speakerPercent: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) : 0

    readonly property string speakerIcon: root.speakerMuted || root.speakerPercent <= 0 ? "volume_off"
        : (root.speakerPercent < 34 ? "volume_down" : "volume_up")
    readonly property string speakerState: root.speakerMuted || root.speakerPercent <= 0 ? "off" : "on"
    readonly property string speakerDetail: root.speakerMuted ? "Speaker: muted"
        : "Speaker: " + root.speakerPercent + "%"

    readonly property string detail: {
        const lines = []
        if (root.networkShown)
            lines.push(root.networkDetail)
        if (root.bluetoothShown)
            lines.push(root.bluetoothDetail)
        if (root.speakerShown)
            lines.push(root.speakerDetail)
        return lines.join("\n")
    }

    property int watchers: 0
    function watch(delta) {
        root.watchers = Math.max(0, root.watchers + delta)
    }
    function refresh() {}
}
