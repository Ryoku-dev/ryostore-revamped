# Contributing

One pull request adds or updates one item. Python 3.11 or newer is all the tooling needs.

## Add or update an item in five steps

1. **Start from a template.** `python3 tools/new.py <subshell|barstyle|profile> <id>` copies `templates/<kind>/` to `<category>/<id>/` and fills in the id and name. To update an existing item, work in its folder and bump `version` in `item.toml`.
2. **Write it.** Edit `item.toml` ([docs/items.md](docs/items.md)) and the code: `qml/` for what the shell loads, `bin/` for scripts Ryoku runs, `data/` for anything else, `tests/` for tests. A profile edits `profile.json` and `home/` ([docs/profiles.md](docs/profiles.md)). Keep upstream `LICENSE`, `NOTICE` and `PROVENANCE.txt`, and say in `README.md` where the code came from and how it is updated. [docs/shells.md](docs/shells.md) lists what a subshell or bar style may import and how Ryoku hosts it.
3. **Capture the preview.** Replace `preview.webp` with a real 1920x1080 WebP capture of the item running on Ryoku.
4. **Build and test.** `python3 tools/build.py <category>/<id>` validates the item and regenerates its `manifest.json` and the category `registry.json`; fix every message it prints. Then `python3 tools/test.py <category>/<id>` runs the item's tests. CI runs `python3 tools/build.py --check`, so commit the generated files. The check also wants a current resource measurement (`measurements/<id>.json`) for every listed item; the build prints `warning: ... missing measurement` or `... older than its version` until a maintainer measures the new version in the lab ([docs/review.md](docs/review.md#measuring-items)) and commits the record. Calling a compositor directly, a repeating Timer that runs while nothing needs it, or a Process that restarts itself fails the build ([docs/review.md](docs/review.md#behaviour-checks)).
5. **Open a pull request.** Say what the item runs, which files it reads and writes, what it contacts on the network, which compositors you tried, and who maintains it.

## After it lands

You maintain what you submit: answer reports, bump the version with every change, and say so in an issue if you stop maintaining it. An item that is not ready yet can stay in the repo with `listed = false`; an item with a known problem can pause downloads with `downloadPaused = true` and a `downloadPauseReason`.

[docs/review.md](docs/review.md) lists what CI checks and what reviewers look for.
