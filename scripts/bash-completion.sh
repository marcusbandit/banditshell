#!/usr/bin/env bash
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
RULES="$REPO/scripts/completion-rules.sh"
COMPDIR="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
TARGET="$COMPDIR/banditshell"
QUIET=0

usage() {
    cat <<EOF
usage: bash-completion.sh install|print|status|remove|where [--quiet]

  install   write $TARGET
  print     write the completion to stdout
  status    exit 0 when current, 1 when stale, 2 when not set up
  remove    delete it
  where     print where it lives

The completion is generated from the header of cli/banditshell through
scripts/completion-rules.sh, the same table zsh-completion.sh reads.
EOF
}

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

deps() {
    printf '%s\n' "$REPO/cli/banditshell" "$RULES" "$SELF" \
        "$REPO/config/Themes.qml" "$REPO/modules/settings/catalogue.js" "$REPO/modules/keyboard/Layouts.qml" \
        "$REPO/scripts/lint-rules.js" "$REPO/packages" "$REPO"/modules/*/module.json \
        "$REPO/api/actions.tsv"
}

generate() {
    local table kind name text verbs="" rules="" panel="" theme="" page="" layer="" package="" id="" lintrule=""
    table="$("$RULES")" || return 1
    while IFS=$'\t' read -r kind name text; do
        case "$kind" in
        verb) verbs+=" $name" ;;
        rule) rules+="    $(quote "$name")"$'\n' ;;
        values)
            case "$name" in
            panel) panel="$text" ;;
            theme) theme="$text" ;;
            page) page="$text" ;;
            layer) layer="$text" ;;
            package) package="$text" ;;
            id) id="$text" ;;
            rule) lintrule="$text" ;;
            esac
            ;;
        esac
    done <<<"$table"

    cat <<EOF
_bs_built=$EPOCHREALTIME
_bs_file=$(quote "$TARGET")

_bs_verbs=(${verbs# })

_bs_rules=(
$rules)

_bs_panel=( $panel )
_bs_theme=( $theme )
_bs_page=( $page )
_bs_layer=( $layer )
_bs_package=( $package )
_bs_id=( $id )
_bs_lintrule=( $lintrule )
EOF
    cat <<'EOF'

_bs_stale() {
    local cli dep
    cli=$(type -P banditshell) || return 1
    cli=$(readlink -f "$cli") || return 1
    _bs_repo=${cli%/*/*}
    [[ -x $_bs_repo/scripts/completion-rules.sh && -x $_bs_repo/scripts/bash-completion.sh ]] || return 1
    for dep in "$_bs_repo/cli/banditshell" "$_bs_repo/scripts/completion-rules.sh" "$_bs_repo/scripts/bash-completion.sh" \
        "$_bs_repo/config/Themes.qml" "$_bs_repo/modules/settings/catalogue.js" "$_bs_repo/modules/keyboard/Layouts.qml" \
        "$_bs_repo/scripts/lint-rules.js" "$_bs_repo/packages" "$_bs_repo"/modules/*/module.json "$_bs_repo/api/actions.tsv"; do
        [[ $dep -nt $_bs_file ]] && return 0
    done
    return 1
}

_bs_moved() {
    local built
    IFS= read -r built 2>/dev/null <"$_bs_file" || return 1
    [[ ${built#*=} != "$_bs_built" ]]
}

_bs_live() {
    type -P banditshell >/dev/null || return 1
    pgrep -x qs >/dev/null 2>&1 || return 1
    if type -P timeout >/dev/null; then
        timeout 2 banditshell "$@" 2>/dev/null
    else
        banditshell "$@" 2>/dev/null
    fi
}

_bs_config_keys() {
    local config=${XDG_CONFIG_HOME:-$HOME/.config}/banditshell/config.json
    [[ -r $config ]] && type -P jq >/dev/null || return 1
    jq -r 'paths(type != "object") | select(all(type == "string")) | join(".")' "$config" 2>/dev/null
}

_bs_desktop_ids() {
    local dir file
    local -a dirs
    IFS=: read -ra dirs <<<"${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${dirs[@]}"; do
        for file in "$dir"/applications/*.desktop; do
            [[ -e $file ]] || continue
            file=${file##*/}
            printf '%s\n' "${file%.desktop}"
        done
    done
}

_bs_places() {
    local root=${TZDIR:-/usr/share/zoneinfo}
    [[ -d $root ]] || return 1
    (cd "$root" && find . -mindepth 2 -type f | sed 's|^\./||')
}

_bs_add() {
    local cur=$1
    shift
    (( $# )) || return 0
    mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -W "$*" -- "$cur")
}

_bs_offer() {
    local cur=$2
    local -a values=()
    case $1 in
    panel) mapfile -t values < <(_bs_live panel); values+=("${_bs_panel[@]}") ;;
    menu) mapfile -t values < <(_bs_live dev menu list) ;;
    theme) mapfile -t values < <(_bs_live config theme list); values+=("${_bs_theme[@]}") ;;
    page) values=("${_bs_page[@]}") ;;
    command) values=("${_bs_verbs[@]}") ;;
    layer) values=("${_bs_layer[@]}") ;;
    package) values=("${_bs_package[@]}") ;;
    id) values=("${_bs_id[@]}") ;;
    rule) values=("${_bs_lintrule[@]}") ;;
    screen) mapfile -t values < <(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}') ;;
    key) mapfile -t values < <(_bs_config_keys) ;;
    app) mapfile -t values < <(_bs_desktop_ids) ;;
    place) mapfile -t values < <(_bs_places) ;;
    index) mapfile -t values < <(_bs_live panel clipboard list | awk -F'\t' 'NF >= 1 {print $1}') ;;
    worktree) mapfile -t values < <(banditshell dev worktrees 2>/dev/null) ;;
    file)
        compopt -o filenames 2>/dev/null
        mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -f -- "$cur")
        return
        ;;
    dir)
        compopt -o filenames 2>/dev/null
        mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -d -- "$cur")
        return
        ;;
    esac
    _bs_add "$cur" "${values[@]}"
}

