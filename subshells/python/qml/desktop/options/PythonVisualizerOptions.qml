pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import Ryoku.Ui.Singletons
import "PythonOpts.js" as PythonOpts

// Serpantinum's "stretch width": the visualizer spans its output edge to edge. The face takes the
// screen's width (PythonFaceProvider) and the slot is pinned to the left edge at its natural scale,
// so the spectrum lines up with the screen instead of a dragged position.
Column {
    id: opts

    property string widget: ""
    property var config: null
    width: parent ? parent.width : 0
    spacing: Tokens.s1

    readonly property var store: PythonOpts.read(opts.config, opts.widget)
    readonly property bool stretchWidth: opts.store.stretchWidth === true

    function setStretch(on) {
        if (!opts.config)
            return;
        const o = PythonOpts.read(opts.config, opts.widget);
        o.stretchWidth = on;
        const values = {};
        values[opts.widget + "Opts"] = JSON.stringify(o);
        if (on) {
            values[opts.widget + "Anchor"] = "free";
            values[opts.widget + "X"] = 0;
            values[opts.widget + "Scale"] = 1;
        }
        opts.config.setMany(values);
    }

    MenuSection {
        label: I18n.tr("Layout")
        gloss: "配置"
    }
    MenuRow {
        label: I18n.tr("Span the screen width")
        value: opts.stretchWidth ? I18n.tr("On") : I18n.tr("Off")
        on: opts.stretchWidth
        closeOnTrigger: false
        onTriggered: opts.setStretch(!opts.stretchWidth)
    }
}
