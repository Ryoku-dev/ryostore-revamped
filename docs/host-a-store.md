# Host a store

Anyone can host a store that Ryoku users add next to the official ones. A store is a folder of static files on any HTTPS host. It is laid out like this repository and uses the same registry and manifest format, with one index file on top. Ryostore reads it, checks every hash, and installs from it the same way it installs from the official stores.

Users add a store in **Ryostore › Sources › Add a source**, or with `ryostore sources add <address>`. Before anything is saved, Ryostore reads the index and every registry it lists. A store that fails any check is refused.

## Layout

```
<base>/
├── ryostore.json                       the store index
├── plugins/
│   ├── registry.json                   generated list of the category's items
│   └── hello-tile/                     one folder per item, named after its id
│       ├── product-manifest.json       generated: every file with its sha256
│       ├── manifest.json               the plugin's own manifest
│       ├── service/Main.qml
│       ├── content/Widget.qml
│       ├── assets/preview-widget.png
│       └── README.md
└── barstyles/
    ├── registry.json
    └── <id>/ ...
```

`<base>` is the address users add, for example `https://example.github.io/my-store` or `https://raw.githubusercontent.com/you/my-store/main`. Every path below is relative to it.

## The index

`ryostore.json` names the store and the categories it serves:

```json
{
  "schema": 1,
  "name": "Example store",
  "description": "One plugin, to show how a store is laid out.",
  "homepage": "https://example.com/my-store",
  "categories": ["plugins"]
}
```

| Field | Required | Rules |
|---|---|---|
| `schema` | yes | `1` |
| `name` | yes | 1 to 48 characters, no control characters, no leading or trailing spaces. Users can rename the store when they add it. |
| `description` | no | up to 280 characters |
| `homepage` | no | an `https://` address |
| `categories` | yes | at least one, each listed once, all from the table below |

Any other field fails the check. Ryostore turns the name into the store's id (`Example store` becomes `example-store`). The id names the store in receipts and install folders.

## Categories a store can serve

