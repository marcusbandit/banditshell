#!/usr/bin/env bash
set -u

verb="${1:-}"
id="${2:-}"
case "$verb" in
find | plan | remove | ask) ;;
*)
    echo "usage: uninstall-app.sh find|plan|remove|ask <desktop-id> | --package <how> <package>" >&2
    exit 2
    ;;
esac
[ -n "$id" ] || exit 2

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
IFS=: read -r -a data_dirs <<<"$data_home:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:$data_home/flatpak/exports/share:/var/lib/flatpak/exports/share"

candidates() {
    local dir name="$id.desktop" i
    for dir in "${data_dirs[@]}" /var/lib/snapd/desktop; do
        dir="${dir%/}"
        [ -n "$dir" ] || continue
        [ -f "$dir/applications/$name" ] && printf '%s\n' "$dir/applications/$name"
        for ((i = 0; i < ${#name}; i++)); do
            [ "${name:i:1}" = - ] && [ -f "$dir/applications/${name:0:i}/${name:i+1}" ] && printf '%s\n' "$dir/applications/${name:0:i}/${name:i+1}"
        done
    done
}

key() {
    sed -n "s/^$1=//p" "$2" | head -n 1
}

owner() {
    local file="$1" line
    if command -v pacman >/dev/null 2>&1; then
        line="$(pacman -Qqo "$file" 2>/dev/null)" && [ -n "$line" ] && printf 'pacman\t%s\n' "$line" && return 0
    fi
    if command -v dpkg-query >/dev/null 2>&1; then
        line="$(dpkg-query -S "$file" 2>/dev/null | head -n 1)" && [ -n "$line" ] && printf 'apt\t%s\n' "${line%%: *}" && return 0
    fi
    if command -v rpm >/dev/null 2>&1; then
        line="$(rpm -qf --qf '%{NAME}\n' "$file" 2>/dev/null | head -n 1)"
        if [ -n "$line" ] && [ "${line#file }" = "$line" ]; then
            if command -v dnf >/dev/null 2>&1; then
                printf 'dnf\t%s\n' "$line"
            else
                printf 'zypper\t%s\n' "$line"
            fi
            return 0
        fi
    fi
    if command -v xbps-query >/dev/null 2>&1; then
        line="$(xbps-query -o "$file" 2>/dev/null | head -n 1)" && [ -n "$line" ] && printf 'xbps\t%s\n' "$(xbps-uhelper getpkgname "${line%%: *}")" && return 0
    fi
    if command -v apk >/dev/null 2>&1; then
        line="$(apk info --who-owns "$file" 2>/dev/null | sed -n 's/.* is owned by //p' | head -n 1)"
        [ -n "$line" ] && printf 'apk\t%s\n' "$(printf '%s' "$line" | sed -E 's/-[0-9][^-]*-r[0-9]+$//')" && return 0
    fi
    return 1
}

classify() {
    local file="$1" found exec
    case "$file" in
    /nix/* | */.nix-profile/*) return 1 ;;
    */flatpak/exports/share/applications/*)
        found="$(key X-Flatpak "$file")"
        [ -n "$found" ] || found="$(basename "$file" .desktop)"
        case "$file" in
        "$HOME"/*) printf 'flatpak-user\t%s\n' "$found" ;;
        *) printf 'flatpak-system\t%s\n' "$found" ;;
        esac
        return 0
        ;;
    /var/lib/snapd/desktop/applications/*)
        found="$(key X-SnapInstanceName "$file")"
        if [ -z "$found" ]; then
            found="$(basename "$file" .desktop)"
            found="${found%%_*}"
        fi
        printf 'snap\t%s\n' "$found"
        return 0
        ;;
    esac
    owner "$file" && return 0
    exec="$(key Exec "$file")"
    found="$(printf '%s' "$exec" | sed -n 's|.*steam://rungameid/\([0-9][0-9]*\).*|\1|p')"
    if [ -n "$found" ]; then
        printf 'steam\t%s\n' "$found"
        return 0
    fi
    found="$(printf '%s' "$exec" | grep -oiE '(/[^" ]+\.appimage)' | head -n 1)"
    if [ -n "$found" ] && [ -f "$found" ]; then
        printf 'appimage\t%s\n' "$found"
        return 0
    fi
    case "$file" in
    "$HOME"/*)
        printf 'entry\t%s\n' "$(basename "$file")"
        return 0
        ;;
    esac
    return 1
}

if [ "$id" = --package ]; then
    how="${3:-}"
    package="${4:-}"
    file=""
    case "$how" in
    pacman | apt | dnf | zypper | xbps | apk | flatpak-user | flatpak-system | snap) ;;
    *) exit 2 ;;
    esac
    [[ $package =~ ^[A-Za-z0-9][A-Za-z0-9+._@:-]*$ ]] || exit 2
else
    file=""
    how=""
    package=""
    first=""
    while IFS= read -r candidate; do
        [ -n "$first" ] || first="$candidate"
        found="$(classify "$candidate")" || continue
        kind="${found%%	*}"
        [ "$kind" = entry ] && [ -n "$how" ] && continue
        if [ -z "$how" ] || [ "$how" = entry ]; then
            file="$candidate"
            how="$kind"
            package="${found#*	}"
        fi
        [ "$how" != entry ] && break
    done < <(candidates)

    if [ -z "$first" ]; then
        echo "no desktop file for $id" >&2
        exit 1
    fi
    if [ -z "$how" ]; then
        echo "$first does not come from a package this can remove" >&2
        exit 3
    fi
fi

if [ "$verb" = find ]; then
    printf '%s\t%s\t%s\n' "$how" "$package" "$file"
    exit 0
fi

others=""
case "$how" in
apt) others="$(apt-get -s remove "$package" 2>/dev/null | sed -n 's/^Remv \([^ ]*\).*/\1/p' | grep -vx -- "${package%%:*}" | tr '\n' ' ')" ;;
apk) others="$(apk info -r "$package" 2>/dev/null | sed '1d;/^$/d' | sed -E 's/-[0-9][^-]*-r[0-9]+$//' | tr '\n' ' ')" ;;
dnf | zypper) others="$(rpm -q --provides "$package" 2>/dev/null | cut -d' ' -f1 | sort -u | while IFS= read -r capability; do rpm -q --whatrequires "$capability" --qf '%{NAME}\n' 2>/dev/null; done | grep -v '^no package' | sort -u | grep -vx -- "$package" | tr '\n' ' ')" ;;
esac
if [ -n "${others// /}" ]; then
    echo "other packages need it: ${others% }"
    exit 5
fi

privileged=1
case "$how" in
pacman) command=(pacman -Rs --noconfirm -- "$package") ;;
apt) command=(env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$package") ;;
dnf) command=(dnf remove -y -- "$package") ;;
zypper) command=(zypper --non-interactive remove "$package") ;;
xbps) command=(xbps-remove -Ry -- "$package") ;;
apk) command=(apk del "$package") ;;
flatpak-user) privileged=0 command=(flatpak uninstall -y --noninteractive --user -- "$package") ;;
flatpak-system) privileged=0 command=(flatpak uninstall -y --noninteractive --system -- "$package") ;;
snap) privileged=0 command=(snap remove "$package") ;;
steam) privileged=0 command=(xdg-open "steam://uninstall/$package") ;;
appimage) privileged=0 command=(gio trash -- "$package" "$file") ;;
entry) privileged=0 command=(gio trash -- "$file") ;;
esac

