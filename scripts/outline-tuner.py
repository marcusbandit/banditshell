#!/usr/bin/env python3
import argparse
import base64
import glob
import importlib.util
import io
import secrets
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
THUMBS = 6
IDLE = 2 * 3600
COOKIE = "outline-tuner"


def sibling(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


Transition = sibling("wallpaper_transition", "wallpaper-transition.py")
Outline = Transition.Outline


def ensure_venv():
    try:
        import cv2
        import numpy
        from PIL import Image
        del cv2, numpy, Image
    except ImportError:
        if sys.executable != Transition.VENV_PY and os.path.exists(Transition.VENV_PY):
            os.execv(Transition.VENV_PY, [Transition.VENV_PY, os.path.abspath(__file__), *sys.argv[1:]])
        sys.exit("outline-tuner: needs numpy, opencv and pillow; install the cut-out from Settings first")


def expand(path, env):
    home = env.get("HOME") or os.path.expanduser("~")
    if path == "~" or path.startswith("~/"):
        path = home + path[1:]
    return path.replace("$HOME", home)


def wallpaper_dir(env):
    try:
        with open(os.path.join(Outline.config_home(env), "banditshell", "config.json")) as f:
            found = json.load(f).get("wallpaper", {}).get("dir")
    except (OSError, ValueError, AttributeError):
        found = None
    if isinstance(found, str) and found.strip():
        return os.path.abspath(expand(found.strip(), env))
    return os.path.join(env.get("HOME") or os.path.expanduser("~"), "Pictures", "Wallpapers")


def list_stills(folder):
    found = []
    for root, dirs, files in os.walk(folder, followlinks=True):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in files:
            if name.lower().endswith(Transition.STILLS) and not name.startswith("."):
                found.append(os.path.relpath(os.path.join(root, name), folder))
    return sorted(found, key=str.lower)


def public_host(run=subprocess.run):
    try:
        done = run(["tailscale", "status", "--json"], capture_output=True, text=True, timeout=5)
        if done.returncode == 0:
            name = (json.loads(done.stdout).get("Self") or {}).get("DNSName") or ""
            if name.strip("."):
                return name.rstrip(".")
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return socket.gethostname()


def tuner_url(host, port, start=None, token=None):
    fields = {k: v for k, v in (("k", token), ("file", start)) if v}
    query = "?" + urllib.parse.urlencode(fields) if fields else ""
    return f"http://{host}:{port}/{query}"


def bind_host(run=subprocess.run):
    try:
        done = run(["tailscale", "ip", "-4"], capture_output=True, text=True, timeout=5)
        if done.returncode == 0 and done.stdout.split():
            return done.stdout.split()[0]
    except (OSError, subprocess.SubprocessError):
        pass
    return "127.0.0.1"


def allowed(token, query, cookie):
    jar = dict(part.strip().split("=", 1) for part in (cookie or "").split(";") if "=" in part)
    return secrets.compare_digest(query.get("k", ""), token) or secrets.compare_digest(jar.get(COOKIE, ""), token)


def neutral_edits(edits):
    return edits is None or not ((edits >= 192) | (edits <= 64)).any()


def compose(model, edits):
    import numpy as np
    m = model.astype(np.uint8).copy()
    if edits is not None:
        m[edits >= 192] = 255
        m[edits <= 64] = 0
    return m


def free_memory():
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) * 1024
    except OSError:
        pass
    return 0


def png_bytes(arr, mode):
    from PIL import Image
    out = io.BytesIO()
    Image.fromarray(arr, mode).save(out, "PNG")
    return out.getvalue()


def decode_png(text):
    import numpy as np
    from PIL import Image
    if not text:
        return None
    if text.startswith("data:"):
        text = text.split(",", 1)[1]
    return np.asarray(Image.open(io.BytesIO(base64.b64decode(text))).convert("L"))


