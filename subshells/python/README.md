# Python

Python is the Serpantinum desktop shell by ilyamiro, adapted to run as a Ryoku subshell. It keeps Serpantinum's bars, panels, guide, launcher, dock and desktop faces while Ryoku supplies compositor state, settings storage, wallpaper, capture, lock, updates and the shared system services.

The port tracks Serpantinum 2.3.1 at commit `3619689`. The copied code is AGPL-3.0-or-later; see `LICENSE` and `NOTICE`.

## Layout

- `qml/Scene.qml` is the subshell entry point; `qml/Main.qml` is the full-screen window its panels open in.
- `qml/launcher/` is the Python launcher contribution (`Main.qml`, `Preview.qml`).
- `qml/dock/Dock.qml` is the Python dock contribution; `PythonDock.qml` is the dock itself. Its behaviour options (floating, on top, exclusive, smart auto-hide, scaling, scrolling) are in the guide's Dock tab and live in `shell.json` under `dock.python`.
- `qml/desktop/` holds the desktop faces: `roster.json` lists them, `Widget.qml` is the component the desktop host creates per face, and `options/<Prefix>Options.qml` is each face's options page.
- `qml/desktop/components/` are copies of Ryoku's desktop menu controls, used by the option pages.
- `qml/assets/`, `qml/scripts/`, `qml/watchers/` and the remaining QML folders belong to the unpacked item and are resolved from its own location.

## Syncing Serpantinum

Work from a clone of https://github.com/ilyamiro/serpantinum and read revisions with `git show`. Record the new commit and release in this README and `NOTICE`.

Three-way merge each changed upstream file from `3619689` to the new revision. Map `src/quickshell/` to `qml/`, `src/scripts/` to `qml/scripts/` and `src/assets/` to `qml/assets/`. Skip upstream files listed as excluded in `NOTICE`, but port any reusable part needed by a file that remains.

Keep these Ryoku seams during the merge:

- compositor state and actions use `Wm` from `Ryoku.Ui.Singletons`;
- settings read the `python` namespace and write through the Ryoku settings socket;
- wallpaper and palette data come from Ryoku services;
- payload paths come from `Caching.payloadDir` and `Caching.assetsPath`;
- recording, updates, audio, network and other system data use Ryoku services;
- launcher, dock and desktop faces keep the contribution contracts in `item.toml`;
- wallpaper, capture, lock, idle, updates and global shell surfaces remain Ryoku-owned.

For recurring conflicts, keep Ryoku's wallpaper source in `WallpaperBlur.qml`, keep the Ryoku-backed `ThemeBackend.qml` and graft new upstream members into it, keep `guide/DockTab.qml` handing off to the Stage Editor, and take upstream's `BarModulesTab.qml` while preserving the per-card mouse ids.

After merging, replace `Caching.serpantinumDir` with `Caching.payloadDir`, route icon and text fonts through `ThemeBackend`, and remove any direct compositor API or command use. Check for `NiriState`, `MangoState`, `WindowTracker`, `Quickshell.Hyprland`, `hyprctl` and `niri msg`. New relative imports must stay inside this item; platform dependencies use the qualified modules allowed by the catalogue shell contract.
