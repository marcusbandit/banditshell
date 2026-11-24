#!/usr/bin/env python3
# Adapted from wallfx in pocket-dots by Diego Malagrida, GPL-3.0:
# https://github.com/diegoMalagrida/pocket-dots/blob/main/home/.local/bin/wallfx

import colorsys
import fcntl
import hashlib
import heapq
import json
import os
import random
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "banditshell", "wallpaper-transition")
CUTOUT = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share"), "banditshell", "cutout")
VENV_PY = os.path.join(CUTOUT, "venv", "bin", "python")
MODEL = "birefnet-general-lite"

CELL = 4
POOL = 12
FIELD_MAX = 1280
SD_RANGE = 16.0
WIDE = 48.0
STILLS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
CUTOUT_CAP = "8G"
CUTOUT_ROOM = 9 << 30


def has_numpy():
    try:
        import numpy  # noqa: F401
        from PIL import Image  # noqa: F401
        return True
    except ImportError:
        return False


def reexec_in_venv():
    if sys.executable != VENV_PY and os.path.exists(VENV_PY):
        os.execv(VENV_PY, [VENV_PY, os.path.abspath(__file__), *sys.argv[1:]])


def grid_of(width, height):
    return max(16, round(width / CELL)), max(9, round(height / CELL))


def value_noise(rng, w, h, scale):
    import numpy as np
    nx, ny = int(w / scale) + 3, int(h / scale) + 3
    lat = rng.random((ny, nx))
    xs = np.arange(w) / scale
    ys = np.arange(h) / scale
    ix, iy = xs.astype(int), ys.astype(int)
    fx, fy = xs - ix, ys - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    top = lat[iy][:, ix] * (1 - fx) + lat[iy][:, ix + 1] * fx
    bot = lat[iy + 1][:, ix] * (1 - fx) + lat[iy + 1][:, ix + 1] * fx
    return top * (1 - fy)[:, None] + bot * fy[:, None]


def blur(a, sigma):
    import numpy as np
    r = int(3 * sigma) + 1
    x = np.arange(-r, r + 1)
    k = np.exp(-x * x / (2.0 * sigma * sigma))
    k /= k.sum()
    a = np.pad(a, r, mode="edge")
    a = sum(k[i] * a[:, i:i + a.shape[1] - 2 * r] for i in range(2 * r + 1))
    a = sum(k[i] * a[i:i + a.shape[0] - 2 * r, :] for i in range(2 * r + 1))
    return a


def rgb16(v, extra=None):
    import numpy as np
    q = np.clip(v * 65535.0 + 0.5, 0, 65535).astype(np.uint16)
    rgb = np.zeros(v.shape + (3,), np.uint8)
    if extra is not None:
        rgb[..., 0] = extra
    rgb[..., 1] = q >> 8
    rgb[..., 2] = q & 255
    return rgb


STEPS = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
         (-1, -1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (1, 1, 1.4142)]


def arrival(cost, seeds, gw, gh):
    inf = float("inf")
    at = [inf] * (gw * gh)
    heap = []
    for i, t0 in seeds:
        at[i] = t0
        heap.append((t0, i))
    heapq.heapify(heap)
    while heap:
        t, i = heapq.heappop(heap)
        if t != at[i]:
            continue
        x, y = i % gw, i // gw
        ci = cost[i]
        for dx, dy, d in STEPS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < gw and 0 <= ny < gh:
                j = ny * gw + nx
                cand = t + (ci + cost[j]) * 0.5 * d
                if cand < at[j]:
                    at[j] = cand
                    heapq.heappush(heap, (cand, j))
    return at


def ranked(at, shape):
    import numpy as np
    a = np.array(at)
    rank = np.empty(a.size)
    rank[np.argsort(a, kind="stable")] = np.arange(a.size)
    return (rank / (a.size - 1) * 65535).astype(np.uint16).reshape(shape)


def contagion_map(seed, w, h):
    import numpy as np
    rng = np.random.default_rng(seed)
    k = h / 270.0
    n = (0.52 * value_noise(rng, w, h, rng.uniform(18, 65) * k)
         + 0.30 * value_noise(rng, w, h, rng.uniform(7, 20) * k)
         + 0.18 * value_noise(rng, w, h, rng.uniform(2, 6) * k))
    cost = 0.12 + np.exp(rng.uniform(5, 9) * (n - 0.5)) + rng.uniform(0.15, 0.65) * rng.random((h, w))
    cost = cost.ravel().tolist()
    wide = max(1.0, (w / h) / (16 / 9))
    seeds = []
    for _ in range(round(int(rng.integers(6, 13)) * wide)):
        x, y = int(rng.uniform(0.06, 0.94) * w), int(rng.uniform(0.08, 0.92) * h)
        seeds.append((y * w + x, float(rng.uniform(0, (w * h) ** 0.5 * 0.12))))
    return ranked(arrival(cost, seeds, w, h), (h, w))


