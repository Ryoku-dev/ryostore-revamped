#!/bin/sh

# The file side of Settings > Keys (services/KeybindService.qml). Everything about
# what to write is worked out in modules/tansu/settings/KeyBinds.js; this only puts
# its block in the right file and hands its calls to hyprctl.
#
#   keybinds.sh check            mode=lua|conf  linked=yes|no  file=<override file>
#   keybinds.sh read             print the override file (KeyBinds.readState finds the state in it)
#   keybinds.sh write <block>    replace our block in the override file with <block> ("" removes it)
#   keybinds.sh call <call>...   run each call as `hyprctl <fields>`; a call's fields are
#                                separated by the ASCII unit separator (\037)
#   keybinds.sh reload           hyprctl reload (a reset needs it: the user's config brings
#                                back its own binds, which can't be re-created from here)
#
# Both config formats are supported:
#   Lua            ~/.config/hypr/tansu_overrides.lua, the file the Hyprland page writes
#                  too, which hyprland.lua loads with `pcall(require, "tansu_overrides")`.
#                  Its other lines (the Hyprland page's, "-- tansu:hypr:..") are left alone.
#   hyprland.conf  ~/.config/hypr/tansu_overrides.conf, which the config has to `source`.
# Our lines are only ever the ones between "tansu:keys:begin" and "tansu:keys:end".

dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
lua_cfg="$dir/hyprland.lua"
conf_cfg="$dir/hyprland.conf"
BEGIN='tansu:keys:begin'
END='tansu:keys:end'

if [ -f "$lua_cfg" ]; then
    mode=lua
    file="$dir/tansu_overrides.lua"
else
    mode=conf
    file="$dir/tansu_overrides.conf"
fi

# Does hyprland.conf, or a file it sources (and so on, a few levels down), source our
# file? `source = ~/x.conf`, `$HOME/x.conf`, relative paths and globs are all followed.
conf_links() {
    depth="$2"
    [ "$depth" -gt 5 ] && return 1
    [ -f "$1" ] || return 1
    base=$(dirname "$1")
    sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*//p' "$1" | sed 's/[[:space:]]*#.*$//' |
    while IFS= read -r src; do
        case "$src" in
            "~/"*) src="$HOME/${src#\~/}" ;;
            '$HOME/'*) src="$HOME/${src#\$HOME/}" ;;
            /*) ;;
            *) src="$base/$src" ;;
        esac
        for f in $src; do
            case "$f" in
                */tansu_overrides.conf) echo yes; exit 0 ;;
            esac
            [ "$(conf_links "$f" $((depth + 1)))" = yes ] && { echo yes; exit 0; }
        done
    done
}

case "$1" in
    check)
        if [ "$mode" = lua ]; then
            grep -q 'tansu_overrides' "$lua_cfg" && linked=yes || linked=no
        else
            [ "$(conf_links "$conf_cfg" 0)" = yes ] && linked=yes || linked=no
            # hyprland.conf calls a `source` of a missing file an error, and the
            # file only gets written on the first change.
            [ -e "$file" ] || { mkdir -p "$dir" && : > "$file"; }
        fi
        printf 'mode=%s\nlinked=%s\nfile=%s\n' "$mode" "$linked" "$file"
        ;;
    read)
        [ -f "$file" ] && cat "$file"
        ;;
    write)
        block="$2"
        mkdir -p "$dir" || exit 1
        [ -e "$file" ] || : > "$file"
        tmp=$(mktemp "$dir/.tansu_keys.XXXXXX") || exit 1
        # Everything outside our markers, with the new block where the old one was
        # (or at the end if there was none).
        BLOCK="$block" awk -v b="$BEGIN" -v e="$END" '
            index($0, b) { skip = 1; if (!done) { printf "%s", ENVIRON["BLOCK"]; done = 1 } ; next }
            skip && index($0, e) { skip = 0; next }
            !skip { print }
            END { if (!done) printf "%s", ENVIRON["BLOCK"] }
        ' "$file" > "$tmp" || { rm -f "$tmp"; exit 1; }
        chmod 644 "$tmp"
        mv -f "$tmp" "$file" || { rm -f "$tmp"; exit 1; }
        ;;
    call)
        shift
        command -v hyprctl >/dev/null 2>&1 || exit 0
        us=$(printf '\037')
        status=0
        for c in "$@"; do
            old_ifs="$IFS"; IFS="$us"
            set -f
            # shellcheck disable=SC2086
            set -- $c
            set +f
            IFS="$old_ifs"
            out=$(hyprctl "$@" 2>&1)
            case "$out" in
                ok*|"") ;;
                *) printf 'hyprctl %s: %s\n' "$*" "$out" >&2; status=1 ;;
            esac
        done
        exit $status
        ;;
    reload)
        command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1
        ;;
    *)
        echo "usage: $0 check | read | write <block> | call <call>... | reload" >&2
        exit 2
        ;;
esac
exit 0
