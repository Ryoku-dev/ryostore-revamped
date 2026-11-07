# Item metadata

Every item has one hand-written `item.toml`. Start it with `#:schema ../../schema/item.schema.json` so Taplo and Even Better TOML complete fields from [`schema/item.schema.json`](../schema/item.schema.json).

After any change run `python3 tools/build.py <category>/<id>`. It validates the item and writes its `manifest.json` and the category's `registry.json`; never edit either by hand. `python3 tools/build.py --check` validates every item and fails when a generated file is stale. Errors name the file and the field or line, for example `barstyles/obi/item.toml:shell.owns: ...` or `barstyles/obi/qml/Scene.qml:4: ...`.

## Folder layout

The top level of a subshell or bar style may contain only:

| Entry | Holds |
|---|---|
| `item.toml` | metadata (this page) |
| `README.md` | what it is, credits, how it is updated from upstream |
| `LICENSE`, `NOTICE`, `PROVENANCE.txt` | licence and upstream credit |
| `preview.webp` | the Store image, a real 1920x1080 WebP capture |
| `screenshots/` | extra images listed in `screenshots` |
| `qml/` | everything the shell loads; the Scene and contribution entries |
| `bin/` | scripts Ryoku runs (`[lifecycle]`, `[runtime]`) |
| `data/` | every other payload the item's scripts or QML read: configs, themes, patches, fonts |
| `tests/` | item tests |
| `manifest.json` | generated |

A profile may contain `item.toml`, `profile.json`, `README.md`, `LICENSE`, `NOTICE`, `PROVENANCE.txt`, `preview.webp`, `screenshots/`, `home/`, the generated `manifest.json`, and `assets/` only when a string in `profile.json` starts with `assets/`.

Anything else fails the build. So do symlinks, special files, compiled executables, private keys and tokens, `sudo`/`doas`/`su`/`pkexec` in shell scripts, more than 2048 files, a file over 256 MiB, or an item over 512 MiB.

## Common fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | equals the folder name; `^[a-z][a-z0-9-]{1,30}$` |
| `name` | yes | display name |
| `version` | yes | semantic version; bump it on every change |
| `summary` | yes | one line for the Store card |
| `description` | yes | text for the detail page |
| `license` | yes | SPDX id or expression |
| `authors` | yes | at least one; the registry joins them with `, ` |
| `tags` | yes | search and grouping labels (may be empty) |
| `upstream` | no | `https://` URL of the project the item came from |
| `accent`, `surface` | no | `#rrggbb` Store colours; default `#7aa2f7` and `#101010` |
| `preview` | no | default `preview.webp`; must be a 1920x1080 WebP |
| `screenshots` | no | paths under `screenshots/` |
| `official` | profiles | profiles must set `true`; shell items may set it for Ryoku-maintained items |
| `listed` | no | default `true`. `false` keeps the item in the repo while it waits for review: it is validated and gets a manifest, but is left out of `registry.json`, so the Store cannot list or install it. |
| `downloadPaused` | no | default `false`. `true` pauses downloads: the item stays visible in the Store but cannot be installed, and existing installs stay removable. |
| `downloadPauseReason` | with `downloadPaused` | non-empty text the Store shows while paused |

`[requires]` is optional:

| Field | Meaning |
|---|---|
| `packageManagers` | editions the item runs on: `pacman`, `dnf`, `xbps`; omit for every edition |
| `windowManager` | the window manager the item is written for; omit for any |
| `reason` | shown when a gate blocks |
| `qmlModules` | exact system QML module URIs imported beyond the platform list, for example `org.kde.syntaxhighlighting`; never `qs` |

## Shell fields

Subshells and bar styles require `[shell]`:

