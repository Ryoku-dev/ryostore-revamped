# Nomarchy

Nomarchy is Ryoku's adapted port of the Omarchy quattro shell. It keeps the configurable bar, panels, menus, themes, notifications, OSD, reminders, media integrations and plugin host while routing desktop actions through Ryoku's compositor-neutral platform.

## Credits

The port tracks [Omarchy](https://github.com/basecamp/omarchy) commit `d9b970dd`, created by 37signals LLC and Omarchy contributors. The shared shell component lineage also credits the [Noctalia Shell](https://github.com/noctalia-dev/noctalia) contributors. Ryoku calls the adapted work Nomarchy to avoid implying endorsement. See `NOTICE` and `LICENSE` for the preserved attribution and terms.

## Layout

- `qml/Scene.qml` is the entry. It runs on the primary output and loads `qml/Host.qml`, the Omarchy shell host.
- `qml/nomarchy/Commons/` and `qml/nomarchy/Ui/` are the shared QML kit, exposed as the item's own modules `nomarchy.Commons` and `nomarchy.Ui` while Nomarchy is in use. Every file imports them by URI so their singletons stay shared.
- `qml/plugins/` contains the built-in Omarchy plugins and `qml/services/` hosts their APIs.
- `bin/omarchy*` provides the Omarchy-compatible command surface.
- `bin/activate`, `bin/deactivate` and `bin/palette` are the daemon lifecycle hooks.
- `data/config/`, `data/default/` and `data/themes/` hold the shipped shell config, menu and template defaults, and themes.
- `tests/` holds the lifecycle and host-seam checks.

## Paths

Omarchy's scripts and QML address their files through `OMARCHY_PATH`, which is `${XDG_DATA_HOME:-$HOME/.local/share}/ryoku/nomarchy`. `bin/activate` builds that root as links into the unpacked item:

| Under `OMARCHY_PATH` | Points to (in this folder) |
|---|---|
| `bin/` | `bin/` |
| `config/`, `default/`, `themes/` | `data/config/`, `data/default/`, `data/themes/` |
| `shell/shell.qml` | `qml/Host.qml` |
| `shell/plugins/`, `shell/services/` | `qml/plugins/`, `qml/services/` |
| `shell/Commons/`, `shell/Ui/` | `qml/nomarchy/Commons/`, `qml/nomarchy/Ui/` |

The Ryoku shell loads `qml/Scene.qml` from the unpacked item and resolves `nomarchy.*` through the store's module link `$XDG_STATE_HOME/ryoku/store/qml/nomarchy`.

Plugins written for upstream Omarchy import the kit as `qs.Commons` and `qs.Ui`. Inside Ryoku `qs` is the shell root, so `qml/services/PluginRegistry.qml` loads each third-party plugin from a staged copy under `${XDG_CACHE_HOME:-$HOME/.cache}/ryoku/nomarchy-plugins/` whose imports read `nomarchy.*`. The user's plugin folder is never changed.

## Lifecycle

The daemon supplies `RYOKU_ITEM_DIR` as the unpacked item root and `RYOKU_ITEM_ID=nomarchy`.

`bin/activate`:

1. Refuses XDG write roots outside the user's home.
2. Creates the user-owned compatibility root at `${XDG_DATA_HOME:-$HOME/.local/share}/ryoku/nomarchy`.
3. Links this item's helpers, data, QML host, plugins and kit into that compatibility root (see Paths).
4. Seeds `~/.config/omarchy/shell.json` when it does not exist.
5. Publishes the selected theme when the current theme files are missing.
6. Links every `omarchy` and `omarchy-*` command into `${XDG_BIN_HOME:-$HOME/.local/bin}` without replacing commands Ryoku does not own.

`bin/deactivate` removes only command links that point into Ryoku's Nomarchy compatibility root. User config, themes and state remain in place for the next activation. It is safe to call repeatedly.

`bin/palette <palette-json>` converts Ryoku's flat palette JSON to Omarchy's `colors.toml`, stages it at `${XDG_CACHE_HOME:-$HOME/.cache}/ryoku/nomarchy-colors.toml`, and republishes the Wallpaper (Ryoku) theme when that is the selected Nomarchy theme. A named Omarchy theme stays selected. The hook writes only below the user's home and is safe to repeat.

## Updating

Copy the Omarchy source at the new pinned revision, retain Ryoku's window-manager, service, command and XDG seams, then update the revision and adaptation list in `NOTICE`. Upstream's `shell/Commons` and `shell/Ui` go to `qml/nomarchy/`, its `config`, `default` and `themes` to `data/`, and every `qs.Commons` / `qs.Ui` import becomes `nomarchy.Commons` / `nomarchy.Ui`. Keep all `shell.services` imports qualified as `Ryoku`.
