import QtQuick
import "../../../services"
import "../../../modules/common"
import "../../common/functions/FlipMath.js" as FM
import "../../../modules/tansu/phone"
import "../../../modules/tansu/wallpaperSelector"

Item {
    id: root

    readonly property bool flatLook: Theme.quickFlat

    property real gridOffsetX: 0
    property real gridOffsetY: 0

    property string content: "settings"
    property string initialTarget: "desktop"
    property var source: null
    property var notificationSource: null
    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    property bool active: false

    property real faceWidth: 1440
    property real faceHeight: 760
    property real cornerRadius: 92

    property real thickness: 135

    property real yaw: 24
    property real pitch: 12
    property real roll: 0
    property real perspective: 6000

    property real popFrom: 0.55
    property real tiltYaw: -22
    property real tiltPitch: 14
    property real tiltRoll: 7
    // How much of that turn the entrance really uses: none in 2D. The numbers above stay the
    // same in 2D on purpose, because they are also the ROOM the phone's picture and the window
    // are made with (`swingYaw/Pitch/Roll` below): the wobble that rings out when the turn lands
    // rolls the phone by a few degrees, and without that room its top (the notch side) was cut
    // off by the edge of the picture while it rang.
    readonly property real tiltK: root.flatLook ? 0 : 1
    readonly property real grow: 1.1

    property real fit: 1
    property real centerX: 0
    property real centerY: 0
    property real pixelRatio: 1

    property real flip: 1
    property real quickFit: 1
    property real quickYaw: 33
    property real quickPitch: 18
    property real dipDepth: 0.12

    property real pop: 1
    property real alpha: 1
    property real tilt: 0

    property real wob: 0

    property bool moving: false
    property bool busy: false
    property bool turning: false

    readonly property alias phone: phone
    readonly property alias face: face
    readonly property var wallpaperFace: wallLoader.item
    readonly property bool wallpapersUp: root.content === "wallpapers"

    property real contentK: root.content === "wallpapers" ? 1 : 0
    Behavior on contentK {
        enabled: root.flip >= 1 && !root.turning && root.pop >= 1 && root.alpha >= 1
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    property bool straightOn: true
    // 2D: both screens face straight on. Otherwise only the Wallpapers do (`straightOn`).
    readonly property real straightGoal: root.flatLook || (root.straightOn && root.content === "wallpapers") ? 1 : 0
    property real straightK: root.straightGoal
    Behavior on straightK {
        enabled: root.flip >= 1 && !root.turning && root.pop >= 1 && root.alpha >= 1
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    readonly property bool straightMoving: root.straightK !== root.straightGoal
    readonly property real straightEff: root.straightK * root.flip
    readonly property real yawEnd: root.yaw * (1 - root.straightK)
    readonly property real pitchEnd: root.pitch * (1 - root.straightK)

    readonly property real halfW: Math.max(phone.screenCenterX + phone.swing.left,
                                           phone.implicitWidth - phone.screenCenterX + phone.swing.right)
    readonly property real halfH: Math.max(phone.screenCenterY + phone.swing.top,
                                           phone.implicitHeight - phone.screenCenterY + phone.swing.top)

    readonly property real shownOpacity: alpha * FM.settingsAlpha(flip)

    readonly property real turnSize: FM.quickScale(flip, quickFit, fit, dipDepth)
                                     / (FM.SIZE_RATIO * Math.max(0.0001, fit))

    signal closeRequested()
    signal wallpapersRequested()
    signal lockWallpapersRequested()
    signal desktopEditRequested()
    signal searchLeft()
    signal wallpapersCloseRequested()
    signal wallpapersLoaded()

    property bool warmWallpapers: false

    function dealIfWarm() {
        if (root.wallpaperFace && root.wallpaperFace.listed)
            root.wallpaperFace.replayDeal()
    }

    function focusWallpapers() {
        if (root.wallpaperFace)
            root.wallpaperFace.forceActiveFocus()
    }

    function setTarget(which) {
        root.initialTarget = which === "lock" ? "lock" : "desktop"
        if (root.wallpaperFace)
            root.wallpaperFace.target = root.initialTarget
    }

    readonly property bool settled: flip >= 1 && pop >= 1 && tilt === 0 && wob === 0 && !turning
    readonly property real gridPx: Math.max(1, pixelRatio)
    // Which point of the body stands on the pivot: the tilted pose's screen middle, or in 2D
    // the front's own middle (they are 27 and 14 design units apart for this phone's pose, which
    // is what would otherwise leave a flat phone that far off the middle of the monitor).
    readonly property real anchorX: root.flatLook ? phone.frontCenter.x : phone.screenCenterX
    readonly property real anchorY: root.flatLook ? phone.frontCenter.y : phone.screenCenterY
    readonly property real sceneX: centerX - anchorX * fit - (phone.layerSwing.left + 8) * fit
    readonly property real sceneY: centerY - anchorY * fit - (phone.layerSwing.top + 8) * fit

    readonly property bool direct: root.settled && !root.moving && !root.straightMoving
                                   && root.flip === 1 && root.straightK >= 1
                                   && (root.contentK <= 0 || root.contentK >= 1) && root.pop === 1
    // The straightened phone's front is not where the tilted pose's middle was
    // (see PhoneBody `directCenterX`), and the direct draw lands exactly where the
    // straightening arrived: that is why switching to it moves nothing. The same
    // offset puts the screen's top-left on a whole device pixel below.
    readonly property real directDX: (phone.directCenterX - root.anchorX) * fit
    readonly property real directDY: (phone.directCenterY - root.anchorY) * fit
    readonly property real faceLeftDev: (centerX + directDX + gridOffsetX) * pixelRatio - phone.directW / 2
    readonly property real faceTopDev: (centerY + directDY + gridOffsetY) * pixelRatio - phone.directH / 2

    readonly property real snapX: direct ? (Math.round(faceLeftDev) - faceLeftDev) / pixelRatio
                                         : (settled ? Math.round(sceneX * gridPx) / gridPx - sceneX : 0)
    readonly property real snapY: direct ? (Math.round(faceTopDev) - faceTopDev) / pixelRatio
                                         : (settled ? Math.round(sceneY * gridPx) / gridPx - sceneY : 0)

    Item {
        id: pivot

        x: root.centerX + root.snapX
        y: root.centerY + root.snapY
        scale: (root.popFrom + (1 - root.popFrom) * root.pop) * root.turnSize
        opacity: root.shownOpacity
        visible: opacity > 0.001

        PhoneBody {
            id: phone

            landscape: true
            faceWidth: root.faceWidth
            faceHeight: root.faceHeight
            cornerRadius: root.cornerRadius
            thickness: root.thickness
            perspective: root.perspective
            yaw: root.yaw
            pitch: root.pitch
            roll: root.roll

            windowShown: root.active

            x: -root.anchorX * root.fit
            y: -root.anchorY * root.fit
            transformOrigin: Item.TopLeft
            scale: root.fit

            moving: root.moving || root.straightMoving
            busy: root.busy
            turnRoll: root.turning ? 90 : 0

            // Standing straight and still: no side wall, and the screen goes
            // straight to the pixels (see `root.direct`).
            // (2D: edge-on the whole time, so the wall is never built, the entrance included.)
            flat: root.direct || (root.flatLook && root.straightK >= 1)
            faceDirect: root.direct
            plain: root.flatLook
            directCenterX: phone.frontCenter.x
            directCenterY: phone.frontCenter.y

            rollOffset: root.tilt * root.tiltK * root.tiltRoll + FM.settingsRoll(root.flip) + root.wob
            pitchOffset: root.tilt * root.tiltK * root.tiltPitch + (root.quickPitch - root.pitch) * (1 - root.flip) + root.wob * 0.5
                         - root.pitch * root.straightEff
            yawOffset: root.tilt * root.tiltK * root.tiltYaw + (root.quickYaw - root.yaw) * (1 - root.flip)
                       - root.yaw * root.straightEff

            swingRoll: root.tiltRoll
            swingPitch: root.tiltPitch
            swingYaw: root.tiltYaw

            renderScale: root.fit * root.pixelRatio

            SettingsFace {
                id: face

                opacity: 1 - root.contentK
                visible: opacity > 0.001
                enabled: !root.wallpapersUp

                source: root.source
                notificationSource: root.notificationSource
                screenName: root.screenName
                clockText: root.clockText
                dateText: root.dateText
                active: root.active
                calm: !root.moving && !root.wallpapersUp
                screenInset: phone.screenInset
                cornerRadius: root.cornerRadius
                renderScale: phone.renderScale

                onCloseRequested: root.closeRequested()
                onWallpapersRequested: root.wallpapersRequested()
                onLockWallpapersRequested: root.lockWallpapersRequested()
                onDesktopEditRequested: root.desktopEditRequested()
                onSearchLeft: root.searchLeft()
            }

            Loader {
                id: wallLoader

                width: root.faceWidth
                height: root.faceHeight
                active: (root.active && (root.wallpapersUp || root.contentK > 0.001)) || root.warmWallpapers
                asynchronous: true

                readonly property real ready: wallLoader.status === Loader.Ready ? 1 : 0
                property real arrive: wallLoader.ready
                Behavior on arrive {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }

                opacity: root.contentK * wallLoader.arrive
                visible: opacity > 0.001
                enabled: root.wallpapersUp

                onLoaded: {
                    root.setTarget(root.initialTarget)
                    root.wallpapersLoaded()
                }

                sourceComponent: Component {
                    WallpaperFace {
                        screenName: root.screenName
                        clockText: root.clockText
                        dateText: root.dateText
                        screenInset: phone.screenInset
                        cornerRadius: root.cornerRadius
                        renderScale: phone.renderScale

                        onCloseRequested: root.wallpapersCloseRequested()
                    }
                }
            }
        }
    }
}
