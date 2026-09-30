#!/usr/bin/env bash

set -uo pipefail

store="${BANDITSHELL_CLIP_STORE:-${XDG_STATE_HOME:-$HOME/.local/state}/banditshell/clipboard}"

maxText="${BANDITSHELL_CLIP_MAXTEXT:-1048576}"
maxBlob="${BANDITSHELL_CLIP_MAXBLOB:-33554432}"

mkdir -p "$store" || exit 1

have_jq() { command -v jq >/dev/null 2>&1; }
have_jq || exit 1

readTimeout="${BANDITSHELL_CLIP_TIMEOUT:-5}"
clip() { timeout -k 1 "$readTimeout" wl-paste "$@"; }

emit() {
    jq -c -n --arg state "$1" --argjson types "$2" --argjson body "$3" \
        '{state: $state, types: $types} + $body'
}

state="${CLIPBOARD_STATE:-data}"

if [ "$state" != "data" ]; then
    emit "$state" '[]' '{}'
    exit 0
fi

mapfile -t typeList < <(clip --list-types 2>/dev/null)
types=$(printf '%s\n' "${typeList[@]}" | jq -R . | jq -sc 'map(select(length > 0))')

has() {
    local want="$1" t
    for t in "${typeList[@]}"; do
        [ "$t" = "$want" ] && return 0
    done
    return 1
}

firstLike() {
    local prefix="$1" t
    for t in "${typeList[@]}"; do
        case "$t" in
        "$prefix"*) printf '%s' "$t"; return 0 ;;
        esac
    done
    return 1
}

if has "text/uri-list"; then
    uris=$(clip -n -t text/uri-list 2>/dev/null | tr -d '\r')
    body=$(printf '%s' "$uris" | jq -Rsc '
        {
            text: .,
            uris: (split("\n") | map(select(startswith("file://") or (test("^[a-z][a-z0-9+.-]*://")))))
        }')
    paths=()
    mimes=()
    while IFS= read -r uri; do
        [ -n "$uri" ] || continue
        case "$uri" in
        file://*) ;;
        *) continue ;;
        esac
        p=${uri#file://}
        p=$(printf '%b' "${p//%/\\x}")
        [ -n "$p" ] || continue
        paths+=("$p")
        if [ -e "$p" ]; then
            mimes+=("$(file --mime-type -b -- "$p" 2>/dev/null || echo "application/octet-stream")")
        else
            mimes+=("")
        fi
    done < <(printf '%s\n' "$uris")

    pathsJson=$(jq -nc '$ARGS.positional' --args ${paths[@]+"${paths[@]}"})
    mimesJson=$(jq -nc '$ARGS.positional' --args ${mimes[@]+"${mimes[@]}"})
    body=$(jq -c -n --argjson b "$body" --argjson paths "$pathsJson" --argjson mimes "$mimesJson" \
        '$b + {paths: $paths, mimes: $mimes}')
    emit "$state" "$types" "$body"
    exit 0
fi

if img=$(firstLike "image/"); then
    tmp="$store/.incoming.$$"
    if ! clip -t "$img" >"$tmp" 2>/dev/null; then
        rm -f "$tmp"
        emit "$state" "$types" '{}'
        exit 0
    fi
    bytes=$(stat -c %s "$tmp" 2>/dev/null || echo 0)
    if [ "$bytes" -eq 0 ] || [ "$bytes" -gt "$maxBlob" ]; then
        rm -f "$tmp"
        emit "$state" "$types" "$(jq -c -n --argjson bytes "$bytes" '{bytes: $bytes, dropped: true}')"
        exit 0
    fi
    ext=${img#image/}
    ext=${ext%%+*}
    ext=${ext//[^a-zA-Z0-9]/}
    [ -n "$ext" ] || ext=bin
    sum=$(sha256sum <"$tmp" | cut -c1-32)
    out="$store/$sum.$ext"
    mv -f "$tmp" "$out" 2>/dev/null || { rm -f "$tmp"; emit "$state" "$types" '{}'; exit 0; }

    read -r w h < <(file -b -- "$out" 2>/dev/null | sed -nE 's/.*[^0-9]([0-9]+) ?x ?([0-9]+).*/\1 \2/p' | head -1)
    if [ -n "${w:-}" ] && [ -n "${h:-}" ]; then
        emit "$state" "$types" "$(jq -c -n --arg file "$out" --argjson bytes "$bytes" --argjson w "$w" --argjson h "$h" '{file: $file, bytes: $bytes, w: $w, h: $h}')"
    else
        emit "$state" "$types" "$(jq -c -n --arg file "$out" --argjson bytes "$bytes" '{file: $file, bytes: $bytes}')"
    fi
    exit 0
fi

if txt=$(firstLike "text/") || has "UTF8_STRING" || has "STRING" || has "TEXT"; then
    text=$(clip -n ${txt:+-t "$txt"} 2>/dev/null)
    size=${#text}
    if [ "$size" -gt "$maxText" ]; then
        emit "$state" "$types" "$(jq -c -n --argjson bytes "$size" '{bytes: $bytes, dropped: true}')"
        exit 0
    fi
    emit "$state" "$types" "$(printf '%s' "$text" | jq -Rsc '{text: .}')"
    exit 0
fi

emit "$state" "$types" '{}'
