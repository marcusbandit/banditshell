#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CLI="$REPO/bin/banditshell"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

DESC_COL=31

if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_USER="$(id -un)"
    TARGET_HOME="${HOME:-}"
fi
[ -n "$TARGET_HOME" ] || TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"

COMPDIR="${BANDITSHELL_ZSH_COMPDIR:-${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/zsh/site-functions}"
TARGET="$COMPDIR/_banditshell"

ZDOT="${ZDOTDIR:-$TARGET_HOME}"
ZSHRC="$ZDOT/.zshrc"
DROPIN_DIR="$ZDOT/.zshrc.d"
DROPIN="$DROPIN_DIR/banditshell-completion.sh"

BEGIN_MARK="# >>> banditshell completions >>>"
END_MARK="# <<< banditshell completions <<<"

QUIET=0
NO_RC=0

header() { awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$CLI"; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

split_alts() {
    local s="$1" depth=0 cur="" i ch
    for ((i = 0; i < ${#s}; i++)); do
        ch="${s:i:1}"
        case "$ch" in
        '<' | '[') depth=$((depth + 1)); cur+="$ch" ;;
        '>' | ']') depth=$((depth - 1)); cur+="$ch" ;;
        '|')
            if [ "$depth" -eq 0 ]; then
                printf '%s\n' "$cur"
                cur=""
            else
                cur+="$ch"
            fi
            ;;
        *) cur+="$ch" ;;
        esac
    done
    printf '%s\n' "$cur"
}

placeholders() {
    local s="$1" i ch depth=0 cur=""
    for ((i = 0; i < ${#s}; i++)); do
        ch="${s:i:1}"
        case "$ch" in
        '<' | '[')
            [ "$depth" -eq 0 ] && cur=""
            depth=$((depth + 1))
            cur+="$ch"
            ;;
        '>' | ']')
            depth=$((depth - 1))
            cur+="$ch"
            [ "$depth" -le 0 ] && { printf '%s\n' "$cur"; cur=""; depth=0; }
            ;;
        *) [ "$depth" -gt 0 ] && cur+="$ch" ;;
        esac
    done
}

CMD_NAME=()
CMD_SPEC=()
CMD_DESC=()

read_header() {
    local line stripped indent head tailtext spec desc first rest name
    local cur_spec="" cur_desc="" open=0

    flush() {
        [ "$open" -eq 1 ] || return 0
        open=0
        local s="$cur_spec"
        first="${s%% *}"
        rest="$(trim "${s#"$first"}")"
        local n
        while IFS= read -r n; do
            n="$(trim "$n")"
            [ -n "$n" ] || continue
            CMD_NAME+=("$n")
            CMD_SPEC+=("$rest")
            CMD_DESC+=("$(trim "$cur_desc")")
        done < <(split_alts "$first")
        cur_spec=""
        cur_desc=""
    }

    while IFS= read -r line; do
        if [[ $line == "  banditshell "* ]]; then
            flush
            open=1
            if [ "${#line}" -gt "$DESC_COL" ] && [ "${line:$((DESC_COL - 2)):2}" = "  " ]; then
                head="${line:0:$DESC_COL}"
                tailtext="${line:$DESC_COL}"
            else
                head="$line"
                tailtext=""
            fi
            cur_spec="$(trim "${head#  banditshell }")"
            cur_desc="$(trim "$tailtext")"
            continue
        fi

        stripped="$(trim "$line")"
        if [ -z "$stripped" ]; then
            flush
            continue
        fi
        [ "$open" -eq 1 ] || continue

        indent=$((${#line} - ${#stripped}))
        if [ "$indent" -ge "$DESC_COL" ]; then
            [ -n "$cur_desc" ] || cur_desc="$stripped"
        elif [ "$indent" -gt 0 ]; then
            cur_spec="$cur_spec|$stripped"
        fi
    done < <(header)

    flush
}

value_source() {
    local cmd="$1" sub="$2" ph="$3"
    local key
    for key in "$cmd:$sub:$ph" "$cmd:$ph" "*:$ph"; do
        case "$key" in
        'menu::<key>' | 'menu:open:<key>' | 'menu:toggle:<key>' | 'demo:<key>') echo menukeys; return ;;
        'settings:page:<key>' | 'settings:open:[page]' | 'settings:[page]') echo setpages; return ;;
        'get:<key>' | 'set:<key>') echo confkeys; return ;;
        'theme:[name]') echo themes; return ;;
        'keyboard:page:<name>') echo kbpages; return ;;
        'launcher:run:<id>') echo desktopids; return ;;
        'zone:add:<place>' | 'zone:find:<text>') echo zoneinfo; return ;;
        'zone:remove:<place>') echo zones; return ;;
        'clipboard:use:<n>' | 'clipboard:pin:<n>' | 'clipboard:remove:<n>') echo clipindex; return ;;
        '*:[screen]') echo screens; return ;;
        '*:[file]' | '*:<file>') echo files; return ;;
        esac
    done
    echo ""
}

