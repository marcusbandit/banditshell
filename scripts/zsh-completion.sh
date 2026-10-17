#!/usr/bin/env bash
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
RULES="$REPO/scripts/completion-rules.sh"
COMPDIR="${BANDITSHELL_ZSH_COMPDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}"
TARGET="$COMPDIR/_banditshell"
QUIET=0

usage() {
    cat <<EOF
usage: zsh-completion.sh install|print|status|remove|where [--quiet]

  install   write $TARGET
  print     write the completion to stdout
  status    exit 0 when current, 1 when stale, 2 when not set up
  remove    delete it
  where     print where it lives

The completion is generated from the header of cli/banditshell through
scripts/completion-rules.sh, the same table bash-completion.sh reads.
EOF
}

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

short() {
    local text="$1"
    if [ "${#text}" -gt 60 ]; then
        text="${text:0:57}"
        text="${text% *}..."
    fi
    printf '%s' "$text"
}

deps() {
    printf '%s\n' "$REPO/cli/banditshell" "$RULES" "$SELF" \
        "$REPO/config/Themes.qml" "$REPO/modules/settings/catalogue.js" "$REPO/modules/keyboard/Layouts.qml" \
        "$REPO/packages" "$REPO"/modules/*/module.json
}

generate() {
    local table kind name text verbs="" rules="" panel="" theme="" page="" layer="" package=""
    table="$("$RULES")" || return 1
    while IFS=$'\t' read -r kind name text; do
        case "$kind" in
        verb) verbs+="    $(quote "$name:$(short "$text")")"$'\n' ;;
        rule) rules+="    $(quote "$name")"$'\n' ;;
        values)
            case "$name" in
            panel) panel="$text" ;;
            theme) theme="$text" ;;
            page) page="$text" ;;
            layer) layer="$text" ;;
            package) package="$text" ;;
            esac
            ;;
        esac
    done <<<"$table"

    cat <<EOF
#compdef banditshell
typeset -g _bs_built=$EPOCHREALTIME
typeset -ga _bs_verbs _bs_rules _bs_panel _bs_theme _bs_page _bs_layer _bs_package
typeset -g _bs_file=$(quote "$TARGET")

_bs_verbs=(
$verbs)

_bs_rules=(
$rules)

_bs_panel=( $panel )
_bs_theme=( $theme )
_bs_page=( $page )
_bs_layer=( $layer )
_bs_package=( $package )
EOF
    cat <<'EOF'

_bs_repo() {
    local cli=${commands[banditshell]:A}
    [[ -n $cli ]] || return 1
    REPLY=${cli:h:h}
}

_bs_stale() {
    _bs_repo || return 1
    [[ -x $REPLY/scripts/completion-rules.sh && -x $REPLY/scripts/zsh-completion.sh ]] || return 1
    local dep
    for dep in $REPLY/cli/banditshell $REPLY/scripts/completion-rules.sh $REPLY/scripts/zsh-completion.sh \
        $REPLY/config/Themes.qml $REPLY/modules/settings/catalogue.js $REPLY/modules/keyboard/Layouts.qml \
        $REPLY/packages $REPLY/modules/*/module.json(N); do
        [[ $dep -nt $_bs_file ]] && return 0
    done
    return 1
}