| Field | Meaning |
|---|---|
| `entry` | the Scene, under `qml/` (normally `qml/Scene.qml`) |
| `frameHost` | `each`: one Scene per monitor; `primary`: one Scene on the primary output |
| `owns` | surfaces the item draws itself while active: `notifications` (banners), `notificationSound`, `osd`, `polkit`, `dock`, `widgets`, `cheatsheet` (shortcuts sheet), `windowClose` ([shells.md](shells.md#surfaces-an-item-owns) explains each) |
| `modules` | module roots under `qml/` exposed while in use; each needs `qml/<module>/qmldir`; never `qs` |

`[shell.ownsSetting]` is optional: it maps an owned surface to a dotted `shell.json` key (`notifications = "python.general.notifications"`), and the ownership lapses while that key is `false`. Every surface in it must be in `owns`; every key matches `^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$`. The manifest carries it as `shell.ownsSetting`.

`[shell.env]` is optional: environment variables set while the item is active ([shells.md](shells.md#environment)). Keys match `^[A-Z][A-Z0-9_]*$` and may not be `PATH`, `HOME`, `USER`, `SHELL`, `LANG`, `DISPLAY` or start with `LC_`, `LD_`, `XDG_`, `QT_`, `QML`, `WAYLAND_`, `DBUS_`, `RYOKU_`, `MALLOC_`. Values are strings; the only `$` references allowed are `$HOME`, `$XDG_DATA_HOME`, `$XDG_STATE_HOME`, `$XDG_CONFIG_HOME`, `$XDG_CACHE_HOME` and `$RYOKU_ITEM_DIR` (no `${...}` form). The manifest carries it as `shell.env`, `{}` when absent.

`[shell.settings]` is optional: `ipc` and `call` (set together), `args`, and `hubEditor` (`frame-rails`, `nacre` or `obi`). See [shells.md](shells.md#settings).

Contributions are optional arrays of tables:

| Table | Fields |
|---|---|
| `[[provides.dock]]` | `id` (the `dock.design` value), `name`, `entry` |
| `[[provides.launcher]]` | `id` (the launcher `variant` value), `name`, `entry`, optional `description`, `preview` |
| `[[provides.desktopWidgets]]` | `id` (the set id), `roster` (JSON array of widget records), `widget`, optional `options` folder |

Contribution `entry`, `preview`, `widget` and `options` live under `qml/`. Contribution ids use the item id pattern and are unique per kind. Roster records need `id` (`^[A-Za-z][A-Za-z0-9_-]*$`), `prefix`, `label`, `kind` and `sizes`.

`[lifecycle]` (`activate`, `deactivate`, `palette`) and `[runtime]` (`check`, `install`, `start`) name executable scripts under `bin/`.

## Subshell example

```toml
#:schema ../../schema/item.schema.json
id = "paper-shell"
name = "Paper Shell"
version = "1.0.0"
summary = "A complete paper-inspired shell"
description = "A bar, panels and settings with a restrained paper look."
license = "GPL-3.0-or-later"
authors = ["A. Maintainer"]
tags = ["panels", "paper"]

[shell]
entry = "qml/Scene.qml"
frameHost = "each"
owns = ["notifications", "osd"]
modules = ["paper"]

[shell.settings]
ipc = "paper"
call = "settings"
args = []

[[provides.launcher]]
id = "paper-search"
name = "Paper Search"
description = "A launcher in the same look."
entry = "qml/launcher/Main.qml"
preview = "qml/launcher/Preview.qml"
```

## Bar style example

```toml
#:schema ../../schema/item.schema.json
id = "thin-line"
name = "Thin Line"
version = "1.0.0"
summary = "A compact top bar"
description = "A bar design on Ryoku's shared surfaces."
license = "MIT"
authors = ["A. Maintainer"]
tags = ["compact"]
upstream = "https://example.org/thin-line"

[requires]
qmlModules = ["org.kde.syntaxhighlighting"]

[shell]
entry = "qml/Scene.qml"
frameHost = "each"
owns = []
modules = []

[lifecycle]
palette = "bin/palette"
```

## Profile example

```toml
#:schema ../../schema/item.schema.json
id = "student"
name = "Student"
version = "1.0.0"
summary = "A focused study account"
description = "A separate account with a declared study tool set."
license = "GPL-3.0-or-later"
authors = ["Ryoku Team"]
tags = ["study"]
official = true

[requires]
packageManagers = ["pacman"]
reason = "Profiles need Arch or CachyOS."
```

Profiles cannot declare `[shell]`, `[provides]`, `[lifecycle]`, `[runtime]` or `qmlModules`. See [profiles.md](profiles.md) for `profile.json`.

## Generated output

`manifest.json` lists every file in the item except itself, with the same item-relative `source` and `destination`, `sha256`, `mode` (`0755` when executable, else `0644`), `size` and `install: true`, under destination `ryoku/<category>/<id>`. Shell manifests add a `shell` object with the `[shell]`, `[provides]`, `[lifecycle]` and `[runtime]` tables, every roster embedded as `rosterRecords`.

`<category>/registry.json` is `{"schema": 1, "<category>": [...]}` with one row per listed item, sorted by id. A row carries the Store fields above, `path` (`<category>/<id>`), `manifestSha256`, `requiresQmlModules` when set, and for shell items `provides`, the ids of its contributions by kind. JSON is written with sorted keys, two-space indent and a final newline.
