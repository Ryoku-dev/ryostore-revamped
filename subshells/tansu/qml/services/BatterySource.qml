import Quickshell
import QtQuick
import shell.services as Ryoku
import "."

// The system side of the battery indicator, fed by Ryoku's Battery singleton
// (UPower). A desktop with no cell reports available=false and the indicator
// hides itself; the readouts otherwise match the rest of the shell.
Scope {
    id: root

    readonly property bool available: Ryoku.Battery.present
    readonly property int percentage: Ryoku.Battery.pct
    readonly property bool isCharging: Ryoku.Battery.charging
    readonly property bool isPluggedIn: Ryoku.Battery.onAc
    readonly property bool isLow: Ryoku.Battery.low

    readonly property string timeRemaining: Ryoku.Battery.timeStr
    readonly property string statusLabel: Ryoku.Battery.stateLabel
}
