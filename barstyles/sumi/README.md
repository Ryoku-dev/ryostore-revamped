# Sumi

Sumi is Ryoku's four-edge frame rail. Each monitor gets independent top, bottom, left, and right rails with configurable zones, widgets, menus, reveal behavior, and exclusive zones.

The item uses Ryoku's `shell.barkit` platform module for frame surfaces, rails, widgets, menus, and input handling. Its settings open the Hub's built-in frame-rails editor.

## Updating

Keep `qml/Scene.qml` within the public platform imports listed in the catalogue shell contract. Changes to frame behavior belong in the shared frame kit when every rail-based item needs them; Sumi-only composition stays in this item.

## License

Sumi is licensed under GPL-3.0-or-later. See `LICENSE`.
