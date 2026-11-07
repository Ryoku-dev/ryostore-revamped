#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
item_dir=$(cd -- "$here/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

export HOME=$tmp/home
export XDG_DATA_HOME=$HOME/data
export XDG_STATE_HOME=$HOME/state
export XDG_CONFIG_HOME=$HOME/config
export XDG_CACHE_HOME=$HOME/cache
export XDG_BIN_HOME=$HOME/bin
export XDG_RUNTIME_DIR=$tmp/run
export RYOKU_ITEM_DIR=$item_dir
export RYOKU_ITEM_ID=nomarchy
mkdir -p "$XDG_STATE_HOME/omarchy/current/theme"
printf 'accent = "#ffffff"\n' >"$XDG_STATE_HOME/omarchy/current/theme/colors.toml"
printf '[bar]\n' >"$XDG_STATE_HOME/omarchy/current/theme/shell.toml"

"$item_dir/bin/activate"
"$item_dir/bin/activate" --check
[[ -L $XDG_DATA_HOME/ryoku/nomarchy/shell/shell.qml ]]
[[ $(readlink -- "$XDG_DATA_HOME/ryoku/nomarchy/config") == "$item_dir/data/config" ]]
[[ $(readlink -- "$XDG_DATA_HOME/ryoku/nomarchy/shell/Commons") == "$item_dir/qml/nomarchy/Commons" ]]
[[ -f $XDG_DATA_HOME/ryoku/nomarchy/default/omarchy/omarchy-menu.jsonc ]]
[[ -f $XDG_CONFIG_HOME/omarchy/shell.json ]]
[[ -L $XDG_BIN_HOME/omarchy-theme-set ]]

cat >"$tmp/palette.json" <<'JSON'
{
  "primary": "#112233",
  "error": "#ff0000",
  "surface": "#101010",
  "onSurface": "#f0f0f0",
  "outline": "#808080"
}
JSON
printf 'named-theme\n' >"$XDG_CONFIG_HOME/omarchy/current-theme"
"$item_dir/bin/palette" "$tmp/palette.json"
grep -qx 'accent = "#112233"' "$XDG_CACHE_HOME/ryoku/nomarchy-colors.toml"

"$item_dir/bin/deactivate"
"$item_dir/bin/deactivate" --check
[[ ! -e $XDG_BIN_HOME/omarchy-theme-set ]]

printf 'nomarchy-lifecycle: all checks passed\n'