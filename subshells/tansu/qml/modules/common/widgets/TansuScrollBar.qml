import QtQuick
import "../../../modules/common"

Rectangle {
    id: bar

    property var view: parent ? parent.parent : null
    property real margin: 8
    property real inset: 2

    readonly property bool flickable: view !== null && view !== undefined && view.visibleArea !== undefined
    readonly property real ratio: flickable ? view.visibleArea.heightRatio : 1
    readonly property real track: view ? view.height - 2 * margin : 0

    visible: flickable && ratio < 1 && track > 40
    z: 100
    width: 6
    radius: 3
    color: Theme.pSurfaceRing
    antialiasing: true

    x: flickable ? view.contentX + view.width - width - inset : 0
    y: flickable ? view.contentY + margin + view.visibleArea.yPosition * track : 0
    height: Math.max(30, ratio * track)
}
