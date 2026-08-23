#!/usr/bin/env python3
"""Take an application's official SVG logo apart, and try it on in our palette.

Four subcommands, in the order you want them:

  parts    render the logo twice, as itself and with one flat colour per
           element, and print the index table. This is how you find out which
           index is the face and which is the shadow under it.
  paths    print the `d` of the elements you name, ready to paste into a
           ShapePath.
  preview  render a plan (index -> role) at real mark size over the colour the
           mark will actually sit on, and print the tight bounding box of what
           the plan keeps.
  bbox     just the tight bounding box, in the file's own user units.

A plan is `INDEX:ROLE[@ALPHA]` separated by commas, where ROLE is `ink`,
`accent` or `drop`:

  --plan 1:ink@0.7,3:ink,8:ink@0.85,2:accent,9:accent,0:drop

Needs rsvg-convert and Pillow, both of which are already here.
"""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is missing: uv pip install pillow (or use the system python)")

ELEMENT = re.compile(r"<(rect|path|circle|ellipse|polygon|polyline)\b[^>]*?/?>")
FILL = re.compile(r"fill:\s*([^;\"]*)")
FILL_ATTR = re.compile(r'\bfill="([^"]*)"')
DATA = re.compile(r'\sd="([^"]*)"')
VIEWBOX = re.compile(r'viewBox="([^"]*)"')

# Distinct enough that two neighbouring parts never read as one.
FLAGS = ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff",
         "#ff8800", "#8800ff", "#00ff88", "#888888", "#ff0088", "#88ff00",
         "#0088ff", "#884400", "#448800", "#004488"]


def load(path):
    """The file, its elements, and everything before the first one."""
    text = Path(path).read_text()
    els = [m.group(0) for m in ELEMENT.finditer(text)]
    if not els:
        sys.exit(f"{path}: no drawable elements found. Is it an SVG?")
    head = text[:text.index(els[0])]
    return text, head, els


STROKE = re.compile(r"stroke:\s*([^;\"]*)")
STROKE_ATTR = re.compile(r'\bstroke="([^"]*)"')


def fill_of(el):
    m = FILL.search(el) or FILL_ATTR.search(el)
    fill = (m.group(1).strip() if m else "")
    if fill and fill != "none":
        return fill
    m = STROKE.search(el) or STROKE_ATTR.search(el)
    stroke = (m.group(1).strip() if m else "")
    if stroke and stroke != "none":
        return f"stroke {stroke}"
    return fill or "(inherited/black)"


def strokes(el):
    """Whether this element is drawn as a LINE rather than as an area.

    Worth knowing before you repaint it: setting a fill on a stroke-only path
    fills the region its line encloses, which for a logo drawn in strokes (a
    wordmark, Spotify's bars) is a solid blob instead of the mark. It also
    decides how the path is written in QML: strokeColor and strokeWidth with a
    transparent fill, rather than the other way round.
    """
    fill = FILL.search(el) or FILL_ATTR.search(el)
    stroke = STROKE.search(el) or STROKE_ATTR.search(el)
    has_stroke = bool(stroke) and stroke.group(1).strip() not in ("", "none")
    no_fill = bool(fill) and fill.group(1).strip() == "none"
    return has_stroke and (no_fill or not fill)


def put(el, prop, value):
    """Set a property, wherever this element happens to keep its properties."""
    pattern = re.compile(rf"{prop}:\s*[^;\"]*")
    if pattern.search(el):
        return pattern.sub(f"{prop}:{value}", el)
    attr = re.compile(rf'\b{prop}="[^"]*"')
    if attr.search(el):
        return attr.sub(f'{prop}="{value}"', el)
    if 'style="' in el:
        return el.replace('style="', f'style="{prop}:{value};', 1)
    if el.rstrip().endswith("/>"):
        return el.replace("/>", f' style="{prop}:{value}"/>', 1)
    return re.sub(r">$", f' style="{prop}:{value}">', el, count=1)


