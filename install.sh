#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UI_DIR="$REPO/installer"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PROGRESS="$RUNTIME_DIR/banditshell-install.jsonl"
ASKPASS_RUN="$RUNTIME_DIR/banditshell-askpass"

INSTALL_ARGS=("$@")
DRY_RUN=0
WANT_UI=1
LIST_ONLY=0
WANT_CHARGE_LIMIT=0
BESIDE_OMARCHY="${BANDITSHELL_BESIDE_OMARCHY:-0}"

usage() {
    cat <<EOF
usage: install.sh [--dry-run] [--no-ui] [--list] [--charge-limit] [--beside-omarchy]

A fresh clone on main first moves to the newest release, the version the
update loop follows by default. Then it installs what banditshell needs: the
CLI into bin/ and, when nothing else
provides one, ~/.local/bin/banditshell, quickshell, the fonts, every package
the shell calls, the C helpers (banditshell dev build), tab completion for zsh
and bash, and the Lua module your Hyprland binds load (a shim beside
hyprland.lua and a pointer file under \$XDG_STATE_HOME/banditshell). Packages
come from pacman, apt, dnf, zypper, xbps or apk, whichever this machine has;
anything a distro does not package is named so you can fetch it upstream. When
the Spotify desktop app is installed it also
puts Spicetify and Spicy Lyrics into it, for word-timed lyrics in the media
card; that restarts Spotify if it is running. Steps already satisfied are
skipped, so a re-run retries only what failed (and re-patches Spotify after a
Spotify update). Run it as yourself; it asks for sudo when a package needs
installing.

  --dry-run   walk every step without installing anything
  --no-ui     stay in the terminal; no progress window
  --list      print the steps and exit

  --beside-omarchy  install the full shell on Omarchy without asking. Its
                    notifications then fight Omarchy's own; the island plugin
                    is the one meant for Omarchy.

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
    --beside-omarchy) BESIDE_OMARCHY=1 ;;
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

qt_present() {
    "$REPO/scripts/find-qt.sh" "$1" "$2" >/dev/null
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
    add_step fontconfig                    "command -v fc-list"                      fontconfig                    1 "finding the fonts once they are in place"
    add_step monocraft                     "font_present Monocraft"                  @monocraft                    1 "the shell's face, and its pixel grid"

    add_step hyprland                      "command -v hyprctl"                      hyprland                      2 "the compositor it talks to"
    add_step qt6-declarative               "qt_present module QtQuick.Effects && qt_present module QtQuick.Shapes" qt6-declarative 2 "QtQuick, Shapes, Effects"
    add_step qt6-multimedia                "qt_present module QtMultimedia"          qt6-multimedia                2 "sound in the notifications"
    add_step qt6-websockets                "qt_present module QtWebSockets"          qt6-websockets                2 "talking to OBS while you stream"
    add_step qt6-shadertools               "qt_present tool qsb"                     qt6-shadertools               2 "qsb, to compile the chassis shader"
    add_step ttf-material-symbols-variable "font_present 'Material Symbols Rounded'" ttf-material-symbols-variable 2 "the icon face"
    add_step ttf-nerd-fonts-symbols        "font_present 'Symbols Nerd Font'"        ttf-nerd-fonts-symbols        2 "per-application marks"
    add_step nodejs                        "command -v node"                         nodejs                        2 "the old-bind rewriter and the tests"
    add_step rsync                         "command -v rsync"                        rsync                         2 "the last known good copy"
    add_step diffutils                     "command -v cmp"                          diffutils                     2 "cmp, which checks the Lua shim beside hyprland.lua is current"
    add_step tar                           "command -v tar"                          tar                           2 "unpacking a new version during an update"
    add_step util-linux                    "command -v flock && command -v setsid"   util-linux                    2 "flock and setsid, which keep updates and the trial watcher apart"
    add_step procps                        "command -v pgrep"                        procps-ng                     2 "ps and pgrep, for the launcher's process list"
    add_step tzdata                        "test -e \"\${TZDIR:-/usr/share/zoneinfo}/zone.tab\"" tzdata             2 "the time zone names for the clock and the region page"
    add_step wl-clipboard                  "command -v wl-paste"                     wl-clipboard                  2 "what was copied, and its types"
    add_step jq                            "command -v jq"                           jq                            2 "the clipboard recorder's json"
    add_step grim                          "command -v grim"                         grim                          2 "screenshots and the freeze picker"
    add_step slurp                         "command -v slurp"                        slurp                         2 "the region when the shell is down"
    add_step swappy                        "command -v swappy"                       swappy                        2 "the default screenshot editor"
    add_step ffmpeg                        "command -v ffprobe"                      ffmpeg                        2 "the picker's frozen frame, video wallpapers"
    add_step libnotify                     "command -v notify-send"                  libnotify                     2 "timers, alarms and the battery speaking up"
    add_step xdg-utils                     "command -v xdg-open"                     xdg-utils                     2 "opening files and links"
    add_step fd                            "command -v fd || command -v fdfind"      fd                            2 "the launcher finding files by name"
    add_step libqalculate                  "command -v qalc"                         libqalculate                  2 "the launcher's units, dates and functions"
    add_step ripgrep                       "command -v rg"                           ripgrep                       2 "the launcher searching inside files"
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
    add_step wayland                       "pkg-config --exists wayland-client"      wayland                       2 "the wayland headers the gamma client builds against"
    add_step helpers                       "helpers_built"                           @helpers                      2 "the pty, the directory lister and the gamma client"
    add_step completion                    "completion_present"                      @completion                   2 "tab completion for the CLI, in zsh and bash"
    add_step path                          "path_present"                            @path                         2 "banditshell on your PATH: ~/.local/bin/banditshell, when nothing else provides one"
    add_step lua-api                       "lua_api_present"                         @lua-api                      2 "the Lua module for binds: the shim beside hyprland.lua and the checkout pointer"
    add_step spicy-lyrics                  "spicy_lyrics_present"                    @spicy                        2 "word-timed lyrics: Spicetify and Spicy Lyrics, in Spotify"

    add_step polkit                        "command -v pkexec"                       polkit                        2 "pkexec, so installs and uninstalls ask for your password in the shell"

    if [ "$PKG_MANAGER" = apk ]; then
        add_step gnu-userland              "gnu_userland_present"                    gnu-userland                  1 "GNU find, sed, grep, ps and setsid, in place of the busybox ones the shell's commands outgrow"
    fi

    if [ "$WANT_CHARGE_LIMIT" -eq 1 ]; then
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
    [ "$(readlink "$REPO/bin/banditshell" 2>/dev/null)" = ../cli/banditshell ] && [ -x "$REPO/bin/banditshell" ]
}

