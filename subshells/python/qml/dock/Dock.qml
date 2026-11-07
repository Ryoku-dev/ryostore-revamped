import QtQuick

Item {
    id: root

    required property var screen
    property bool surfaceVisible: true
    property bool stageEditing: false
    readonly property var surface: dock.surface

    width: 0
    height: 0

    PythonDock {
        id: dock
        targetScreen: root.screen
        surfaceVisible: root.surfaceVisible
        stageEditing: root.stageEditing
    }
}
