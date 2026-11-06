# Lab status

A QS Bar plugin for the Hacker profile. It keeps the current tunnel and target visible without polling.

## What it does

- Shows the `tun0` IPv4 address, or a muted `no vpn` when the interface has no IPv4 address.
- Adds the current target IP when `$XDG_STATE_HOME/ryoku/lab/target` contains one.
- Reads the optional target name from `$XDG_STATE_HOME/ryoku/lab/target.name`.
- Copies the target on a left click. With no target, it copies the `tun0` address instead.
- Opens the detail panel on a right click. The panel has separate copy actions for the tunnel and target addresses.

The target and `target.name` files are plain text. The target file's first token must be an IPv4 address. The name file uses its first line.

## What it runs

| Command | When |
|---|---|
| `ip -4 -o addr show dev tun0` | Once when the plugin service starts. |
| `ip -4 -o monitor address` | For the life of the plugin service. Address events update the readout. |
| `wl-copy <address>` | Only after a copy action. |

The plugin uses `FileView` change notifications for both target files. It has no polling timer, makes no network requests, writes no files and runs no privileged command.

## Requirements

- `ip` from iproute2
- `wl-copy` from wl-clipboard

## Preview

`assets/preview-widget.png` is an offscreen capture of the real widget.

## License

MIT, copyright 2026 Ryoku Team. See [LICENSE](LICENSE).
