import json
import os
import sys

WORD = os.environ.get("BANDITSHELL_PLUGIN_ID", "plugin")


def send(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def results(seq, text):
    typed = text.strip()
    if not typed:
        return {"type": "results", "seq": seq, "items": [{"id": "hint", "title": f"Type after {WORD} to see rows here"}]}
    return {
        "type": "results",
        "seq": seq,
        "items": [
            {
                "id": f"echo:{typed}",
                "title": typed,
                "subtitle": "Enter copies it, the actions menu has more",
                "copy": typed,
                "actions": [{"id": "count", "title": "Count the letters", "icon": "tag"}],
            }
        ],
    }


for line in sys.stdin:
    try:
        message = json.loads(line)
    except ValueError:
        continue
    kind = message.get("type")
    if kind == "query":
        send(results(message["seq"], message.get("text", "")))
    elif kind == "complete" and message["id"].startswith("echo:"):
        send({"type": "fill", "text": f"{WORD} {message['id'][5:]} "})
    elif kind == "activate" and message.get("action") == "count":
        typed = message["id"][5:]
        send({"type": "effect", "do": "notify", "title": WORD, "body": f"{len(typed)} letters"})
