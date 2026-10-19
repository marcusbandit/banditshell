#!/usr/bin/env python3
import glob
import hashlib
import json
import os
import sqlite3
import sys
import time
from urllib.parse import quote, urlsplit

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
FLATPAK = os.path.join(HOME, ".var", "app")

MOZILLA = [
    ("Zen", os.path.join(HOME, ".zen")),
    ("Zen", os.path.join(FLATPAK, "app.zen_browser.zen", ".zen")),
    ("Firefox", os.path.join(HOME, ".mozilla", "firefox")),
    ("Firefox", os.path.join(FLATPAK, "org.mozilla.firefox", ".mozilla", "firefox")),
    ("Firefox", os.path.join(HOME, "snap", "firefox", "common", ".mozilla", "firefox")),
    ("LibreWolf", os.path.join(HOME, ".librewolf")),
    ("LibreWolf", os.path.join(FLATPAK, "io.gitlab.librewolf-community", ".librewolf")),
    ("Floorp", os.path.join(HOME, ".floorp")),
    ("Waterfox", os.path.join(HOME, ".waterfox")),
]

CHROMIUM = [
    ("Chromium", os.path.join(CONFIG, "chromium")),
    ("Chromium", os.path.join(FLATPAK, "org.chromium.Chromium", "config", "chromium")),
    ("Chromium", os.path.join(HOME, "snap", "chromium", "common", "chromium")),
    ("Chrome", os.path.join(CONFIG, "google-chrome")),
    ("Chrome", os.path.join(FLATPAK, "com.google.Chrome", "config", "google-chrome")),
    ("Brave", os.path.join(CONFIG, "BraveSoftware", "Brave-Browser")),
    ("Brave", os.path.join(FLATPAK, "com.brave.Browser", "config", "BraveSoftware", "Brave-Browser")),
    ("Vivaldi", os.path.join(CONFIG, "vivaldi")),
    ("Edge", os.path.join(CONFIG, "microsoft-edge")),
    ("Thorium", os.path.join(CONFIG, "thorium")),
]

HISTORY_LIMIT = 1500
BOOKMARK_LIMIT = 5000
PLACES_LIMIT = 4000
ICON_LIMIT = 300
CHROME_EPOCH_MS = 11644473600000
WEB = ("http://", "https://")


def host_of(url):
    try:
        host = (urlsplit(url).hostname or "").lower()
    except ValueError:
        return ""
    return host[4:] if host.startswith("www.") else host


def profiles():
    found = []
    for browser, root in MOZILLA:
        for places in sorted(glob.glob(os.path.join(glob.escape(root), "*", "places.sqlite"))):
            found.append(("mozilla", browser, os.path.dirname(places)))
    for browser, root in CHROMIUM:
        for history in sorted(glob.glob(os.path.join(glob.escape(root), "*", "History"))):
            found.append(("chromium", browser, os.path.dirname(history)))
    return found


def watched(kind, folder):
    names = ["places.sqlite", "places.sqlite-wal"] if kind == "mozilla" else ["History", "Bookmarks"]
    return [os.path.join(folder, n) for n in names]


def signature(kind, folder):
    out = []
    for path in watched(kind, folder):
        try:
            stat = os.stat(path)
        except OSError:
            continue
        out.append([path, int(stat.st_mtime), stat.st_size])
    return out


def opened(path):
    if not os.path.isfile(path):
        return None
    try:
        return sqlite3.connect("file:" + quote(os.path.abspath(path)) + "?mode=ro&immutable=1", uri=True)
    except sqlite3.Error:
        return None


