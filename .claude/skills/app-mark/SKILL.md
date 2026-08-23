---
name: app-mark
description: Redraw an application's icon for banditshell's sidebar as a themed vector mark, built from the app's own official logo and recoloured into the shell's palette. Use this whenever the user asks to fix, replace, improve or add the icon, logo or mark for a specific program ("take Zen Browser and fix its icon", "the Discord icon is wrong", "give Spotify a proper mark", "make an icon for X like you did for kitty"), or complains that an app shows a generic category glyph, clashing brand artwork, or an unreadable blob in the sidebar. Also use it when touching components/marks/, Apps.drawnMarks, or AppMark's drawn-mark table.
---

# A drawn mark for one application

The sidebar draws one mark per application. Most applications are served by the
three automatic answers already in the shell, and this skill is for the ones
where all three are wrong:

- **its own artwork** (`iconMode: colour`) is a photograph in a band made of one
  grey and one accent. kitty's is an orange cat on a black terminal.
- **a flat tint of that artwork** (`mono:`) is a silhouette, and a logo made of
  parts collapses into a blob.
- **the category glyph** (`iconMode: glyph`, the default) says "a terminal" when
  the question was "which terminal".

The answer is to take the application's official logo apart and put it back
together in the theme's colours, as vectors, so it is both recognisably that
application and made of the same stuff as the rest of the bar.

`components/marks/Kitty.qml` is the worked example. Read it before starting: it
is short, and its header comment is the argument for every choice below.

## What actually changes

Three files, always the same three:

| File | What you add |
| --- | --- |
| `components/marks/<Name>.qml` | the drawing |
| `services/Apps.qml` → `drawnMarks` | `"^<class>$": "<Name>"` |
| `components/AppMark.qml` → `drawnMarks` + a `Component` | `<Name>: <name>Mark` |

Nothing else. If you find yourself editing a style file
(`modules/sidebar/Workspace*.qml`) to make one application look right, stop:
marks are chosen by `AppIcons.markFor`, and a style that special-cases an app is
a style that will disagree with the next style.

## 1. Find the class, and check the mark is really wrong

The registry is keyed by the window class, not by the name a person uses.

```bash
hyprctl clients -j | python3 -c "import json,sys;print(sorted({c['class'] for c in json.load(sys.stdin)}))"
```

Then look at what the shell draws for it today (see step 7 for the screenshot
recipe). Sometimes the mark is fine and the real complaint is size, colour or
position, and none of that is fixed by drawing a new one.

Where a drawn mark sits in `AppIcons.markFor`: what the user picked in settings,
then `apps.icons` from config.json, then **this**, then whatever the current
icon mode works out, then the category glyph. So a drawn mark beats every
automatic answer and loses to both places a person said otherwise. That order is
the reason you should not reach for this skill when a one-line `apps.icons`
override would do: if the right answer is an existing Material Symbol, say so
and add the override instead.

## 2. Get the official logo

Prefer the project's own repository over an icon theme's copy: upstream is the
mark the application actually claims, and it is usually a clean multi-part SVG
rather than something traced.

```bash
curl -sL -o /tmp/<name>.svg https://raw.githubusercontent.com/<owner>/<repo>/master/logo/<name>.svg
```

If you cannot find an upstream SVG, `fd -i <name> /usr/share/icons` will find
the icon theme's, which is a fine second choice. If the only thing available is
a PNG, stop and say so: this skill draws vectors, and tracing a bitmap by hand
is not the job.

Note where it came from in the component's header comment. It is somebody else's
mark and the file should say whose.

## 3. Take it apart

```bash
python3 .claude/skills/app-mark/scripts/mark.py parts /tmp/<name>.svg -o /tmp/<name>-parts
```

This prints an index table (tag, the fill the file gives it, how big its path
is) and renders two PNGs: the logo as itself, and the logo with one flat colour
per element. **Read both images.** The colour-coded one is how you learn which
index is the face, which is the shadow under it, and, most importantly, which
shapes are HOLES: a part that shows a different part's colour through it is a
hole in the path above it, and holes are the whole trick in step 4.

