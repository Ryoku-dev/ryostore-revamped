# Review

## What CI checks

`.github/workflows/check.yml` runs on every push and pull request:

1. `python3 tools/build.py --check`: validates every item and fails when a committed `manifest.json` or `registry.json` differs from what the build would write.
2. `python3 -m unittest discover -s tests -p 'test_*.py'`: the tooling tests.
3. `python3 tools/test.py`: every item's own tests.
4. `qmllint` on changed `.qml` files; only parser errors (`Expected token`, `Unexpected token`, `Syntax error`) fail, because items import modules the runner does not have.

`tools/build.py` checks, per item:

- `item.toml`: known fields only, types, id equals the folder, semantic version, SPDX-style licence, `https://` upstream, colours, `listed`, `downloadPaused` with its reason, `[requires]` values, `[shell]` values including `owns`, `ownsSetting` and `hubEditor`, contribution fields and unique ids;
- the fixed folder layout ([items.md](items.md#folder-layout)); entries and option folders under `qml/`, scripts under `bin/` and executable; every `[shell] modules` root has a `qmldir`;
- `preview.webp` is a 1920x1080 WebP; every referenced file exists inside the item; desktop-widget rosters are arrays of valid records;
- the import gate ([shells.md](shells.md#imports)): module imports are platform, own or declared modules, `qs` is never used, relative imports and `.js` includes stay inside the item, and an unqualified `shell.services` import does not collide with a local type;
- the security screen: no symlinks or special files, no compiled executables, no private keys or tokens, no privilege escalation in shell scripts, file count and size limits;
- profiles: `profile.json` matches `schema/profile.schema.json` and `item.toml`, needs `pacman`, `expand`, `seedOnce` and the rice exist in `home/`, no duplicate components, capabilities or environment keys, no forbidden environment keys, and `storeItems` name listed items in this catalogue.

Every message names the file and the field or line.

## What reviewers check

- One focused item with a maintainer who answers.
- A licence that allows redistribution, with upstream credit, notices and provenance kept.
- A preview that shows the submitted item.
- A clear account of processes, files, network access and external dependencies.
- Behaviour on Hyprland, niri and Wayfire, or a declared `windowManager` gate.
- Nothing runs while the item is not in use: no work outside the Scene and contributions, no second bottom-layer surface.
- Lifecycle scripts that clean up after themselves, and a `[runtime]` only when the item needs its own process.
- Tests for parsing, state and non-obvious integration points.
- A version bump and regenerated files with every update.

A green check is not a security review. Read the source together with what the pull request says it does, and turn down code nobody can understand or maintain.
