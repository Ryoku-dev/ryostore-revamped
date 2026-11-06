pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
        || ((Quickshell.env("HOME") || "") + "/.local/state")
    readonly property string labDir: stateHome + "/ryoku/lab"

    property string tunIPv4: ""
    property string target: ""
    property string targetName: ""
    property bool initialAddressSeen: false

    readonly property bool tunnelUp: tunIPv4.length > 0
    readonly property string tunnelLabel: tunnelUp ? tunIPv4 : qsTr("no vpn")
    readonly property string barText: target.length > 0
        ? tunnelLabel + "  \u2192  " + target
        : tunnelLabel
    readonly property string preferredCopy: target.length > 0 ? target : tunIPv4

    function firstLine(raw) {
        const line = String(raw || "").split("\n")[0].trim();
        return line.length > 80 ? line.slice(0, 80) : line;
    }

    function validIPv4(value) {
        const parts = String(value || "").split(".");
        if (parts.length !== 4)
            return false;
        for (let i = 0; i < parts.length; i++) {
            if (!/^\d{1,3}$/.test(parts[i]))
                return false;
            const octet = Number(parts[i]);
            if (octet < 0 || octet > 255)
                return false;
        }
        return true;
    }

    function loadTarget(raw) {
        const value = firstLine(raw).split(/\s+/)[0] || "";
        target = validIPv4(value) ? value : "";
    }

    function loadTargetName(raw) {
        targetName = firstLine(raw);
    }

    function applyAddressLine(raw) {
        const line = String(raw || "").trim();
        if (!/(^|\s)tun0(\s|$)/.test(line))
            return;

        const match = line.match(/\binet\s+([0-9.]+)\/\d+\b/);
        const address = match && validIPv4(match[1]) ? match[1] : "";
        if (/^Deleted\b/.test(line)) {
            if (address.length === 0 || tunIPv4 === address)
                tunIPv4 = "";
            return;
        }
        if (address.length > 0)
            tunIPv4 = address;
    }

    function copy(value) {
        const text = String(value || "");
        if (text.length > 0)
            Quickshell.execDetached(["wl-copy", text]);
    }

    function copyPreferred() { copy(preferredCopy); }
    function copyTunnel() { copy(tunIPv4); }
    function copyTarget() { copy(target); }

    FileView {
        id: targetFile
        path: svc.labDir + "/target"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: svc.loadTarget(text())
        onLoadFailed: svc.target = ""
    }

    FileView {
        id: targetNameFile
        path: svc.labDir + "/target.name"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: svc.loadTargetName(text())
        onLoadFailed: svc.targetName = ""
    }

    Process {
        id: initialAddress
        command: ["ip", "-4", "-o", "addr", "show", "dev", "tun0"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                svc.initialAddressSeen = true;
                svc.applyAddressLine(line);
            }
        }
        onExited: {
            if (!svc.initialAddressSeen)
                svc.tunIPv4 = "";
        }
    }

    Process {
        id: addressMonitor
        command: ["ip", "-4", "-o", "monitor", "address"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => svc.applyAddressLine(line)
        }
    }
}
