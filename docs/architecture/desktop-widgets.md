# Desktop widgets: clear glass

The widgets on the bare desktop are five small panes (clock, weather, now playing, system, AI
limits) that sit on glass with no colour of its own, can be dropped anywhere, and each come in
three sizes. This page records why they look and behave the way they do. It was written with the
redesign in #891 (PR #892), when the owner asked for glass that bends like Apple's, has zero
colour and stays transparent, and for widgets placed one by one instead of a column that wrapped
like text.

## The material: no tint at all

A pane draws the wallpaper that is already behind it, changed in three ways: blurred, bent at the
rim, and lit along its edge. Nothing is painted on top of it. The old cards were the shell's
surface colour at 88%, which on a dark wallpaper reads as a hole cut in the picture; that was the
"too aggressive" part. A tint of any hue fights some wallpaper, and the owner's ask was zero
colour, so the glass carries none and takes all of its colour from what is behind it.

The cost is legibility on bright wallpapers. That is handled with light, not colour (see
Legibility below).

## Two blurs, made once per wallpaper

`components/GlassSource.qml` decodes the wallpaper once per screen and keeps two blurred copies
laid out the way the wallpaper window lays out the picture (cover, centred):

| Copy  | Resolution     | Blur  | Used for                          |
| ----- | -------------- | ----- | --------------------------------- |
| soft  | half the screen | 6 px  | the glass at rest                 |
| frost | a quarter       | 48 px | the glass in use, and its light level |

Both are rendered by `MultiEffect` into static textures, so the blur costs one pass when the
wallpaper changes and nothing per frame. A pane mixes the two by a `frosting` amount, which gives
a continuous blur from clear to frosted without blurring anything live. The panes sample these
textures at their own screen position, which is why the widget window covers the whole screen and
ignores exclusive zones: its coordinates are the wallpaper's.

## The bend

Apple's Liquid Glass reads as glass because of its edge: near the rim the picture behind it is
pulled inward and magnified, as if the pane were a thick slab with a rounded bevel. The centre is
left alone, so text over it is never distorted. `components/glass.frag` does the same with a small
physical model, per pixel:

```text
d      signed distance to the pane's squircle (the shell's radius and corner power)
x      depth into the rim: 0 at the edge, 1 once past the bezel
h(x)   bevel height, a convex squircle profile: (1 - (1 - x)^4)^(1/4)
h'(x)  its slope: (1 - x)^3 * (1 - (1 - x)^4)^(-3/4)
N      surface normal, tilted outward by the slope
ray    refract(straight down, N, 1 / 1.5)          glass index 1.5
shift  ray.xy / -ray.z * bend                      where the picture is read from
```

The squircle profile was chosen because it matches the shell's squircle corners and because it
is flat for most of its width and steep only at the very edge: the interior stays undistorted and
the bend gathers into a thin band, which is the look. The bezel is 1.25 times the large padding
(30 px at the default scale), capped at 30% of the pane's short side so small panes do not turn
into lenses. `bend` is 0.9 of the bezel.

The rim also splits light very slightly: red and blue are read at 0.95 and 1.05 of the shift. The
fringe that makes comes from the wallpaper's own colours, so it adds no colour of its own; it is
only there on the rim and only on wallpapers with something to split.

## Light

A 1.25 px rim highlight, lit from the top left. Every edge gets 30% of it; the part facing the
light gets the rest by how squarely it faces, and the far edge gets 60% of that, the way a glass
edge catches the reflection from inside. Inside the bezel a soft glow falls off with the bend.
The light is white and added, never a colour.

There is no shadow and no outer glow. The shell's rule for depth is thickness and layering, and
the owner has said no to glow; on dark wallpapers a shadow would be invisible anyway.

## Legibility without colour

White text has to read on any wallpaper, and the glass may not tint. Three neutral adjustments:

- The light level is capped. The cap is applied to the frost copy's brightness, not each pixel's,
  so a bright wallpaper dims evenly and keeps its detail and hue. Applied per pixel it flattened
  bright streaks into grey ones and looked dirty.
- Colour is pulled slightly toward grey (90% saturation at rest).
- A small neutral lift (2.5%) so the pane still reads on a near-black wallpaper.

On the owner's dark wallpaper the cap never engages and the lift is what shows. On a bright one
the cap does most of the work.