def write_pair(path, smooth_path, a):
    import numpy as np
    from PIL import Image
    h, w = a.shape
    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[..., 0] = a >> 8
    rgb[..., 1] = a & 255
    smooth = blur(a.astype(np.float64) / 65535.0, 2.5)
    for dest, arr in ((path, rgb), (smooth_path, rgb16(smooth))):
        tmp = f"{dest}.{os.getpid()}.tmp.png"
        Image.fromarray(arr, "RGB").save(tmp)
        os.replace(tmp, dest)


def pool_dir(gw, gh):
    d = os.path.join(CACHE, "contagion", f"{gw}x{gh}")
    os.makedirs(d, exist_ok=True)
    return d


def pool_pair(d, k):
    return os.path.join(d, f"map-{k}.png"), os.path.join(d, f"map-{k}-smooth.png")


def fill(d, k, gw, gh):
    path, smooth = pool_pair(d, k)
    write_pair(path, smooth, contagion_map(random.randrange(1 << 30), gw, gh))
    return path, smooth


def spread(gw, gh):
    d = pool_dir(gw, gh)
    made = [k for k in range(POOL) if all(os.path.exists(p) for p in pool_pair(d, k))]
    if made:
        k = random.choice(made)
        return k, pool_pair(d, k)
    return 0, fill(d, 0, gw, gh)


def detach():
    if os.fork() != 0:
        return False
    null = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(null, fd)
    os.setsid()
    os.nice(19)
    return True


