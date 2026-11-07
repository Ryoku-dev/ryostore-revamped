# Paths and loading

The canonical source-to-machine table is in the root [README](../README.md#paths). This page explains when those paths exist and which paths item code may keep.

## Installed shell items

Installing a subshell or bar style writes a verified `bundle.tar.gz` below `$XDG_DATA_HOME/ryoku/<category>/<id>/` and a receipt below `$XDG_STATE_HOME/ryoku/store/<category>/`. Installation does not unpack or activate the item.

`ryostore` computes the in-use set from the bar style, dock, launcher, and desktop-widget selections. It unpacks only that set below `$XDG_STATE_HOME/ryoku/store/unpacked/`, creates QML module links below `$XDG_STATE_HOME/ryoku/store/qml/`, and writes `shells.json` atomically. The digest directory changes when an item version, file path, or file hash changes.

The shell reads entries only from `shells.json`. Shipped Orpheus and Kairos use paths relative to the shell configuration root; Store entries use verified absolute paths below the unpacked directory. Item metadata and QML must use item-relative paths so both source review and unpacking remain safe.

After a selection is committed, Ryoku restarts the shell before pruning the old unpacked directory and module links. Item scripts receive `RYOKU_ITEM_DIR` instead of guessing a data or state path.

## Profiles

Profile payloads install below the Store product destination and are consumed by the profile planner. Files below `home/` describe the target account's home; they are not paths into the contributor's machine and must never contain absolute home-directory references.

## Test override

`RYOSTORE_SHIPPED_ROOT` replaces the normal shipped shell root for tests and isolated labs. It does not change Store data, state, receipts, or user selections.
