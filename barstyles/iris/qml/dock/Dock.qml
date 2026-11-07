import QtQuick
import shell.services as Ryoku
import inir.modules.iris.dock as ShimaDock

Item {
    id: root

    required property var screen
    property bool surfaceVisible: true
    property bool stageEditing: false
    readonly property var surface: dockSurface.surface

    width: 0
    height: 0

    ShimaDock.IrisDockSurface {
        id: dockSurface
        screen: root.screen
        surfaceVisible: root.surfaceVisible
        stageEditing: root.stageEditing
        frameReserves: Ryoku.Config.barStyle === "iris"
    }
}
