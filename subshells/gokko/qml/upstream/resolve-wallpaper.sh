#!/bin/sh
# Resolve a renderable still for a Ryoku wallpaper; never execute project content.
set -eu
source_path=${1:-}
video_poster=${2:-}

[ -n "$source_path" ] || exit 0

is_image() {
    case "$1" in
        *.[pP][nN][gG]|*.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[wW][eE][bB][pP]|*.[aA][vV][iI][fF]|*.[bB][mM][pP])
            [ -f "$1" ] ;;
        *) return 1 ;;
    esac
}

if is_image "$source_path"; then
    printf '%s\n' "$source_path"
    exit 0
fi

case "$source_path" in
    *.[mM][pP]4|*.[wW][eE][bB][mM]|*.[mM][kK][vV]|*.[mM][oO][vV])
        if [ -f "$video_poster" ]; then
            printf '%s\n' "$video_poster"
        else
            printf 'MacShell: video poster unavailable: %s\n' "$source_path" >&2
        fi
        exit 0 ;;
esac

if [ -d "$source_path" ]; then
    for candidate in \
        preview.jpg preview.png preview.webp preview.jpeg \
        wallpaper.jpg wallpaper.png wallpaper.webp \
        thumbnail.jpg thumbnail.png \
        assets/preview.jpg assets/preview.png assets/preview.webp \
        assets/wallpaper.jpg assets/wallpaper.png; do
        if is_image "$source_path/$candidate"; then
            printf '%s\n' "$source_path/$candidate"
            exit 0
        fi
    done
    candidate=$(find "$source_path" -maxdepth 2 -type f \
        \( -iname 'preview.jpg' -o -iname 'preview.png' -o \
           -iname 'preview.webp' -o -iname 'thumbnail.jpg' -o \
           -iname 'wallpaper.jpg' -o -iname 'wallpaper.png' \) \
        -print -quit 2>/dev/null || true)
    if [ -n "$candidate" ] && is_image "$candidate"; then
        printf '%s\n' "$candidate"
        exit 0
    fi
    printf 'MacShell: no usable preview image in wallpaper project: %s\n' "$source_path" >&2
else
    printf 'MacShell: unsupported or missing wallpaper source: %s\n' "$source_path" >&2
fi
exit 0
