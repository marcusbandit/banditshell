#!/usr/bin/env bash
set -u
umask 077

usage() {
    echo "usage: system-upgrade.sh start DIR [--noconfirm]" >&2
    echo "       system-upgrade.sh state DIR" >&2
    echo "       system-upgrade.sh seen DIR" >&2
    echo "       system-upgrade.sh answer DIR TEXT" >&2
    echo "       system-upgrade.sh cancel DIR" >&2
    echo "       system-upgrade.sh watch DIR" >&2
    exit 2
}

[ $# -ge 2 ] || usage
verb=$1
dir=$2

started_at() {
    local stat
    stat=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
    stat=${stat##*) }
    printf '%s\n' "$stat" | cut -d' ' -f20
}

runner_pid() {
    local pid since
    [ -r "$dir/pid" ] || return 1
    read -r pid since <"$dir/pid" || return 1
    [[ $pid =~ ^[0-9]+$ ]] && [ "$pid" -gt 1 ] || return 1
    [ -e "$dir/status" ] && return 1
    [ -n "$since" ] && [ "$(started_at "$pid")" = "$since" ] || return 1
    printf '%s\n' "$pid"
}

committed() {
    grep -aqE 'checking (keys in keyring|keyring|package integrity)|loading package files|checking for file conflicts|checking available disk space|:: Running pre-transaction hooks|:: Processing package changes|:: Running post-transaction hooks' -- "$dir/log" 2>/dev/null && return 0
    awk '{
        rest = $0
        while (match(rest, /Total \( *[0-9]+\/[0-9]+\)/)) {
            pair = substr(rest, RSTART, RLENGTH)
            gsub(/[^0-9\/]/, "", pair)
            split(pair, n, "/")
            if (n[1] == n[2]) found = 1
            rest = substr(rest, RSTART + RLENGTH)
        }
    } END { exit !found }' "$dir/log" 2>/dev/null
}

send() {
    timeout 2 sh -c 'printf "%b" "$2" >"$1"' sh "$dir/input" "$1"
}

case "$verb" in
start)
    runner_pid >/dev/null && exit 3
    if [ -n "${BANDITSHELL_UPGRADE_COMMAND:-}" ]; then
        command=$BANDITSHELL_UPGRADE_COMMAND
    else
        command -v pkexec >/dev/null 2>&1 || exit 4
        [ -x /usr/bin/pacman ] || exit 4
        command="pkexec /usr/bin/pacman -Syu --color always"
        case "${3:-}" in
        "") ;;
        --noconfirm) command="$command --noconfirm" ;;
        *) usage ;;
        esac
    fi
    rm -rf -- "$dir"
    mkdir -p -- "$dir" || exit 1
    mkfifo -- "$dir/input" || exit 1
    : >"$dir/log"
    setsid -f bash -c '
        dir=$1 command=$2
        stat=$(cat /proc/$$/stat)
        stat=${stat##*) }
        echo "$$ $(printf "%s\n" "$stat" | cut -d" " -f20)" >"$dir/pid.new" && mv -f -- "$dir/pid.new" "$dir/pid"
        exec 3<>"$dir/input"
        SHELL=/bin/sh LC_ALL=C.UTF-8 TERM=xterm-256color script -qfec "stty cols 80 rows 24 2>/dev/null; exec $command" --log-out "$dir/log" <&3 >/dev/null 2>&1
        code=$?
        echo "$code" >"$dir/status.new" && mv -f -- "$dir/status.new" "$dir/status"
    ' bash "$dir" "$command" </dev/null >/dev/null 2>&1
    for _ in $(seq 40); do
        [ -s "$dir/pid" ] && exit 0
        sleep 0.05
    done
    exit 1
    ;;
state)
    [ -e "$dir/log" ] || exit 0
    if pid=$(runner_pid); then
        printf 'pid=%s\n' "$pid"
    else
        printf 'status=%s\n' "$(head -n 1 -- "$dir/status" 2>/dev/null)"
    fi
    [ -e "$dir/seen" ] && echo seen=1
    exit 0
    ;;
seen)
    [ -e "$dir/log" ] && : >"$dir/seen"
    ;;
answer)
    [ $# -ge 3 ] || usage
    runner_pid >/dev/null || exit 1
    case "$3" in "" | *[![:alnum:]]*) exit 2 ;; esac
    send "$3\n"
    ;;
cancel)
    runner_pid >/dev/null || exit 1
    committed && exit 5
    send '\003'
    ;;
watch)
    printf '\033[2mWatching the system update. Closing this window leaves it running.\033[0m\n\n'
    if pid=$(runner_pid); then
        tail -n +2 -f --pid="$pid" -- "$dir/log"
    else
        tail -n +2 -- "$dir/log" 2>/dev/null
    fi
    code=$(cat "$dir/status" 2>/dev/null)
    case "$code" in
    0) said="The update finished." ;;
    130 | 126) said="The update was cancelled." ;;
    "") said="The update is still running in the background." ;;
    *) said="The update stopped (code $code)." ;;
    esac
    printf '\n\033[2m%s Press Enter to close.\033[0m' "$said"
    read -r _
    ;;
*)
    usage
    ;;
esac
