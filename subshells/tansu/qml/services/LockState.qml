pragma Singleton
import QtQuick
import Quickshell
import "."

Singleton {
    id: root

    property bool locked: false

    property string phase: "idle"

    property date lockedAt: new Date()

    // True for exactly as long as the compositor's session lock is engaged (phase "locked"):
    // from then on nothing but the lock surface is drawn, so whatever the rest of the shell
    // is doing is invisible and can be stopped. It turns true when the lock ring has finished
    // and false the moment the password is accepted (phase "unlocking"), so everything that
    // listens to it is already coming back while the unlock ring opens up the desktop.
    // Never true during "locking" (the desktop is still on screen under the ring) or
    // "unlocking". Settings -> General -> Launcher & lock -> "Sleep the desktop while locked"
    // (`lock.sleepDesktop`) turns it off: this then stays false and nothing is stopped.
    readonly property bool desktopAsleep: root.phase === "locked" && SettingsService.flag("lock.sleepDesktop")

    // Which transition locking and unlocking play: the wallpaper switcher's
    // style (Settings -> Desktop -> Wallpaper), so the lock feels like a
    // wallpaper change. To pin one, replace the binding of `wantedStyle`
    // with a style name ("tansuRing", "star", "diagonalBlocks", "tansuIris",
    // "tansuFlash" or "fade"). If that style's lock shader could not be loaded
    // (its .qsb was never built), LockRing.qml sets styleFallback and the
    // lock plays the ring instead, which always has a shader.
    readonly property string wantedStyle: WallpaperService.transitionStyle
    readonly property string transitionStyle: root.styleFallback ? "tansuRing" : root.wantedStyle
    property bool styleFallback: false
    onWantedStyleChanged: root.styleFallback = false

    readonly property int ringMs: WallpaperService.transitionMsFor(root.transitionStyle)

    property bool relockPending: false

    function lock() {
        if (root.phase === "unlocking") {
            root.relockPending = true
            return
        }
        if (root.phase !== "idle")
            return
        root.lockedAt = new Date()
        WallpaperService.rollLockStyle()
        root.phase = "locking"
    }

    function engage() {
        if (root.phase !== "locking")
            return
        root.locked = true
        root.phase = "locked"
    }

    function beginUnlock() {
        if (root.phase !== "locked")
            return
        root.locked = false
        WallpaperService.rollLockStyle()
        root.phase = "unlocking"
    }

    function finishUnlock() {
        if (root.phase !== "unlocking")
            return
        root.phase = "idle"
        if (root.relockPending) {
            root.relockPending = false
            root.lock()
        }
    }
}
