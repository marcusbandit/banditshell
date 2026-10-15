#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UI_DIR="$REPO/installer"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PROGRESS="$RUNTIME_DIR/banditshell-install.jsonl"
ASKPASS_RUN="$RUNTIME_DIR/banditshell-askpass"

DRY_RUN=0
WANT_UI=1
LIST_ONLY=0
WANT_CHARGE_LIMIT=0

usage() {
    cat <<EOF
usage: install.sh [--dry-run] [--no-ui] [--list] [--charge-limit]

Installs what banditshell needs on Arch: the CLI into bin/, quickshell, the
font, every package the shell calls, the C helpers (banditshell dev build) and tab
completion for zsh and bash. When the Spotify desktop app is installed it also
puts Spicetify and Spicy Lyrics into it, for word-timed lyrics in the media
card; that restarts Spotify if it is running. Steps already satisfied are
skipped, so a re-run retries only what failed (and re-patches Spotify after a
Spotify update). Run it as yourself; it asks for sudo when a package needs
installing.

  --dry-run   walk every step without installing anything
  --no-ui     stay in the terminal; no progress window
  --list      print the steps and exit

  --charge-limit   opt in to holding the battery charge. Writing the battery's
                   charge_control_end_threshold needs root, so this installs a
                   small helper into /usr/local/libexec and a polkit action that
                   lets you, signed in on this machine, run only that helper. The
                   helper takes one number from 50 to 100 and writes it to the
                   battery's threshold; it does nothing else. Needs sudo and polkit.
EOF
}

for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-ui) WANT_UI=0 ;;
    --list) LIST_ONLY=1 ;;
    --charge-limit) WANT_CHARGE_LIMIT=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "install.sh: unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "install.sh: run it as yourself, not as root; it writes into your own runtime" >&2
    echo "and config directories and asks for sudo only for packages" >&2
    exit 1