def repaint(el, colour, alpha):
    """The element, painted, as a line if that is what it is and an area if not."""
    if colour is None:
        return None
    prop = "stroke" if strokes(el) else "fill"
    out = put(el, prop, colour)
    return put(out, f"{prop}-opacity", alpha)


def rebuild(head, els, plan, viewbox=None):
    """A new SVG holding only the elements the plan keeps."""
    out = head
    if viewbox:
        out = (VIEWBOX.sub(f'viewBox="{viewbox}"', out) if VIEWBOX.search(out)
               else out.replace("<svg", f'<svg viewBox="{viewbox}"', 1))
    for i, el in enumerate(els):
        painted = plan.get(i)
        # Not in the plan, or in it as `drop`: both mean this part is not in the
        # mark. Dropping by leaving it out is the same as dropping it by name.
        if painted is None or painted[0] is None:
            continue
        out += repaint(el, *painted)
    # Close whatever the head opened, outermost last.
    for tag in reversed(re.findall(r"<(svg|g)\b", head)):
        out += f"</{tag}>"
    return out


def size_of(head):
    """The user-unit box the file draws in: its viewBox, or its width/height."""
    vb = VIEWBOX.search(head)
    if vb:
        return tuple(float(v) for v in vb.group(1).replace(",", " ").split())
    w = re.search(r'\bwidth="([\d.]+)', head)
    h = re.search(r'\bheight="([\d.]+)', head)
    if w and h:
        return (0.0, 0.0, float(w.group(1)), float(h.group(1)))
    return None


def render(svg_text, out_png, width=None, height=None):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg_text)
        tmp = f.name
    cmd = ["rsvg-convert", tmp, "-o", str(out_png)]
    if width:
        cmd += ["-w", str(int(width))]
    if height:
        cmd += ["-h", str(int(height))]
    subprocess.run(cmd, check=True)
    return out_png


def units_bbox(svg_text, head):
    """The tight bounding box of some ink, in the file's own user units."""
    box = size_of(head)
    if not box:
        sys.exit("the root <svg> has neither a viewBox nor a width and height")
    vx, vy, vw, vh = box
    scale = 8
    with tempfile.TemporaryDirectory() as d:
        png = render(svg_text, Path(d) / "m.png", width=vw * scale, height=vh * scale)
        box = Image.open(png).convert("RGBA").getbbox()
    if not box:
        return None
    x0, y0, x1, y1 = (v / scale for v in box)
    return (round(vx + x0, 2), round(vy + y0, 2), round(x1 - x0, 2), round(y1 - y0, 2))


def parse_plan(spec, ink, accent):
    plan = {}
    for piece in spec.split(","):
        piece = piece.strip()
        if not piece:
            continue
        index, _, role = piece.partition(":")
        role, _, alpha = role.partition("@")
        alpha = float(alpha) if alpha else 1.0
        colour = {"ink": ink, "accent": accent, "drop": None}.get(role.strip())
        if role.strip() not in ("ink", "accent", "drop"):
            colour = role.strip()  # a literal colour, for trying something out
        plan[int(index)] = (colour, alpha)
    return plan


def cmd_parts(args):
    _, head, els = load(args.svg)
    print(f"{len(els)} elements in {args.svg}\n")
    print(f"{'idx':>3}  {'tag':<9} {'own fill':<22} d=")
    for i, el in enumerate(els):
        d = DATA.search(el)
        tag = ELEMENT.match(el).group(1)
        print(f"{i:>3}  {tag:<9} {fill_of(el):<22} {len(d.group(1)) if d else 0} chars")
    out = Path(args.out or tempfile.mkdtemp(prefix="mark-"))
    out.mkdir(parents=True, exist_ok=True)
    render(Path(args.svg).read_text(), out / "original.png", width=args.size, height=args.size)
    flagged = {i: (FLAGS[i % len(FLAGS)], 1.0) for i in range(len(els))}
    render(rebuild(head, els, flagged), out / "parts.png", width=args.size, height=args.size)
    print(f"\noriginal: {out / 'original.png'}\nby part:  {out / 'parts.png'}")
    print("Read both. The colour an index got in the table above is the colour it")
    print("has in parts.png; anything that shows a DIFFERENT part's colour through")
    print("it is a hole, which is the thing worth knowing before you repaint it.")


