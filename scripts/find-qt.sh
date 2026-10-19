#!/usr/bin/env bash

set -u

usage() {
    echo "usage: find-qt.sh tool <name> | module <QtModule>" >&2
    exit 2
}

query() {
    local probe key value
    for probe in qmake6 qtpaths6 qmake-qt6 qtpaths-qt6; do
        command -v "$probe" >/dev/null 2>&1 || continue
        for key in "$@"; do
            case "$probe" in
            qmake*) value=$("$probe" -query "$key" 2>/dev/null) ;;
            *) value=$("$probe" --query "$key" 2>/dev/null) ;;
            esac
            [ -n "$value" ] && printf '%s\n' "$value"
        done
        return 0
    done
}

prefixes() {
    local dir
    printf '%s\n' /usr/lib/qt6 /usr/lib64/qt6 /usr/libexec/qt6 /usr/local/lib/qt6
    for dir in /usr/lib/*-linux-gnu*/qt6; do
        [ -d "$dir" ] && printf '%s\n' "$dir"
    done
}

find_tool() {
    local name=$1 dir
    for dir in "${name}6" "$name-qt6" "$name"; do
        command -v "$dir" 2>/dev/null && return 0
    done
    while IFS= read -r dir; do
        [ -x "$dir/$name" ] && { printf '%s\n' "$dir/$name"; return 0; }
    done < <(query QT_HOST_BINS QT_INSTALL_BINS QT_HOST_LIBEXECS QT_INSTALL_LIBEXECS; prefixes | sed 's|$|/bin|'; prefixes)
    return 1
}

find_module() {
    local module=${1//.//} dir
    while IFS= read -r dir; do
        [ -n "$dir" ] && [ -d "$dir/$module" ] && { printf '%s\n' "$dir/$module"; return 0; }
    done < <(
        printf '%s\n' "${QML_IMPORT_PATH:-}" "${QML2_IMPORT_PATH:-}" "${NIXPKGS_QT6_QML_IMPORT_PATH:-}" | tr ':' '\n'
        query QT_INSTALL_QML
        prefixes | sed 's|$|/qml|'
    )
    return 1
}

[ $# -eq 2 ] || usage
case "$1" in
tool) find_tool "$2" ;;
module) find_module "$2" ;;
*) usage ;;
esac
