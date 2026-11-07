import QtQuick
import QtQuick.Effects
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../phone"
import "../quickPanel"

// The screen of the Settings phone: what is drawn inside the landscape
// PhoneBody. Like QuickPanelFace.qml it is pure UI: QuickPanel.qml (through
// SettingsStage.qml) gives it what the shell knows and turns its signals into
// actions.
//
// The layout is a game's main menu, held sideways, with a page behind each
// button. There is no list of pages beside the page; the menu IS the list:
//
//   MENU     (camera)  <leaning title banner>                 clock   <x>
//            (cut-out)  ╱ 01 Quick ╱  ╱ 02 General ╱  ╱ 03 Bar ╱  ╱ 04 About ╱
//
//   A PAGE   (camera)  <leaning title banner>        [Menu]  clock   <x>
//            (cut-out) ┌────────────────────────────────────────────────┐
//                      │  the page, the whole width: a scrolling stack  │
//                      │  of cards, each with a coloured name plate     │
//                      └────────────────────────────────────────────────┘
//
// Only what this barstyle owns is offered here. Everything Ryoku owns (its
// displays, the compositor, keybinds, network, the system theme, the wallpaper
// daemon, updates) lives in the Ryoku Hub, not on this phone.
//
// The camera cut-out is on the left edge, so everything that sits beside it
// keeps `safeLeft` clear (what a real phone's "safe area" does).
Item {
    id: face

    width: 1440
    height: 760

    property var source: null
    property var notificationSource: null
    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"

    property real screenInset: 26
    property real cornerRadius: 92
    property real renderScale: 1

    signal closeRequested()
    signal wallpapersRequested()
    signal lockWallpapersRequested()
    signal desktopEditRequested()
    signal searchLeft()

    readonly property var pages: [
        { id: "quick", icon: "instant_mix", label: "Quick", title: "Quick", sub: "The things you reach for most" },
        { id: "general", icon: "tune", label: "General", title: "General", sub: "How the shell behaves" },
        { id: "bar", icon: "toast", label: "Bar", title: "Bar", sub: "What it carries and how it behaves" },
        { id: "about", icon: "info", label: "About", title: "About", sub: "This barstyle and its credits" }
    ]

    property int pageIndex: 0

    property bool hub: true
    property real hubP: hub ? 1 : 0
    Behavior on hubP {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
        }
    }

    property real pos: pageIndex
    Behavior on pos {
        enabled: !face.hub
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    property var visited: [true, false, false, false]

    function visit(i) {
        if (visited[i])
            return
        const v = visited.slice()
        v[i] = true
        visited = v
    }

    function go(i) {
        pageIndex = Math.max(0, Math.min(pages.length - 1, i))
        hub = false
    }

    function showHub() {
        hub = true
    }

    function step(d) {
        if (hub)
            return
        go(pageIndex + d)
    }

    onPageIndexChanged: {
        visit(pageIndex)
        swap.restart()
        face.remember()
    }

    onHubChanged: {
        swap.restart()
        face.remember()
    }

    function remember() {
        SettingsService.set("settings.page", hub ? "" : pages[pageIndex].id)
    }

    function restorePage() {
        const i = pages.findIndex(p => p.id === SettingsService.get("settings.page"))
        if (i >= 0)
            go(i)
    }

    Component.onCompleted: {
        if (SettingsService.loaded)
            face.restorePage()
    }

    Connections {
        target: SettingsService
        function onLoadedChanged() {
            if (SettingsService.loaded)
                face.restorePage()
        }
    }

    property bool active: true

    function scrollPagesToTop() {
        for (let i = 0; i < pageRepeater.count; i++) {
            const slot = pageRepeater.itemAt(i)
            if (slot && slot.item && slot.item.scrollToTop)
                slot.item.scrollToTop()
        }
    }

    onActiveChanged: {
        if (active && hub)
            face.scrollPagesToTop()
        if (!active)
            search.clear()
    }

    // False while the phone is still turning in / out or ringing out
    // (SettingsStage hands it down). The pages that have not been built yet are
    // warmed up one by one on the timer below, so building a page never stalls
    // the turn. Defaults to true, so nothing else changes.
    property bool calm: true

    Timer {
        interval: 280
        repeat: true
        running: face.active && face.calm
        onTriggered: {
            for (let i = 0; i < face.pages.length; i++) {
                if (!face.visited[i]) {
                    face.visit(i)
                    return
                }
            }
            running = false
        }
    }

    readonly property real safeLeft: 96
    readonly property real safeRight: 50

    readonly property real pageX: safeLeft
    readonly property real pageTop: 114
    readonly property real pageWidth: width - safeLeft - safeRight
    readonly property real pageHeight: 594

    readonly property real hubGapX: 26
    readonly property real hubGapY: 30
    readonly property int hubCols: Math.ceil(pages.length / 2)
    readonly property real hubTileW: Math.floor((pageWidth - (pages.length % 2 ? 0 : 34) - (hubCols - 1) * hubGapX - 10) / hubCols)
    readonly property real hubStagger: pages.length % 2 ? Math.floor((hubTileW + hubGapX) / 2) : 34
    readonly property real hubTileH: Math.floor((pageHeight - hubGapY - 16) / 2)

    readonly property color backdropColor: backdrop.color

    Item {
        id: screenArea

        x: face.screenInset
        y: face.screenInset
        width: face.width - 2 * face.screenInset
        height: face.height - 2 * face.screenInset
        z: -10

        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: screenMask
        }

        TansuBackdrop {
            id: backdrop
            x: -face.screenInset
            y: -face.screenInset
            width: face.width
            height: face.height
        }
    }

    Item {
        id: screenMask
        width: screenArea.width
        height: screenArea.height
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))

        Rectangle {
            anchors.fill: parent
            color: "black"
            radius: Math.max(0, face.cornerRadius - face.screenInset)
            antialiasing: true
        }
    }

    property int shownPage: -1

    readonly property var hubInfo: ({ icon: "settings", title: "Settings", sub: "Pick what you want to change" })
    readonly property var shownInfo: shownPage < 0 ? hubInfo : pages[shownPage]

    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: titleBlock
            property: "opacity"
            to: 0
            duration: 80
        }
        ScriptAction { script: face.shownPage = face.hub ? -1 : face.pageIndex }
        NumberAnimation {
            target: titleBlock
            property: "opacity"
            to: 1
            duration: 200
        }
    }

    Item {
        id: banner

        x: face.safeLeft - 8
        y: 28
        height: 70
        width: bannerKey.capW + 8

        TansuKey {
            id: bannerKey

            capW: Math.max(420, 92 + Math.max(titleText.implicitWidth, subText.implicitWidth) + 120)
            capH: 66
            skew: 0.26 * Theme.settingsLean
            radius: 26
            lit: true
            litP: 1
            borderBase: 4
            borderLit: 4
            ringExtra: 5
            shadowBaseX: 5
            shadowBaseY: 4
            flatShadow: Theme.quickFlat

            Behavior on capW {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            Item {
                id: titleBlock
                anchors.fill: parent

                Rectangle {
                    x: 54 - width / 2
                    y: (bannerKey.capH - height) / 2
                    width: 34
                    height: 34
                    radius: 10
                    rotation: 45
                    color: Theme.colBg
                    border.width: 3
                    border.color: Theme.colBorder
                    antialiasing: true
                }

                MaterialIcon {
                    x: 54 - width / 2
                    y: (bannerKey.capH - height) / 2
                    size: 24
                    name: face.shownInfo.icon
                    weight: Theme.settingsIconWeight
                    color: Theme.colBorder
                }

                Column {
                    x: 92
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: titleText
                        text: face.shownInfo.title
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 25
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        lineHeight: 26
                        lineHeightMode: Text.FixedHeight
                    }

                    Text {
                        id: subText
                        text: face.shownInfo.headerSub !== undefined ? face.shownInfo.headerSub : face.shownInfo.sub
                        color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.78)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        lineHeight: 15
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }

            MaterialIcon {
                x: bannerKey.capW - 52
                y: 8
                size: 24
                name: "star"
                weight: Theme.settingsIconWeight
                rotation: 14
                color: Theme.colBg
            }
        }
    }

    TansuKey {
        id: clockChip

        x: closeButton.x - 16 - capW - 6
        y: 34
        capW: Math.max(clockLabel.implicitWidth, dateLabel.implicitWidth) + 62
        capH: 56
        skew: 0.26 * Theme.settingsLean
        radius: 20
        flatShadow: Theme.quickFlat

        Column {
            anchors.centerIn: parent

            Text {
                id: clockLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.clockText
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 21
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                lineHeight: 24
                lineHeightMode: Text.FixedHeight
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.dateText
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
            }
        }
    }

    SettingRoundButton {
        id: closeButton
        x: face.width - face.safeRight - width
        y: 33
        size: 58
        icon: "close"
        onClicked: face.closeRequested()
    }

    TansuNavKey {
        id: menuKey

        x: clockChip.x - 24 - width
        y: 38
        icon: "apps"
        label: "Menu"
        opacity: 1 - face.hubP
        visible: opacity > 0.01
        enabled: !face.hub
        onClicked: face.showHub()
    }

    property string searchText: ""
    property var results: []
    property int selected: 0
    readonly property bool searching: searchText.trim() !== ""

    onSearchTextChanged: {
        if (searching) {
            for (let i = 0; i < pages.length; i++)
                visit(i)
        }
        searchTimer.restart()
    }

    Timer {
        id: searchTimer
        interval: 120
        onTriggered: face.rebuildResults()
    }

    function indexItems(node, pageIdx, card, out) {
        const kids = node.children
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            const cardTitle = c.isSectionCard === true ? String(c.title) : card
            if (typeof c.label === "string" && c.label !== "" && c.selected === undefined) {
                out.push({
                    item: c,
                    page: pageIdx,
                    card: cardTitle,
                    label: c.label,
                    icon: typeof c.icon === "string" ? c.icon : "",
                    hay: (c.label + " " + (typeof c.detail === "string" ? c.detail : "") + " "
                        + cardTitle + " " + pages[pageIdx].label).toLowerCase()
                })
            } else if (c.children && c.children.length > 0) {
                indexItems(c, pageIdx, cardTitle, out)
            }
        }
    }

    function rebuildResults() {
        const q = searchText.trim().toLowerCase()
        if (q === "") {
            results = []
            return
        }
        const words = q.split(/\s+/)
        const out = []
        for (let i = 0; i < pageRepeater.count; i++) {
            const slot = pageRepeater.itemAt(i)
            if (!slot || !slot.item || !slot.item.cards)
                continue
            const all = []
            indexItems(slot.item.cards, i, "", all)
            for (const r of all) {
                if (words.every(w => r.hay.indexOf(w) >= 0))
                    out.push(r)
            }
        }
        results = out
    }

    onResultsChanged: selected = 0

    function stepResult(d) {
        if (results.length === 0)
            return
        selected = Math.max(0, Math.min(results.length - 1, selected + d))
        const top = 18 + selected * 82
        if (top < resultsFlick.contentY)
            resultsFlick.contentY = top - 18
        else if (top + 68 > resultsFlick.contentY + resultsFlick.height)
            resultsFlick.contentY = top + 68 + 18 - resultsFlick.height
    }

    function openResult(r) {
        const slot = pageRepeater.itemAt(r.page)
        search.clear()
        go(r.page)
        searchLeft()
        Qt.callLater(() => {
            if (slot && slot.item)
                slot.item.scrollToItem(r.item)
        })
    }

    function typeIntoSearch(character) {
        search.begin(character)
    }

    SearchPill {
        id: search
        x: menuKey.x - 24 - width
        y: 36
        width: 280
        height: 52
        placeholder: "Search settings"
        stepKeys: true
        onTextChanged: face.searchText = text
        onStepped: direction => face.stepResult(direction)
        onLeave: {
            if (face.results.length > 0)
                face.openResult(face.results[Math.min(face.selected, face.results.length - 1)])
            else
                face.searchLeft()
        }
    }

    Keys.onEscapePressed: {
        search.clear()
        face.searchLeft()
    }

    Item {
        id: hubArea

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.pageHeight
        opacity: face.hubP
        scale: 0.96 + 0.04 * face.hubP
        visible: opacity > 0.01
        enabled: face.hub

        Repeater {
            model: face.pages

            delegate: TansuHubTile {
                required property var modelData
                required property int index

                readonly property int col: index % face.hubCols
                readonly property int row: Math.floor(index / face.hubCols)

                x: col * (face.hubTileW + face.hubGapX) + row * face.hubStagger
                y: 4 + row * (face.hubTileH + face.hubGapY)
                tileW: face.hubTileW
                tileH: face.hubTileH
                slot: index
                number: index + 1
                icon: modelData.icon
                label: modelData.label
                subtitle: modelData.sub
                onClicked: face.go(index)
            }
        }
    }

    Item {
        id: pageArea
        x: face.pageX
        y: face.pageTop - 12
        width: face.pageWidth
        height: face.pageHeight + 12
        clip: true
        opacity: 1 - face.hubP
        visible: opacity > 0.01
        enabled: !face.hub

        Repeater {
            id: pageRepeater
            model: face.pages

            delegate: Loader {
                id: slot

                required property var modelData
                required property int index

                readonly property real d: slot.index - face.pos

                width: pageArea.width
                height: pageArea.height
                x: d * 90
                opacity: Math.max(0, 1 - Math.abs(d) * 1.7)
                scale: 1 - Math.min(1, Math.abs(d)) * 0.03
                visible: opacity > 0.01
                enabled: slot.index === face.pageIndex
                active: face.visited[slot.index] === true
                asynchronous: slot.index !== face.pageIndex
                onLoaded: {
                    if (face.searching)
                        searchTimer.restart()
                }
                sourceComponent: slot.index === 0 ? quickPage
                    : slot.index === 1 ? generalPage
                    : slot.index === 2 ? barPage : aboutPage
            }
        }
    }

    Item {
        id: searchArea
        x: face.pageX
        y: face.pageTop - 12
        width: face.pageWidth
        height: face.pageHeight + 12
        clip: true
        opacity: face.searching ? 1 : 0
        visible: opacity > 0.01
        enabled: face.searching

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Rectangle {
            anchors.fill: parent
            color: face.backdropColor
        }

        Text {
            visible: face.results.length === 0
            anchors.centerIn: parent
            text: "No settings found"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        WheelScroll { scroller: resultsFlick }
        Flickable {
            id: resultsFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: resultsColumn.height + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: resultsColumn
                x: 4
                y: 18
                width: parent.width - 16
                spacing: 14

                Repeater {
                    model: face.results

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        width: resultsColumn.width
                        height: 68
                        radius: 20
                        color: row.index === face.selected ? Theme.pSurfaceHover : Theme.pSurface
                        border.width: 3
                        border.color: Theme.pLine
                        antialiasing: true

                        MaterialIcon {
                            x: 26
                            anchors.verticalCenter: parent.verticalCenter
                            size: 28
                            name: row.modelData.icon !== "" ? row.modelData.icon : "settings"
                            weight: Theme.settingsIconWeight
                            color: Theme.pInk
                        }

                        Column {
                            x: 78
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: row.modelData.label
                                color: Theme.pInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 20
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }

                            Text {
                                text: face.pages[row.modelData.page].label + (row.modelData.card !== "" ? "  ·  " + row.modelData.card : "")
                                color: Theme.pInkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: face.selected = row.index
                            onClicked: face.openResult(row.modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: quickPage
        SettingsPageQuick {
            host: face
            width: pageArea.width
            height: pageArea.height
        }
    }

    Component {
        id: generalPage
        SettingsPageGeneral {
            host: face
            width: pageArea.width
            height: pageArea.height
        }
    }

    Component {
        id: barPage
        SettingsPageBar {
            host: face
            width: pageArea.width
            height: pageArea.height
        }
    }

    Component {
        id: aboutPage
        SettingsPageAbout {
            host: face
            width: pageArea.width
            height: pageArea.height
        }
    }
}
