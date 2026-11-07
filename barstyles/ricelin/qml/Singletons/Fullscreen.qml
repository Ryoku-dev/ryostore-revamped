pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

/**
 * Runtime fullscreen state shared by the Ricelin scene.
 *
 * Hide the bar for the focused window rather than for any fullscreen window on
 * the output. Native and windowed fullscreen are reported by the Wayland
 * toplevel state; borderless fullscreen is recognized by its output-sized
 * geometry. The reserve surface is separate and remains mapped at all times.
 */
Singleton {
    id: root

    function activeWindowIsFullscreen(name) {
        const win = Wm.focusedWindow;

        // During startup/focus handoff there may briefly be no foreign-toplevel
        // handle yet. Preserve the native fullscreen fallback for that interval.
        if (!win)
            return Wm.focusedOutput === name && Wm.outputHasFullscreen(name);

        const output = String(win.output || Wm.focusedOutput || "");
        if (output !== name)
            return false;

        // This covers compositor fullscreen and Niri's windowed-fullscreen mode.
        const toplevel = win.toplevel;
        if (toplevel && toplevel.fullscreen === true)
            return true;

        // Older/partial toplevel providers may omit the handle while the daemon
        // still knows the active workspace's fullscreen state.
        if (!toplevel && Wm.outputHasFullscreen(name))
            return true;

        // Borderless games often remain ordinary Wayland windows. Detect only
        // the focused window whose geometry matches the output, not maximized
        // windows that leave the bar's reserved top strip available.
        let screen = null;
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name === name) {
                screen = screens[i];
                break;
            }
        }
        if (!screen)
            return false;

        const sw = Number(screen.width) || 0;
        const sh = Number(screen.height) || 0;
        const ww = Number(win.width) || 0;
        const wh = Number(win.height) || 0;
        if (sw <= 0 || sh <= 0 || ww <= 0 || wh <= 0)
            return false;

        const widthTolerance = Math.max(4, sw * 0.02);
        const heightTolerance = Math.max(4, sh * 0.02);
        return Math.abs(ww - sw) <= widthTolerance
            && Math.abs(wh - sh) <= heightTolerance;
    }
}
