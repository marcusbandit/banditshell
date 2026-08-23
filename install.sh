#!/usr/bin/env bash
# banditshell installer: the shell building itself out of the download.
#
# Two phases, and the split is the whole idea.
#
#   Phase 1 is the MINIMUM needed to draw anything at all: quickshell, and the
#   font. Plain terminal output, no ceremony, measured in seconds. Nothing here
#   can be pretty, because the thing that would draw it is what phase 1 installs.
#
#   Phase 2 is everything else, and it runs UNDER a quickshell surface that
#   watches this script's progress and assembles a piece of banditshell's own
#   chrome for each dependency that lands. By the end the progress display has
#   put itself together into something that looks like the shell you just
#   installed, which is the point.
#
# The pretty half is never allowed to block the useful half. No Wayland session,
# no quickshell, a QML error, a missing font: any of those drops this back to a
# terminal progress bar and the install still finishes.
#
#   ./install.sh              install
#   ./install.sh --dry-run    exercise the whole pipeline with fake steps,
#                             installing nothing. Proves the UI animates.
#   ./install.sh --no-ui      terminal only, never launch the surface
#   ./install.sh --list       print the dependency table and exit
#
# ROOT. In order: already root, then passwordless sudo, then ask once through
# sudo's own askpass protocol and keep the credential warm for the rest of the
# run. The password is never an argument, never a file, never a log line: it
# travels from the prompt to sudo over a pipe and dies with the helper.

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UI_DIR="$REPO/installer"

# WHOSE machine this is, which is not the same as who is running the script.
# `sudo ./install.sh` is a normal way to run an installer, and everything it
# leaves in a home directory has to belong to the person who typed it rather
# than to root.
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || id -u)"

# The user's runtime dir, not root's: the surface runs as them and has to be
# able to read the progress file.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$TARGET_UID}"
[ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && RUNTIME_DIR="/run/user/$TARGET_UID"

PROGRESS="$RUNTIME_DIR/banditshell-install.jsonl"
ASKPASS_RUN="$RUNTIME_DIR/banditshell-askpass"

DRY_RUN=0
WANT_UI=1
LIST_ONLY=0

for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-ui) WANT_UI=0 ;;
    --list) LIST_ONLY=1 ;;
    -h | --help)
        awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$(readlink -f "${BASH_SOURCE[0]}")"
        exit 0
        ;;
    *) echo "install.sh: unknown option: $arg" >&2; exit 2 ;;
    esac
done

# ---------------------------------------------------------------- the table --
#
# One row per dependency: a name, the question "is it already here", the package
# that answers no, and which phase it belongs to. Adding a dependency is adding a
# row; nothing downstream counts them by hand, and the surface lays itself out
# from however many there turn out to be.
#
# `@monocraft` is the one payload that is not a package name. The font's AUR
# packages build it from source with fontforge, which is minutes and a compiler
# for a 700 KB file that upstream already ships built. Phase 1 has a budget of
# seconds, so it takes the prebuilt release instead. See install_monocraft.

STEP_NAME=()
STEP_PROBE=()
STEP_PKG=()
STEP_PHASE=()
STEP_WHAT=()

add_step() {
    STEP_NAME+=("$1")
    STEP_PROBE+=("$2")
    STEP_PKG+=("$3")
    STEP_PHASE+=("$4")
    STEP_WHAT+=("$5")
}

# Is a font family installed, by its exact family name.
#
# Written in two steps ON PURPOSE. The obvious one line version ends in
# `grep -qix`, and `grep -q` exits the instant it matches, which hands the
# commands upstream of it a SIGPIPE. Under `set -o pipefail` that makes the whole
# pipeline exit 141 and the probe reports the font MISSING at exactly the moment
# it found it. Every font in the table failed its probe that way, and two of them
# went on to ask for a root password to install something already on the disk.
# Collecting first and matching without -q means grep consumes all of its input
# and nothing upstream is ever cut off.
font_present() {
    local families
    families="$(fc-list : family 2>/dev/null | tr ',' '\n')"
    [ -n "$families" ] || return 1
    printf '%s\n' "$families" | grep -ix "$1" >/dev/null 2>&1
}