fi

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
    add_step cli                           "cli_installed"                           @cli                          1 "the CLI wrapper itself, cli/banditshell into bin/"
    add_step quickshell                    "command -v qs"                           quickshell                    1 "the toolkit the shell is written against"
    add_step curl                          "command -v curl"                         curl                          1 "fetching the font"
    add_step unzip                         "command -v unzip"                        unzip                         1 "unpacking the font"
    add_step monocraft                     "font_present Monocraft"                  @monocraft                    1 "the shell's face, and its pixel grid"

    add_step hyprland                      "command -v hyprctl"                      hyprland                      2 "the compositor it talks to"
    add_step qt6-declarative               "test -d /usr/lib/qt6/qml/QtQuick"        qt6-declarative               2 "QtQuick, Shapes, Effects"
    add_step qt6-multimedia                "test -d /usr/lib/qt6/qml/QtMultimedia"   qt6-multimedia                2 "sound in the notifications"
    add_step qt6-shadertools               "test -x /usr/lib/qt6/bin/qsb"            qt6-shadertools               2 "qsb, to compile the chassis shader"
    add_step ttf-material-symbols-variable "font_present 'Material Symbols Rounded'" ttf-material-symbols-variable 2 "the icon face"
    add_step ttf-nerd-fonts-symbols        "font_present 'Symbols Nerd Font'"        ttf-nerd-fonts-symbols        2 "per-application marks"
    add_step nodejs                        "command -v node"                         nodejs                        2 "the old-bind rewriter and the tests"
    add_step rsync                         "command -v rsync"                        rsync                         2 "the last known good copy"
    add_step wl-clipboard                  "command -v wl-paste"                     wl-clipboard                  2 "what was copied, and its types"
    add_step jq                            "command -v jq"                           jq                            2 "the clipboard recorder's json"
    add_step grim                          "command -v grim"                         grim                          2 "screenshots and the freeze picker"
    add_step slurp                         "command -v slurp"                        slurp                         2 "the region when the shell is down"
    add_step swappy                        "command -v swappy"                       swappy                        2 "the default screenshot editor"
    add_step ffmpeg                        "command -v ffprobe"                      ffmpeg                        2 "the picker's frozen frame, video wallpapers"
    add_step libnotify                     "command -v notify-send"                  libnotify                     2 "timers, alarms and the battery speaking up"
    add_step xdg-utils                     "command -v xdg-open"                     xdg-utils                     2 "opening files and links"
    add_step fd                            "command -v fd"                           fd                            2 "the launcher finding files by name"
    add_step libqalculate                  "command -v qalc"                         libqalculate                  2 "the launcher's units, currency and dates"
    add_step networkmanager                "command -v nmcli"                        networkmanager                2 "wi-fi and wired"
    add_step ddcutil                       "command -v ddcutil"                      ddcutil                       2 "monitor brightness over DDC/CI"
    add_step pciutils                      "command -v lspci"                        pciutils                      2 "the device page's graphics card"
    add_step wtype                         "command -v wtype"                        wtype                         2 "the on-screen keyboard's typing"
    add_step ydotool                       "command -v ydotool"                      ydotool                       2 "the on-screen keyboard's modifier chords"
    add_step python                        "command -v python3"                      python                        2 "the palette, the hinge probe, the keyring prompter"
    add_step python-gobject                "python3 -c 'import gi'"                  python-gobject                2 "the keyring prompter's bus side"
    add_step python-cryptography           "python3 -c 'import cryptography'"        python-cryptography           2 "the keyring prompter's secret exchange"
    add_step python-evdev                  "python3 -c 'import evdev'"               python-evdev                  2 "the pen tablet's pad buttons"
    add_step glib2                         "command -v gdbus"                        glib2                         2 "the portal calls"
    add_step zenity                        "command -v zenity"                       zenity                        2 "the one dialog qml cannot draw"
    add_step qrencode                      "command -v qrencode"                     qrencode                      2 "the qr the shell hands out"
    add_step zxing-cpp                     "command -v ZXingReader"                  zxing-cpp                     2 "the qr the shell reads back"
    add_step librsvg                       "command -v rsvg-convert"                 librsvg                       2 "svg icons, for the palette"
    add_step gcc                           "command -v gcc"                          gcc                           2 "compiling the C helpers"
    add_step pkgconf                       "command -v pkg-config"                   pkgconf                       2 "finding the wayland client library"
    add_step helpers                       "helpers_built"                           @helpers                      2 "the pty, the directory lister and the gamma client"
    add_step completion                    "completion_present"                      @completion                   2 "tab completion for the CLI, in zsh and bash"
    add_step spicy-lyrics                  "spicy_lyrics_present"                    @spicy                        2 "word-timed lyrics: Spicetify and Spicy Lyrics, in Spotify"

    if [ "$WANT_CHARGE_LIMIT" -eq 1 ]; then
        add_step polkit                    "command -v pkexec"                       polkit                        2 "pkexec, to run the charge limit helper without a password"
        add_step charge-limit              "charge_limit_present"                    @charge-limit                 2 "the helper that writes the battery's charge limit, and its polkit action"
    fi
}

CHARGE_HELPER="/usr/local/libexec/banditshell-charge-limit"
CHARGE_POLICY="/usr/share/polkit-1/actions/org.banditshell.charge-limit.policy"

charge_limit_present() {
    if ! ls /sys/class/power_supply/BAT*/charge_control_end_threshold >/dev/null 2>&1; then
        PROBE_NOTE="no battery here has a charge limit; nothing to install"
        return 0
    fi
    cmp -s "$REPO/scripts/charge-limit.sh" "$CHARGE_HELPER" || return 1
    cmp -s "$REPO/assets/polkit/org.banditshell.charge-limit.policy" "$CHARGE_POLICY"
}

install_charge_limit() {
    if ! need_root; then
        STEP_OUTPUT="no sudo, so the charge limit helper was not installed"
        return 1
    fi
    STEP_OUTPUT="$(sudo -n install -Dm755 -o root -g root "$REPO/scripts/charge-limit.sh" "$CHARGE_HELPER" 2>&1 \
        && sudo -n install -Dm644 -o root -g root "$REPO/assets/polkit/org.banditshell.charge-limit.policy" "$CHARGE_POLICY" 2>&1)"
}

