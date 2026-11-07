import QtQuick 6.11
import nomarchy.Ui

BarWidget {
  id: root
  moduleName: "omarchy.spacer"

  readonly property int span: settings && settings.size !== undefined ? Number(settings.size) : 12

  implicitWidth: vertical ? barSize : span
  implicitHeight: vertical ? span : barSize
  visible: span > 0
}
