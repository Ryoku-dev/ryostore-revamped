pragma ComponentBehavior: Bound
import QtQuick
import "PythonRoster.js" as PythonRoster

Item {
    id: adapter

    property string faceId: "time"
    property string kind: "face"
    property string prefix: "pythonTime"
    property var screen: null
    property real hostX: 0
    property real hostY: 0
    property real scaleCfg: 1
    property string sizeCfg: ""
    property string inkColorA: ""
    property bool ryokuStyle: false
    property real radiusCfg: -1
    property var optionOverrides: ({})

    readonly property var rosterFace: PythonRoster.byPrefix(adapter.prefix)
    readonly property string selectedVariant: {
        const sizes = adapter.rosterFace ? adapter.rosterFace.sizes : ["default"];
        return sizes.indexOf(adapter.sizeCfg) >= 0 ? adapter.sizeCfg : sizes[0];
    }
    readonly property string selectedImage: adapter.faceId === "image"
        && typeof adapter.optionOverrides.imagePath === "string"
        ? adapter.optionOverrides.imagePath : ""
    readonly property color hostOverride: adapter.inkColorA.length > 0
        ? adapter.inkColorA : "transparent"
    readonly property int screenW: adapter.screen ? adapter.screen.width : 1920
    readonly property int screenH: adapter.screen ? adapter.screen.height : 1080

    implicitWidth: faceProvider.implicitWidth
    implicitHeight: faceProvider.implicitHeight
    width: implicitWidth
    height: implicitHeight

    PythonFaceProvider {
        id: faceProvider
        faceId: adapter.faceId
        variant: adapter.selectedVariant
        screenW: adapter.screenW
        screenH: adapter.screenH
        imagePath: adapter.selectedImage
        ryokuStyle: adapter.ryokuStyle
        inkOverride: adapter.hostOverride
        accentOverride: adapter.hostOverride
        sizeOverride: adapter.selectedVariant
        scaleOverride: adapter.scaleCfg
        radiusOverride: adapter.radiusCfg
        optionOverrides: adapter.optionOverrides
    }

    Binding {
        target: faceProvider.item
        property: "parent"
        value: adapter
        when: faceProvider.item !== null
    }
    Binding {
        target: faceProvider.item
        property: "visible"
        value: true
        when: faceProvider.item !== null
    }
}
