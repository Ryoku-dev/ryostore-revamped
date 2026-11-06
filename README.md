# Ryostore Revamped

This is the revamped content catalogue for Ryoku 2.0 Hyperion. It starts with
installable profiles and is read only on Ryoku's unstable channel.

A profile is a separate account, not a sandbox. Ryostore downloads its definition
without privileges, then Ryoku Hub shows the complete activation plan before asking
for administrator approval.

## Layout

- `profiles/registry.json` lists the profiles the Store can show.
- `profiles/<id>/profile.json` declares the account, packages and user setup.
- `profiles/<id>/home/` holds files laid into the profile account's home.
- `profiles/<id>/assets/` holds the 1920x1080 WebP preview and screenshots.
- `profiles/<id>/manifest.json` records every downloadable file and digest.
- `schema/profile.schema.json` is the profile format.
- `tools/pack-profile.py` regenerates manifests and registry hashes.
- `tests/validate-profiles.py` checks the complete catalogue.

## Commands

Pack one profile after changing its definition or payload:

```sh
python3 tools/pack-profile.py hacker
```

Pack every registered profile:

```sh
python3 tools/pack-profile.py --all
```

Validate the catalogue and its tests:

```sh
python3 tests/validate-profiles.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

See [AUTHORING.md](AUTHORING.md) before changing a profile.
