#!/usr/bin/env bash
set -u

mode=quiet
case "${1:-}" in
--command | --quiet | --polkit | --ask)
    mode="${1#--}"
    shift
    ;;
esac

name_pattern='^[A-Za-z0-9][A-Za-z0-9+._@:-]*$'

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

finish() {
    "$@" </dev/null
    local status=$?
    case "$status" in
    0 | 126 | 127) exit "$status" ;;
    *) exit 10 ;;
    esac
}

for want in "$@"; do
    manager="${want%%:*}"
    package="${want#*:}"
    privileged=1
    case "$manager" in
    flatpak)
        IFS=/ read -r -a parts <<<"$package"
        for part in "${parts[@]}"; do
            [[ $part =~ $name_pattern ]] || exit 2
        done
        ;;
    *)
        [[ $package =~ $name_pattern ]] || exit 2
        ;;
    esac
    case "$manager" in
    pacman) tool=pacman command=(pacman -S --needed --noconfirm -- "$package") ;;
    apt) tool=apt-get command=(apt-get install -y "$package") ;;
    dnf) tool=dnf command=(dnf install -y -- "$package") ;;
    zypper) tool=zypper command=(zypper --non-interactive install "$package") ;;
    xbps) tool=xbps-install command=(xbps-install -y -- "$package") ;;
    apk) tool=apk command=(apk add "$package") ;;
    flatpak)
        tool=flatpak privileged=0
        case "${#parts[@]}" in
        3)
            case "${parts[0]}" in
            user) where=--user ;;
            system) where=--system ;;
            *) exit 2 ;;
            esac
            command=(flatpak install -y --noninteractive "$where" -- "${parts[1]}" "${parts[2]}")
            ;;
        2) command=(flatpak install -y --noninteractive -- "${parts[0]}" "${parts[1]}") ;;
        *) command=(flatpak install -y --noninteractive -- "$package") ;;
        esac
        ;;
    aur)
        tool="$(aur_helper)" || continue
        privileged=0
        command=("$tool" -S "$package")
        ;;
    *) continue ;;
    esac
    command -v "$tool" >/dev/null 2>&1 || continue

    if [ "$manager" = aur ] && [ "$mode" != ask ] && [ "$mode" != command ]; then
        exit 4
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
        finish "${command[@]}"
        ;;
    polkit)
        [ "$privileged" -eq 0 ] && finish "${base[@]}"
        [ "$(id -u)" -eq 0 ] && finish "${base[@]}"
        command -v pkexec >/dev/null 2>&1 || exit 4
        [ "$tool" = apt-get ] && base=(env DEBIAN_FRONTEND=noninteractive "${base[@]}")
        finish pkexec "${base[@]}"
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
