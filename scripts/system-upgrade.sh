#!/usr/bin/env bash
set -u
umask 077

usage() {
    echo "usage: system-upgrade.sh start DIR [--noconfirm]" >&2
    echo "       system-upgrade.sh command DIR [--noconfirm]" >&2
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
    grep -aqE 'checking (keys in keyring|keyring|package integrity)|loading package files|checking for file conflicts|checking available disk space|:: Running pre-transaction hooks|:: Processing package changes|:: Running post-transaction hooks|Preconfiguring packages|\(Reading database|Preparing to unpack|Unpacking [^ ]+ \(|Setting up [^ ]+ \(|Removing [^ ]+ \(|Running transaction|Transaction check|\[ *[0-9]+/[0-9]+\] (Verify package|Prepare transaction|Installing|Upgrading|Downgrading|Reinstalling|Removing|Erasing)|Checking for file conflicts|\( *[0-9]+/[0-9]+\) (Installing|Removing):' -- "$dir/log" 2>/dev/null && return 0
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

tool() {
    local name
    for name in pacman apt-get dnf zypper; do
        if command -v "$name" >/dev/null 2>&1; then
            printf '%s\n' "${name%-get}"
            return 0
        fi
    done
    return 1
}

rolling() {
    grep -qE '^ID="?opensuse-(tumbleweed|slowroll|microos)"?$' -- "${BANDITSHELL_OS_RELEASE:-/etc/os-release}" 2>/dev/null
}

upgrade_command() {
    local yes=$2 binary
    binary=$(command -v "$([ "$1" = apt ] && echo apt-get || echo "$1")") || return 1
    case "$binary" in /*) ;; *) return 1 ;; esac
    case "$1" in
    pacman) echo "pkexec $binary -Syu --color always${yes:+ --noconfirm}" ;;
    apt) echo "pkexec /bin/sh -c '$binary update && exec env DEBIAN_FRONTEND=noninteractive $binary -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade${yes:+ -y}'" ;;
    dnf) echo "pkexec $binary upgrade --refresh${yes:+ -y}" ;;
    zypper)
        if rolling; then
            echo "pkexec $binary${yes:+ --non-interactive} dist-upgrade --download-in-advance"
        else
            echo "pkexec $binary${yes:+ --non-interactive} update --download-in-advance"
        fi
        ;;
    *) return 1 ;;
    esac
}

planned() {
    local yes=
    case "${1:-}" in
    "") ;;
    --noconfirm) yes=1 ;;
    *) usage ;;
    esac
    if [ -n "${BANDITSHELL_UPGRADE_COMMAND:-}" ]; then
        printf '%s\n%s\n' "${BANDITSHELL_UPGRADE_TOOL:-pacman}" "$BANDITSHELL_UPGRADE_COMMAND"
        return 0
    fi
    command -v pkexec >/dev/null 2>&1 || return 4
    local name
    name=$(tool) || return 4
    printf '%s\n' "$name"
    upgrade_command "$name" "$yes" || return 4
}

send() {
    timeout 2 sh -c 'printf "%b" "$2" >"$1"' sh "$dir/input" "$1"
}

case "$verb" in
command)
    planned "${3:-}"
    exit
    ;;
start)
    runner_pid >/dev/null && exit 3
    plan=$(planned "${3:-}") || exit
    name=${plan%%$'\n'*}
    command=${plan#*$'\n'}
    rm -rf -- "$dir"
    mkdir -p -- "$dir" || exit 1
    mkfifo -- "$dir/input" || exit 1
    : >"$dir/log"
    printf '%s\n' "$name" >"$dir/tool"
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
    [ -s "$dir/tool" ] && printf 'tool=%s\n' "$(head -n 1 -- "$dir/tool")"
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
