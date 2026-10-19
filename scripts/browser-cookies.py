#!/usr/bin/env python3
import glob
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
FLATPAK = os.path.join(HOME, ".var", "app")

MOZILLA = {
    "zen": [os.path.join(HOME, ".zen"), os.path.join(FLATPAK, "app.zen_browser.zen", ".zen")],
    "firefox": [os.path.join(HOME, ".mozilla", "firefox"), os.path.join(FLATPAK, "org.mozilla.firefox", ".mozilla", "firefox"), os.path.join(HOME, "snap", "firefox", "common", ".mozilla", "firefox")],
    "librewolf": [os.path.join(HOME, ".librewolf"), os.path.join(FLATPAK, "io.gitlab.librewolf-community", ".librewolf")],
    "floorp": [os.path.join(HOME, ".floorp")],
    "waterfox": [os.path.join(HOME, ".waterfox")],
}

CHROMIUM = [("chromium", "chromium"), ("google-chrome", "chrome"), ("chrome", "chrome"), ("brave", "brave"), ("vivaldi", "vivaldi"), ("edge", "edge"), ("opera", "opera")]


def newest_profile(roots):
    found = []
    for root in roots:
        found += glob.glob(os.path.join(glob.escape(root), "*", "cookies.sqlite"))
    return os.path.dirname(max(found, key=os.path.getmtime)) if found else ""


def default_browser():
    try:
        return subprocess.run(["xdg-settings", "get", "default-web-browser"], capture_output=True, text=True, timeout=5).stdout.strip().lower()
    except (OSError, subprocess.SubprocessError):
        return ""


def main():
    browser = default_browser()
    for family, roots in MOZILLA.items():
        if family in browser:
            profile = newest_profile(roots)
            if profile:
                print("firefox:" + profile)
                return 0
    for marker, name in CHROMIUM:
        if marker in browser:
            print(name)
            return 0
    profile = newest_profile([root for roots in MOZILLA.values() for root in roots])
    if profile:
        print("firefox:" + profile)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
