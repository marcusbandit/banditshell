#!/usr/bin/env bash
# Tab completion for banditshell, BUILT FROM THE CLI RATHER THAN BESIDE IT.
#
# The usual way to give a program completions is to write a second file that
# lists its verbs, and the usual thing that happens next is that the two drift:
# a verb gets added, renamed or removed, and the completion goes on offering the
# old set for as long as nobody notices. There is no way to notice. Completion
# is the one part of a CLI you never read.
#
# So there is no second list here. The verbs come out of the comment block at
# the top of bin/banditshell, which is the same block `banditshell help` prints,
# and the whole point is that it is ALREADY the register: it has to be right,
# because a person reads it. This file parses it and writes the zsh function
# from what it finds.
#
#   ./zsh-completion.sh print              write the completion to stdout
#   ./zsh-completion.sh install            put it where zsh looks, wire the fpath
#   ./zsh-completion.sh status             where it is, and whether it is current
#   ./zsh-completion.sh remove             take it and the fpath line back out
#   ./zsh-completion.sh where              print the path it installs to
#
#   --quiet   say nothing; the exit code is the answer.
#
# `status` answers in its EXIT CODE as well as its words, because the two callers
# that are not a person need three states rather than a paragraph:
#
#   0   installed, and built from the CLI as it stands now
#   1   installed, but older than something it was built from
#   2   not installed
#
# The installer's probe treats anything but 0 as work to do; the settings row
# draws all three differently.
#   --no-rc   install the file but do not touch any shell startup file.
#
# THE FORMAT IT READS is spelled out at the bottom of bin/banditshell's header
# and enforced loosely here: anything this cannot parse is skipped rather than
# guessed at, because a completion that offers nothing is a small annoyance and
# one that offers a verb that does not exist is a lie.
#
# STAYING CURRENT is the other half, and it does not go through this script. The
# generated function stats its own sources on every completion and rebuilds
# itself when any of them is newer, which costs a handful of stat calls on the
# first Tab of a session and nothing at all after that. A verb added to the CLI
# is therefore complete-able on the next Tab, with nothing run and nothing
# clicked. `install` and the settings row exist for the first time and for the
# case where the rebuild cannot write.

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CLI="$REPO/bin/banditshell"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

# The column the header's prose starts in. Everything left of it on a
# `banditshell ...` line is the spec; a continuation line indented to it is more
# prose, and one indented less than it is more spec. See the note under the
# header block in bin/banditshell.
DESC_COL=31

# WHOSE machine this is, which is not the same as who is running the script:
# install.sh may be under sudo, and a completion installed into root's home is a
# completion nobody will ever get.
#
# $HOME is believed whenever this is not root, and only then is the password
# database asked. That order matters both ways: under `sudo` $HOME is root's and
# the database is the only thing that knows better, and outside it $HOME is the
# session's own answer and overriding it with a database lookup would make this
# script the one thing on the machine that cannot be pointed somewhere else.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_USER="$(id -un)"
    TARGET_HOME="${HOME:-}"
fi
[ -n "$TARGET_HOME" ] || TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"

# Where the function goes. The user's own data directory rather than
# /usr/share/zsh/site-functions on purpose: it needs no root, it survives a
# package manager, and it is the one location that exists on every distribution
# because it is the one nothing else owns. $BANDITSHELL_ZSH_COMPDIR overrides it
# for anyone whose zsh is arranged differently.
COMPDIR="${BANDITSHELL_ZSH_COMPDIR:-${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/zsh/site-functions}"
TARGET="$COMPDIR/_banditshell"

# The zsh startup file, and its modular drop-in directory when there is one. A
# ~/.zshrc.d that .zshrc actually loops over is a strictly better place for this
# than the middle of somebody's .zshrc, so it is preferred when both the
# directory and the loop are there.
ZDOT="${ZDOTDIR:-$TARGET_HOME}"
ZSHRC="$ZDOT/.zshrc"
DROPIN_DIR="$ZDOT/.zshrc.d"
DROPIN="$DROPIN_DIR/banditshell-completion.sh"

BEGIN_MARK="# >>> banditshell completions >>>"
END_MARK="# <<< banditshell completions <<<"

QUIET=0
NO_RC=0

# --------------------------------------------------------------- the parse --

# The header block, exactly as `banditshell help` prints it.
header() { awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$CLI"; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Split on `|` at bracket depth zero, so the `|` inside `<closed|open>` and
# `[on|off]` stays where it belongs and only the ones separating alternatives
# are cuts. This is the whole reason those two are bracketed in the header.
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

# Every `<...>` and `[...]` in a spec, in the order they appear, taken whole so a
# bracketed alternation comes out as one token. A character walk rather than a
# regex: a POSIX bracket expression cannot hold a `]` anywhere but first, so the
# obvious pattern matches nothing and does it silently.
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

# One entry per verb, filled by read_header.
CMD_NAME=()
CMD_SPEC=()
CMD_DESC=()

# The header, turned into the three arrays above.
#
# A `banditshell ...` line opens an entry; a blank line closes it. While one is
# open, an indented line is either more spec or more prose, decided by whether
# it reaches the description column. Nothing else in the block is looked at,
# which is what lets the prose above and below the table say whatever it likes.
read_header() {
    local line stripped indent head tailtext spec desc first rest name
    local cur_spec="" cur_desc="" open=0

    flush() {
        [ "$open" -eq 1 ] || return 0
        open=0
        local s="$cur_spec"
        first="${s%% *}"
        rest="$(trim "${s#"$first"}")"
        # The one line whose FIRST token is an alternation: `start|stop|...` is
        # five verbs, not one verb with a strange name. They share whatever spec
        # and prose follow, which is the correct reading in every case the header
        # has ever had.
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
            # A description only exists when the spec stopped short of the
            # column and left a gap: a spec long enough to run past it (`menu`,
            # `notifications`) has no prose on its own line and must not be cut
            # in half looking for some.
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
            # Only the first line is kept: the rest of a paragraph is worth
            # reading in `banditshell help` and unreadable in a completion menu.
            [ -n "$cur_desc" ] || cur_desc="$stripped"
        elif [ "$indent" -gt 0 ]; then
            # Another ALTERNATIVE, not more of the last one. `alarm add` is on
            # its own line only because it is too long to sit on the first, and
            # a space here would graft it onto `remove <handle>`.
            cur_spec="$cur_spec|$stripped"
        fi
    done < <(header)

    flush
}

# ------------------------------------------------------------ what a value is --
#
# The one thing the header cannot tell anybody: `<key>` is a menu key under
# `menu`, a page under `settings` and a setting name under `set`, and no amount
# of parsing prose will separate those. So the STRUCTURE is derived and only the
# SOURCE of a value is named here, keyed most specific first:
#
#   verb:sub:<placeholder>   verb:<placeholder>   *:<placeholder>
#
# A placeholder with no entry completes nothing, which is the honest answer.
# `[on|off]` and friends need no entry at all: a bracketed alternation is its own
# list of candidates and is handled below.
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

# --------------------------------------------------------- baked-in lists --
#
# The lists that are facts about the CHECKOUT rather than about a running shell:
# they are read here, once, and written into the generated file. The function's
# own staleness check watches the files they came from, so editing Themes.qml or
# dropping a page into modules/settings/pages/ is enough to make the next Tab
# rebuild with it. That is the same bargain the rest of this makes: derived from
# the source of truth, refreshed by the source of truth changing.

bake_themes() { sed -n 's/^\s*readonly property Theme \([A-Za-z0-9_]*\):.*/\1/p' "$REPO/config/Themes.qml"; }

# A settings page IS its file: services/Settings.qml's own comment says adding a
# key there and dropping <Key>Page.qml in is the whole recipe, so the directory
# listing and the register cannot disagree.
bake_setpages() {
    local f b
    for f in "$REPO"/modules/settings/pages/*Page.qml; do
        [ -e "$f" ] || continue
        b="$(basename "$f" Page.qml)"
        printf '%s\n' "$(printf '%s' "${b:0:1}" | tr 'A-Z' 'a-z')${b:1}"
    done
}

bake_kbpages() { sed -n 's/^ \{12\}\([a-zA-Z]*\): \[$/\1/p' "$REPO/modules/keyboard/Layouts.qml"; }

# ------------------------------------------------------------- generation --

# zsh single-quoted literal: the only escape inside '' is '\'' .
zq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

# A list of words as a zsh array body.
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

        # A verb with no prose of its own describes itself with what it takes,
        # which for `menu` or `picker` is the more useful line anyway.
        [ -n "$desc" ] || desc="$spec"
        # Long enough to be worth reading in a list, short enough that the list
        # is still a list. `banditshell help` has the rest.
        [ "${#desc}" -gt 64 ] && desc="$(trim "${desc:0:61}")..."
        # No trailing colon when there is nothing after it: `_describe` draws an
        # empty description as a bare `--`, which is a column of punctuation
        # saying nothing. A plain value just lists itself.
        [ -n "$desc" ] && desc=":$desc"
        out_cmds="$out_cmds    $(zq "$cmd$desc")"$'\n'

        local subs="" argmap="" slots=""
        while IFS= read -r alt; do
            alt="$(trim "$alt")"
            [ -n "$alt" ] || continue
            word="${alt%% *}"
            args="$(trim "${alt#"$word"}")"
            if [[ $word =~ ^[a-z][a-z0-9-]*$ ]]; then
                # `_describe` cuts a `value:description` pair at the FIRST
                # colon, so only the value has to be colon-free; the hint after
                # it can say whatever the header said.
                subs="$subs $(zq "$word${args:+:$args}")"
                slots="$(slot_lines "$cmd" "$word" "$args")"
            else
                # No subcommand: the alternative is the verb's own arguments.
                slots="$(slot_lines "$cmd" "" "$alt")"
            fi
            [ -n "$slots" ] && argmap="$argmap$slots"$'\n' 
        done < <(split_alts "$spec")

        [ -n "$subs" ] && out_subcase="$out_subcase    $cmd) subs=(${subs# }) ;;"$'\n'
        [ -n "$argmap" ] && out_argcase="$out_argcase$argmap"
    done

    emit_file "$out_cmds" "$out_subcase" "$out_argcase"
}

# arg_slots, with the newline command substitution eats put back and blank lines
# dropped, so the generated table comes out one pair to a line.
slot_lines() {
    local ln out=""
    while IFS= read -r ln; do
        [ -n "$(trim "$ln")" ] && out="$out$ln"$'\n'
    done < <(arg_slots "$1" "$2" "$3")
    printf '%s' "$out"
}

# One line of the generated argument table per positional slot a verb takes:
#
#   'verb sub 1' 'source-or-literal-list'
#
# Positions come from the order the placeholders appear in the spec, which is the
# order they appear on the command line. Flags are collected separately and
# offered at every position, because a flag is not a position.
arg_slots() {
    local cmd="$1" sub="$2" args="$3"
    [ -n "$args" ] || return 0

    local slot=0 tok src lits flags="" out=""
    local ph
    while IFS= read -r ph; do
        [ -n "$ph" ] || continue

        # A flag and its value: `[--days <spec>]`. The flag is offered anywhere,
        # the value it takes is the shell's business, not ours.
        if [[ $ph == *--* ]]; then
            for tok in $(printf '%s' "$ph" | grep -o -- '--[a-z][a-z-]*'); do
                flags="$flags $tok"
            done
            continue
        fi

        slot=$((slot + 1))
        # A bracketed alternation IS the candidate list: `[on|off]`,
        # `<closed|open|toggle>`. Nothing needs to be looked up.
        local inner="${ph:1:${#ph}-2}"
        if [[ $inner == *"|"* ]]; then
            lits=""
            while IFS= read -r tok; do
                tok="$(trim "$tok")"
                [ -n "$tok" ] && lits="$lits $tok"
            done < <(split_alts "$inner")
            # ONE word, not a list. `_bs_args` is an associative array and its
            # body is read as key, value, key, value: a value spread over five
            # words would silently become two more keys and an odd one out. The
            # reader splits it back with ${(z)...}.
            out="$out    $(zq "$cmd $sub $slot") $(zq "literal$lits")"$'\n'
            continue
        fi

        src="$(value_source "$cmd" "$sub" "$ph")"
        [ -n "$src" ] && out="$out    $(zq "$cmd $sub $slot") $(zq "$src")"$'\n'
    done < <(placeholders "$args")

    [ -n "$flags" ] && out="$out    $(zq "$cmd $sub flags") $(zq "literal$flags")"$'\n'
    printf '%s' "$out"
}

# The files whose changing means the completion is out of date. Directories are
# in the list on purpose: a page added to modules/settings/pages/ changes that
# directory's mtime without changing any file already in it.
deps() {
    printf '%s\n' "$CLI" "$SELF" \
        "$REPO/config/Themes.qml" \
        "$REPO/modules/settings/pages" \
        "$REPO/modules/keyboard/Layouts.qml"
}

emit_file() {
    local cmds="$1" subcase="$2" argcase="$3"

    cat <<EOF
#compdef banditshell
# GENERATED. Do not edit: every verb below came out of the comment block at the
# top of $CLI, and this file rewrites itself from it.
#
# Regenerating is not something anyone has to remember. _banditshell stats the
# files listed in _bs_deps on its first run in a shell, and when any of them is
# newer than this file it rebuilds and re-sources itself before answering. So a
# verb added to the CLI is complete-able on the next Tab; nothing to run, nothing
# to click. \`banditshell completions install\` is for the first time and for the
# case where this file cannot be written (a read-only or root-owned install), and
# it says so rather than failing quietly.

_bs_cli=$(zq "$CLI")
_bs_self=$(zq "$TARGET")
_bs_gen=$(zq "$SELF")
_bs_deps=($(deps | zarray))

_bs_themes=($(bake_themes | zarray))
_bs_setpages=($(bake_setpages | zarray))
_bs_kbpages=($(bake_kbpages | zarray))

# The verbs, and what each one is for.
_bs_commands=(
$cmds)

# What a verb's alternatives are, and the argument each of them takes. Both come
# from the header; see the contract at the bottom of the CLI's own.
typeset -gA _bs_args
_bs_args=(
$argcase)

# ---------------------------------------------------------------- sources --
#
# Everything a value could be. The rule for all of them is the same: a
# completion may not block and may not fail loudly. A shell that is not running,
# a compositor that is not Hyprland and a missing python are all ordinary, and
# the answer to each is an empty list.

# Ask the RUNNING shell. Costs nothing when there is not one, which is the point
# of the pgrep: \`qs ipc call\` against a dead shell is not instant.
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
        # Only the running shell knows these: a menu key is registered by
        # whatever sidebar widget owns it, so there is no list on disk to read.
        vals=( \${(f)"\$(_bs_ipc menu list)"} )
        (( \$#vals )) && _describe -t menus 'menu' vals
        ;;
    setpages)  _describe -t pages 'page' _bs_setpages ;;
    kbpages)   _describe -t pages 'layer' _bs_kbpages ;;
    confkeys)
        # Read out of config.json rather than baked in: the shell writes every
        # default into it on first run, so the file is always the full register
        # and a setting added to config/Config.qml needs nothing done here.
        vals=( \${(f)"\$(_bs_confkeys_live)"} )
        (( \$#vals )) && _describe -t settings 'setting' vals
        ;;
    screens)
        # Hyprland's own answer, not the shell's: the monitor list is true
        # whether or not banditshell is up, and that is when you want it.
        vals=( \${(f)"\$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print \$2}')"} )
        (( \$#vals )) && _describe -t screens 'screen' vals
        ;;
    desktopids)
        vals=( \${(f)"\$(_bs_desktop_ids)"} )
        (( \$#vals )) && _describe -t applications 'application' vals
        ;;
    zoneinfo)
        # The tz database, which is what \`zone add\` takes. Region/City only:
        # the top-level files are legacy aliases and posix/ and right/ are the
        # same list twice over.
        vals=( \${(f)"\$(_bs_zoneinfo)"} )
        (( \$#vals )) && compadd -a vals
        ;;
    zones)
        # The places already added, which is what \`zone remove\` takes. The
        # panel prints a table; the id is in the last column, in brackets.
        vals=( \${(f)"\$(_bs_ipc zone list | sed -n 's/.*(\\([A-Za-z_]*\\/[A-Za-z_+-]*\\)).*/\\1/p')"} )
        (( \$#vals )) && compadd -a vals
        ;;
    clipindex)
        # \`clipboard list\` prints index, pin, kind, summary, tab separated,
        # and the index alone is unreadable: 12 of what? So the summary rides
        # along as the description.
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

# ----------------------------------------------------------------- the fn --

_banditshell() {
    # STAY CURRENT, cheaply. A handful of stats on the first completion of a
    # session, and the guard makes the re-source a one-way trip: if the rebuild
    # somehow leaves this file still older than its sources, the second pass
    # finds the guard set and just completes with what it has.
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

    # No _arguments. It exists to parse option specs, banditshell has none
    # outside \`alarm add\`, and asking it to do a plain positional dispatch buys
    # a \`--\` in every menu and a return code that has to be argued with. The
    # line is words[1]=banditshell, words[2]=verb, words[3]=its alternative.
    if (( CURRENT == 2 )); then
        _describe -t commands 'banditshell' _bs_commands
        return
    fi

    local cmd=\$words[2] sub=""
    local -a subs _bs_literals
    case \$cmd in
$subcase    esac

    # The verb's own alternatives, when it has any and the cursor is on the
    # word that would be one.
    if (( CURRENT == 3 )) && (( \$#subs )); then
        _describe -t alternatives "\$cmd" subs
        return
    fi

    # Which slot on the line this is. A verb with alternatives spends a word on
    # one of them, so its first argument is the fourth; a verb without spends
    # none and its first argument is the third.
    local slot
    if (( \$#subs )); then
        sub=\$words[3]
        slot=\$(( CURRENT - 3 ))
    else
        slot=\$(( CURRENT - 2 ))
    fi
    (( slot >= 1 )) || return

    # Flags first: a flag is not a position, so a verb that has any offers them
    # wherever the cursor happens to be. The key is built the same way it was
    # written, empty \`sub\` and all, so the two spellings cannot drift.
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

# Both ways in: autoloaded by compinit as a completion function, or sourced
# directly by \`source <(banditshell completions print)\`, which is the whole
# setup for anyone who would rather not have a file installed.
if [[ \$funcstack[1] = _banditshell ]]; then
    _banditshell "\$@"
else
    compdef _banditshell banditshell
fi
EOF
}

# ------------------------------------------------------------- installing --

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# Anything left in the user's home belongs to the user, even under sudo.
user_own() {
    [ "$(id -u)" -eq 0 ] || return 0
    [ -n "${SUDO_USER:-}" ] || return 0
    chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")" "$@" 2>/dev/null || true
}

# The line that makes zsh look in COMPDIR, written to be safe wherever in a
# startup file it lands. Two orders are possible and both happen in the wild:
# before compinit, where adding to fpath is enough, and after it (oh-my-zsh runs
# compinit itself, half way up the file), where fpath is no longer being read
# and the function has to be autoloaded and bound by hand. Doing both, guarded,
# is shorter than trying to detect which one this is.
hook_body() {
    cat <<EOF
$BEGIN_MARK
# Written by \`banditshell completions install\`. Delete it, or run
# \`banditshell completions remove\`, and nothing else here is touched.
[[ -n \${fpath[(r)$COMPDIR]} ]] || fpath=($COMPDIR \$fpath)
if (( \$+functions[compdef] )); then
    autoload -Uz _banditshell 2>/dev/null && compdef _banditshell banditshell
else
    autoload -Uz compinit && compinit
fi
$END_MARK
EOF
}

# Which startup file the hook goes in. A ~/.zshrc.d that .zshrc actually loops
# over gets its own file, because a drop-in directory exists precisely so that
# things like this do not accumulate in .zshrc.
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

    # .zshrc itself: the block goes in once and is replaced in place on every
    # re-run, so this can be run any number of times without stacking up.
    [ -f "$f" ] || : >"$f"
    strip_hook "$f"
    # A trailing newline first, so the block cannot land glued to whatever the
    # last line was.
    [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && printf '\n' >>"$f"
    hook_body >>"$f" || return 1
    user_own "$f"
    say "  fpath      $f (a guarded block at the end)"
}

# compinit remembers where every completion function lived in .zcompdump, and a
# file appearing in a directory it has already walked is exactly the case that
# cache gets wrong. Dropping it costs a second on the next shell and removes the
# most common reason a freshly installed completion appears to do nothing.
drop_dump() {
    local d
    for d in "$ZDOT"/.zcompdump*; do
        [ -e "$d" ] && rm -f "$d"
    done
    return 0
}

# Is the installed file there and newer than everything it was built from?
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
    # Written whole and moved into place: a half-written completion function is
    # a shell that prints a parse error on every Tab.
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
            # The drop-in is ours whole. Stripping the block out of it would
            # leave an empty file in a directory that loops over everything in
            # it, which is litter rather than tidiness.
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

# ------------------------------------------------------------------- main --

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