class Tuner:
    def __init__(self, folder, start):
        self.folder = folder
        self.start = os.path.abspath(start) if start else None
        self.thumbs = {}
        self.jobs = {}
        self.lock = threading.Lock()

    def files(self):
        names = list_stills(self.folder) if os.path.isdir(self.folder) else []
        start = None
        if self.start:
            rel = os.path.relpath(self.start, self.folder)
            start = rel if rel in names else self.start
            if start == self.start:
                names.insert(0, self.start)
        return names, start

    def path_of(self, name):
        if not isinstance(name, str) or not name:
            return None
        if self.start and name == self.start:
            return self.start
        path = os.path.abspath(os.path.join(self.folder, name))
        if not path.startswith(os.path.abspath(self.folder) + os.sep) or not Transition.is_still(path):
            return None
        return path

    def thumb(self, path):
        import numpy as np
        stamp = os.stat(path).st_mtime_ns
        with self.lock:
            found = self.thumbs.get(path)
        if found and found[0] == stamp:
            return found[1], found[2]
        im = Transition.thumbnail(path)
        arr = np.asarray(im)
        with self.lock:
            self.thumbs.pop(path, None)
            self.thumbs[path] = (stamp, im, arr)
            while len(self.thumbs) > THUMBS:
                self.thumbs.pop(next(iter(self.thumbs)))
        return im, arr

    def model(self, path, prep):
        import numpy as np
        from PIL import Image
        mask_path = Transition.model_mask_path(path, prep)
        if not os.path.exists(mask_path):
            return None
        im, _ = self.thumb(path)
        return np.asarray(Image.open(mask_path).convert("L").resize(im.size))

    def hand(self, path, over):
        import numpy as np
        from PIL import Image
        hand = Transition.hand_mask_path(path, over)
        if not hand:
            return None
        im, _ = self.thumb(path)
        mask = Image.open(hand).convert("L")
        return np.asarray(mask) if mask.size == im.size else None

    def base_mask(self, path, prep, source):
        over = Outline.read_override(Transition.overrides(), path)[0]
        if source == "hand":
            found = self.hand(path, over)
            if found is not None:
                return found, "hand"
        found = self.model(path, prep)
        if found is not None:
            return found, "model"
        if over and over["edited"] and Outline.prep_tag(over["prep"]) == Outline.prep_tag(prep):
            found = self.hand(path, over)
            if found is not None:
                return found, "hand"
        return None, None

    def cached_meta(self, path):
        try:
            with open(Transition.outline_base(path) + ".json") as f:
                return json.load(f)
        except (OSError, ValueError):
            return None

    def state(self, path):
        im, _ = self.thumb(path)
        over = Outline.read_override(Transition.overrides(), path)[0]
        shade = Transition.colours(path) or ("#ffffff", "#ffffff")
        edits = Outline.override_paths(Transition.overrides(), path)["edits"]
        return {
            "size": list(im.size),
            "ember": shade[0],
            "ink": shade[1],
            "override": over,
            "hasEdits": bool(over) and os.path.exists(edits),
            "free": round(free_memory() / (1 << 30), 1),
            "need": round(Transition.CUTOUT_ROOM / (1 << 30), 1),
            "cached": self.cached_meta(path),
        }

    def shape(self, path, body):
        base, source = self.base_mask(path, body.get("prep"), body.get("base"))
        if base is None:
            return {"missing": True}
        edits = decode_png(body.get("edits"))
        if edits is not None and edits.shape != base.shape:
            edits = None
        m = compose(base, edits).astype("float32") / 255.0
        over = Outline.clean_override(body)
        found, rgb, lines = Transition.shape(m, over["threshold"], over["seed"], Transition.key_of(path), True)
        stats = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in found.items()}
        reply = {"stats": stats, "source": source}
        if rgb is not None:
            reply["field"] = base64.b64encode(png_bytes(rgb, "RGB")).decode()
            reply["line"] = base64.b64encode(png_bytes(lines, "RGB")).decode()
        return reply

    def job(self, kind, work):
        jid = f"{kind}-{time.time_ns()}"
        record = {"state": "running", "kind": kind, "started": time.time()}
        with self.lock:
            self.jobs[jid] = record

        def go():
            try:
                record.update(work())
            except Exception as e:
                record.update({"state": "failed", "why": str(e)[:200]})
            record["seconds"] = round(time.time() - record["started"], 1)

        threading.Thread(target=go, daemon=True).start()
        return jid

    def run_model(self, path, prep):
        prep = Outline.clean_prep(prep)
        if os.path.exists(Transition.model_mask_path(path, prep)):
            return {"done": True}
        if not Transition.room():
            return {"refused": "memory", "free": round(free_memory() / (1 << 30), 1), "need": round(Transition.CUTOUT_ROOM / (1 << 30), 1)}

        def work():
            done = subprocess.run(Transition.capped_mask_command(path, prep), env=Transition.capped_env(),
                                  capture_output=True, text=True)
            if done.returncode == 0 and os.path.exists(Transition.model_mask_path(path, prep)):
                return {"state": "done"}
            return {"state": {1: "busy", 3: "memory", 4: "failed", 137: "memory", -9: "memory"}.get(done.returncode, "failed"), "why": done.stderr[-300:]}

        return {"job": self.job("model", work)}

    def save(self, path, body):
        import numpy as np
        folder = Transition.overrides()
        over = Outline.clean_override(body)
        im, _ = self.thumb(path)
        base, source = self.base_mask(path, over["prep"], body.get("base"))
        edits = decode_png(body.get("edits"))
        if base is None:
            return {"refused": "mask"}
        if edits is not None and edits.shape != base.shape:
            edits = None
        mask_png = edits_png = None
        if base is not None and (source == "hand" or not neutral_edits(edits)):
            mask_png = png_bytes(compose(base, edits), "L")
        if not neutral_edits(edits):
            edits_png = png_bytes(np.ascontiguousarray(edits), "L")
        settings = dict(over, size=list(im.size))
        if mask_png is None and Transition.needs_model(path, over) and not Transition.room():
            return {"refused": "memory", "free": round(free_memory() / (1 << 30), 1), "need": round(Transition.CUTOUT_ROOM / (1 << 30), 1)}
        Outline.write_override(folder, path, settings, mask_png, edits_png)

        def work():
            subprocess.run(Transition.capped_command([path, "--force"]), env=Transition.capped_env(),
                           capture_output=True, text=True)
            self.prune(path)
            meta = self.cached_meta(path)
            if not meta or "cover" not in meta:
                return {"state": "busy" if not meta else "failed", "meta": meta}
            return {"state": "done", "meta": meta}

        return {"job": self.job("save", work)}

    def clear(self, path):
        Outline.clear_override(Transition.overrides(), path)
        self.prune(path)
        return {"cleared": True, "cached": self.cached_meta(path)}

    def prune(self, path):
        keep = os.path.basename(Transition.outline_base(path))
        key = Transition.key_of(path)
        for stale in glob.glob(os.path.join(Transition.outline_dir(), f"{key}-o*")):
            name = os.path.basename(stale)
            if keep == key or (not name.startswith(keep + "-") and not name.startswith(keep + ".")):
                try:
                    os.remove(stale)
                except OSError:
                    pass


