#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UI_DIR="$REPO/installer"

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || id -u)"

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

font_present() {
    local families
    families="$(fc-list : family 2>/dev/null | tr ',' '\n')"
    [ -n "$families" ] || return 1
    printf '%s\n' "$families" | grep -ix "$1" >/dev/null 2>&1
}

build_table() {
    if [ "$DRY_RUN" -eq 1 ]; then
        add_step quickshell   "false" ""  1 "the toolkit"
        add_step monocraft    "false" ""  1 "the font"
        local n
        for n in cli hyprland qt6-declarative qt6-multimedia qt6-shadertools \
            ttf-material-symbols-variable ttf-nerd-fonts-symbols wl-clipboard \
            jq grim ffmpeg python python-gobject python-cryptography glib2 zenity \
            qrencode zxing-cpp librsvg zsh-completion; do
            add_step "$n" "false" "" 2 "pretend"
        done
        return
    fi

    add_step cli          "cli_installed"             @cli       1 "the CLI wrapper itself, cli/banditshell into bin/"
    add_step quickshell "command -v qs"          quickshell 1 "the toolkit the shell is written against"
    add_step monocraft  "font_present Monocraft" @monocraft 1 "the shell's face, and its pixel grid"

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
    add_step python                       "command -v python3"           python                        2 "the palette, the hinge probe, the keyring prompter"
    add_step python-gobject               "python3 -c 'import gi'"       python-gobject                2 "the keyring prompter's bus side"
    add_step python-cryptography          "python3 -c 'import cryptography'" python-cryptography       2 "the keyring prompter's secret exchange"
    add_step glib2                        "command -v gdbus"             glib2                         2 "the portal calls"
    add_step zenity                       "command -v zenity"            zenity                        2 "the one dialog qml cannot draw"
    add_step qrencode                     "command -v qrencode"          qrencode                      2 "the qr the shell hands out"
    add_step zxing-cpp                    "command -v ZXingReader"       zxing-cpp                     2 "the qr the shell reads back"
    add_step librsvg                      "command -v rsvg-convert"      librsvg                       2 "svg icons, for the palette"

    add_step zsh-completion "completion_present" @zsh-completion 2 "tab completion for the CLI, in zsh"
}

completion_present() {
    if ! command -v zsh >/dev/null 2>&1; then
        PROBE_NOTE="no zsh on this machine"
        return 0
    fi
    "$REPO/scripts/zsh-completion.sh" status --quiet
}

# The CLI's source is tracked at cli/banditshell and the copy in bin/ is build
# output, the way bs-pty is build output of src/bs-pty.c. Present means not
# just existing but CURRENT: a pull that lands a new cli/banditshell makes the
# stale bin/ copy older than its source, and the step runs again.
cli_installed() {
    [ -x "$REPO/bin/banditshell" ] || return 1
    [ "$REPO/cli/banditshell" -nt "$REPO/bin/banditshell" ] && return 1
    return 0
}

install_cli() {
    install -m755 "$REPO/cli/banditshell" "$REPO/bin/banditshell" || return 1
    user_own "$REPO/bin/banditshell"
}

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

USE_COLOUR=0
[ -t 1 ] && [ -z "${NO_COLOR:-}" ] && USE_COLOUR=1
c() { [ "$USE_COLOUR" -eq 1 ] && printf '\033[%sm' "$1"; }

say() { printf '%s\n' "$*"; }

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

    if [ "$state" = "start" ]; then
        [ -t 1 ] || return 0
        printf '\r  [%s] %2d/%-2d %s %-30s' "$b" "$((i + 1))" "$total" "$mark" "$name"
        return 0
    fi
    [ -t 1 ] && printf '\r'
    printf '  [%s] %2d/%-2d %s %-30s\n' "$b" "$((i + 1))" "$total" "$mark" "$name"
}

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
    (
        while true; do
            sudo -n -v 2>/dev/null || exit 0
            sleep 60
        done
    ) &
    KEEPALIVE_PID=$!
}

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

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

install_pkg() {
    local pkg="$1"
    need_root || return 1
    as_root pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1
}

MONOCRAFT_VER="4.2.1"
MONOCRAFT_URL="https://github.com/IdreesInc/Monocraft/releases/download/v${MONOCRAFT_VER}/Monocraft-otf.zip"
MONOCRAFT_SHA="e623b72f1021062ad0156cc41f54b108e70bd35e2b295127475bb572d8ade61d"

install_monocraft() {
    local tmp
    tmp="$(mktemp -d)" || return 1
    trap "rm -rf '$tmp'" RETURN

    curl -fsSL -o "$tmp/mono.zip" "$MONOCRAFT_URL" || return 1

    local got
    got="$(sha256sum "$tmp/mono.zip" | cut -d' ' -f1)"
    if [ "$got" != "$MONOCRAFT_SHA" ]; then
        echo "checksum mismatch" >&2
        return 1
    fi

    unzip -oq "$tmp/mono.zip" -d "$tmp/x" || return 1

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

install_completion() {
    command -v zsh >/dev/null 2>&1 || return 0
    "$REPO/scripts/zsh-completion.sh" install --quiet
}

UI_PID=""

ui_stop() {
    [ -n "$UI_PID" ] || return 0
    kill "$UI_PID" 2>/dev/null || true
    UI_PID=""
}

ui_start() {
    [ "$WANT_UI" -eq 1 ] || return 1
    command -v qs >/dev/null 2>&1 || return 1
    [ -f "$UI_DIR/shell.qml" ] || return 1

    local wl="${WAYLAND_DISPLAY:-}"
    if [ -z "$wl" ] && [ -n "${SUDO_USER:-}" ]; then
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

    sleep 1.5
    if ! kill -0 "$UI_PID" 2>/dev/null; then
        UI_PID=""
        return 1
    fi
    return 0
}

DONE_N=0
SKIP_N=0
FAIL_N=0

PROBE_NOTE=""

run_step() {
    local i="$1"
    local name="${STEP_NAME[$i]}"
    local probe="${STEP_PROBE[$i]}"
    local pkg="${STEP_PKG[$i]}"

    PROBE_NOTE=""
    if eval "$probe" >/dev/null 2>&1; then
        emit_step "$i" skip "${PROBE_NOTE:-already present}"
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" skip
        SKIP_N=$((SKIP_N + 1))
        return 0
    fi

    emit_step "$i" start
    [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" start

    local ok=1
    if [ "$DRY_RUN" -eq 1 ]; then
        sleep 0.45
        ok=0
    elif [ "$pkg" = "@monocraft" ]; then
        install_monocraft && ok=0
    elif [ "$pkg" = "@zsh-completion" ]; then
        install_completion && ok=0
    elif [ "$pkg" = "@cli" ]; then
        install_cli && ok=0
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

    say "  phase 1: enough to draw with"
    for ((i = 0; i < total; i++)); do
        [ "${STEP_PHASE[$i]}" = "1" ] || continue
        run_step "$i"
    done
    say ""

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

    [ "$ui" -eq 1 ] && sleep 4
    ui_stop

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
    if command -v zsh >/dev/null 2>&1; then
        say "    in a NEW zsh:   banditshell <Tab> completes every verb"
    fi
    say "    run it now:     $REPO/bin/banditshell start"
    say "    see it live:    $REPO/bin/banditshell run"
    say "    every verb:     $REPO/bin/banditshell help"
    return 0
}

main
