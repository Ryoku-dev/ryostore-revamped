# Shima

Shima is Ryoku's integration of [iNiR](https://github.com/snowarch/iNiR) by snowarch and the iNiR contributors. iNiR is the upstream shell. iRiS is its island-style panel family. Shima keeps the internal `iris` ids and settings keys for compatibility while presenting the integration under Ryoku's Shima name.

The item includes the iRiS, Material ii and Waffle panel families, upstream widgets, configurable motion, glass surfaces, audio-reactive visualizers and Ryoku service bridges. Ryoku owns the shell host, desktop scene, wallpaper, capture tools and global shortcuts.

## Layout

- `qml/Scene.qml` mounts the Shima panel system.
- `qml/inir/` is the vendored iNiR module root. Its `inir.*` import URIs must not change.
- `qml/launcher/`, `qml/desktop/` and `qml/dock/` expose optional Shima parts to Ryoku's contribution hosts.
- `data/runtime/` pins the optional full upstream shell and carries its verified Ryoku patches.
- `bin/` contains the runtime hooks supervised by `ryoku-shell`.
- `tests/` checks the pinned source and item integration.

The installed item remains packed while unused. Ryoku unpacks it only while Shima or one of its contributions is selected, links `qml/inir` into the active module root, and restarts the shell after a committed switch.

## Runtime hooks

`bin/runtime-wanted` exits successfully only when `RYOKU_SHIMA_UPSTREAM=1` and a niri session is available. Otherwise Ryoku loads the integrated `qml/Scene.qml` bar style.

`bin/runtime-install` downloads the revision in `data/runtime/upstream.json`, verifies the archive and patch digests, applies both patches, verifies the assembled payload and activates a generation under `$XDG_DATA_HOME/ryoku/shima/current`. It is safe to run repeatedly. Pass `verify` or `status` for inspection, and `--archive PATH` with `install` for an offline verified archive.

`bin/runtime-start` launches the full upstream shell from the active generation. The daemon sets `RYOKU_RUNTIME_MANAGED=1` and `RYOKU_RUNTIME_READY_FILE`; Shima writes its process id to that file only after its critical and deferred panels load. The process replaces Ryoku's resident shell for that run. `bin/ryoku-shima-wallpaper` is available to the runtime through the item-local `PATH`.

The daemon supplies `RYOKU_ITEM_DIR` as the unpacked item root. `RYOKU_SHIMA_PATCH_DIR`, `RYOKU_SHIMA_RUNTIME_DIR` and `RYOKU_SHIMA_SOURCE` remain optional developer overrides.

## Resync iNiR

Work from a clone of [iNiR](https://github.com/snowarch/iNiR) and read it with `git show`; never copy its working tree. The catalogue copy is `barstyles/iris/qml/inir/`. Keep `LICENSE` and `NOTICE` unchanged and keep the pinned source details in `PROVENANCE.txt` and `data/runtime/upstream.json` synchronized.

1. Find the previous upstream base from the last Shima sync and compare it with `origin/prerelease`. `qml/inir/VERSION` is a release version, not a commit id.
2. Three-way merge each upstream file against the previous base. Rewrite both `import qs` and `import qs.*` to `import inir` and `import inir.*` before merging.
3. Preserve Ryoku seams. Use `Directories.payloadPath(...)` instead of `Quickshell.shellPath(...)`, `WorkspaceService` instead of compositor-specific services, and Ryoku's wallpaper, idle and material bridges. Do not restore IrisGate, Orbit, lock/login surfaces, Niri-only settings, setup scripts, community Hub pages, the upstream wallpaper picker, mascot assets or the `scripts/inir` CLI.
4. Keep every path derived from the item itself. `Directories.modulePath` must resolve to `qml/inir`, and child Quickshell processes must include the unpacked item's `qml` directory in `QML_IMPORT_PATH` and `QML2_IMPORT_PATH`.
5. Update every affected `qmldir`. Compare the property and function sets when upstream renames an API. Preserve internal `iris` ids and `inir.iris.*` settings keys.
6. Rebuild a changed fragment shader with Qt's `qsb`. Add only upstream-introduced defaults to `qml/inir/modules/common/IrisDefaults.js`.
7. If the optional full-shell source changed, update `data/runtime/runtime-files.txt`, both patches, every digest and count in `data/runtime/upstream.json`, then update `PROVENANCE.txt`.
8. Update `tests/test_shima_pinned_source.py` and `.github/workflows/iris-upstream-pin.yml` with the new archive revision.

All user-visible copy says Shima. The About page must credit iNiR by snowarch and separately identify the Ryoku maintainer. Do not import iNiR or iRiS names, logos, Kira, mascots or visual identity as Ryoku branding.

## Review notes

A Shima scene that falls back usually has a QML load failure. Follow the complete `Type ... unavailable` chain to its final line. Common failures are missing `qmldir` entries, missing `inir.services` imports, assignments to read-only properties and stale ids used as object properties.

Settings writes use Ryoku's daemon socket. Standalone tools and application launches resolve executables through `PATH`; do not add `/usr/bin` assumptions. Keep desktop-wide features in Ryoku rather than absorbing them into this item.

## License and credit

The vendored upstream is GPL-3.0 with the additional terms in `NOTICE`. See `PROVENANCE.txt` for the pinned revision and integration history.