## 4. Decide what each part is made of

The palette a mark may use is small on purpose:

- **the ink it is handed.** The mark gets a `colour` property, exactly as a
  status gauge's mark does. Whatever is drawing it passes the row's own colour,
  so the mark dims and brightens with focus like every other mark in the column.
  This is the only colour the drawing has, and it must never be a literal.
- **the same ink held back** (`Qt.rgba(colour.r, colour.g, colour.b, colour.a *
  0.7)`), for a part that is behind another part. This shell does not draw
  borders, so one plane in front of another is said with weight. Two or three
  steps is plenty: full, ~0.85, ~0.7.
- **`Appearance.colour.accent`**, for at most one small feature. kitty gets its
  eyes. This is the only thing in a mark that does not follow the ink, and a
  mark that accents half of itself is a mark that shouts.
- **nothing at all**, and this is the one to reach for first. A shape that the
  original fills with white or with the background is better left as a HOLE in
  the path above it, because then whatever the mark is standing on shows
  through: a plain cell, the hover marker, the accent sheet of the workspace you
  are on. The drawing is correct on all of them without knowing about any of
  them, and a hole survives being two pixels wide where a painted highlight has
  to guess the colour behind it and gets it wrong on one of the three.

So: drop the backdrop rectangle almost every logo has. Its job in the original
was to be the paper; here the shell is the paper.

## 5. Try it on at the size it will actually be

```bash
python3 .claude/skills/app-mark/scripts/mark.py preview /tmp/<name>.svg \
  --plan "1:ink@0.7,2:accent,3:ink,8:ink@0.85,9:accent" \
  -o /tmp/<name>-try
```

