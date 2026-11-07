pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../modules/common"
import "../../../modules/common/widgets"

// Native app drawer for the Tansu bar's phone. The independent RyoStore
// Tansu launcher is a separate product; this screen needs no extra install.
Item {
    id: face

    readonly property bool classicPanel: true
    width: 654
    height: 1214

    // Keep the QuickPanel interface stable for the phone's route animation.
    property var source: null
    property real renderScale: 1
    property string screenName: ""
    property real visibleBottom: 1214
    property real visibleReach: 1214
    property string clockText: ""
    property string dateText: ""
    property real downloadBps: 0
    property real uploadBps: 0

    readonly property string query: searchInput.text
    property bool keyNav: false

    signal appActivated(var app)
    signal closeRequested()
    signal jumpRequested(int index)
    signal doneRequested()
    signal pickerRequested()
    signal colorPickedBack(string hex)

    readonly property var results: {
        const needle = face.query.toLowerCase().trim()
        const list = (DesktopEntries.applications.values || []).slice()
        const filtered = list.filter(app => {
            if (!app || !app.name)
                return false
            if (!needle)
                return true
            const fields = [app.name, app.genericName, app.comment]
            const keywords = app.keywords || []
            for (const word of keywords)
                fields.push(word)
            return fields.join(" ").toLowerCase().includes(needle)
        })
        filtered.sort((a, b) => {
            if (needle) {
                const rank = app => {
                    const name = String(app.name || "").toLowerCase()
                    return name === needle ? 3 : name.startsWith(needle) ? 2 : name.includes(needle) ? 1 : 0
                }
                const delta = rank(b) - rank(a)
                if (delta)
                    return delta
            }
            return String(a.name).localeCompare(String(b.name))
        })
        return filtered
    }

    function focusSearch() {
        searchInput.forceActiveFocus()
        searchInput.cursorPosition = searchInput.text.length
    }

    function appendText(text) {
        searchInput.text += text
        focusSearch()
    }

    function setText(text) {
        searchInput.text = text
        focusSearch()
    }

    function reset() {
        searchInput.text = ""
        face.keyNav = false
        appGrid.currentIndex = -1
        appGrid.positionViewAtBeginning()
    }

    function back() {
        if (searchInput.text.length > 0)
            reset()
        else
            face.closeRequested()
    }

    function activateCurrent() {
        const index = appGrid.currentIndex >= 0 ? appGrid.currentIndex : 0
        if (index >= 0 && index < face.results.length)
            face.appActivated(face.results[index])
    }

    function moveSelection(key) {
        if (appGrid.count === 0)
            return
        let index = appGrid.currentIndex < 0 ? 0 : appGrid.currentIndex
        if (appGrid.currentIndex >= 0) {
            if (key === Qt.Key_Down)
                index += 4
            else if (key === Qt.Key_Up)
                index -= 4
            else if (key === Qt.Key_Right)
                index++
            else if (key === Qt.Key_Left)
                index--
        }
        appGrid.currentIndex = Math.max(0, Math.min(appGrid.count - 1, index))
        appGrid.positionViewAtIndex(appGrid.currentIndex, GridView.Contain)
        face.keyNav = true
    }

    onQueryChanged: {
        appGrid.currentIndex = face.query.trim() ? 0 : -1
        appGrid.positionViewAtBeginning()
    }
    onEnabledChanged: if (enabled) Qt.callLater(face.focusSearch)

    Text {
        x: 68
        y: 44
        text: face.clockText
        color: Theme.pInk
        font.family: Theme.fontFamily
        font.pixelSize: 24
        font.weight: Font.ExtraBold
    }

    Text {
        x: 68
        y: 78
        text: face.dateText
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 18
    }

    Rectangle {
        id: searchBox
        x: 52
        y: 130
        width: 550
        height: 70
        radius: 35
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine

        MaterialIcon {
            x: 23
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 30
        }

        TextInput {
            id: searchInput
            x: 70
            width: parent.width - 130
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.pInk
            selectionColor: Theme.accentCyan
            selectedTextColor: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
            clip: true
            selectByMouse: true
            focus: true

            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier)
                        && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                    face.jumpRequested(event.key - Qt.Key_0)
                } else if (event.key === Qt.Key_Escape) {
                    face.back()
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    face.activateCurrent()
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                        || ((event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                            && searchInput.text.length === 0)) {
                    face.moveSelection(event.key)
                } else {
                    return
                }
                event.accepted = true
            }
        }

        Text {
            x: 70
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Search applications"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 23
        }

        MaterialIcon {
            x: parent.width - 55
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length > 0
            name: "close"
            size: 26
        }

        MouseArea {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 55
            height: parent.height
            visible: searchInput.text.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: face.reset()
        }
    }

    Text {
        x: 58
        y: 220
        text: face.query.trim()
            ? face.results.length + " matches"
            : face.results.length + " applications"
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    GridView {
        id: appGrid
        x: 52
        y: 268
        width: 550
        height: Math.max(170, Math.min(836, face.visibleReach - y - 35))
        clip: true
        cellWidth: width / 4
        cellHeight: 168
        currentIndex: -1
        model: face.results
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: cellHeight

        TansuScrollBar {}

        delegate: Item {
            id: tile
            required property var modelData

            width: appGrid.cellWidth
            height: appGrid.cellHeight
            readonly property bool selected: face.keyNav && GridView.isCurrentItem
            readonly property string iconPath: Quickshell.iconPath(String(tile.modelData.icon || ""), true) || ""
            readonly property bool noIcon: iconPath === "" || appIcon.status === Image.Error

            Rectangle {
                x: 6
                y: 4
                width: parent.width - 12
                height: 141
                radius: 19
                color: tile.selected || area.containsMouse ? Theme.pSurfaceHover : "transparent"
                border.width: tile.selected ? 2 : 0
                border.color: Theme.accentCyan
            }

            IconImage {
                id: appIcon
                x: Math.round((parent.width - 76) / 2)
                y: 16
                implicitSize: 76
                asynchronous: true
                visible: !tile.noIcon
                source: tile.iconPath
            }

            MaterialIcon {
                x: Math.round((parent.width - 60) / 2)
                y: 24
                visible: tile.noIcon
                name: "apps"
                size: 60
                color: Theme.pInkSub
            }

            Text {
                x: 5
                y: 111
                width: parent.width - 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: String(tile.modelData.name || "")
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: face.keyNav = false
                onClicked: face.appActivated(tile.modelData)
            }
        }
    }

    Text {
        anchors.centerIn: appGrid
        visible: face.results.length === 0
        text: face.query.trim() ? "No matching applications" : "No applications installed"
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 22
    }
}
