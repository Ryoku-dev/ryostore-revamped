# Review

## What CI checks

`.github/workflows/check.yml` runs on every push and pull request:

1. `python3 tools/build.py --check`: validates every item and fails when a committed `manifest.json` or `registry.json` differs from what the build would write, or when a listed item's resource measurement is missing or stale ([items.md](items.md#resource-measurements)).
2. `python3 -m unittest discover -s tests -p 'test_*.py'`: the tooling tests.
3. `python3 tools/test.py`: every item's own tests.
4. `qmllint` on changed `.qml` files; only parser errors (`Expected token`, `Unexpected token`, `Syntax error`) fail, because items import modules the runner does not have.

`tools/build.py` checks, per item:

- `item.toml`: known fields only, types, id equals the folder, semantic version, SPDX-style licence, `https://` upstream, colours, `listed`, `downloadPaused` with its reason, `[requires]` values, `[shell]` values including `owns`, `ownsSetting` and `hubEditor`, contribution fields and unique ids;
- the fixed folder layout ([items.md](items.md#folder-layout)); entries and option folders under `qml/`, scripts under `bin/` and executable; every `[shell] modules` root has a `qmldir`;
- `preview.webp` is a 1920x1080 WebP; every referenced file exists inside the item; desktop-widget rosters are arrays of valid records;
- the import gate ([shells.md](shells.md#imports)): module imports are platform, own or declared modules, `qs` is never used, relative imports and `.js` includes stay inside the item, and an unqualified `shell.services` import does not collide with a local type;
- the security screen: no symlinks or special files, no compiled executables, no private keys or tokens, no privilege escalation in shell scripts, file count and size limits;
- profiles: `profile.json` matches `schema/profile.schema.json` and `item.toml`, needs `pacman`, `expand`, `seedOnce` and the rice exist in `home/`, no duplicate components, capabilities or environment keys, no forbidden environment keys, and `storeItems` name listed items in this catalogue;
- the behaviour checks below, for subshells and bar styles;
- `measurements/<id>.json`: a valid record whose tier matches its delta, measured for the item's current version, with no leftover processes; required for every listed item whose downloads are not paused, and no record without an item.

Every message names the file and the field or line.

## Behaviour checks

`tools/build.py` reads every QML, JavaScript and script file under `qml/` and `bin/` (comments ignored) and fails on:

- **A direct compositor call** without the matching `requires.windowManager`: `hyprctl`, `import Quickshell.Hyprland`, `HYPRLAND_INSTANCE_SIGNATURE` or the Hyprland sockets (`hyprland`); `niri msg` or `NIRI_SOCKET` (`niri`); `WAYFIRE_SOCKET`, `wf-msg` or Wayfire IPC (`wayfire`); `swaymsg`, `SWAYSOCK`, `I3SOCK` or `import Quickshell.I3` (`sway`). One finding per file and compositor.
- **An ungated repeating Timer**: `repeat: true` with `running: true`, or with an interval of 1000 ms or less (Qt's default when unset) whose `running` binding names nothing about visibility or activity (an identifier containing visible, hidden, open, shown, active, hover, playing, focus, pressed, drag, loading, busy, pending, running, count, length, want, pop and similar).
- **A self-restarting Process**: its `onExited`, `onRunningChanged` or `onFinished` starts it again (`running = true`, `<id>.running = true`, `<id>.exec(...)`), directly or through a Timer whose trigger starts it, with no condition except its exit status. A restart behind a pending-work, wanted or retry-count condition passes.

Use the Wm facade instead of a compositor, gate the Timer on what makes it needed, or bound the restart. When the code is right as it is (a call that checks the running compositor first, a clock the bar always shows), add an entry with a reviewed reason to `tools/behaviour-allowlist.json`:

```json
{"item": "subshells/gokko", "check": "compositor", "file": "qml/upstream/MacBar.qml", "key": "hyprland", "reason": "Every hyprctl call checks macWm.provider first."}
```

`check` is `compositor`, `timer` or `process`; `key` is the compositor, or the object's `id` (`Timer@<n>` / `Process@<n>` for the n-th one without an id in that file), exactly as the build message prints it. An entry that matches nothing fails the build, so the list stays current.

## Measuring items

A maintainer measures in the Hyperion lab after any version bump, from a host shell:

```sh
/dev/shm/hyperion/lab/bin/lab-install-hyperion
sudo -n /dev/shm/hyperion/lab/bin/lab-user tester -- python3 /srv/ryostore-revamped/tools/measure.py --install \
  --ryoku "$(git -C /home/nero/Work/hyperion describe --always --dirty)" --out /mnt/hyperion-lab-captures/measurements
cp /dev/shm/hyperion/lab/captures/measurements/*.json measurements/
python3 tools/build.py && python3 tools/build.py --check
```

The lab copies this catalogue to `/srv/ryostore-revamped` and runs the real desktop (`lab-desktop --real tester`) in nested niri. `--install` installs or updates every listed, downloadable item first; name item ids to measure only those. One item takes about three minutes (`--settle 90 --window 60 --linger 10`). The script refuses to run outside a container unless given `--allow-host`, and restores the bar style that was active.

An item whose `requires.windowManager` names one compositor is measured in a session of that compositor, against Orpheus in the same session: the Store does not install it anywhere else, so a niri session would keep measuring an older version. In the Hyperion lab, `/mnt/hyperion-lab-captures/bench/hyprmeasure.sh "<ryoku describe>" <id>...` (run with `lab-shell tester`) starts a Hyprland with a headless output on a wlroots host inside the container, runs the desktop on it and calls `measure.py` with the given ids; the records land in `measurements-hypr/`.

PSS readings move by up to about 15 MB between identical runs, so an item measured near a tier boundary (30 or 80 MB) can change tier from one run to the next without changing.

## What reviewers check

- One focused item with a maintainer who answers.
- A licence that allows redistribution, with upstream credit, notices and provenance kept.
- A preview that shows the submitted item.
- A clear account of processes, files, network access and external dependencies.
- Behaviour on Hyprland, niri and Wayfire, or a declared `windowManager` gate; every allowlist entry's reason checked against the code.
- Nothing runs while the item is not in use: no work outside the Scene and contributions, no second bottom-layer surface.
- Lifecycle scripts that clean up after themselves, and a `[runtime]` only when the item needs its own process.
- Tests for parsing, state and non-obvious integration points.
- A version bump and regenerated files with every update.

A green check is not a security review. Read the source together with what the pull request says it does, and turn down code nobody can understand or maintain.
