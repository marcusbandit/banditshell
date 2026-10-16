#!/usr/bin/env bash
set -u
umask 077

usage() {
    echo "usage: screen-record.sh start STATE_DIR FILE MODE SOUND RECORDER [ARGS...]" >&2
    echo "       screen-record.sh stop STATE_DIR" >&2
    exit 2
}

now_ms() {
    local stamp
    stamp=$(date +%s%3N 2>/dev/null)
    [[ $stamp =~ ^[0-9]+$ ]] || stamp=$(($(date +%s) * 1000))
    printf '%s\n' "$stamp"
}

case "${1:-}" in
start)
    [ "$#" -ge 6 ] || usage
    dir=$2 file=$3 mode=$4 sound=$5
    shift 5
    case "$mode" in screen | area | window) ;; *) usage ;; esac
    case "$sound" in sound | quiet) ;; *) usage ;; esac
    case "$file" in /*) ;; *) usage ;; esac
    case "$1" in wf-recorder | wl-screenrec | gpu-screen-recorder) ;; *) usage ;; esac

    mkdir -p -- "$dir" && chmod 700 -- "$dir" || exit 1
    state="$dir/recording"
    if [ -s "$state" ] && [ -d "/proc/$(head -n 1 "$state")" ]; then
        echo "a recording is already running" >&2
        exit 3
    fi
    old_umask=$(umask)
    umask 022
    mkdir -p -- "$(dirname -- "$file")" || exit 1
    umask "$old_umask"

    log="$dir/recording.log"
    : >"$log"
    set -m
    "$@" </dev/null >>"$log" 2>&1 &
    child=$!
    trap 'kill -INT "$child" 2>/dev/null' INT TERM HUP

    partial=$(mktemp "$state.XXXXXX") || exit 1
    printf '%s\n%s\n%s\n%s\n%s\n' "$child" "$(now_ms)" "$file" "$mode" "$sound" >"$partial"
    mv -f -- "$partial" "$state"

    status=0
    wait "$child" || status=$?
    while kill -0 "$child" 2>/dev/null; do
        wait "$child" || status=$?
    done

    size=0
    [ -f "$file" ] && size=$(stat -c %s -- "$file" 2>/dev/null || echo 0)
    [ "$size" -gt 0 ] 2>/dev/null || rm -f -- "$file"
    partial=$(mktemp "$dir/result.XXXXXX") || exit 1
    {
        printf '%s\n%s\n%s\n' "$status" "$file" "$size"
        tail -n 3 -- "$log"
    } >"$partial"
    mv -f -- "$partial" "$dir/result"
    rm -f -- "$state"
    exit "$status"
    ;;
stop)
    [ "$#" -eq 2 ] || usage
    state="$2/recording"
    [ -r "$state" ] || exit 1
    pid=$(head -n 1 -- "$state")
    [[ $pid =~ ^[0-9]+$ ]] && [ "$pid" -gt 1 ] || exit 1
    [ -d "/proc/$pid" ] || exit 1
    kill -INT "$pid"
    ;;
*)
    usage
    ;;
esac
