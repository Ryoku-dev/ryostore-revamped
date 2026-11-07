# Sukunabikona

Sukunabikona is an adaptive bar style for Ryoku. It has two states that
share one visual language:

- an empty or floating-only workspace expands into a full left command rail;
- the first tiled window collapses that rail into a three-pill top bar.

The full rail carries workspaces, media controls, the playback spectrum, live
system telemetry, machine identity, Ryoku shortcuts, pinned app roles, and
session controls. The compact state keeps Ryoku/workspaces on the left,
window-or-media context plus the spectrum in the centre, and volume/time on the
right.

Colours and typography come from Ryoku's live `Theme`, so wallpaper-driven
Matugen changes repaint the surface without a second theme engine.

## Runtime contract

This style runs inside the Ryoku shell and uses only its public data plane:

- `Wm` for windows, workspaces, focus and fullscreen state;
- `Media` and `AudioBars` for MPRIS playback and the shared CAVA feed;
- `Audio` for output volume and mute;
- `Sysinfo` and `StatsFeed` for CPU, memory, GPU and disk telemetry;
- `Network`, `Session`, `ShellState` and `Theme` for the remaining shell state.

It does not import a compositor-specific QML module, open a compositor socket,
or invoke a compositor command-line interface.

## Local reads and commands

The style makes read-only local probes for labels:

- `/proc/cpuinfo`
- `/etc/os-release`
- `/proc/sys/kernel/osrelease`
- `lspci -mm` for the display-controller label

Commands are launched only after an explicit click and use Ryoku's own stable
entry points:

- `ryoku-shell hub open <section>`
- `ryoku-shell launcher`, `ryoku-shell quicksettings`, `ryoku-shell lock`
- `ryoku-app terminal|files|browser`
- `ryogami wallpaper ui`

The style itself performs no network requests and writes no configuration.

## Scaling

The approved rail layout is native at 1440p and scales down on shorter outputs.
The compact top bar remains full-resolution and reserves only its own top band.

## Licence and maintenance

Copyright (C) 2026 aethctl.

Licensed under GPL-3.0-only. This is a community Ryostore contribution maintained
by `aethctl`, not by the Ryoku team.