cli_installed() {
    [ -x "$REPO/bin/banditshell" ] || return 1
    [ "$REPO/cli/banditshell" -nt "$REPO/bin/banditshell" ] && return 1
    return 0
}

install_cli() {
    install -Dm755 "$REPO/cli/banditshell" "$REPO/bin/banditshell"
}

helpers_built() {
    local helper
    for helper in bs-pty bs-ls bs-gamma; do
        [ -x "$REPO/bin/$helper" ] || return 1
        [ "$REPO/src/$helper.c" -nt "$REPO/bin/$helper" ] && return 1
    done
    return 0
}

install_helpers() {
    STEP_OUTPUT="$("$REPO/bin/banditshell" dev build 2>&1)"
}

completion_present() {
    "$REPO/scripts/bash-completion.sh" status --quiet || return 1
    if ! command -v zsh >/dev/null 2>&1; then
        PROBE_NOTE="no zsh on this machine; bash only"
        return 0
    fi
    "$REPO/scripts/zsh-completion.sh" status --quiet
}

install_completion() {
    "$REPO/scripts/bash-completion.sh" install --quiet || return 1
    command -v zsh >/dev/null 2>&1 || return 0
    "$REPO/scripts/zsh-completion.sh" install --quiet
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

KEEPALIVE_PID=""
SUDO_READY=0

cleanup() {
    if [ -n "$KEEPALIVE_PID" ]; then
        kill "$KEEPALIVE_PID" 2>/dev/null
        KEEPALIVE_PID=""
    fi
    ui_stop
    askpass_stop
    return 0
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

start_keepalive() {
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
    [ "$SUDO_READY" -eq 1 ] && return 0

    if sudo -n true 2>/dev/null; then
        SUDO_READY=1
        start_keepalive
        return 0
    fi

    if graphical_possible; then
        if SUDO_ASKPASS="$UI_DIR/askpass.sh" \
            BANDITSHELL_ASKPASS_DIR="$ASKPASS_RUN" \
            BANDITSHELL_UI_DIR="$UI_DIR" \
            sudo -A -v 2>/dev/null; then
            SUDO_READY=1
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
            SUDO_READY=1
            start_keepalive
            return 0
        fi
        say "  authentication failed ($try of 3)"
    done
    return 1
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

install_pkg() {
    local pkg="$1"
    if ! command -v pacman >/dev/null 2>&1; then
        STEP_OUTPUT="no pacman on this machine; install $pkg with the system's package manager"
        return 1
    fi
    if ! need_root; then
        STEP_OUTPUT="no sudo, so $pkg was not installed"
        return 1
    fi
    STEP_OUTPUT="$(sudo -n pacman -S --needed --noconfirm "$pkg" 2>&1)"
}

MONOCRAFT_VER="4.2.1"
MONOCRAFT_URL="https://github.com/IdreesInc/Monocraft/releases/download/v${MONOCRAFT_VER}/Monocraft-otf.zip"
MONOCRAFT_SHA="e623b72f1021062ad0156cc41f54b108e70bd35e2b295127475bb572d8ade61d"

install_monocraft() {
    local tmp status=0
    tmp="$(mktemp -d)" || return 1
    fetch_monocraft "$tmp" || status=1
    rm -rf "$tmp"
    return "$status"
}

fetch_monocraft() {
    local tmp="$1"
    curl -fsSL -o "$tmp/mono.zip" "$MONOCRAFT_URL" || { STEP_OUTPUT="could not download $MONOCRAFT_URL"; return 1; }

    local got
    got="$(sha256sum "$tmp/mono.zip" | cut -d' ' -f1)"
    if [ "$got" != "$MONOCRAFT_SHA" ]; then
        STEP_OUTPUT="checksum mismatch: $got"
        return 1
    fi

    unzip -oq "$tmp/mono.zip" -d "$tmp/x" || return 1

    local dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/monocraft"
    mkdir -p "$dest" || return 1
    cp "$tmp/x/Monocraft-otf/Monocraft.otf" "$dest/" || return 1
    cp "$tmp"/x/Monocraft-otf/weights/*.otf "$dest/" 2>/dev/null
    fc-cache -f "$dest" >/dev/null 2>&1
    return 0
}

SPICY_LOADER_URL="https://raw.githubusercontent.com/Spikerko/spicy-lyrics/main/builds/spicy-lyrics.mjs"
SPICETIFY_RELEASES="https://github.com/spicetify/cli/releases"
SPICETIFY=""

spotify_dir() {
    local dir
    for dir in /opt/spotify /usr/share/spotify /usr/lib/spotify /usr/lib64/spotify \
        "$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify" \
        /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify; do
        if [ -d "$dir/Apps" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
    done
    return 1
}

spotify_prefs() {
    local prefs
    for prefs in "${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs" "$HOME/.var/app/com.spotify.Client/config/spotify/prefs"; do
        if [ -f "$prefs" ]; then
            printf '%s\n' "$prefs"
            return 0
        fi
    done
    return 1
}

find_spicetify() {
    if command -v spicetify >/dev/null 2>&1; then
        SPICETIFY="$(command -v spicetify)"
    elif [ -x "$HOME/.spicetify/spicetify" ]; then
        SPICETIFY="$HOME/.spicetify/spicetify"
    else
        return 1
    fi
}

spicy_has_run() {
    local index
    for index in "$HOME"/.cache/spotify/*/"Service Worker"/CacheStorage/*/index.txt \
        "$HOME"/.var/app/com.spotify.Client/cache/spotify/*/"Service Worker"/CacheStorage/*/index.txt; do
        grep -qs SpicyLyrics_LyricsStore "$index" && return 0
    done
    return 1
}

spicy_lyrics_present() {
    local dir config
    if ! dir="$(spotify_dir)"; then
        if command -v snap >/dev/null 2>&1 && snap list spotify >/dev/null 2>&1; then
            PROBE_NOTE="Spotify is a snap, which Spicetify cannot patch; lyrics come from lrclib.net"
        else
            PROBE_NOTE="no Spotify desktop app; lyrics come from lrclib.net"
        fi
        return 0
    fi
    find_spicetify || return 1
    grep -qsi spicetify "$dir/Apps/xpui/index.html" || return 1
    config="$("$SPICETIFY" -c 2>/dev/null)" || return 1
    grep -Eq '^extensions[[:space:]]*=.*spicy-lyrics' "$config" && return 0
    grep -Eq '^custom_apps[[:space:]]*=.*marketplace' "$config" && spicy_has_run && return 0
    return 1
}

fetch_spicetify() {
    local target tag tmp dest="$HOME/.spicetify"
    case "$(uname -m)" in
    x86_64) target="linux-amd64" ;;
    aarch64) target="linux-arm64" ;;
    *)
        STEP_OUTPUT="Spicetify has no build for $(uname -m)"
        return 1
        ;;
    esac
    tag="$(curl -fsSL -H 'Accept: application/json' "$SPICETIFY_RELEASES/latest" | sed -n 's/.*"tag_name":"v\{0,1\}\([^"]*\)".*/\1/p')"
    if [ -z "$tag" ]; then
        STEP_OUTPUT="could not find the latest Spicetify release"
        return 1
    fi
    mkdir -p "$dest" || return 1
    tmp="$(mktemp)" || return 1
    if ! curl -fsSL -o "$tmp" "$SPICETIFY_RELEASES/download/v$tag/spicetify-$tag-$target.tar.gz" || ! tar xzf "$tmp" -C "$dest"; then
        rm -f "$tmp"
        STEP_OUTPUT="could not download Spicetify $tag"
        return 1
    fi
    rm -f "$tmp"
    chmod +x "$dest/spicetify"
    SPICETIFY="$dest/spicetify"
}

install_spicy_lyrics() {
    local dir prefs config extensions restart=-n
    dir="$(spotify_dir)" || return 0
    if ! prefs="$(spotify_prefs)"; then
        STEP_OUTPUT="open Spotify once and sign in, then run install.sh again"
        return 1
    fi
    find_spicetify || fetch_spicetify || return 1

    if [ ! -w "$dir" ] || [ ! -w "$dir/Apps" ]; then
        if ! need_root; then
            STEP_OUTPUT="no sudo, so Spicetify cannot patch $dir"
            return 1
        fi
        if ! sudo -n chmod a+wr "$dir" || ! sudo -n chmod -R a+wr "$dir/Apps"; then
            STEP_OUTPUT="could not make $dir writable for Spicetify"
            return 1
        fi
    fi

    "$SPICETIFY" -q config spotify_path "$dir" prefs_path "$prefs" >/dev/null 2>&1 </dev/null
    config="$("$SPICETIFY" -c 2>/dev/null)"
    if [ ! -f "$config" ]; then
        STEP_OUTPUT="Spicetify did not write its config"
        return 1
    fi

    if ! grep -Eq '^custom_apps[[:space:]]*=.*marketplace' "$config" || ! spicy_has_run; then
        extensions="$("$SPICETIFY" path userdata 2>/dev/null)/Extensions"
        mkdir -p "$extensions" || return 1
        if ! curl -fsSL -o "$extensions/spicy-lyrics.mjs" "$SPICY_LOADER_URL"; then
            STEP_OUTPUT="could not download Spicy Lyrics"
            return 1
        fi
        grep -Eq '^extensions[[:space:]]*=.*spicy-lyrics' "$config" || "$SPICETIFY" -q config extensions spicy-lyrics.mjs >/dev/null 2>&1 </dev/null
    fi

    pgrep -x spotify >/dev/null 2>&1 && restart=""
    if grep -Eq '^version[[:space:]]*=[[:space:]]*[^[:space:]]' "$config"; then
        STEP_OUTPUT="$("$SPICETIFY" $restart apply 2>&1 </dev/null)" && return 0
        STEP_OUTPUT="$("$SPICETIFY" $restart restore backup apply 2>&1 </dev/null)"
    else
        STEP_OUTPUT="$("$SPICETIFY" $restart backup apply 2>&1 </dev/null)"
    fi
}

UI_PID=""

ui_stop() {
    [ -n "$UI_PID" ] || return 0
    kill "$UI_PID" 2>/dev/null || true
    UI_PID=""
}

ui_start() {
    [ "$WANT_UI" -eq 1 ] || return 1
    [ -n "${WAYLAND_DISPLAY:-}" ] || return 1
    command -v qs >/dev/null 2>&1 || return 1
    [ -f "$UI_DIR/shell.qml" ] || return 1

    BANDITSHELL_INSTALL_LOG="$PROGRESS" qs -p "$UI_DIR" >/dev/null 2>&1 &
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
STEP_OUTPUT=""

run_step() {
    local i="$1"
    local name="${STEP_NAME[$i]}"
    local probe="${STEP_PROBE[$i]}"
    local pkg="${STEP_PKG[$i]}"

    PROBE_NOTE=""
    STEP_OUTPUT=""
    if [ "$DRY_RUN" -eq 0 ] && eval "$probe" >/dev/null 2>&1; then
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
    else
        case "$pkg" in
        @monocraft) install_monocraft && ok=0 ;;
        @completion) install_completion && ok=0 ;;
        @cli) install_cli && ok=0 ;;
        @helpers) install_helpers && ok=0 ;;
        @spicy) install_spicy_lyrics && ok=0 ;;
        @charge-limit) install_charge_limit && ok=0 ;;
        *) install_pkg "$pkg" && ok=0 ;;
        esac
    fi

    if [ "$ok" -eq 0 ]; then
        emit_step "$i" "done"
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" "done"
        DONE_N=$((DONE_N + 1))
    else
        emit_step "$i" failed "$(printf '%s' "${STEP_OUTPUT:-install failed}" | tail -1)"
        [ "$UI_PID" = "" ] && bar "$i" "${#STEP_NAME[@]}" "$name" failed
        [ -n "$STEP_OUTPUT" ] && printf '%s\n' "$STEP_OUTPUT" | tail -20 | sed 's/^/      /'
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
    say "    in a new shell: banditshell <Tab> completes every command"
    say "    run it now:     $REPO/bin/banditshell start"
    say "    see it live:    $REPO/bin/banditshell dev run"
    say "    what it does:   $REPO/bin/banditshell help"
    return 0
}

main
