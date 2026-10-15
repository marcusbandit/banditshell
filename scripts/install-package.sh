#!/usr/bin/env bash
set -u

mode=quiet
case "${1:-}" in
--command | --quiet | --ask)
    mode="${1#--}"
    shift
    ;;
esac

for want in "$@"; do
    manager="${want%%:*}"
    package="${want#*:}"
    case "$manager" in
    pacman) tool=pacman command=(pacman -S --needed --noconfirm "$package") ;;
    apt) tool=apt-get command=(apt-get install -y "$package") ;;
    dnf) tool=dnf command=(dnf install -y "$package") ;;
    zypper) tool=zypper command=(zypper --non-interactive install "$package") ;;
    xbps) tool=xbps-install command=(xbps-install -y "$package") ;;
    apk) tool=apk command=(apk add "$package") ;;
    *) continue ;;
    esac
    command -v "$tool" >/dev/null 2>&1 || continue

    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            command=(sudo "${command[@]}")
        elif command -v doas >/dev/null 2>&1; then
            command=(doas "${command[@]}")
        fi
    fi

    case "$mode" in
    command)
        echo "${command[*]}"
        exit 0
        ;;
    quiet)
        [ "${command[0]}" = sudo ] && command=(sudo -n "${command[@]:1}")
        [ "${command[0]}" = doas ] && command=(doas -n "${command[@]:1}")
        exec "${command[@]}" </dev/null
        ;;
    ask)
        echo "Press Enter to install $package, then type your password if asked."
        read -r -e -i "${command[*]}" -p "$ " typed || exit 1
        eval "$typed"
        status=$?
        echo
        if [ "$status" -eq 0 ]; then
            echo "Installed. Press Enter to close."
        else
            echo "That stopped with an error ($status). Press Enter to close."
        fi
        read -r _
        exit "$status"
        ;;
    esac
done

echo "no package manager found for: $*" >&2
exit 3
