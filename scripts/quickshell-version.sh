#!/usr/bin/env bash

set -u

MINIMUM="0.3.2"

older() {
    local -a ours least
    local i a b
    IFS=. read -ra ours <<<"$1"
    IFS=. read -ra least <<<"$2"
    for i in 0 1 2; do
        a="${ours[i]:-0}"
        b="${least[i]:-0}"
        a="${a%%[!0-9]*}"
        b="${b%%[!0-9]*}"
        [ "${a:-0}" -lt "${b:-0}" ] && return 0
        [ "${a:-0}" -gt "${b:-0}" ] && return 1
    done
    return 1
}

command -v qs >/dev/null 2>&1 || { echo "quickshell is not installed"; exit 2; }
line=$(qs --version 2>/dev/null | head -n 1)
have=$(printf '%s\n' "$line" | sed -n 's/^[Qq]uickshell[^0-9]*\([0-9][0-9.]*\).*/\1/p')
have="${have%.}"
if [ -z "$have" ]; then
    echo "quickshell did not say its version"
    exit 3
fi
if older "$have" "$MINIMUM"; then
    echo "quickshell $have is older than $MINIMUM, the version banditshell is built on; parts of the shell may not load until it is updated"
    exit 1
fi
echo "quickshell $have"