## States drive the glass

Every pane has one number, `raised`, eased with the shell's `Follow`: 0 at rest, 0.25 while
hovered, 1 while open or dragged. Each glass value is a straight line in it:

| Value      | Rest  | Open  |
| ---------- | ----- | ----- |
| frosting   | 0     | 0.85  |
| saturation | 0.9   | 0.7   |
| light cap  | 0.5   | 0.35  |
| lift       | 0.025 | 0.06  |
| rim light  | 0.14  | 0.24  |

So the glass is most transparent when nothing is asked of it. Hovering only lights the rim a
little; the frost comes with a click or a grab, which is what "more transparent, especially when
it's not in use" asked for.

The clock is the exception: the owner liked it as it was, so it has no glass at rest at all. The
glass fades in when it is hovered or opened, or when the wallpaper behind the digits is busy
enough that they would not read (the existing ink check in `Backdrop.qml`).

## Glass everywhere, without wiring

The widgets own their glass sources, but every other card in the shell (sheets, menus, the
what's new log, the wallpaper picker's pills, the workspace card) gets glass by default.
`components/GlassPanel.qml` finds what to sample on its own:

- Each `ScreenBackdrop` offers itself to the `Backdrops` registry under the window it lives in,
  and a panel uses the one in its own window. It has to be the same window: a window renders
  with its own scene graph, and a texture from another window's backdrop comes out black. A
  caller can still pass a `backdrop` of its own, as the desktop widgets do.
- The shell window has one per screen. Another layer window that wants glass makes its own
  `ScreenBackdrop`, screen-sized, at minus its place on the screen, so the picture lines up with
  the wallpaper. The screenshot picker does this.
- A panel works out where it reads the backdrop from: its place in the window minus the
  backdrop's (`components/glass-place.js`). The place follows every parent's position, so a card
  inside a scrolled list or a sliding sheet keeps sampling what is really behind it.
- While a panel shows on screen and samples a `ScreenBackdrop`, it holds it, and the backdrop
  captures the windows behind it live instead of every 1.5 seconds, so a window dragged under a
  card shows there at once.
- A window with no backdrop of its own gets the solid material described under Floating windows.
  A panel whose backdrop exists but is not ready, such as with the wallpaper off, keeps the
  translucent readable surface it had before.

### Glass on glass

A sheet inside a chassis pop-out, such as the launcher's Ctrl+K sheet over the launcher, has
the pop-out's frosted glass behind it, not the wallpaper. Sampling the wallpaper clearly there
would read as a hole punched through the pop-out. So a panel whose parents say there is glass
beneath (`glassBeneath` on a `LazyPanel` or the launcher, true while its pop-out has chassis
blobs) is drawn as a second pane: fully frosted, a little lighter and greyer, with a brighter
rim. It keeps the same colour as the pane under it and separates from it by light and edge, the
way one sheet of frosted glass reads over another.

### Floating windows

The files and mixer windows are ordinary toplevels. The compositor puts them wherever the user
drags them, over other windows, and the shell cannot read what is behind a toplevel, so they
cannot be refraction glass. Their sheets use a solid version of the same material: the window's
own neutral surface lifted toward white (`Appearance.colour.pane`), with the same top-left rim
light and no tint or shadow. Next to a glass card it reads as the same glass seen against an
opaque wall. The same material shows wherever a panel has no backdrop yet, for example while
the wallpaper is still loading or when it is turned off.

## Placement

Each widget is placed on its own and remembered per screen in
`$XDG_STATE_HOME/banditshell/desktop-widgets.json`.

- A drop anchors the widget to the screen edges nearest its centre, one horizontal and one
  vertical, and stores the gaps to them. A widget dropped top right stays top right when the
  sidebar folds or the resolution changes, and it grows away from those edges: a right-anchored
  widget grows to the left, a bottom-anchored one upward.
- The desk has a soft grid: a pitch of `padding.huge` stretched so the area ends on a whole cell,
  with `padding.large` between cells. A widget's glass covers whole cells, so two neighbours one
  cell apart sit exactly one gap apart and their edges line up. The pitch is stretched rather
  than fixed so a right- or bottom-anchored widget lands on the same grid as a left one.
