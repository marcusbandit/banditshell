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
                "actions": [
                    {"id": "shout", "title": "Shout it", "icon": "campaign"},
                    {"id": "details", "title": "Details", "icon": "info"},
                    {"id": "letters", "title": "Letters", "icon": "abc"},
                    {"id": "write", "title": "Write a greeting", "icon": "edit"},
                ],
            }
        ],
    }


def details(who):
    return {
        "kind": "detail",
        "id": f"details:{who}",
        "title": f"{GREETING}, {who}",
        "text": f"A greeting for {who}, written by a plugin in Python.",
        "facts": [
            {"label": "Letters", "value": str(len(who))},
            {"label": "Vowels", "value": str(sum(c in "aeiou" for c in who.lower()))},
        ],
        "actions": [{"id": "copy", "title": "Copy", "icon": "content_copy", "copy": f"{GREETING}, {who}"}],
    }


def letters(who):
    return {
        "kind": "list",
        "id": f"letters:{who}",
        "title": f"The letters of {who}",
        "placeholder": "Filter letters",
        "items": [
            {"id": f"{i}", "title": c, "subtitle": f"letter {i + 1}", "copy": c}
            for i, c in enumerate(who)
        ],
    }


def form(who):
    return {
        "kind": "form",
        "id": "write",
        "title": "Write a greeting",
        "fields": [
            {"key": "name", "type": "text", "title": "Who", "value": who, "required": True},
            {"key": "style", "type": "choice", "title": "Style", "choices": [{"value": "plain", "title": "Plain"}, {"value": "loud", "title": "Loud"}]},
            {"key": "sign", "type": "toggle", "title": "Sign it"},
        ],
        "submit": "Copy greeting",
    }


def written(values):
    text = f"{GREETING}, {values.get('name', '')}"
    if values.get("style") == "loud":
        text = text.upper() + "!"
    if values.get("sign"):
        text += " (from a plugin)"
    return text


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
    elif kind == "activate" and not message.get("view"):
        who = message["id"].split(":", 1)[1]
        action = message.get("action")
        if action == "shout":
            send({"type": "effect", "do": "copy", "text": f"{GREETING.upper()}, {who.upper()}!"})
        elif action == "details":
            send({"type": "view", "view": details(who)})
        elif action == "letters":
            send({"type": "view", "view": letters(who)})
        elif action == "write":
            send({"type": "view", "view": form(who)})
    elif kind == "submit" and message.get("view") == "write":
        send({"type": "effect", "do": "copy", "text": written(message.get("values", {}))})
