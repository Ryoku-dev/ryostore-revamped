# Ryostore

The catalogue Ryoku 2.0 installs subshells, bar styles and official account profiles from. Every item is one folder with its source, metadata, licence, preview, tests and a generated manifest. Ryoku itself ships only the Orpheus and Kairos subshells; everything else lives here.

New here? Read [CONTRIBUTING.md](CONTRIBUTING.md), then [docs/items.md](docs/items.md).

## Map

| Path | What it is |
|---|---|
| `subshells/<id>/` | one folder per subshell: a complete shell look (bar, panels, settings) |
| `barstyles/<id>/` | one folder per bar style: a bar design |
| `profiles/<id>/` | one folder per official account profile |
| `<category>/registry.json` | generated list of the category's listed items |
| `templates/subshell/`, `templates/barstyle/`, `templates/profile/` | starters `tools/new.py` copies |
| `schema/item.schema.json`, `schema/profile.schema.json` | schemas for `item.toml` and `profile.json` |
| `tools/build.py` | validates items, writes manifests and registries; `--check` fails when stale |
| `tools/new.py` | scaffolds an item from a template |
| `tools/test.py` | runs every item's own tests |
| `tools/platform.json` | the QML modules and `shell.services` names Ryoku provides to items |
| `tests/` | tests for the tooling |
| `docs/` | [items.md](docs/items.md) (`item.toml` and folder layout), [shells.md](docs/shells.md) (writing subshells and bar styles), [profiles.md](docs/profiles.md), [paths.md](docs/paths.md), [review.md](docs/review.md) |
| `.github/workflows/check.yml` | the one CI check; item-owned workflows are named `<id>-*.yml` |

## Paths

| What | Where |
|---|---|
| Shipped subshell (Ryoku package) | `/usr/share/ryoku/config/quickshell/shell/subshells/<id>/`, materialized to `~/.config/quickshell/shell/subshells/<id>/` |
| Installed store item (packed) | `$XDG_DATA_HOME/ryoku/<category>/<id>/bundle.tar.gz` |
| Receipt | `$XDG_STATE_HOME/ryoku/store/<category>/<id>.json` |
| Unpacked while in use | `$XDG_STATE_HOME/ryoku/store/unpacked/<category>/<id>/<digest>/` (mirrors the repo item folder) |
| QML module links while in use | `$XDG_STATE_HOME/ryoku/store/qml/<module>` -> `<unpacked>/qml/<module>` |
| Shells index the shell, Hub and daemon read | `$XDG_STATE_HOME/ryoku/store/shells.json` |
| Selections | `~/.config/ryoku/shell.json` `barStyle`, `dock.design`; `~/.config/ryoku/launcher.json` `variant`; `~/.config/ryoku/widgets.json` desktop widget keys |

`$XDG_DATA_HOME` defaults to `~/.local/share`, `$XDG_STATE_HOME` to `~/.local/state`. The digest is a SHA-256 over the item id, version and every file path and hash, so a new version unpacks to a new folder. `RYOSTORE_SHIPPED_ROOT` overrides the shipped root (`${XDG_CONFIG_HOME:-~/.config}/quickshell/shell`) for tests and labs. [docs/paths.md](docs/paths.md) explains when each path exists.

## From repo folder to Loader

Take `barstyles/qsbar/` with `[shell] entry = "qml/Scene.qml"`:

1. **Repo folder.** `barstyles/qsbar/` holds `item.toml`, `qml/`, `bin/`, `data/` and the rest. `tools/build.py` lists every file in `barstyles/qsbar/manifest.json` and adds a row to `barstyles/registry.json`.
2. **Packed bundle.** `ryostore install barstyles qsbar` downloads the files the manifest lists, checks each hash, stores them as `~/.local/share/ryoku/barstyles/qsbar/bundle.tar.gz` and writes the receipt `~/.local/state/ryoku/store/barstyles/qsbar.json`. Nothing is unpacked or loaded yet.
3. **Unpacked folder.** Once `shell.json` says `"barStyle": "qsbar"` (or a selection names one of the item's contributions), `ryostore internal shells-sync` verifies the bundle and unpacks it to `~/.local/state/ryoku/store/unpacked/barstyles/qsbar/<digest>/`, the same tree as the repo folder. Each `[shell] modules` root gets a link in `~/.local/state/ryoku/store/qml/`.
4. **shells.json.** The same sync writes `~/.local/state/ryoku/store/shells.json`: every installed and shipped item, with `entry` set to `<unpacked>/qml/Scene.qml`, `inUse`, `prepared`, its contributions, and the active item's `activeOwns`.
5. **Loader.** The shell's `Shells` singleton reads `shells.json`; the bar Loader's source is the active item's `entry`. Contributions load the same way through `Shells.contributions(kind)`. Switching away restarts the shell under the reload cover and prunes the unpacked folder and links.

Shipped Orpheus and Kairos skip steps 1 to 3: their `shells.json` paths are relative to the shell config root.

## The resource rule

An installed item costs nothing unless it is the active bar style or one of its contributions is selected. It stays packed otherwise, no Ryoku file imports it, and a committed switch restarts the shell so nothing of the previous item keeps running.
