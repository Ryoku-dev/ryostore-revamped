import QtQuick 6.11
import shell.services as Ryoku
import nomarchy.Ui
import Ryoku.Ui.Singletons
BarIndicator {
  id: root

  active: Ryoku.Nightlight.on
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: I18n.tr("Day Light")
  inactiveTooltipText: I18n.tr("Night Light")

  function toggle() {
    Ryoku.Nightlight.toggle()
  }

  onPressed: function() { root.toggle() }
}
