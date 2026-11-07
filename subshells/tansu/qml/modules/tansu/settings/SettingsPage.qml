import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../phone"

Item {
    id: page

    property var host: null

    default property alias content: column.data
    property alias overlay: overlayHost.data

    readonly property real cardWidth: width - 14
    readonly property real tileWidth: Math.floor((cardWidth - 5 - 52 - 16 * 2) / 3) - 6

    // Two across, and the whole width, inside a card (sliders, notes).
    readonly property real halfWidth: Math.floor((cardWidth - 5 - 52 - 16) / 2)
    readonly property real fullWidth: cardWidth - 5 - 52

    readonly property color fadeColor: host && host.backdropColor !== undefined ? host.backdropColor : Theme.pSurface

    function scrollToTop() {
        scrollAnim.stop()
        page.pinned = -1
        flick.contentY = 0
    }

    readonly property Item cards: column

    function scrollToItem(it) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, column.y + it.mapToItem(column, 0, 0).y - 90))
        scrollAnim.stop()
        page.pinned = -1
        scrollAnim.from = flick.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    property var sections: []
    property string sectionSig: ""

    function refreshSections() {
        if (!page.visible)
            return
        const out = []
        const kids = column.children
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (c.isSectionCard === true && c.visible && c.height > 0 && c.title !== "")
                out.push({ title: String(c.title), y: Math.round(c.y), accent: String(c.accent) })
        }
        const sig = JSON.stringify(out)
        if (sig === page.sectionSig)
            return
        page.sectionSig = sig
        page.sections = out
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(page.refreshSections)
    }
    readonly property bool showChips: sections.length > 1
    readonly property real topGap: showChips ? 60 : 12

    property int pinned: -1
    property real pinnedY: 0

    readonly property int activeIdx: {
        if (page.pinned >= 0 && page.pinned < sections.length)
            return page.pinned
        let a = 0
        const y = flick.contentY + 40
        for (let i = 0; i < sections.length; i++) {
            if (column.y + sections[i].y - 22 <= y)
                a = i
        }
        if (flick.contentHeight - flick.height > 1 && flick.contentY >= flick.contentHeight - flick.height - 2)
            a = Math.max(0, sections.length - 1)
        return a
    }

    function scrollToSection(i) {
        if (i < 0 || i >= sections.length)
            return
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, column.y + sections[i].y - 30))
        scrollAnim.stop()
        page.pinned = i
        page.pinnedY = to
        scrollAnim.from = flick.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    onActiveIdxChanged: {
        const it = chipRep.itemAt(activeIdx)
        if (!it)
            return
        const w = chipStrip.width
        if (it.x < chipStrip.contentX + 6)
            chipStrip.contentX = Math.max(0, it.x - 6)
        else if (it.x + it.width > chipStrip.contentX + w - 6)
            chipStrip.contentX = Math.max(0, Math.min(chipStrip.contentWidth - w, it.x + it.width - w + 6))
    }

    Connections {
        target: column
        function onImplicitHeightChanged() { Qt.callLater(page.refreshSections) }
        function onChildrenChanged() { Qt.callLater(page.refreshSections) }
    }

    Component.onCompleted: Qt.callLater(page.refreshSections)

    NumberAnimation {
        id: scrollAnim
        target: flick
        property: "contentY"
        duration: 300
        easing.type: Easing.OutCubic
    }

    WheelScroll { scroller: flick }
    Flickable {
        id: flick
        y: page.topGap
        width: parent.width
        height: parent.height - page.topGap
        contentWidth: width
        contentHeight: column.y + column.implicitHeight + 34
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        onContentYChanged: {
            PanelActivity.touch()
            if (page.pinned >= 0 && !scrollAnim.running && Math.abs(flick.contentY - page.pinnedY) > 3)
                page.pinned = -1
        }
        onMovementStarted: scrollAnim.stop()

        Column {
            id: column
            x: 2
            y: 30
            width: page.cardWidth
            spacing: 44
        }
    }

    Item {
        id: overlayHost
        anchors.fill: parent
        z: 60
    }

    // The jump chips: a row of the same bouncy keycaps as the rest of the
    // Settings pages (SettingChip), above the cards, only when there is more
    // than one titled card. They press in and spring back when clicked, and the
    // one for the card in view is lit and pulses as it takes over.
    Flickable {
        id: chipStrip

        visible: page.showChips
        x: 0
        y: 3
        width: page.width
        height: 50
        contentWidth: chipRow.width + 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = Theme.wheelPx(event, true)
                chipStrip.contentX = Math.max(0, Math.min(chipStrip.contentWidth - chipStrip.width, chipStrip.contentX - d))
            }
        }

        Row {
            id: chipRow
            x: 6
            y: 2
            spacing: 10

            Repeater {
                id: chipRep
                model: page.sections

                delegate: SettingChip {
                    id: chip

                    required property var modelData
                    required property int index

                    capH: 42
                    label: chip.modelData.title
                    selected: chip.index === page.activeIdx
                    onClicked: page.scrollToSection(chip.index)
                }
            }
        }
    }

    Rectangle {
        y: page.topGap
        width: parent.width
        height: 18
        opacity: flick.contentY > 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: page.fadeColor }
            GradientStop { position: 1.0; color: Qt.rgba(page.fadeColor.r, page.fadeColor.g, page.fadeColor.b, 0) }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 26
        opacity: flick.contentY < flick.contentHeight - flick.height - 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(page.fadeColor.r, page.fadeColor.g, page.fadeColor.b, 0) }
            GradientStop { position: 1.0; color: page.fadeColor }
        }
    }

    Rectangle {
        readonly property real track: flick.height - 16
        visible: flick.visibleArea.heightRatio < 1
        x: page.width - 8
        y: flick.y + 8 + flick.visibleArea.yPosition * track
        width: 6
        height: Math.max(30, flick.visibleArea.heightRatio * track)
        radius: 3
        color: Theme.pSurfaceRing
        antialiasing: true
    }
}
