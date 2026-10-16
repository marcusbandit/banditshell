#!/bin/sh

# @raycast.schemaVersion 1
# @raycast.title Hello
# @raycast.mode compact
# @raycast.icon 👋
# @raycast.packageName Examples
# @raycast.argument1 { "type": "text", "placeholder": "name", "optional": true }

echo "Hello, ${1:-world}. It is $(date +%H:%M)."
