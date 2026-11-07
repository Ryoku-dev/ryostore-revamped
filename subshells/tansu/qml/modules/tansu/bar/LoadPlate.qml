import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

TansuPlate {
    id: plate

    property string label: ""
    property string glyph: ""
    property real pct: 0
    property color ink: Theme.colBorder

    height: 100

    Behavior on colorTop { ColorAnimation { duration: 160 } }
    Behavior on colorBottom { ColorAnimation { duration: 160 } }

    Row {
        x: 14
        y: 11
        spacing: 6

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: plate.glyph
            fill: 0
            size: 18
            weight: 600
            color: plate.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: plate.label
            color: plate.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            font.letterSpacing: 1.2
        }
    }

    StickerText {
        id: num
        x: 6
        y: 28
        text: String(Math.round(plate.pct))
        pixelSize: 44
        fillColor: plate.numberFill
        ringColor: plate.numberRing
    }

    StickerText {
        x: num.x + num.width - 6
        y: 48
        text: "%"
        pixelSize: 18
        fillColor: plate.numberFill
        ringColor: plate.numberRing
    }

    Burst {
        id: puff
        x: plate.width / 2
        y: plate.faceHeight / 2
        radius: 52
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: puff.fire()
    }
}