install_cli() {
    mkdir -p "$REPO/bin" && ln -sfn ../cli/banditshell "$REPO/bin/banditshell"
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

LOCAL_BIN="$HOME/.local/bin"

path_present() {
    if [ "$(readlink -f "$LOCAL_BIN/banditshell" 2>/dev/null)" = "$(readlink -f "$REPO/cli/banditshell")" ]; then
        case ":$PATH:" in
        *":$LOCAL_BIN:"*) ;;
        *) PROBE_NOTE="linked in $LOCAL_BIN, which is not on your PATH yet" ;;
        esac
        return 0
    fi
    command -v banditshell >/dev/null 2>&1
}

install_path() {
    mkdir -p "$LOCAL_BIN" && ln -sfn "$REPO/cli/banditshell" "$LOCAL_BIN/banditshell"
}

lua_api_present() {
    local state hypr
    state="${XDG_STATE_HOME:-$HOME/.local/state}/banditshell/root"
    hypr="${HYPR_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"
    [ "$(head -n 1 "$state" 2>/dev/null)" = "$REPO" ] || return 1
    if [ ! -d "$hypr" ]; then
        PROBE_NOTE="no Hyprland config yet; the shim goes in when there is one"
        return 0
    fi
    cmp -s "$REPO/api/shim.lua" "$hypr/banditshell.lua"
}

