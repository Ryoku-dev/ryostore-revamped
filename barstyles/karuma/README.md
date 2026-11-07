# Karuma Ryoku bar style

Karuma is a configurable paper-and-ink bar style for Ryoku. It includes a horizontal bar and adaptive side rail, movable built-in and Ryoku plugin modules, live media, tray and status surfaces, quick settings, profiles, and a configuration hub.

## Runtime behavior

- Runs as a native Ryoku bar style through `qml/Scene.qml`; it uses Ryoku's own UI, singletons and plugin host rather than targeting a specific window manager.
- Reads the Ryoku shell configuration, the current desktop and theme tokens, connected display, workspace, window, media and system state, and installed Ryoku plugin metadata.
- Writes its bar-style settings and user-selected profiles to the Karuma and Ryoku configuration and state locations.
- Can invoke system utilities for supported controls such as networking, Bluetooth, brightness, screen recording, and keep-awake. Those actions depend on the corresponding system utility or device being available.
- Opens the project's linked GitHub pages from its settings UI. It contains no updater or separate network client.

## Packaging

`item.toml` contains the catalogue metadata. The generated `manifest.json` records the complete installed payload. The bundled fonts retain their own OFL licence texts in `qml/assets/fonts/`.

## Credits

Karuma's source comments describe its paper-and-ink layout as inspired by the original Ma layout. See the source, `PROVENANCE.txt`, and bundled font licence files for component context.
