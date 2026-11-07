import QtQuick
import "CalendarMath.js" as CM
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

TansuPopup {
    id: root

    property date today: new Date()

    property int firstDay: 1

    property int monthShift: 0
    readonly property date viewDate: CM.monthStart(root.today, root.monthShift)
    readonly property var cells: CM.monthGrid(root.viewDate, root.today, root.firstDay)
    readonly property var weekdays: CM.weekdayLabels(root.firstDay)
    readonly property int viewYear: root.viewDate.getFullYear()
    readonly property int viewMonth: root.viewDate.getMonth()
    readonly property int nowMonth: root.viewYear === root.today.getFullYear() ? root.today.getMonth() : -1

    readonly property var marks: CM.parseMarks(SettingsService.get("calendar.marks"))
    readonly property var markNames: ["Cool", "Cute", "Happy", "Mysterious", "Pure"]

    function setMark(key, idx) {
        const next = Object.assign({}, root.marks)
        if (idx > 0)
            next[key] = idx
        else
            delete next[key]
        SettingsService.set("calendar.marks", CM.serializeMarks(next, root.today))
    }

    readonly property color weekendInk: Theme.tierMax

    readonly property int todayCol: (root.today.getDay() - root.firstDay + 7) % 7
    readonly property int todayIndex: {
        for (let i = 0; i < root.cells.length; i++)
            if (root.cells[i].isToday)
                return i
        return -1
    }

    readonly property int cell: 40
    readonly property int gap: 4
    readonly property int pad: 16
    readonly property int gridW: 7 * root.cell + 6 * root.gap
    readonly property int gridH: 6 * root.cell + 5 * root.gap

    contentWidth: root.gridW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    property int hoverIndex: -1
    property int hoverMonth: -1
    property bool hoverYear: false
    property bool hoverSticker: false

    readonly property var focusCell: root.hoverIndex >= 0 && root.hoverIndex < root.cells.length
        ? root.cells[root.hoverIndex] : null
    readonly property int fY: root.focusCell ? root.focusCell.y : root.today.getFullYear()
    readonly property int fM: root.focusCell ? root.focusCell.m : root.today.getMonth()
    readonly property int fD: root.focusCell ? root.focusCell.d : root.today.getDate()
    readonly property int fDow: new Date(root.fY, root.fM, root.fD).getDay()
    readonly property int fDiff: CM.dayDiff(root.today, root.fY, root.fM, root.fD)
    readonly property bool focusIsToday: root.fDiff === 0
    readonly property string focusKey: root.fY + "-" + root.fM + "-" + root.fD

    readonly property var readout: {
        if (root.hoverYear)
            return [String(root.viewYear), "Click: next year  ·  right-click: last year"]
        if (root.hoverMonth >= 0) {
            const n = CM.shiftFor(root.today, root.viewYear, root.hoverMonth)
            const when = n === 0 ? "This month" : (n === 1 ? "Next month" : (n === -1 ? "Last month"
                : (n > 0 ? "In " + n + " months" : -n + " months ago")))
            return [CM.monthName(root.hoverMonth) + " " + root.viewYear, when + "  ·  click to jump"]
        }
        if (root.hoverSticker && root.monthShift !== 0)
            return ["Back to today", CM.longDay(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())]
        if (root.focusCell) {
            const m = root.marks[root.focusCell.key] || 0
            let hint = ""
            if (!root.focusCell.inMonth)
                hint = "  ·  click to turn the page"
            else if (m > 0)
                hint = "  ·  " + root.markNames[m - 1] + " star"
            else
                hint = "  ·  click to stick a star"
            return [CM.longDay(root.fY, root.fM, root.fD), CM.relative(root.fDiff) + hint]
        }
        const t = root.today
        const left = CM.daysInMonth(t.getFullYear(), t.getMonth()) - t.getDate()
        return [CM.weekdayLong(t.getDay()) + "  ·  Week " + CM.isoWeek(t.getFullYear(), t.getMonth(), t.getDate()),
                left === 0 ? "Last day of " + CM.monthName(t.getMonth())
                           : left + (left === 1 ? " day" : " days") + " left in " + CM.monthName(t.getMonth())]
    }

    property real wave: 1
    readonly property real waveMs: 620

    NumberAnimation {
        id: waveAnim
        target: root
        property: "wave"
        from: 0
        to: 1
        duration: root.waveMs
    }

    property real heroPop: 1
    onFocusKeyChanged: heroPopAnim.restart()

    NumberAnimation {
        id: heroPopAnim
        target: root
        property: "heroPop"
        from: 0.86
        to: 1
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 2.4
    }

    onMonthShiftChanged: waveAnim.restart()

    onOpenChanged: {
        if (open) {
            monthShift = 0
            hoverIndex = -1
            hoverMonth = -1
            hoverYear = false
            hoverSticker = false
            if (root.reveal < 0.35)
                waveAnim.restart()
        }
    }

    onKeyed: event => {
        if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Right) {
            root.monthShift++
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Left) {
            root.monthShift--
            event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            root.monthShift = 0
            event.accepted = true
        }
    }

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.gridW
        spacing: 10

        TansuPlate {
            id: plate
            width: root.gridW
            height: 104

            Pill {
                id: sticker
                x: 12
                y: 10
                width: 78
                height: 84
                shadowDx: 3
                shadowDy: 4
                cornerRadius: 20
                ringWidth: 4
                rotation: -6
                scale: root.heroPop
                transformOrigin: Item.Center
                pressed: stickerArea.pressed
                fillColor: Theme.chipFill

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 7
                    text: CM.weekdayShort(root.fDow).toUpperCase()
                    color: Theme.chipInk
                    opacity: 0.8
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 1.2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    text: root.fD
                    color: root.focusIsToday ? (Theme.dark ? Theme.accentMint : Theme.colBorder) : Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 40
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Pill {
                id: backTag
                readonly property bool shown: root.monthShift !== 0
                x: 2
                y: 76
                width: 72
                height: 28
                shadowDy: 3
                cornerRadius: 10
                ringWidth: 3
                rotation: 5
                fillGradient: accentGradient
                scale: backTag.shown ? 1 : 0
                opacity: backTag.shown ? 1 : 0
                visible: opacity > 0.01
                transformOrigin: Item.Center
                pressed: stickerArea.pressed

                Behavior on scale {
                    NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "undo"
                        fill: 0
                        size: 14
                        weight: 700
                        color: Theme.colBorder
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TODAY"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.5
                    }
                }
            }

            MouseArea {
                id: stickerArea
                x: sticker.x
                y: sticker.y
                width: sticker.width
                height: sticker.height + 8
                hoverEnabled: true
                cursorShape: root.monthShift !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: root.hoverSticker = true
                onExited: root.hoverSticker = false
                onClicked: root.monthShift = 0
            }

            Item {
                id: titleBlock
                x: 106
                y: 2
                width: plate.width - 106 - 72
                height: 54

                Item {
                    id: monthFit
                    width: monthSticker.implicitWidth
                    height: monthSticker.implicitHeight
                    scale: Math.min(1, titleBlock.width / monthFit.width)
                    transformOrigin: Item.TopLeft

                    StickerText {
                        id: monthSticker
                        text: CM.monthName(root.viewMonth)
                        pixelSize: 32
                        fillColor: plate.numberFill
                        ringColor: plate.numberRing
                    }
                }
            }

            Text {
                x: 108
                y: 58
                width: plate.width - 108 - 12
                elide: Text.ElideRight
                text: root.readout[0]
                color: Theme.colBorder
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                x: 108
                y: 75
                width: plate.width - 108 - 12
                elide: Text.ElideRight
                text: root.readout[1]
                color: Theme.colBorder
                opacity: 0.8
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Item {
                id: yearChip
                x: plate.width - 62
                y: 10
                width: 54
                height: 29

                Pill {
                    anchors.fill: parent
                    shadowDy: 3
                    cornerRadius: 11
                    ringWidth: 3
                    fillColor: Theme.chipFill
                    pressed: yearArea.pressed

                    Text {
                        anchors.centerIn: parent
                        text: root.viewYear
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                MouseArea {
                    id: yearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverYear = true
                    onExited: root.hoverYear = false
                    onClicked: mouse => root.monthShift += (mouse.button === Qt.RightButton ? -12 : 12)
                }
            }
        }

        Rectangle {
            id: dayStrip
            width: root.gridW
            height: 28
            radius: 14
            color: Theme.surfaceHover
            border.width: 2
            border.color: Theme.line
            antialiasing: true

            Slant {
                x: root.todayCol * (root.cell + root.gap) + 1
                y: 3
                width: root.cell - 2
                height: 22
                skew: 0.22
                radius: 8
                gradient: accentGradient
                borderColor: Theme.line
                borderWidth: 2
            }

            Repeater {
                model: root.weekdays

                delegate: Item {
                    required property string modelData
                    required property int index
                    x: index * (root.cell + root.gap)
                    width: root.cell
                    height: dayStrip.height

                    readonly property bool weekend: ((root.firstDay + index) % 7) === 0
                        || ((root.firstDay + index) % 7) === 6
                    readonly property bool isTodayCol: index === root.todayCol

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.isTodayCol ? Theme.colBorder
                             : (parent.weekend ? root.weekendInk
                                               : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.9))
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }
            }
        }

        Item {
            id: board
            width: root.gridW
            height: root.gridH

            Repeater {
                model: 7

                delegate: Rectangle {
                    required property int index
                    readonly property bool weekend: ((root.firstDay + index) % 7) === 0
                        || ((root.firstDay + index) % 7) === 6
                    visible: weekend
                    x: index * (root.cell + root.gap) - 2
                    y: -3
                    width: root.cell + 4
                    height: board.height + 6
                    radius: 16
                    color: Qt.rgba(root.weekendInk.r, root.weekendInk.g, root.weekendInk.b, 0.08)
                }
            }

            Rectangle {
                readonly property int row: root.todayIndex >= 0 ? Math.floor(root.todayIndex / 7) : 0
                visible: root.todayIndex >= 0
                x: -4
                width: parent.width + 8
                height: root.cell + 4
                y: row * (root.cell + root.gap) - 2
                radius: 18
                color: Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.12)
                opacity: Math.min(1, root.wave * 2)
            }

            Rectangle {
                readonly property int row: root.hoverIndex >= 0 ? Math.floor(root.hoverIndex / 7) : 0
                x: -4
                width: parent.width + 8
                height: root.cell + 4
                y: row * (root.cell + root.gap) - 2
                radius: 18
                color: Theme.surfaceHover
                opacity: root.hoverIndex >= 0 ? 1 : 0
                Behavior on y {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }

            Grid {
                id: grid
                columns: 7
                spacing: root.gap

                Repeater {
                    model: root.cells

                    delegate: Item {
                        id: dayCell
                        required property var modelData
                        required property int index
                        width: root.cell
                        height: root.cell

                        readonly property bool raised: modelData.isToday || (hit.containsMouse && modelData.inMonth)
                        readonly property int mark: root.marks[modelData.key] || 0

                        readonly property real t: Math.max(0, Math.min(1,
                            (root.wave * root.waveMs - (modelData.row * 42 + modelData.col * 12)) / 300))

                        onMarkChanged: {
                            if (dayCell.mark > 0)
                                markDot.bump()
                        }

                        Item {
                            id: inner
                            anchors.fill: parent
                            scale: 0.4 + 0.6 * CM.outBack(dayCell.t, 2.0)
                            opacity: Math.min(1, dayCell.t * 2.5)
                            rotation: dayCell.modelData.isToday ? -4 : 0
                            transformOrigin: Item.Center

                            Rectangle {
                                visible: dayCell.raised
                                x: 0
                                y: 3
                                width: parent.width
                                height: parent.height - 3
                                radius: 15
                                color: Theme.lineShadow
                                antialiasing: true
                            }

                            Rectangle {
                                id: face
                                visible: dayCell.raised
                                width: parent.width
                                height: parent.height - 3
                                y: hit.pressed ? 3 : 0
                                radius: 15
                                antialiasing: true
                                border.width: dayCell.modelData.isToday ? Theme.borderWidth : 2
                                border.color: Theme.line
                                color: dayCell.modelData.isToday ? "transparent" : Theme.surface
                                gradient: dayCell.modelData.isToday ? accentGradient : null

                                Behavior on y {
                                    NumberAnimation {
                                        duration: hit.pressed ? 70 : 240
                                        easing.type: hit.pressed ? Easing.OutQuad : Easing.OutBack
                                        easing.overshoot: 2.2
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (dayCell.raised ? face.y : 0) + (parent.height - 3 - height) / 2 + 1
                                text: dayCell.modelData.day
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                                color: {
                                    if (dayCell.modelData.isToday)
                                        return Theme.colBorder
                                    if (!dayCell.modelData.inMonth)
                                        return Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.4)
                                    if (dayCell.modelData.isWeekend)
                                        return root.weekendInk
                                    return Theme.ink
                                }
                            }

                            Item {
                                x: parent.width - 14
                                y: 2
                                width: 10
                                height: 10
                                visible: dayCell.mark > 0

                                DiamondDot {
                                    id: markDot
                                    anchors.centerIn: parent
                                    size: 10
                                    lit: true
                                    litColor: dayCell.mark > 0 ? Theme.attributeColors[dayCell.mark - 1] : Theme.accentMint
                                    lineColor: Theme.line
                                }
                            }
                        }

                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoverIndex = dayCell.index
                            onExited: {
                                if (root.hoverIndex === dayCell.index)
                                    root.hoverIndex = -1
                            }
                            onClicked: mouse => {
                                const c = dayCell.modelData
                                if (mouse.button === Qt.RightButton) {
                                    root.setMark(c.key, 0)
                                } else if (!c.inMonth) {
                                    root.monthShift += (c.y * 12 + c.m) < (root.viewYear * 12 + root.viewMonth) ? -1 : 1
                                } else {
                                    root.setMark(c.key, (dayCell.mark + 1) % 6)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: laneRow
            width: root.gridW
            height: 34

            Repeater {
                model: [
                    { icon: "chevron_left", step: -1, left: 0 },
                    { icon: "chevron_right", step: 1, left: root.gridW - 38 }
                ]

                delegate: Item {
                    id: navButton
                    required property var modelData
                    x: navButton.modelData.left
                    width: 38
                    height: 34

                    Pill {
                        anchors.fill: parent
                        shadowDy: 3
                        cornerRadius: 13
                        ringWidth: Theme.borderWidth + Theme.whiteLine
                        fillColor: Theme.chipFill
                        pressed: navArea.pressed

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: navButton.modelData.icon
                            fill: 0
                            size: 20
                            color: Theme.chipInk
                            weight: 600
                        }
                    }

                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthShift += navButton.modelData.step
                    }
                }
            }

            Rectangle {
                x: 46
                y: 2
                width: root.gridW - 92
                height: 28
                radius: 14
                color: Theme.surfaceHover
                border.width: 2
                border.color: Theme.line
                antialiasing: true
            }

            Item {
                id: lane
                x: 50
                y: 2
                width: root.gridW - 100
                height: 28
                readonly property real pitch: lane.width / 12

                Repeater {
                    model: 12

                    delegate: Item {
                        id: slot
                        required property int index
                        x: slot.index * lane.pitch
                        width: lane.pitch
                        height: lane.height

                        readonly property bool viewed: slot.index === root.viewMonth
                        readonly property bool nowM: slot.index === root.nowMonth
                        z: (slot.viewed || slotArea.containsMouse) ? 2 : 0

                        Item {
                            id: dotBox
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: 10
                            height: 10
                            scale: slot.viewed ? 1.45 : (slotArea.containsMouse ? 1.3 : 1)
                            Behavior on scale {
                                NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                            }

                            DiamondDot {
                                anchors.centerIn: parent
                                size: 10
                                lit: slot.viewed || slot.nowM
                                litColor: slot.viewed ? Theme.accentMint : Theme.accentCyan
                                offColor: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.38)
                            }
                        }

                        MouseArea {
                            id: slotArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoverMonth = slot.index
                            onExited: {
                                if (root.hoverMonth === slot.index)
                                    root.hoverMonth = -1
                            }
                            onClicked: root.monthShift = CM.shiftFor(root.today, root.viewYear, slot.index)
                        }
                    }
                }

                Rectangle {
                    y: 22
                    width: 14
                    height: 3
                    radius: 1.5
                    color: Theme.ink
                    x: root.viewMonth * lane.pitch + (lane.pitch - width) / 2
                    Behavior on x {
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    }
                }
            }
        }
    }

    // Wheel pages months over the whole card; buttons still reach everything
    // underneath because this one accepts no clicks.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 50
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.monthShift--
            else if (wheel.angleDelta.y < 0)
                root.monthShift++
        }
    }
}