install_lua_api() {
    STEP_OUTPUT="$("$REPO/cli/banditshell" doctor api 2>&1)"
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

RUNTIME_MADE=0

cleanup() {
    [ "$RUNTIME_MADE" -eq 0 ] || rm -rf "$RUNTIME_DIR"
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
        local why
        why="$(head -n 1 "$ASKPASS_RUN/why" 2>/dev/null)"
        askpass_stop
        [ -z "$why" ] || say "  $why"
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

PKG_MANAGER=""
APT_REFRESHED=0
XBPS_SYNCED=0

PACKAGE_TABLE='
pacman                         apt-get                   dnf                     zypper                   xbps-install           apk
quickshell                     =                         =                       =                        =                      -
curl                           =                         =                       =                        =                      =
unzip                          =                         =                       =                        =                      =
fontconfig                     =                         =                       =                        =                      =
hyprland                       =                         -                       =                        -                      =
qt6-declarative                qml6-module-qtquick+qml6-module-qtquick-shapes+qml6-module-qtquick-effects  qt6-qtdeclarative       qt6-declarative-imports  qt6-declarative        qt6-qtdeclarative
qt6-multimedia                 qml6-module-qtmultimedia  qt6-qtmultimedia        qt6-multimedia-imports   qt6-multimedia         qt6-qtmultimedia
qt6-websockets                 qml6-module-qtwebsockets  qt6-qtwebsockets-devel  qt6-websockets-imports   qt6-websockets         qt6-qtwebsockets
qt6-shadertools                qt6-shader-baker          qt6-qtshadertools       qt6-shadertools-devel    qt6-shadertools-devel  qt6-qtshadertools-dev
ttf-material-symbols-variable  @material-symbols         @material-symbols       @material-symbols        @material-symbols      @material-symbols
ttf-nerd-fonts-symbols         @nerd-symbols             @nerd-symbols           @nerd-symbols            @nerd-symbols          @nerd-symbols
nodejs                         =                         =                       nodejs-default           =                      =
rsync                          =                         =                       =                        =                      =
wl-clipboard                   =                         =                       =                        =                      =
jq                             =                         =                       =                        =                      =
grim                           =                         =                       =                        =                      =
slurp                          =                         =                       =                        =                      =
swappy                         =                         =                       =                        =                      -
ffmpeg                         =                         ffmpeg-free             =                        =                      =
libnotify                      libnotify-bin             =                       libnotify-tools          =                      =
xdg-utils                      =                         =                       =                        =                      =
fd                             fd-find                   fd-find                 =                        =                      =
libqalculate                   qalc                      qalculate               qalculate                qalculate              qalc
ripgrep                        =                         =                       =                        =                      =
networkmanager                 network-manager           NetworkManager          NetworkManager           NetworkManager         networkmanager-cli
ddcutil                        =                         =                       =                        =                      =
pciutils                       =                         =                       =                        =                      =
wtype                          =                         =                       =                        =                      =
ydotool                        =                         =                       =                        -                      -
python                         python3                   python3                 python3                  python3                python3
python-gobject                 python3-gi                python3-gobject         python3-gobject          python3-gobject        py3-gobject3
python-cryptography            python3-cryptography      python3-cryptography    python3-cryptography     python3-cryptography   py3-cryptography
python-evdev                   python3-evdev             python3-evdev           python3-evdev            python3-evdev          py3-evdev
glib2                          libglib2.0-bin            =                       glib2-tools              glib                   glib
zenity                         =                         =                       =                        =                      =
qrencode                       =                         =                       =                        =                      libqrencode-tools
zxing-cpp                      zxing-cpp-tools           -                       zxing-cpp-examples       zxing-cpp-progs        zxing
librsvg                        librsvg2-bin              librsvg2-tools          rsvg-convert             librsvg-utils          rsvg-convert
gcc                            gcc+libc6-dev             =                       =                        =                      build-base
pkgconf                        =                         pkgconf-pkg-config      pkgconf-pkg-config       =                      =
util-linux                     =                         =                       =                        =                      util-linux-misc
procps-ng                      procps                    =                       procps                   =                      =
tzdata                         =                         =                       timezone                 =                      =
wayland                        libwayland-dev            wayland-devel           wayland-devel            wayland-devel          wayland-dev
polkit                         pkexec                    =                       pkexec                   =                      =
gnu-userland                   -                         -                       -                        -                      coreutils+findutils+grep+sed+gawk+procps-ng+util-linux-misc
'

detect_manager() {
    local tool word
    for word in $( (. /etc/os-release 2>/dev/null && printf '%s %s' "${ID:-}" "${ID_LIKE:-}") ); do
        case "$word" in
        arch) tool=pacman ;;
        debian | ubuntu) tool=apt-get ;;
        fedora | rhel) tool=dnf ;;
        opensuse* | suse) tool=zypper ;;
        void) tool=xbps-install ;;
        alpine) tool=apk ;;
        gentoo) tool=emerge ;;
        nixos) tool=nix-env ;;
        *) continue ;;
        esac
        if command -v "$tool" >/dev/null 2>&1; then
            PKG_MANAGER="$tool"
            return 0
        fi
    done
    for tool in pacman apt-get dnf zypper xbps-install apk emerge nix-env; do
        if command -v "$tool" >/dev/null 2>&1; then
            PKG_MANAGER="$tool"
            return 0
        fi
    done
}

