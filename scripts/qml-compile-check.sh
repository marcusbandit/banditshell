#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
-h | --help)
    echo "usage: qml-compile-check.sh [checkout]"
    echo "  compile every QML file of the checkout in a fresh, offscreen Quickshell"
    echo "  engine with its own HOME and runtime dir and no D-Bus, Wayland or"
    echo "  Hyprland; prints FAIL lines and CHECKED <n> failures, exits 1 on any"
    exit 0
    ;;
esac

root="$(cd "${1:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..}" && pwd)"
command -v qs >/dev/null || { echo "qml-compile-check.sh: qs not found" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

probe() {
    local dir="$1" files code=0
    files=$(cd "$dir" && find -L . -name '*.qml' ! -name probe.qml | sed 's|^\./||' | sort | sed 's/.*/"&"/' | paste -sd, -)
    mkdir -p "$dir.home" "$dir.runtime"
    chmod 700 "$dir.runtime"
    cat >"$dir/probe.qml" <<QML
import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property var files: [$files]

    function check(): int {
        let failures = 0;
        for (const file of root.files) {
            const component = Qt.createComponent(Qt.resolvedUrl(file), Component.PreferSynchronous);
            if (component.status === Component.Ready)
                continue;
            const error = component.status === Component.Error ? component.errorString().trim() : "status " + component.status;
            if (/backend loaded|No .*backend/.test(error))
                continue;
            failures++;
            console.log("FAIL", file, error);
        }
        console.log("CHECKED", failures, "failures in", root.files.length, "files");
        return failures;
    }

    Timer {
        running: true
        interval: 0
        onTriggered: Qt.exit(root.check() > 0 ? 1 : 0)
    }
}
QML
    (cd "$dir" && env -i \
        PATH="$PATH" \
        HOME="$dir.home" \
        XDG_RUNTIME_DIR="$dir.runtime" \
        LANG=C.UTF-8 \
        QT_QPA_PLATFORM=offscreen \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent \
        timeout 120 qs -p "$dir/probe.qml") >"$dir.log" 2>&1 || code=$?
    sed 's/\x1b\[[0-9;]*m//g' "$dir.log" >"$dir.plain"
    grep -E 'FAIL|CHECKED' "$dir.plain" | sed "s|^.*qml: |${2}|" || true
    if ! grep -q 'CHECKED' "$dir.plain"; then
        echo "qml-compile-check.sh: the probe never reported (qs exit $code):" >&2
        tail -20 "$dir.plain" >&2
        return 1
    fi
    return "$code"
}

mkdir -p "$work/shell" "$work/installer"
for entry in config services components modules previews shell.qml preview.qml; do
    ln -s "$root/$entry" "$work/shell/$entry"
done
for entry in "$root"/installer/*; do
    ln -s "$entry" "$work/installer/"
done

status=0
probe "$work/shell" "" || status=1
probe "$work/installer" "installer: " || status=1
exit "$status"
