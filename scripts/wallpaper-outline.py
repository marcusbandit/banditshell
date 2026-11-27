import hashlib
import json
import math
import os

PREP = {
    "clip": (0.0, 0.0, 8.0),
    "tile": (8, 2, 32),
    "brightness": (0.0, -0.6, 0.6),
    "gamma": (1.0, 0.3, 3.0),
    "sharpen": (0.0, 0.0, 4.0),
    "radius": (2.0, 0.5, 10.0),
    "edges": (0.0, 0.0, 2.0),
}
ASPECTS = ("squash", "pad", "tiles")
LINES = ("ember", "ink", "white")
THRESHOLD = 0.5
OVERLAP = 0.25


def config_home(env):
    return env.get("XDG_CONFIG_HOME") or os.path.join(env.get("HOME") or os.path.expanduser("~"), ".config")


def overrides_dir(env):
    return os.path.join(config_home(env), "banditshell", "wallpaper-outlines")


def override_name(img):
    return os.path.basename(img.rstrip("/"))


def override_paths(folder, img):
    base = os.path.join(folder, override_name(img))
    return {"json": base + ".json", "mask": base + ".mask.png", "edits": base + ".edits.png"}


def number(value, default, low, high):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        return default
    return min(max(value, low), high)


def clean_prep(raw):
    raw = raw if isinstance(raw, dict) else {}
    prep = {}
    for name, (default, low, high) in PREP.items():
        value = number(raw.get(name), default, low, high)
        prep[name] = int(round(value)) if isinstance(default, int) else float(value)
    prep["aspect"] = raw.get("aspect") if raw.get("aspect") in ASPECTS else "squash"
    return prep


def is_identity(prep):
    p = clean_prep(prep)
    return (p["clip"] == 0 and p["brightness"] == 0 and p["gamma"] == 1 and p["sharpen"] == 0
            and p["edges"] == 0 and p["aspect"] == "squash")


def prep_tag(prep):
    p = clean_prep(prep)
    if is_identity(p):
        return ""
    used = {"aspect": p["aspect"]}
    if p["brightness"] != 0:
        used["brightness"] = p["brightness"]
    if p["gamma"] != 1:
        used["gamma"] = p["gamma"]
    if p["clip"] > 0:
        used["clip"], used["tile"] = p["clip"], p["tile"]
    if p["sharpen"] > 0:
        used["sharpen"], used["radius"] = p["sharpen"], p["radius"]
    if p["edges"] > 0:
        used["edges"] = p["edges"]
    return hashlib.sha1(json.dumps(used, sort_keys=True).encode()).hexdigest()[:10]


def clean_seed(raw):
    if not isinstance(raw, (list, tuple)) or len(raw) != 2:
        return None
    x, y = (number(v, None, 0.0, 1.0) for v in raw)
    if x is None or y is None:
        return None
    return [round(float(x), 4), round(float(y), 4)]


def clean_override(raw):
    raw = raw if isinstance(raw, dict) else {}
    size = raw.get("size")
    if not (isinstance(size, list) and len(size) == 2 and all(isinstance(v, int) and not isinstance(v, bool) and v > 0 for v in size)):
        size = None
    sha = raw.get("mask_sha")
    edited = raw.get("edited") is True and isinstance(sha, str) and sha != ""
    return {
        "prep": clean_prep(raw.get("prep")),
        "threshold": float(number(raw.get("threshold"), THRESHOLD, 0.02, 0.98)),
        "seed": clean_seed(raw.get("seed")),
        "edited": edited,
        "mask_sha": sha if edited else None,
        "size": size,
        "line": raw.get("line") if raw.get("line") in LINES else LINES[0],
    }


def line_colour(shade, choice):
    if choice == "white":
        return "#ffffff"
    if not shade:
        return None
    return shade[1] if choice == "ink" else shade[0]


def read_override(folder, img):
    try:
        with open(override_paths(folder, img)["json"], "rb") as f:
            data = f.read()
        raw = json.loads(data)
    except (OSError, ValueError):
        return None, ""
    if not isinstance(raw, dict):
        return None, ""
    return clean_override(raw), hashlib.sha1(data).hexdigest()[:8]


def override_tag(folder, img):
    _, digest = read_override(folder, img)
    return f"-o{digest}" if digest else ""