_banditshell() {
    local cur cword
    local -a words
    if declare -F _get_comp_words_by_ref >/dev/null; then
        _get_comp_words_by_ref -n =: cur words cword
    else
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
        cur=${COMP_WORDS[COMP_CWORD]}
    fi
    COMPREPLY=()

    if [[ -z ${_bs_reloading:-} ]] && { _bs_stale && "$_bs_repo/scripts/bash-completion.sh" install --quiet 2>/dev/null || _bs_moved; }; then
        _bs_reloading=1
        # shellcheck disable=SC1090
        source "$_bs_file"
        unset _bs_reloading
        _banditshell "$@"
        return
    fi

    if (( cword == 1 )); then
        _bs_add "$cur" "${_bs_verbs[@]}"
        return
    fi

    local target=$(( cword - 1 )) rule word item i n score ok best=-1 literal wild exact=0
    local -a parts items flags holes offers=() literals=()
    local -A seen=()
    for rule in "${_bs_rules[@]}"; do
        read -ra parts <<<"$rule"
        [[ ${parts[-1]} == --* ]] && unset 'parts[-1]'
        (( ${#parts[@]} == target )) || continue
        ok=1
        for (( i = 0; i < target; i++ )); do
            IFS=, read -ra items <<<"${parts[i]}"
            literal=0
            for item in "${items[@]}"; do
                [[ $item == "${words[i + 1]}" ]] && literal=1
            done
            (( literal )) || { ok=0; break; }
        done
        (( ok )) && { exact=1; break; }
    done
    for rule in "${_bs_rules[@]}"; do
        read -ra parts <<<"$rule"
        flags=()
        if [[ ${parts[-1]} == --* ]]; then
            IFS=, read -ra flags <<<"${parts[-1]}"
            unset 'parts[-1]'
        fi
        n=${#parts[@]}
        score=0
        ok=1
        for (( i = 0; i < target && i < n; i++ )); do
            IFS=, read -ra items <<<"${parts[i]}"
            word=${words[i + 1]}
            literal=0
            wild=0
            for item in "${items[@]}"; do
                if [[ $item == @* || $item == '*' ]]; then
                    wild=1
                elif [[ $item == "$word" ]]; then
                    literal=1
                fi
            done
            if (( literal )); then
                score=$(( score + 1 ))
            elif (( ! wild )); then
                ok=0
                break
            fi
        done
        (( ok )) || continue
        (( exact && score < target )) && continue
        if (( target < n )); then
            IFS=, read -ra items <<<"${parts[target]}"
        elif (( ${#flags[@]} )) && [[ ${words[cword - 1]} != --* ]]; then
            items=("${flags[@]}")
        else
            continue
        fi
        holes=()
        for item in "${items[@]}"; do
            case $item in
            '*') ;;
            @*) holes+=("$item") ;;
            *) literals+=("$item") ;;
            esac
        done
        (( ${#holes[@]} )) || continue
        if (( score > best )); then
            best=$score
            offers=()
        fi
        (( score == best )) && offers+=("${holes[@]}")
    done

    for item in "${offers[@]}"; do
        [[ -n ${seen[$item]:-} ]] && continue
        seen[$item]=1
        _bs_offer "${item#@}" "$cur"
    done
    _bs_add "$cur" "${literals[@]}"
    (( ${#COMPREPLY[@]} > 1 )) && mapfile -t COMPREPLY < <(printf '%s\n' "${COMPREPLY[@]}" | awk '!seen[$0]++')
    return 0
}

complete -F _banditshell banditshell
EOF
}

current() {
    [ -f "$TARGET" ] || return 1
    local dep
    while IFS= read -r dep; do
        [ -e "$dep" ] || continue
        [ "$dep" -nt "$TARGET" ] && return 1
    done < <(deps)
    return 0
}

do_install() {
    local tmp
    mkdir -p "$COMPDIR" || { say "cannot create $COMPDIR"; return 1; }
    tmp="$(mktemp "$COMPDIR/.banditshell.XXXXXX")" || return 1
    if ! generate >"$tmp"; then
        rm -f "$tmp"
        say "could not build the completion from $REPO/cli/banditshell"
        return 1
    fi
    chmod 644 "$tmp"
    mv "$tmp" "$TARGET" || { rm -f "$tmp"; return 1; }
    say "  bash  $TARGET"
    say "        a running bash keeps the old one until: exec bash"
    return 0
}

do_status() {
    if [ ! -f "$TARGET" ]; then
        say "  bash  not set up (run: banditshell completions install)"
        return 2
    fi
    if current; then
        say "  bash  $TARGET, current"
        return 0
    fi
    say "  bash  $TARGET, out of date (the next Tab rebuilds it)"
    return 1
}

do_remove() {
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET"
        say "  bash  removed $TARGET"
    else
        say "  bash  nothing to remove"
    fi
    return 0
}

action="${1:-status}"
shift 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
    --quiet | -q) QUIET=1 ;;
    *) echo "bash-completion.sh: unknown option: $arg" >&2; exit 2 ;;
    esac
done

case "$action" in
print) generate ;;
install) do_install ;;
status) do_status ;;
remove) do_remove ;;
where) printf '%s\n' "$TARGET" ;;
-h | --help | help) usage ;;
*) usage >&2; exit 2 ;;
esac
