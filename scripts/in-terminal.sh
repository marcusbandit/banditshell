#!/bin/sh

script="${1:?usage: in-terminal.sh SCRIPT}"

for term in "${TERMINAL%% *}" kitty foot ghostty alacritty wezterm konsole gnome-terminal xterm; do
    [ -n "$term" ] && command -v "$term" >/dev/null 2>&1 && break
    term=
done
[ -n "$term" ] || exit 127

case ${term##*/} in
kitty | foot) exec "$term" sh -c "$script" ;;
wezterm) exec "$term" start -- sh -c "$script" ;;
gnome-terminal) exec "$term" -- sh -c "$script" ;;
*) exec "$term" -e sh -c "$script" ;;
esac