package_names() {
    local column
    case "$PKG_MANAGER" in
    pacman) column=1 ;;
    apt-get) column=2 ;;
    dnf) column=3 ;;
    zypper) column=4 ;;
    xbps-install) column=5 ;;
    apk) column=6 ;;
    *) return 2 ;;
    esac
    awk -v pkg="$1" -v column="$column" '
        $1 == pkg { found = 1; name = $column }
        END {
            if (!found || name == "=") name = pkg
            if (name == "-" || name == "") exit 1
            gsub(/\+/, " ", name)
            print name
        }' <<<"$PACKAGE_TABLE"
}

package_download() {
    awk -v pkg="$1" '$1 == pkg { for (i = 2; i <= NF; i++) if ($i ~ /^@/) { print $i; exit } }' <<<"$PACKAGE_TABLE"
}

gnu_userland_present() {
    find / -maxdepth 0 -printf '' 2>/dev/null \
        && sed --version 2>/dev/null | grep -q '^sed (GNU sed)' \
        && grep --version 2>/dev/null | grep -q 'GNU grep' \
        && awk --version 2>/dev/null | grep -q 'GNU Awk' \
        && ps --version 2>/dev/null | grep -q procps \
        && setsid --help 2>&1 | grep -q -- --fork
}

install_pkg() {
    local pkg="$1" names status=0
    local -a list
    names="$(package_names "$pkg")" || status=$?
    if [ "$status" -eq 2 ] && names="$(package_download "$pkg")" && [ -n "$names" ]; then
        status=0
    fi
    case "$status" in
    1)
        STEP_OUTPUT="$pkg is not packaged for $PKG_MANAGER; install it from upstream"
        return 1
        ;;
    2)
        STEP_OUTPUT="no package manager this installer drives${PKG_MANAGER:+ ($PKG_MANAGER)}; install $pkg yourself"
        return 1
        ;;
    esac
    case "$names" in
    @nerd-symbols) install_font "$NERD_SYMBOLS_URL" "$NERD_SYMBOLS_SHA" nerd-symbols; return ;;
    @material-symbols) install_font "$MATERIAL_SYMBOLS_URL" "$MATERIAL_SYMBOLS_SHA" material-symbols; return ;;
    esac
    if ! need_root; then
        STEP_OUTPUT="no sudo, so $names was not installed"
        return 1
    fi
    read -ra list <<<"$names"
    case "$PKG_MANAGER" in
    pacman) STEP_OUTPUT="$(sudo -n pacman -S --needed --noconfirm "${list[@]}" 2>&1)" ;;
    apt-get)
        if [ "$APT_REFRESHED" -eq 0 ]; then
            sudo -n apt-get update >/dev/null 2>&1 && APT_REFRESHED=1
        fi
        STEP_OUTPUT="$(sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y "${list[@]}" 2>&1)" && return 0
        case "$STEP_OUTPUT" in
        *"Unable to locate package"* | *"has no installation candidate"*) ;;
        *) return 1 ;;
        esac
        local backports policy first="$STEP_OUTPUT"
        backports="$(. /etc/os-release 2>/dev/null && printf '%s' "${VERSION_CODENAME:-}")-backports"
        policy="$(apt-cache policy 2>/dev/null)"
        if ! grep -q " $backports/" <<<"$policy"; then
            STEP_OUTPUT="$first"$'\n'"not in the main archive; $backports may carry it: add it to your apt sources and run this again"
            return 1
        fi
        STEP_OUTPUT="$(sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -t "$backports" "${list[@]}" 2>&1)" && return 0
        STEP_OUTPUT="$first"$'\n'"$STEP_OUTPUT"
        return 1
        ;;
    dnf) STEP_OUTPUT="$(sudo -n dnf install -y "${list[@]}" 2>&1)" ;;
    zypper) STEP_OUTPUT="$(sudo -n zypper --non-interactive install "${list[@]}" 2>&1)" ;;
    xbps-install)
        local sync=-S
        [ "$XBPS_SYNCED" -eq 0 ] || sync=""
        STEP_OUTPUT="$(sudo -n xbps-install -y $sync "${list[@]}" 2>&1)" && XBPS_SYNCED=1
        ;;
    apk) STEP_OUTPUT="$(sudo -n apk add "${list[@]}" 2>&1)" ;;
    esac
}