build_table() {
    if [ "$DRY_RUN" -eq 1 ]; then
        # Fake steps, so the pipeline and the animation can be proved without
        # touching the machine. Deliberately the same SHAPE as the real table.
        add_step quickshell   "false" ""  1 "the toolkit"
        add_step monocraft    "false" ""  1 "the font"
        local n
        for n in hyprland qt6-declarative qt6-multimedia qt6-shadertools \
            ttf-material-symbols-variable ttf-nerd-fonts-symbols wl-clipboard \
            jq grim ffmpeg python glib2 zenity qrencode zxing-cpp librsvg; do
            add_step "$n" "false" "" 2 "pretend"
        done
        return
    fi

    # -- phase 1: the minimum that can draw -----------------------------------
    add_step quickshell "command -v qs"          quickshell 1 "the toolkit the shell is written against"
    add_step monocraft  "font_present Monocraft" @monocraft 1 "the shell's face, and its pixel grid"

    # -- phase 2: everything the shell actually uses ---------------------------
    add_step hyprland                     "command -v hyprctl"           hyprland                      2 "the compositor it talks to"
    add_step qt6-declarative              "test -d /usr/lib/qt6/qml/QtQuick"        qt6-declarative    2 "QtQuick, Shapes, Effects"
    add_step qt6-multimedia               "test -d /usr/lib/qt6/qml/QtMultimedia"   qt6-multimedia     2 "sound in the notifications"
    add_step qt6-shadertools              "test -x /usr/lib/qt6/bin/qsb"            qt6-shadertools    2 "qsb, to compile the chassis shader"
    add_step ttf-material-symbols-variable "font_present 'Material Symbols Rounded'" ttf-material-symbols-variable 2 "the icon face"
    add_step ttf-nerd-fonts-symbols       "font_present 'Symbols Nerd Font'"        ttf-nerd-fonts-symbols 2 "per-application marks"
    add_step wl-clipboard                 "command -v wl-paste"          wl-clipboard                  2 "what was copied, and its types"
    add_step jq                           "command -v jq"                jq                            2 "the clipboard recorder's json"
    add_step grim                         "command -v grim"              grim                          2 "screenshots and the freeze picker"
    add_step ffmpeg                       "command -v ffmpeg"            ffmpeg                        2 "the picker's frozen frame"
    add_step python                       "command -v python3"           python                        2 "the palette and the hinge probe"
    add_step glib2                        "command -v gdbus"             glib2                         2 "the portal calls"
    add_step zenity                       "command -v zenity"            zenity                        2 "the one dialog qml cannot draw"
    add_step qrencode                     "command -v qrencode"          qrencode                      2 "the qr the shell hands out"
    add_step zxing-cpp                    "command -v ZXingReader"       zxing-cpp                     2 "the qr the shell reads back"
    add_step librsvg                      "command -v rsvg-convert"      librsvg                       2 "svg icons, for the palette"
}

# ------------------------------------------------------------- the protocol --
#
# One json object per line, appended. The surface tails this file and animates
# from it; the terminal fallback prints from the same calls. Two readers, one
# source of truth, and nothing in the pretty half that the plain half does not
# also know.
#
#   {"state":"begin","total":18,"phase1":2,"phase2":16}
#   {"i":0,"total":18,"phase":1,"name":"quickshell","what":"...","state":"start"}
#   {"i":0,"total":18,"phase":1,"name":"quickshell","state":"done"}
#   {"i":1,"total":18,"phase":1,"name":"monocraft","state":"skip","note":"present"}
#   {"i":7,"total":18,"phase":2,"name":"jq","state":"failed","note":"..."}
#   {"state":"finished","done":14,"skipped":3,"failed":1}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit() {
    printf '%s\n' "$1" >>"$PROGRESS" 2>/dev/null || true
}

emit_step() {
    local i="$1" state="$2" note="${3:-}"
    local line
    line="{\"i\":$i,\"total\":${#STEP_NAME[@]},\"phase\":${STEP_PHASE[$i]}"
    line="$line,\"name\":\"$(json_escape "${STEP_NAME[$i]}")\""
    line="$line,\"what\":\"$(json_escape "${STEP_WHAT[$i]}")\""
    line="$line,\"state\":\"$state\""
    [ -n "$note" ] && line="$line,\"note\":\"$(json_escape "$note")\""
    emit "$line}"
}

# ------------------------------------------------------------- terminal out --

USE_COLOUR=0
[ -t 1 ] && [ -z "${NO_COLOR:-}" ] && USE_COLOUR=1
c() { [ "$USE_COLOUR" -eq 1 ] && printf '\033[%sm' "$1"; }

say() { printf '%s\n' "$*"; }

# The fallback progress bar, and the only progress display when there is no
# surface. Computed from the count rather than drawn in fixed slots, for the
# same reason the surface is: the table changes length.
bar() {
    local i="$1" total="$2" name="$3" state="$4"
    local width=28
    local filled=$(((i + 1) * width / total))
    local b="" k
    for ((k = 0; k < width; k++)); do
        if [ "$k" -lt "$filled" ]; then b="$b#"; else b="$b."; fi
    done
    local mark
    case "$state" in
    done) mark="ok  " ;;
    skip) mark="have" ;;
    failed) mark="FAIL" ;;
    *) mark="...." ;;
    esac

    # The in-flight line is redrawn over itself, which only works on a terminal.
    # Piped into a file or a log it would leave every step twice, so off a tty
    # only the settled line is printed.
    if [ "$state" = "start" ]; then
        [ -t 1 ] || return 0
        printf '\r  [%s] %2d/%-2d %s %-30s' "$b" "$((i + 1))" "$total" "$mark" "$name"
        return 0
    fi
    [ -t 1 ] && printf '\r'
    printf '  [%s] %2d/%-2d %s %-30s\n' "$b" "$((i + 1))" "$total" "$mark" "$name"
}

# ------------------------------------------------------------------- root ----
#
# Worked out at the FIRST moment root is actually needed, not up front: a re-run
# on a machine that already has everything must not ask for a password to
# discover it has nothing to do.

ROOT_MODE=""
KEEPALIVE_PID=""

cleanup() {
    [ -n "$KEEPALIVE_PID" ] && kill "$KEEPALIVE_PID" 2>/dev/null
    ui_stop
    askpass_stop
    return 0
}
trap cleanup EXIT INT TERM

start_keepalive() {
    [ "$ROOT_MODE" = "direct" ] && return 0
    [ -n "$KEEPALIVE_PID" ] && return 0
    # Asked ONCE. Every privileged call after this is a plain `sudo -n` against a
    # timestamp this refreshes, so a sixteen package phase 2 is one prompt and
    # not sixteen.
    (
        while true; do
            sudo -n -v 2>/dev/null || exit 0
            sleep 60
        done
    ) &
    KEEPALIVE_PID=$!
}

# Can a password be asked for with a picture rather than a terminal line? Only
# once there is something to draw it with, which is the bootstrapping knot: the
# graphical prompt is a quickshell surface, and quickshell is what phase 1
# installs. So phase 1 on a bare machine authenticates through the terminal, and
# the graphical prompt is what a re-run and phase 2 get. Both paths end at the
# same cached timestamp, so nobody is asked twice either way.
graphical_possible() {
    [ "$WANT_UI" -eq 1 ] || return 1
    [ -n "${WAYLAND_DISPLAY:-}" ] || return 1
    command -v qs >/dev/null 2>&1 || return 1
    [ -f "$UI_DIR/askpass.qml" ] || return 1
    return 0
}

need_root() {
    [ -n "$ROOT_MODE" ] && return 0

    if [ "$(id -u)" -eq 0 ]; then
        ROOT_MODE="direct"
        return 0
    fi

    if sudo -n true 2>/dev/null; then
        ROOT_MODE="cached"
        start_keepalive
        return 0
    fi

    if graphical_possible; then
        # sudo's own askpass protocol: the helper prints the secret on stdout and
        # sudo reads it off a pipe. Nothing here ever sees the value, which is
        # exactly why this is the supported path and not a hand-rolled one.
        if SUDO_ASKPASS="$UI_DIR/askpass.sh" \
            BANDITSHELL_ASKPASS_DIR="$ASKPASS_RUN" \
            BANDITSHELL_UI_DIR="$UI_DIR" \
            sudo -A -v 2>/dev/null; then
            ROOT_MODE="cached"
            start_keepalive
            askpass_stop
            return 0
        fi
        askpass_stop
        say "  (graphical prompt did not complete, falling back to the terminal)"
    fi

    # sudo counts its own tries; this bounds the outer loop so a wrong password
    # cannot spin forever.
    local try
    for try in 1 2 3; do
        if sudo -v; then
            ROOT_MODE="cached"
            start_keepalive
            return 0
        fi
        say "  authentication failed ($try of 3)"
    done
    return 1
}

