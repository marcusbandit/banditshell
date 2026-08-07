#!/usr/bin/env bash
# What the clipboard just became, as one line of JSON.
#
# Run as `wl-paste --watch scripts/clip-record.sh`, so it fires once per
# selection and prints one object per fire. services/Clipboard.qml reads those
# lines off stdout and does everything else: dedup, history, ordering, storage
# policy. This half only answers the question the compositor can answer and QML
# cannot, which is WHAT WAS COPIED.
#
# That question is the whole reason this file exists rather than the shell
# reading somebody else's history store. A clipboard offers its content in
# several types at once and the type list is the only place the difference
# between a file, a picture, a sound and a sentence is written down. clipse
# records four fields and no type among them, so a path, a URL and a paragraph
# arrive identical and a menu built on it can only guess by looking at the text.
# `wl-paste --list-types` is not a guess.
#
# Output, one line, always a complete object (see `emit`):
#   state  data | sensitive | nil | clear   what wl-paste said this event was
#   types  every MIME type the source offers, in its own order of preference
#   text   the content, when it is textual
#   file   where the bytes were saved, when it is not
#   bytes  how big that file is
#   paths  a copied FILE's real path(s), decoded out of the URI list
#   mimes  what `file` makes of each of those paths, index for index
#
# Missing keys mean "does not apply"; the reader must not assume any of them.

set -uo pipefail

store="${BANDITSHELL_CLIP_STORE:-${XDG_STATE_HOME:-$HOME/.local/state}/banditshell/clipboard}"

# CEILINGS, because a clipboard is not a place anything agreed to be kept.
# Copying a disk image offers it to whoever asks, and a history that stores
# every offer would answer a paste by filling the disk. Past these the event is
# recorded as what it was and the bytes are dropped, which is the honest
# outcome: the menu can say a thing was copied without claiming to still have it.
maxText="${BANDITSHELL_CLIP_MAXTEXT:-1048576}"
maxBlob="${BANDITSHELL_CLIP_MAXBLOB:-33554432}"

mkdir -p "$store" || exit 1

# jq builds every string, because the values here are arbitrary bytes from
# arbitrary applications: a quote, a backslash, a newline or a lone tab in a
# copied snippet would each end the line early if this printed JSON by hand, and
# the reader would see a parse error rather than the paste. --arg takes the
# bytes as they are and does the escaping itself.
have_jq() { command -v jq >/dev/null 2>&1; }
have_jq || exit 1

# EVERY READ OF THE CLIPBOARD IS BOUNDED, and this is not defensive padding.
#
# A selection is served by the process that owns it, over a pipe opened per
# request. Ask for a type and the owner writes it; if the owner is GONE, which is
# exactly what has happened when the clipboard changed between listing the types
# and fetching the bytes, nothing is ever written and the read never returns.
# Measured, not theorised: copying twice in quick succession left `wl-paste -t
# image/png` alive for five minutes with the script waiting on it, one stuck
# process per occurrence, and the picture never recorded.
#
# The window is small and this runs on every selection, so it is hit by ordinary
# use rather than by anything exotic. TERM first and KILL a second later, since a
# process wedged on a pipe that will never be written does not always take the
# hint.
readTimeout="${BANDITSHELL_CLIP_TIMEOUT:-5}"
clip() { timeout -k 1 "$readTimeout" wl-paste "$@"; }

# ONE line, ALWAYS. Every path out of this script ends here, including the ones
# that decided to store nothing, because silence and "nothing worth keeping" look
# identical to a reader and only one of them means the watcher is still alive.
emit() {
    jq -c -n --arg state "$1" --argjson types "$2" --argjson body "$3" \
        '{state: $state, types: $types} + $body'
}

state="${CLIPBOARD_STATE:-data}"

# NOTHING IS READ ON THESE. A cleared clipboard has nothing to offer and asking
# anyway logs an error per event; a sensitive one has plenty and wl-clipboard is
# telling us not to keep it. The event is still reported, so the shell can drop a
# live "current" marker rather than going on pointing at a selection that is gone.
if [ "$state" != "data" ]; then
    emit "$state" '[]' '{}'
    exit 0
fi

# The source's OWN order, kept. A preference list is information: the first type
# an application offers is the one it would rather you took, and re-sorting it
# here would throw that away before the reader ever saw it.
mapfile -t typeList < <(clip --list-types 2>/dev/null)
types=$(printf '%s\n' "${typeList[@]}" | jq -R . | jq -sc 'map(select(length > 0))')

has() {
    local want="$1" t
    for t in "${typeList[@]}"; do
        [ "$t" = "$want" ] && return 0
    done
    return 1
}

# The first offered type matching a prefix, so `image/` finds image/png without
# this file carrying a list of every picture format there has ever been.
firstLike() {
    local prefix="$1" t
    for t in "${typeList[@]}"; do
        case "$t" in
        "$prefix"*) printf '%s' "$t"; return 0 ;;
        esac
    done
    return 1
}