def mozilla_places(browser, folder):
    connection = opened(os.path.join(folder, "places.sqlite"))
    if not connection:
        return [], [], None
    bookmarks, history = [], []
    try:
        for url, title, visits, last in connection.execute(
            "SELECT p.url, COALESCE(NULLIF(b.title, ''), p.title), p.visit_count, p.last_visit_date "
            "FROM moz_bookmarks b JOIN moz_places p ON p.id = b.fk WHERE b.type = 1 LIMIT ?", (BOOKMARK_LIMIT,)):
            if url and url.startswith(WEB):
                bookmarks.append(place(url, title, visits, (last or 0) // 1000, True, browser))
        for url, title, visits, last in connection.execute(
            "SELECT url, title, visit_count, last_visit_date FROM moz_places "
            "WHERE hidden = 0 AND visit_count > 0 AND (url LIKE 'http://%' OR url LIKE 'https://%') "
            "ORDER BY frecency DESC LIMIT ?", (HISTORY_LIMIT,)):
            history.append(place(url, title, visits, (last or 0) // 1000, False, browser))
    except sqlite3.Error:
        pass
    connection.close()
    return bookmarks, history, ("mozilla", os.path.join(folder, "favicons.sqlite"))


def chromium_nodes(node, browser, out):
    if isinstance(node, dict):
        if node.get("type") == "url" and str(node.get("url", "")).startswith(WEB):
            out.append(place(node["url"], node.get("name", ""), 0, 0, True, browser))
        for child in node.get("children", []) or []:
            chromium_nodes(child, browser, out)


def chromium_places(browser, folder):
    bookmarks, history = [], []
    try:
        with open(os.path.join(folder, "Bookmarks"), encoding="utf-8") as stream:
            roots = json.load(stream).get("roots", {})
        for root in roots.values():
            chromium_nodes(root, browser, bookmarks)
    except (OSError, ValueError, AttributeError):
        pass
    connection = opened(os.path.join(folder, "History"))
    if connection:
        try:
            for url, title, visits, last in connection.execute(
                "SELECT url, title, visit_count, last_visit_time FROM urls WHERE hidden = 0 AND visit_count > 0 "
                "ORDER BY visit_count + 3 * typed_count DESC, last_visit_time DESC LIMIT ?", (HISTORY_LIMIT,)):
                if url and url.startswith(WEB):
                    history.append(place(url, title, visits, max(0, (last or 0) // 1000 - CHROME_EPOCH_MS), False, browser))
        except sqlite3.Error:
            pass
        connection.close()
    return bookmarks[:BOOKMARK_LIMIT], history, ("chromium", os.path.join(folder, "Favicons"))


def place(url, title, visits, last, bookmark, browser):
    return {"url": url, "title": (title or "").strip(), "host": host_of(url), "bookmark": bookmark, "visits": visits or 0, "last": last or 0, "browser": browser, "icon": ""}


def merged(lists):
    by_url = {}
    order = []
    for entry in lists:
        kept = by_url.get(entry["url"])
        if kept is None:
            by_url[entry["url"]] = dict(entry)
            order.append(entry["url"])
            continue
        if entry["bookmark"] and not kept["bookmark"]:
            kept["bookmark"] = True
            kept["title"] = entry["title"] or kept["title"]
        kept["visits"] = max(kept["visits"], entry["visits"])
        kept["last"] = max(kept["last"], entry["last"])
        kept["title"] = kept["title"] or entry["title"]
    return [by_url[url] for url in order]


def extension(data):
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if data[:4] == b"\x00\x00\x01\x00":
        return ".ico"
    if data[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if data[:4] == b"GIF8":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    head = data[:256].lstrip().lower()
    if head.startswith(b"<svg") or head.startswith(b"<?xml"):
        return ".svg"
    return ""


def icon_name(host):
    return hashlib.sha1(host.encode()).hexdigest()[:16]


def existing_icons(folder):
    have = {}
    for path in glob.glob(os.path.join(folder, "*")):
        have[os.path.splitext(os.path.basename(path))[0]] = path
    return have


def best_icons(connection, kind, pages):
    connection.execute("CREATE TEMP TABLE wanted (url TEXT PRIMARY KEY, host TEXT)")
    connection.executemany("INSERT OR IGNORE INTO wanted VALUES (?, ?)", [(url, host) for host, urls in pages.items() for url in urls])
    if kind == "mozilla":
        rows = connection.execute(
            "SELECT w.host, i.id, i.width FROM moz_pages_w_icons p JOIN wanted w ON w.url = p.page_url "
            "JOIN moz_icons_to_pages ip ON ip.page_id = p.id JOIN moz_icons i ON i.id = ip.icon_id "
            "WHERE p.page_url IN (SELECT url FROM wanted)")
    else:
        rows = connection.execute(
            "SELECT w.host, b.id, b.width FROM icon_mapping m JOIN wanted w ON w.url = m.page_url "
            "JOIN favicon_bitmaps b ON b.icon_id = m.icon_id WHERE m.page_url IN (SELECT url FROM wanted)")
    best = {}
    for host, icon, width in rows.fetchall():
        score = abs((width or 16) - 48)
        if host not in best or score < best[host][1]:
            best[host] = (icon, score)
    query = "SELECT data FROM moz_icons WHERE id = ?" if kind == "mozilla" else "SELECT image_data FROM favicon_bitmaps WHERE id = ?"
    for host, (icon, _) in best.items():
        row = connection.execute(query, (icon,)).fetchone()
        if row and row[0]:
            yield host, bytes(row[0])


def fill_icons(places, favicon_sources, folder, tried):
    private_folder(folder)
    have = existing_icons(folder)
    ranked = sorted(places, key=lambda e: (not e["bookmark"], -e["visits"]))
    wanted = []
    for entry in ranked:
        host = entry["host"]
        if host and icon_name(host) not in have and host not in tried and host not in wanted:
            wanted.append(host)
    wanted = set(wanted[:ICON_LIMIT])
    tried.update(wanted)
    pages = {host: ["https://" + host + "/", "https://www." + host + "/", "http://" + host + "/"] for host in wanted}
    for entry in places:
        if entry["host"] in pages and len(pages[entry["host"]]) < 8:
            pages[entry["host"]].append(entry["url"])
    for kind, path in favicon_sources if wanted else []:
        connection = opened(path)
        if not connection:
            continue
        try:
            for host, data in best_icons(connection, kind, {h: u for h, u in pages.items() if h in wanted}):
                ending = extension(data)
                if not ending:
                    continue
                target = os.path.join(folder, icon_name(host) + ending)
                with open(target, "wb") as out:
                    out.write(data)
                have[icon_name(host)] = target
                wanted.discard(host)
        except sqlite3.Error:
            pass
        connection.close()
        if not wanted:
            break
    for entry in places:
        entry["icon"] = have.get(icon_name(entry["host"]), "") if entry["host"] else ""


def load(path):
    try:
        with open(path, encoding="utf-8") as stream:
            return json.load(stream)
    except (OSError, ValueError):
        return {}


def private_folder(folder):
    os.makedirs(folder, mode=0o700, exist_ok=True)
    os.chmod(folder, 0o700)


def save(path, data):
    private_folder(os.path.dirname(path) or ".")
    partial = path + ".part"
    with open(partial, "w", encoding="utf-8") as out:
        json.dump(data, out, ensure_ascii=False, separators=(",", ":"))
    os.replace(partial, path)


def main():
    if len(sys.argv) != 3:
        print("usage: browser-places.py <places.json> <favicon-folder>", file=sys.stderr)
        return 2
    os.umask(0o077)
    target, icons = sys.argv[1], sys.argv[2]
    memory_path = os.path.splitext(target)[0] + "-profiles.json"
    memory = load(memory_path)
    kept = memory.get("profiles", {})
    found = profiles()
    stamps = {folder: signature(kind, folder) for kind, _, folder in found}
    if os.path.isfile(target) and all(kept.get(folder, {}).get("signature") == stamps[folder] for folder in stamps) and set(kept) == set(stamps):
        print("unchanged")
        return 0
    fresh = {}
    bookmarks, history, favicon_sources = [], [], []
    for kind, browser, folder in found:
        known = kept.get(folder)
        if known and known.get("signature") == stamps[folder]:
            fresh[folder] = known
        else:
            reader = mozilla_places if kind == "mozilla" else chromium_places
            marks, visited, favicons = reader(browser, folder)
            fresh[folder] = {"signature": stamps[folder], "bookmarks": marks, "history": visited, "favicons": favicons}
        bookmarks += fresh[folder]["bookmarks"]
        history += fresh[folder]["history"]
        if fresh[folder].get("favicons"):
            favicon_sources.append(fresh[folder]["favicons"])
    history.sort(key=lambda e: -e["visits"])
    places = merged(bookmarks + history)[:PLACES_LIMIT]
    tried = set(memory.get("tried", []))
    fill_icons(places, favicon_sources, icons, tried)
    save(memory_path, {"profiles": fresh, "tried": sorted(tried)})
    save(target, {"generated": int(time.time() * 1000), "places": places})
    return 0


if __name__ == "__main__":
    sys.exit(main())
