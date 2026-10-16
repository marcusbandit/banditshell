#!/usr/bin/env bash
set -u

uid="$(id -u)"

if command -v systemctl >/dev/null 2>&1; then
    while IFS= read -r unit; do
        [ -n "$unit" ] || continue
        systemctl --user stop "$unit" 2>/dev/null && printf 'unit\t%s\n' "$unit"
    done < <(systemctl --user list-units --type=service --state=running --no-legend --plain 2>/dev/null | cut -d' ' -f1 | grep -iE 'polkit|policykit')
fi

for name in hyprpolkitagent polkit-gnome-authentication-agent-1 polkit-kde-authentication-agent-1 polkit-mate-authentication-agent-1 polkit-efl-authentication-agent-1 lxqt-policykit-agent lxpolkit xfce-polkit soteria; do
    for pid in $(pgrep -u "$uid" -x "${name:0:15}" 2>/dev/null); do
        exe="$(readlink "/proc/$pid/exe" 2>/dev/null)"
        kill "$pid" 2>/dev/null && printf 'exe\t%s\n' "${exe:-$name}"
    done
done

exit 0
