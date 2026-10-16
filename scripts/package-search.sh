#!/usr/bin/env bash
set -u

verb="${1:-}"
term="${2:-}"

usage() {
    echo "usage: package-search.sh tools | system <term> | aur <term> | flatpak" >&2
    exit 2
}

has() {
    command -v "$1" >/dev/null 2>&1
}

literal_words() {
    local word
    read -r -a words <<<"$1"
    for word in "${words[@]}"; do
        printf '%s\n' "$word" | sed 's/[][\.*^$+?(){}|]/\\&/g'
    done
}

case "$verb" in
tools)
    for tool in pacman apt-cache dnf zypper xbps-query apk flatpak paru yay pikaur pkexec; do
        has "$tool" && printf '%s\n' "$tool"
    done
    exit 0
    ;;
system)
    [ -n "$term" ] || usage
    mapfile -t patterns < <(literal_words "$term")
    [ "${#patterns[@]}" -gt 0 ] || usage
    if has pacman; then
        echo "@@ pacman"
        pacman -Ss -- "${patterns[@]}" 2>/dev/null | head -n 1200
    elif has apt-cache; then
        found="$(apt-cache search --names-only -- "${patterns[@]}" 2>/dev/null | head -n 600)"
        echo "@@ apt"
        printf '%s\n' "$found"
        mapfile -t names < <(printf '%s\n' "$found" | cut -d' ' -f1 | sed '/^$/d' | head -n 20)
        if [ "${#names[@]}" -gt 0 ]; then
            echo "@@ apt-policy"
            apt-cache policy -- "${names[@]}" 2>/dev/null
        fi
    elif has dnf; then
        found="$(dnf -q -C search -- "$term" 2>/dev/null | head -n 200)"
        [ -n "$found" ] || found="$(dnf -q search -- "$term" 2>/dev/null | head -n 200)"
        echo "@@ dnf"
        printf '%s\n' "$found"
        mapfile -t names < <(printf '%s\n' "$found" | sed -n 's/^[[:space:]]*\([^[:space:]:]*\)\.[a-z0-9_]*[[:space:]]*[:	].*/\1/p' | head -n 40)
        if [ "${#names[@]}" -gt 0 ]; then
            echo "@@ rpm"
            rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' -- "${names[@]}" 2>/dev/null | grep -v ' is not installed$'
        fi
    elif has zypper; then
        echo "@@ zypper"
        zypper --non-interactive --no-refresh search -- "$term" 2>/dev/null
    elif has xbps-query; then
        echo "@@ xbps"
        xbps-query -Rs "$term" 2>/dev/null
    elif has apk; then
        echo "@@ apk"
        apk search -v -- "$term" 2>/dev/null
        echo "@@ apk-installed"
        apk info 2>/dev/null
    else
        exit 3
    fi
    exit 0
    ;;
aur)
    [ -n "$term" ] || usage
    has pacman || exit 3
    has curl || exit 3
    echo "@@ foreign"
    pacman -Qm 2>/dev/null
    echo "@@ aur"
    curl -fsSG --max-time 8 --data-urlencode "arg=$term" -d v=5 -d type=search -d by=name-desc https://aur.archlinux.org/rpc/ || exit 1
    echo
    ;;
flatpak)
    has flatpak || exit 3
    flatpak list --app --columns=application,version 2>/dev/null
    ;;
*)
    usage
    ;;
esac