as_root() {
    if [ "$ROOT_MODE" = "direct" ]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

# Anything this script leaves in the user's home belongs to the user, even when
# the script was started with sudo.
user_own() {
    [ "$(id -u)" -eq 0 ] || return 0
    [ -n "${SUDO_USER:-}" ] || return 0
    chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$@" 2>/dev/null || true
}

askpass_stop() {
    [ -d "$ASKPASS_RUN" ] || return 0
    local pidf="$ASKPASS_RUN/ui.pid"
    if [ -f "$pidf" ]; then
        kill "$(cat "$pidf" 2>/dev/null)" 2>/dev/null || true
        rm -f "$pidf"
    fi
    rm -rf "$ASKPASS_RUN" 2>/dev/null || true
}

# ---------------------------------------------------------------- installs --

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

install_pkg() {
    local pkg="$1"
    need_root || return 1
    as_root pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1
}

# Monocraft, from the release upstream already built.
#
# Pinned by checksum, because this is the one dependency that arrives over plain
# https rather than through a package manager that has already checked it.
MONOCRAFT_VER="4.2.1"
MONOCRAFT_URL="https://github.com/IdreesInc/Monocraft/releases/download/v${MONOCRAFT_VER}/Monocraft-otf.zip"
MONOCRAFT_SHA="e623b72f1021062ad0156cc41f54b108e70bd35e2b295127475bb572d8ade61d"

install_monocraft() {
    local tmp
    tmp="$(mktemp -d)" || return 1
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    curl -fsSL -o "$tmp/mono.zip" "$MONOCRAFT_URL" || return 1

    local got
    got="$(sha256sum "$tmp/mono.zip" | cut -d' ' -f1)"
    if [ "$got" != "$MONOCRAFT_SHA" ]; then
        echo "checksum mismatch" >&2
        return 1
    fi

    unzip -oq "$tmp/mono.zip" -d "$tmp/x" || return 1

    # System wide when root is already in hand, the user's own font directory
    # when it is not: a font is the one dependency here that does not need root
    # at all, and asking for a password to install one would be rude.
    local dest
    if [ "$(id -u)" -eq 0 ]; then
        dest="/usr/share/fonts/monocraft"
        install -d "$dest" || return 1
        install -m644 "$tmp/x/Monocraft-otf/Monocraft.otf" "$dest/" || return 1
        install -m644 "$tmp"/x/Monocraft-otf/weights/*.otf "$dest/" 2>/dev/null
    else
        dest="$TARGET_HOME/.local/share/fonts/monocraft"
        mkdir -p "$dest" || return 1
        cp "$tmp/x/Monocraft-otf/Monocraft.otf" "$dest/" || return 1
        cp "$tmp"/x/Monocraft-otf/weights/*.otf "$dest/" 2>/dev/null
        user_own "$TARGET_HOME/.local/share/fonts"
    fi

    fc-cache -f "$dest" >/dev/null 2>&1
    return 0
}

# -------------------------------------------------------------- the surface --

UI_PID=""

ui_stop() {
    [ -n "$UI_PID" ] || return 0
    kill "$UI_PID" 2>/dev/null || true
    UI_PID=""
}

# Launched as the USER even when this script is root, because the surface needs
# their Wayland session and their runtime dir, neither of which root is in.
ui_start() {
    [ "$WANT_UI" -eq 1 ] || return 1
    command -v qs >/dev/null 2>&1 || return 1
    [ -f "$UI_DIR/shell.qml" ] || return 1

    local wl="${WAYLAND_DISPLAY:-}"
    if [ -z "$wl" ] && [ -n "${SUDO_USER:-}" ]; then
        # Started with sudo from inside their session: the variable was scrubbed
        # but the socket is still sitting in their runtime dir.
        # `| head -1` would SIGPIPE `sort` the same way the font probe was
        # bitten above; sort's own -z-free output is small enough to take whole
        # and pick from with a shell builtin instead.
        local socks
        socks="$(find "$RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]*' ! -name '*.lock' 2>/dev/null | sort)"
        wl="$(basename "${socks%%$'\n'*}" 2>/dev/null)"
    fi
    [ -n "$wl" ] || return 1

    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        runuser -u "$TARGET_USER" -- env \
            XDG_RUNTIME_DIR="$RUNTIME_DIR" WAYLAND_DISPLAY="$wl" \
            BANDITSHELL_INSTALL_LOG="$PROGRESS" \
            qs -p "$UI_DIR" >/dev/null 2>&1 &
    else
        BANDITSHELL_INSTALL_LOG="$PROGRESS" \
            qs -p "$UI_DIR" >/dev/null 2>&1 &
    fi
    UI_PID=$!

    # Give it a moment to either come up or die. A surface that failed to start
    # must not leave the install printing nothing to a terminal it thinks is
    # being ignored.
    sleep 1.5
    if ! kill -0 "$UI_PID" 2>/dev/null; then
        UI_PID=""
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------- the steps --

DONE_N=0
SKIP_N=0
FAIL_N=0

run_step() {
    local i="$1"
    local name="${STEP_NAME[$i]}"
    local probe="${STEP_PROBE[$i]}"
    local pkg="${STEP_PKG[$i]}"

    if eval "$probe" >/dev/null 2>&1; then
        emit_step "$i" skip "already present"
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" skip
        SKIP_N=$((SKIP_N + 1))
        return 0
    fi

    emit_step "$i" start
    [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" start

    local ok=1
    if [ "$DRY_RUN" -eq 1 ]; then
        # Long enough to watch, short enough to sit through.
        sleep 0.45
        ok=0
    elif [ "$pkg" = "@monocraft" ]; then
        install_monocraft && ok=0
    else
        install_pkg "$pkg" && ok=0
    fi

    if [ "$ok" -eq 0 ]; then
        emit_step "$i" done
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" done
        DONE_N=$((DONE_N + 1))
    else
        emit_step "$i" failed "install failed"
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" failed
        FAIL_N=$((FAIL_N + 1))
    fi
    return 0
}

# ---------------------------------------------------------------------- run --

main() {
    build_table
    local total="${#STEP_NAME[@]}"

    if [ "$LIST_ONLY" -eq 1 ]; then
        local i
        printf '%-32s %-6s %s\n' NAME PHASE WHAT
        for ((i = 0; i < total; i++)); do
            printf '%-32s %-6s %s\n' "${STEP_NAME[$i]}" "${STEP_PHASE[$i]}" "${STEP_WHAT[$i]}"
        done
        exit 0
    fi

    mkdir -p "$RUNTIME_DIR" 2>/dev/null
    : >"$PROGRESS"
    user_own "$PROGRESS"

    local p1=0 p2=0 i
    for ((i = 0; i < total; i++)); do
        [ "${STEP_PHASE[$i]}" = "1" ] && p1=$((p1 + 1)) || p2=$((p2 + 1))
    done
    emit "{\"state\":\"begin\",\"total\":$total,\"phase1\":$p1,\"phase2\":$p2,\"dry\":$DRY_RUN}"

    c 1; say "banditshell"; c 0
    [ "$DRY_RUN" -eq 1 ] && say "  dry run: nothing will be installed"
    say ""

    # -- phase 1 --------------------------------------------------------------
    say "  phase 1: enough to draw with"
    for ((i = 0; i < total; i++)); do
        [ "${STEP_PHASE[$i]}" = "1" ] || continue
        run_step "$i"
    done
    say ""

    # -- the handover ---------------------------------------------------------
    #
    # Everything from here is watched rather than printed, IF the surface comes
    # up. If it does not, the bar keeps printing and the install is no worse off
    # than it was a second ago.
    local ui=0
    if ui_start; then
        ui=1
        say "  phase 2: watch the screen"
    else
        say "  phase 2: the rest"
    fi

    for ((i = 0; i < total; i++)); do
        [ "${STEP_PHASE[$i]}" = "2" ] || continue
        run_step "$i"
    done

    emit "{\"state\":\"finished\",\"done\":$DONE_N,\"skipped\":$SKIP_N,\"failed\":$FAIL_N}"

    # Let the surface finish its last animation before it is taken away.
    [ "$ui" -eq 1 ] && sleep 4
    ui_stop

    # -- what happened --------------------------------------------------------
    say ""
    c 1; say "  summary"; c 0
    say "    installed  $DONE_N"
    say "    already had $SKIP_N"
    say "    failed     $FAIL_N"
    say ""

    if [ "$FAIL_N" -gt 0 ]; then
        say "  Some dependencies did not install. Re-run to retry only those:"
        say "    $REPO/install.sh"
        return 1
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "  Dry run only. Nothing was installed."
        return 0
    fi

    say "  banditshell is ready."
    say "    run it now:     $REPO/bin/banditshell start"
    say "    see it live:    $REPO/bin/banditshell run"
    say "    every verb:     $REPO/bin/banditshell help"
    return 0
}

main
