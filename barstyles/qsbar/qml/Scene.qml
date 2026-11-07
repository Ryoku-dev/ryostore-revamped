// QS Bar (Quickshell Rise) entry on Ryoku's bar style contract.
//
// item.toml asks for frameHost "primary", so Ryoku hosts exactly one Scene, on
// the primary output. VariantRoot fans one bar across every screen itself, so
// multi-monitor behaviour is unchanged.
//
// The bar form (islands, full, fit, dock, notch) is a Theme property, not a
// separate implementation. IpcRouter owns the bar's runtime IPC targets;
// core/SettingsIpc owns the qsbar settings target.

import QtQuick
import "."
import "core"

Item {
    id: sceneRoot

    // The screen, set by the host's Loader.
    property var modelData: null

    width: 0
    height: 0

    VariantRoot {
        id: barRoot
    }

    IpcRouter {
        barRoot: barRoot
    }
}
