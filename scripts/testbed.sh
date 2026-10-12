#!/usr/bin/env bash
set -euo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RUNTIME/banditshell-testbed"
CONF="$STATE/sway.conf"
MARK="$STATE/display"
SOCKET="$STATE/socket"
PIDS="$STATE/pids"

usage() {
    cat <<EOF
usage: testbed.sh start [WxH]|run <qml> [VAR=value ...]|shot [file]|key <args>
                  |at <x> <y>|click [button]|reap|stop

A headless sway to run QML in, away from the live session. Its state lives in
$STATE.

  start [WxH]                start the compositor, 1400x900 unless told
  run <qml> [VAR=value ...]  reap the last run, then qs -p <qml> inside it
  shot [file]                grim the testbed, to $STATE/shot.png unless told
  key <args>                 wtype into it
  at <x> <y>                 put the cursor there
  click [button]             press and release, button1 unless told
  reap                       kill what run started
  stop                       reap, then stop the compositor
EOF
}

displays() {
    local socket
    for socket in "$RUNTIME"/wayland-*; do
        if [[ $socket =~ /wayland-[0-9]+$ ]]; then
            printf '%s\n' "${socket##*/}"
        fi
    done
    return 0
}

bed_display() { cat "$MARK" 2>/dev/null; }
bed_socket() { cat "$SOCKET" 2>/dev/null; }

case "${1:-}" in
start)
    "$0" stop || true
    mkdir -p "$STATE"
    chmod 700 "$STATE"
    printf 'output HEADLESS-1 resolution %s\ndefault_border none\n' "${2:-1400x900}" >"$CONF"
    command -v sway >/dev/null || { echo "testbed.sh: sway is not installed" >&2; exit 1; }
    before=$(displays)
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
        setsid sway --config "$CONF" >"$STATE/sway.log" 2>&1 &
    fresh=""
    for _ in $(seq 40); do
        fresh=$(displays | grep -vxF -- "$before" | sort -V | tail -1 || true)
        [ -n "$fresh" ] && break
        sleep 0.25
    done
    if [ -z "$fresh" ]; then
        echo "testbed.sh: sway never opened a display (log: $STATE/sway.log)" >&2
        exit 1
    fi
    printf '%s\n' "$fresh" >"$MARK"
    pid=$(pgrep -f -- "--config $CONF" | head -1 || true)
    if [ -n "$pid" ]; then
        printf '%s\n' "$RUNTIME/sway-ipc.$(id -u).$pid.sock" >"$SOCKET"
    fi
    echo "testbed on $(bed_display)"
    ;;
run)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    qml="$(realpath -- "$2")"
    shift 2
    "$0" reap
    mkdir -p "$STATE"
    chmod 700 "$STATE"
    (cd "$HOME" && env WAYLAND_DISPLAY="$(bed_display)" "$@" \
        nohup qs -p "$qml" >"$STATE/qs.log" 2>&1 &
        echo $! >>"$PIDS")
    sleep "${TESTBED_SETTLE:-5}"
    ;;
shot)
    out="${2:-$STATE/shot.png}"
    WAYLAND_DISPLAY="$(bed_display)" grim "$out"
    echo "$out"
    ;;
key)
    shift
    WAYLAND_DISPLAY="$(bed_display)" wtype "$@"
    ;;
at)
    [ $# -ge 3 ] || { usage >&2; exit 2; }
    swaymsg -s "$(bed_socket)" seat - cursor set "$2" "$3" >/dev/null
    ;;
click)
    swaymsg -s "$(bed_socket)" seat - cursor press "${2:-button1}" >/dev/null
    swaymsg -s "$(bed_socket)" seat - cursor release "${2:-button1}" >/dev/null
    ;;
reap)
    if [ -f "$PIDS" ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null || true
        done <"$PIDS"
    fi
    rm -f "$PIDS"
    sleep 0.4
    ;;
stop)
    "$0" reap
    for pid in $(pgrep -x sway 2>/dev/null || true); do
        if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -qF -- "$CONF"; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    rm -f "$MARK" "$SOCKET"
    ;;
-h | --help | help)
    usage
    ;;
*)
    usage >&2
    exit 2
    ;;
esac