def handler(tuner, page, token, seen):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def let_in(self):
            url = urllib.parse.urlparse(self.path)
            if not allowed(token, dict(urllib.parse.parse_qsl(url.query)), self.headers.get("Cookie")):
                self.send(403, {"error": "open the link banditshell wallpaper outline printed"})
                return False
            seen[0] = time.monotonic()
            return True

        def send(self, code, body, kind="application/json"):
            if not isinstance(body, bytes):
                body = json.dumps(body).encode()
            self.send_response(code)
            self.send_header("Content-Type", kind)
            self.send_header("Set-Cookie", f"{COOKIE}={token}; Path=/; HttpOnly; SameSite=Strict")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def image(self, arr, quality=90):
            from PIL import Image
            out = io.BytesIO()
            Image.fromarray(arr, "RGB").save(out, "JPEG", quality=quality)
            self.send(200, out.getvalue(), "image/jpeg")

        def target(self, name):
            path = tuner.path_of(name)
            if not path or not os.path.isfile(path):
                self.send(404, {"error": "no such wallpaper"})
                return None
            return path

        def do_GET(self):
            if not self.let_in():
                return
            url = urllib.parse.urlparse(self.path)
            q = dict(urllib.parse.parse_qsl(url.query))
            if url.path == "/":
                self.send(200, open(page, "rb").read(), "text/html; charset=utf-8")
            elif url.path == "/api/files":
                names, start = tuner.files()
                self.send(200, {"files": names, "start": start})
            elif url.path == "/api/state":
                path = self.target(q.get("f"))
                if path:
                    self.send(200, tuner.state(path))
            elif url.path == "/api/original":
                path = self.target(q.get("f"))
                if path:
                    self.image(tuner.thumb(path)[1])
            elif url.path == "/api/edits":
                path = self.target(q.get("f"))
                if path:
                    edits = Outline.override_paths(Transition.overrides(), path)["edits"]
                    if os.path.exists(edits):
                        self.send(200, open(edits, "rb").read(), "image/png")
                    else:
                        self.send(404, {"missing": True})
            elif url.path == "/api/job":
                with tuner.lock:
                    record = dict(tuner.jobs.get(q.get("id"), {"state": "unknown"}))
                if record.get("state") == "running":
                    record["seconds"] = round(time.time() - record["started"], 1)
                self.send(200, record)
            else:
                self.send(404, {"error": "not found"})

        def do_POST(self):
            if not self.let_in():
                return
            url = urllib.parse.urlparse(self.path)
            try:
                length = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(min(length, 64 << 20)) or b"{}")
            except ValueError:
                self.send(400, {"error": "bad json"})
                return
            if not isinstance(body, dict):
                self.send(400, {"error": "bad json"})
                return
            path = self.target(body.get("f"))
            if not path:
                return
            if url.path == "/api/prep":
                self.image(Outline.preprocess(tuner.thumb(path)[1], body.get("prep")))
            elif url.path == "/api/mask":
                base, source = tuner.base_mask(path, body.get("prep"), body.get("base"))
                if base is None:
                    self.send(404, {"missing": True})
                else:
                    self.send(200, {"source": source, "mask": base64.b64encode(png_bytes(base, "L")).decode()})
            elif url.path == "/api/shape":
                self.send(200, tuner.shape(path, body))
            elif url.path == "/api/run":
                self.send(200, tuner.run_model(path, body.get("prep")))
            elif url.path == "/api/save":
                self.send(200, tuner.save(path, body))
            elif url.path == "/api/clear":
                self.send(200, tuner.clear(path))
            else:
                self.send(404, {"error": "not found"})

    return Handler