# A copied FILE, which is the case that looks like text and is not.
#
# Dragging a song out of a file manager puts `text/uri-list` on the clipboard and
# ALSO offers it as text/plain, so anything that reads the preferred text type
# gets `file:///home/.../track.flac` and stores a sentence. The URI list is the
# type that says these are files, so it is tested before text and decoded here:
# percent-escapes come off, and `file` is asked what each one actually is. That
# is where "this is audio" comes from, and there is nowhere else it could come
# from, because the clipboard carries the reference and never the sound.
if has "text/uri-list"; then
    # CR stripped ON THE WAY IN, once. RFC 2483 ends every line of a URI list
    # with CRLF, so each entry arrives with a trailing carriage return; left on,
    # it rides into the stored text, into the URI, and through percent-decoding
    # into the PATH, where the file is then not found and a copied song is
    # reported as a dead link. Doing it here rather than at each use is what
    # stops the next reader of `uris` from rediscovering that.
    uris=$(clip -n -t text/uri-list 2>/dev/null | tr -d '\r')
    body=$(printf '%s' "$uris" | jq -Rsc '
        {
            text: .,
            uris: (split("\n") | map(select(startswith("file://") or (test("^[a-z][a-z0-9+.-]*://")))))
        }')
    # Decoded and probed in the shell, because percent-decoding and libmagic are
    # both here and neither is in QML.
    paths=()
    mimes=()
    while IFS= read -r uri; do
        [ -n "$uri" ] || continue
        case "$uri" in
        file://*) ;;
        *) continue ;;
        esac
        # %20 and friends. printf's %b turns the \x escapes into the bytes.
        p=${uri#file://}
        p=$(printf '%b' "${p//%/\\x}")
        # A URI THAT DECODES TO NOTHING IS SKIPPED HERE, before either array
        # grows, which is the only place the two can be kept in step. Dropping
        # it later from `paths` alone (a `select(length > 0)` on one side and
        # not the other) leaves `mimes` one longer with the hole still in the
        # middle, so every mime after the gap is read against the wrong path:
        # a file that exists gets reported "gone" and the row's whole kind can
        # flip. A bare `file://` line is the case that produces it.
        [ -n "$p" ] || continue
        paths+=("$p")
        if [ -e "$p" ]; then
            mimes+=("$(file --mime-type -b -- "$p" 2>/dev/null || echo "application/octet-stream")")
        else
            # A path that is no longer there is still what was copied. Said
            # plainly rather than guessed at, so the menu can show it struck
            # through instead of claiming a type for a file it cannot open.
            mimes+=("")
        fi
    done < <(printf '%s\n' "$uris")

    # BOTH ARRAYS ARE BUILT THE SAME WAY, which is the whole point: they are
    # read index for index on the far end, so anything that filters one has to
    # filter the other identically or the pairing silently shifts. Nothing
    # filters either now; the skip above is what guarantees no empty element
    # exists to filter. `${a[@]+...}` is the empty-array guard under `set -u`,
    # and the count is taken from bash rather than recovered in jq.
    # Built from the ARGUMENT VECTOR, not from a stream of lines, because a
    # filename may legally contain a newline and a line-split would then turn one
    # path into two and shift every mime after it. `--args` takes each element as
    # itself whatever bytes are in it, and yields `[]` for none, so the empty
    # case needs no branch of its own.
    pathsJson=$(jq -nc '$ARGS.positional' --args ${paths[@]+"${paths[@]}"})
    mimesJson=$(jq -nc '$ARGS.positional' --args ${mimes[@]+"${mimes[@]}"})
    body=$(jq -c -n --argjson b "$body" --argjson paths "$pathsJson" --argjson mimes "$mimesJson" \
        '$b + {paths: $paths, mimes: $mimes}')
    emit "$state" "$types" "$body"
    exit 0
fi

# A PICTURE, saved rather than described.
#
# Named by content hash, so the same screenshot copied twice is one file on disk
# and the reader can dedup on the name without comparing megabytes. The extension
# comes off the MIME type so the file is openable by anything, and image/svg+xml
# lands as .svg rather than .svg+xml.
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
    # Renamed, never copied: same filesystem, so it is atomic, and a reader that
    # sees the name sees the whole file. `.incoming` is a dotfile for the window
    # between the two, where a directory listing would otherwise show a partial
    # picture as history.
    mv -f "$tmp" "$out" 2>/dev/null || { rm -f "$tmp"; emit "$state" "$types" '{}'; exit 0; }

    # HOW BIG THE PICTURE IS, IN ITS OWN PIXELS, asked here because here is the
    # only place it can be asked cheaply and truthfully.
    #
    # The menu cannot work it out later: a thumbnail is decoded at the size it is
    # drawn, so what QML can measure is the size of the copy it asked for, not
    # the size of the picture. Decoding at full size purely to measure would be
    # the one expensive thing in an otherwise cheap path. libmagic already read
    # the header to identify the file and reports the dimensions from it, so this
    # is a regex over a string that has already been produced.
    #
    # Both or neither: a half-parsed size is worse than none, since the row uses
    # the pair as a ratio.
    read -r w h < <(file -b -- "$out" 2>/dev/null | sed -nE 's/.*[^0-9]([0-9]+) ?x ?([0-9]+).*/\1 \2/p' | head -1)
    if [ -n "${w:-}" ] && [ -n "${h:-}" ]; then
        emit "$state" "$types" "$(jq -c -n --arg file "$out" --argjson bytes "$bytes" --argjson w "$w" --argjson h "$h" '{file: $file, bytes: $bytes, w: $w, h: $h}')"
    else
        emit "$state" "$types" "$(jq -c -n --arg file "$out" --argjson bytes "$bytes" '{file: $file, bytes: $bytes}')"
    fi
    exit 0
fi

# TEXT, which is everything left. `-n` because a trailing newline is an artefact
# of how the content was selected and not part of what was copied: without it
# every path dragged from a terminal is stored one byte different from the same
# path typed out, and the two never dedup against each other.
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

# Offered as something this shell has no way to show and no business storing.
# Reported anyway: the type list alone is enough for the menu to say what it was.
emit "$state" "$types" '{}'
