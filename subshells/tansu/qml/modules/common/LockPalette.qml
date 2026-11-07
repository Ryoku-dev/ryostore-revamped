pragma Singleton
import QtQuick
import "../../services"

QtObject {
    id: root

    readonly property var p: ThemeService.lockPalette

    readonly property color cBorder: Qt.color(p.border)
    readonly property color cA: Qt.color(p.A)
    readonly property color cB: Qt.color(p.B)
    readonly property color cDeep: Qt.color(p.deep)
    readonly property color cRim: Qt.color(p.rimHi)
    readonly property color cGlint: Qt.color(p.glint)
    readonly property color cWall: Qt.color(p.wallMid)

    function hue(c) { return c.hslHue < 0 ? 0 : c.hslHue }
    function hsl(h, s, l, a) { return Qt.hsla(h, (p && p.mono === true) ? 0 : Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l)), a === undefined ? 1 : a) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property color mint: p.lockMint !== undefined ? Qt.color(p.lockMint)
                                : hsl(hue(cB), Math.min(cB.hslSaturation, 0.75), 0.72)
    readonly property color mintDeep: hsl(hue(mint), 0.6, 0.52)
    readonly property color pink: p.lockPink !== undefined ? Qt.color(p.lockPink)
                                : hsl(hue(cA), Math.min(cA.hslSaturation, 0.95), 0.73)
    readonly property color paper: hsl(hue(cB), 0.6, 0.99)

    readonly property color panel: alpha(Qt.darker(cBorder, 1.15), 0.85)
    readonly property color panelEdge: alpha(cRim, 0.4)
    readonly property color divider: alpha(cBorder, 0.5)
    readonly property color cap: alpha(Qt.darker(cBorder, 1.2), 0.85)
    readonly property color well: Qt.darker(cBorder, 1.35)

    readonly property color periwinkle: cGlint
    readonly property color band: hsl(hue(cGlint), Math.min(cGlint.hslSaturation, 0.6), 0.62, 0.55)
    readonly property color bandClear: alpha(band, 0)
    readonly property color lavenderText: hsl(hue(cGlint), 0.8, 0.89)

    readonly property color shadow: alpha(cDeep, 0.25)

    readonly property color scrimBase: Qt.darker(cBorder, 1.45)
    readonly property color scrimTop: alpha(scrimBase, 0.1)
    readonly property color scrimClear: alpha(scrimBase, 0)
    readonly property color scrimBottom: alpha(scrimBase, 0.6)

    readonly property color fallbackTop: Qt.lighter(cWall, 1.1)
    readonly property color fallbackBottom: Qt.darker(cBorder, 1.6)

    readonly property color sparkle: hsl(hue(cA), 1, 0.94)

    readonly property color calPaper: hsl(hue(cGlint), 0.45, 0.91)
    readonly property color calAccent: hsl(hue(pink), Math.max(0.7, Math.min(1, pink.hslSaturation)), 0.58)
    readonly property color calMint: hsl(hue(mint), Math.max(0.6, Math.min(1, mint.hslSaturation)), 0.66)
    readonly property color calLilac: hsl(hue(cGlint), 0.75, 0.74)
    readonly property color calMuted: alpha(cBorder, 0.7)
}