if [ "$privileged" -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
    case "$verb" in
    ask)
        if command -v sudo >/dev/null 2>&1; then
            command=(sudo "${command[@]}")
        elif command -v doas >/dev/null 2>&1; then
            command=(doas "${command[@]}")
        fi
        ;;
    *)
        if ! command -v pkexec >/dev/null 2>&1; then
            [ "$verb" = plan ] || exit 4
        fi
        command=(pkexec "${command[@]}")
        ;;
    esac
fi

case "$verb" in
plan)
    printf '%s\n' "${command[*]}"
    ;;
remove)
    if [ "${command[0]}" = pkexec ]; then
        trusted=$(PATH="${BANDITSHELL_SYSTEM_PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/run/current-system/sw/bin}" command -v -- "${command[1]}") || exit 4
        command=(pkexec "$trusted" "${command[@]:2}")
    fi
    "${command[@]}" </dev/null
    status=$?
    case "$status" in
    0 | 126 | 127) exit "$status" ;;
    *) exit 10 ;;
    esac
    ;;
ask)
    echo "Press Enter to remove $package, then type your password if asked."
    read -r -e -i "$(printf '%q ' "${command[@]}")" -p "$ " typed || exit 1
    eval "$typed"
    status=$?
    echo
    if [ "$status" -eq 0 ]; then
        echo "Removed. Press Enter to close."
    else
        echo "That stopped with an error ($status). Press Enter to close."
    fi
    read -r _
    exit "$status"
    ;;
esac
