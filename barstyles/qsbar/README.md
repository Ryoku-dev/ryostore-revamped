# QS Bar

QS Bar is Ryoku's port of [Quickshell Rise](https://github.com/HANCORE-linux/quickshell-dots) by HANCORE-linux. It keeps the upstream bar forms, widgets, panels, settings window, and draggable layout while using Ryoku's compositor-neutral services, palette, shell settings, and plugin host.

The item loads only while `barStyle` is `qsbar`. Its entry point is `qml/Scene.qml`; `frameHost = "primary"` makes Ryoku host it once, on the primary output, and the scene creates one bar per output.

It is also the bar that hosts `topbarGlyph` plugins (`qml/BarPlugins.qml` finds them, `qml/BarSlot.qml` draws them), which is why the Hacker profile installs it.

## Where things are

| Path | What it is |
|---|---|
| `qml/Scene.qml` | Entry point Ryoku loads. |
| `qml/VariantRoot.qml` | One bar per output, panels, the settings window. |
| `qml/Theme.qml` | Live settings, layout, and every write to `shell.json`. |
| `qml/core/widgets.json` | Built-in widget catalogue: ids, visibility keys, settings rows. |
| `qml/core/SettingsIpc.qml` | The `qsbar` IPC target. |
| `qml/core/SettingsRules.js` | Layout placement and value checks the IPC target uses. |
| `qml/core/IpcRouter.qml` | Runtime IPC targets (`theme`, `picker`, `layout`, `reactor`, `lifecycle`, `ryoku.system-update`). |
| `qml/controlcenter/` | QS Bar Settings window. |
| `tests/size-probe.sh` | Offscreen size probe for the bar scale; skipped without `qs` and a Ryoku checkout. |

## Settings

Open the settings window through the item IPC target:

```sh
qs -c shell ipc call qsbar settings ""
```

Pass `close` to close it, or a route such as `bars`, `identity`, `layout`, `widgets`, `dock`, or `community` to open that page. The Hub uses the same call (`[shell.settings]` in `item.toml`).

QS Bar reads its namespace from `shell.json` through `shell.services.Config`. Every write goes through the daemon's `settings.patch` call; bar plugin placement goes through `ryoku-plugins-place`. The item never writes `shell.json` directly. Volume boost is shared platform policy at `audio.boost`; `audioBoost` remains the widget setting name. The 12-hour clock setting writes the shared `general.clock_format_24_h`.

The bar reports its live `top` or `bottom` edge through `Shells.activeBarEdge`, so Ryoku's dock can take the other edge.

With `qsbar.isolateMonitors` on (Settings > Identity > Isolate, or `qs -c shell ipc call qsbar set workspaces isolateMonitors true`), each bar shows only the workspaces on its own output, resolves a click to that output's workspace by id, and dims its active marker to 72% while another output holds focus; the workspace popup filters the same way. `qml/modules/WorkspaceIsolation.js` holds the rules and `tests/WorkspaceIsolation.test.mjs` covers them.

## IPC

The `qsbar` target exists only while QS Bar is the active bar style. All calls use `qs -c shell ipc call qsbar <function> [arguments...]`, and every argument must be passed (use `""` for an empty one). Writes return `ok` or `err qsbar: <reason>`; a write made before the bar has loaded its settings returns `err qsbar: settings not ready`. Reads return JSON.

| Former `ryoku-shell bar` verb | QS Bar IPC call | Arguments and result |
|---|---|---|
| `list [--json]` | `list` | Every placeable widget in bar order: `[{id,label,kind,section,index,shown}]`. Bar plugins that are installed but off keep their slot and show `shown: false`. |
| `catalog [--json]` | `catalog` | Built-in widgets from `qml/core/widgets.json` plus installed `topbarGlyph` plugins, with their settings rows. |
| `move <id> --section <s> [--index n \| --before id \| --after id]` | `move <id> <left\|center\|right> <placement>` | Placement is `""` to append, a 0-based index (clamped), `before:<id>`, or `after:<id>`. |
| `show <id>` | `show <id>` | Shows a built-in widget, or enables a bar plugin on the bar. |
| `hide <id>` | `hide <id>` | Hides a built-in widget, or disables a bar plugin. |
| `set <id> <key> <value>` | `set <id> <key> <value>` | Checks the value against the widget's settings row in `widgets.json` (choice, toggle, multi as comma list, int, text) or the plugin's manifest setting (toggle, choice, slider, int, free text), then writes it. |
| `position <top\|bottom>` | `position <top\|bottom>` | Sets the bar edge. |
| `form <form>` | `form <full\|fit\|dock\|notch\|islands>` | Sets the bar form. |
| `defaults` | `defaults` | Restores the shipped layout and widget visibility. |
| `settings [route]` | `settings <route>` | `""` opens the default page, a route opens that page, `close` closes the window. |

`launcher`, `workspaces`, and `clock` have no visibility key, so `show`, `hide`, and `visibility` refuse them.

Layout helpers:

- `layout` returns the live `{version,left,center,right}` document.
- `layoutMove <id> <section> <placement>` is `move`.
- `layoutAdd <id> <section> <placement>` shows or enables a widget, then places it.
- `layoutRemove <id>` is `hide`.
- `visibility <id> <on|off>` is `show` or `hide` from a boolean.

`ryoku-shell dock ...` is not part of this item: it edits Ryoku's own dock and stays in Ryoku.

Examples:

```sh
qs -c shell ipc call qsbar move cpu left after:status
qs -c shell ipc call qsbar set volume audioBoost on
qs -c shell ipc call qsbar set ai aiTools claude,codex
qs -c shell ipc call qsbar position bottom
qs -c shell ipc call qsbar form islands
qs -c shell ipc call qsbar defaults
```

## Updating the port

The runtime under `qml/` came from Ryoku's maintained Quickshell Rise port. Update it from the pinned Ryoku source tree, preserve the MIT license, and keep platform integrations behind the documented `shell.services`, `Ryoku.Ui`, `Ryoku.Ui.Singletons`, `Ryoku.PluginKit`, and stage-frame contracts. Relative imports must stay inside this item.

## License

Quickshell Rise is copyright 2026 HANCORE-linux and released under the MIT License. Ryoku's modifications keep that license in `LICENSE`.
