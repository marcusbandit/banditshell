#!/usr/bin/env bash
set -euo pipefail

DIR="${BANDITSHELL_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
cd "$DIR"

for dir in config services components components/blob components/marks modules modules/*/ modules/*/*/ previews; do
    dir="${dir%/}"
    qmls=$(find "$dir" -maxdepth 1 -name '*.qml' | sort) || continue
    [ -n "$qmls" ] || continue
    mod="qs.${dir//\//.}"
    {
        printf 'module %s\n' "$mod"
        for qml in $qmls; do
            name=$(basename "$qml" .qml)
            if [ "$(head -1 "$qml")" = "pragma Singleton" ]; then
                printf 'singleton %s 1.0 %s\n' "$name" "$(basename "$qml")"
            else
                printf '%s 1.0 %s\n' "$name" "$(basename "$qml")"
            fi
        done
    } > "$dir/qmldir"
    echo "wrote $dir/qmldir"
done
