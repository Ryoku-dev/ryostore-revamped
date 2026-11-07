# Subshells and bar styles

A subshell is a complete shell look: its bar plus its own panels, quick settings and settings window. A bar style is a bar design. Both are chosen by `barStyle` in `~/.config/ryoku/shell.json` and only one is active at a time. The category folder (`subshells/` or `barstyles/`) decides which one an item is; Ryoku never keeps a list of ids. New installs and every fallback use Orpheus, which ships with Ryoku together with Kairos.

The folder layout is fixed (see [items.md](items.md#folder-layout)): everything the shell loads lives under `qml/`, scripts Ryoku runs live under `bin/`, other payload lives under `data/`.

## Scene

`[shell] entry` (normally `qml/Scene.qml`) is the Scene. With `frameHost = "each"` Ryoku creates one Scene per monitor; with `"primary"` one Scene on the primary output. The host sets `modelData` to the screen, so the root declares `required property var modelData`. A Scene that draws a bar on another edge sets `Ryoku.Shells.activeBarEdge` to `"top"`, `"bottom"`, `"left"` or `"right"` so Ryoku's own surfaces keep clear of it. Nothing in a Scene may assume a compositor; Ryoku supports Hyprland, niri and Wayfire.

## Imports

An item may import, by URI:

- Qt's own modules: every URI starting with `Qt` (`QtQuick`, `QtQml`, `Qt5Compat.GraphicalEffects`, `Qt.labs.platform`, ...);
- every URI starting with `Quickshell`;
- the Ryoku platform: `shell.services`, `shell.barkit`, `shell.modules.stage.frame`, `stage`, `Ryoku.Ui`, `Ryoku.Ui.Singletons`, `Ryoku.Blobs`, `Ryoku.PluginKit`, `Ryoku.FrameBars`;
- its own modules: a folder under `qml/<module>` for every root named in `[shell] modules` (`import inir.modules.iris.style` needs `modules = ["inir"]` and the folder `qml/inir/modules/iris/style/`);
- system modules named exactly in `[requires] qmlModules`.

The list is pinned in [`tools/platform.json`](../tools/platform.json), together with every name `shell.services` exports. That file is updated when Ryoku adds a platform module or a `shell.services` export.

Rules `tools/build.py` enforces:

- `qs` is reserved by Quickshell for the shell config root. Never `import qs` or `qs.*`, and never name a module `qs`.
- `shell.Ui` and `shell.Commons` no longer exist. Controls an item needs from Ryoku's desktop menus are item-local copies that keep their attribution (`barstyles/iris/qml/desktop/components/` is an example).
- Relative imports (`import "dir"`, `import "file.js" as X`), `.import "file.js" as X` in JavaScript and ES `import ... from "./x.mjs"` must be relative and stay inside the item folder. URLs and absolute paths are rejected.
- `import shell.services as Ryoku` is the recommended form, then `Ryoku.Shells`, `Ryoku.Theme`, `Ryoku.Screens.x()`. An unqualified `import shell.services` fails when the file uses a name that is both a local type (a `.qml` file in its own folder or in a folder it imports unqualified) and a `shell.services` export, for example a `widgets/Audio.qml` that reads `Audio.volume`. The error names the file and line.

The scan reads the import lines at the top of each `.qml` file and every line of `.js`, `.mjs` and `qmldir` files. Runtime strings such as `"file://" + path` are not checked.

`shell.services` also exports the JavaScript libraries `Screens`, `Calendar` and `WeatherFormat`.

## Surfaces an item owns

`[shell] owns` lists Ryoku surfaces the item draws itself while it is active. Ryoku turns its own version off for that time:

| Value | The item draws | Ryoku keeps off |
|---|---|---|
| `notifications` | notification banners | its notification banners |
| `notificationSound` | plays its own notification sound | its notification sound |
| `osd` | volume, brightness and similar on-screen displays | its OSD |
| `polkit` | the authentication prompt | its polkit island |
| `dock` | its own dock | its dock surfaces, dock menus and the ii dock host |
| `widgets` | its own desktop widgets | its desktop widgets and deck frost |
| `cheatsheet` | its own shortcuts sheet | its cheatsheet |
| `windowClose` | the close-window confirmation | its close keybind handling |

An item whose own settings can turn a surface off maps it in `[shell.ownsSetting]` to a dotted `shell.json` key. The ownership lapses while that key is `false` (a missing key counts as owned), so Ryoku draws the surface again:

```toml
[shell.ownsSetting]
notifications = "python.general.notifications"
```

`shells.json` carries the active item's list as `activeOwns` (`[]` while the item is pending, broken or unavailable). Compositor binds read only `activeOwns`, so no Ryoku code names an item.

With `windowClose`, the item provides IPC target `closeConfirm` with function `trigger`: it asks, or closes the focused window itself when its own setting says not to ask.

While active, an item may hand two things to Ryoku:

- `Ryoku.Shells.desktopCanvas` (owners of `widgets`), because a store item cannot create a second bottom-layer surface: an object with `ready`, `widgetOutput` (output name), `widgetCount`, `editing` and `desktopCanvasComponent` (a `Component`). The item clears it when destroyed. Ryoku's Desktop hosts that component below windows on that output while the item is active.
- `Ryoku.Notifs.itemPopupMs` (owners of `notifications`): how long its banners stay up, in milliseconds. `0` keeps Ryoku's default.

## Settings

Settings data stays in Ryoku's `Config.qml` namespaces for compatibility: `qsbar`, `python`, `inir`, `orpheus`, `kairos`. They hold data only; no Ryoku behaviour is keyed on an item id.

Inactive items are not loaded, so their IPC targets do not exist. `[shell.settings]` tells the Hub how to open the item's settings:

- `ipc`, `call` and `args`: for the active item the Hub runs `qs -c shell ipc call <ipc> <call> <args...>`. For an installed but inactive item the Hub offers to switch to it first.
- `hubEditor`: one of the built-in Hub editors `frame-rails`, `nacre` or `obi`. They edit `shell.json` data and work whether the item is active or not.

Command-line control follows the same rule. `ryoku-shell bar ...` is gone: QS Bar's settings API is its own IPC target `qsbar` (`verbs`, `catalog`, `layout`, `layoutAdd`, `layoutRemove`, `layoutMove`, `move`, `show`, `hide`, `visibility`, `set`, `position`, `form`, `defaults`, `settings`), present only while QS Bar is active, for example `qs -c shell ipc call qsbar show clock`. `ryoku-shell dock show|hide|edge|autohide|pin|unpin|list` stays: it edits Ryoku's universal dock, which is platform.

## Contributions

A contribution is a part Ryoku can use while the item is installed, even when another item is active. Selecting it puts the item in use (see the resource rule below). Its QML lives under `qml/`.

**Dock** (`[[provides.dock]]`, selected by `shell.json` `dock.design`). The entry root receives `screen`, `surfaceVisible` and `stageEditing`, and exposes `surface` (its `PanelWindow`).

**Launcher** (`[[provides.launcher]]`, selected by `launcher.json` `variant`). The entry receives no injected properties. Its root exposes readonly `bool shown` and functions `show(mon)`, `hide()`, `toggle(mon)` and `stateDump()`; `mon` is the selected monitor name and may be empty. The preview is visual only, sized `implicitWidth: 720`, `implicitHeight: 250`. It receives `settings` when it declares `property var settings`, and the Hub connects `signal editRequested(string key, var value)` when it is declared. Until the item is unpacked the Hub and launcher show the default variant.

**Desktop widgets** (`[[provides.desktopWidgets]]`). `roster` is a JSON array of records with `id`, `prefix`, `label`, `kind` and `sizes`, plus optional `icon` and `gloss`; `tools/build.py` embeds it in the manifest. Ryoku instantiates `widget` once per record. Its root declares:

| Property | Meaning |
|---|---|
| `string faceId`, `string kind`, `string prefix` | from the roster record |
| `var screen`, `real hostX`, `real hostY` | placement |
| `real scaleCfg`, `real radiusCfg` | size scale and corner radius |
| `string sizeCfg` | `<prefix>Size`, else the record's first `sizes` entry |
| `string inkColorA` | ink colour |
| `bool ryokuStyle` | `<prefix>Style` is `"ryoku"` (the default) |
| `var optionOverrides` | parsed `<prefix>Opts` |

Its `implicitWidth` and `implicitHeight` size the slot. A widget loads only while its `<prefix>Enabled` key is on and the item is unpacked. Option pages live in `options` as `<Prefix>Options.qml` (prefix with its first letter capitalised); their roots declare `property string widget` and `property var config`, and sections are `MenuSection` items with `ryoSection: true`. Widget code reads keys with `config.get(key, config.writeMonitor)` and writes them with `config.set`, `config.setMany` or `config.setLive`, never `config[key]`. Prefixes must not collide with Ryoku's own widget keys: `clock`, `calendar`, `music`, `aio`, `stats`, `weather`, `notes`, `dayprogress`, `shape`, `visualizer` and `ii*`.

## Environment

`[shell.env]` sets environment variables on the supervised shell process and on the item's lifecycle and runtime scripts while the item is active; the commit restart applies them. Ryoku expands only `$HOME`, `$XDG_DATA_HOME`, `$XDG_STATE_HOME`, `$XDG_CONFIG_HOME`, `$XDG_CACHE_HOME` (with their standard defaults) and `$RYOKU_ITEM_DIR`; any other `$` fails the build. Variables Ryoku or the session own (`PATH`, `HOME`, `USER`, `SHELL`, `LANG`, `DISPLAY`, `LC_*`, `LD_*`, `XDG_*`, `QT_*`, `QML*`, `WAYLAND_*`, `DBUS_*`, `RYOKU_*`, `MALLOC_*`) cannot be set. `shells.json` carries the table in the item record as `env`.

```toml
[shell.env]
OMARCHY_PATH = "$XDG_DATA_HOME/ryoku/nomarchy"
```

## Lifecycle and runtime

Scripts live in `bin/`, are executable, run as the user and may not escalate privileges. Ryoku sets `RYOKU_ITEM_DIR` (the unpacked item folder) and `RYOKU_ITEM_ID`.

- `[lifecycle] activate` runs when the item becomes the active `barStyle`, `deactivate` when it stops being active (the old item's `deactivate` runs before the new item's `activate`), and `palette` after Ryoku regenerated the wallpaper palette, with the palette JSON path as its first argument.
- `[runtime]` is for an item that runs as its own process. While the item is active the daemon runs `check`; on exit 0 it runs `install` once when needed, then supervises `start`, restarting it with backoff and falling back when it keeps failing.

## Translations

Wrap user-facing strings in `I18n.tr("...")` from `Ryoku.Ui.Singletons`. Strings resolve against Ryoku's shared catalogue and the user's overlay in `~/.config/ryoku/i18n/`; a string the catalogue does not know shows as written. Items do not ship catalogue files.

## The resource rule

An installed item costs nothing until it is in use: it is the active `barStyle` or one of its contributions is selected. Until then it stays packed as `bundle.tar.gz`, no Ryoku file imports it, and its modules are not on the QML import path.

When a selection changes, `ryostore internal shells-sync` unpacks the items now in use, links their modules and rewrites `shells.json`. Committing a switch restarts the shell under the reload cover, so the previous item's singletons, timers and processes are gone, and then prunes unpacked folders and module links that are no longer in use. The full path from repo folder to Loader is in the [README](../README.md#from-repo-folder-to-loader).

What breaks the rule: work started from outside the item's Scene or contributions, a second bottom-layer surface, or Ryoku code changes that name your item. Keep timers, watchers, processes and decoders inside objects the Scene or a contribution owns, so they end when it is unloaded.

## Tests

Put item tests in `tests/`: `*.test.mjs` (run with `node --test`), `test_*.py` or `*.sh`. `python3 tools/test.py <category>/<id>` runs them.
