#!/bin/bash
# THE TERMINAL, BESIDE A REAL ONE, ON THE SAME SESSION.
#
# banditshell's terminal is written from scratch, so the only honest question
# about it is "does it look like a terminal", and the only honest answer is a
# real terminal showing the same bytes at the same moment. This opens the debug
# view and a kitty attached to the SAME tmux session, side by side: same
# session, same size, same output, and every difference is this emulator's.
#
# Kitty is the truth. This is the copy.
#
#   scripts/termcompare.sh            in the headless testbed, screenshot both
#   scripts/termcompare.sh --here     on this desktop, workspace 3
set -euo pipefail

DIR="${BANDITSHELL_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
STAMP=/tmp/banditshell-termdebug.session
HERE=""
[ "${1:-}" = "--here" ] && HERE=1

rm -f "$STAMP"

if [ -n "$HERE" ]; then
    # Workspace 3, silently: the point is to look at it, not to be interrupted
    # by it appearing over something else.
    hyprctl keyword windowrule "workspace 3 silent, match:title ^(banditshell-termdebug)$" >/dev/null 2>&1 || true
    ( cd "$HOME" && nohup qs -p "$DIR/termdebug.qml" >/tmp/termdebug.log 2>&1 & )
else
    "$DIR/scripts/testbed.sh" start "${BED_SIZE:-2400x900}" >/dev/null
    "$DIR/scripts/testbed.sh" run "$DIR/termdebug.qml"
fi

# WAIT FOR THE SESSION NAME rather than guessing it. The helper reports the
# session it adopted or made, and the debug view writes it here; picking the
# newest banditshell-files-* out of `tmux ls` would find the wrong one the
# moment two of these exist.
for _ in $(seq 60); do
    [ -s "$STAMP" ] && break
    sleep 0.5
done
[ -s "$STAMP" ] || { echo "no session reported; is tmux running in the pty?" >&2; exit 1; }
SESSION=$(cat "$STAMP")
echo "session: $SESSION"

# A SECOND CLIENT, AND A SESSION THAT REFUSES TO RESIZE.
#
# tmux sizes a session to its SMALLEST client, so two windows of different
# shapes do not merely look different - the larger one is shown tmux's filler
# over the area the session does not cover, which reads exactly like this
# emulator drawing dots it should not. It cost twenty minutes to work that out
# the first time.
#
# So the session is pinned to a fixed grid and both clients draw the same
# region. Whatever either has left over is filler on BOTH sides, which is
# honest and comparable.
GRID="${GRID:-100x30}"
COLS=${GRID%x*}
ROWS=${GRID#*x}

if [ -n "$HERE" ]; then
    ( nohup kitty --title banditshell-truth -e tmux attach -t "$SESSION" >/dev/null 2>&1 & )
else
    ( WAYLAND_DISPLAY=$(cat /tmp/banditshell-testbed.display) \
        nohup kitty --title banditshell-truth -e tmux attach -t "$SESSION" >/dev/null 2>&1 & )
fi

sleep 4
tmux set-option -t "$SESSION" window-size manual 2>/dev/null || true
tmux resize-window -t "$SESSION" -x "$COLS" -y "$ROWS" 2>/dev/null || true
echo "session pinned to ${COLS}x${ROWS}"

sleep 4
[ -n "$HERE" ] || "$DIR/scripts/testbed.sh" shot "${SHOT:-/tmp/termcompare.png}"
