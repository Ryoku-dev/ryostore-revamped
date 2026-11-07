import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

// The screen of the Wallpapers phone: what is drawn inside the flat landscape
// PhoneBody. A gallery app, with everything the wallpaper board had:
//
//   GALLERY  (camera)  <Wallpapers banner>                   clock   <x>
//            (cut-out) [Desktop|Lockscreen]  12 wallpapers   [search] [Newest] (o)(o)(o)
//                      ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
//                      │ pic  │ │ pic  │ │ pic  │ ...        a grid of thumbnails,
//                      └──────┘ └──────┘ └──────┘            scrolling
//
//   VIEWER   (camera)  <Wallpapers banner>        [Gallery]  clock   <x>
//            (cut-out) ┌──────────────────────┐   name
//                      │   the picture        │   [ Set as Desktop    ]
//                      └──────────────────────┘   [ Set as Lockscreen ]   < >
//
// The toolbar is the board's header: the Desktop | Lockscreen switch (only with
// Separate Lockscreen Wallpaper on; it chooses which side's applied picture the
// gallery marks, and the lockscreen side wears the lockscreen's own colours), a
// search field (or just start typing), the sort menu, "jump to applied",
// shuffle (jumps to a random one) and refresh (the dot says the folder changed
// since the list was made; sorting never reads the folder).
//
// Tap a picture to open it in the viewer. The viewer has the two actions:
// Set as Desktop (WallpaperService.setWallpaper) and Set as Lockscreen
// (WallpaperService.setLockWallpaper). With "One wallpaper per monitor" on they
// change this monitor only, and Shift+click changes every monitor. Set as
// Lockscreen turns "Separate Lockscreen Wallpaper" on if it is off (the
// lockscreen would otherwise just follow the desktop), keeping what the
// lockscreen shows now.
//
// The gallery has two looks, switched by the round button at the end of the
// toolbar: the WHEEL (WallpaperWheel.qml, the default: a Ferris wheel the
// pictures hang from; spin it, click the one in front to open it, or set it
// straight from the two keys under it) and the plain GRID above.
//
// Keys: arrows move (on the wheel Left / Right turn it), Enter opens, Escape
// steps back (sort menu, search, viewer, then the launcher phone), Tab flips
// Desktop / Lockscreen, Home / End.
// In the viewer: Left / Right = previous / next, Enter = Set as Desktop.
//
// The camera cut-out is on the left edge, so everything beside it keeps
// `safeLeft` clear. Pure UI apart from WallpaperService: the only thing it
// asks of the outside is `closeRequested()`.
Item {
    id: face

    readonly property bool classicPanel: true

    width: 1440
    height: 760

    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    property real screenInset: 26
    property real cornerRadius: 92
    property real renderScale: 1

    signal closeRequested()

    readonly property real safeLeft: 96
    readonly property real safeRight: 50
    readonly property real pageX: safeLeft
    readonly property real pageTop: 114
    readonly property real pageWidth: width - safeLeft - safeRight
    readonly property real pageHeight: 594

    readonly property real toolbarH: 46
    readonly property real galleryTop: pageTop + 58
    readonly property real galleryHeight: pageHeight - 58

    readonly property int columns: 5
    readonly property real cellW: Math.floor(pageWidth / columns)
    readonly property real cellH: 178

    property int viewIndex: -1
    property string viewPath: ""
    property string viewName: ""
    readonly property bool viewing: viewIndex >= 0

    property real viewP: viewing ? 1 : 0
    Behavior on viewP {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    property bool carousel: true
    property real carouselP: carousel ? 1 : 0
    Behavior on carouselP {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    property bool keyNav: false
    property string justSet: ""

    property string target: "desktop"
    readonly property bool lockMode: WallpaperService.separateLock && face.target === "lock"

    readonly property string desktopPath: WallpaperService.pathFor(face.screenName)
    readonly property string lockPath: WallpaperService.lockPathFor(face.screenName)
    readonly property string currentPath: face.lockMode ? face.lockPath : face.desktopPath
    readonly property string otherPath: !WallpaperService.separateLock ? ""
                                        : (face.lockMode ? face.desktopPath : face.lockPath)

    readonly property bool viewIsVideo: face.viewPath !== "" && WallpaperService.isVideo(face.viewPath)

    property var items: []
    property var matched: []
    property string searchText: ""
    property string sortMode: "date_desc"
    property bool sortOpen: false
    property bool hasNew: false
    property bool listed: false

    readonly property var sortOptions: [
        { mode: "date_desc", label: "Date added (newest first)", short: "Newest" },
        { mode: "date_asc",  label: "Date added (oldest first)", short: "Oldest" },
        { mode: "name_asc",  label: "Name (A to Z)",             short: "A\u2013Z" },
        { mode: "name_desc", label: "Name (Z to A)",             short: "Z\u2013A" },
        { mode: "size_desc", label: "Size (largest first)",      short: "Largest" },
        { mode: "size_asc",  label: "Size (smallest first)",     short: "Smallest" }
    ]

    readonly property string sortShort: {
        for (const o of face.sortOptions) {
            if (o.mode === face.sortMode)
                return o.short
        }
        return ""
    }

    readonly property string subtitle: (WallpaperService.separateLock ? (face.lockMode ? "Lockscreen only  \u00b7  " : "Desktop only  \u00b7  ") : "")
        + (face.searchText.trim() !== ""
            ? face.matched.length + " of " + face.items.length + " match"
            : face.items.length + (face.items.length === 1 ? " wallpaper" : " wallpapers"))
        + (WallpaperService.perMonitor && face.screenName !== "" ? "  \u00b7  for " + face.screenName : "")
        + (WallpaperService.customFolder ? "  \u00b7  " + WallpaperService.directoryShort : "")

    FolderListModel {
        id: files
        folder: WallpaperService.directoryUrl
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp",
                      "*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi"]
        showDirs: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready && !face.listed)
                face.refresh()
        }
        onCountChanged: {
            if (!face.listed) {
                if (status === FolderListModel.Ready)
                    face.refresh()
            } else {
                face.hasNew = true
            }
        }
    }

    Connections {
        target: WallpaperService

        function onDirectoryChanged() {
            face.listed = false
            face.searchText = ""
            if (files.status === FolderListModel.Ready)
                Qt.callLater(face.refresh)
        }
    }

    Component.onCompleted: {
        if (files.status === FolderListModel.Ready)
            face.refresh()
    }

    function sortItems(list, mode) {
        const sorted = list.slice()
        if (mode === "name_asc")
            sorted.sort((a, b) => a.fileName.localeCompare(b.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "name_desc")
            sorted.sort((a, b) => b.fileName.localeCompare(a.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "size_desc")
            sorted.sort((a, b) => b.fileSize - a.fileSize)
        else if (mode === "size_asc")
            sorted.sort((a, b) => a.fileSize - b.fileSize)
        else if (mode === "date_asc")
            sorted.sort((a, b) => a.fileModified - b.fileModified)
        else
            sorted.sort((a, b) => b.fileModified - a.fileModified)
        return sorted
    }

    function refresh() {
        const list = []
        for (let i = 0; i < files.count; i++) {
            const mod = files.get(i, "fileModified")
            list.push({
                fileName: files.get(i, "fileName") || "",
                filePath: files.get(i, "filePath") || "",
                fileSize: files.get(i, "fileSize") || 0,
                fileModified: mod ? new Date(mod).getTime() : 0
            })
        }
        face.items = face.sortItems(list, face.sortMode)
        face.listed = true
        face.hasNew = false
        face.recompute()
    }

    // Re-order what is already listed (never reads the folder).
    function setSort(mode) {
        face.sortMode = mode
        face.items = face.sortItems(face.items, mode)
        face.recompute()
        grid.positionViewAtBeginning()
    }

    function recompute() {
        const q = face.searchText.trim().toLowerCase()
        face.matched = q === "" ? face.items
            : face.items.filter(it => it.fileName.toLowerCase().indexOf(q) !== -1)
    }

    onSearchTextChanged: {
        face.recompute()
        Qt.callLater(() => grid.positionViewAtBeginning())
    }

    function baseName(fileName) {
        const i = fileName.lastIndexOf(".")
        return i > 0 ? fileName.slice(0, i) : fileName
    }

    function goTo(i) {
        if (i < 0 || i >= face.matched.length)
            return
        if (face.carousel) {
            wheelView.rotateTo(i)
            return
        }
        grid.currentIndex = i
        face.keyNav = true
        grid.positionViewAtIndex(i, GridView.Center)
    }

    function jumpToApplied() {
        face.sortOpen = false
        for (let i = 0; i < face.matched.length; i++) {
            if (face.matched[i].filePath === face.currentPath) {
                face.goTo(i)
                return
            }
        }
    }

    function shuffle() {
        face.sortOpen = false
        if (face.matched.length > 0)
            face.goTo(Math.floor(Math.random() * face.matched.length))
    }

    function showIndex(i) {
        const n = face.matched.length
        if (n <= 0)
            return
        const k = ((i % n) + n) % n
        face.sortOpen = false
        face.viewIndex = k
        face.viewPath = face.matched[k].filePath
        face.viewName = face.matched[k].fileName
        grid.currentIndex = k
        wheelView.rotateTo(k)
        face.justSet = ""
    }

    function toggleLook() {
        face.sortOpen = false
        if (face.carousel) {
            const i = wheelView.centerIndex
            if (i >= 0) {
                grid.currentIndex = i
                grid.positionViewAtIndex(i, GridView.Center)
            }
        } else if (grid.currentIndex >= 0) {
            wheelView.rotateTo(grid.currentIndex)
        }
        face.carousel = !face.carousel
    }

    function closeViewer() {
        if (face.viewIndex >= 0)
            grid.positionViewAtIndex(face.viewIndex, GridView.Contain)
        face.viewIndex = -1
        face.justSet = ""
    }

    function back() {
        if (face.sortOpen)
            face.sortOpen = false
        else if (face.viewing)
            face.closeViewer()
        else if (face.searchText !== "")
            search.clear()
        else
            face.closeRequested()
    }

    function setDesktop(all, path) {
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        if (all)
            WallpaperService.setWallpaper(p)
        else
            WallpaperService.setWallpaper(p, face.screenName)
        face.flash("desktop")
    }

    function setLock(all, path) {
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        if (!WallpaperService.separateLock)
            WallpaperService.setSeparateLock(true)
        if (all)
            WallpaperService.setLockWallpaper(p)
        else
            WallpaperService.setLockWallpaper(p, face.screenName)
        face.flash("lock")
    }

    function flash(which) {
        face.justSet = which
        flashTimer.restart()
    }

    function replayDeal() {
        if (face.carousel)
            wheelView.deal()
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: face.justSet = ""
    }

    focus: true


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

    Item {
        id: banner

        x: face.safeLeft - 8
        y: 28
        height: 70
        width: bannerKey.capW + 8

        TansuKey {
            id: bannerKey

            capW: 420
            capH: 66
            radius: 26
            lit: true
            litP: 1
            borderBase: 4
            borderLit: 4
            ringExtra: 5
            shadowBaseX: 5
            shadowBaseY: 4

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
                name: face.lockMode ? "lock" : "wallpaper"
                color: Theme.colBorder
            }

            Column {
                x: 92
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Wallpapers"
                    color: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    lineHeight: 29
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    text: face.viewing ? "Preview" : (face.carousel ? "Spin the wheel" : "Pick a picture")
                    color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.78)
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    lineHeight: 17
                    lineHeightMode: Text.FixedHeight
                }
            }

            MaterialIcon {
                x: bannerKey.capW - 52
                y: 8
                size: 24
                name: "star"
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
        radius: 20

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
        x: clockChip.x - 24 - width
        y: 38
        icon: "arrow_back"
        label: "Gallery"
        opacity: face.viewP
        visible: opacity > 0.01
        enabled: face.viewing
        onClicked: face.closeViewer()
    }

    WheelScroll { scroller: grid }
    GridView {
        id: grid

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        clip: true
        cellWidth: face.cellW
        cellHeight: face.cellH
        model: face.matched
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        maximumFlickVelocity: 3200

        opacity: (1 - face.viewP) * (1 - face.carouselP)
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: !face.viewing && !face.carousel

        delegate: Item {
            id: cell

            required property int index
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property string path: cell.modelData.filePath
            readonly property bool applied: cell.path === face.currentPath
            readonly property bool other: face.otherPath !== "" && cell.path === face.otherPath
            readonly property bool picked: face.keyNav && GridView.isCurrentItem
            readonly property bool hot: area.containsMouse || picked
            readonly property bool video: WallpaperService.isVideo(cell.path)
            readonly property real tw: cell.width - 22
            readonly property real th: cell.height - 22

            readonly property color markColor: face.lockMode ? LockPalette.pink : Theme.accentMint
            readonly property color otherColor: face.lockMode ? Theme.accentCyan : LockPalette.pink

            readonly property real push: area.pressed ? 5 : (cell.hot ? -2 : 0)

            Rectangle {
                x: 9
                y: 9
                width: cell.tw
                height: cell.th
                radius: 16
                color: Theme.pLineShadow
            }

            Rectangle {
                id: body

                x: 4 + cell.push
                y: 4 + cell.push
                width: cell.tw
                height: cell.th
                radius: 16
                color: Theme.pSurface
                border.width: 4
                border.color: cell.hot ? Theme.accentCyan : Theme.pLine

                Behavior on x {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: Theme.pSurfaceHover

                    Image {
                        id: thumb

                        anchors.fill: parent
                        source: WallpaperService.thumbUrl(cell.path)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.ceil(Math.max(cell.tw, cell.th * 1.8) * face.renderScale * 2)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        size: 40
                        name: cell.video ? "movie" : "image"
                        color: Theme.pInkSub
                    }

                    Rectangle {
                        visible: cell.video
                        x: parent.width - width - 10
                        y: parent.height - height - 10
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.pSurface
                        border.width: 3
                        border.color: Theme.pLine

                        MaterialIcon {
                            anchors.centerIn: parent
                            size: 18
                            name: "play_arrow"
                            color: Theme.colBorder
                        }
                    }
                }

                Rectangle {
                    visible: cell.applied
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: "transparent"
                    border.width: 5
                    border.color: cell.markColor
                }

                Rectangle {
                    visible: cell.applied
                    x: parent.width - width - 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.markColor
                    border.width: 3
                    border.color: Theme.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        name: "check"
                        weight: 700
                        color: Theme.colBorder
                    }
                }

                Rectangle {
                    visible: cell.other
                    x: 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.otherColor
                    border.width: 3
                    border.color: Theme.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 19
                        name: face.lockMode ? "desktop_windows" : "lock"
                        color: Theme.colBorder
                    }
                }

                Rectangle {
                    x: 10
                    y: parent.height - height - 10
                    width: Math.min(parent.width - 20 - (cell.video ? 40 : 0), nameText.implicitWidth + 22)
                    height: 28
                    radius: 14
                    color: Theme.pSurface
                    border.width: 3
                    border.color: Theme.pLine
                    opacity: cell.hot ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        width: parent.width - 18
                        horizontalAlignment: Text.AlignHCenter
                        text: face.baseName(cell.modelData.fileName)
                        elide: Text.ElideMiddle
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: face.keyNav = false
                onClicked: face.showIndex(cell.index)
            }
        }
    }

    Rectangle {
        visible: face.viewP < 0.5 && !face.carousel && grid.contentHeight > grid.height + 1
        x: grid.x + grid.width - 8
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 6
        height: Math.max(40, grid.visibleArea.heightRatio * grid.height)
        radius: 3
        color: Theme.pSurfaceRing
        opacity: 1 - face.viewP
    }

    WallpaperWheel {
        id: wheelView

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        items: face.matched
        currentPath: face.currentPath
        otherPath: face.otherPath
        desktopPath: face.desktopPath
        lockPath: face.lockPath
        lockMode: face.lockMode
        justSet: face.justSet
        renderScale: face.renderScale
        active: face.carousel && !face.viewing

        opacity: face.carouselP * (1 - face.viewP)
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: face.carousel && !face.viewing

        onOpened: index => face.showIndex(index)
        onSetDesktopRequested: (path, all) => face.setDesktop(all, path)
        onSetLockRequested: (path, all) => face.setLock(all, path)
    }

    Column {
        x: face.pageX + (face.pageWidth - width) / 2
        y: face.galleryTop + (face.galleryHeight - height) / 2
        visible: face.listed && face.matched.length === 0 && face.viewP < 0.5
        spacing: 8

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            name: face.items.length === 0 ? "photo_library" : "search_off"
            color: Theme.pInkSub
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: face.items.length === 0 ? "No wallpapers yet" : "No wallpapers match \u201c" + face.searchText + "\u201d"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.items.length === 0
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: "Put pictures or videos in " + WallpaperService.directoryShort + ", or choose another folder"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: toolbar

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.toolbarH
        z: 5
        opacity: 1 - face.viewP
        visible: opacity > 0.01
        enabled: !face.viewing

        WallpaperTargetSwitch {
            id: targetSwitch

            visible: WallpaperService.separateLock
            x: 2
            y: 2
            current: face.target
            onPicked: id => {
                face.sortOpen = false
                face.target = id
            }
        }

        Text {
            x: (targetSwitch.visible ? targetSwitch.x + targetSwitch.width + 18 : 4)
            y: 2
            height: 40
            width: Math.max(0, controls.x - x - 14)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: face.subtitle
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 2
            spacing: 12

            SearchPill {
                id: search

                placeholder: "Search wallpapers"
                onTextChanged: face.searchText = text
                onLeave: face.forceActiveFocus()
            }

            SortChip {
                id: sortChip

                label: face.sortShort
                active: face.sortOpen
                onClicked: face.sortOpen = !face.sortOpen
            }

            MagnetButton {
                icon: "folder_open"
                label: "Wallpaper folder"
                active: WallpaperService.customFolder
                onClicked: {
                    face.sortOpen = false
                    WallpaperService.pickFolder(face.lockMode ? "lock" : "desktop")
                }
            }

            MagnetButton {
                icon: "my_location"
                label: "Jump to applied"
                onClicked: face.jumpToApplied()
            }

            MagnetButton {
                icon: "shuffle"
                label: "Shuffle"
                onClicked: face.shuffle()
            }

            MagnetButton {
                icon: "refresh"
                label: "Refresh"
                badge: face.hasNew
                onClicked: {
                    face.sortOpen = false
                    face.refresh()
                }
            }

            MagnetButton {
                icon: face.carousel ? "grid_view" : "view_carousel"
                label: face.carousel ? "Grid" : "Wheel"
                onClicked: face.toggleLook()
            }
        }

        GallerySortCard {
            x: controls.x + sortChip.x + sortChip.width - width
            y: face.toolbarH + 6
            shown: face.sortOpen
            sortMode: face.sortMode
            options: face.sortOptions
            onSelected: mode => {
                face.setSort(mode)
                face.sortOpen = false
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 4
        enabled: face.sortOpen
        onClicked: face.sortOpen = false
    }

    Item {
        id: viewerArea

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.pageHeight
        opacity: face.viewP
        scale: 0.96 + 0.04 * face.viewP
        visible: opacity > 0.01
        enabled: face.viewing

        readonly property real cardW: 830
        readonly property real cardH: Math.round(cardW / 1.6)
        readonly property real panelX: cardW + 42
        readonly property real panelW: width - panelX - 6

        Rectangle {
            x: 9
            y: 15
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: Theme.pLineShadow
        }

        Rectangle {
            x: 0
            y: 6
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: Theme.pSurface
            border.width: 5
            border.color: Theme.pLine

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 19
                color: Theme.pSurfaceHover

                Image {
                    id: bigPicture

                    anchors.fill: parent
                    source: face.viewPath === "" ? ""
                            : (face.viewIsVideo ? WallpaperService.thumbUrl(face.viewPath) : "file://" + face.viewPath)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(Math.min(3840, Math.ceil(viewerArea.cardW * face.renderScale * 2)),
                                        Math.min(2400, Math.ceil(viewerArea.cardH * face.renderScale * 2)))
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: bigPicture.status !== Image.Ready
                    size: 64
                    name: face.viewIsVideo ? "movie" : "image"
                    color: Theme.pInkSub
                }
            }
        }

        Column {
            x: viewerArea.panelX
            y: 6
            width: viewerArea.panelW
            spacing: 8

            Text {
                width: parent.width
                text: face.viewName
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 28
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                text: face.viewIsVideo ? "Video wallpaper" : "Picture"
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 10

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.desktopPath
                    width: onDesk.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: Theme.accentMint
                    border.width: 3
                    border.color: Theme.colBorder

                    Text {
                        id: onDesk
                        anchors.centerIn: parent
                        text: "On your desktop"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.lockPath
                    width: onLock.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: LockPalette.pink
                    border.width: 3
                    border.color: Theme.colBorder

                    Text {
                        id: onLock
                        anchors.centerIn: parent
                        text: "On your lockscreen"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }
            }
        }

        WallpaperActionKey {
            x: viewerArea.panelX
            y: 214
            capW: viewerArea.panelW - 8
            icon: "desktop_windows"
            label: "Set as Desktop"
            done: face.justSet === "desktop"
            onClicked: all => face.setDesktop(all)
        }

        WallpaperActionKey {
            x: viewerArea.panelX
            y: 312
            capW: viewerArea.panelW - 8
            icon: "lock"
            label: "Set as Lockscreen"
            done: face.justSet === "lock"
            onClicked: all => face.setLock(all)
        }

        Text {
            x: viewerArea.panelX
            y: 410
            width: viewerArea.panelW
            wrapMode: Text.WordWrap
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            text: {
                const lines = []
                if (WallpaperService.perMonitor && face.screenName !== "")
                    lines.push("Changes this monitor (" + face.screenName + ") only. Shift+click: every monitor.")
                if (!WallpaperService.separateLock)
                    lines.push("Set as Lockscreen turns on a separate lockscreen wallpaper.")
                return lines.join("\n")
            }
        }

        Row {
            x: viewerArea.panelX
            y: viewerArea.cardH - 40
            spacing: 14

            TansuNavKey {
                icon: "chevron_left"
                label: "Previous"
                onClicked: face.showIndex(face.viewIndex - 1)
            }

            TansuNavKey {
                icon: "chevron_right"
                label: "Next"
                onClicked: face.showIndex(face.viewIndex + 1)
            }
        }
    }
}