| Category | What it is | How to build it |
|---|---|---|
| `subshells` | complete shell looks | `tools/build.py` in a fork of this repository |
| `barstyles` | bar designs | `tools/build.py` in a fork of this repository |
| `docks`, `launchers`, `osds`, `notifications`, `sidebars` | shell QML folders | the script below, or `tools/pack-product.py` in a fork of [ryoku-dev/ryostore](https://github.com/ryoku-dev/ryostore) |
| `plugins` | desktop tiles, frame popouts and bar marks | the script below, or `tools/pack-product.py` |

Each of these categories installs only through the hashed manifest: Ryostore downloads each listed file, checks its size and sha256, and installs it as a whole or not at all. Each one also runs from Ryostore's own index, so a second store's copy can live in its own folder.

Only the official stores may serve the other categories, and a store that lists one is refused:

- `profiles` and `bundles`: they change accounts, packages and system settings.
- `rices`, `colorschemes`, `nautilus`, installers and live wallpapers: they install without a per-file hash manifest.
- `lockscreens`, `fastfetch`, `ryotunes-skins`, `vesktop-themes`, `decors`, `launcher-images` and `fastfetch-emblems`: they are applied from a folder that is shared with other apps, outside the store's own folders.

## Registries and manifests

`<category>/registry.json` holds every listed item of the category:

```json
{ "schema": 1, "<category>": [ { ...entry... } ] }
```

Only `schema` and the one category key are allowed. Entries follow the official format exactly. Ryostore rejects unknown fields, duplicate ids, a `path` that is not `<category>/<id>`, and absolute or `..` paths.

| Entry field | Required | Rules |
|---|---|---|
| `id` | yes | `^[a-z0-9]+(-[a-z0-9]+)*$`, equals the folder name |
| `name`, `version`, `author`, `summary`, `description` | yes | non-empty |
| `path` | yes | `<category>/<id>` |
| `tags`, `screenshots` | yes | arrays (may be empty); screenshots are paths inside the item |
| `preview` | yes | a path inside the item, never a URL |
| `accent`, `surface` | yes, except shell items | `#rrggbb` |
| `manifest` | yes | `product-manifest.json` for plugins, `manifest.json` for the others |
| `manifestSha256` | yes | sha256 of the manifest file, lowercase hex |
| `upstream` | yes | the `https://` home of the item |
| `hosts`, `icon`, `tagline`, `lastUpdated`, `discord` | no | as in the official plugin registry |
| `windowManager`, `packageManagers` | no | limit the item to a compositor or to editions; add a `...Reason` |
| `downloadPaused`, `downloadPauseReason` | no | keep an item listed while new installs are paused |

`official` is accepted but ignored. Only the source decides whether an item is official, and an item from a store a user added never is.

The manifest lists every file of the item:

```json
{
  "schema": 1,
  "id": "hello-tile",
  "category": "plugins",
  "version": "1.0.0",
  "destination": "ryoku/plugins/hello-tile",
  "files": [
    { "source": "content/Widget.qml", "destination": "content/Widget.qml",
      "sha256": "…", "mode": "0644", "size": 2245, "install": true }
  ]
}
```

- `destination` is always `ryoku/<category>/<id>`. Ryostore installs a user store's copy into its own folder, `~/.local/share/ryoku/sources/<store-id>/<category>/<id>/`.
- `mode` is `0644`, or `0755` for a script with a shebang. Files with `install: false` (the preview, screenshots, a plugin's README and LICENSE) are listed but never downloaded.
- At most 2048 files, 256 MiB per file and 512 MiB per item. No symlinks, no `.ryostore-` names.
- `id`, `category` and `version` must match the registry entry. A changed file needs a new manifest, a new `manifestSha256`, and a new `version` so installed copies update.

### Subshells and bar styles: tools/build.py

Fork this repository and delete the items you do not ship, together with their `measurements/<id>.json` and their entries in `tools/behaviour-allowlist.json`, because the build refuses a measurement or an allowlist entry for an item that is gone. Then add your own folders as [items.md](items.md) and [shells.md](shells.md) describe, and run:

```sh
python3 tools/build.py              # validates every item, writes manifest.json and registry.json
python3 tools/build.py --check      # fails when a generated file is stale or a measurement is missing
```

A plain build prints missing resource measurements as warnings and still writes the registry, so a store does not need `tools/measure.py`. Without a measurement the item gets no resource tier in Ryostore. `--check` treats a missing measurement as an error, so use it only if you measure. Add `ryostore.json` at the root with `"categories": ["subshells", "barstyles"]` (or one of them). The build also writes an empty `profiles/registry.json`. Leave `profiles` out of the index, because a user store cannot serve it.

### Plugins and the other QML categories: the script

Save this as `tools/hash-store.py` in your store. It writes each item's manifest from the files in its folder, then each entry's `manifestSha256`, for every category in `ryostore.json` except `subshells` and `barstyles`, which `tools/build.py` writes. Run it after every change: `python3 tools/hash-store.py`.

```python
#!/usr/bin/env python3
import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
docs = {"README.md", "LICENSE", "COPYING", "NOTICE", "AUTHORS"}


def manifest(category, entry):
    folder = root / entry["path"]
    held_back = {entry["preview"], *entry["screenshots"]}
    files = []
    for path in sorted(folder.rglob("*")):
        relative = path.relative_to(folder).as_posix()
        if path.is_symlink():
            sys.exit(f"{entry['path']}/{relative}: symlinks are not allowed")
        if not path.is_file() or relative == entry["manifest"] or relative.startswith("."):
            continue
        data = path.read_bytes()
        script = os.access(path, os.X_OK) and data.startswith(b"#!")
        files.append({
            "source": relative,
            "destination": relative,
            "sha256": hashlib.sha256(data).hexdigest(),
            "mode": "0755" if script else "0644",
            "size": len(data),
            "install": relative not in held_back and not (category == "plugins" and relative in docs),
        })
    return {"schema": 1, "id": entry["id"], "category": category, "version": entry["version"],
            "destination": f"ryoku/{category}/{entry['id']}", "files": files}


index = json.loads((root / "ryostore.json").read_text())
for category in index["categories"]:
    if category in ("subshells", "barstyles"):
        continue
    registry_path = root / category / "registry.json"
    registry = json.loads(registry_path.read_text())
    for entry in registry[category]:
        raw = (json.dumps(manifest(category, entry), indent=2) + "\n").encode()
        (root / entry["path"] / entry["manifest"]).write_bytes(raw)
        entry["manifestSha256"] = hashlib.sha256(raw).hexdigest()
    registry_path.write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n")
```

## A minimal store

This is a whole store with one plugin, built from the [plugin template](https://github.com/ryoku-dev/ryostore/tree/main/plugins/template). See the template and [AUTHORING.md](https://github.com/ryoku-dev/ryostore/blob/main/plugins/AUTHORING.md) for the plugin side.

1. Copy the template's `service/`, `content/` and `assets/` into `plugins/hello-tile/`, and write its `manifest.json` (the plugin's own manifest: its `id` must equal the folder name):

   ```json
   {
     "id": "hello-tile",
     "name": "Hello tile",
     "version": "1.0.0",
     "author": "Your Name <you@example.com>",
     "description": "A desktop tile with a greeting and a counter.",
     "license": "MIT",
     "tags": ["example", "desktop-widget"],
     "official": false,
     "entryPoints": { "main": "service/Main.qml", "content": "content/Widget.qml" },
     "files": ["assets/preview-widget.png"],
     "capabilities": { "densities": ["compact"] },
     "hosts": ["desktopWidget"],
     "defaults": { "host": "desktopWidget", "desktopWidget": { "bg": "card" }, "icon": "extension", "label": "Hello tile" }
   }
   ```

2. Write `ryostore.json` as in [The index](#the-index), and `plugins/registry.json` with an empty hash:

   ```json
   {
     "schema": 1,
     "plugins": [
       {
         "id": "hello-tile",
         "name": "Hello tile",
         "version": "1.0.0",
         "path": "plugins/hello-tile",
         "author": "Your Name",
         "summary": "A desktop tile with a greeting and a counter.",
         "description": "A desktop tile with a greeting and a counter. It runs no commands and reads nothing.",
         "tags": ["desktop-widget"],
         "hosts": ["desktopWidget"],
         "accent": "#c96b3c",
         "surface": "#101010",
         "preview": "assets/preview-widget.png",
         "screenshots": ["assets/preview-widget.png"],
         "upstream": "https://example.com/hello-tile",
         "manifest": "product-manifest.json",
         "manifestSha256": ""
       }
     ]
   }
   ```

3. Run `python3 tools/hash-store.py`. It writes `plugins/hello-tile/product-manifest.json` and fills in `manifestSha256`.

4. Try it on your own machine before you publish:

   ```sh
   python3 -m http.server --bind 127.0.0.1 8765 --directory .
   ryostore sources add http://127.0.0.1:8765
   ryostore install plugins hello-tile --source example-store
   ```

   `ryostore sources add file:///path/to/store` works too. Plain `http://` is accepted only on 127.0.0.1 and localhost. Everywhere else the address must be `https://`. Remove the test source with `ryostore sources remove example-store`.

## Hosting

Any static host that serves files over HTTPS works: GitHub Pages, `raw.githubusercontent.com`, a CDN, or your own server. Ryostore fetches each file with a plain GET (it adds a cache-busting query), follows no login, and reads at most 4 MiB for an index, registry or manifest. Keep the address stable: users add it once, and a new address is a new store to them.

Publish an update by bumping the item's `version` and rebuilding. Ryostore shows **Update** for every user whose installed version differs from the listed one.

## Trust and what users see

Ryoku reviews the official stores and nothing else. A store you host runs code on your users' machines: plugins and shell items are QML that run inside their shell with their permissions, and scripts in `bin/` run as them. Ryostore says so wherever your store shows up:

- **Adding a store.** The Sources view asks for confirmation and says that Ryoku does not review the store and that its items run with the user's permissions.
- **Every item.** Each item from your store carries a badge with your store's name, and its page shows this warning: *From \<your store\>, a store you added. Ryoku does not review it: it runs inside your shell with your permissions, so only install it if you trust the store.*
- **Never official.** An `official` field in your registry is ignored.

What Ryostore checks, and what it does not:

- It checks the index, every registry and every manifest strictly, and the size and sha256 of every downloaded file. A file that does not match its manifest is never installed. This proves the files are the ones your store lists. It does not prove they are safe.
- It installs your items into your store's own folders (`~/.local/share/ryoku/sources/<store-id>/`, `~/.local/state/ryoku/store/sources/<store-id>/`), so no store can overwrite another store's install or an official one.
- One copy of a `<category>/<id>` is installed at a time, because the shell knows an item by its id. If an official item or another store's item with the same id is installed, Ryostore refuses to install yours until the user removes the other one. Pick ids that are unlikely to clash, for example with your store's name as a prefix.
- A store can be turned off or removed at any time. Its installed items keep working but get no more updates, and they stay listed so they can be removed.

Things a reviewer of the official stores would catch are your job: no `sudo`, no downloaded code, no secrets, network hosts declared, and a README that says what the item runs, reads and writes. [review.md](review.md) and [AUTHORING.md](https://github.com/ryoku-dev/ryostore/blob/main/plugins/AUTHORING.md#rules) list those rules.
