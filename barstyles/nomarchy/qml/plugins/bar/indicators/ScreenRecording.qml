import QtQuick 6.11
import shell.services as Ryoku
import nomarchy.Ui
import Ryoku.Ui.Singletons
BarIndicator {
  id: root

  readonly property bool recording: Ryoku.Recorder.active

  active: recording
  activeText: "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: I18n.tr("Stop recording")
  inactiveTooltipText: I18n.tr("Screen Recording")


  onPressed: function() {
    if (root.recording)
      Ryoku.Recorder.stop()
    else
      Spawn.run(["ryoku-cmd-ryoshot"])
  }
}
