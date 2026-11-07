pragma ComponentBehavior: Bound
import QtQuick
import "../components"
import Ryoku.Ui.Singletons
import "PythonOpts.js" as PythonOpts

// Options for the Python GitHub widget: the account whose contribution graph
// it paints. Upstream typed the name into the face itself; the Ryoku host sets
// it through the widget's <prefix>Opts JSON, which the provider writes into the
// face's hostUser property (the face then persists and fetches on its own).
Column {
    id: opts

    property string widget: ""
    property var config: null
    width: parent ? parent.width : 0
    spacing: Tokens.s1

    readonly property string user: String(PythonOpts.read(opts.config, opts.widget).hostUser || "")

    MenuSection { label: I18n.tr("GitHub"); gloss: "貢献" }
    MenuTextField {
        label: I18n.tr("Username")
        placeholder: I18n.tr("GitHub username")
        text: opts.user
        onCommitted: (v) => PythonOpts.put(opts.config, opts.widget, "hostUser", v.trim())
    }
}
