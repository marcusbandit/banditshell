#!/usr/bin/env bash
set -u

mode=quiet
case "${1:-}" in
--command | --quiet | --polkit | --ask)
    mode="${1#--}"
    shift
    ;;
esac

aur_helper() {
    local helper
    for helper in paru yay pikaur; do
        if command -v "$helper" >/dev/null 2>&1; then
            printf '%s\n' "$helper"
            return 0
        fi
    done
    return 1
}

for want in "$@"; do
    manager="${want%%:*}"
    package="${want#*:}"
    privileged=1
    case "$manager" in
    pacman) tool=pacman command=(pacman -S --needed --noconfirm "$package") ;;
    apt) tool=apt-get command=(apt-get install -y "$package") ;;
    dnf) tool=dnf command=(dnf install -y "$package") ;;
    zypper) tool=zypper command=(zypper --non-interactive install "$package") ;;
    xbps) tool=xbps-install command=(xbps-install -y "$package") ;;
    apk) tool=apk command=(apk add "$package") ;;
    flatpak)
        tool=flatpak privileged=0
        IFS=/ read -r -a parts <<<"$package"
        case "${#parts[@]}" in
        3)
            where=--system
            [ "${parts[0]}" = user ] && where=--user
            command=(flatpak install -y --noninteractive "$where" "${parts[1]}" "${parts[2]}")
            ;;
        2) command=(flatpak install -y --noninteractive "${parts[0]}" "${parts[1]}") ;;
        *) command=(flatpak install -y --noninteractive "$package") ;;
        esac
        ;;
    aur)
        tool="$(aur_helper)" || continue
        privileged=0
        case "$tool" in
        paru) command=(paru -S --needed --noconfirm --skipreview) ;;
        yay) command=(yay -S --needed --noconfirm --answerdiff None --answerclean None --answeredit None) ;;
        pikaur) command=(pikaur -S --needed --noconfirm --noedit --nodiff) ;;
        esac
        ;;
    *) continue ;;
    esac
    command -v "$tool" >/dev/null 2>&1 || continue

    if [ "$manager" = aur ]; then
        case "$mode" in
        quiet)
            case "$tool" in
            paru | yay) command+=(--sudoflags -n) ;;
            *) exit 1 ;;
            esac
            ;;
        polkit)
            case "$tool" in
            paru | yay) command -v pkexec >/dev/null 2>&1 && command+=(--sudo pkexec) || exit 4 ;;
            *) exit 4 ;;
            esac
            ;;
        ask) command=("$tool" -S) ;;
        esac
        command+=("$package")
    fi
    base=("${command[@]}")

    if [ "$privileged" -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
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
    polkit)
        [ "$privileged" -eq 0 ] && exec "${base[@]}" </dev/null
        [ "$(id -u)" -eq 0 ] && exec "${base[@]}" </dev/null
        command -v pkexec >/dev/null 2>&1 || exit 4
        [ "$tool" = apt-get ] && base=(env DEBIAN_FRONTEND=noninteractive "${base[@]}")
        exec pkexec "${base[@]}" </dev/null
        ;;
    ask)
        echo "Press Enter to install $package, then type your password if asked."
        read -r -e -i "$(printf '%q ' "${command[@]}")" -p "$ " typed || exit 1
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
