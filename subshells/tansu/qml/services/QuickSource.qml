import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import shell.services as Ryoku
import "../modules/common/functions/QuickTiles.js" as QT
import "."

// What the phone's Quick screen shows and does, wired to Ryoku's own services:
// Network, Bluetooth, Audio, Nightlight, PowerProfiles, Devices, SessionActions
// and Notifs. Every tile with no Ryoku backend was dropped from the default
// panel, so a clickable control always has something real behind it.
Scope {
    id: root

    property bool active: false
    property var targetScreen: null
    onActiveChanged: {
        Ryoku.Network.setTrafficActive("tansu-quick", root.active)
        if (root.active)
            Ryoku.Devices.startProbes("tansu-quick")
        else
            Ryoku.Devices.stopProbes("tansu-quick")
        root.audioMixerActive = false
        root.editing = false
    }

    readonly property string userName: Ryoku.Session.user
    readonly property string hostName: Ryoku.Session.host

    readonly property bool wifiOn: Ryoku.Network.wifiRadio
    readonly property string wifiName: Ryoku.Network.kind === "wifi" ? Ryoku.Network.activeSsid : ""
    readonly property string ethernetName: Ryoku.Network.kind === "ethernet" ? "Ethernet" : ""
    readonly property string networkKind: Ryoku.Network.kind === "ethernet" ? "ethernet" : "wifi"
    readonly property bool networkOn: root.networkKind === "ethernet" ? true : Ryoku.Network.wifiRadio
    readonly property string networkDetail: {
        const net = Ryoku.Network
        if (!net.wifiPresent && net.kind === "")
            return "OFF"
        if (net.kind === "ethernet")
            return "Connected"
        if (net.wifiConnectivity === "Connected" && net.activeSsid !== "")
            return net.activeSsid
        return net.wifiRadio ? "Not connected" : "OFF"
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: root.btAdapter !== null && root.btAdapter.enabled
    readonly property var btDeviceList: (Bluetooth.devices && root.bluetoothOn) ? Bluetooth.devices.values : []
    readonly property string bluetoothDevice: {
        for (let i = 0; i < root.btDeviceList.length; i++)
            if (root.btDeviceList[i].connected)
                return root.btDeviceList[i].name || root.btDeviceList[i].address || ""
        return ""
    }
    readonly property string bluetoothDetail: root.bluetoothOn
        ? (root.bluetoothDevice !== "" ? root.bluetoothDevice : "ON") : "OFF"

    // ===== audio =====
    // Ryoku's Audio singleton already tracks every node it lists (sink, source,
    // devices and streams), so volumes and mutes here read live.
    readonly property var sinkAudio: Ryoku.Audio.sink ? Ryoku.Audio.sink.audio : null
    readonly property var sourceAudio: Ryoku.Audio.source ? Ryoku.Audio.source.audio : null
    readonly property bool speakerOn: root.sinkAudio ? !root.sinkAudio.muted : false
    readonly property bool microphoneOn: root.sourceAudio ? !root.sourceAudio.muted : false
    readonly property real speakerVolume: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) : 0
    readonly property real microphoneVolume: root.sourceAudio ? Math.round(root.sourceAudio.volume * 100) : 0

    readonly property real brightness: Ryoku.Devices.backlightAvailable ? Ryoku.Devices.backlightPct : 100
    readonly property real gamma: Ryoku.Nightlight.on
        ? Math.round(Math.max(10, Math.min(100, 100 - (6500 - Ryoku.Nightlight.temperature) / 40))) : 100

    readonly property bool nightLightOn: Ryoku.Nightlight.on
    property int nightLightTemperatureCached: 4500
    readonly property int nightLightTemperature: Ryoku.Nightlight.temperature
    readonly property bool nightLightAuto: Ryoku.Nightlight.schedule === "sun"
    property int nightLightAutoFrom: 20
    property int nightLightAutoTo: 6

    readonly property string powerProfileName: Ryoku.PowerProfiles.profile === "power-saver" ? "saver"
        : (Ryoku.PowerProfiles.profile === "performance" ? "performance" : "balanced")

    readonly property bool keepAwakeOn: Ryoku.Flags.keepAwake

    readonly property bool notificationsOn: !Ryoku.Notifs.dnd

    readonly property var tiles: QT.sanitize(SettingsService.get("quick.tiles", QT.defaultTiles), root.tileColumns)
    readonly property int tileColumns: QT.clampColumns(SettingsService.get("quick.tileColumns", QT.defaultColumns))

    property bool editing: false

    // Features with no Ryoku backend stay as inert defaults so the UI has
    // something to bind to while their buttons are out of the default panel.
    readonly property bool gameModeOn: false
    readonly property bool darkModeOn: false
    readonly property string darkModeName: Ryoku.Nightlight.on ? "dark" : "light"
    readonly property bool easyEffectsOn: false
    readonly property bool warpOn: false
    readonly property bool warpConnecting: false
    readonly property bool warpInstalled: false
    readonly property bool keyboardOn: false
    readonly property bool musicListening: false
    readonly property bool antiFlashbangOn: false
    readonly property int antiFlashbangLevel: 0
    readonly property bool nightLightDialogOpen: false

    readonly property var wifiNetworks: {
        const list = Ryoku.Network.accessPoints || []
        const out = []
        for (let i = 0; i < list.length; i++) {
            const ap = list[i]
            if (!ap || !ap.ssid)
                continue
            out.push({
                ssid: ap.ssid,
                signal: Number(ap.strength || 0),
                secured: !(String(ap.security || "").toLowerCase() === ""
                    || String(ap.security || "").toLowerCase() === "none"),
                connected: ap.active === true
            })
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal))
        return out
    }
    property bool wifiScanning: false
    property bool wifiManualScanning: false
    property bool networkDialogOpen: false
    property string wifiConnectingSsid: ""
    property string wifiConnectError: ""

    readonly property var bluetoothDevices: {
        const list = root.btDeviceList
        const out = []
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            out.push({
                address: d.address || "",
                name: d.name || d.address || "",
                connected: d.connected === true,
                battery: Ryoku.BtLink.batteryLevel(d)
            })
        }
        out.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
        return out
    }
    property bool bluetoothScanning: false
    property bool bluetoothManualScanning: false
    property bool bluetoothDialogOpen: false
    property string bluetoothConnectingAddress: ""
    property string bluetoothConnectError: ""

    readonly property var speakerDevices: Ryoku.Audio.outputs.map(n => ({
        id: n.name, name: Ryoku.Audio.nodeLabel(n), active: n === Ryoku.Audio.sink
    }))
    readonly property var microphoneDevices: Ryoku.Audio.inputs.map(n => ({
        id: n.name, name: Ryoku.Audio.nodeLabel(n), active: n === Ryoku.Audio.source
    }))
    readonly property var speakerStreams: Ryoku.Audio.streams.map(n => ({
        id: String(n.id),
        name: Ryoku.Audio.streamName(n),
        volume: n.audio ? Math.round(n.audio.volume * 100) : 0,
        muted: n.audio ? n.audio.muted : false,
        corked: n.audio ? n.audio.corked : false
    }))
    readonly property var microphoneStreams: Ryoku.Audio.captureStreams.map(n => ({
        id: String(n.id),
        name: Ryoku.Audio.streamName(n),
        volume: n.audio ? Math.round(n.audio.volume * 100) : 0,
        muted: n.audio ? n.audio.muted : false,
        corked: n.audio ? n.audio.corked : false
    }))
    readonly property bool audioDevicesScanning: false
    property bool audioDevicesManualScanning: false
    property string audioDeviceSelectingId: ""
    property bool audioMixerActive: false

    readonly property real downloadBps: root.active ? Ryoku.Network.downBps : 0
    readonly property real uploadBps: root.active ? Ryoku.Network.upBps : 0

    function refresh() {}

    function toggleNetwork() {
        Ryoku.Network.setWifiEnabled(!Ryoku.Network.wifiRadio)
    }

    function toggleBluetooth() {
        if (root.btAdapter)
            root.btAdapter.enabled = !root.btAdapter.enabled
    }

    function toggleSpeaker() {
        if (root.sinkAudio)
            root.sinkAudio.muted = !root.sinkAudio.muted
    }

    function toggleMicrophone() {
        if (root.sourceAudio)
            root.sourceAudio.muted = !root.sourceAudio.muted
    }

    function setSpeakerVolume(percent) {
        if (root.sinkAudio)
            root.sinkAudio.volume = Math.max(0, Math.min(1, percent / 100))
    }

    function setMicrophoneVolume(percent) {
        if (root.sourceAudio)
            root.sourceAudio.volume = Math.max(0, Math.min(1, percent / 100))
    }

    function setBrightness(percent) {
        Ryoku.Devices.setBacklight(percent)
    }

    function setGamma(percent) {
        const k = 2500 + Math.max(0, Math.min(100, percent)) * 40
        if (percent >= 100) {
            if (Ryoku.Nightlight.on)
                Ryoku.Nightlight.setEnabled(false)
            Ryoku.Nightlight.setTemperature(k)
        } else {
            Ryoku.Nightlight.setEnabled(true, k)
        }
    }

    function toggleKeepAwake() {
        Ryoku.Flags.keepAwake = !Ryoku.Flags.keepAwake
    }

    function toggleNotifications() {
        Ryoku.Flags.dnd = !Ryoku.Flags.dnd
    }

    function toggleEditing() { root.editing = !root.editing }

    function toggleNightLight() {
        Ryoku.Nightlight.toggle()
    }

    function setNightLight(on) {
        Ryoku.Nightlight.setEnabled(on === true)
    }

    function setNightLightTemperature(kelvin) {
        Ryoku.Nightlight.setTemperature(kelvin)
    }

    function setNightLightAuto(on) {
        Ryoku.Nightlight.setSchedule(on === true)
    }

    function setNightLightSchedule(from, to) {
        root.nightLightAutoFrom = from
        root.nightLightAutoTo = to
    }

    function toggleGameMode() {}
    function toggleDarkMode() { Ryoku.Nightlight.toggle() }
    function toggleEasyEffects() {}
    function toggleWarp() {}
    function toggleKeyboard() {}
    function toggleMusicRecognition() {}
    function toggleAntiFlashbang() {}

    function cyclePowerProfile() {
        const list = Ryoku.PowerProfiles.profiles
        if (list.length === 0)
            return
        const at = list.indexOf(Ryoku.PowerProfiles.profile)
        Ryoku.PowerProfiles.setProfile(list[(at + 1) % list.length])
    }

    function runTileAction(id) {
        if (id === "screenSnip")
            Ryoku.Capture.shoot("region")
        else if (id === "colorPicker")
            Quickshell.execDetached(["ryoku-cmd-color-picker"])
    }

    function setTiles(list) {
        SettingsService.set("quick.tiles", list)
    }

    function setTileColumns(columns) {
        const c = QT.clampColumns(columns)
        if (c === root.tileColumns || !QT.fits(root.tiles, c))
            return
        SettingsService.set("quick.tileColumns", c)
    }

    function indexOfTile(id) {
        for (let i = 0; i < root.tiles.length; i++)
            if (root.tiles[i].id === id)
                return i
        return -1
    }

    function moveTile(from, to) {
        if (from < 0 || from >= root.tiles.length || to < 0 || to >= root.tiles.length || from === to)
            return
        const list = root.tiles.slice()
        const moved = list.splice(from, 1)[0]
        list.splice(to, 0, moved)
        root.setTiles(list)
    }

    function resizeTile(index) {
        if (index < 0 || index >= root.tiles.length)
            return
        const size = QT.nextSize(root.tiles, index, root.tileColumns)
        if (size === root.tiles[index].size)
            return
        const list = root.tiles.map(t => ({ id: t.id, size: t.size }))
        list[index].size = size
        root.setTiles(list)
    }

    function removeTile(index) {
        if (index < 0 || index >= root.tiles.length)
            return
        const list = root.tiles.slice()
        list.splice(index, 1)
        root.setTiles(list)
    }

    function addTile(id) {
        if (QT.catalog.indexOf(id) < 0 || root.indexOfTile(id) >= 0)
            return
        const list = root.tiles.concat([{ id: id, size: "small" }])
        if (!QT.fits(list, root.tileColumns))
            return
        root.setTiles(list)
    }

    Timer { id: wifiScanDone; interval: 4000; onTriggered: { root.wifiScanning = false; root.wifiManualScanning = false } }
    function scanWifi(forceRescan, manual) {
        root.wifiScanning = true
        root.wifiManualScanning = manual === true
        Ryoku.Network.refresh()
        wifiScanDone.restart()
    }
    function connectWifi(ssid, password) {
        root.wifiConnectingSsid = ssid
        root.wifiConnectError = ""
        Ryoku.Network.connectWifi(ssid, password || "")
        wifiConnectDone.restart()
    }
    function disconnectWifi(ssid) { Ryoku.Network.disconnectWifi() }
    Timer {
        id: wifiConnectDone
        interval: 6000
        onTriggered: {
            root.wifiConnectingSsid = ""
            if (Ryoku.Network.wifiConnectivity !== "Connected")
                root.wifiConnectError = "Couldn't connect"
        }
    }
    function openNetworkSettings() { Quickshell.execDetached(["ryoku-shell", "hub", "open", "network"]) }

    Timer { id: btScanDone; interval: 12000; onTriggered: { if (root.btAdapter) root.btAdapter.discovering = false; root.bluetoothScanning = false; root.bluetoothManualScanning = false } }
    function scanBluetooth(manual) {
        if (!root.btAdapter)
            return
        root.bluetoothScanning = true
        root.bluetoothManualScanning = manual === true
        root.btAdapter.discovering = true
        btScanDone.restart()
    }
    function connectBluetoothDevice(address) {
        root.bluetoothConnectingAddress = address
        root.bluetoothConnectError = ""
        for (let i = 0; i < root.btDeviceList.length; i++)
            if (root.btDeviceList[i].address === address)
                root.btDeviceList[i].connect()
        btConnectDone.restart()
    }
    function disconnectBluetoothDevice(address) {
        for (let i = 0; i < root.btDeviceList.length; i++)
            if (root.btDeviceList[i].address === address)
                root.btDeviceList[i].disconnect()
    }
    Timer {
        id: btConnectDone
        interval: 8000
        onTriggered: {
            root.bluetoothConnectingAddress = ""
            if (root.bluetoothDevice === "")
                root.bluetoothConnectError = "Couldn't connect"
        }
    }
    function openBluetoothSettings() { Quickshell.execDetached(["ryoku-shell", "hub", "open", "bluetooth"]) }

    function scanAudioDevices(manual) { root.audioDevicesManualScanning = manual === true }
    function setDefaultSink(id) {
        for (let i = 0; i < Ryoku.Audio.outputs.length; i++)
            if (Ryoku.Audio.outputs[i].name === id)
                Ryoku.Audio.setOutput(Ryoku.Audio.outputs[i])
    }
    function setDefaultSource(id) {
        for (let i = 0; i < Ryoku.Audio.inputs.length; i++)
            if (Ryoku.Audio.inputs[i].name === id)
                Ryoku.Audio.setInput(Ryoku.Audio.inputs[i])
    }
    function nodeFor(kind, id) {
        const list = kind === "microphone" ? Ryoku.Audio.captureStreams : Ryoku.Audio.streams
        for (let i = 0; i < list.length; i++)
            if (String(list[i].id) === String(id))
                return list[i]
        return null
    }
    function setStreamVolume(kind, id, value) {
        const n = root.nodeFor(kind, id)
        if (n && n.audio)
            n.audio.volume = Math.max(0, Math.min(1, value / 100))
    }
    function setStreamMuted(kind, id, muted) {
        const n = root.nodeFor(kind, id)
        if (n && n.audio)
            n.audio.muted = muted === true
    }
    function beginStreamDrag(kind, id) {}
    function endStreamDrag(kind, id) {}

    function powerOff() { Ryoku.SessionActions.run("shutdown") }
    function reboot() { Ryoku.SessionActions.run("reboot") }
    function logout() { Ryoku.SessionActions.run("logout") }
    function lock() { Ryoku.SessionActions.run("lock") }
    function sleep() { Ryoku.SessionActions.run("suspend") }
    function hibernate() { Ryoku.SessionActions.run("suspend") }
    function lockThen(action) { Ryoku.SessionActions.run(action) }
    function runPending() {}
    function firmwareReboot() { Ryoku.SessionActions.run("reboot") }
    function openSystemMonitor() { Quickshell.execDetached(["ryoku-shell", "hub", "open", "system"]) }
}