- The widget stays exactly under the pointer while dragged, and nothing snaps while it is held.
  The grid shows as thin lines in the gutters between cells, brightest at the pointer and fading
  to nothing a few cells away. On release the widget glides softly into the nearest free cell. While any widget is held, the whole screen takes pointer
  input, so a fast drag that outruns the widget keeps going.
- Widgets never overlap at rest. A drop, a resize or a pin that would crowd another widget sends
  the one just touched to the nearest free cell; the others keep their places.
- With nothing saved, the widgets stack from the top in two groups: work on the left (system,
  AI limits), time and the day on the right (clock, weather, now playing). The first drag saves
  every widget's place, so nothing shifts later when, say, the weather loads.

The old column filled from one side and wrapped into a second column when it ran out of height.
The owner disliked exactly that wrap, and on a 5120 px screen a column wastes the width anyway.

## Three forms

Every widget has a small, medium and large form. The form it rests at is the owner's choice per
widget; nothing about it is global.

- Hovering never changes the size. It only lights the rim, the same on every widget.
- A click opens the large form in place, on the grid: its size is whole cells and it grows from
  one corner of its resting cell block. It takes the corner whose growth covers the fewest
  neighbours and stays on screen, preferring the one away from its anchored edges; closing
  shrinks it back into the same corner. Only one widget is
  large at a time; a click on it or on the empty desktop closes it. The open widget is drawn above
  the rest, and its glass samples the desk with the other widgets on it, so whatever it covers
  shows through its frost instead of hiding behind it.
- While a widget shows a size other than its resting one, a pin sits on the corner facing away
  from its anchor. Pressing it makes that size the resting one.
- Right-click offers the three sizes, with the resting one marked, and Reset position.
- When the form changes, the glass resizes and the forms cross-fade. Each form is pinned to the
  anchored corner, so a growing widget reveals more rather than sliding its content around.

| Widget      | Small                       | Medium                                        | Large                                         |
| ----------- | --------------------------- | --------------------------------------------- | --------------------------------------------- |
| Clock       | 05:24 and a short date      | hours over minutes, date (unchanged)          | adds the month, world clocks, next alarm      |
| Weather     | sky and temperature         | place, sky, temperature, high and low, feels like, wind, humidity | adds the next eight three-hour slots and the week |
| Now playing | cover, title, play or pause | larger cover, title, artist, controls, progress | big cover, scrubber with times, controls     |
| System      | three numbers with a thread of graph | three columns with graphs           | the columns plus the chosen one's detail (cores, VRAM, swap) |
| AI limits   | each provider's tightest window | every main window as a thin bar with its reset | adds the extra windows and when they were read |

The defaults rest the clock, weather, system and limits at medium, and now playing at small.

## Per-widget decisions

- The clock is kept as the owner liked it. The month moved into its large form because the calendar
  card only repeated the date written above it and had no events to show.
- Weather was liked but said too little. Medium adds feels like, wind and humidity, all
  read from the same wttr answer; large adds the hours and the week. High and low are labelled,
  since two bare numbers next to each other did not say which was which. The hours follow the
  weather place's clock, not the machine's.
- Now playing is rebuilt around the cover. The "Paused / app name" header is gone; the app is a
  quiet line in the large form only.
- The system meters were liked, apart from their backgrounds. They keep the label, number and
  graph, on one sheet of glass instead of three dark tiles. Clicking a column opens its detail.
- AI limits get one line per window: label, percent left, time to reset, and a 4 px bar in the
  provider's colour with a tick where an even pace would be. The nested cards, the hatching and
  the "left" after every number went.

## What went away

- The calendar card, folded into the clock.
- The timers card. The owner never uses it; timers still live in the island, the launcher and the
  CLI.
- The side setting, replaced by placement.

## Checking it

The widgets are rendered headlessly in a private gamescope at the owner's screen size, with
invented weather, track and limit data, and driven with QtTest's synthetic pointer events, which
do reach hover handlers. That covers rest, hover peek, open, drag and the menu. The glass was
checked on a dark, a bright and a colourful wallpaper. The pointer-input region cannot be checked
that way, since synthetic events skip the compositor; the fast-drag fix was found and checked
live.

## Open

- The glass shows a video wallpaper's poster, not the moving picture, and switches at once when
  the wallpaper changes instead of following its transition.
- The owner has notes on behaviour still to come.
- #876 asks to pick the weather city from the widget and to give memory more room.
