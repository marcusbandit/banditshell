#!/usr/bin/env bash
set -u

: "${SHELL_QML:?}" "${SRC:?}" "${OUT:?}"
CHECKOUT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
results="$OUT/calls.tsv"
: >"$results"
export BANDITSHELL_DIR="$SRC"
cli="$SRC/cli/banditshell"

record() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$results"; }

target_count() { qs ipc -p "$SHELL_QML" show 2>/dev/null | grep -c '^target'; }

wait_for_targets() {
    local previous=-1 count stable=0 waited
    for ((waited = 0; waited < 60; waited++)); do
        count=$(target_count)
        if [ "$count" -gt 0 ] && [ "$count" -eq "$previous" ]; then
            stable=$((stable + 1))
            [ "$stable" -ge 2 ] && return 0
        else
            stable=0
        fi
        previous=$count
        sleep 1
    done
    return 1
}

try() {
    local label="$1" pattern="$2" out status first
    shift 2
    out=$(timeout 8 "$@" 2>&1)
    status=$?
    first=$(printf '%s\n' "$out" | head -n 1)
    if [ "$status" -ne 0 ]; then
        record FAIL "$label" "exit $status: $first"
    elif [ -n "$pattern" ] && ! printf '%s\n' "$out" | grep -Eq "$pattern"; then
        record FAIL "$label" "unexpected reply: $first"
    else
        record PASS "$label" "$first"
    fi
}

ipc_status() { try "ipc $1 status" "" qs ipc -p "$SHELL_QML" call "$1" status; }

verb() {
    local label="$1"
    shift
    try "$label" "" "$cli" "$@"
    sleep 0.6
}

shot() {
    local name="$1"
    qs ipc -p "$SHELL_QML" call shot take "$OUT/$name.png" >/dev/null 2>&1
    sleep 2
    if [ -s "$OUT/$name.png" ] && [ "$(head -c 4 "$OUT/$name.png" | tail -c 3)" = PNG ]; then
        record PASS "shot $name" "$OUT/$name.png"
    else
        record FAIL "shot $name" "no png written"
    fi
}

if ! wait_for_targets; then
    record FAIL "shell came up and listed its ipc targets" "no targets after 60 seconds"
    exit 0
fi
record PASS "shell came up and listed its ipc targets" "$(target_count) targets"
sleep 2

[ -z "${BOOT_SHOTS:-}" ] || shot rest

while IFS= read -r target; do
    ipc_status "$target"
done < <(node "$CHECKOUT/scripts/boot-check.js" calls "$CHECKOUT/tests/fixtures/ipc-targets.json")

verb "panel launcher toggle" panel launcher toggle
sleep 1
[ -z "${BOOT_SHOTS:-}" ] || shot launcher
verb "panel launcher status" panel launcher status
verb "panel launcher close" panel launcher close
verb "panel clipboard toggle" panel clipboard toggle
sleep 1
verb "panel close" panel close
sleep 1

if command -v notify-send >/dev/null; then
    try "notify-send first" "" notify-send -a Boot "Boot check" "first message"
    try "notify-send second" "" notify-send -a Boot "Boot check" "second message"
    sleep 1
    verb "notifications" notifications
    verb "notifications list" notifications list
else
    record SKIP "notifications" "notify-send not found"
fi

verb "island push" island push --id boot-check --text "Booting" --progress 0.5
sleep 1
verb "island update" island update boot-check --text "Booted" --progress 1
sleep 1
verb "island end" island end boot-check "done"
verb "focus quiet" focus quiet
verb "focus mode list" focus mode list
verb "wallpaper" wallpaper
verb "clock timer" clock timer
try "version --json" '^\{' "$cli" version --json
verb "action panel.clipboard.toggle" action panel.clipboard.toggle
sleep 1
verb "panel close after action" panel close
sleep 1
exit 0
