#!/usr/bin/env bash
# SUDO_ASKPASS helper: hand sudo a password that came from a drawn window.
#
# sudo's askpass contract is one line: print the secret on stdout, exit 0. Exit
# non-zero and sudo gives up. That contract is the reason this is worth doing at
# all rather than driving `sudo -S` by hand, because it means THIS script is the
# only thing that ever holds the value, it holds it in a variable for one
# printf, and the variable dies with the process a moment later.
#
# WHAT IS NEVER DONE WITH IT, and each of these has bitten somebody:
#   - it is never an argument to anything (/proc/*/cmdline is world readable)
#   - it is never written to a file (the fifos below carry it through the
#     kernel; nothing lands on a disk)
#   - it is never echoed, logged, or run under `set -x`
#
# WHY A PERSISTENT WINDOW. sudo retries a wrong password by calling this helper
# AGAIN, up to passwd_tries times. A helper that drew its own window per call
# would flash the window away and back for every typo, which is both ugly and
# the exact moment somebody mistypes again. So the window is a separate process
# that outlives the helper: the first call starts it, later calls reach the same
# one through a pair of fifos and it shows its error state in place.
#
# Not run by hand. install.sh sets SUDO_ASKPASS to this and calls `sudo -A`.

set -uo pipefail

DIR="${BANDITSHELL_ASKPASS_DIR:-${XDG_RUNTIME_DIR:-/tmp}/banditshell-askpass}"
UI_DIR="${BANDITSHELL_UI_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)}"

REQ="$DIR/req"
RSP="$DIR/rsp"
PIDF="$DIR/ui.pid"
TRIES="$DIR/tries"

# 0700, in the runtime dir, which is tmpfs and the user's alone. The fifos carry
# no data at rest but the directory should still not be readable by anyone else.
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
    # The window has to exist before anything is written at it. Writing to a
    # fifo blocks until a reader opens, so this is belt and braces rather than
    # the actual synchronisation, but a UI that died on startup would otherwise
    # hang sudo on that open forever.
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

# "ask" the first time, "retry" after that, so the window can show an inline
# error rather than pretending nothing happened.
token="ask"
[ "$attempt" -gt 1 ] && token="retry"

if ! timeout 20 sh -c 'printf "%s\n" "$1" > "$2"' _ "$token" "$REQ"; then
    exit 1
fi

# The read is bounded. A window somebody walked away from must eventually let
# sudo fail rather than holding an install open all night.
if ! IFS= read -r -t 300 secret <"$RSP"; then
    exit 1
fi

if [ -f "$DIR/cancelled" ]; then
    unset secret
    exit 1
fi

printf '%s\n' "$secret"
unset secret
exit 0
