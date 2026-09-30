#!/bin/bash
set -euo pipefail

DIR="${BANDITSHELL_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CONF=/tmp/banditshell-testbed.conf
MARK=/tmp/banditshell-testbed.display
PIDS=/tmp/banditshell-testbed.pids

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
    "$0" reap
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
    [ -f "$PIDS" ] && while read -r pid; do
        kill "$pid" 2>/dev/null || true
    done < "$PIDS"
    rm -f "$PIDS"
    sleep 0.4
    ;;
stop)
    "$0" reap
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
