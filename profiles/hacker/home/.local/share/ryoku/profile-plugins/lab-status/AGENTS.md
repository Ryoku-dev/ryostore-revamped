# Agent guide for the lab-status plugin

This folder is a Ryoku shell plugin. Follow the rules below when editing it.

## Rules

- Keep one folder named after the plugin id.
- Keep `manifest.json`, `service/Main.qml`, `content/Widget.qml`, `content/Panel.qml`, `README.md`, `LICENSE` and a real `assets/preview-widget.png` capture.
- Use only QtQuick, Quickshell, Ryoku.PluginKit and files inside this plugin.
- Keep logic in `service/Main.qml` and presentation in `content/`.
- List every external command in `dependencies.commands`.
- Do not use privilege escalation, network access or shell command strings.
- Do not write outside `pluginApi.stateDir`, the plugin cache or a temporary directory.
- Keep credentials and compiled binaries out of the tree.
- Keep the README accurate about commands and file access.

The host sets `pluginApi`, `s`, `active`, `density` and `widthBudget`. Read those values and do not assign them. The bar panel is controlled through `pluginApi.togglePanel()`.