bake_themes() { sed -n 's/^\s*readonly property Theme \([A-Za-z0-9_]*\):.*/\1/p' "$REPO/config/Themes.qml"; }

bake_setpages() {
    local f b
    for f in "$REPO"/modules/settings/pages/*Page.qml; do
        [ -e "$f" ] || continue
        b="$(basename "$f" Page.qml)"
        printf '%s\n' "$(printf '%s' "${b:0:1}" | tr 'A-Z' 'a-z')${b:1}"
    done
}

bake_kbpages() { sed -n 's/^ \{12\}\([a-zA-Z]*\): \[$/\1/p' "$REPO/modules/keyboard/Layouts.qml"; }

zq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

zarray() {
    local w out=""
    while IFS= read -r w; do
        [ -n "$w" ] || continue
        out="$out $(zq "$w")"
    done
    printf '%s' "${out# }"
}

generate() {
    read_header

    local i cmd spec desc alt word args ph
    local out_cmds="" out_subcase="" out_argcase=""

    for i in "${!CMD_NAME[@]}"; do
        cmd="${CMD_NAME[$i]}"
        spec="${CMD_SPEC[$i]}"
        desc="${CMD_DESC[$i]}"

        [ -n "$desc" ] || desc="$spec"
        [ "${#desc}" -gt 64 ] && desc="$(trim "${desc:0:61}")..."
        [ -n "$desc" ] && desc=":$desc"
        out_cmds="$out_cmds    $(zq "$cmd$desc")"$'\n'

        local subs="" argmap="" slots=""
        while IFS= read -r alt; do
            alt="$(trim "$alt")"
            [ -n "$alt" ] || continue
            word="${alt%% *}"
            args="$(trim "${alt#"$word"}")"
            if [[ $word =~ ^[a-z][a-z0-9-]*$ ]]; then
                subs="$subs $(zq "$word${args:+:$args}")"
                slots="$(slot_lines "$cmd" "$word" "$args")"
            else
                slots="$(slot_lines "$cmd" "" "$alt")"
            fi
            [ -n "$slots" ] && argmap="$argmap$slots"$'\n'
        done < <(split_alts "$spec")

        [ -n "$subs" ] && out_subcase="$out_subcase    $cmd) subs=(${subs# }) ;;"$'\n'
        [ -n "$argmap" ] && out_argcase="$out_argcase$argmap"
    done

    emit_file "$out_cmds" "$out_subcase" "$out_argcase"
}

slot_lines() {
    local ln out=""
    while IFS= read -r ln; do
        [ -n "$(trim "$ln")" ] && out="$out$ln"$'\n'
    done < <(arg_slots "$1" "$2" "$3")
    printf '%s' "$out"
}

arg_slots() {
    local cmd="$1" sub="$2" args="$3"
    [ -n "$args" ] || return 0

    local slot=0 tok src lits flags="" out=""
    local ph
    while IFS= read -r ph; do
        [ -n "$ph" ] || continue

        if [[ $ph == *--* ]]; then
            for tok in $(printf '%s' "$ph" | grep -o -- '--[a-z][a-z-]*'); do
                flags="$flags $tok"
            done
            continue
        fi

        slot=$((slot + 1))
        local inner="${ph:1:${#ph}-2}"
        if [[ $inner == *"|"* ]]; then
            lits=""
            while IFS= read -r tok; do
                tok="$(trim "$tok")"
                [ -n "$tok" ] && lits="$lits $tok"
            done < <(split_alts "$inner")
            out="$out    $(zq "$cmd $sub $slot") $(zq "literal$lits")"$'\n'
            continue
        fi

        src="$(value_source "$cmd" "$sub" "$ph")"
        [ -n "$src" ] && out="$out    $(zq "$cmd $sub $slot") $(zq "$src")"$'\n'
    done < <(placeholders "$args")

    [ -n "$flags" ] && out="$out    $(zq "$cmd $sub flags") $(zq "literal$flags")"$'\n'
    printf '%s' "$out"
}

deps() {
    printf '%s\n' "$CLI" "$SELF" \
        "$REPO/config/Themes.qml" \
        "$REPO/modules/settings/pages" \
        "$REPO/modules/keyboard/Layouts.qml"
}

emit_file() {
    local cmds="$1" subcase="$2" argcase="$3"

    cat <<EOF

_bs_cli=$(zq "$CLI")
_bs_self=$(zq "$TARGET")
_bs_gen=$(zq "$SELF")
_bs_deps=($(deps | zarray))

_bs_themes=($(bake_themes | zarray))
_bs_setpages=($(bake_setpages | zarray))
_bs_kbpages=($(bake_kbpages | zarray))

_bs_commands=(
$cmds)

typeset -gA _bs_args
_bs_args=(
$argcase)

_bs_ipc() {
    pgrep -x qs >/dev/null 2>&1 || return 1
    local -a lines
    if (( \$+commands[timeout] )); then
        lines=( \${(f)"\$(timeout 2 \$_bs_cli "\$@" 2>/dev/null)"} )
    else
        lines=( \${(f)"\$(\$_bs_cli "\$@" 2>/dev/null)"} )
    fi
    (( \$#lines )) || return 1
    print -rl -- \$lines
}

_bs_source() {
    local kind=\$1
    local -a vals
    case \$kind in
    themes)
        vals=( \${(f)"\$(_bs_ipc themes)"} )
        (( \$#vals )) || vals=( \$_bs_themes )
        _describe -t themes 'theme' vals
        ;;
    menukeys)
        vals=( \${(f)"\$(_bs_ipc menu list)"} )
        (( \$#vals )) && _describe -t menus 'menu' vals
        ;;
    setpages)  _describe -t pages 'page' _bs_setpages ;;
    kbpages)   _describe -t pages 'layer' _bs_kbpages ;;
    confkeys)
        vals=( \${(f)"\$(_bs_confkeys_live)"} )
        (( \$#vals )) && _describe -t settings 'setting' vals
        ;;
    screens)
        vals=( \${(f)"\$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print \$2}')"} )
        (( \$#vals )) && _describe -t screens 'screen' vals
        ;;
    desktopids)
        vals=( \${(f)"\$(_bs_desktop_ids)"} )
        (( \$#vals )) && _describe -t applications 'application' vals
        ;;
    zoneinfo)
        vals=( \${(f)"\$(_bs_zoneinfo)"} )
        (( \$#vals )) && compadd -a vals
        ;;
    zones)
        vals=( \${(f)"\$(_bs_ipc zone list | sed -n 's/.*(\\([A-Za-z_]*\\/[A-Za-z_+-]*\\)).*/\\1/p')"} )
        (( \$#vals )) && compadd -a vals
        ;;
    clipindex)
        vals=( \${(f)"\$(_bs_ipc clipboard list | awk -F'\t' 'NF>=4 {print \$1 ":" \$3 " " \$4}')"} )
        (( \$#vals )) && _describe -t entries 'entry' vals
        ;;
    files) _files ;;
    literal) _describe -t values 'value' _bs_literals ;;
    esac
}

_bs_confkeys_live() {
    local cfg=\${XDG_CONFIG_HOME:-\$HOME/.config}/banditshell/config.json
    [[ -r \$cfg ]] || return 1
    (( \$+commands[python3] )) || return 1
    python3 -c '
import json, sys
def walk(o, p=""):
    if isinstance(o, dict) and o:
        for k, v in o.items():
            yield from walk(v, p + k + ".")
    else:
        yield p[:-1]
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
print("\n".join(k for k in walk(d) if k))
' \$cfg 2>/dev/null
}

_bs_desktop_ids() {
    local -a dirs
    dirs=( \${XDG_DATA_HOME:-\$HOME/.local/share}/applications \${(s.:.)\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}}/applications )
    local d f
    for d in \$dirs; do
        [[ -d \$d ]] || continue
        for f in \$d/*.desktop(N); do
            print -r -- \${\${f:t}%.desktop}
        done
    done
}

_bs_zoneinfo() {
    local root=/usr/share/zoneinfo
    [[ -d \$root ]] || return 1
    local f
    for f in \$root/*/**/*(N.) \$root/*/*(N.); do
        print -r -- \${f#\$root/}
    done | sort -u
}

_banditshell() {
    if [[ -z \$_bs_refreshing ]]; then
        local dep stale=0
        for dep in \$_bs_deps; do
            [[ -e \$dep && \$dep -nt \$_bs_self ]] && { stale=1; break }
        done
        if (( stale )) && [[ -w \$_bs_self || -w \${_bs_self:h} ]]; then
            if command \$_bs_gen install --quiet --no-rc 2>/dev/null; then
                local _bs_refreshing=1
                unfunction _banditshell 2>/dev/null
                source \$_bs_self
                _banditshell "\$@"
                return
            fi
        fi
    fi

    if (( CURRENT == 2 )); then
        _describe -t commands 'banditshell' _bs_commands
        return
    fi

    local cmd=\$words[2] sub=""
    local -a subs _bs_literals
    case \$cmd in
$subcase    esac

    if (( CURRENT == 3 )) && (( \$#subs )); then
        _describe -t alternatives "\$cmd" subs
        return
    fi

    local slot
    if (( \$#subs )); then
        sub=\$words[3]
        slot=\$(( CURRENT - 3 ))
    else
        slot=\$(( CURRENT - 2 ))
    fi
    (( slot >= 1 )) || return

    local -a spec
    spec=( \${(z)_bs_args[\$cmd \$sub flags]} )
    if (( \$#spec )) && [[ \$words[CURRENT] == -* ]]; then
        _bs_literals=( \${spec[2,-1]} )
        _bs_source literal
        return
    fi

    spec=( \${(z)_bs_args[\$cmd \$sub \$slot]} )
    (( \$#spec )) || return
    _bs_literals=( \${spec[2,-1]} )
    _bs_source \${spec[1]}
}

if [[ \$funcstack[1] = _banditshell ]]; then
    _banditshell "\$@"
else
    compdef _banditshell banditshell
fi
EOF
}

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

user_own() {
    [ "$(id -u)" -eq 0 ] || return 0
    [ -n "${SUDO_USER:-}" ] || return 0
    chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")" "$@" 2>/dev/null || true
}

hook_body() {
    cat <<EOF
$BEGIN_MARK
[[ -n \${fpath[(r)$COMPDIR]} ]] || fpath=($COMPDIR \$fpath)
if (( \$+functions[compdef] )); then
    autoload -Uz _banditshell 2>/dev/null && compdef _banditshell banditshell
else
    autoload -Uz compinit && compinit
fi
$END_MARK
EOF
}

hook_path() {
    if [ -d "$DROPIN_DIR" ] && [ -f "$ZSHRC" ] && grep -q 'zshrc\.d' "$ZSHRC" 2>/dev/null; then
        printf '%s' "$DROPIN"
    else
        printf '%s' "$ZSHRC"
    fi
}

hook_present() {
    local f
    f="$(hook_path)"
    [ -f "$f" ] && grep -qF "$BEGIN_MARK" "$f"
}

strip_hook() {
    local f="$1"
    [ -f "$f" ] || return 0
    grep -qF "$BEGIN_MARK" "$f" || return 0
    local tmp
    tmp="$(mktemp)" || return 1
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { skip = 1 }
        !skip { print }
        $0 == e { skip = 0 }
    ' "$f" >"$tmp" && cat "$tmp" >"$f"
    rm -f "$tmp"
}

write_hook() {
    local f
    f="$(hook_path)"
    if [ "$f" = "$DROPIN" ]; then
        hook_body >"$f" || return 1
        user_own "$f"
        say "  fpath      $f"
        return 0
    fi

    [ -f "$f" ] || : >"$f"
    strip_hook "$f"
    [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && printf '\n' >>"$f"
    hook_body >>"$f" || return 1
    user_own "$f"
    say "  fpath      $f (a guarded block at the end)"
}

drop_dump() {
    local d
    for d in "$ZDOT"/.zcompdump*; do
        [ -e "$d" ] && rm -f "$d"
    done
    return 0
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
    mkdir -p "$COMPDIR" || { say "cannot create $COMPDIR"; return 1; }
    local tmp
    tmp="$(mktemp)" || return 1
    if ! generate >"$tmp"; then
        rm -f "$tmp"
        say "could not build the completion from $CLI"
        return 1
    fi
    mv "$tmp" "$TARGET" || { rm -f "$tmp"; return 1; }
    chmod 644 "$TARGET"
    user_own "$COMPDIR"

    say "  completion $TARGET"
    if [ "$NO_RC" -eq 0 ]; then
        write_hook
        drop_dump
    fi
    return 0
}

do_status() {
    if [ ! -f "$TARGET" ]; then
        say "not set up"
        say "  run: banditshell completions install"
        return 2
    fi
    say "  completion $TARGET"
    if hook_present; then
        say "  fpath      $(hook_path)"
    elif [ "$NO_RC" -eq 0 ]; then
        say "  fpath      not wired; zsh may not find it"
    fi
    if current; then
        say "  state      current"
        return 0
    fi
    say "  state      out of date (the next Tab rebuilds it)"
    return 1
}

do_remove() {
    local gone=0
    [ -f "$TARGET" ] && { rm -f "$TARGET"; say "  removed    $TARGET"; gone=1; }
    if hook_present; then
        local f
        f="$(hook_path)"
        if [ "$f" = "$DROPIN" ]; then
            rm -f "$f"
            say "  removed    $f"
        else
            strip_hook "$f"
            say "  removed    the fpath block in $f"
        fi
        gone=1
    fi
    drop_dump
    [ "$gone" -eq 1 ] || say "nothing to remove"
    return 0
}

action="${1:-status}"
shift 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
    --quiet | -q) QUIET=1 ;;
    --no-rc) NO_RC=1 ;;
    *) echo "zsh-completion.sh: unknown option: $arg" >&2; exit 2 ;;
    esac
done

case "$action" in
print | generate) generate ;;
install) do_install ;;
status) do_status ;;
remove | uninstall) do_remove ;;
where) printf '%s\n' "$TARGET" ;;
-h | --help | help)
    awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$SELF"
    ;;
*)
    echo "usage: zsh-completion.sh install|print|status|remove|where" >&2
    exit 2
    ;;
esac
