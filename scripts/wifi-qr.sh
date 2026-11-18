#!/bin/sh
set -u
file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/banditshell-wifi-qr-XXXXXX") || exit 3
trap 'rm -f "$file"' EXIT
case "${1:-}" in
screen)
    sleep 0.4
    if [ -n "${2:-}" ]; then
        grim -o "$2" "$file" || exit 3
    else
        grim "$file" || exit 3
    fi
    ;;
clipboard)
    kind=$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/')
    if [ -z "$kind" ]; then
        wl-paste --no-newline 2>/dev/null | head -c 4096
        exit 0
    fi
    wl-paste --type "$kind" >"$file" 2>/dev/null || exit 3
    ;;
*)
    exit 2
    ;;
esac
command -v ZXingReader >/dev/null || exit 4
ZXingReader -json -formats QRCode "$file"
