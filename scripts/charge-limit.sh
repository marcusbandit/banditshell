#!/bin/sh
set -eu

value="${1:-}"

case "$value" in
'' | 0* | *[!0-9]*)
    echo "usage: charge-limit <50-100>" >&2
    exit 2
    ;;
esac

if [ "${#value}" -gt 3 ] || [ "$value" -lt 50 ] || [ "$value" -gt 100 ]; then
    echo "usage: charge-limit <50-100>" >&2
    exit 2
fi

status=1
for attribute in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [ -w "$attribute" ] || continue
    printf '%s\n' "$value" >"$attribute" && status=0
done
exit "$status"
