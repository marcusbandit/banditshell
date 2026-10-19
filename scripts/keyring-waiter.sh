#!/usr/bin/env bash
set -u

name="${1:?usage: keyring-waiter.sh <bus name> [fallback command...]}"
shift

patience=${KEYRING_WAITER_PATIENCE:-15}
grace=${KEYRING_WAITER_GRACE:-5}

owned() {
    [ "$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner "$name" 2>/dev/null)" = "(true,)" ]
}

shell_coming() {
    local config
    while IFS= read -r config; do
        [ -f "$(dirname "$config")/scripts/keyring-prompter.py" ] && return 0
    done < <(qs list --all 2>/dev/null | sed -n 's/^[[:space:]]*Config path:[[:space:]]*//p')
    return 1
}

elapsed() { echo $(((${EPOCHREALTIME/[.,]/} - started) / 1000000)); }

started=${EPOCHREALTIME/[.,]/}

while [ "$(elapsed)" -lt "$patience" ]; do
    owned && exit 0
    [ "$(elapsed)" -ge "$grace" ] && ! shell_coming && break
    sleep 0.2
done

owned && exit 0
[ "$#" -gt 0 ] && exec "$@"
exit 1
