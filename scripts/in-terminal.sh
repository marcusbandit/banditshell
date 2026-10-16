#!/bin/sh

script="${1:?usage: in-terminal.sh SCRIPT}"

for term in "${TERMINAL%% *}" xdg-terminal-exec kitty foot ghostty alacritty wezterm konsole ptyxis gnome-terminal xterm; do
    [ -n "$term" ] && command -v "$term" >/dev/null 2>&1 && break
    term=
done
if [ -z "$term" ]; then
    command -v notify-send >/dev/null 2>&1 && notify-send -a banditshell "No terminal found" "Install a terminal such as foot or kitty, or set TERMINAL."
    exit 127
fi

case ${term##*/} in
xdg-terminal-exec | kitty | foot) exec "$term" sh -c "$script" ;;
ptyxis) exec "$term" -- sh -c "$script" ;;
wezterm) exec "$term" start -- sh -c "$script" ;;
gnome-terminal) exec "$term" -- sh -c "$script" ;;
*) exec "$term" -e sh -c "$script" ;;
esac
