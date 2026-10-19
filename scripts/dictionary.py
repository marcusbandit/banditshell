#!/usr/bin/env python3
import json
import os
import shutil
import signal
import sqlite3
import sys
import tempfile
import time
import urllib.request
import zipfile

SOURCE = "https://github.com/globalwordnet/english-wordnet/releases/download/2025-edition/english-wordnet-2025-json.zip"
VERSION = 2
PARTS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}
ENDINGS = [
    ("s", ""), ("ses", "s"), ("xes", "x"), ("zes", "z"), ("ches", "ch"), ("shes", "sh"), ("men", "man"), ("ies", "y"),
    ("es", "e"), ("es", ""), ("ed", "e"), ("ed", ""), ("ing", "e"), ("ing", ""),
    ("er", ""), ("est", ""), ("er", "e"), ("est", "e"), ("ier", "y"), ("iest", "y"),
]
MOST_EXAMPLES = 2
MOST_RELATED = 8
MOST_COMPLETIONS = 6
STALE = 60 * 60


def say(message):
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def sentence(text):
    text = str(text or "").strip()
    return text[:1].upper() + text[1:]


def example_text(example):
    return example.get("text", "") if isinstance(example, dict) else str(example)


def lemma_of(sense_id):
    return sense_id.split("%", 1)[0].replace("_", " ")


def read_synsets(archive):
    synsets = {}
    for name in archive.namelist():
        base = os.path.basename(name)
        if not base.endswith(".json") or base.startswith(("entries-", "frames")):
            continue
        for synset_id, synset in json.loads(archive.read(name)).items():
            synsets[synset_id] = (
                sentence((synset.get("definition") or [""])[0]),
                [example_text(e) for e in synset.get("example", [])[:MOST_EXAMPLES]],
                synset.get("members", []),
                synset.get("similar", []),
            )
    return synsets


def phonetic_of(entries):
    for entry in entries:
        sounds = entry.get("pronunciation", [])
        chosen = next((s for s in sounds if s.get("variety") == "US"), None) or (sounds[0] if sounds else None)
        if chosen and chosen.get("value"):
            return f"/{chosen['value']}/"
    return ""


def unique(words, leave_out):
    seen = {leave_out.lower()}
    kept = []
    for word in words:
        word = word.replace("_", " ")
        if word.lower() not in seen:
            seen.add(word.lower())
            kept.append(word)
    return kept[:MOST_RELATED]


def entry_of(word, entries, synsets):
    groups = {}
    for pos, entry in entries:
        part = PARTS.get(pos.split("-")[0], pos)
        senses = groups.setdefault(part, [])
        for sense in entry.get("sense", []):
            synset = synsets.get(sense.get("synset"))
            if not synset:
                continue
            text, examples, members, similar = synset
            near = [m for s in similar for m in synsets.get(s, ("", [], [], []))[2]]
            senses.append({
                "text": text,
                "examples": examples,
                "synonyms": unique(members + near, word),
                "antonyms": unique([lemma_of(a) for a in sense.get("antonym", [])], word),
            })
    ordered = sorted(((part, senses) for part, senses in groups.items() if senses), key=lambda group: -len(group[1]))
    forms = []
    for _, entry in entries:
        forms += [f for f in entry.get("form", []) if f not in forms]
    return {
        "word": word,
        "phonetic": phonetic_of([entry for _, entry in entries]),
        "forms": forms,
        "groups": [{"part": part, "senses": senses} for part, senses in ordered],
    }


