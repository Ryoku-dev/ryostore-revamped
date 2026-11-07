pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import Ryoku.Ui.Singletons
import "PythonOpts.js" as PythonOpts

Column {
    id: opts

    property string widget: ""
    property var config: null
    width: parent ? parent.width : 0
    spacing: Tokens.s1

    readonly property var store: PythonOpts.read(opts.config, opts.widget)
    readonly property string variant: PythonOpts.get(opts.config, opts.widget + "Size") || "default"
    readonly property bool sineWave: opts.store.sineWave !== false
    readonly property real lineThickness: Number(opts.store.lineThickness ?? 8)

    MenuSection {
        visible: opts.variant === "circle"
        label: I18n.tr("Circle")
        gloss: "円形"
    }
    MenuRow {
        visible: opts.variant === "circle"
        label: I18n.tr("Wave edge")
        value: opts.sineWave ? I18n.tr("On") : I18n.tr("Off")
        on: opts.sineWave
        closeOnTrigger: false
        onTriggered: PythonOpts.put(opts.config, opts.widget, "sineWave", !opts.sineWave)
    }
    MenuSlider {
        id: thickness
        visible: opts.variant === "circle"
        label: I18n.tr("Line thickness")
        from: 3
        to: 16
        step: 0.5
        value: opts.lineThickness
        valueText: Number(thickness.value).toFixed(1)
        onMoved: (v) => PythonOpts.put(opts.config, opts.widget, "lineThickness", v)
        onReleased: (v) => PythonOpts.put(opts.config, opts.widget, "lineThickness", v)
    }
}
