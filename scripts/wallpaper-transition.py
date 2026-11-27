#!/usr/bin/env python3
# Adapted from wallfx in pocket-dots by Diego Malagrida, GPL-3.0:
# https://github.com/diegoMalagrida/pocket-dots/blob/main/home/.local/bin/wallfx

import colorsys
import fcntl
import hashlib
import heapq
import importlib.util
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time

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
PACKAGES = ["rembg", "onnxruntime", "opencv-python-headless", "numpy", "pillow"]
MAP_NAME = re.compile(r"map-(\d+)-(\d+)\.png")


def sibling(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(os.path.dirname(os.path.abspath(__file__)), file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


Outline = sibling("wallpaper_outline", "wallpaper-outline.py")


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


def pair_of(d, k, gen):
    return os.path.join(d, f"map-{k}-{gen}.png"), os.path.join(d, f"map-{k}-{gen}-smooth.png")


def pool(d):
    newest = {}
    for name in os.listdir(d):
        m = MAP_NAME.fullmatch(name)
        if not m:
            continue
        k, gen = int(m[1]), int(m[2])
        if gen > newest.get(k, -1) and os.path.exists(pair_of(d, k, gen)[1]):
            newest[k] = gen
    return newest


def fill(d, k, gw, gh):
    path, smooth = pair_of(d, k, time.time_ns())
    write_pair(path, smooth, contagion_map(random.randrange(1 << 30), gw, gh))


def prune(d, k):
    keep = pool(d).get(k)
    for name in os.listdir(d):
        m = MAP_NAME.fullmatch(name)
        if m and int(m[1]) == k and int(m[2]) != keep:
            for path in pair_of(d, k, int(m[2])):
                try:
                    os.remove(path)
                except FileNotFoundError:
                    pass


def spread(gw, gh):
    d = pool_dir(gw, gh)
    newest = pool(d)
    if not newest:
        return None, None
    k = random.choice(sorted(newest))
    return k, pair_of(d, k, newest[k])


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
    lock = open(os.path.join(CACHE, ".renew.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return
    d = pool_dir(gw, gh)
    time.sleep(4)
    fill(d, k, gw, gh)
    time.sleep(10)
    prune(d, k)


def contagion(gw, gh):
    k, pair = spread(gw, gh)
    if detach():
        try:
            renew(k if k is not None else 0, gw, gh)
        finally:
            os._exit(0)
    return pair


def key_of(img):
    st = os.stat(img)
    return hashlib.sha1(f"{os.path.realpath(img)}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:16]


def overrides():
    return Outline.overrides_dir(os.environ)


def outline_dir():
    d = os.path.join(CACHE, "outline")
    os.makedirs(d, exist_ok=True)
    return d


def outline_base(img):
    return os.path.join(outline_dir(), key_of(img) + Outline.override_tag(overrides(), img))


def model_mask_path(img, prep=None):
    tag = Outline.prep_tag(prep)
    return os.path.join(outline_dir(), key_of(img)) + (f"-mask-{tag}.png" if tag else "-mask.png")


def hand_mask_path(img, over):
    if not over or not over["edited"]:
        return None
    path = Outline.override_paths(overrides(), img)["mask"]
    return path if os.path.exists(path) else None


def needs_model(img, over):
    return hand_mask_path(img, over) is None and not os.path.exists(model_mask_path(img, over["prep"] if over else None))


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


def cutout_for(im, prep):
    if Outline.is_identity(prep):
        return cutout(im).convert("L")
    import numpy as np
    from PIL import Image
    p = Outline.clean_prep(prep)
    rgb = Outline.preprocess(np.asarray(im), p)
    run = cutout_alone if p["aspect"] == "tiles" else lambda a: np.asarray(cutout(Image.fromarray(a)).convert("L"))
    return Image.fromarray(Outline.cut(rgb, p["aspect"], run), "L")


def cutout_alone(a):
    import tempfile
    import numpy as np
    from PIL import Image
    os.makedirs(CACHE, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=CACHE) as d:
        src, out = os.path.join(d, "in.png"), os.path.join(d, "out.png")
        Image.fromarray(a).save(src)
        subprocess.run([sys.executable, os.path.abspath(__file__), "cutout-one", src, out], check=True)
        return np.asarray(Image.open(out).convert("L"))


def thumbnail(img):
    from PIL import Image
    im = Image.open(img).convert("RGB")
    im.thumbnail((FIELD_MAX, FIELD_MAX))
    return im


def model_mask(img, im, prep=None):
    from PIL import Image
    path = model_mask_path(img, prep)
    if os.path.exists(path):
        return Image.open(path).convert("L")
    mask = cutout_for(im, prep)
    tmp = f"{path}.{os.getpid()}.tmp.png"
    mask.save(tmp)
    os.replace(tmp, path)
    return mask


def subject_mask(img, im, over):
    from PIL import Image
    hand = hand_mask_path(img, over)
    if hand:
        mask = Image.open(hand).convert("L")
        if mask.size == im.size:
            return mask
    return model_mask(img, im, over["prep"] if over else None)


def shape(m, threshold=Outline.THRESHOLD, seed=None, key="0"):
    import cv2
    import numpy as np
    h, w = m.shape
    b = (m > threshold).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(b, connectivity=8)
    keep = np.zeros(n, bool)
    keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= 0.002 * w * h
    b = keep[lab].astype(np.uint8)
    cover = float(b.mean())
    unsure = float(((m > 0.1) & (m < 0.9)).mean())
    ok = 0.008 <= cover <= 0.72 and unsure <= 0.06
    contours, _ = cv2.findContours(b, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    contours = [c for c in contours if len(c) >= 40 and abs(cv2.contourArea(c)) >= 0.0008 * w * h]
    found = {"ok": ok, "cover": cover, "unsure": unsure, "contours": len(contours), "w": w, "h": h}
    if not ok:
        return found, None, None

    din = cv2.distanceTransform(b, cv2.DIST_L2, 5)
    dout = cv2.distanceTransform(1 - b, cv2.DIST_L2, 5)
    sd = dout - din

    if seed:
        inner = Outline.seed_order(b, seed, arrival)
    else:
        inner = np.clip(din / max(np.percentile(din[b > 0], 99), 1.0), 0, 1)

    rng = np.random.default_rng(int(key[:8], 16))
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
    for c in contours:
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
    return found, rgb, rgb16(smooth, extra=line)


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

    over, digest = Outline.read_override(overrides(), img)
    im = thumbnail(img)
    mask = subject_mask(img, im, over)
    m = np.asarray(mask.resize(im.size), np.float32) / 255.0
    found, rgb, lines = shape(m, over["threshold"] if over else Outline.THRESHOLD, over["seed"] if over else None, key_of(img))
    meta = {"img": img, "ok": found["ok"], "cover": round(found["cover"], 3), "unsure": round(found["unsure"], 3), "w": found["w"], "h": found["h"]}
    if over:
        meta["override"] = digest
        meta["contours"] = found["contours"]
    if not found["ok"]:
        json.dump(meta, open(base + ".json", "w"))
        return None

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


def capped(args):
    cmd = [VENV_PY, os.path.abspath(__file__), *args]
    run = shutil.which("systemd-run")
    if run:
        cmd = [run, "--user", "--scope", "-q", "-p", f"MemoryMax={CUTOUT_CAP}", "-p", "MemorySwapMax=0", *cmd]
    return cmd


def capped_command(images):
    return capped(["outline", *images])


def capped_mask_command(img, prep):
    return capped(["mask", img, json.dumps(Outline.clean_prep(prep), sort_keys=True)])


def capped_env():
    return dict(os.environ, OMP_NUM_THREADS="4")


def outline_capped(images):
    if images:
        subprocess.run(capped_command(images), check=False, env=capped_env())


def give_up(base, img, why):
    with open(base + ".json", "w") as f:
        json.dump({"img": img, "ok": False, "failed": why}, f)


def outline_batch(images, force=False):
    os.makedirs(CACHE, exist_ok=True)
    gate = open(os.path.join(CACHE, ".cutout.lock"), "w")
    try:
        fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 1
    for img in images:
        if not is_still(img):
            continue
        base = outline_base(img)
        trying = base + ".trying"
        if os.path.exists(trying):
            os.remove(trying)
            if not cached_outline(base)[1]:
                give_up(base, img, "stopped")
            continue
        if not force and cached_outline(base)[1]:
            continue
        if needs_model(img, Outline.read_override(overrides(), img)[0]) and not room():
            return 1
        open(trying, "w").close()
        try:
            print("outline" if outline(img, force) else "contagion", img, flush=True)
        except Exception as e:
            give_up(base, img, str(e)[:200])
        finally:
            if os.path.exists(trying):
                os.remove(trying)
    return 0


def mask_job(img, prep):
    if not is_still(img):
        return 2
    path = model_mask_path(img, prep)
    if os.path.exists(path):
        print(path, flush=True)
        return 0
    os.makedirs(CACHE, exist_ok=True)
    gate = open(os.path.join(CACHE, ".cutout.lock"), "w")
    try:
        fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 1
    if not room():
        return 3
    try:
        model_mask(img, thumbnail(img), prep)
    except Exception as e:
        print(str(e)[:200], file=sys.stderr)
        return 4
    print(path, flush=True)
    return 0


def outline_later(img):
    if detach():
        try:
            outline_capped([img])
        finally:
            os._exit(0)


def pick(img, width, height, token):
    gw, gh = grid_of(width, height)
    found = None
    if is_still(img):
        found, known = cached_outline(outline_base(img))
        if not known and cutout_ready():
            outline_later(img)
    if found:
        kind, pair = "outline", found
    else:
        pair = contagion(gw, gh)
        kind = "contagion" if pair else "none"
    if not pair:
        print(token, "none", "-", "-", "-", sep="\t")
        return
    shade = tint(img) if is_still(img) else None
    if kind == "outline":
        over = Outline.read_override(overrides(), img)[0]
        colour = Outline.line_colour(shade, over["line"] if over else Outline.LINES[0])
    else:
        colour = shade[0] if shade else None
    print(token, kind, *pair, colour or "-", sep="\t")


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
        made = pool(d)
        for k in range(POOL):
            if k not in made:
                fill(d, k, gw, gh)
    stills = [img for img in images if is_still(img)]
    for img in stills:
        tint(img)
    if cutout_ready():
        outline_capped([img for img in stills if not cached_outline(outline_base(img))[1]])


def install_steps(uv, has_venv):
    venv = os.path.join(CUTOUT, "venv")
    steps = []
    if uv:
        if not has_venv:
            steps.append([uv, "venv", "-q", "--python", "3.12", venv])
        steps.append([uv, "pip", "install", "-q", "--python", VENV_PY, *PACKAGES])
    else:
        if not has_venv:
            steps.append([sys.executable, "-m", "venv", venv])
        steps.append([VENV_PY, "-m", "pip", "install", "-q", *PACKAGES])
    steps.append([VENV_PY, "-c", f"from rembg import new_session; new_session({MODEL!r})"])
    return steps


def install():
    os.makedirs(CUTOUT, exist_ok=True)
    try:
        os.remove(os.path.join(CUTOUT, "ready"))
    except FileNotFoundError:
        pass
    env = dict(os.environ, U2NET_HOME=os.path.join(CUTOUT, "models"))
    with open(os.path.join(CUTOUT, "install.log"), "w") as log:
        for step in install_steps(shutil.which("uv"), os.path.exists(VENV_PY)):
            if subprocess.run(step, stdout=log, stderr=subprocess.STDOUT, env=env).returncode != 0:
                return 1
    open(os.path.join(CUTOUT, "ready"), "w").close()
    return 0


def main(argv):
    cmd, rest = (argv[0], argv[1:]) if argv else ("", [])
    if cmd in ("pick", "warm") and not has_numpy():
        reexec_in_venv()
    if cmd == "pick" and len(rest) == 4:
        pick(rest[0], int(rest[1]), int(rest[2]), rest[3])
        return 0
    if cmd == "warm" and rest:
        warm(rest[0], rest[1:])
        return 0
    if cmd == "outline" and rest:
        reexec_in_venv()
        return outline_batch([a for a in rest if a != "--force"], force="--force" in rest)
    if cmd == "mask" and len(rest) == 2:
        reexec_in_venv()
        try:
            prep = json.loads(rest[1])
        except ValueError:
            return 2
        return mask_job(rest[0], prep)
    if cmd == "cutout-one" and len(rest) == 2:
        reexec_in_venv()
        from PIL import Image
        cutout(Image.open(rest[0]).convert("RGB")).convert("L").save(rest[1])
        return 0
    if cmd == "status":
        print("installed" if cutout_ready() else "missing")
        return 0
    if cmd == "install":
        return install()
    print("usage: wallpaper-transition.py pick IMG W H TOKEN | warm WxH[,WxH] [IMG...] | outline IMG... | mask IMG PREP | status | install", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