def renew(k, gw, gh):
    import time
    lock = open(os.path.join(CACHE, ".renew.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return
    time.sleep(4)
    fill(pool_dir(gw, gh), k, gw, gh)


def contagion(gw, gh):
    k, pair = spread(gw, gh)
    if detach():
        try:
            renew(k, gw, gh)
        finally:
            os._exit(0)
    return pair


def key_of(img):
    st = os.stat(img)
    return hashlib.sha1(f"{os.path.realpath(img)}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:16]


def outline_base(img):
    d = os.path.join(CACHE, "outline")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, key_of(img))


def cached_outline(base):
    try:
        meta = json.load(open(base + ".json"))
    except (OSError, ValueError):
        return None, False
    if meta.get("ok") and os.path.exists(base + "-field.png") and os.path.exists(base + "-line.png"):
        return (base + "-field.png", base + "-line.png"), True
    return None, True


session = None


def cutout(im):
    global session
    os.environ.setdefault("U2NET_HOME", os.path.join(CUTOUT, "models"))
    import onnxruntime
    from rembg import new_session, remove
    if session is None:
        opts = onnxruntime.SessionOptions()
        opts.enable_cpu_mem_arena = False
        opts.enable_mem_pattern = False
        providers = ["CPUExecutionProvider"]
        if "OpenVINOExecutionProvider" in onnxruntime.get_available_providers():
            providers.insert(0, ("OpenVINOExecutionProvider", {"device_type": "GPU", "cache_dir": os.path.join(CACHE, "ov")}))
        try:
            session = new_session(MODEL, opts, providers=providers)
        except Exception:
            session = new_session(MODEL, opts, providers=["CPUExecutionProvider"])
    return remove(im, session=session, only_mask=True)


def outline(img, force=False):
    base = outline_base(img)
    if not force:
        found, known = cached_outline(base)
        if known:
            return found
    try:
        import cv2
        import numpy as np
        from PIL import Image
    except ImportError:
        return None

    lock = open(base + ".lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    if not force:
        found, known = cached_outline(base)
        if known:
            return found

    im = Image.open(img).convert("RGB")
    im.thumbnail((FIELD_MAX, FIELD_MAX))
    mask_path = base + "-mask.png"
    if os.path.exists(mask_path):
        mask = Image.open(mask_path).convert("L")
    else:
        gate = open(os.path.join(CACHE, ".cutout.lock"), "w")
        try:
            fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return None
        if not room():
            return None
        mask = cutout(im).convert("L")
        mask.save(mask_path)
    m = np.asarray(mask.resize(im.size), np.float32) / 255.0
    h, w = m.shape
    b = (m > 0.5).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(b, connectivity=8)
    keep = np.zeros(n, bool)
    keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= 0.002 * w * h
    b = keep[lab].astype(np.uint8)
    cover = float(b.mean())
    unsure = float(((m > 0.1) & (m < 0.9)).mean())
    ok = 0.008 <= cover <= 0.72 and unsure <= 0.06
    meta = {"img": img, "ok": ok, "cover": round(cover, 3), "unsure": round(unsure, 3), "w": w, "h": h}
    if not ok:
        json.dump(meta, open(base + ".json", "w"))
        return None

    din = cv2.distanceTransform(b, cv2.DIST_L2, 5)
    dout = cv2.distanceTransform(1 - b, cv2.DIST_L2, 5)
    sd = dout - din

    inner = np.clip(din / max(np.percentile(din[b > 0], 99), 1.0), 0, 1)

    rng = np.random.default_rng(int(key_of(img)[:8], 16))
    noise = (0.6 * value_noise(rng, w, h, w / 9.0) + 0.4 * value_noise(rng, w, h, w / 28.0))
    warped = dout * (0.75 + 0.5 * noise) + noise * 0.08 * max(w, h)
    outside = b == 0
    order = np.zeros((h, w), np.float32)
    vals = warped[outside]
    r = np.empty(vals.size)
    r[np.argsort(vals, kind="stable")] = np.arange(vals.size)
    order[outside] = r / max(vals.size - 1, 1)

    edge = np.zeros((h, w), np.uint8)
    param_at = np.zeros((h, w), np.float32)
    contours, _ = cv2.findContours(b, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    for c in contours:
        if len(c) < 40 or abs(cv2.contourArea(c)) < 0.0008 * w * h:
            continue
        c = c[:, 0, :]
        seg = np.sqrt((np.diff(c, axis=0, append=c[:1]) ** 2).sum(1))
        s = np.concatenate([[0], np.cumsum(seg)[:-1]])
        length = s[-1] + seg[-1]
        s = (s - s[np.argmin(c[:, 1])]) % length
        p = np.minimum(s, length - s) / (length / 2)
        p[(c[:, 0] <= 1) | (c[:, 0] >= w - 2) | (c[:, 1] <= 1) | (c[:, 1] >= h - 2)] = -1
        edge[c[:, 1], c[:, 0]] = 1
        param_at[c[:, 1], c[:, 0]] = p
    line = np.zeros((h, w), np.uint8)
    if edge.any():
        _, labels = cv2.distanceTransformWithLabels(1 - edge, cv2.DIST_L2, 5,
                                                    labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(edge)
        table = np.concatenate([[0], param_at[ys, xs]])
        near = np.abs(sd) < SD_RANGE
        v = table[labels[near]]
        line[near] = np.where(v < 0, 0, np.clip(v * 255, 1, 255)).astype(np.uint8)

    rgb = np.zeros((h, w, 3), np.uint8)
    rgb[..., 0] = np.clip(dout / WIDE * 255, 0, 255)
    rgb[..., 1] = np.clip(inner * 255, 0, 255)
    rgb[..., 2] = np.clip((sd + SD_RANGE) / (2 * SD_RANGE) * 255, 0, 255)
    smooth = cv2.GaussianBlur(order.astype(np.float32), (0, 0), 4.0)
    lines = rgb16(smooth, extra=line)
    for suffix, arr in (("-field.png", rgb), ("-line.png", lines)):
        tmp = f"{base}{suffix}.{os.getpid()}.tmp.png"
        Image.fromarray(arr, "RGB").save(tmp)
        os.replace(tmp, base + suffix)
    json.dump(meta, open(base + ".json", "w"))
    return base + "-field.png", base + "-line.png"


def hex_of(rgb):
    return "#" + "".join(f"{round(max(0.0, min(1.0, c)) * 255):02x}" for c in rgb)


def colours(img):
    try:
        from PIL import Image
        im = Image.open(img)
        im.draft("RGB", (160, 160))
        im = im.convert("RGB")
        im.thumbnail((96, 96))
        q = im.quantize(8)
        used = sorted(i for _, i in q.getcolors())
        flat = q.getpalette()
        pal = [tuple(c / 255 for c in flat[3 * i:3 * i + 3]) for i in used]
    except Exception:
        return None
    if not pal:
        return None

    def chroma(c):
        _, light, sat = colorsys.rgb_to_hls(*c)
        return sat * (1 - abs(2 * light - 1))

    def luma(c):
        return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

    hue, light, sat = colorsys.rgb_to_hls(*max(pal, key=chroma))
    ember = colorsys.hls_to_rgb(hue, min(max(light, 0.62), 0.82), max(sat, 0.55))
    return hex_of(ember), hex_of(max(pal, key=luma))


def tint(img):
    d = os.path.join(CACHE, "tint")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, key_of(img))
    try:
        found = open(path).read().split()
        if len(found) == 2:
            return found
    except OSError:
        pass
    found = colours(img)
    if found:
        with open(f"{path}.{os.getpid()}.tmp", "w") as f:
            f.write(" ".join(found))
        os.replace(f"{path}.{os.getpid()}.tmp", path)
    return found


def is_still(img):
    return img.lower().endswith(STILLS) and os.path.isfile(img)


def cutout_ready():
    return os.path.exists(os.path.join(CUTOUT, "ready"))


def room():
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) * 1024 >= CUTOUT_ROOM
    except OSError:
        pass
    return False


def outline_capped(img):
    cmd = [VENV_PY, os.path.abspath(__file__), "outline", img]
    run = shutil.which("systemd-run")
    if run:
        cmd = [run, "--user", "--scope", "-q", "-p", f"MemoryMax={CUTOUT_CAP}", "-p", "MemorySwapMax=0", *cmd]
    done = subprocess.run(cmd, check=False, capture_output=True, text=True, env=dict(os.environ, OMP_NUM_THREADS="4"))
    base = outline_base(img)
    if done.returncode not in (0, 1) and not cached_outline(base)[1]:
        json.dump({"img": img, "ok": False, "failed": done.returncode}, open(base + ".json", "w"))
    return done.returncode == 0


def outline_later(img):
    if detach():
        try:
            outline_capped(img)
        finally:
            os._exit(0)


def pick(img, width, height):
    gw, gh = grid_of(width, height)
    found = None
    if is_still(img):
        found, known = cached_outline(outline_base(img))
        if not known and cutout_ready():
            outline_later(img)
    kind, pair = ("outline", found) if found else ("contagion", contagion(gw, gh))
    found = tint(img) if is_still(img) else None
    print(img, kind, *pair, *(found or ("-", "-")), sep="\t")


def warm(sizes, images):
    os.makedirs(CACHE, exist_ok=True)
    lock = open(os.path.join(CACHE, ".warm.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return
    os.nice(19)
    for size in sizes.split(","):
        gw, gh = grid_of(*(int(n) for n in size.split("x")))
        d = pool_dir(gw, gh)
        for k in range(POOL):
            if not all(os.path.exists(p) for p in pool_pair(d, k)):
                fill(d, k, gw, gh)
    for img in images:
        if is_still(img):
            tint(img)
    if not cutout_ready():
        return
    for img in images:
        if not is_still(img) or cached_outline(outline_base(img))[1]:
            continue
        print("outline" if outline_capped(img) else "contagion", img, flush=True)


def install():
    uv = shutil.which("uv")
    if not uv:
        print("needs uv", file=sys.stderr)
        return 1
    os.makedirs(CUTOUT, exist_ok=True)
    try:
        os.remove(os.path.join(CUTOUT, "ready"))
    except FileNotFoundError:
        pass
    venv = os.path.join(CUTOUT, "venv")
    if not os.path.exists(VENV_PY):
        subprocess.run([uv, "venv", "-q", "--python", "3.12", venv], check=True)
    subprocess.run([uv, "pip", "install", "-q", "--python", VENV_PY, "rembg", "onnxruntime",
                    "opencv-python-headless", "numpy", "pillow"], check=True)
    env = dict(os.environ, U2NET_HOME=os.path.join(CUTOUT, "models"))
    subprocess.run([VENV_PY, "-c", f"from rembg import new_session; new_session({MODEL!r})"], check=True, env=env)
    open(os.path.join(CUTOUT, "ready"), "w").close()
    return 0


def main(argv):
    cmd, rest = (argv[0], argv[1:]) if argv else ("", [])
    if cmd in ("pick", "warm") and not has_numpy():
        reexec_in_venv()
    if cmd == "pick" and len(rest) == 3:
        pick(rest[0], int(rest[1]), int(rest[2]))
        return 0
    if cmd == "warm" and rest:
        warm(rest[0], rest[1:])
        return 0
    if cmd == "outline" and rest:
        reexec_in_venv()
        try:
            r = outline(rest[0], force="--force" in rest)
        except Exception as e:
            print(e, file=sys.stderr)
            return 3
        if r:
            print(*r)
        return 0 if r else 1
    if cmd == "status":
        print("installed" if cutout_ready() else "missing")
        return 0
    if cmd == "install":
        return install()
    print("usage: wallpaper-transition.py pick IMG W H | warm WxH[,WxH] [IMG...] | outline IMG | status | install", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