A plan is `INDEX:ROLE[@ALPHA]`, where the role is `ink`, `accent` or `drop`.
Anything you leave out is dropped. The command prints the tight bounding box of
what you kept (keep those four numbers, they are the component's `artX/artY/
artW/artH`) and renders the mark at 25px and 120px over the colour a sidebar
cell actually is, magnified so you can see the pixels.

**Read the preview.** The 25px one is the one that decides; a mark that only
works at 120px is a mark that does not work. Iterate on the plan here, where a
round trip is one command, rather than in QML where it is a reload and a
screenshot.

Two things this step is for:

- **Contrast between planes.** If the part behind is too close to the ink, the
  front part loses its edge; if it is too far, the mark falls apart into pieces.
  Try 0.45, 0.6, 0.75 and look.
- **What to throw away.** Hairline detail does not survive: kitty's whiskers
  came out as four sprays of dirt around the face and are simply not in the
  component. Drop the detail rather than shrinking everything else to make room
  for it. But drop as little as you can get away with, and never a part that
  carries the mark's meaning: kitty without its terminal is a cat, which is
  wrong however clean it looks.

If the user has a theme other than the default, pass the real colours with
`--ink`, `--accent` and `--bg`. You can lift them off a screenshot: the cell
colour and the brightest pixel of a neighbouring glyph are close enough to judge
by.

## 6. Write the component

Get the path data:

```bash
python3 .claude/skills/app-mark/scripts/mark.py paths /tmp/<name>.svg --only 1,3,8,2,9
```

Paste it **untouched**. Do not hand-edit path coordinates: the numbers are the
mark, and a translate belongs in the item that holds the Shape.

`components/marks/<Name>.qml`, following `Kitty.qml`:

```qml
import QtQuick
import QtQuick.Shapes
import qs.config

// <NAME>, DRAWN IN OUR COLOURS.
//
// [why this application needed drawing rather than the three automatic answers]
// [where the original came from]
// [what each part is made of and why, including what was dropped]
Item {
    id: root

    property color colour: Appearance.colour.text
    property real size: Appearance.font.iconSize

    // The drawing's own box, from `mark.py preview`.
    readonly property real artX: 24.75
    readonly property real artY: 834.862
    readonly property real artW: 190.5
    readonly property real artH: 195

    implicitWidth: Math.round(root.size * root.artW / root.artH)
    implicitHeight: root.size

    Item {
        anchors.centerIn: parent

        width: root.artW
        height: root.artH
        scale: root.size / root.artH

        Shape {
            width: 240      // big enough to hold the file's own coordinates
            height: 240
            x: -root.artX
            y: -root.artY

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.colour
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "..."
                }
            }
        }
    }
}
```

The parts that matter:

- **The two nested Items are the transform.** The inner one is the drawing's own
  box in the file's units and scales to the mark's size; the Shape inside is
  offset by `-artX/-artY` to bring the paths into that box. If the file's root
  `<g>` carries a `transform="translate(0 -812.362)"`, fold it into `artY` (the
  y you measured plus 812.362) rather than trying to undo it in the path data.
  Shape does not clip to its own size, so its `width`/`height` only need to be
  roomy.
- **`implicitWidth` follows the aspect, `implicitHeight` is the size.** A logo
  that is wider than it is tall should be drawn wider than it is tall, and
  `AppMark` centres it in the square it was given.
- **`fillRule: ShapePath.OddEvenFill` wherever a path has subpaths inside it.**
  That is what makes them holes instead of two more filled shapes. If your cat
  comes out blind or your prompt comes out solid, this is why.
- **`preferredRendererType: Shape.CurveRenderer`** on every Shape, so the curves
  antialias properly. Same reason `G2Rect` uses it.
- **Order is paint order**, back to front: the thing behind first.
- **A stroked part stays stroked.** `parts` marks those in the table as
  `stroke <colour>`, and they are a line rather than an area: filling one fills
  the region its line encloses, which for a logo drawn in strokes is a blob
  where the mark was. In QML that is `strokeColor` and `strokeWidth` with
  `fillColor: "transparent"`, and copy the original's cap and join
  (`capStyle: ShapePath.RoundCap`) or the ends come out square.
- Alpha comes off the ink:
  `Qt.rgba(root.colour.r, root.colour.g, root.colour.b, root.colour.a * 0.7)`.
  A literal hex anywhere in the file is a bug, `Appearance.colour.accent`
  excepted.

## 7. Register it, as a type

In `services/Apps.qml`, add the class to `drawnMarks`. The key is a regex tried
case-insensitively against the window class, so cover the variants that are the
same application (`"(discord|vesktop|webcord)"`).

In `components/AppMark.qml`, add a line to its `drawnMarks` table and a
`Component` holding the new type.

That second table looks redundant and is not. A mark reached only through a URL
built from a string at runtime is not part of the module graph, so Quickshell
does not watch it: every edit to the drawing changes nothing until the shell is
restarted, while every other file in the project hot-reloads. It cost an hour
once. Named as a type, it reloads like everything else.

## 8. Look at it on screen

The shell hot-reloads on save. Check it loaded cleanly, then look:

```bash
timeout 4 qs -p /home/bandit/banditshell log 2>&1 | tail -5
grim -o "$(hyprctl monitors -j | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["name"])')" -l 0 /tmp/bar.png
python3 -c "
from PIL import Image
im = Image.open('/tmp/bar.png').convert('RGB')
im.crop((8, 500, 56, 900)).resize((288, 2400), Image.NEAREST).save('/tmp/bar_zoom.png')"
```

Then **Read `/tmp/bar_zoom.png`**. The whole point of the last three steps is
that a mark is a picture, and the only way to know a picture is right is to look
at it. Crop tighter and magnify more for the one row you changed.

If you need the application running to see its mark and it is not, say so rather
than guessing; do not open the user's programs to make a screenshot happen.

Two hazards in this step, both learned the hard way:

- The log replays its history, so `grep -i error` will happily show you errors
  from ten minutes ago. Read the **tail**, and touch a file to force a fresh
  reload if you are unsure which pass you are looking at.
- If you change a setting to test something (`banditshell set ...`), put it back
  the moment you are done. Leaving the user's sidebar in a state they did not
  ask for reads as the change you just made.

## Then commit

One commit, the three files together, in the repo's voice: what was wrong with
the automatic answers for this application, what each part of the drawing is
made of, and what you dropped. See `git log` for the register.
