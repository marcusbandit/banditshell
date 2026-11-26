#!/usr/bin/env python3
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request


def _iso_from_epoch(epoch):
    if epoch is None:
        return ""
    try:
        return datetime.fromtimestamp(float(epoch), tz=timezone.utc).isoformat().replace("+00:00", "Z")
    except Exception:
        return ""


def _clamp_percent(value):
    try:
        return round(max(0.0, min(100.0, float(value))), 1)
    except Exception:
        return 0.0


def fetch_claude():
    path = os.path.expanduser("~/.claude/.credentials.json")
    if not os.path.exists(path):
        return {"id": "claude", "name": "Claude", "primary": [], "extra": [], "error": "not signed in"}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            creds = json.load(fh)
        token = (creds.get("claudeAiOauth") or {}).get("accessToken")
        if not token:
            return {"id": "claude", "name": "Claude", "primary": [], "extra": [], "error": "no token"}
        req = urllib.request.Request(
            "https://api.anthropic.com/api/oauth/usage",
            headers={
                "Authorization": f"Bearer {token}",
                "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": "claude-code/2.1.273",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        return {"id": "claude", "name": "Claude", "primary": [], "extra": [], "error": str(exc)}

    primary = []
    extra = []
    five_hour = data.get("five_hour")
    if isinstance(five_hour, dict) and five_hour.get("utilization") is not None:
        primary.append({
            "id": "five_hour",
            "kind": "session",
            "label": "5-hour",
            "usedPercent": _clamp_percent(five_hour.get("utilization")),
            "resetsAt": five_hour.get("resets_at") or "",
            "durationMins": 300,
        })
    seven_day = data.get("seven_day")
    if isinstance(seven_day, dict) and seven_day.get("utilization") is not None:
        primary.append({
            "id": "seven_day",
            "kind": "weekly",
            "label": "Weekly",
            "usedPercent": _clamp_percent(seven_day.get("utilization")),
            "resetsAt": seven_day.get("resets_at") or "",
            "durationMins": 10080,
        })

    for item in data.get("limits") or []:
        if not isinstance(item, dict):
            continue
        if item.get("kind") == "weekly_scoped" and item.get("percent") is not None:
            model = ((item.get("scope") or {}).get("model") or {}).get("display_name") or ""
            label = f"Weekly · {model}" if model else "Weekly"
            extra.append({
                "id": f"scoped-{model.lower() or len(extra)}",
                "kind": "weekly",
                "label": label,
                "usedPercent": _clamp_percent(item.get("percent")),
                "resetsAt": item.get("resets_at") or "",
                "durationMins": 10080,
            })

    return {"id": "claude", "name": "Claude", "primary": primary, "extra": extra, "error": ""}


def fetch_antigravity():
    home = os.path.expanduser("~")
    uid = os.getuid()
    agy = os.environ.get("AGY_BIN", os.path.join(home, ".local", "bin", "agy"))
    if not os.path.exists(agy):
        return {"id": "antigravity", "name": "Antigravity", "primary": [], "extra": [], "error": "agy not found"}
    clean_env = {
        "HOME": home,
        "USER": os.environ.get("USER", ""),
        "PATH": f"{home}/.local/bin:/usr/local/bin:/usr/bin:/bin",
        "DBUS_SESSION_BUS_ADDRESS": os.environ.get("DBUS_SESSION_BUS_ADDRESS", f"unix:path=/run/user/{uid}/bus"),
        "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}"),
    }
    try:
        proc = subprocess.run(
            [agy, "-p", "/usage", "--output-format", "json"],
            env=clean_env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=25,
            check=True,
        )
        raw = proc.stdout.strip()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            data = json.loads(raw.splitlines()[-1])
        if data.get("status") != "SUCCESS":
            return {"id": "antigravity", "name": "Antigravity", "primary": [], "extra": [], "error": data.get("error") or "failed"}
    except Exception as exc:
        return {"id": "antigravity", "name": "Antigravity", "primary": [], "extra": [], "error": str(exc)}

    groups = (data.get("command") or {}).get("data", {}).get("groups") or []
    primary = []
    extra = []
    for idx, group in enumerate(groups):
        gname = (group.get("name") or "").strip()
        is_normal = idx == 0 or "gemini" in gname.lower()
        buckets = sorted(
            group.get("buckets") or [],
            key=lambda b: 0 if (b.get("window") or "").lower() == "5h" else 1,
        )
        for b in buckets:
            rem = b.get("remaining_fraction")
            if rem is None:
                continue
            win = (b.get("window") or "").lower()
            kind = "session" if win == "5h" else ("weekly" if win == "weekly" else "other")
            base_label = "5-hour" if win == "5h" else ("Weekly" if win == "weekly" else (b.get("name") or "Limit"))
            duration = 300 if win == "5h" else (10080 if win == "weekly" else 0)
            entry = {
                "id": str(b.get("id") or f"ag-{idx}-{win}"),
                "kind": kind,
                "label": base_label if is_normal else f"{base_label} · {gname or 'Claude & GPT'}",
                "usedPercent": _clamp_percent((1.0 - float(rem)) * 100.0),
                "resetsAt": b.get("reset_time") or "",
                "durationMins": duration,
            }
            if is_normal:
                primary.append(entry)
            else:
                extra.append(entry)

    return {"id": "antigravity", "name": "Antigravity", "primary": primary, "extra": extra, "error": ""}


def fetch_codex():
    path = os.path.expanduser("~/.codex/auth.json")
    if not os.path.exists(path):
        return {"id": "codex", "name": "Codex", "primary": [], "extra": [], "error": "not signed in"}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            auth = json.load(fh)
        tokens = auth.get("tokens") or {}
        token = tokens.get("access_token")
        account_id = tokens.get("account_id")
        if not token:
            return {"id": "codex", "name": "Codex", "primary": [], "extra": [], "error": "no token"}
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "OpenAI-Beta": "codex-1",
            "Originator": "Codex Desktop",
            "Accept": "application/json",
        }
        if account_id:
            headers["Chatgpt-Account-Id"] = account_id
        req = urllib.request.Request("https://chatgpt.com/backend-api/wham/usage", headers=headers)
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        return {"id": "codex", "name": "Codex", "primary": [], "extra": [], "error": str(exc)}

    rate = data.get("rate_limit") or {}
    primary = []
    pw = rate.get("primary_window")
    if isinstance(pw, dict) and pw.get("used_percent") is not None:
        secs = pw.get("limit_window_seconds") or 18000
        primary.append({
            "id": "codex-5h",
            "kind": "session",
            "label": "5-hour",
            "usedPercent": _clamp_percent(pw.get("used_percent")),
            "resetsAt": _iso_from_epoch(pw.get("reset_at")),
            "durationMins": int(round(secs / 60)),
        })
    sw = rate.get("secondary_window")
    if isinstance(sw, dict) and sw.get("used_percent") is not None:
        secs = sw.get("limit_window_seconds") or 604800
        primary.append({
            "id": "codex-weekly",
            "kind": "weekly",
            "label": "Weekly",
            "usedPercent": _clamp_percent(sw.get("used_percent")),
            "resetsAt": _iso_from_epoch(sw.get("reset_at")),
            "durationMins": int(round(secs / 60)),
        })

    return {"id": "codex", "name": "Codex", "primary": primary, "extra": [], "error": ""}


FETCHERS = {
    "claude": fetch_claude,
    "antigravity": fetch_antigravity,
    "codex": fetch_codex,
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--providers", default="claude,antigravity")
    args = parser.parse_args()
    wanted = [p.strip() for p in args.providers.split(",") if p.strip() in FETCHERS]
    if not wanted:
        json.dump({"providers": []}, sys.stdout)
        return
    with ThreadPoolExecutor(max_workers=len(wanted)) as pool:
        futures = {p: pool.submit(FETCHERS[p]) for p in wanted}
        results = [futures[p].result() for p in wanted]
    json.dump({"providers": results}, sys.stdout)


if __name__ == "__main__":
    main()
