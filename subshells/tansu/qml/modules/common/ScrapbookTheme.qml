pragma Singleton
import QtQuick
import "../../services"

QtObject {
    id: root

    readonly property color page: "#f5eeda"
    readonly property color ink: "#4a4536"

    readonly property color tapeTeal: "#7fb8bd"
    readonly property color tapeCoral: "#e8886f"
    readonly property color tapeMint: "#b7d99a"
    readonly property color tag: "#eec25e"          // mustard hang-tag
    readonly property color accentCurrent: "#3fa7c4"

    readonly property color cork: "#c99a63"
    readonly property color corkLight: "#dfb883"
    readonly property color corkDark: "#a97b48"
    readonly property color corkSpeck: "#6f4a29"
    readonly property color frameWood: "#9b6a3f"
    readonly property color frameHighlight: "#bd8a58"
    readonly property color frameShade: "#5b3c22"
    readonly property color noteShadow: "#4d3220"
    readonly property color pinPink: "#d98cc0"

    readonly property color filmBase: "#18171c"
    readonly property color filmEdge: "#0b0a0e"
    readonly property color filmFrame: "#232229"
    readonly property color filmScreen: "#2b2a33"
    readonly property color filmScreenHover: "#2f4a3a"
    readonly property color filmHole: "#e9e3d2"
    readonly property color filmHoleShade: "#a39d8b"
    readonly property color filmPrint: "#f0a63c"
    readonly property color filmPrintSoft: "#88f0e8d6"

    readonly property color boardBg: ThemeService.palette.boardBg
    readonly property color boardBgClear: Qt.rgba(boardBg.r, boardBg.g, boardBg.b, 0)
    readonly property color boardDot: ThemeService.palette.boardDot
    readonly property color tapePink: "#f4a3c8"
    readonly property color accentPink: "#ff8fd6"
    readonly property color labelPaper: "#fffdf7"
    readonly property color inkSoft: "#8b8aa6"
}
