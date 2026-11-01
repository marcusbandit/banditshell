import datetime
import json
import os
import sys

HABITS = [h.strip() for h in (os.environ.get("BANDITSHELL_PREF_HABITS") or "Read, Stretch, Drink water").split(",") if h.strip()]
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "banditshell-streaks.json")
WORDS = ["habit", "habits", "streak", "today", "done"]


def send(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def load():
    try:
        with open(STATE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(data):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".new", "w") as f:
        json.dump(data, f)
    os.replace(STATE + ".new", STATE)


def key(habit):
    return habit.lower().replace(" ", "-")


def days(done, today, count):
    return [(today - datetime.timedelta(days=n)).isoformat() in done for n in range(count - 1, -1, -1)]


def run(done, today):
    day = today if today.isoformat() in done else today - datetime.timedelta(days=1)
    n = 0
    while day.isoformat() in done:
        n += 1
        day -= datetime.timedelta(days=1)
    return n


def best(done):
    longest = 0
    for start in done:
        day = datetime.date.fromisoformat(start)
        if (day - datetime.timedelta(days=1)).isoformat() in done:
            continue
        n = 0
        while day.isoformat() in done:
            n += 1
            day += datetime.timedelta(days=1)
        longest = max(longest, n)
    return longest


def habit_item(habit, data, today):
    done = set(data.get(key(habit), []))
    streak = run(done, today)
    finished = today.isoformat() in done
    return {
        "id": key(habit),
        "title": habit,
        "subtitle": f"{streak} days in a row" if streak else "no streak yet",
        "icon": "check_circle" if finished else "radio_button_unchecked",
        "keywords": WORDS,
        "qml": "StreakRow.qml",
        "preview": {"qml": "StreakPreview.qml"},
        "props": {"days": days(done, today, 10), "month": days(done, today, 35), "streak": streak, "best": best(done), "done": finished},
        "actions": [{"id": "toggle", "title": "Not done today" if finished else "Done today", "icon": "check"}],
    }


def summary_item(data, today):
    left = [h for h in HABITS if today.isoformat() not in data.get(key(h), [])]
    finished = len(HABITS) - len(left)
    return {
        "id": "today",
        "title": f"{finished} of {len(HABITS)} done today",
        "subtitle": today.strftime("%A %d %B"),
        "text": f"Still to do: {', '.join(left)}." if left else "Everything is done for today.",
        "icon": "event_available",
        "height": 2,
        "tags": ["all done"] if not left else [f"{len(left)} to go"],
        "keywords": WORDS,
        "copy": f"{finished} of {len(HABITS)} habits done today",
    }


def results(seq, text, prefixed):
    data = load()
    today = datetime.date.today()
    wanted = [h for h in HABITS if not prefixed or text.lower() in h.lower()]
    items = ([summary_item(data, today)] if not text or not prefixed else []) + [habit_item(h, data, today) for h in wanted]
    return {"type": "results", "seq": seq, "items": items}


def toggle(habit_id):
    habit = next((h for h in HABITS if key(h) == habit_id), None)
    if not habit:
        return
    data = load()
    today = datetime.date.today()
    done = set(data.get(habit_id, []))
    done.symmetric_difference_update([today.isoformat()])
    data[habit_id] = sorted(done)
    save(data)
    send({"type": "update", "item": habit_item(habit, data, today)})
    send({"type": "update", "item": summary_item(data, today)})


for line in sys.stdin:
    try:
        message = json.loads(line)
    except ValueError:
        continue
    kind = message.get("type")
    if kind == "query":
        send(results(message["seq"], message.get("text", ""), message.get("prefixed", False)))
    elif kind == "activate" and message.get("action") == "toggle":
        toggle(message.get("id", ""))
