import QtQuick 6.11
import shell.services as Ryoku
import nomarchy.Ui
import Ryoku.Ui.Singletons
BarIndicator {
  id: root

  active: Ryoku.Flags.keepAwake
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: I18n.tr("Allow Idle Lock & Screensaver")
  inactiveTooltipText: I18n.tr("Stay Awake")

  function toggle() {
    Ryoku.Flags.keepAwake = !Ryoku.Flags.keepAwake
  }

  onPressed: function() { root.toggle() }
}
