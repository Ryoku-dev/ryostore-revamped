import QtQuick
import "../../common/functions/PhoneMath.js" as PM
import "../../../modules/common"
import "../../../services"

// The phone the Quick Panel lives in — its "hardware". Whatever you put
// inside a PhoneBody ends up on the phone's screen; this draws the body
// around it and puts the whole thing in a 2.5D pose, modelled on the
// Figma "REFERENCE 2.5 PHONE FOR QUICK PANEL" render:
//
//   - a real thickness: the frame is a solid, so the right-hand side (and
//     a sliver of the bottom) shows, with a bright edge along the front
//     rim fading darker toward the back
//   - side buttons on the right edge (the upper, slim one can be the live Power
//     button, see `powerButton`), and speaker / port holes on the bottom edge
//   - a notch with a camera lens
//   - perspective: the edge nearer the viewer is a little bigger
//
// How the 3D is done: nothing here is a 3D model. The screen is one flat
// layer, and the thickness is the same rounded rectangle repeated many
// times, each one pushed a little further back. Every layer goes through
// the same 4x4 matrix (PhoneMath.js) — a rotation plus perspective — and
// stacked, the offsets between them read as a solid side wall. Because
// they all share one matrix, taps and hover land on the right spot on the
// tilted screen, too.
//
// Pure UI (no Quickshell imports).
Item {
    id: root

    property real faceWidth: 654
    property real faceHeight: 1214
    property real cornerRadius: 100
    property bool landscape: false

    property bool powerButton: false
    property bool powerOn: false
    signal powerClicked()
    readonly property real powerY: 338
    readonly property real powerH: 150
    readonly property real buttonStick: 14
    readonly property int buttonSlices: 7
    readonly property real powerStick: 18

    property bool powerHeld: false
    readonly property bool powerDown: root.powerHeld || powerHoldTimer.running
    property real powerPress: root.powerDown ? 1 : 0
    readonly property real powerKeep: 0.15
    readonly property real powerStickNow: root.buttonStick * (1 - (1 - root.powerKeep) * root.powerPress)
    readonly property real powerSlide: 11
    Behavior on powerPress {
        NumberAnimation {
            duration: root.powerDown ? 70 : 190
            easing.type: root.powerDown ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 2
        }
    }
    Timer {
        id: powerHoldTimer
        interval: 110
    }

    property real rimWidth: Theme.phoneRimWidth
    property real bezelWidth: Theme.phoneBezelWidth
    readonly property real screenInset: rimWidth + bezelWidth
    // How far the notch reaches back into the dark glass past the screen's edge, so
    // it and the bezel are one shape (they are the same colour). Inside the glass:
    // it must stay under bezelWidth.
    readonly property real notchLead: Math.min(14, bezelWidth - 2)

    property bool shadow: SettingsService.flag("quick.phoneShadow")
    property real shadowDx: 3
    property real shadowDy: 12
    property color shadowColor: Qt.rgba(0, 0, 0, 0.17)
    readonly property real shadowFade: 40
    readonly property real shadowEdge: 140

    property real thickness: 92
    property real yaw: 33
    property real pitch: 18
    property real roll: 0
    // Added on top of the pose above while drawing — but not to the size
    // the phone reports, so animating them (QuickPanel tilts the phone as
    // it comes out of the "pocket") never resizes anything.
    property real yawOffset: 0
    property real pitchOffset: 0
    property real rollOffset: 0

    property real swingYaw: 0
    property real swingPitch: 0
    property real swingRoll: 0
    // How far the phone may be turned in the plane of the screen (degrees,
    // signed: negative is anticlockwise) — the Quick Panel turning into the
    // Settings phone rolls its body by up to 90 (see FlipMath.js). Unlike
    // the swing* values this never changes the size the phone reports (so it
    // can't resize a window); it only makes the picture the phone is drawn into
    // big enough that a phone rolled that far isn't cut off by its edges.
    // Leave it 0 whenever the phone isn't turning: the bigger picture costs
    // sharpness and memory (see `ss`).
    property real turnRoll: 0
    property real perspective: 3400

    property real renderScale: 1

    property real superSample: 2

    property bool moving: false
    property bool busy: false
    property int settleDelay: 150
    property bool crisp: true
    property int moveSamples: 2
    property int restSamples: 4
    property real moveMegapixels: 8
    property int turnSamples: 2
    property real turnMegapixels: 2.5
    readonly property bool turnLite: turnRoll !== 0
    property real restMegapixels: 10

    readonly property bool active: moving || busy

    // ===== graphics memory while it is out of sight (cold / warm) =====
    // Every layer below (scene, wall, face) keeps a multisample colour buffer, a
    // multisample depth/stencil buffer and a resolve texture, at `samples` x
    // the picture's size. Qt keeps them for as long as the layer is switched
    // on, and Quickshell hides a window with a plain setVisible(false), which
    // does not give them back. On an iGPU that memory is system RAM, so a
    // phone that was opened once would hold it for the rest of the session.
    //
    // `windowShown` is set by the owner: is the window this phone lives in
    // mapped? (true = the old behaviour, for an owner that does not say.) A
    // phone that has not been on screen for `coolDelay` ms goes cold: all its
    // layers are switched off and their buffers are freed. The moment it is on
    // screen again it is warm again, in the same event-loop turn, before the
    // first frame is drawn, and every layer is exactly what it was (same size,
    // same samples, same mipmaps). Opening again within `coolDelay` finds the
    // buffers still there. Set `coolDelay` to a huge number (or windowShown to
    // true) to get the old always-resident behaviour back.
    property bool windowShown: true
    property int coolDelay: 20000
    readonly property bool onScreen: windowShown && root.visible
    property bool warm: false

    onOnScreenChanged: {
        if (onScreen) {
            coolTimer.stop()
            warm = true
        } else {
            coolTimer.restart()
        }
    }

    Timer {
        id: coolTimer
        interval: root.coolDelay
        onTriggered: root.warm = root.onScreen
    }

    readonly property int samples: turnLite ? turnSamples : (moving ? moveSamples : restSamples)

    onActiveChanged: {
        if (active) {
            settleTimer.stop()
            crisp = false
        } else {
            settleTimer.restart()
        }
    }

    Component.onCompleted: {
        crisp = !active
        wallFine = !moving
        warm = onScreen
    }

    // The fine side wall (see `sliceCount`) is only built once the phone
    // has stopped moving, a beat after it lands, so the pull-out itself
    // never has to draw it.
    onMovingChanged: {
        if (moving) {
            wallTimer.stop()
            wallFine = false
        } else {
            wallTimer.restart()
        }
    }

    Timer {
        id: wallTimer
        interval: 140
        onTriggered: root.wallFine = !root.moving
    }

    Timer {
        id: settleTimer
        interval: root.settleDelay
        onTriggered: root.crisp = true
    }

    readonly property real ss: {
        if (superSample <= 0)
            return 1
        const px = scene.width * scene.height * renderScale * renderScale
        const mp = turnLite ? turnMegapixels : (moving ? moveMegapixels : restMegapixels)
        return Math.max(1, Math.min(superSample, Math.sqrt(mp * 1000000 / Math.max(1, px))))
    }

    // Same idea, but for `face` alone (the screen content: buttons,
    // sliders, text -- everything the cursor is actually over while
    // interacting, and what you're looking at while the phone pops in
    // or out). Neither `moving` nor `busy` trims this: it's the layer
    // you're actually focused on while dragging a slider, holding a
    // button, or watching the phone arrive/leave, so it always draws at
    // full quality. `contentTrimmed` is kept (always false) rather than
    // removed outright, so `layer.mipmap` below still reads as a single
    // toggle if a future case ever needs this tier back.
    //
    // Sharpness rule for this layer: the face is drawn flat into a
    // texture, tilted, and drawn into `scene`, which is then shrunk to
    // the monitor. Every one of those steps that isn't 1:1 softens the
    // text. Trilinear mipmapping makes it worse: it blends in the next,
    // half-size level whenever the tilt shrinks the picture even a
    // little (the far side always is), which is a plain blur. So the
    // face is drawn at the SAME texel density as the scene it lands in
    // (`faceOversample` 1, not "a bit more to be safe" -- 1.4 plus
    // mipmaps was measurably softer) and sampled with plain bilinear
    // (`faceMipmap` off): the tilt shrinks it by at most ~1.2x at rest,
    // which bilinear handles without aliasing. Raise `faceMipmap` again
    // only if thin lines shimmer while the phone flies in.
    property real faceOversample: 1
    property bool faceMipmap: false
    readonly property bool contentTrimmed: false
    readonly property real contentSS: {
        if (superSample <= 0)
            return 1
        const px = root.faceWidth * root.faceHeight * renderScale * renderScale
        const cap = Math.sqrt(restMegapixels * 1000000 / Math.max(1, px))
        // Never denser than the scene is at rest (same 10 MP cap, but
        // measured on the scene, which is the bigger picture).
        const sceneCap = Math.sqrt(restMegapixels * 1000000
                                   / Math.max(1, scene.width * scene.height * renderScale * renderScale))
        return Math.max(1, Math.min(superSample * faceOversample, cap, Math.max(1, sceneCap)))
    }
    readonly property int contentSamples: restSamples

    // ===== a flat front, drawn straight to the pixels (faceDirect) =====
    // For a phone that faces straight on and stays that way (the Overview phone
    // once it has landed). Its owner turns this on only while yaw, pitch and roll
    // are exactly 0 after the offsets above.
    //
    // Why: the tilted body draws the front through a 4x4 matrix, and even with
    // every angle at 0 that matrix still scales the front by `flatScale` (the
    // perspective, because the body is centred in its own thickness) and moves it
    // by the resting pose's odd, fractional offsets. So the front's texels never
    // land on the big picture's texels, and the picture is then shrunk to the
    // monitor from a second, unrelated grid: two softening resamples, drifting in
    // and out of phase across the screen.
    //
    // Here the front is instead drawn into a texture that is an exact whole number
    // of times the size it has on the monitor (`directW` x `directH` device pixels,
    // times a whole `directK`), shown with a plain scale and move (no perspective),
    // straight to the window with no big picture in between. The owner puts its
    // top-left on a whole device pixel, so one
    // device pixel is exactly `directK` x `directK` texels: the only resample left
    // is a clean box filter.
    property bool faceDirect: false

    readonly property real flatScale: 1 / (1 - (thickness / 2) / perspective)
    readonly property int directW: Math.max(1, Math.round(faceWidth * flatScale * renderScale))
    readonly property int directH: Math.max(1, Math.round(faceHeight * flatScale * renderScale))
    readonly property int directK: Math.max(1, Math.floor(contentSS))
    readonly property real directScaleX: directW / Math.max(0.0001, faceWidth * renderScale)
    readonly property real directScaleY: directH / Math.max(0.0001, faceHeight * renderScale)

    readonly property var frontCenter: PM.apply(drawBase, faceWidth / 2, faceHeight / 2, 0)
    // Where `faceDirect` puts the middle of the front. It is the middle of the
    // resting screen (screenCenterX / Y) unless the owner says otherwise. Those
    // are NOT where a phone that has straightened from the tilted pose ends up:
    // the body turns about its own middle (half its thickness behind the front),
    // so the flat front's middle is some way from the tilted front's middle (27 and
    // 14 design units for the Settings' pose). An owner that eases a tilted phone
    // flat and then goes direct sets these to `frontCenter`, so that switching to
    // the direct draw does not move the phone.
    property real directCenterX: screenCenterX
    property real directCenterY: screenCenterY

    readonly property var frontMatrix: root.faceDirect
        ? Qt.matrix4x4(root.directScaleX, 0, 0, root.directCenterX - root.directScaleX * root.faceWidth / 2,
                       0, root.directScaleY, 0, root.directCenterY - root.directScaleY * root.faceHeight / 2,
                       0, 0, 1, 0,
                       0, 0, 0, 1)
        : root.matrix(PM.ident())

    property color rimColor: Theme.colBorder
    property color rimHighlight: Theme.phoneRimHighlight
    property color bezelColor: Theme.phoneBezel
    property color screenColor: Theme.pSurface
    property color wallLight: Theme.phoneWallLight
    property color wallMid: Theme.phoneWallMid
    property color wallDark: Theme.phoneWallDark
    property color hardwareDark: Theme.phoneHardware

    default property alias content: contentHost.data

    readonly property var pose: PM.build(faceWidth, faceHeight, thickness, cornerRadius,
                                         yaw, pitch, roll, perspective, 4)
    implicitWidth: pose.w
    implicitHeight: pose.h
    width: implicitWidth
    height: implicitHeight

    readonly property real screenCenterX: pose.cx
    readonly property real screenCenterY: pose.cy

    readonly property var swing: {
        let minX = pose.pad, maxX = pose.w - pose.pad, minY = pose.pad
        for (const k of [1, 0.5, -0.4]) {
            const b = PM.boundsFor(faceWidth, faceHeight, thickness, cornerRadius,
                                   yaw + swingYaw * k, pitch + swingPitch * k,
                                   roll + swingRoll * k, perspective, pose)
            minX = Math.min(minX, b.minX)
            maxX = Math.max(maxX, b.maxX)
            minY = Math.min(minY, b.minY)
        }
        return { left: pose.pad - minX, right: maxX - (pose.w - pose.pad), top: pose.pad - minY }
    }

    // `swing` for the picture the phone is drawn into (see `scene`): the same,
    // plus the in-plane roll of `turnRoll`, plus the bottom edge (a window
    // never needs that one, the screen's edge is there, but a phone turning
    // about its middle swings out below its resting size as well, and the
    // picture has to hold it). Equal to `swing` (and 0 at the bottom) while
    // turnRoll is 0, so nothing changes until a turn is asked for.
    readonly property var layerSwing: {
        if (turnRoll === 0)
            return { left: swing.left, right: swing.right, top: swing.top, bottom: 0 }
        let minX = pose.pad, maxX = pose.w - pose.pad
        let minY = pose.pad, maxY = pose.h - pose.pad
        for (const kr of [-0.2, 0, 0.25, 0.5, 0.75, 1, 1.2]) {
            for (const k of [1, 0.5, -0.4]) {
                const b = PM.boundsFor(faceWidth, faceHeight, thickness, cornerRadius,
                                       yaw + swingYaw * k, pitch + swingPitch * k,
                                       roll + swingRoll * k + turnRoll * kr, perspective, pose)
                minX = Math.min(minX, b.minX)
                maxX = Math.max(maxX, b.maxX)
                minY = Math.min(minY, b.minY)
                maxY = Math.max(maxY, b.maxY)
            }
        }
        return { left: pose.pad - minX, right: maxX - (pose.w - pose.pad),
                 top: pose.pad - minY, bottom: maxY - (pose.h - pose.pad) }
    }

    readonly property var drawBase: PM.baseFor(faceWidth, faceHeight, thickness,
                                               yaw + yawOffset, pitch + pitchOffset,
                                               roll + rollOffset, perspective, pose)

    function matrix(local) {
        const m = PM.mul(drawBase, local)
        return Qt.matrix4x4(m[0], m[1], m[2], m[3],
                            m[4], m[5], m[6], m[7],
                            m[8], m[9], m[10], m[11],
                            m[12], m[13], m[14], m[15])
    }

    // Same as matrix(PM.trans(0, 0, z)), for the one place that's called
    // sliceCount times a frame (the depth slices below): PM.zOffset skips
    // the general matrix multiply and the throwaway translation matrix
    // that mul(drawBase, trans(0, 0, z)) would otherwise redo per slice,
    // per frame, for the whole time the phone is tilting in or out.
    function matrixZ(z) {
        const m = PM.zOffset(drawBase, z)
        return Qt.matrix4x4(m[0], m[1], m[2], m[3],
                            m[4], m[5], m[6], m[7],
                            m[8], m[9], m[10], m[11],
                            m[12], m[13], m[14], m[15])
    }

    function wallColor(s) {
        const L = wallLight, M = wallMid, D = wallDark
        const c = PM.ramp([[0.00, M.r * 255, M.g * 255, M.b * 255],
                           [0.05, L.r * 255, L.g * 255, L.b * 255],
                           [0.20, M.r * 255, M.g * 255, M.b * 255],
                           [1.00, D.r * 255, D.g * 255, D.b * 255]], s)
        return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1)
    }

    property real wallStepPx: 0.5
    property int maxWallSlices: 200
    property bool wallFine: true

    readonly property int coarseSlices: Math.max(8, Math.round(thickness / 3))

    readonly property real wallFoot: {
        const y = Math.sin(Math.abs(yaw) * Math.PI / 180)
        const p = Math.sin(Math.abs(pitch) * Math.PI / 180)
        return Math.max(0.3, Math.sqrt(y * y + p * p))
    }
    readonly property int fineSlices: Math.max(coarseSlices, Math.min(maxWallSlices,
        Math.ceil(thickness * renderScale * wallFoot / Math.max(0.1, wallStepPx))))
    property bool flat: false
    property bool plain: false
    readonly property int sliceCount: flat ? 0 : (wallFine ? fineSlices : coarseSlices)

    BorderImage {
        x: root.shadowDx
        y: root.shadowDy
        width: root.faceWidth + 2 * root.shadowFade
        height: root.faceHeight + 2 * root.shadowFade
        visible: root.shadow && !root.flat
        opacity: root.shadowColor.a
        source: "file://" + Directories.asset("images/phone-shadow.png")
        smooth: true
        cache: true
        border.left: root.shadowEdge
        border.right: root.shadowEdge
        border.top: root.shadowEdge
        border.bottom: root.shadowEdge
        transform: Matrix4x4 {
            matrix: root.matrixZ(-root.thickness).times(
                        Qt.matrix4x4(1, 0, 0, -root.shadowFade,
                                     0, 1, 0, -root.shadowFade,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1))
        }
    }

    Item {
        id: scene

        readonly property real padL: root.layerSwing.left + 8
        readonly property real padR: root.layerSwing.right + 8 + Math.max(root.buttonStick, root.powerStick)
        readonly property real padT: root.layerSwing.top + 8
        readonly property real padB: 24 + root.layerSwing.bottom

        x: -padL
        y: -padT
        width: root.width + padL + padR
        height: root.height + padT + padB

        layer.enabled: root.warm && root.superSample > 0 && !root.faceDirect
        layer.samples: root.samples
        layer.smooth: true
        layer.mipmap: !root.turnLite
        layer.textureSize: Qt.size(Math.ceil(width * root.renderScale * root.ss),
                                   Math.ceil(height * root.renderScale * root.ss))

        Item {
            id: wall

            width: scene.width
            height: scene.height

            layer.enabled: root.warm && root.wallFine && !root.faceDirect && !root.flat
            layer.smooth: true
            layer.samples: Math.min(4, root.samples)
            layer.textureSize: Qt.size(Math.ceil(scene.width * root.renderScale * root.ss),
                                       Math.ceil(scene.height * root.renderScale * root.ss))

            Item {
                x: scene.padL
                y: scene.padT
                width: root.width
                height: root.height

                Repeater {
                    model: Math.max(root.maxWallSlices, root.sliceCount)

                    delegate: Rectangle {
                        required property int index
                        readonly property bool used: index < root.sliceCount
                        readonly property real depth: (root.sliceCount - index) / Math.max(1, root.sliceCount)

                        visible: used
                        width: root.faceWidth
                        height: root.faceHeight
                        radius: root.cornerRadius
                        antialiasing: root.wallFine || depth < 0.2
                        color: used ? root.wallColor(depth) : "transparent"
                        transform: Matrix4x4 {
                            matrix: used ? root.matrixZ(-depth * root.thickness) : Qt.matrix4x4()
                        }
                    }
                }
            }
        }

        Item {
            x: scene.padL
            y: scene.padT
            width: root.width
            height: root.height

            Item {
                visible: !root.landscape && !root.faceDirect && !root.flat
                width: root.thickness
                height: root.faceHeight
                layer.enabled: root.warm && !scene.layer.enabled
                layer.samples: root.samples
                layer.smooth: true
                transform: Matrix4x4 {
                    matrix: root.matrix([0, 0, 0, root.faceWidth,
                                         0, 1, 0, 0,
                                         -1, 0, 0, 0,
                                         0, 0, 0, 1])
                }

                Rectangle {
                    x: root.thickness * 0.34
                    y: root.powerY
                    width: root.thickness * 0.24
                    height: root.powerH
                    radius: width / 2
                    color: root.wallMid
                    border.width: 2
                    border.color: root.wallDark
                    antialiasing: true
                }

                Rectangle {
                    visible: !root.plain
                    x: root.thickness * 0.24
                    y: 704
                    width: root.thickness * 0.44
                    height: 168
                    radius: width / 2
                    color: root.wallMid
                    border.width: 2
                    border.color: root.wallDark
                    antialiasing: true
                }
            }

            Repeater {
                model: !root.landscape && !root.faceDirect && !root.flat && !root.plain ? root.buttonSlices : 0

                delegate: Item {
                    id: slice

                    required property int index
                    readonly property bool face: index === root.buttonSlices - 1

                    width: root.thickness
                    height: root.faceHeight
                    transform: Matrix4x4 {
                        matrix: root.matrix([0, 0, 0, root.faceWidth + (slice.index + 1) * root.buttonStick / root.buttonSlices,
                                             0, 1, 0, 0,
                                             -1, 0, 0, 0,
                                             0, 0, 0, 1])
                    }

                    Rectangle {
                        x: root.thickness * 0.24
                        y: 704
                        width: root.thickness * 0.44
                        height: 168
                        radius: width / 2
                        color: slice.face ? root.wallLight : root.wallMid
                        border.width: slice.face ? 2 : 0
                        border.color: root.wallDark
                        antialiasing: true
                    }
                }
            }

            Repeater {
                model: !root.landscape && !root.faceDirect && !root.flat ? root.buttonSlices : 0

                delegate: Item {
                    id: pslice

                    required property int index
                    readonly property bool face: index === root.buttonSlices - 1

                    width: root.thickness
                    height: root.faceHeight
                    transform: Matrix4x4 {
                        matrix: root.matrix([0, 0, 0, root.faceWidth + (pslice.index + 1) * root.powerStickNow / root.buttonSlices,
                                             0, 1, 0, 0,
                                             -1, 0, 0, 0,
                                             0, 0, 0, 1])
                    }

                    Rectangle {
                        id: powerSlice

                        readonly property bool lit: root.powerButton && (root.powerOn || powerSliceArea.containsMouse)

                        x: root.thickness * 0.34
                        y: root.powerY
                        width: root.thickness * 0.24
                        height: root.powerH
                        radius: width / 2
                        color: !pslice.face ? root.wallMid
                               : (powerSliceArea.pressed ? Theme.accentCyan : (lit ? Theme.accentMint : root.wallLight))
                        border.width: pslice.face ? 2 : 0
                        border.color: root.wallDark
                        antialiasing: true

                        MouseArea {
                            id: powerSliceArea

                            enabled: root.powerButton && pslice.face
                            anchors.fill: parent
                            anchors.leftMargin: -18
                            anchors.rightMargin: -18
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressedChanged: {
                                root.powerHeld = pressed
                                if (pressed)
                                    powerHoldTimer.restart()
                            }
                            onClicked: root.powerClicked()
                        }
                    }
                }
            }

            Item {
                visible: !root.landscape && !root.faceDirect && !root.flat
                width: root.faceWidth
                height: root.thickness
                layer.enabled: root.warm && !scene.layer.enabled
                layer.samples: root.samples
                layer.smooth: true
                transform: Matrix4x4 {
                    matrix: root.matrix([1, 0, 0, 0,
                                         0, 0, 0, root.faceHeight,
                                         0, -1, 0, 0,
                                         0, 0, 0, 1])
                }

                readonly property real hole: root.thickness * 0.26
                readonly property real midY: root.thickness / 2

                Rectangle {
                    x: root.faceWidth / 2 - 46
                    y: parent.midY - root.thickness * 0.21
                    width: 92
                    height: root.thickness * 0.42
                    radius: height / 2
                    color: root.hardwareDark
                    antialiasing: true
                }

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        width: parent.hole
                        height: parent.hole
                        radius: width / 2
                        x: root.faceWidth / 2 + 78 + index * 30
                        y: parent.midY - height / 2
                        color: root.hardwareDark
                        antialiasing: true
                    }
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: parent.hole
                        height: parent.hole
                        radius: width / 2
                        x: root.faceWidth / 2 - 78 - parent.hole - index * 30
                        y: parent.midY - height / 2
                        color: root.hardwareDark
                        antialiasing: true
                    }
                }
            }

            Item {
                visible: root.landscape && !root.faceDirect && !root.flat
                width: root.thickness
                height: root.faceHeight
                layer.enabled: root.warm && !scene.layer.enabled
                layer.samples: root.samples
                layer.smooth: true
                transform: Matrix4x4 {
                    matrix: root.matrix([0, 0, 0, root.faceWidth,
                                         0, 1, 0, 0,
                                         -1, 0, 0, 0,
                                         0, 0, 0, 1])
                }

                readonly property real hole: root.thickness * 0.26
                readonly property real midY: root.faceHeight / 2

                Rectangle {
                    x: root.thickness / 2 - root.thickness * 0.21
                    y: parent.midY - 46
                    width: root.thickness * 0.42
                    height: 92
                    radius: width / 2
                    color: root.hardwareDark
                    antialiasing: true
                }

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        width: parent.hole
                        height: parent.hole
                        radius: width / 2
                        x: root.thickness / 2 - width / 2
                        y: parent.midY + 78 + index * 30
                        color: root.hardwareDark
                        antialiasing: true
                    }
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: parent.hole
                        height: parent.hole
                        radius: width / 2
                        x: root.thickness / 2 - width / 2
                        y: parent.midY - 78 - height - index * 30
                        color: root.hardwareDark
                        antialiasing: true
                    }
                }
            }

            Item {
                visible: root.powerButton && (root.flat || root.faceDirect) && !root.landscape
                width: root.faceWidth
                height: root.faceHeight
                transform: Matrix4x4 {
                    matrix: root.frontMatrix
                }

                Rectangle {
                    x: root.faceWidth - 4 - root.powerSlide * root.powerPress
                    y: root.powerY + 5 * (1 - root.powerPress)
                    width: root.powerStick + 4
                    height: root.powerH
                    radius: 8
                    color: root.wallDark
                    antialiasing: true
                }

                Rectangle {
                    id: powerTab

                    readonly property bool lit: root.powerOn || powerTabArea.containsMouse

                    x: root.faceWidth - 4 - root.powerSlide * root.powerPress
                    y: root.powerY + 4 * root.powerPress
                    width: root.powerStick + 4
                    height: root.powerH
                    radius: 8
                    color: powerTabArea.pressed ? Theme.accentCyan : (lit ? Theme.accentMint : root.wallLight)
                    border.width: 2
                    border.color: root.wallDark
                    antialiasing: true
                }

                // The click area stays where the button rests (it is not the button's child):
                // the button slides in under the pointer, and a press near its outer edge
                // must still end on it.
                MouseArea {
                    id: powerTabArea

                    enabled: root.powerButton
                    x: root.faceWidth
                    y: root.powerY - 6
                    width: root.powerStick + 6
                    height: root.powerH + 12
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: {
                        root.powerHeld = pressed
                        if (pressed)
                            powerHoldTimer.restart()
                    }
                    onClicked: root.powerClicked()
                }
            }

            Item {
                id: face

                width: root.faceWidth
                height: root.faceHeight
                // Normally the tilted body's 4x4. With `faceDirect` it is just the
                // plain scale and move the 4x4 comes to when everything is flat, with
                // the scale taken to a whole number of device pixels (see `directW`)
                // and the middle of the front where the owner wants it (directCenterX /
                // directCenterY, the resting screen's middle unless set). The owner
                // puts the result on a whole device pixel.
                transform: Matrix4x4 {
                    matrix: root.frontMatrix
                }

                layer.enabled: root.warm
                layer.samples: root.contentSamples
                layer.smooth: true
                // This is the plane the yaw/pitch tilt actually rotates in
                // 3D, so the GPU samples it at a steep, non-uniform angle —
                // more foreshortened toward the far edge than the near one.
                // A flat bilinear tap can't minify that correctly (it's
                // exactly the "jagged distant floor texture" problem from
                // 3D rendering); mipmap gives it a filtered chain to draw
                // from at each point on the tilted quad instead. Always on
                // here (unlike `scene` below): this texture is captured
                // flat, before the tilt is applied (see `contentSS`'s
                // comment above for why that means it isn't rebuilt every
                // frame just because the phone is moving), so there's no
                // per-frame cost tied to keeping mipmap on that `moving`
                // would actually be saving.
                //
                // Resolution/samples here come from `contentSS`/
                // `contentSamples`, not the shared `ss`/`samples` the body
                // uses -- this is the actual screen content (what the
                // cursor sits over while interacting, and what you're
                // looking at while the phone pops in or out). Neither
                // `moving` nor `busy` trims it (see the comment up at
                // `contentTrimmed`), so opening/closing the panel, dragging
                // a slider, or holding a button down never blurs it.
                //
                // Mipmap always stays on for the same reason -- always on,
                // matching `contentTrimmed` always being false.
                layer.mipmap: root.faceMipmap && !root.contentTrimmed
                layer.textureSize: root.faceDirect
                                   ? Qt.size(root.directW * root.directK, root.directH * root.directK)
                                   : Qt.size(Math.ceil(root.faceWidth * root.renderScale * root.contentSS),
                                             Math.ceil(root.faceHeight * root.renderScale * root.contentSS))

                Rectangle {
                    anchors.fill: parent
                    radius: root.cornerRadius
                    color: root.rimColor
                    antialiasing: true
                }

                Rectangle {
                    visible: !root.plain
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: root.cornerRadius - 2
                    color: "transparent"
                    border.width: 2
                    border.color: root.rimHighlight
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.rimWidth
                    radius: root.cornerRadius - root.rimWidth
                    color: root.bezelColor
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.screenInset
                    radius: root.cornerRadius - root.screenInset
                    color: root.screenColor
                    antialiasing: true
                }

                Item {
                    id: contentHost
                    anchors.fill: parent
                }

                Item {
                    visible: !root.landscape
                    x: 202
                    y: root.screenInset - root.notchLead
                    width: 249
                    height: 49 + root.notchLead
                    clip: true

                    Rectangle {
                        y: -27
                        width: parent.width
                        height: parent.height + 27
                        radius: 27
                        color: root.bezelColor
                        antialiasing: true
                    }

                    Rectangle {
                        visible: !root.plain
                        x: 24
                        y: 15 + root.notchLead
                        width: 22
                        height: 22
                        radius: 11
                        color: root.hardwareDark
                        antialiasing: true

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.phoneLens
                            antialiasing: true

                            Rectangle {
                                x: 2
                                y: 2
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Theme.phoneLensGlint
                            }
                        }
                    }
                }
                Item {
                    visible: root.landscape
                    x: root.screenInset - root.notchLead
                    y: (root.faceHeight - 249) / 2
                    width: 49 + root.notchLead
                    height: 249
                    clip: true

                    Rectangle {
                        x: -27
                        width: parent.width + 27
                        height: parent.height
                        radius: 27
                        color: root.bezelColor
                        antialiasing: true
                    }

                    Rectangle {
                        visible: !root.plain
                        x: 15 + root.notchLead
                        y: 249 - 24 - 22
                        width: 22
                        height: 22
                        radius: 11
                        color: root.hardwareDark
                        antialiasing: true

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.phoneLens
                            antialiasing: true

                            Rectangle {
                                x: 2
                                y: 2
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Theme.phoneLensGlint
                            }
                        }
                    }
                }

            }
        }
    }
}
