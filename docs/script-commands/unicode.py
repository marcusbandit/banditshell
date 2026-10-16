#!/usr/bin/env python3

# @raycast.title Unicode
# @raycast.packageName Examples
# @banditshell.mode list

import json
import sys
import unicodedata

words = " ".join(sys.argv[1:]).upper().split()
items = []
if words:
    for point in range(0x20, 0x110000):
        character = chr(point)
        name = unicodedata.name(character, "")
        if name and unicodedata.category(character)[0] not in "MC" and all(word in name for word in words):
            items.append({
                "uid": f"{point:04X}",
                "title": name.title(),
                "subtitle": f"U+{point:04X}",
                "icon": character,
                "copy": character,
            })
            if len(items) == 50:
                break

print(json.dumps({"items": items}))
