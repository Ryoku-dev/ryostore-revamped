# Nacre

Nacre is a configurable island bar for Ryoku. Its left, centre, and right
islands host workspace, media, status, tray, weather, and system controls.

Ryoku Hub edits the island layout through the built-in Nacre editor. The scene
uses Ryoku's `Ryoku.FrameBars` Nacre configuration API and shared shell services;
it does not start a separate service or compositor integration.

The runtime entry is `qml/Scene.qml`.