def serve(host, port):
    try:
        return ThreadingHTTPServer((host, port), None)
    except OSError:
        if port == 0:
            raise
        return ThreadingHTTPServer((host, 0), None)


def watch_idle(server, seen):
    while True:
        time.sleep(60)
        if time.monotonic() - seen[0] > IDLE:
            server.shutdown()
            return


def main(argv):
    parser = argparse.ArgumentParser(prog="outline-tuner.py")
    parser.add_argument("--file")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--ready")
    args = parser.parse_args(argv)
    ensure_venv()
    tuner = Tuner(wallpaper_dir(os.environ), args.file)
    host = bind_host()
    server = serve(host, args.port)
    token = secrets.token_urlsafe(16)
    seen = [time.monotonic()]
    server.RequestHandlerClass = handler(tuner, os.path.join(HERE, "outline-tuner.html"), token, seen)
    threading.Thread(target=watch_idle, args=(server, seen), daemon=True).start()
    port = server.server_address[1]
    _, start = tuner.files()
    url = tuner_url(public_host() if host != "127.0.0.1" else host, port, start, token)
    if args.ready:
        tmp = f"{args.ready}.{os.getpid()}.tmp"
        with open(tmp, "w") as f:
            f.write(f"{os.getpid()} {port} {url}\n")
        os.replace(tmp, args.ready)
    print(url, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
