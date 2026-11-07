# Imi 2

A full-desktop Material 3 shell for the Ryoku desktop shell. Version 2
brings the whole ii shell family: the bar with its widget set and edit
mode, the dynamic island, both sidebars, on-screen display, notification
banners, the session screen and the vertical bar.

Ryoku provides the platform. Most compositor state goes through the host's
Wm facade, colors come from the shell's
matugen palette, and audio, network, battery, brightness, weather,
notifications, media and the rest are the shell's own services - the
barstyle keeps no private copies of them.

## Configuration

Settings live in `~/.config/ryoku/barstyle-imi/config.json`, mirroring
the option categories (bar, appearance, sidebar, osd, and so
on). The bar's own edit mode (double-click the bar) covers widget
layout; the settings window covers the rest.

## Structure

```
imi/
├── item.toml               # Catalogue metadata and shell contract
├── qml/Scene.qml           # Entry point, loaded once per monitor
├── qml/GlobalStates.qml    # Cross-surface UI state bus
├── qml/modules/common/     # Config, Appearance, widget kit, functions
├── qml/modules/ii/         # Bar, dynamic island, sidebars, OSD, session screen
├── qml/services/           # Host-service adapters and services
└── preview.webp            # Store preview
```

## Dependencies

- Ryoku Desktop Shell (Quickshell-based)
- Hyprland. Keyboard layouts, several popups, workspaces and the settings
  pages call `hyprctl` and `Quickshell.Hyprland` directly, so `item.toml`
  declares `windowManager = "hyprland"` and the Store offers Imi only there.
- KDE syntax-highlighting QML module (`org.kde.syntaxhighlighting`) for code blocks in the AI chat sidebar

## Known gaps

These were already missing in the old store copy; the code still asks for them and
falls back to nothing.

- Config pages `BarScrollActionsConfig.qml`, `BarTooltipsConfig.qml`,
  `BarPopupsConfig.qml`, `PerfMonitorConfig.qml` and `DockWorkspaceConfig.qml`
  under `qml/modules/settings/configs/widgets/`.
- Quick-toggle images `pixel_buds.png`, `pixel_headphone_2_complete.png`,
  `pixel_headphone_2_front.png` and `pixel_3d.png` under `qml/assets/images/devices/`.
- The font `qml/assets/fonts/LED Dot-Matrix.ttf` used by the expressive media card.

## License

GPL-3.0 - see PROVENANCE.txt for attribution. Community-maintained by
dodo986.