def build(db, source):
    os.makedirs(os.path.dirname(db), exist_ok=True)
    for old in os.listdir(os.path.dirname(db)):
        path = os.path.join(os.path.dirname(db), old)
        if old.startswith("dictionary-") and time.time() - os.path.getmtime(path) > STALE:
            shutil.rmtree(path, ignore_errors=True)
    work = tempfile.mkdtemp(prefix="dictionary-", dir=os.path.dirname(db))
    try:
        download = os.path.join(work, "wordnet.zip")
        if os.path.isfile(source):
            shutil.copyfile(source, download)
        else:
            request = urllib.request.Request(source, headers={"User-Agent": "banditshell launcher"})
            with urllib.request.urlopen(request, timeout=120) as reply, open(download, "wb") as out:
                shutil.copyfileobj(reply, out)
        with zipfile.ZipFile(download) as archive:
            synsets = read_synsets(archive)
            words = {}
            for name in archive.namelist():
                if os.path.basename(name).startswith("entries-"):
                    for word, poses in json.loads(archive.read(name)).items():
                        words.setdefault(word.lower(), []).append((word, poses))
        fresh = os.path.join(work, "dictionary.sqlite")
        con = sqlite3.connect(fresh)
        con.executescript("""
            CREATE TABLE entries (key TEXT PRIMARY KEY, rank INTEGER, data TEXT) WITHOUT ROWID;
            CREATE TABLE forms (form TEXT, key TEXT, PRIMARY KEY (form, key)) WITHOUT ROWID;
            CREATE TABLE meta (name TEXT PRIMARY KEY, value TEXT);
        """)
        for key, spellings in words.items():
            spellings.sort(key=lambda spelling: spelling[0] != key)
            entries = [(pos, entry) for _, poses in spellings for pos, entry in poses.items()]
            entry = entry_of(spellings[0][0], entries, synsets)
            if not entry["groups"]:
                continue
            rank = sum(len(g["senses"]) for g in entry["groups"]) * 10 - key.count(" ") * 5
            con.execute("INSERT INTO entries VALUES (?, ?, ?)", (key, rank, json.dumps(entry, ensure_ascii=False)))
            con.executemany("INSERT OR IGNORE INTO forms VALUES (?, ?)", [(f.lower(), key) for f in entry["forms"]])
        con.execute("CREATE INDEX ranked ON entries (key, rank)")
        con.execute("INSERT INTO meta VALUES ('version', ?)", (str(VERSION),))
        con.commit()
        con.close()
        os.replace(fresh, db)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def ready(db):
    if not os.path.isfile(db):
        return False
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        found = con.execute("SELECT value FROM meta WHERE name = 'version'").fetchone()
        con.close()
        return found is not None and found[0] == str(VERSION)
    except sqlite3.Error:
        return False


def stems(word):
    for ending, replacement in ENDINGS:
        stem = word[: -len(ending)]
        if not word.endswith(ending) or len(stem + replacement) < 3:
            continue
        yield stem + replacement
        if not replacement and len(stem) > 3 and stem[-1] == stem[-2] and stem[-1] not in "aeiouls":
            yield stem[:-1]


class Dictionary:
    def __init__(self, db):
        self.con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)

    def entry(self, key):
        found = self.con.execute("SELECT data FROM entries WHERE key = ?", (key,)).fetchone()
        return json.loads(found[0]) if found else None

    def lookup(self, word):
        key = " ".join(word.lower().split())
        found = self.entry(key)
        if found:
            return found
        for (lemma,) in self.con.execute("SELECT key FROM forms WHERE form = ?", (key,)).fetchall():
            found = self.entry(lemma)
            if found:
                return dict(found, asked=word)
        for stem in stems(key):
            found = self.entry(stem)
            if found:
                return dict(found, asked=word)
        return None

    def complete(self, word, leave_out):
        key = " ".join(word.lower().split())
        if len(key) < 2:
            return []
        keys = self.con.execute(
            "SELECT key FROM entries INDEXED BY ranked WHERE key > ? AND key < ? ORDER BY rank DESC, length(key) LIMIT ?",
            (key, key + "\uffff", MOST_COMPLETIONS + 1),
        ).fetchall()
        return [self.entry(k) for (k,) in keys if k != leave_out][:MOST_COMPLETIONS]


def serve(db, source, build_missing=True):
    if not ready(db):
        if not build_missing:
            return 3
        say({"state": "building"})
        try:
            build(db, source)
        except Exception as error:
            say({"state": "failed", "error": str(error)})
            return 1
    words = Dictionary(db)
    say({"state": "ready"})
    for line in sys.stdin:
        try:
            ask = json.loads(line)
        except ValueError:
            continue
        word = str(ask.get("word", ""))
        entry = words.lookup(word)
        complete = bool(ask.get("complete"))
        completions = words.complete(word, (entry or {}).get("word", "").lower()) if complete else []
        say({"word": word, "entry": entry, "completions": completions, "completed": complete})
    return 0


def main(argv):
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if len(argv) >= 2 and argv[0] == "serve":
        return serve(argv[1], argv[2] if len(argv) > 2 else SOURCE)
    if len(argv) >= 2 and argv[0] == "serve-built":
        return serve(argv[1], SOURCE, build_missing=False)
    if len(argv) >= 2 and argv[0] == "build":
        build(argv[1], argv[2] if len(argv) > 2 else SOURCE)
        return 0
    if len(argv) >= 3 and argv[0] == "lookup":
        print(json.dumps(Dictionary(argv[1]).lookup(" ".join(argv[2:])), ensure_ascii=False, indent=1))
        return 0
    sys.stderr.write("usage: dictionary.py serve|serve-built|build <db> [source] | lookup <db> <word>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
