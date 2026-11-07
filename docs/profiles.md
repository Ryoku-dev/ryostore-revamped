# Profiles

This catalogue accepts official Ryoku profiles only: every profile sets `official = true` and is maintained alongside the Ryoku release that consumes it. Community tool collections belong in the regular Ryostore.

A profile creates a separate standard account and declares what Ryoku's reviewed host engine should install and configure. It cannot carry a root script: the profile says what it needs, and the host engine plans and performs the privileged changes, so the plan is accurate, the receipt is complete and removal shows exactly what it will change.

A separate account is not a sandbox. Its menus, dock and default apps show only its own tools, but programs installed for the whole computer can still be started from its terminal, and apps it installs also appear in the other accounts. Files in other accounts stay private: each home folder is readable only by its owner.

Profiles currently run on Arch and CachyOS only, so `requires.packageManagers` must include `pacman`, in both `item.toml` and `profile.json`, with the same list.

## Files

A profile folder contains `item.toml`, `profile.json`, `README.md`, `preview.webp` (a real 1920x1080 WebP capture), optional `LICENSE`/`NOTICE`/`PROVENANCE.txt`, `screenshots/` and `home/`, and the generated `manifest.json`. It may add `assets/` only when a string in `profile.json` starts with `assets/`. The payload under `home/` mirrors the new account's home.

`id`, `name` and `version` must be equal in `item.toml` and `profile.json`.

## profile.json

`profile.json` follows [`schema/profile.schema.json`](../schema/profile.schema.json). It declares:

- the profile API and supported package managers;
- the account's suggested name, allowed permissions, groups and shell;
- repositories (only the approved BlackArch repository) and package components;
- approved file capabilities for selected tools;
- wordlist links and extraction from files below `/usr/share`;
- lab host suffixes, session environment values and PATH entries;
- launcher allowlists and the rice the account uses;
- managed home files (`expand`), files seeded once (`seedOnce`) and user-data paths kept on reset (`userData`);
- optional Store shell items to install (`storeItems`);
- one first-run command and message.

Beyond the schema, `tools/build.py` checks that:

- `expand` and `seedOnce` name files in `home/`;
- the rice exists at `home/.config/ryoku/rices/<rice>/rice.json` (the template ships `starter`);
- component names, capability tools and environment keys are unique, and every capability tool is a component's command;
- no environment key is `PATH`, `HOME`, `USER`, `XDG_RUNTIME_DIR` or starts with `LD_`;
- every `storeItems` entry names an item in this catalogue that is listed.

## Store items

`storeItems` lists subshells or bar styles the account gets:

```json
"storeItems": [
  {"category": "barstyles", "id": "qsbar"}
]
```

The plan shows them before approval; `ryoku profile lay` then installs them as the account with `ryostore install`. Installing does not activate them; the profile's rice selects the bar style.

## Build

After a change run `python3 tools/build.py profiles/<id>`. It validates the profile and rewrites `profiles/<id>/manifest.json` and `profiles/registry.json`.