_bs_moved() {
    local compdef built
    { read -r compdef; read -r built } 2>/dev/null <$_bs_file || return 1
    [[ ${built#*=} != "$_bs_built" ]]
}

_bs_live() {
    (( $+commands[banditshell] )) || return 1
    pgrep -x qs >/dev/null 2>&1 || return 1
    if (( $+commands[timeout] )); then
        timeout 2 banditshell "$@" 2>/dev/null
    else
        banditshell "$@" 2>/dev/null
    fi
}

_bs_config_keys() {
    local config=${XDG_CONFIG_HOME:-$HOME/.config}/banditshell/config.json
    [[ -r $config ]] && (( $+commands[jq] )) || return 1
    jq -r 'paths(type != "object") | select(all(type == "string")) | join(".")' $config 2>/dev/null
}

_bs_desktop_ids() {
    local dir file
    for dir in ${XDG_DATA_HOME:-$HOME/.local/share}/applications ${(s.:.)${XDG_DATA_DIRS:-/usr/local/share:/usr/share}}/applications; do
        for file in $dir/*.desktop(N); do
            print -r -- ${${file:t}%.desktop}
        done
    done
}

_bs_places() {
    local root=/usr/share/zoneinfo file
    [[ -d $root ]] || return 1
    for file in $root/*/**/*(N.); do
        print -r -- ${file#$root/}
    done
}

_bs_offer() {
    local -a values
    case $1 in
    panel) values=( $_bs_panel ${(f)"$(_bs_live panel)"} ) ;;
    menu) values=( ${(f)"$(_bs_live dev menu list)"} ) ;;
    theme) values=( $_bs_theme ${(f)"$(_bs_live config theme list)"} ) ;;
    page) values=( $_bs_page ) ;;
    command) values=( ${_bs_verbs%%:*} ) ;;
    layer) values=( $_bs_layer ) ;;
    package) values=( $_bs_package ) ;;
    screen) values=( ${(f)"$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')"} ) ;;
    key) values=( ${(f)"$(_bs_config_keys)"} ) ;;
    app) values=( ${(f)"$(_bs_desktop_ids)"} ) ;;
    place) values=( ${(f)"$(_bs_places)"} ) ;;
    worktree) values=( ${(f)"$(banditshell dev worktrees 2>/dev/null)"} ) ;;
    index)
        values=( ${(f)"$(_bs_live panel clipboard list | awk -F'\t' 'NF >= 4 {print $1 ":" $3 " " $4}')"} )
        (( $#values )) && _describe -t entries 'clipboard entry' values
        return
        ;;
    file) _files; return ;;
    dir) _files -/; return ;;
    esac
    values=( ${(u)values:#} )
    (( $#values )) && compadd -a values
}

_banditshell() {
    if [[ -z $_bs_reloading ]] && { _bs_stale && $REPLY/scripts/zsh-completion.sh install --quiet 2>/dev/null || _bs_moved }; then
        typeset -g _bs_reloading=1
        source $_bs_file
        unset _bs_reloading
        _banditshell "$@"
        return
    fi

    if (( CURRENT == 2 )); then
        _describe -t commands 'banditshell command' _bs_verbs
        return
    fi

    local target=$(( CURRENT - 1 )) rule word i n score ok best=-1 exact=0
    local -a typed parts items flags offers literals
    typed=( "${(@)words[2,CURRENT-1]}" )
    for rule in $_bs_rules; do
        parts=( ${(s: :)rule} )
        [[ $parts[-1] == --* ]] && parts[-1]=()
        (( $#parts == target - 1 )) || continue
        ok=1
        for (( i = 1; i < target; i++ )); do
            items=( ${(s:,:)parts[i]} )
            (( ${items[(Ie)$typed[i]]} )) || { ok=0; break }
        done
        (( ok )) && { exact=1; break }
    done
    for rule in $_bs_rules; do
        parts=( ${(s: :)rule} )
        flags=()
        if [[ $parts[-1] == --* ]]; then
            flags=( ${(s:,:)parts[-1]} )
            parts[-1]=()
        fi
        n=$#parts
        score=0
        ok=1
        for (( i = 1; i < target && i <= n; i++ )); do
            items=( ${(s:,:)parts[i]} )
            word=$typed[i]
            if (( ${items[(Ie)$word]} )); then
                score=$(( score + 1 ))
            elif (( ! ${#${(M)items:#(@*|\*)}} )); then
                ok=0
                break
            fi
        done
        (( ok )) || continue
        (( exact && score < target - 1 )) && continue
        if (( target <= n )); then
            items=( ${(s:,:)parts[target]} )
        elif (( $#flags )) && [[ $typed[-1] != --* ]]; then
            items=( $flags )
        else
            continue
        fi
        literals+=( ${items:#(@*|\*)} )
        items=( ${(M)items:#@*} )
        (( $#items )) || continue
        if (( score > best )); then
            best=$score
            offers=()
        fi
        (( score == best )) && offers+=( $items )
    done

    literals=( ${(u)literals} )
    (( $#literals )) && compadd -a literals
    for word in ${(u)offers}; do
        _bs_offer ${word#@}
    done
}

if [[ -n $_bs_reloading ]]; then
    :
elif [[ $funcstack[1] = _banditshell ]]; then
    _banditshell "$@"
else
    compdef _banditshell banditshell
fi
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
    local fresh=0 tmp
    [ -e "$TARGET" ] || fresh=1
    mkdir -p "$COMPDIR" || { say "cannot create $COMPDIR"; return 1; }
    tmp="$(mktemp "$COMPDIR/.banditshell.XXXXXX")" || return 1
    if ! generate >"$tmp"; then
        rm -f "$tmp"
        say "could not build the completion from $REPO/cli/banditshell"
        return 1
    fi
    chmod 644 "$tmp"
    mv "$tmp" "$TARGET" || { rm -f "$tmp"; return 1; }
    say "  zsh   $TARGET"
    if [ "$fresh" -eq 1 ]; then
        say "        new to fpath; if a fresh zsh does not complete it: rm -f ~/.zcompdump*; exec zsh"
    else
        say "        a running zsh keeps the old one until: exec zsh"
    fi
    return 0
}

do_status() {
    if [ ! -f "$TARGET" ]; then
        say "  zsh   not set up (run: banditshell completions install)"
        return 2
    fi
    if current; then
        say "  zsh   $TARGET, current"
        return 0
    fi
    say "  zsh   $TARGET, out of date (the next Tab rebuilds it)"
    return 1
}

do_remove() {
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET"
        say "  zsh   removed $TARGET"
    else
        say "  zsh   nothing to remove"
    fi
    return 0
}

action="${1:-status}"
shift 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
    --quiet | -q) QUIET=1 ;;
    *) echo "zsh-completion.sh: unknown option: $arg" >&2; exit 2 ;;
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
