#!/usr/bin/env bash
set -u

word="${BANDITSHELL_PLUGIN_ID:-plugin}"

field() {
    sed -n "s/.*\"$1\":\(\"\(\([^\"\\\\]\|\\\\.\)*\)\"\|\([0-9]*\)\).*/\2\4/p" <<<"$2"
}

while IFS= read -r line; do
    case "$(field type "$line")" in
    query)
        seq=$(field seq "$line")
        text=$(field text "$line")
        if [ -z "$text" ]; then
            printf '{"type":"results","seq":%s,"items":[{"id":"hint","title":"Type after %s to see rows here"}]}\n' "$seq" "$word"
        else
            printf '{"type":"results","seq":%s,"items":[{"id":"echo:%s","title":"%s","subtitle":"Enter copies it","copy":"%s"}]}\n' "$seq" "$text" "$text" "$text"
        fi
        ;;
    complete)
        id=$(field id "$line")
        printf '{"type":"fill","text":"%s %s "}\n' "$word" "${id#echo:}"
        ;;
    esac
done
