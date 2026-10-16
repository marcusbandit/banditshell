#!/usr/bin/env python3
import glob
import gzip
import json
import os
import re
import sys
import xml.etree.ElementTree as ElementTree

LANG = "{http://www.w3.org/XML/1998/namespace}lang"
KINDS = {"desktop-application", "desktop", "console-application"}
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9+._@:-]*$")


def installations():
    home = os.path.expanduser("~")
    data = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share")
    return [("system", os.environ.get("FLATPAK_SYSTEM_DIR") or "/var/lib/flatpak"), ("user", os.environ.get("FLATPAK_USER_DIR") or os.path.join(data, "flatpak"))]


def sources():
    found = []
    for installation, root in installations():
        for active in sorted(glob.glob(os.path.join(root, "appstream", "*", "*", "active"))):
            plain = os.path.join(active, "appstream.xml")
            packed = plain + ".gz"
            path = plain if os.path.isfile(plain) else packed if os.path.isfile(packed) else ""
            if path:
                found.append({"installation": installation, "remote": active.split(os.sep)[-3], "path": path, "mtime": os.path.getmtime(path)})
    return found


def untranslated(component, tag):
    for child in component.findall(tag):
        if child.get(LANG) is None and child.text:
            return " ".join(child.text.split())
    return ""


def icon_of(component, active):
    found = []
    for icon in component.findall("icon"):
        if icon.get("type") != "cached" or not icon.text:
            continue
        try:
            size = int(icon.get("height") or icon.get("width") or 0)
        except ValueError:
            continue
        path = os.path.join(active, "icons", f"{size}x{size}", icon.text.strip())
        if os.path.isfile(path):
            found.append((size, path))
    big = sorted(f for f in found if f[0] >= 64)
    if big:
        return big[0][1]
    return max(found)[1] if found else ""


def read(source):
    active = os.path.dirname(source["path"])
    opener = gzip.open if source["path"].endswith(".gz") else open
    apps = []
    with opener(source["path"], "rb") as stream:
        for _, element in ElementTree.iterparse(stream):
            if element.tag != "component":
                continue
            if element.get("type") in KINDS:
                identifier = (element.findtext("id") or "").strip()
                if identifier.endswith(".desktop"):
                    identifier = identifier[: -len(".desktop")]
                release = element.find("releases/release")
                if NAME.match(identifier) and NAME.match(source["remote"]):
                    apps.append({
                        "id": identifier,
                        "name": untranslated(element, "name") or identifier,
                        "summary": untranslated(element, "summary"),
                        "version": release.get("version", "") if release is not None else "",
                        "remote": source["remote"],
                        "installation": source["installation"],
                        "icon": icon_of(element, active),
                    })
            element.clear()
    return apps


def main():
    if len(sys.argv) != 2:
        print("usage: flatpak-index.py <index.json>", file=sys.stderr)
        return 2
    os.umask(0o077)
    target = sys.argv[1]
    found = sources()
    if not found:
        return 3
    signature = [[s["path"], s["mtime"]] for s in found]
    try:
        with open(target, encoding="utf-8") as kept:
            if json.load(kept).get("signature") == signature:
                print("unchanged")
                return 0
    except (OSError, ValueError):
        pass
    apps = {}
    for source in found:
        try:
            for app in read(source):
                apps.setdefault(app["id"], app)
        except (OSError, ElementTree.ParseError, EOFError):
            continue
    folder = os.path.dirname(target) or "."
    os.makedirs(folder, mode=0o700, exist_ok=True)
    os.chmod(folder, 0o700)
    partial = target + ".part"
    with open(partial, "w", encoding="utf-8") as out:
        json.dump({"signature": signature, "apps": sorted(apps.values(), key=lambda a: a["name"].lower())}, out, ensure_ascii=False, separators=(",", ":"))
    os.replace(partial, target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
