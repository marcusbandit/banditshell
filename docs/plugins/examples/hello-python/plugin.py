import json
import os
import sys

GREETING = os.environ.get("BANDITSHELL_PREF_GREETING") or "Hello"


def send(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def results(seq, text):
    who = text.strip() or "world"
    return {
        "type": "results",
        "seq": seq,
        "items": [
            {
                "id": f"greet:{who}",
                "title": f"{GREETING}, {who}",
                "subtitle": f"{len(who)} letters · Enter copies it",
                "icon": "waving_hand",
                "copy": f"{GREETING}, {who}",
                "actions": [{"id": "shout", "title": "Shout it", "icon": "campaign"}],
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
    elif kind == "complete":
        send({"type": "fill", "text": f"greet {message['id'].split(':', 1)[1]} "})
    elif kind == "activate" and message.get("action") == "shout":
        who = message["id"].split(":", 1)[1]
        send({"type": "effect", "do": "copy", "text": f"{GREETING.upper()}, {who.upper()}!"})
