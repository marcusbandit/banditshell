#!/usr/bin/env bash
set -u

case "${1:-}" in
-h | --help | "")
    echo "usage: assistant-request.sh <url> <auth-prefix> <get|post|stream> [header...]"
    echo "  the body comes on stdin for post and stream; the key comes from"
    echo "  BANDITSHELL_ASSISTANT_KEY and is handed to curl on a file descriptor,"
    echo "  so it never shows in a process list"
    exit 0
    ;;
esac

url=$1 auth=$2 method=$3
shift 3

key=${BANDITSHELL_ASSISTANT_KEY:-}
unset BANDITSHELL_ASSISTANT_KEY

options=(-sS -N --connect-timeout 5 -w '\n@@status %{http_code}\n')
for header in "$@"; do
    options+=(-H "$header")
done
case "$method" in
get) options+=(--max-time 15) ;;
post) options+=(--max-time 300 --data-binary @-) ;;
stream) options+=(--data-binary @-) ;;
esac

if [ -n "$auth" ]; then
    exec curl "${options[@]}" -H @/dev/fd/3 "$url" 3<<EOF
$auth$key
EOF
fi
exec curl "${options[@]}" "$url"
