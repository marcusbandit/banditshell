#!/bin/sh
umask 077
target="${1:?usage: write-private.sh FILE < TEXT}"
folder=$(dirname -- "$target")
mkdir -p -- "$folder" && chmod 700 -- "$folder" || exit 1
partial=$(mktemp "$target.XXXXXX") || exit 1
if cat >"$partial"; then
    mv -f -- "$partial" "$target"
else
    rm -f -- "$partial"
    exit 1
fi
