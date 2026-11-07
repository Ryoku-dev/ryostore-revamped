import QtQuick
import "../components"
import Ryoku.Ui.Singletons

Column {
    property string widget: ""
    property var config: null

    width: parent ? parent.width : 0
    spacing: Tokens.s1

    MenuSection {
        label: I18n.tr("No additional options")
        gloss: "標準"
    }
}
