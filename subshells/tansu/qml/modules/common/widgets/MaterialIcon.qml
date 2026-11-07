import QtQuick
import QtQuick.Controls.impl
import "../../../modules/common"
import "../functions/IconMap.js" as IconMap

// One icon, drawn from the Solar Icon Set (assets/icons: `bold` and `outline`
// folders, SVG).
//
//   MaterialIcon { name: "wifi_off"; size: 24 }
//
// `name` is still the Material Symbols name the shell has always used, so no
// page had to change: IconMap.js says which Solar file stands for it (a name
// that is already a Solar file name, with _ for -, needs no entry there). It's
// a vector image, so it stays crisp at any size and under the Quick Panel's
// tilt.
//
// `fill` picks the file: 0 = the style chosen in Settings (outline, broken, line
// duotone or bold duotone), 1 = bold (the Solar "Bold" set plays the part of
// FILL 1). If a name has no file in that style it tries outline, then bold, and
// a name with no Solar icon at all is still written as text in the
// "Material Symbols Rounded" font, as before.
//
// Colour is `color` (the mode's ink by default: navy in light mode, pale in dark), so hover / muted /
// on-a-dark-pill looks are just a colour, not a second asset.
//
// The look of every icon in the shell is set in one place, Theme.qml
// (iconFill); `fill` here overrides it for a single icon. `weight` is only
// used by the font fallback (the Solar files have one weight each).
Text {
    id: root

    property string name: ""
    property real size: 24
    property real fill: Theme.iconFill
    property real weight: Theme.iconWeight

    readonly property real drawSize: Theme.capsuleFor(root) ? Math.min(size, 16) : size

    readonly property bool filled: root.fill >= 0.5
    readonly property var solarFiles: IconMap.candidates(root.name, root.filled, Theme.iconStyle)

    property int attempt: 0
    onSolarFilesChanged: root.attempt = 0

    readonly property real faceSize: Math.round(root.drawSize * 0.88)
    readonly property real facePixels: root.faceSize * (Math.ceil(Screen.devicePixelRatio) + 1)
    readonly property bool textFallback: root.attempt >= root.solarFiles.length
    readonly property string iconFile:
        root.name === "" || root.textFallback ? ""
        : "file://" + Directories.asset(root.solarFiles[root.attempt])

    width: drawSize
    height: drawSize
    text: root.textFallback ? name : ""
    color: Theme.classicFor(root) ? Theme.pInk : Theme.ink
    // Only the font glyph is clipped. Clipping the item also clips the image
    // below, and an image inside a clipped node goes unpainted for the first
    // seconds after the Quick Panel's layer is mapped.
    clip: root.textFallback

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    font.family: Theme.iconFont
    font.pixelSize: drawSize
    font.hintingPreference: Font.PreferFullHinting
    font.variableAxes: ({
        "FILL": root.fill,
        "wght": root.weight,
        "opsz": Math.max(20, Math.min(48, root.drawSize)),
        "GRAD": 0
    })

    ColorImage {
        x: Math.floor((root.width - root.faceSize) / 2)
        y: Math.floor((root.height - root.faceSize) / 2)
        width: root.faceSize
        height: root.faceSize
        visible: !root.textFallback && root.name !== ""
        color: root.color
        fillMode: Image.PreserveAspectFit
        mipmap: false
        sourceSize: Qt.size(root.facePixels, root.facePixels)
        source: root.iconFile
        onStatusChanged: {
            if (status === Image.Error && !root.textFallback)
                Qt.callLater(() => root.attempt++)
        }
    }
}