def cmd_paths(args):
    _, _, els = load(args.svg)
    for i in [int(v) for v in args.only.split(",")]:
        d = DATA.search(els[i])
        print(f"--- {i} ---")
        print(d.group(1) if d else f"(no d=; it is a <{ELEMENT.match(els[i]).group(1)}>, convert it or draw it by hand)")


def cmd_bbox(args):
    _, head, els = load(args.svg)
    keep = ({int(v) for v in args.only.split(",")} if args.only else set(range(len(els))))
    plan = {i: ("#ffffff", 1.0) for i in keep}
    box = units_bbox(rebuild(head, els, plan), head)
    print(f"x={box[0]} y={box[1]} w={box[2]} h={box[3]}" if box else "(nothing drawn)")


def cmd_preview(args):
    _, head, els = load(args.svg)
    plan = parse_plan(args.plan, args.ink, args.accent)
    body = rebuild(head, els, plan)
    box = units_bbox(body, head)
    if not box:
        sys.exit("the plan draws nothing")
    print(f"tight box of the plan: x={box[0]} y={box[1]} w={box[2]} h={box[3]}")
    print("Use those four numbers as the mark's artX/artY/artW/artH, so it fills")
    print("the size it is given instead of the file's own margin.")
    cropped = rebuild(head, els, plan, viewbox=f"{box[0]} {box[1]} {box[2]} {box[3]}")

    out = Path(args.out or tempfile.mkdtemp(prefix="mark-"))
    out.mkdir(parents=True, exist_ok=True)
    sizes = [int(v) for v in args.sizes.split(",")]
    strip = Image.new("RGB", (sum(s * 6 + 30 for s in sizes) + 30, max(sizes) * 6 + 60), args.bg)
    x = 30
    for size in sizes:
        png = render(cropped, out / f"at{size}.png", height=size)
        im = Image.open(png).convert("RGBA")
        big = im.resize((im.width * 6, im.height * 6), Image.NEAREST)
        strip.paste(big, (x, 30), big)
        x += big.width + 30
    strip.save(out / "preview.png")
    print(f"\nper size: {', '.join(str(out / f'at{s}.png') for s in sizes)}")
    print(f"together, magnified, on {args.bg}: {out / 'preview.png'}")
    print("Read preview.png. The SMALLEST size is the one that decides: a mark")
    print("that only works at 120px is a mark that does not work.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("parts", help="index the elements and render a colour-coded map")
    a.add_argument("svg")
    a.add_argument("-o", "--out", help="directory for the PNGs")
    a.add_argument("--size", type=int, default=240)
    a.set_defaults(fn=cmd_parts)

    a = sub.add_parser("paths", help="print the d= of the given indices")
    a.add_argument("svg")
    a.add_argument("--only", required=True, help="e.g. 1,3,8")
    a.set_defaults(fn=cmd_paths)

    a = sub.add_parser("bbox", help="tight bounding box in user units")
    a.add_argument("svg")
    a.add_argument("--only", help="e.g. 1,3,8; default is everything")
    a.set_defaults(fn=cmd_bbox)

    a = sub.add_parser("preview", help="render a plan at mark size over the shell's own colour")
    a.add_argument("svg")
    a.add_argument("--plan", required=True, help="INDEX:ROLE[@ALPHA],... where ROLE is ink|accent|drop")
    a.add_argument("--ink", default="#e1e6ea", help="the colour a mark is handed")
    a.add_argument("--accent", default="#7fb3d4")
    a.add_argument("--bg", default="#515f67", help="what the mark will sit on")
    a.add_argument("--sizes", default="25,120")
    a.add_argument("-o", "--out", help="directory for the PNGs")
    a.set_defaults(fn=cmd_preview)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