fetch_checked() {
    local url="$1" sha="$2" out="$3" got
    curl -fsSL -o "$out" "$url" || { STEP_OUTPUT="could not download $url"; return 1; }
    got="$(sha256sum "$out" | cut -d' ' -f1)"
    [ "$got" = "$sha" ] || { STEP_OUTPUT="checksum mismatch for $url: $got"; return 1; }
}

MATERIAL_SYMBOLS_URL="https://raw.githubusercontent.com/google/material-design-icons/49d4db35df873165d6bd6ba09b063c7dafbac2f4/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
MATERIAL_SYMBOLS_SHA="32e4011709e055596eb8d2dd0f7cb547b47c1d40ac9ecb8fad54f7f7eac202e7"
NERD_SYMBOLS_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/NerdFontsSymbolsOnly.zip"
NERD_SYMBOLS_SHA="fdca3682534f6f65e1ccb2345b0362ccf67d9b8eca7c8025330946e93e2473bc"

install_font() {
    local url="$1" sha="$2" dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$3" tmp status=0
    tmp="$(mktemp -d)" || return 1
    if fetch_checked "$url" "$sha" "$tmp/download" && mkdir -p "$dest"; then
        case "$url" in
        *.zip) unzip -oq "$tmp/download" -d "$tmp/x" && cp "$tmp"/x/*.ttf "$dest/" || status=1 ;;
        *) cp "$tmp/download" "$dest/$3.ttf" || status=1 ;;
        esac
    else
        status=1
    fi
    rm -rf "$tmp"
    [ "$status" -eq 0 ] && fc-cache -f "$dest" >/dev/null 2>&1
    return "$status"
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
        @path) install_path && ok=0 ;;
        @lua-api) install_lua_api && ok=0 ;;
        @helpers) install_helpers && ok=0 ;;
        @spicy) install_spicy_lyrics && ok=0 ;;
        @charge-limit) install_charge_limit && ok=0 ;;
        *) install_pkg "$pkg" && ok=0 ;;
        esac
    fi

    if [ "$ok" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "${pkg#@}" = "$pkg" ] && ! eval "$probe" >/dev/null 2>&1; then
        ok=1
        STEP_OUTPUT="${STEP_OUTPUT:+$STEP_OUTPUT
}installed, but the check still fails: $probe"
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

OMARCHY_SYSTEM=/usr/share/omarchy
ISLAND_ADD="omarchy plugin add https://github.com/marcusbandit/banditshell-island.git --enable"

omarchy_present() {
    local dir
    for dir in "${OMARCHY_PATH:-}" "$HOME/.local/share/omarchy" "$OMARCHY_SYSTEM"; do
        [ -n "$dir" ] && [ -e "$dir/bin/omarchy-version" ] && return 0
    done
    return 1
}

can_ask() { [ -t 0 ]; }

omarchy_check() {
    [ "$BESIDE_OMARCHY" -eq 0 ] && omarchy_present || return 0
    say "Omarchy already shows your notifications, and the full banditshell would fight it for them."
    say "banditshell island is the one made for Omarchy: the notification, music and lyrics"
    say "pill, as an Omarchy plugin. Add it with:"
    say "    $ISLAND_ADD"
    say ""
    if ! can_ask; then
        say "Nothing was installed. To put the full shell beside Omarchy anyway:"
        say "    $REPO/install.sh --beside-omarchy"
        return 1
    fi
    local answer=""
    printf 'Install the full shell beside Omarchy anyway? [y/N] '
    read -r answer || true
    case "$answer" in
    [yY] | [yY][eE][sS]) BESIDE_OMARCHY=1 ;;
    *) say "Nothing was installed."; return 1 ;;
    esac
    say ""
}

release_due() {
    local config="${XDG_CONFIG_HOME:-$HOME/.config}/banditshell/config.json" stable
    RELEASE_NOTE=""
    [ -z "${BANDITSHELL_ON_RELEASE:-}" ] && [ ! -e "$config" ] || return 1
    [ "$(git -C "$REPO" symbolic-ref --quiet --short HEAD 2>/dev/null)" = main ] || return 1
    GIT_TERMINAL_PROMPT=0 git -C "$REPO" ls-remote --exit-code --heads origin stable >/dev/null 2>&1
    case $? in
    0) ;;
    2) RELEASE_NOTE="no release on GitHub yet, so this copy stays on main"; return 1 ;;
    *) RELEASE_NOTE="could not reach GitHub to find the newest release, so this copy stays on main"; return 1 ;;
    esac
    if ! GIT_TERMINAL_PROMPT=0 git -C "$REPO" fetch --quiet --no-tags origin \
        "+refs/heads/stable:refs/remotes/origin/stable" "+refs/tags/v*:refs/tags/v*" 2>/dev/null; then
        RELEASE_NOTE="could not fetch the newest release, so this copy stays on main"
        return 1
    fi
    stable="$(git -C "$REPO" rev-parse --verify --quiet refs/remotes/origin/stable)" || return 1
    [ "$stable" != "$(git -C "$REPO" rev-parse HEAD)" ] && git -C "$REPO" merge-base --is-ancestor "$stable" HEAD || return 1
    if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
        RELEASE_NOTE="this copy has edits, so it stays on main"
        return 1
    fi
}

checkout_release() {
    local tag
    if ! release_due; then
        [ -z "$RELEASE_NOTE" ] || say "  $RELEASE_NOTE"
        return 1
    fi
    tag="$(git -C "$REPO" describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude 'v*-*' refs/remotes/origin/stable 2>/dev/null || echo stable)"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  would check out $tag, the newest release"
        return 1
    fi
    git -C "$REPO" reset --quiet --keep refs/remotes/origin/stable || return 1
    say "  checked out $tag, the newest release"
}

main() {
    if [ "$LIST_ONLY" -eq 0 ]; then
        omarchy_check || exit 1
        if checkout_release; then
            local arg
            local -a args=()
            for arg in "${INSTALL_ARGS[@]}"; do
                [ "$arg" = --beside-omarchy ] || args+=("$arg")
            done
            BANDITSHELL_ON_RELEASE=1 BANDITSHELL_BESIDE_OMARCHY="$BESIDE_OMARCHY" exec bash "$REPO/install.sh" "${args[@]}"
        fi
    fi
    detect_manager
    build_table
    local total="${#STEP_NAME[@]}"

    if [ "$LIST_ONLY" -eq 1 ]; then
        local i names
        if package_names curl >/dev/null; then
            printf 'packages from: %s\n' "$PKG_MANAGER"
        else
            printf "packages from: nothing this installer drives%s; the names below are Arch's\n" "${PKG_MANAGER:+ ($PKG_MANAGER is here)}"
        fi
        printf '%-32s %-6s %s\n' NAME PHASE WHAT
        for ((i = 0; i < total; i++)); do
            names=""
            case "${STEP_PKG[$i]}" in
            @*) ;;
            *)
                if names="$(package_names "${STEP_PKG[$i]}")"; then
                    case "$names" in @*) names="  [downloaded]" ;; *) names="  [$names]" ;; esac
                elif [ $? -eq 2 ]; then
                    names="  [${STEP_PKG[$i]} on Arch]"
                else
                    names="  [not packaged here]"
                fi
                ;;
            esac
            printf '%-32s %-6s %s%s\n' "${STEP_NAME[$i]}" "${STEP_PHASE[$i]}" "${STEP_WHAT[$i]}" "$names"
        done
        exit 0
    fi

    if ! mkdir -p "$RUNTIME_DIR" 2>/dev/null || [ ! -w "$RUNTIME_DIR" ]; then
        RUNTIME_DIR="$(mktemp -d)"
        RUNTIME_MADE=1
        PROGRESS="$RUNTIME_DIR/banditshell-install.jsonl"
        ASKPASS_RUN="$RUNTIME_DIR/banditshell-askpass"
    fi
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
    say "    your binds:     local bs = require(\"banditshell\") in your Hyprland lua;"
    say "                    $REPO/docs/hyprland-binds.example.lua"
    say "    run it now:     $REPO/bin/banditshell start"
    say "    see it live:    $REPO/bin/banditshell dev run"
    say "    what it does:   $REPO/bin/banditshell help"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi
