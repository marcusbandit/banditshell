pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "dictionary.js" as Words

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).define !== false

    property real primaryDownAt: 0
    readonly property real primaryRest: 10 * 60 * 1000

    readonly property string script: `
        word="$1"
        backup=$(mktemp) || exit 1
        first=$(mktemp) || exit 1
        pids=""
        cleanup() {
            [ -n "$pids" ] && kill $pids 2>/dev/null
            rm -f "$backup" "$first"
        }
        trap cleanup EXIT
        trap 'exit 143' TERM
        trap 'exit 130' INT
        curl -fsS --max-time 6 -A "banditshell launcher" "https://en.wiktionary.org/api/rest_v1/page/definition/$word" >"$backup" 2>/dev/null &
        backing=$!
        pids=$backing
        if [ "$2" = 1 ]; then
            curl -fsS --connect-timeout 1 --max-time 2.5 "https://api.dictionaryapi.dev/api/v2/entries/en/$word" >"$first" 2>/dev/null &
            asking=$!
            pids="$pids $asking"
            wait "$asking"
            status=$?
            if [ -s "$first" ] && [ "$(head -c 1 "$first")" = "[" ]; then
                cat "$first"
                exit 0
            fi
            [ "$status" -eq 22 ] || echo "@@ down"
        fi
        wait "$backing"
        [ -s "$backup" ] || exit 1
        cat "$backup"
    `

    property Lookup lookup: Lookup {
        delay: 450
        keep: 200
        file: `${Config.cacheDir}/online/definitions.json`
        commandFor: word => ["sh", "-c", root.script, "sh", encodeURIComponent(word), Date.now() - root.primaryDownAt > root.primaryRest ? "1" : "0"]
        read: (text, word) => {
            const down = text.indexOf("@@ down\n") === 0;
            if (down)
                root.primaryDownAt = Date.now();
            return Words.readAnswer(down ? text.slice(8) : text, word);
        }
    }
}
