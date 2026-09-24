#!/bin/bash
# A COMPOSITOR TO TEST IN, so testing never touches the session being used.
#
# Every verification this project does is visual: open the window, drive it,
# screenshot it, look. Done on the running desktop that means windows appearing
# over whatever the user is doing, a pointer being moved out from under their
# hand, and synthetic keystrokes landing in whichever application happened to
# have focus. All three have happened.
#
# So the shell under test runs in a headless sway on its own WAYLAND_DISPLAY.
# grim screenshots THAT display rather than a monitor, wtype types into it, and
# swaymsg moves its pointer - none of which the real session can see. It is also
# strictly better testing: a fixed resolution, no other windows, and no chance
# of screenshotting a stale instance from an earlier run.
#
#   scripts/testbed.sh start [WxH]     bring the bed up
#   scripts/testbed.sh run <qml> [env] run a config inside it
#   scripts/testbed.sh shot <png>      screenshot the bed
#   scripts/testbed.sh key <args...>   wtype into the bed
#   scripts/testbed.sh at <x> <y>      move the bed's pointer
#   scripts/testbed.sh click [button]  press and release
#   scripts/testbed.sh stop            tear it all down
set -euo pipefail

DIR="${BANDITSHELL_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CONF=/tmp/banditshell-testbed.conf
MARK=/tmp/banditshell-testbed.display
PIDS=/tmp/banditshell-testbed.pids

# WHICH DISPLAY IS THE BED. Recorded at start rather than guessed at every call:
# the session's own socket is also in that directory, and picking the newest one
# is right exactly until it is not.
bed_display() { cat "$MARK" 2>/dev/null; }

case "${1:-}" in
start)
    "$0" stop || true
    printf 'output HEADLESS-1 resolution %s\ndefault_border none\n' "${2:-1400x900}" > "$CONF"
    before=$(ls "$RUNTIME" | grep -c '^wayland-[0-9]*$' || true)
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
        setsid sway --config "$CONF" > /tmp/banditshell-testbed.log 2>&1 &
    for _ in $(seq 40); do
        now=$(ls "$RUNTIME" | grep -c '^wayland-[0-9]*$' || true)
        [ "$now" -gt "$before" ] && break
        sleep 0.25
    done
    ls -1 "$RUNTIME" | grep '^wayland-[0-9]*$' | sort -V | tail -1 > "$MARK"
    echo "testbed on $(bed_display)"
    ;;
run)
    [ $# -ge 2 ] || { echo "usage: testbed.sh run <qml> [VAR=value ...]" >&2; exit 2; }
    qml="$2"; shift 2
    # Its own instance every time, and the previous one taken down first: a
    # screenshot of a stale window that merely looks current is the single most
    # expensive mistake this rig exists to prevent.
    #
    # BY RECORDED PID, never by `pkill -f`. A pattern that matches the process
    # also matches the shell that ran the command containing it, so `pkill -f
    # 'qs -p'` kills the caller - which cost an evening of screenshots of
    # windows that were never taken down, and looked exactly like the code being
    # broken.
    "$0" reap
    # nohup rather than setsid, because setsid FORKS: the pid recorded would be
    # setsid's and killing it leaves the real process running. That is how stale
    # windows survived every reap and got screenshotted instead of the new ones,
    # twice, each time looking exactly like the change having no effect.
    ( cd "$HOME" && env WAYLAND_DISPLAY="$(bed_display)" "$@" \
        nohup qs -p "$qml" > /tmp/banditshell-testbed-qs.log 2>&1 &
      echo $! >> "$PIDS" )
    sleep "${TESTBED_SETTLE:-5}"
    ;;
shot)
    WAYLAND_DISPLAY="$(bed_display)" grim "${2:-/tmp/banditshell-testbed.png}"
    echo "${2:-/tmp/banditshell-testbed.png}"
    ;;
key)
    shift
    WAYLAND_DISPLAY="$(bed_display)" wtype "$@"
    ;;
at)
    swaymsg -s "$(ls -1 "$RUNTIME"/sway-ipc.*.sock 2>/dev/null | tail -1)" \
        seat - cursor set "$2" "$3" >/dev/null
    ;;
click)
    sock=$(ls -1 "$RUNTIME"/sway-ipc.*.sock 2>/dev/null | tail -1)
    swaymsg -s "$sock" seat - cursor press "${2:-button1}" >/dev/null
    swaymsg -s "$sock" seat - cursor release "${2:-button1}" >/dev/null
    ;;
reap)
    # Everything this rig started, and nothing else.
    [ -f "$PIDS" ] && while read -r pid; do
        kill "$pid" 2>/dev/null || true
    done < "$PIDS"
    rm -f "$PIDS"
    sleep 0.4
    ;;
stop)
    "$0" reap
    # sway is matched by exact name AND by our own config path, so a sway the
    # user is running is never a candidate.
    for pid in $(pgrep -x sway 2>/dev/null || true); do
        tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q "$CONF" && kill "$pid" 2>/dev/null || true
    done
    rm -f "$MARK"
    ;;
*)
    sed -n '2,20p' "$0"
    exit 2
    ;;
esac
