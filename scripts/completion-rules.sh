#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CLI="${1:-$REPO/cli/banditshell}"
DESCRIPTION_COLUMN=31
SOURCES=" panel menu screen theme key file dir page layer app place index worktree command "

case "${1:-}" in
-h | --help)
    echo "usage: completion-rules.sh [cli]"
    echo "  print the completion table that scripts/zsh-completion.sh and"
    echo "  scripts/bash-completion.sh both build from the CLI's header"
    exit 0
    ;;
esac

[ -r "$CLI" ] || { echo "completion-rules.sh: cannot read $CLI" >&2; exit 1; }

header() { awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$CLI"; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

split_on() {
    local separator="$1" s="$2" depth=0 current="" i ch
    for ((i = 0; i < ${#s}; i++)); do
        ch="${s:i:1}"
        case "$ch" in
        '<' | '[') depth=$((depth + 1)) ;;
        '>' | ']') depth=$((depth - 1)) ;;
        esac
        if [ "$ch" = "$separator" ] && [ "$depth" -eq 0 ]; then
            printf '%s\n' "$current"
            current=""
        else
            current+="$ch"
        fi
    done
    printf '%s\n' "$current"
}

plain_word() { [[ $1 =~ ^[a-z][a-z0-9-]*$ ]]; }

placeholder() {
    if [[ $SOURCES == *" $1 "* ]]; then
        printf '@%s' "$1"
    else
        printf '*'
    fi
}

position_of() {
    local token="$1" inner item items="" piece
    if plain_word "$token"; then
        printf '%s' "$token"
        return
    fi
    case "$token" in
    '<'*'>' | '['*']') inner="${token:1:${#token}-2}" ;;
    *) printf '*'; return ;;
    esac
    if [[ $inner != *"|"* ]] && [[ $inner != *"<"* ]]; then
        placeholder "$inner"
        return
    fi
    while IFS= read -r item; do
        item="$(trim "$item")"
        [ -n "$item" ] || continue
        if plain_word "$item"; then
            piece="$item"
        elif [[ $item =~ ^\<([a-z]+)\>$ ]]; then
            piece="$(placeholder "${BASH_REMATCH[1]}")"
        else
            piece="*"
        fi
        [[ ",$items," == *",$piece,"* ]] || items="${items:+$items,}$piece"
    done < <(split_on '|' "$inner")
    printf '%s' "$items"
}

flags_of() { grep -o -- '--[a-z][a-z-]*' <<<"$1" | paste -sd, -; }

alternative_rule() {
    local alternative="$2" token rule="$1" flags=""
    while IFS= read -r token; do
        [ -n "$token" ] || continue
        if [[ $token == [\[\<]--* ]]; then
            flags="${flags:+$flags,}$(flags_of "$token")"
            continue
        fi
        rule+=" $(position_of "$token")"
    done < <(split_on ' ' "$alternative")
    printf 'rule\t%s%s\n' "$rule" "${flags:+ $flags}"
}

emit_entry() {
    local spec="$1" description="$2" names rest name alternative
    if [[ $spec == "<"*">:"* ]]; then
        name="${spec%%>:*}"
        name="${name#<}"
        rest="$(trim "${spec#*>:}")"
        printf 'values\t%s\t%s\n' "$name" "$(split_on '|' "$rest" | while IFS= read -r v; do trim "$v"; echo; done | paste -sd' ' -)"
        return
    fi
    names="${spec%% *}"
    rest="$(trim "${spec#"$names"}")"
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        printf 'verb\t%s\t%s\n' "$name" "$description"
        if [ -z "$rest" ]; then
            printf 'rule\t%s\n' "$name"
            continue
        fi
        while IFS= read -r alternative; do
            alternative="$(trim "$alternative")"
            [ -n "$alternative" ] && alternative_rule "$name" "$alternative"
        done < <(split_on '|' "$rest")
    done < <(split_on '|' "$names")
}

parse() {
    local line stripped indent spec="" description="" open=0 section="" summary="" summary_open=0
    while IFS= read -r line; do
        if [[ $line =~ ^[a-z][a-z\|]*(\ \ |$) ]]; then
            [ "$open" -eq 1 ] && emit_entry "$spec" "$(verb_description "$description")"
            open=0
            section="${line%% *}"
            summary=""
            summary_open=1
            if [ "${#line}" -gt "$DESCRIPTION_COLUMN" ] && [ "${line:$((DESCRIPTION_COLUMN - 2)):2}" = "  " ]; then
                summary="$(trim "${line:$DESCRIPTION_COLUMN}")"
                summary_open=0
            fi
            continue
        fi
        if [[ $line == "  banditshell "* ]] || [[ $line =~ ^\ \ \<[a-z]+\>: ]]; then
            [ "$open" -eq 1 ] && emit_entry "$spec" "$(verb_description "$description")"
            open=1
            summary_open=0
            if [ "${#line}" -gt "$DESCRIPTION_COLUMN" ] && [ "${line:$((DESCRIPTION_COLUMN - 2)):2}" = "  " ]; then
                spec="$(trim "${line:0:$DESCRIPTION_COLUMN}")"
                description="$(trim "${line:$DESCRIPTION_COLUMN}")"
            else
                spec="$(trim "$line")"
                description=""
            fi
            spec="${spec#banditshell }"
            continue
        fi
        stripped="$(trim "$line")"
        if [ -z "$stripped" ]; then
            [ "$open" -eq 1 ] && emit_entry "$spec" "$(verb_description "$description")"
            open=0
            summary_open=0
            continue
        fi
        indent=$((${#line} - ${#stripped}))
        if [ "$summary_open" -eq 1 ] && [ "$indent" -ge "$DESCRIPTION_COLUMN" ]; then
            summary="${summary:+$summary }$stripped"
            continue
        fi
        [ "$open" -eq 1 ] || continue
        if [ "$indent" -ge "$DESCRIPTION_COLUMN" ]; then
            description="${description:+$description }$stripped"
        elif [ "$indent" -gt 0 ]; then
            spec="$spec|$stripped"
        fi
    done < <(header)
    [ "$open" -eq 1 ] && emit_entry "$spec" "$(verb_description "$description")"
    return 0
}

verb_description() {
    if [ -n "$summary" ] && [[ $section != *"|"* ]]; then
        printf '%s' "$summary"
    else
        printf '%s' "${1:-$summary}"
    fi
}

bake() {
    printf 'values\ttheme\t%s\n' "$(sed -n 's/^\s*readonly property Theme \([A-Za-z0-9_]*\):.*/\1/p' "$REPO/config/Themes.qml" | paste -sd' ' -)"
    printf 'values\tpage\t%s\n' "$(sed -n -e 's/^    { id: "\([a-z]*\)", name: "[^"]*", icon: "[^"]*",\( preview: "[^"]*",\)\{0,1\}$/\1/p' -e 's/^        id: "\([a-z]*\)", name: .*/\1/p' "$REPO/modules/settings/catalogue.js" | paste -sd' ' -)"
    printf 'values\tlayer\t%s\n' "$(sed -n 's/^ \{12\}\([a-zA-Z]*\): \[$/\1/p' "$REPO/modules/keyboard/Layouts.qml" | paste -sd' ' -)"
}

parse | awk -F'\t' '$1 == "verb" && verbs[$2]++ { next } !seen[$0]++'
bake
