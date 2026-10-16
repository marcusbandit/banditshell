pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "translation.js" as Translation

Singleton {
    id: root

    readonly property var settings: Config.values.launcher.online ?? {}
    readonly property bool enabled: root.settings.translate !== false
    readonly property string preferred: Translation.languageCode(root.settings.translateTo ?? "") || Translation.localeCode(Qt.locale().name) || "en"
    readonly property string fallback: root.preferred === "en" ? "" : "en"

    readonly property string script: `
        q="$1"
        to="$2"
        ask() {
            out=$(curl -fsS --max-time 5 -A "Mozilla/5.0" -G --data-urlencode "q=$q" -d sl=auto -d "tl=$to" "$@" 2>/dev/null) || return 1
            [ "\${out#\\[}" != "$out" ] || return 1
            printf '%s\\n' "$out"
        }
        ask -d client=gtx -d dt=t https://translate.googleapis.com/translate_a/single && exit 0
        ask -d client=dict-chrome-ex https://clients5.google.com/translate_a/t && exit 0
        case "$q" in -*) exit 1 ;; esac
        command -v trans >/dev/null 2>&1 && exec trans -brief -no-ansi -no-autocorrect ":$to" "$q"
        exit 1
    `

    property Lookup lookup: Lookup {
        delay: 450
        keep: 200
        file: `${Config.cacheDir}/translations.json`
        commandFor: key => {
            const asked = Translation.splitKey(key);
            return ["sh", "-c", root.script, "sh", asked.text, asked.to];
        }
        read: text => Translation.readAnswer(text)
    }
}