def replace_file(path, data):
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def remove_file(path):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def write_override(folder, img, settings, mask_png=None, edits_png=None):
    os.makedirs(folder, exist_ok=True)
    paths = override_paths(folder, img)
    over = clean_override(settings)
    if mask_png:
        replace_file(paths["mask"], mask_png)
        over["edited"] = True
        over["mask_sha"] = hashlib.sha1(mask_png).hexdigest()[:12]
    else:
        remove_file(paths["mask"])
        over["edited"] = False
        over["mask_sha"] = None
    if edits_png:
        replace_file(paths["edits"], edits_png)
    else:
        remove_file(paths["edits"])
    body = {"file": override_name(img), **over}
    replace_file(paths["json"], (json.dumps(body, indent=2, sort_keys=True) + "\n").encode())
    return over


def clear_override(folder, img):
    for path in override_paths(folder, img).values():
        remove_file(path)


def preprocess(rgb, prep):
    import cv2
    import numpy as np
    p = clean_prep(prep)
    if p["brightness"] == 0 and p["gamma"] == 1 and p["clip"] == 0 and p["sharpen"] == 0 and p["edges"] == 0:
        return rgb
    x = rgb.astype(np.float32) / 255.0
    if p["brightness"] != 0 or p["gamma"] != 1:
        x = np.clip(x + p["brightness"], 0, 1) ** (1.0 / p["gamma"])
    if p["clip"] > 0:
        lab = cv2.cvtColor((x * 255 + 0.5).astype(np.uint8), cv2.COLOR_RGB2LAB)
        lab[..., 0] = cv2.createCLAHE(clipLimit=p["clip"], tileGridSize=(p["tile"], p["tile"])).apply(lab[..., 0])
        x = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB).astype(np.float32) / 255.0
    if p["sharpen"] > 0:
        x = np.clip(x + p["sharpen"] * (x - cv2.GaussianBlur(x, (0, 0), p["radius"])), 0, 1)
    if p["edges"] > 0:
        gray = cv2.GaussianBlur(cv2.cvtColor(x, cv2.COLOR_RGB2GRAY), (0, 0), 1.0)
        mag = np.hypot(cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3))
        mag = np.clip(mag / max(float(np.percentile(mag, 99)), 1e-6), 0, 1)
        lift = np.clip(p["edges"] * mag, 0, 1)[..., None]
        x = 1 - (1 - x) * (1 - lift)
    return (np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8)


def tile_starts(length, side):
    if length <= side:
        return [0]
    step = side * (1 - OVERLAP)
    count = math.ceil((length - side) / step) + 1
    return [round(i * (length - side) / (count - 1)) for i in range(count)]


def cut(rgb, aspect, run):
    import numpy as np
    h, w = rgb.shape[:2]
    if aspect == "pad" and w != h:
        side = max(w, h)
        fill = rgb.reshape(-1, 3).mean(0).astype(np.uint8)
        canvas = np.empty((side, side, 3), np.uint8)
        canvas[:] = fill
        ox, oy = (side - w) // 2, (side - h) // 2
        canvas[oy:oy + h, ox:ox + w] = rgb
        return np.ascontiguousarray(run(canvas)[oy:oy + h, ox:ox + w])
    if aspect == "tiles" and w != h:
        side = min(w, h)
        out = np.zeros((h, w), np.uint8)
        for start in tile_starts(max(w, h), side):
            if w > h:
                window = (slice(None), slice(start, start + side))
            else:
                window = (slice(start, start + side), slice(None))
            out[window] = np.maximum(out[window], run(np.ascontiguousarray(rgb[window])))
        return out
    return run(rgb)


def seed_order(b, seed, arrival, cell=4, gap=4.0):
    import cv2
    import numpy as np
    h, w = b.shape
    gw, gh = -(-w // cell), -(-h // cell)
    padded = np.zeros((gh * cell, gw * cell), np.uint8)
    padded[:h, :w] = b > 0
    small = padded.reshape(gh, cell, gw, cell).max(axis=(1, 3)) > 0
    if not small.any():
        return np.zeros((h, w), np.float32)
    sx = min(max(int(seed[0] * gw), 0), gw - 1)
    sy = min(max(int(seed[1] * gh), 0), gh - 1)
    if not small[sy, sx]:
        ys, xs = np.nonzero(small)
        k = int(np.argmin((xs - sx) ** 2 + (ys - sy) ** 2))
        sx, sy = int(xs[k]), int(ys[k])
    cost = np.where(small, 1.0, gap).ravel().tolist()
    at = np.array(arrival(cost, [(sy * gw + sx, 0.0)], gw, gh), np.float32).reshape(gh, gw)
    full = cv2.resize(at, (gw * cell, gh * cell), interpolation=cv2.INTER_LINEAR)[:h, :w]
    inside = b > 0
    top = max(float(np.percentile(full[inside], 99)), 1.0) if inside.any() else 1.0
    return np.where(inside, np.clip(full / top, 0, 1), 0).astype(np.float32)
