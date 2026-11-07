pragma Singleton
import QtQuick
import shell.services as Ryoku
import Ryoku.Ui.Singletons as Ui

QtObject {
    readonly property color brand: "#e2342a"
    readonly property color gold: "#d9a441"
    readonly property color accent: Ryoku.Theme.primary
    readonly property color bone: Ui.Tokens.bone
    readonly property color inkOnBone: Ui.Tokens.inkOnBone
    readonly property color ink: Ryoku.Theme.onSurface
    readonly property color inkDim: Ryoku.Theme.onSurfaceVariant
    readonly property color inkSoft: Qt.rgba((ink.r + inkDim.r) / 2, (ink.g + inkDim.g) / 2, (ink.b + inkDim.b) / 2, 1)
    readonly property color faint: Qt.rgba(ink.r, ink.g, ink.b, 0.42)
    readonly property color surface: Ryoku.Theme.surface
    readonly property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.16)
    readonly property color lineStrong: Qt.rgba(ink.r, ink.g, ink.b, 0.42)
    readonly property color tile: Qt.rgba(ink.r, ink.g, ink.b, 0.06)
    readonly property color tileHover: Qt.rgba(ink.r, ink.g, ink.b, 0.10)
    readonly property color tilePress: Qt.rgba(ink.r, ink.g, ink.b, 0.16)

    readonly property string font: Ryoku.Config.fontFamily.length > 0 ? Ryoku.Config.fontFamily : "Space Grotesk"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "Material Symbols Rounded"

    readonly property int s1: Ui.Tokens.s1
    readonly property int s2: Ui.Tokens.s2
    readonly property int s3: Ui.Tokens.s3
    readonly property int s5: Ui.Tokens.s5
    readonly property int s7: Ui.Tokens.s7
    readonly property int ctlH: Ui.Tokens.ctlH
    readonly property int menuTileRadius: Ui.Tokens.radius
    readonly property int fSmall: Ui.Tokens.fSmall
    readonly property int fMicro: Ui.Tokens.fMicro
    readonly property real trackMark: Ui.Tokens.trackMark
    readonly property int quick: 140
}
