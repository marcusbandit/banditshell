#!/usr/bin/env bash

set -uo pipefail

DIR="${BANDITSHELL_ASKPASS_DIR:-${XDG_RUNTIME_DIR:-/tmp}/banditshell-askpass}"
UI_DIR="${BANDITSHELL_UI_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)}"

REQ="$DIR/req"
RSP="$DIR/rsp"
PIDF="$DIR/ui.pid"
TRIES="$DIR/tries"

mkdir -p "$DIR" || exit 1
chmod 700 "$DIR" || exit 1

[ -p "$REQ" ] || mkfifo -m 600 "$REQ" || exit 1
[ -p "$RSP" ] || mkfifo -m 600 "$RSP" || exit 1
rm -f "$DIR/cancelled"

ui_alive() {
    [ -f "$PIDF" ] || return 1
    kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null
}

if ! ui_alive; then
    printf '1' >"$TRIES"
    BANDITSHELL_ASKPASS_DIR="$DIR" qs -p "$UI_DIR/askpass.qml" >/dev/null 2>&1 &
    printf '%s' "$!" >"$PIDF"
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        ui_alive || break
        [ -f "$DIR/ready" ] && break
        sleep 0.2
    done
    ui_alive || exit 1
else
    printf '%s' "$(($(cat "$TRIES" 2>/dev/null || echo 1) + 1))" >"$TRIES"
fi

attempt="$(cat "$TRIES" 2>/dev/null || echo 1)"

token="ask"
[ "$attempt" -gt 1 ] && token="retry"

give_up() {
    printf '%s\n' "$1" >"$DIR/why"
    printf 'askpass: %s\n' "$1" >&2
    exit 1
}

rm -f "$DIR/why"

if ! timeout 20 sh -c 'printf "%s\n" "$1" > "$2"' _ "$token" "$REQ"; then
    give_up "the password window did not take the request"
fi

exec 3<>"$RSP" || exit 1
secret=""
waited=0
wait_limit="${BANDITSHELL_ASKPASS_WAIT:-300}"
while :; do
    alive=0
    ui_alive && alive=1
    IFS= read -r -t 1 part <&3
    status=$?
    secret="$secret$part"
    [ "$status" -eq 0 ] && break
    [ "$status" -gt 128 ] || give_up "the password window closed without an answer"
    [ "$alive" -eq 1 ] || give_up "the password window closed without an answer"
    waited=$((waited + 1))
    [ "$waited" -lt "$wait_limit" ] || give_up "no answer from the password window in $wait_limit seconds"
done
unset part
exec 3<&-

if [ -f "$DIR/cancelled" ]; then
    unset secret
    exit 1
fi

printf '%s\n' "$secret"
unset secret
exit 0
