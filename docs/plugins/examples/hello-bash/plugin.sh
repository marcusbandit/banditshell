#!/usr/bin/env bash
set -u

field() {
    sed -n "s/.*\"$1\":\(\"\(\([^\"\\\\]\|\\\\.\)*\)\"\|\([0-9]*\)\).*/\2\4/p" <<<"$2"
}

while IFS= read -r line; do
    case "$(field type "$line")" in
    query)
        seq=$(field seq "$line")
        text=$(field text "$line")
        [ -n "$text" ] || text=world
        printf '{"type":"results","seq":%s,"items":[{"id":"hello:%s","title":"Hello, %s","subtitle":"Enter copies it","icon":"waving_hand","copy":"Hello, %s"}]}\n' \
            "$seq" "$text" "$text" "$text"
        ;;
    complete)
        id=$(field id "$line")
        printf '{"type":"fill","text":"hello %s "}\n' "${id#hello:}"
        ;;
    activate)
        printf '{"type":"effect","do":"notify","title":"Hello","body":"from bash"}\n'
        ;;
    esac
done
