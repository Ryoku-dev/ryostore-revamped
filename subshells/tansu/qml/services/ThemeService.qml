pragma Singleton
import QtQuick
import Quickshell
import shell.services as Ryoku

// The Tansu bar palette follows Ryoku's live Material palette (the same one every
// other barstyle wears). Every colour below is read straight off shell.services
// Theme / Scheme, which the theme daemon keeps in step with the wallpaper, so the
// bar re-tints with the rest of the shell and never keeps a private palette.
//
// dark is derived from the surface's luminance: Ryoku has no manual dark switch,
// a light wallpaper simply yields light roles.
Singleton {
    id: root

    function lum(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    readonly property bool dark: root.lum(Ryoku.Theme.surface) < 0.5
    readonly property bool darker: false
    readonly property string mode: root.dark ? "dark" : "light"

    readonly property var palette: ({
        A: Ryoku.Theme.primary,
        B: Ryoku.Theme.tertiary,
        border: Ryoku.Theme.onSurface,
        deep: Ryoku.Theme.surface,
        divider: Ryoku.Theme.outlineVariant,
        hoverTint: Qt.rgba(Ryoku.Theme.primary.r, Ryoku.Theme.primary.g, Ryoku.Theme.primary.b, 0.12),
        rimHi: Ryoku.Theme.outline,
        bezel: Ryoku.Theme.surfaceContainerHighest,
        hardware: Ryoku.Theme.surfaceContainerLowest,
        lens: Ryoku.Theme.primary,
        glint: Ryoku.Theme.secondary,
        wallLight: Ryoku.Theme.surfaceContainerHigh,
        wallMid: Ryoku.Theme.surfaceContainer,
        wallDark: Ryoku.Theme.surfaceContainerLow,
        boardBg: Ryoku.Theme.surfaceContainerLow,
        boardDot: Ryoku.Theme.outlineVariant,
        lockMint: Ryoku.Theme.primary,
        lockPink: Ryoku.Theme.tertiary,
        mono: false
    })

    readonly property var lockPalette: root.palette
    readonly property var matugenPalette: root.palette
    readonly property var customColors: root.palette
    readonly property var current: root.palette
    readonly property var baseGroups: [ ({ name: "Ryoku", c: root.palette }) ]
    readonly property var groups: root.baseGroups
    readonly property int index: 0
    readonly property bool touched: false
    readonly property bool themeLoaded: true

    property bool systemBusy: false
    property bool firstDarkPending: false

    function firstDarkDone() {}
    function setDark(on) {}
    function setModeAndSystem(mode) {}
    function cycleModeAndSystem() { Ryoku.Nightlight.toggle() }
    function setTheme(id) {}
    function cycle() {}
    function togglePicker() {}
    function has() { return false }
    function applyPalette() {}
    function toggleDark() { Ryoku.Nightlight.toggle() }
}
