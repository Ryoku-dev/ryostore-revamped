# Authoring profiles

This catalogue accepts official Ryoku profiles only. Every registry row must set
`official` to `true`, and the definition must be maintained with the Ryoku release
that consumes it. Community tool collections belong in the regular Ryostore.

Profiles are currently available only on Arch and CachyOS. Both use `pacman`, so a
registry row and its `profile.json` requirements must name that package manager.

## What a profile declares

A profile may declare:

- one separate standard account and its allowed permissions, groups and shell;
- packages from the host repositories and the approved BlackArch repository;
- approved file capabilities for selected tools;
- wordlist links and extraction from files below `/usr/share`;
- lab host suffixes, session environment values and PATH entries;
- launcher allowlists and the rice used by the account;
- managed home files, files seeded once and user-data directories kept on reset;
- one first-run command and message.

The payload under `home/` mirrors the new account's home. `expand` and `seedOnce`
must name files in that payload. The selected rice must have
`home/.config/ryoku/rices/<rice>/rice.json`. The Store preview is
`assets/preview.webp` and must be a 1920x1080 WebP image.

A profile cannot carry a root script. The profile says what it needs, while the
reviewed Ryoku host engine plans and performs privileged changes. This keeps the
plan accurate, makes receipts complete and lets removal show exactly what it will
change.

A profile is a separate account, not a sandbox. Its menus, dock and default apps
show only its own tools, but programs installed for the whole computer can still
be started from its terminal. Apps it installs also appear in the other accounts
on this computer. Files in other accounts stay private: each home folder is
readable only by its owner.

## Pack and validate

After changing a profile, rebuild its manifest and registry hash from the repo
root:

```sh
python3 tools/pack-profile.py <id>
```

Use `--all` to rebuild every registered profile. The packer includes
`profile.json`, `home/**` and `assets/**`, rejects symlinks, and records each file's
size, mode and SHA-256 digest.

Run both checks before submitting a change:

```sh
python3 tests/validate-profiles.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

The validator checks the registry, file manifest, profile schema, allowlists,
payload references and preview dimensions. Fix the definition or payload instead
of weakening a failed rule.
