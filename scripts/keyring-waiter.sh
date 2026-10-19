#!/usr/bin/env bash
set -u

name="${1:?usage: keyring-waiter.sh <bus name> [fallback command...]}"
shift

patience=${KEYRING_WAITER_PATIENCE:-15}
grace=${KEYRING_WAITER_GRACE:-5}
fresh=${KEYRING_WAITER_FRESH:-30}

claimed_within() {
    gdbus wait --session --timeout "$1" "$name" >/dev/null 2>&1
}

shell_starting() {
    local line config=""
    while IFS= read -r line; do
        case $line in
            *"Config path:"*) config=${line#*Config path: } ;;
            *"running for "*)
                [[ $line =~ running\ for\ ([0-9]+)\ hours,\ ([0-9]+)\ minutes,\ ([0-9]+)\ seconds ]] || continue
                [ $((BASH_REMATCH[1] * 3600 + BASH_REMATCH[2] * 60 + BASH_REMATCH[3])) -lt "$fresh" ] &&
                    [ -f "$(dirname "$config")/scripts/keyring-prompter.py" ] && return 0
                ;;
        esac
    done < <(qs list --all 2>/dev/null)
    return 1
}

claimed_within "$grace" && exit 0
[ "$patience" -gt "$grace" ] && shell_starting && claimed_within "$((patience - grace))" && exit 0
[ "$#" -gt 0 ] && exec "$@"
exit 1
