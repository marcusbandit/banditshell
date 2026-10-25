# banditshell - Design Document

> A from-scratch desktop shell to eventually replace caelestia.
> Written 2026-07-28 as a reference. **Nothing is being built yet** - this is the
> captured plan and philosophy to return to when work actually starts.

Why this exists at all: caelestia is finished and excellent, but the constant urge to
tweak it is the tell that I'd rather own the whole mental model than live in someone
else's. This document is so that intent survives the gap between now and whenever I
actually start.

**Named 2026-08-01: banditshell.** Lives in `~/.banditshell`... no: `~/banditshell`, settings in
`~/.config/banditshell/config.json`, driven by the `banditshell` CLI, and its Wayland surfaces
announce themselves under the namespace `banditshell` (which is how the compositor's blur rule
finds them).

---

## 0. How I want AI to help

**REVISED 2026-08-01.** The original rule here was "I type every line myself". Dropped. The
assistant writes the code and puts it in the files.

What did **not** change: **I want to understand all of it.** The understanding requirement moved
from *authorship* to *architecture*:

- **The structure is mine.** I want to know how the shell is laid out, why each file exists, and
  what talks to what. Section 8 is the living map of that and must be kept current.
- **Explain the structure as it changes.** When a file is added, moved, or a boundary shifts,
  say so and say why. Don't let the tree drift ahead of my mental model.
- Code should be written to be *read*: **no comments, or close to it.** The rule
  was once "comments explain the non-obvious *why*"; that allowance inflated
  into essays in every file and was stripped on 2026-09-30. Now: no comments
  unless asked. If code needs explaining, rename or restructure it instead.

Original rejected alternative: assistant-as-tutor-only (explain, never write). It made the
project stall, which is the exact failure mode section 5 warns about.

---

## 1. Tech stack (decided)

Same foundation as caelestia:

- **Quickshell** - the Wayland shell toolkit ("build your own shell" is literally its purpose).
- **QML** - all the UI and reactive logic.
- **C** - for the parts that need it (native plugins / performance-sensitive bits), same as
  caelestia's compiled `Caelestia.Config` plugin pattern.
- Compositor: Hyprland (existing), talked to over its IPC socket.

Rationale for staying on Quickshell rather than going lower-level (Rust/GTK/etc.): "know
how my whole system works" is satisfied by writing *every widget myself*. I don't also
have to reimplement the compositor bindings to earn that. Quickshell keeps the project
about *my shell*, not about fighting a new toolkit. I can always drop to C (or lower) for
a specific widget that demands it. **caelestia stays on disk as something to learn from.**
It shows that the hard parts can be done (wallpaper backend, lock screen, IPC face-unlock
pill). Read it for the idea, then close it and write ours. No code crosses over.

---

## 2. The core design philosophy

### 2.1 Nothing at a glance

At rest, **the screen is empty**. No persistent bar. No always-on widgets. No clock sitting
there. Nothing is served before I ask for it.

This is the opposite of caelestia's always-present bar. The whole thesis: **information
appears in response to intent, not preemptively.**

The thin border caelestia always draws around the screen: I'm not a fan. I keep an
**invisible interaction region** (a hit-target ring / edge zones) for summoning things, but
it is **never drawn**. The border exists as a mechanism; it must not exist as decoration.

**DECIDED 2026-07-28: never visible by default.** The border is not decoration and must not
be drawn at rest. **Rejected:** a permanently visible frame, and painting the whole frame
solid whenever a widget is summoned (both read as caelestia's border, which I dislike).

**REVERSED 2026-08-01. The border is drawn, and it is part of the shell.** What I disliked was
not the existence of a frame, it was a thin line sitting *on top of* the desktop like a
decoration. A band of the same material as the panels, cut from the same shape, reading as the
chassis the desktop sits inside, is a different thing and I want it. Concretely:

- The band is **not an overlay**. It is the same surface as everything else the shell draws, on
  the normal shell layer, and it gives way to a fullscreen window the way a bar does.
- The band and the sidebar are **one shape** (`modules/Chassis.qml`), not two panels next to
  each other. See section 8 for why that matters.
- It **reserves its own space**, so windows sit inside it with the compositor's gap intact
  rather than jammed against it.

**FULLSCREEN, 2026-10-16: the monitor belongs to the window.** A fullscreen window (Hyprland's
fullscreen mode, not maximize) makes the shell on that monitor step aside: chassis, sidebar,
island, panels and menus stop drawing, transient panels close and refuse to open, the input
mask empties so no edge grab steals a click, and the shell takes no keyboard. Settings and
pinned things are hidden rather than closed and come back when the window leaves fullscreen.
The one thing left is the band's outer edge exactly as it looks at rest: the same seam ring,
the same rounded screen corners and the same frame colour outside them. `FullscreenBorder`
draws it with the chassis's own `BlobField`, the band cut down to the ring's width over the
solid surface, on the overlay layer because a fullscreen window covers the band's own layer.
Bare and a floating stream panel draw no edge at rest, so they draw none here either. The
reservations stay as they were, so the windows underneath do not re-tile on the way in or
out. Other monitors are untouched.

The ring takes its colour from the picture (2026-10-18). In the theme's colour it read as a
bright frame round the black bars of films, so once the melt is done the ring shows the
fullscreen window's own edge, while the frame outside the rounded corners stays black: a toplevel capture, refreshed eight times a second, shrunk to
a 32-pixel swatch and stretched back, then darkened. Black bars give a black edge that
disappears; bright content gives a soft darker edge in its own colour, so the rounded screen
still reads. `edge.fullscreen` (Settings, Shape and motion) turns the ring off for a plain
fullscreen.

The launcher is one exception (2026-10-17). Summoned over a fullscreen window, it opens on
the overlay surface that draws the edge ring, as one solid panel rising out of the ring with no
band or sidebar behind it. It takes the keyboard while it is open and closes back to the plain
fullscreen window. The password card is the other (2026-10-19): an application is blocked on
its answer, so it moves onto the same overlay surface and takes the keyboard there rather than
waiting, unseen, for the window to leave fullscreen. Every other panel and menu still refuses to
open there.

The change is a motion, not a cut. Hyprland fades every top-layer surface out under a
fullscreen window, so the overlay carries the transition: it starts as an exact copy of the
chassis at rest and melts the band out to the edge ring at `revealSpeed`, which tracks the
window's own easeOutExpo grow. Leaving runs it backwards; once the copy is back at rest the
real shell is shown under it and the copy fades out, which is also how the sidebar's icons
come back in.

This is deliberately close to caelestia's construction. **We are rebuilding caelestia's main
parts, with more control, because they are ours.** The point was never that caelestia is wrong;
it is that I want the whole mental model. Where caelestia solved something well, learn why
the idea works and build our own version of it from scratch. Don't invent a worse idea to be
different, and never copy its code: every line here is written here.

**But it MAY reveal itself through interaction.** The direction I like: the border
*deforms* near the cursor, so the reveal and the reaction are the same event. It isn't "a
border that distorts", it's "a distortion that shows a border was there". Local, transient,
tied to where I actually am.

Integration between a summoned widget and the screen edge is otherwise carried by **motion**:
widgets live behind the edge and slide out via a clipping container, so they read as
emerging from the frame.

**Direction for the menus (2026-08-01): metaball.** When panels and menus start appearing, they
should feel like they *separate out of* the chassis and merge back into it, the way two blobs
of liquid join and part, rather than sliding in as separate rectangles. The chassis already
being a single shape is what makes that possible: a menu is another region of the same shape,
so the join between them can be a smooth blend instead of an overlap. Worth building the
machinery for early rather than retrofitting it.

### 2.2 Intent summons the outcome

When I do something with my cursor, **the expected outcome should occur.** The interaction
*is* the request, and the request is fulfilled.

Example (illustrative, not final): cursor straight up to the **top-center** of the screen →
the **time** appears. Move to a corner → whatever belongs there. The mapping of
**screen region + gesture → widget** is the central interaction model of this shell, and it
is the thing most worth designing carefully.

Design note for that mapping: regions/zones must be **computed from data, not hardcoded**
(see `~/.claude/rules/math-over-hardcoding.md`). If there are N summon zones along an edge,
their positions come from a formula over N, never a fixed enum of percentages. The instant
the count varies, hardcoded slots become wrong and visually biased.

### 2.3 Everything reacts to interaction ("alive")

**Every interaction produces a visible/felt response.** Not just hover and click - the full
vocabulary:

- hover
- click
- click-drag
- drag (proximity / not-clicked, i.e. the cursor being *near* something reacts)
- typing
- moving a menu
- switching menus
- ... and so on for anything the user can do.

The feel to chase: **as if the intent of using the computer makes the computer comply.**
Alive, responsive, compliant to intent. Nothing is static. Nothing is dead. The computer
answers the *intent* of use, and only when asked.

Animation implementation for all this motion/summon/tracking comes in three curves, all chased
every frame so any of them can be caught and retargeted mid-flight:

- **Follow (`components/Follow.qml`), ease-out**, for anything that answers an input: a reveal,
  a press, a panel arriving. Exponential smoothing,
  `position += (target - position) * (1 - Math.exp(-speed * dt))` (see
  `~/.claude/rules/animation-smoothing.md`): it moves the moment it is asked, fast when far,
  gentle when close, safe at any dt.
- **Travel (`components/Travel.qml`), ease-in-out**, for something already on screen moving to a
  new place: the workspace marker, a menu gliding between sidebar icons, rows closing up, the
  next notification stepping forward. A critically damped follower: it starts gently, arrives
  gently, keeps its speed when the target moves, and never crosses past the target.
- **Spring (`components/Spring.qml`)**, for anything the hand can hold: a notification card, the
  island when it is pulled open or shut, a stack lifted away. A mass on a spring, solved exactly
  each frame (`components/spring.js`), with stiffness, damping and mass in `control.spring`. A
  finger holds it 1:1 (`hold`), a press catches it wherever it is in flight (`grab`), and letting
  go hands it the finger's speed (`release`), so a throw carries on the way it was thrown. Short
  of a throw it goes back to the middle with a little bounce, about four percent past it, by the
  owner's call on 2026-10-18. `control.dragResistance` is the give: how much a card resists the
  finger before it commits.

**This is a rule, not a default.** Anything in this shell that moves, tracks, reveals, resizes
or follows goes through one of those three. A `NumberAnimation` or a `Behavior` on a position is a
bug, with exactly one exception: a **looping clock** with no target being chased at all. The
whole list: the mic indicator's processing ripple and typing caret, the battery charge sweep and
low-charge throb, the scrolling-text marquee, the equalizer, the lyric
line's sung-gap clock, the lyrics loading pulse, the activity bubble's and the settings keyboard
widget's spinners, and the demo clocks of the settings scenes. Every one of them stops or freezes
when `Appearance.lessMotion` is true. No overshoot, bounce or flourish anywhere except under the
hand: the shell starts from no play at all, and anything playful comes back one deliberate piece
at a time. The first piece is the Spring's small bounce on what can be grabbed.

**Fades are motion too.** An opacity or a colour that changes goes through `Follow`
(`epsilon: Appearance.animation.fadeEpsilon`, since the default epsilon is in pixels) or
`components/FollowColour.qml`, never a `Behavior`. Both snap under `lessMotion`, so a reduced
motion setting now stills the fades as well. Speeds come from `Appearance.animation`:
`revealSpeed` for what used to be a fast fade, `trackSpeed` for normal, `settleSpeed` for slow,
`snapSpeed` for small knobs.

**A key gets an instant answer.** Anything a hotkey opens appears in its first frame, and a
hotkey, Esc or Enter that puts it away takes it at once: the key already announced the outcome.
`Appearance.instantly()` opens a window of a few frames in which both curves snap and the
duration tokens collapse; the IPC entry points and the surfaces' Esc and Enter handlers call it.
The pointer, touch and touchpad keep their origin: a surface grows out of what was clicked, and
a drag follows the finger. Reduced motion is the same switch held on: no motion at all, fades
included.

Three corollaries, each of them learned by shipping the mistake:

- **A snap is not smoothing.** `Follow.snap()` is for the first layout, and for placing
  something while it cannot be seen. Snapping something the eye is already on is how you get a
  jump back after having written the smoothing correctly.
- **If it flicks, look for a snap to a stale target, not for a missing animation.** The mic
  pill "flew in from the corner" on a monitor change while smoothing perfectly the whole time:
  it was snapping at the instant it appeared, to a position derived from an `activewindow` that
  had not refreshed yet, and then smoothly correcting. The animation was never the problem. So:
  while a thing is invisible, a target change is a PLACEMENT; once it is visible, the same
  change is a JOURNEY. Gate the snap on the reveal, not on the event.
- **Speed is per-journey, not per-shell.** Exponential smoothing takes the same time whatever
  the distance, which means velocity scales with distance. `trackSpeed` reads as tracking when
  a plate follows a workspace 200px and as a smear when the mic pill crosses 3000px of desk to
  another monitor. Widget-scale and desk-scale motion want different speeds; same curve.

### 2.4 Contextual prominence - same info, different formats, different places

The same information should be available **in different formats in different places, where it
makes sense.**

Worked example - the time:
- It's nice to have the time in **multiple** places where that's sensible.
- But it should **not** be the centerpiece when I'm looking at the battery or the wifi menu.
- Yet **still visible** in some peripheral/ambient form could be neat.

This implies a **hierarchy of prominence** driven by current context/intent:
- **Focus element** - the thing I summoned right now: large, central, the point.
- **Ambient/peripheral elements** - secondary info shown smaller, dimmer, at the edges,
  present but not competing for attention.

So a widget isn't "shown or hidden" - it has a *role* in the current context (focus vs
ambient vs absent), and that role changes as intent moves around the screen.

### 2.5 Motion: animate to teach, never to decorate

Source: "The Ridiculous Engineering Of Animations" (Enrico Tartarotti, 18:36). Every frame of
animation sits between the user's intent and the result, so it costs them time. Only information
they do not already have earns that time.

The rules, in the order the video builds them:

- Motion is a map. An animation teaches where a thing lives and where it came from: an app grows
  out of its icon, the volume slider slides out of the volume buttons, the island opens from
  itself. The same object should leave and return through the same place every time. A panel that
  enters from the top once and from the side the next time breaks the map, and the user feels it
  before they can say why.
- Copying nature is the starting point, not the goal. Physics (slow in, slow out, follow-through)
  makes motion read as real. Once the motion is copied, the next question is whether it should run
  at all.
- Animate what the user did not start, or what they have not yet learned. The first time an action
  happens, motion can teach. The thousandth time it only waits. A surface opened all day should
  not animate in at all, because a keyboard action already announces its own outcome.
- Animate what the user must find again. The video keeps a sidebar animated even when it hides by
  default, because the user can summon it and has to learn that it exists. Rarity and
  discoverability decide, not the kind of thing.
- The curve sets the speed as much as the duration does. Enter and exit use ease-out: progress is
  front-loaded, so the thing arrives fast and settles. Ease-in starts slow and is wrong for enter
  and exit. Something already on screen that moves to a new place uses ease-in-out.
- Motion can hide latency, but a result that arrives instantly can still be distrusted. A launch
  animation buys time while an app starts. A short settle at the end of an instant transfer
  convinced users the money had moved. Where the work is real, as with an upload, show the real
  progress instead.
- Every motion must be interruptible. A swipe can reverse mid-flight. A motion the user cannot
  retarget feels like lag even when it is short. Section 2.3's smoothing retargets by construction.
- When motion is switched off, the signal must survive. The game keeps its screen shake and its
  throw animation with animations disabled, because the shake is the only sign that damage landed.
  An animation that carries information needs a second channel for when it is removed: a state
  change, a colour, a blink on the item that was acted on.
- Tune against the thousandth repetition. macOS's desktop-switch slide shows where full-screen apps
  live, and it is disliked enough that people fake a trackpad swipe to suppress it. A spatial
  lesson that turns into friction gets switched off, and then it teaches nothing. Multiply each
  duration by how often it runs: 400 ms on something opened a thousand times a day is about
  6.7 minutes of waiting.
- Personality comes from timing. Bounce, overshoot and a long ease-in-out read as playful or
  premium. Work tools lean rigid and fast. This shell takes the rigid end. The one place a bounce
  lives is under the hand: whatever can be grabbed is a spring (section 2.3), so a card let go
  short of a throw swings a little past the middle and settles, the way a held object would.
  Nothing else overshoots, and the character comes from the pixel type and the chassis (section
  6).

Applied to this shell:

- A keyboard-summoned surface (the launcher, a workspace switch) appears without travel. Its first
  frame already shows it. Its response is the state change itself.
- Section 2.3 asks for a visible or felt response to every interaction. That response does not have
  to be movement. A colour, a dim, a blink or a fill can answer an action that should not travel.
- Anything the pointer or the island summons grows from its source, so the eye can follow it back.
  Section 18 holds the island's anatomy.
- Hover reveals keep a dwell timer on the first hover. Once a tooltip is open, neighbouring
  targets show theirs at once, because the user is already searching.
- A surface that is not summoned by the user keeps its motion, because the user has not yet
  learned it exists.

---

## 3. Feature completeness - menus handle the WHOLE domain

The system menus must handle **all** of their domain, not the happy path. No half-features.
Each custom menu should be *more* capable than a typical shell's, because I'm building it to
actually replace everything I use.

- **Wifi / network:** every wifi login type (WPA personal, WPA-Enterprise / 802.1X, open,
  captive portal), **hidden/secret networks**, **hotspot / tethering**, showing my **IP**,
  saved networks, forget/reconnect, ethernet too. Everything.
  - Reference: my existing `~/bin/wifi` CLI already handles open / WPA / 802.1X / hidden /
    captive-portal joins via nmcli with no sudo. Reuse that knowledge / logic.
- **Bluetooth:** full - scan, pair, trust, connect/disconnect, device battery levels, audio
  profile switching, remove, etc.
- **Sound:** full - per-app volume, output/input device switching, profiles, mute, defaults.
- **Same principle for every menu.** If the domain has a capability, my menu exposes it.

---

## 4. Feature list (my priority / importance order)

1. **Launcher** - the main thing I want. (Also the hardest to build *well*.)
2. **Time and date**
3. **Notification hub**
4. **Power menu**
5. **Workspace indicators + window** (current window)
6. **Sound control**
7. **Wifi / Ethernet menu**
8. **Bluetooth menu**
9. **Power indicator** (battery)
10. **Performance menu**
11. **Media menu**

---

## 5. Build order (NOT the same as importance order)

Importance order and build order are nearly reversed. The launcher is #1 to *have* and close
to worst to *build first* (app indexing + fuzzy ranking + keyboard nav + theming + exec, all
at once). Build in order of **rising difficulty**, so each widget teaches the skill the next
one needs.

**Tier 0 - the skeleton (build first even though it's low on the want-list)**
- **Time & date (clock).** The "hello world." Sets up the layer-shell window, the reactive
  property system, and - critically - the **visual language**: Monocraft loaded, spacing,
  colors, motion feel. Everything after inherits this. Also the first test of the
  summon-on-intent model (cursor to top-center → time).

**Tier 1 - run commands & read simple state (fast wins, morale)**
- **Power menu** - buttons that run `loginctl` / `systemctl`. Output-only, no state. Easiest.
- **Power indicator (battery)** - read one value (UPower or `/sys/class/power_supply`).
- **Performance menu** - same read-and-display loop on a timer, scaled to CPU / temp / mem.

**Tier 2 - compositor IPC**
- **Workspace indicators + window** - Hyprland IPC socket + event stream. First reaction to
  an external event source. Big everyday-use unlock.

**Tier 3 - DBus consumers (the skill behind most of what's left)**
- **Media menu (MPRIS)** - friendliest DBus intro, well-documented. Start the DBus journey here.
- **Sound control** - PipeWire / `pactl`.
- **Bluetooth menu** - bluez over DBus.
- **Wifi / Ethernet** - NetworkManager over DBus (hardest of the three).

**Tier 4 - the hard capstones**
- **Notification hub.** Secretly the hardest reactive piece: you don't *read* notifications,
  you **implement the daemon** (`org.freedesktop.Notifications` DBus *server*) plus history /
  persistence. Its middling importance rank hides its top-tier difficulty - budget for it.
- **Launcher.** My #1 want, built last. By now I'll have exec (power menu), styling (clock),
  and list + keyboard UIs (media / bluetooth).
  - **Escape hatch:** the launcher has two versions. A crude dmenu-style "list apps, type to
    filter, Enter to launch" is reachable *much* earlier (mostly exec + a filtered list, both
    of which exist by Tier 1-3). **Don't let "the launcher must be perfect" gate the start.**
    Ship the ugly one early, polish it as the capstone.

**The anti-pattern to avoid:** "I'll build the whole shell someday" → stays perpetually
someday. **The escape:** build *one widget* (the clock) my way, standalone, running next to
caelestia (Quickshell lets them coexist). Momentum beats the grand plan.

---

## 6. Visual / aesthetic direction

- **Font: Monocraft** (pixel / Minecraft-y monospace). A deliberate aesthetic, chosen so my
  shell *looks* different from caelestia's Google-Sans-Flex smoothness. Different look,
  different soul. (caelestia reference: Google Sans Flex sans, JetBrainsMono Nerd Font mono,
  Material Symbols Rounded icons.)
  - Because it's a pixel font, all text goes through `components/StyledText.qml`, which sets
    `renderType: Text.NativeRendering`. Qt's default distance-field renderer smears pixel-font
    stems into grey mush; native rendering keeps them on the pixel grid.
- **Corners are G2, never circular.** Every rounded shape goes through `components/SquircleRect.qml`
  (a squircle drawn with `QtQuick.Shapes`). `Rectangle.radius` is banned in this project: it's
  a circular arc, so curvature jumps at the corner and the eye reads a pinch.
  Portable rule: `~/.claude/rules/g2-corners.md`.
  - **A convex SquircleRect is a fragment shader, not a path.** Fill and inside stroke draw through
    `squirclefill.frag`, the same p-norm corner as the Shape's outline, so a size that animates
    costs a few uniform updates per frame instead of a new SVG path, a JS string and a curve
    tessellation. A concave corner keeps the `QtQuick.Shapes` path, which is the only one that
    can draw it. `shaded: false` forces the Shape for one instance.
  - **Where a panel meets a screen edge, the corner is CONCAVE** (a negative radius in
    `SquircleRect`). A convex corner there curls the panel away from the edge and leaves a notch of
    dead space, which is wrong: nothing is floating, the panel is part of the edge. Concave
    makes the panel's free edge sweep outward and arrive tangent to the screen edge. Convex is
    for things that genuinely float.
  - **A PICTURE cannot go through the primitive, so it is masked by one.** An image is a
    texture, not a path, so album art or a notification's thumbnail dropped into a rounded
    plate keeps its own square corners over the plate's curve, a pixel away from a G2 corner
    for comparison. `components/SquircleImage.qml` renders the picture to a texture and lets a
    SquircleRect of the same size eat it. Same shape, applied differently.
  - **An OUTLINE is allowed on a control, never on the body.** `SquircleRect` grew a stroke for the
    transport's play ring. The old "fill only" rule was about the chassis: a hairline on a
    contour that joins another shape reads as a seam through one object. A ring around a
    button joins nothing, and it is how to give a control a boundary without a solid fill.
    It is stroked INSIDE the item's bounds, because a ring is laid out as a target.
  - **A pill is an object or a place, and the two have different ends.** Decided 2026-10-17:
    both shapes stay, and every pill says which it is (`SquircleRect { pill: "object" }` or
    `pill: "place"`; radius and corner power follow from that, and a pill drawn any other way
    is a lint failure). An OBJECT gets true round ends (power 2): something you grab, press as
    one round target, or that marks a count or a state. Knobs and beads, drag handles, dots,
    badges and counts, round icon buttons, chips, the island's compact capsule and its
    bubbles. A PLACE gets the shell's own corner power: something sits in it or moves along
    it. Tracks, gauges and meters, text fields, rails, the highlight plate behind a row or a
    segment, cards. When unsure, ask what the hand does with it: dragged or tapped as one
    thing is an object; something lives in it or slides along it is a place. That is why a
    toggle is two shapes, a place (the track) holding an object (the knob), and why the
    island's capsule eases from round ends into the shell's corner as it grows into a card.
  - **A button is an object, whatever it is doing.** Decided 2026-10-18, retiring the
    Material 3 button: it keeps its round ends at rest, pressed and switched on, and nothing
    squares off. A press answers with the fill step and the press scale. A toggle that is on
    becomes the accent plate, so its state is a colour and survives reduced motion. Four
    emphases, named for what they are: `accent` for the one action a view is about, `plate`
    (the default), `ring` for a boundary without a fill, and `bare` for a label that lights on
    contact. No drop shadow under any of them: depth is material, not decoration.
- **At most three font sizes, shell-wide.** `small` / `normal` / `large` in
  `config/Appearance.qml` and nothing else. Hierarchy is carried by colour, weight and
  spacing instead. The one exception is `display` (one and a half times `large`), and
  it is only the island's clock: asked for bigger, by hand, on a screenshot. Portable rule: `~/.claude/rules/type-scale.md`.
- **Palette: the machine's, not the shell's.** The colours are not invented here. `~/.config/theme` is
  the colour authority: `theme-set` renders one theme into `current/` for every app on the box at
  once, and `config/Themes.qml` reads this shell's share (`palette.json`) and hands it to
  `config/Appearance.qml`, so the shell and Hyprland's window borders are the same object rather
  than two things that happen to match. One hue family climbing near-black to silvery white, with a
  saturated end (`dim` / `mid` / `bright`) spent sparingly so a bright stop reads as a specular
  highlight, plus one `alarm` outside the family.
  - **The Monocraft constraint is load-bearing.** Pixel-font stems are one device pixel, so
    anti-aliasing has nothing to work with and mid-tones turn text to mush. Pixel text goes a bright
    stop on a dark one. **Never on a mid tone.** That is why the panel is the darkest ramp stop and
    not a mid one.
  - Rounding matches too: `Appearance.rounding.normal` is 15, which is Hyprland's
    `rounding = 15`. Hyprland is already drawing superellipse corners there
    (`rounding_power = 4.0`), the same idea as our G2 smoothing.
  - If the theme conf changes, the render changes, and the shell follows it. One direction.
- **One state recipe.** Hover, press, selection and disabled look the same everywhere, built from
  the palette's fill steps and nothing else. Colour changes between states fade through
  `FollowColour`.

  | State | List row | Card or tile |
  |---|---|---|
  | rest | transparent | `fill` |
  | hover | `fill` | `fillStrong` |
  | pressed | `fillStrong` | `fillStronger` |
  | selected | `fillStrong`, label in `text` | `accentFill`, glyph in `accent` |
  | disabled | `Appearance.opacity.disabled` | `Appearance.opacity.disabled` |
  | focus | `Appearance.stroke.ring` in `accent` | `Appearance.stroke.ring` in `accent` |

  Applied in `MenuRow`, `Button` (a transparent plate takes the row column, an opaque one blends
  toward its label colour by the same fill step) and the settings tiles. A switched-on toggle,
  a checked button and the chosen segment of a `Segments` row are one thing, a state, so they
  share the solid `accent` plate with `accentText` on it. An off toggle is a `textFaint` ring
  around `fill` with a `textDim` knob. Decided 2026-10-25 in #172 and #175. `textGhost` is for
  decorative rules only; readable text, placeholders and disabled glyphs use `textFaint`.
- **Small constants have names.** `Appearance.padding.hair` (4), `Appearance.stroke.line` (1) and
  `ring` (the font stem), `Appearance.opacity.disabled` / `trail` / `glow`, the icon ladder
  `Appearance.icon.small` to `hero`, `Appearance.press.lift` and `grab`, and
  `Appearance.colour.pane` for the mock panels in settings scenes.
- **Distinctive, not generic.** Never trade a distinctive look for a generic "clean" one.
  Since I'm establishing the style from scratch, commit to an idiom early (the clock sets it)
  and build every later widget in that idiom.
- **Empty at rest, alive on contact.** The aesthetic *is* the philosophy in section 2:
  darkness/transparency at rest, motion and light on intent.

---

## 7. Open questions to resolve when work starts

- The concrete **region + gesture → widget** map: which screen zones summon what, how gestures
  are recognized, how overlapping intents resolve. (Compute zones from data, don't hardcode.)
- How a widget's **role** (focus / ambient / absent) is represented and transitioned as intent
  moves - one state machine? per-widget? a global "attention" model?
- ~~Where the **invisible interaction region** lives~~ **DECIDED 2026-07-28:** a single
  full-screen transparent `PanelWindow` whose `mask` is a **10px border ring** (matches
  Hyprland `gaps_out = 10`, which he already likes the look of). Built with
  `Region { width/height: screen } + Region { intersection: Intersection.Subtract }` for the
  inner cutout. Middle of the screen passes input through to apps; only the ring is solid.
  Summoned widgets are added back into the mask while active
  (`item: wanted ? thePill : null`) so hovering them doesn't count as leaving. **Mask gates
  input, opacity gates visuals** - keep those two separate. Masked areas must stay
  *contiguous* or the cursor crosses dead pixels and the widget flickers away.
  This one window is the foundation for ALL future summon zones, not one panel per widget.
  - **AMENDED 2026-08-01:** "one window" holds for *summon zones*, but **not** for anything that
    reserves space. A Wayland exclusive zone belongs to a whole surface anchored to one edge, so
    a full-screen surface anchored to all four edges cannot have one. Panels that displace tiled
    windows therefore get their own `PanelWindow`, and the ring window is set to
    `WlrLayershell.exclusionMode: ExclusionMode.Ignore` so it keeps hugging the physical screen
    edges instead of being pushed inward by them.
- Persistence/state store for notifications (Tier 4) and saved networks/devices.
- How much goes in **C** vs QML (start pure QML; drop to C only where measured need appears).

---

## 8. Code structure (living map - keep this current)

```
banditshell/
├── shell.qml                    entry point: Variants -> one set of surfaces per screen
├── preview.qml                  the preview router: BANDITSHELL_PREVIEW names the
│                                file in previews/ to open in its place
├── previews/                    the shell's pieces, opened alone in a window of
│                                their own - battery, calculator, files, the
│                                island, the lock face, notifications, qr,
│                                the quick controls panel, settings, the
│                                sidebar in both styles, the terminal
│                                workbench, windows, the gallery (`banditshell
│                                dev preview gallery`, `... preview lock`). They
│                                sit in a folder so the root stays just the two
│                                entry points, and the folder holds because a
│                                quickshell import path may point here: the `qs`
│                                symlink in ~/.config/quickshell is this checkout
├── .qmllint.ini                 which qmllint warnings the LSP may raise; the
│                                code keeps ImportFailure, DuplicatePropertyBinding,
│                                UnusedImports and RequiredProperty honest and
│                                turns the categories that cannot see through the
│                                singletons down to off
├── */qmldir                     one per QML folder, naming the module (qs.config,
│                                qs.services, ...) and every type in it; what lets
│                                the LSP resolve `import qs.config`. Regenerate
│                                with scripts/qmldirs.sh after adding files
├── packages/                    one module.json per package that has no folder of its
│                                own under modules/ (core, compositor, clock, ...);
│                                the others keep theirs at modules/<name>/module.json.
│                                docs/architecture/modules.md has the map
├── modules.baseline.json        the module boundary violations that exist today;
│                                `banditshell dev modules` fails on any not in it
├── cli/
│   ├── banditshell              the CLI; bin/banditshell links to it
│   └── commands.tsv             the command table scripts/completion-rules.sh
│                                parses out of the CLI's help header: verbs, rules,
│                                value lists. GENERATED and committed (`scripts/
│                                completion-rules.sh --write`); a test fails when
│                                it is stale. `banditshell api check` walks it
├── api/                         the stable API a user's binds are written against
│   ├── actions.tsv              the contract: one row per action id, its status,
│   │                            the API number it appeared in, the command it
│   │                            stands for today, one line of description
│   ├── released.txt             every id ever shipped, sorted. Append only; a test
│   │                            fails if the table loses one
│   └── shim.lua                 copied beside hyprland.lua as banditshell.lua. It
│                                never names an action or a verb and carries a
│                                format number, so it is replaced only by a newer
│                                format. Finds the checkout, loads lua/banditshell.lua
├── lua/
│   └── banditshell.lua          what a user's config requires: the ids as callable
│                                names, bs.bind, bs.describe, bs.run. At press time
│                                it does one hl.exec_cmd and nothing else
├── rules.baseline.json          how many violations of each house rule each file holds
│                                today; `banditshell dev lint` fails on any more
├── config/
│   ├── Config.qml               SINGLETON. ~/.config/banditshell/config.json, live.
│   ├── Compositor.qml           SINGLETON. What Hyprland/niri say about rounding + gaps.
│   ├── Themes.qml               SINGLETON. Named palettes (ramp + accents).
│   ├── ControlTuning.qml        SINGLETON. The gesture tunables (`control.*`) and the
│   │                            compositor's touchpad scroll direction, as the defaults
│   │                            Pull, GlideList, ScrollGesture and SignalBars take; a
│   │                            caller overrides them with the component's own property
│   └── Appearance.qml           SINGLETON. Config x Compositor x Themes -> the tokens.
├── components/                  generic, reusable, know nothing about the shell
│   ├── squircle.js              G2 corner geometry (pure maths, no QML)
│   ├── SquircleRect.qml               the ONE rounded-rect primitive; fill and/or outline;
│   │                                  `pill: "object"|"place"` sets radius and corner power
│   ├── squirclefill.frag        the convex path of it, drawn by a shader (+ .qsb)
│   ├── SquircleImage.qml              a picture cut to that same corner, by mask
│   ├── BlurredImage.qml         the same cut, the picture blurred to colour
│   ├── ImagePalette.qml         a picture's main colours and how much of it each
│   │                            covers, read off a 24px copy in a Canvas
│   ├── ColourField.qml          up to four colours blended into a slow, soft
│   │                            field, each as large as its share, all fields
│   │                            on one clock so two of them agree (+ .frag)
│   ├── Waveform.qml             levels as one smooth mirrored curve: a ring of
│   │                            levels, a playhead gliding through it, a shader
│   │                            drawing a B-spline with soft ends (+ .frag)
│   ├── CrossfadeText.qml        a line whose old words fade out under the new ones
│   ├── ScrollingText.qml        one line that fades at its edges and, when too
│   │                            long, scrolls round with a pause at the start
│   ├── blob/
│   │   ├── blob.frag            the chassis as a signed distance field
│   │   ├── blob.frag.qsb        compiled; rebuild with `banditshell dev shaders`
│   │   ├── BlobField.qml        the ShaderEffect that draws it
│   │   ├── island.frag          a pill and a bubble melting into each other, and
│   │   │                        whatever is drawn inside them, cut to that shape
│   │   └── IslandField.qml      its QML side
│   ├── ProgressRing.qml         a ring that fills: an app on its way
│   ├── AppMark.qml             one window's mark, from a spec: symbol/glyph/mono/image
│   ├── Follow.qml               a value that chases a target by exponential smoothing
│   ├── FollowColour.qml         the same for a colour; every colour fade goes through it
│   ├── Spring.qml               a value on a spring, for whatever the hand holds: held 1:1,
│   │                            caught mid-flight, thrown with the finger's speed; spring.js
│   │                            is its exact step (tests/spring.test.js)
│   ├── Pull.qml                 a directional swipe; the way in, and back out, that needs no hover
│   ├── ScrollGesture.qml        two fingers on a touchpad, delivered as that same swipe
│   ├── WheelStep.qml            the wheel the way a browser scrolls: 100 px a notch added to
│   │                            one target and glided to, touchpad pixels 1:1; every
│   │                            scrolling view carries one and the keys share its target
│   ├── GlideList.qml            a list that scrolls through WheelStep
│   ├── Separator.qml            a hairline divider
│   ├── StyledText.qml           the ONE text element
│   ├── Icon.qml                 the ONE icon glyph; verifies the name exists
│   ├── SignalBars.qml           a drawn strength meter (the font's is illegible)
│   ├── BatteryMeter.qml         a drawn battery: every level, and charging as motion
│   ├── Slider.qml               a bead on a rail; read-only loses the bead
│   ├── Toggle.qml               a switch
│   ├── reveal.frag             the blob a new wallpaper opens through
│   ├── RevealMask.qml          its QML side; a layer.effect, so it masks anything
│   ├── WallpaperSource.qml      one wallpaper, whatever kind of file it turns out
│   │                            to be: picture, SVG, GIF or video, behind one `ready`
│   ├── MenuRow.qml              icon + label + detail + trailing slot
│   ├── MenuLayer.qml            the rest of a row, folded up under it
│   ├── Segments.qml             a row of choices of which exactly one is taken;
│   │                            the sheet's two questions and the clipboard's tabs
│   ├── Button.qml                 THE one button: four emphases (accent, plate,
│   │                            ring, bare), always the object pill, the
│   │                            five-rung size ladder; a toggle's colour IS its state
│   ├── ButtonGroup.qml           several presses joined as ONE plate; a member
│   │                            lights inside it, the group asks who was pressed
│   ├── vt.js                    a terminal as a DATA STRUCTURE: the byte stream
│   │                            a shell speaks, turned back into rows. No QML in
│   │                            it, the way highlight.js has none
│   ├── base64.js                the wire codec, because Qt.atob returns a
│   │                            QString and a terminal stream is not text
│   ├── TerminalView.qml         that, drawn: one Text per ROW, backgrounds as
│   │                            rectangles under it, and keys back out as bytes
│   ├── highlight.js             what language is this, and where are its tokens
│   ├── CodeBlock.qml            that, coloured from the theme, one delegate per
│   │                            line so a 60,000-line paste costs 30 of them
│   ├── Tooltips.qml             what is hovered and what it says; one, shell-wide
│   ├── SecretField.qml          THE field you type a secret into: the
│   │                            keyring's and the wifi row's.
│   │                            One mark per character rather than an
│   │                            asterisk, each a different object pill from
│   │                            secret-marks.js, and only the NEW one moves.
│   │                            The secret leaves through `accepted` and by
│   │                            no other door: there is no readable text
│   │                            property, on purpose
│   ├── secret-marks.js          the mark family: a dot and a grain at four
│   │                            angles, all of them the object pill.
│   │                            Shape comes from the POSITION and never from
│   │                            the character, which would be the password
│   │                            written on screen in a code
│   ├── BalancedText.qml         a paragraph that breaks on purpose: same line
│   │                            count as greedy wrap, evened out, so a string
│   │                            somebody else wrote does not leave an orphan
│   ├── IdentityField.qml        the same slot for a network that wants to know WHO
│   │                            you are: a username, a password, and the method
│   │                            the two of them travel in (802.1X)
│   ├── AspectMark.qml           two rectangles: the screen as an outline, the
│   │                            picture solid inside it, both fitted to one box
│   ├── DropShadow.qml           the soft shadow under a floating thing, drawn
│   │                            from its shape rather than its pixels, so it
│   │                            costs nothing when the thing resizes every frame;
│   │                            takes the same `pill` role as the shape it mirrors
│   ├── FloatingTooltip.qml      a plain label floating above whatever it is
│   │                            dropped into, after the tooltip delay; for
│   │                            surfaces with no chassis to melt a tip out of
│   ├── QrScanner.qml            the camera, and whatever code it finds; needs
│   │                            zxing-cpp's `ZXingReader` on PATH to decode
│   ├── QrCamera.qml             its QtMultimedia half, loaded by URL, so a machine
│   │                            without the module only loses the scanner
│   └── QrCode.qml               the same square the other way round: a string as
│                                a card, ink on paper, every module a G2 corner
│                                that asks its neighbours; needs `qrencode`
├── services/                    state that outlives any one widget
│   ├── Hypr.qml                 Hyprland IPC -> clean workspace state, and
│   │                            what the launcher does to a window: fullscreen,
│   │                            maximize, restore, float, center, an exact
│   │                            place, another monitor or workspace. Each in
│   │                            Lua and in the legacy dispatcher form
│   ├── WindowLayouts.qml        which tiling layouts there are (dwindle, master,
│   │                            scrolling when core has it, hy3 when loaded,
│   │                            and every hl.layout.register in the Lua
│   │                            config) and switching between them live with
│   │                            hyprctl eval, so the files keep their own;
│   │                            apply_layout_binds(name) runs after, when the
│   │                            config defines one
│   ├── keybind-search.js        the parsed binds as "which chord does this":
│   │                            the chord written out, one entry per chord of
│   │                            a bind, and the words that find it
│   ├── tray-search.js           asking for the tray, and a tray item found by
│   │                            name or id
│   ├── special-workspaces.js    asking for the scratchpad or a special workspace
│   │                            and what its row says
│   ├── shell-actions.js         api/actions.tsv as launcher rows: wildcard ids
│   │                            expanded per panel, ids that only print or would
│   │                            recurse left out, arguments read from the
│   │                            description, and the command an id runs
│   ├── ShellActions.qml         api/actions.tsv and cli/commands.tsv, read once
│   ├── recent-documents.js      recently-used.xbel read into documents, secret
│   │                            names dropped, newest first
│   ├── RecentDocuments.qml      those documents, kept to the ones that still exist
│   ├── chords.js                hotkey chords as pure functions: same chord,
│   │                            legacy keyword form, readable form and the
│   │                            command a launcher hotkey runs; the launcher,
│   │                            the settings shortcuts list and LauncherHotkeys
│   │                            all read it from here
│   ├── layout-model.js          the window layout workshop's model: arrangements,
│   │                            regions, rules, the edits and their problems
│   ├── layout-lua.js            that model written as Lua for hyprland.lua, and
│   │                            the loader and bind lines around it
│   ├── HyprConfig.qml           the Hyprland config as a model: the tree
│   │                            (the file this compositor was handed with
│   │                            -c, else hyprland.lua, else hyprland.conf,
│   │                            + everything it requires or sources)
│   │                            scanned into binds, each carrying the file
│   │                            and lines it came from. Edits splice those
│   │                            lines and splice nothing else; every write
│   │                            is verified (`--verify-config`) before the
│   │                            compositor reloads, and a failed one is
│   │                            put back the way it was
│   │                            One option at a time goes the same way:
│   │                            `setOption("input:kb_layout", ...)` finds
│   │                            where hl.config or an hl.device block already
│   │                            sets it and rewrites that value in place, or
│   │                            adds it to the nearest table that exists (else
│   │                            a new hl.config call at the end of the main
│   │                            file). Options built by code, set under a
│   │                            condition, or set in two places are refused
│   │                            with the line they come from. No live
│   │                            `hyprctl keyword` after it: the Lua parser
│   │                            refuses that command, and the reload that
│   │                            follows re-applies the file
│   ├── hyprgen.js               that model, as text: a Lua-aware scanner
│   │                            (strings, escapes, long brackets, multi-
│   │                            line calls, block depth), chord parsing,
│   │                            line composition and the splice. Binds the
│   │                            scanner cannot fully own -- loops, submap
│   │                            functions, concatenation -- come back
│   │                            `dynamic`, read-only, with the chords their
│   │                            loop tables and aliases resolve to. No QML
│   │                            in it, the way vt.js has none, tested the
│   │                            same way
│   ├── Keyboards.qml            the user's own board, when they name one: a
│   │                            VIA definition copied into the shell's
│   │                            config and watched, aligned into keys, with
│   │                            the keymap VIA saved for it laid on top;
│   │                            the built-in shape (cheatsheet.shape); and
│   │                            the keys struck in cheatsheet.blocked
│   ├── keyboards.js             the board models as data: the drawn
│   │                            template (function row, ISO main block,
│   │                            numpad; ansi, iso or split), the VIA reader,
│   │                            legends by position, and the saved-keymap
│   │                            reader that names keys by keycode. No QML
│   │                            in it, tested in node
│   ├── whatsnew.js               the What's new log as DATA: entries parsed
│   │                            tolerantly and accumulated past the
│   │                            last-shown marker, the newest id as the
│   │                            version and the git tag for it. No QML in it, the way
│   │                            hyprgen.js has none, tested the same way
│   ├── update.js                the update's words: git's answer read into
│   │                            values, a failure said plainly with the
│   │                            files in the way named, and classify() and
│   │                            summary(), which read `git diff
│   │                            --name-status` (plus api/actions.tsv,
│   │                            install.sh and the incoming What's new
│   │                            entries) into restart or reload, commands,
│   │                            helpers, deps and edits in the way. The CLI
│   │                            runs it under node (`node update.js report`).
│   │                            It also says which branch a channel
│   │                            (stable or main) and an updates.branch
│   │                            override follow. No QML in it, tested in node
│   ├── Tray.qml                 StatusNotifierItem host: what runs without a window
│   ├── AppIcons.qml             what each app looks like: seen, picked, suggested
│   ├── DesktopIndex.qml         every installed desktop entry read once: its
│   │                            name, icon, Exec program, MimeType and
│   │                            categories, which Quickshell's own list leaves
│   │                            out
│   ├── DefaultApps.qml          the default app for links, folders, mail,
│   │                            pictures, video and terminals, read with
│   │                            `xdg-mime query default` and written with
│   │                            `xdg-mime default` for every type in the group
│   │                            (the terminal goes in xdg-terminals.list when
│   │                            xdg-terminal-exec is installed)
│   ├── StartupApps.qml          what starts with the session, from the places
│   │                            it can: exec lines in Hyprland's Lua
│   │                            (commented out behind sourceEdits; one app
│   │                            dropped from a `shell-up` line), enabled
│   │                            systemd user units, ~/.config/autostart
│   │                            (`Hidden=true`), and, where its unit is
│   │                            enabled, ~/.config/autostart-managed (the
│   │                            launcher's `disabled=true` overrides).
│   │                            Nothing here runs XDG autostart on
│   │                            Hyprland, so the shell launches those once
│   │                            per session, marked in XDG_RUNTIME_DIR
│   ├── desktop-entries.js       desktop file parsing, the autostart file
│   │                            text, Hidden toggling. No QML, tested in node
│   ├── default-apps.js          which entries offer to handle a group of
│   │                            types, and the terminal list. No QML, tested
│   │                            in node
│   ├── startup-apps.js          exec-line parsing and toggling, the `shell-up`
│   │                            wrapper's arguments, systemd unit listing. No
│   │                            QML, tested in node
│   ├── Audio.qml                PipeWire: sinks, sources, volume, mute
│   ├── Battery.qml              UPower, the low warning, and the nearly empty
│   │                            step: warn once, count down 30 s, then
│   │                            suspend or hibernate (battery.js is the
│   │                            pure part, tested in node)
│   ├── ChargeLimit.qml          battery.holdCharge / holdAt written to the
│   │                            battery's charge_control_end_threshold
│   │                            through a pkexec helper the installer puts
│   │                            in only when asked (install.sh
│   │                            --charge-limit); read back, never assumed
│   ├── Lid.qml                  holds a handle-lid-switch block inhibitor
│   │                            while there is a lid, watches logind's
│   │                            LidClosed, and does what power.lid.* says
│   │                            for battery, mains or screens attached;
│   │                            on a machine with no lid it runs nothing
│   ├── PowerProfile.qml         the power mode, read back live from
│   │                            power-profiles-daemon or tuned, never kept
│   │                            in config because other tools change it
│   ├── Suspension.qml           suspend, hibernate or lock for whoever asks;
│   │                            a hibernate the machine cannot do is a suspend
│   ├── Network.qml              NetworkManager: the wire and the radio, one entry per SSID
│   ├── Bluetooth.qml            bluez: adapter and devices
│   ├── Media.qml                MPRIS, with a stable choice of player: the one
│   │                            playing, else the one you last played and paused,
│   │                            or the one you picked. A paused player you never
│   │                            played, an old video in a browser tab, is never
│   │                            shown, even when it is the only one. Keeps
│   │                            its own clock, re-anchored on every honest report
│   │                            (seeks made in the app, pause, a new track, a
│   │                            rate change), deaf for 2.5s after its own seek and
│   │                            then asking the bus once, so a bridge's stale
│   │                            answer neither moves the bar nor sticks
│   ├── Lyrics.qml               the words to what is playing. A Spotify track is
│   │                            looked up first in what Spicy Lyrics already
│   │                            cached inside Spotify (word timing, backing
│   │                            vocals, duet sides); everything else, and
│   │                            whatever Spicy does not have, from lrclib.net.
│   │                            Asked only while something on screen holds it
│   │                            (the media card, the notch). install.sh puts
│   │                            Spicetify and Spicy Lyrics into Spotify when
│   │                            Spotify is there, and re-patches it after a
│   │                            Spotify update
│   ├── lyrics.js                LRC or Spicy's JSON in, one model out: lines of
│   │                            timed words, a parenthesis lifted onto a backing
│   │                            line of its own, the music between lines as a
│   │                            break; line-only lyrics get their words paced
│   ├── player-choice.js         which player Media shows, as a plain function
│   ├── SystemInfo.qml            /proc and /sys: cpu, memory, temperature
│   ├── Display.qml              the screen's comfort: brightness over DDC/CI
│   │                            (ddcutil, one strictly serial queue,
│   │                            --noverify, and NEVER a readback - Samsung
│   │                            Odyssey firmware reports 1% whatever the
│   │                            truth, so the shell caches the last-set
│   │                            level and owns it, persisted like warmth)
│   │                            and colour warmth through bin/bs-gamma, a
│   │                            daemon that OUTLIVES the shell (guarded
│   │                            spawn, state file in ~/.local/state, polled
│   │                            every 300ms) so Hyprland's LUT reset - a
│   │                            full-brightness flash - never runs at
│   │                            restart
│   ├── nightlight.js            when the screens should be warm: sunrise and sunset
│   │                            from a latitude and longitude, set times, and
│   │                            how far to ease at any moment. Display's timer
│   │                            asks it; a hand on the warmth wins to the next
│   │                            edge. No QML in it, tested in node
│   ├── TimeFormat.qml           the ONE place a time or a date becomes text,
│   │                            reading region.clock24 and region.dateFormat;
│   │                            every clock, calendar, lock face and file date
│   │                            goes through it, in English whatever the
│   │                            system language is. timeformat.js is the
│   │                            maths, tested in node
│   ├── Localisation.qml         the system's zone, language and formats, changed
│   │                            only when the panel asks (timedatectl, localectl,
│   │                            polkit asks for the password) and never at load;
│   │                            zone from network reads geoclue's demo client and
│   │                            the nearest zone in zone.tab. localisation.js is
│   │                            the parsing, tested in node
│   ├── Wallpaper.qml            the current wallpaper and the list to pick from;
│   │                            what kind each file is, its size, the colour
│   │                            groups it falls in, and a poster frame per video
│   ├── Notifications.qml        the notification DAEMON (a server, not a reader);
│   │                            also where quiet lives: a notification always
│   │                            lands in history, and quiet, the night window
│   │                            and the sender's rule decide popup and sound.
│   │                            History is saved to the state directory and
│   │                            comes back as dead entries (no buttons, no
│   │                            reply); notification-store.js,
│   │                            notification-search.js (the launcher's
│   │                            query, threads, ages) and
│   │                            notification-timing.js (mute and snooze
│   │                            spans) hold the pure parts. A rule can mute
│   │                            an app for a while (muteUntil); snooze puts
│   │                            a popup away and brings it back; an entry
│   │                            that arrives while quiet is marked withheld,
│   │                            and the end of quiet tells Notices how many
│   ├── AppNotifications.qml     the index over it: which application each one
│   │                            came from, so a launcher row can carry its own
│   ├── AlertSounds.qml          plays the three alert sounds (notification, low
│   │                            battery, error) from assets/sounds with pw-play
│   ├── Modes.qml                which mode is on and what it changed, so leaving
│   │                            it puts back exactly that; kept in modes.json
│   ├── Usage.qml                when this machine was awake, kept for the calendar
│   ├── Apps.qml                 desktop entries, and ranked search over them
│   ├── Uninstaller.qml          which package an app came from, and taking it
│   │                            away: scripts/uninstall-app.sh asks pacman,
│   │                            dpkg, rpm, xbps, apk, flatpak, snap or Steam,
│   │                            refuses when other packages need it, and runs
│   │                            the removal through pkexec, so the password is
│   │                            asked by Polkit below; a terminal only when
│   │                            there is no pkexec or no agent
│   ├── LauncherHotkeys.qml      a key for any launcher row, kept in config.json
│   │                            and bound LIVE with hyprctl eval, again after
│   │                            every Hyprland reload; the user's own Hyprland
│   │                            files are never written. The bind calls
│   │                            `banditshell panel launcher run <row id>`
│   ├── Clipboard.qml            what has been copied, and what each of them IS;
│   │                            runs its own wl-paste watcher, because the type
│   │                            list is the only place "file" differs from "text"
│   ├── Settings.qml             whether the settings panel is open, on which
│   │                            screen, at which page, and a row to reveal
│   ├── Power.qml                the ways a session can end, and how each is done
│   ├── Calculator.qml            arithmetic, once: how a number is written, what an
│   │                            operator does, and what a TYPED expression means.
│   │                            Two inputs onto one question, so they cannot
│   │                            disagree; the keypad's own state is not here.
│   │                            What it cannot do (units, dates, functions)
│   │                            goes to qalc when that is installed. Typed
│   │                            sums are read up to the last part that makes
│   │                            sense, so 5+5- still says 10
│   ├── Currency.qml             an amount in one currency, said in another:
│   │                            the ECB's daily rates, fetched when online
│   │                            and kept for when it is not. Coins (btc, eth
│   │                            and a dozen more) are currencies too, priced
│   │                            from CoinGecko only when one is typed and at
│   │                            most every ten minutes
│   ├── dates.js                 plain words about dates, read without qalc:
│   │                            days until christmas, monday in 3 weeks,
│   │                            10 days ago, week number, Easter. English and
│   │                            Danish; a date already past this year means
│   │                            next year's
│   ├── colours.js               a colour in hex, rgb or hsl said in the others,
│   │                            for the answer row and its swatch
│   ├── Lock.qml                 whether the screen is locked, and what decides it.
│   │                            Also the password on its way to PAM: typed into
│   │                            a buffer nothing outside can read, called WRONG
│   │                            the moment PAM has not said yes within
│   │                            lock.verdict ms (both answers take ~50 ms
│   │                            since the PAM stack runs nodelay; a wrong one
│   │                            used to sleep 2 s), and queued, not refused,
│   │                            when it is sent while the last one is out
│   ├── Keymap.qml               the keyboard's layouts, which one is on, and Caps
│   │                            Lock, read from Hyprland's main keyboard and
│   │                            re-read on its activelayout event; next() moves
│   │                            every keyboard to the next layout
│   ├── Keyring.qml              the KEYRING'S question, once the shell is the one
│   │                            asking it. gnome-keyring draws nothing: it asks
│   │                            whoever owns org.gnome.keyring.SystemPrompter,
│   │                            and with nobody there D-Bus activates gcr's GTK
│   │                            box. scripts/keyring-prompter.py owns the name
│   │                            instead and talks to this over its pipes. The
│   │                            second file here that knows a password, and it
│   │                            holds one for less time than Lock does: the
│   │                            secret goes straight down the helper's stdin and
│   │                            is never stored. An app that asks before the
│   │                            shell is up (Nextcloud, two seconds into a
│   │                            face-unlocked login) no longer gets gcr's box:
│   │                            the helper points the name's D-Bus activation at
│   │                            scripts/keyring-waiter.sh, so the question waits
│   │                            on the bus for the shell
│   ├── DarkMode.qml             whether apps are asked for dark: the freedesktop
│   │                            colour-scheme key, read and watched with
│   │                            gsettings, which portal-aware apps follow
│   ├── Polkit.qml               the shell as the polkit agent, so pkexec (an
│   │                            install, an uninstall, the charge limit) asks
│   │                            in the same card as the keyring. Only one agent
│   │                            per session, so scripts/polkit-takeover.sh
│   │                            stops any other (hyprpolkitagent, polkit-gnome,
│   │                            the KDE one) BEFORE the shell registers, and
│   │                            the setting being turned off starts them again.
│   │                            It registers once: Quickshell crashes when an
│   │                            agent is destroyed while its registration is
│   │                            still in flight. Previews never take over
│   ├── Tablet.qml               whether the machine is FOLDED OVER. The changes
│   │                            come from the compositor (a switch bind execs
│   │                            the CLI); the state at startup comes from
│   │                            scripts/tablet-state.py, and is allowed to fail.
│   │                            TWO switches, not one: the hinge switch trips at
│   │                            0 degrees as well as 360, so the LID vetoes it
│   │                            and a shut laptop is not a tablet. They fire
│   │                            unordered, so the fold settles before it counts.
│   │                            Also owns `docked`, which FrameExclusions reads:
│   │                            an exclusive zone belongs to a one-edge surface
│   │                            and the board is drawn in the four-edge one, so
│   │                            the two ends need one answer between them
│   ├── PenMap.qml               WHERE THE DRAWING TABLET POINTS, and nothing to
│   │                            do with Tablet.qml above, which is the hinge.
│   │                            A tablet is an ABSOLUTE device, so pointed at a
│   │                            32:9 panel its 224x148mm surface is stretched
│   │                            2.35x sideways. This owns the rectangle it maps
│   │                            to instead, in GLOBAL layout coordinates,
│   │                            because that is the only frame in which "which
│   │                            monitor is this on" has an answer. Clamps to
│   │                            that monitor, keeps the tablet's own aspect
│   │                            unless told not to, and converts to Hyprland's
│   │                            monitor-relative form on the way out. Applied
│   │                            with `hyprctl eval` and hl.device, because the
│   │                            Lua config killed `hyprctl keyword`; eval is
│   │                            WIPED by a reload, so it re-applies on
│   │                            configreloaded. Driven from the pad by
│   │                            scripts/pen-pad.py, and from `banditshell
│   │                            penmap` when the tablet is asleep and cannot
│   │                            ask for itself.
│   ├── PenButtons.qml           the pen's two side buttons, remapped. Hyprland
│   │                            has no such setting, and pen-pad.py reads the
│   │                            pad, not the pen, so scripts/pen-buttons.py
│   │                            grabs the pen and hands everything on through
│   │                            a stand-in device of the same name, with the
│   │                            buttons changed. Runs only while a button is
│   │                            off its default, so a pen as shipped is never
│   │                            touched
│   ├── Keystrokes.qml           the one service that types OUTWARD, and it needs
│   │                            TWO transports: wtype for characters (the
│   │                            compositor never acts on them, so no bind can
│   │                            fire) and ydotool for chords (a real uinput
│   │                            keyboard, so SUPER+1 works). Queued so two
│   │                            cannot race. NOT named `Keys`, which is QML's
│   │                            own attached type and would shadow every
│   │                            Keys.onPressed in the repo
│   ├── Files.qml                the file browser's whole mind: where it is,
│   │                            what is there, and the shell session it is
│   │                            having. THE SHELL OWNS THE DIRECTORY; see 17.
│   │                            home and openWith forward to System, and a
│   │                            reveal request from System lands here
│   ├── FilesUndo.qml            what Ctrl+Z can take back in the browser:
│   │                            trash, move, rename, paste. A delete comes
│   │                            back through gio's own trash record, and
│   │                            nothing is overwritten on the way back
│   ├── FileSearch.qml           files by name under home (fd), words inside
│   │                            them (ripgrep, one line a file, eight files,
│   │                            stopped the moment the line changes; never
│   │                            hidden files, where keys live), and one
│   │                            folder listed for a typed path, for the
│   │                            launcher; which hidden ones count is a setting
│   ├── Update.qml               whether the public repo is ahead of this
│   │                            checkout, and the one update in flight. It
│   │                            runs nothing of its own: `banditshell
│   │                            update check --json` finds what is waiting
│   │                            and what kind of change it is, and
│   │                            `update apply --detach` does the update in a
│   │                            session of its own, so a restart or a hot
│   │                            reload cannot kill it. Its progress is read
│   │                            back from update/progress.log and its
│   │                            outcome from update/result.json, which a
│   │                            fresh shell reads on start too. States: idle
│   │                            -> available -> downloading -> verifying ->
│   │                            restarting -> updated, or rolledback when
│   │                            the new shell did not start, or failed. A
│   │                            copy with commits of its own, or on another
│   │                            branch (a tried worktree), is told so, not
│   │                            offered a button that cannot work. Knows the
│   │                            channel it follows and the version of both
│   │                            sides; docs/architecture/updates.md tells the
│   │                            whole loop
│   ├── Notices.qml              what the shell itself has to say, as opposed
│   │                            to an application's notification: an update on
│   │                            GitHub, a new kernel, a restart it wants, a
│   │                            finished download. Each glances in the island
│   │                            for a few seconds, held while you look; the
│   │                            standing ones then wait under the clock until
│   │                            they are dealt with. A new track only glances
│   │                            when its player is not the focused window
│   ├── Activities.qml           the island's front door: a registry any source
│   │                            posts to (`push`, `update`, `end`), plus the
│   │                            running timers and the ringing alarm read from
│   │                            Clock. The island draws `shown`; a press goes
│   │                            to `activate`. In memory only
│   ├── activities.js            the registry's rules: ids, spans, progress,
│   │                            ordering, expiry, outcomes, the timer and
│   │                            alarm items, the level moments. No QML,
│   │                            tested in node
│   ├── Events.qml               the event stream: watches the workspace, panels,
│   │                            mode, quiet, media, activities, notifications and
│   │                            update state, and appends one JSON line per change
│   │                            to $XDG_RUNTIME_DIR/banditshell/events.jsonl for
│   │                            `banditshell events` (docs/events.md)
│   ├── events.js                the stream's rules: snapshot, diff into events,
│   │                            filter match, the rotating writer script. No QML,
│   │                            tested in node
│   ├── Levels.qml               volume, mute, brightness and mic mute as a
│   │                            second in the island, unless an open surface
│   │                            already shows that level
│   ├── LevelCover.qml           what a surface declares while it shows a
│   │                            level, so Levels stays quiet about it
│   ├── Moments.qml              the island's short moments, posted through
│   │                            Activities: a screenshot thumbnail, a Copied
│   │                            line, a Bluetooth audio device connecting.
│   │                            `island.moments.*` switches each one off
│   ├── moments.js               what those moments say and how long they last,
│   │                            the copy masking, the screenshot actions.
│   │                            No QML, tested in node
│   ├── Privacy.qml              reads the PipeWire graph and posts a privacy
│   │                            activity for each of microphone, camera and
│   │                            screen share that is in use, and removes it
│   │                            when the stream stops
│   ├── privacy.js               which PipeWire nodes and links mean a camera,
│   │                            a microphone or a screen share, and which
│   │                            apps own them. No QML, tested in node
│   ├── Screenshots.qml          the `captured(path)` signal the picker and
│   │                            `screenshot full` raise when a picture exists
│   ├── Downloads.qml            inotifywait on the XDG download folder. A name
│   │                            counts once it is a non-empty file with no
│   │                            .part or .crdownload beside it, which is what
│   │                            skips Firefox's empty placeholder
│   ├── Pacman.qml               checkupdates every few hours, and whether the
│   │                            kernel the machine RUNS is in the list. A
│   │                            running kernel whose modules folder lost its
│   │                            vmlinuz has been replaced: that is the restart.
│   │                            Results are kept in state so a hot reload does
│   │                            not ask the mirrors again. Its terminal upgrade
│   │                            is now only the fallback for SystemUpgrade
│   ├── pacman.js                checkupdates' answer read into values. No QML
│   │                            in it, tested in node
│   ├── SystemUpgrade.qml        pacman -Syu through pkexec, so the shell's own
│   │                            password prompt asks, run detached by
│   │                            scripts/system-upgrade.sh so a reload or a
│   │                            restart never kills it. Follows the log the
│   │                            runner keeps in the runtime dir and picks a
│   │                            running or unseen update back up after a reload;
│   │                            answers "Proceed with installation?" itself and
│   │                            hands every other question to the island
│   ├── system-upgrade.js        pacman's terminal output, progress bars and
│   │                            all, read into a phase, a fraction per stage,
│   │                            a question and plain-word failures. Tested in
│   │                            node against recorded runs
│   ├── Dictation.qml            gvoice: the live phase, language and levels off
│   │                            its socket (one connection for the whole shell),
│   │                            and the history the clipboard shows
│   ├── Weather.qml              the weather now, from wttr.in (located by the
│   │                            connection unless `weather.location` names a
│   │                            place), fetched when the island opens and the
│   │                            last reading is older than `weather.minutes`;
│   │                            the week ahead from Open-Meteo at the
│   │                            coordinates wttr.in returns, else wttr.in's
│   │                            three days
│   ├── weather.js               both answers read into days, and WMO codes into
│   │                            the icons wttr.in's codes already used
│   ├── WhatsNew.qml              the update's own changelog, read: entries
│   │                            newer than the marker in the user's config
│   │                            are what the What's new card shows. The log
│   │                            is a file IN the checkout, so only a pull
│   │                            can bring entries in - the available state
│   │                            cannot announce what it does not have. A
│   │                            config.json the shell had to create starts
│   │                            at the newest entry: a first install is not
│   │                            read the whole history
│   ├── StreamState.qml          streamer mode: the screen that carries the
│   │                            band while streaming. Every other screen
│   │                            floats - it keeps its pop-ups but reserves
│   │                            nothing and draws no frame, so no window moves
│   │                            - and Shell.offStageScreen sends what viewers
│   │                            must not read (notifications, the keyring
│   │                            prompt) to the band's screen. Follows
│   │                            hypr-mode: on every Hyprland reload it reads
│   │                            ~/.local/state/hypr/streamer and turns itself
│   │                            on or off to match
│   ├── Obs.qml                  OBS over its WebSocket, only while streaming:
│   │                            the password is read from OBS's own config,
│   │                            state arrives as events, and the one poll is
│   │                            the stream and recording clocks while they run
│   ├── ObsLink.qml              that WebSocket, made by URL at start; without
│   │                            qt6-websockets, Obs reads "missing" and the rest
│   │                            of the shell loads as usual
│   ├── obs.js                   that protocol as DATA: the challenge answer
│   │                            (SHA-256, since QML has no crypto), which
│   │                            sources are camera, screen, mic or desktop
│   │                            audio, and the stream's rate and drops
│   ├── Shell.qml                which ShellWindows exist, and the host end of
│   │                            Panels (open, toggle and isOpen by panel name)
│   ├── SessionControl.qml       core interface: lockRequested() and sleeping, so
│   │                            idle, suspend and the battery services never
│   │                            name Lock; Lock answers the request and
│   │                            publishes sleeping
│   ├── Notify.qml               core interface: alert(kind) and post(spec) for
│   │                            services that raise a sound or a notification;
│   │                            Notifications answers. notify.js builds the
│   │                            notify-send command and the category
│   ├── Focus.qml                core interface: focusedScreen (Hypr publishes
│   │                            it) and offStageScreen, the screen the
│   │                            streamer is not on (StreamState pins it)
│   ├── Panels.qml               core interface: open(name, args), toggle(name)
│   │                            and isOpen(name); Shell answers for the window
│   │                            panels, Settings claims its own name
│   └── System.qml               core interface: home, copyText, openWith and
│                                reveal, the helpers that used to live on Files
├── modules/                     actual shell UI
│   ├── ShellWindow.qml          THE surface: everything visible, all the input
│   ├── Chassis.qml              the band + sidebar as ONE shape
│   ├── BandProgress.qml         a long job's progress, drawn inside the top band
│   ├── FrameExclusions.qml      invisible; reserves the room the chassis occupies
│   ├── Ipc.qml                  the control surface the CLI talks to, as a flat
│   │                            list: one line per <Name>Ipc.qml, no logic.
│   │                            Each module keeps its own `qs ipc` handlers in
│   │                            its folder (CalculatorIpc, ClipboardIpc, FilesIpc,
│   │                            HotkeysIpc, KeyboardIpc, LauncherIpc, MediaIpc,
│   │                            MenuIpc, ModeIpc, PasswordIpc, PenIpc, PickerIpc,
│   │                            QuickControlsIpc, SessionIpc, SettingsIpc,
│   │                            SidebarIpc, StreamIpc, WallpaperIpc). Target
│   │                            names and function signatures are frozen by
│   │                            tests/ipc-targets.test.js against
│   │                            tests/fixtures/ipc-targets.json
│   ├── panel/                   the panel contract, owned by core
│   │   ├── LazyPanel.qml        a panel built the first time it is asked for
│   │   ├── PanelIpc.qml         the handler base for a panel with no screen
│   │   │                        argument: toggle, open, close on the panel named
│   │   │                        by its target. A module subclasses it and adds
│   │   │                        status and its own verbs
│   │   ├── ScreenPanelIpc.qml   the same, with a screen argument on toggle and open
│   │   ├── PinnedPanelIpc.qml   the same for panels that are pinned rather than
│   │   │                        shown (island)
│   │   └── PanelWindows.qml     what those bases share, and what any handler asks
│   │                            of the shell windows: the window on a screen,
│   │                            toggle, open, close, pin, and the screen a verb
│   │                            means. A handler's own helpers cannot live on
│   │                            its root, since every function there is a verb
│   ├── cli.js                   the words the CLI speaks: durations, times of
│   │                            day, repeat days, columns
│   ├── ipc/                     the handlers that have no module folder of
│   │                            their own, grouped by package: ClockIpc (timer,
│   │                            alarm, zone), AudioIpc (output), DisplayIpc
│   │                            (screen, tablet), NotificationsIpc (notifications,
│   │                            quiet), CompositorIpc (migration), HostIpc
│   │                            (border), CoreIpc (shell)
│   ├── Tooltip.qml              the one tooltip, drawn wherever it was asked for
│   ├── island/                  the top centre, where everything that pops up
│   │   │                        now arrives (see 18)
│   │   ├── Island.qml           what holds the centre and which bubbles sit
│   │   │                        beside it (arrange() keeps the order), which
│   │   │                        size that makes, and the morph between them; a
│   │   │                        surface of its own, so the island never
│   │   │                        repaints the full-screen chassis. The strip in the
│   │   │                        band stays in ShellWindow: hover with a dwell,
│   │   │                        tap to pin, pull down
│   │   ├── ActivityRow.qml      the one anatomy: a mark, words, a sign. The
│   │   │                        compact island is one or a few of these, a row
│   │   │                        in the overview is one of these. Given more
│   │   │                        width it gives it to the middle, so bars gain
│   │   │                        bars
│   │   ├── ActivityLook.qml     how each kind looks: its mark, words and sign
│   │   ├── ActivityMark.qml     the mark alone, squircle in a row, round in a
│   │   │                        bubble
│   │   ├── ActivityBubble.qml   a kind beside the centre: its mark, plus the
│   │   │                        ring and badge that keep its state readable
│   │   ├── ActivityIpc.qml      the `activity` IPC target behind
│   │   │                        `banditshell island push|update|end|list`
│   │   ├── AlertDeck.qml        the notifications that are up: the newest in
│   │   │                        front with the rest peeking, spread into a list
│   │   │                        on hover and inside the overview
│   │   ├── IslandIpc.qml        the island's `qs ipc` handler; InspectIpc.qml
│   │   │                        holds the inspector's
│   │   ├── IslandInspector.qml  `banditshell dev inspect island`: a panel that
│   │   │                        makes up each situation on the live island,
│   │   │                        so it can be looked at, hovered and clicked;
│   │   │                        everything made up goes when it closes, and
│   │   │                        a click on a made-up row is held back
│   │   ├── MockNotification.qml what a made-up notification stands in for
│   │   ├── IslandOverview.qml   what going up to it shows: the clock at display
│   │   │                        size, its ink set into the corner at the same
│   │   │                        margin from the top as from the left; the date
│   │   │                        level with the clock's top and the weather on its
│   │   │                        baseline; arriving notifications, the live rows,
│   │   │                        the player, and the notifications row last
│   │   ├── IslandMedia.qml      the player, after the media card: cover with a
│   │   │                        shadow and words that cross-fade; the title on
│   │   │                        the cover's top, artist and album one tight
│   │   │                        group on its bottom, each one line that scrolls
│   │   │                        when it does not fit; the seek bar; the transport
│   │   │                        between the two times on one line; its words
│   │   │                        and its expand mark open the card
│   │   ├── TaskHeader.qml       the head every island view shares: a mark, a
│   │   │                        name, a line under it and a close mark
│   │   ├── IslandShellUpdate.qml the shell update, around the update menu
│   │   ├── IslandNotifications.qml the history as AlertDeck cards, fanned
│   │   ├── IslandNotificationPage.qml one notification at full size: the whole
│   │   │                        text, its actions and reply; where a tap goes
│   │   │                        when there is no app to open
│   │   ├── IslandTimers.qml     timers and alarms, around the clock menu
│   │   ├── IslandCalendar.qml   the month, around the calendar menu
│   │   ├── IslandWeather.qml    the week ahead, a day per column with its range
│   │   ├── IslandUpgrade.qml    the system update when the island has become
│   │   │                        it: stages, progress, pacman's questions as
│   │   │                        buttons, cancel while it is still safe, and a
│   │   │                        terminal that only watches
│   │   ├── upgrade-samples.js   made-up pacman runs for the preview and the
│   │   │                        inspector
│   │   └── DictationWave.qml    the voice, as one curve that glides
│   ├── media/
│   │   ├── MediaController.qml  Super+M's card, floating in the middle:
│   │   │                        keyboard-driven (space, arrows, shift+arrows,
│   │   │                        l lyrics, s shuffle, r repeat, tab the next
│   │   │                        player), pops in and out, or grows out of the
│   │   │                        island's own body when the island opens it; the
│   │   │                        cover on top, lit
│   │   │                        from behind by its own blur, and the lyrics
│   │   │                        widening it to the right when there are any; the
│   │   │                        CheatSheet's kind of object, the power panel's
│   │   │                        kind of guest
│   │   ├── MediaTransport.qml   the ONE set of media buttons: a ring and two glyphs,
│   │   │                        shuffle and repeat at its ends on the card
│   │   ├── Scrubber.qml         the ONE seek bar: a straight run up to the pip, bright while it plays
│   │   │                        and dim when paused, and a quieter run after it
│   │   ├── ArtCrossfade.qml     the cover, sharp or blurred, fading into the next one
│   │   │                        only once the next one has loaded
│   │   ├── LyricsView.qml       the card's right half: the sung line held a third of
│   │   │                        the way down, wheel to read ahead, it comes back
│   │   ├── LyricLine.qml        one line: the lead, its backing vocals smaller
│   │   │                        under it, or three dots that fill through a
│   │   │                        break; the other singer's lines on the right; a
│   │   │                        click seeks to it
│   │   ├── LyricBlock.qml       words laid out into rows by hand (FontMetrics
│   │   │                        measures exactly what StyledText draws), lit word
│   │   │                        by word in reading order, the sung part glowing
│   │   ├── PlayerChips.qml      every player, the shown one by name, the rest by mark
│   │   └── Equalizer.qml        three bars that move while something plays
│   ├── VolumeRail.qml           the volume pill on the right edge; DISABLED
│   │                            2026-10-09 (not mounted in ShellWindow), kept
│   │                            because the QuickControls edge grew out of it
│   ├── quickcontrols/
│   │   └── QuickControls.qml    the right edge's whole answer: one card, three
│   │                            rows - sound, brightness, warmth - each an
│   │                            icon, a slider, a live value. The edge grab
│   │                            rail keeps the volume's drag and wheel, so
│   │                            the old muscle memory still works; the
│   │                            warmth row wears the colour it sets
│   ├── stream/
│   │   ├── StreamPanel.qml      a band across the stream screen's top: a
│   │   │                        portrait screen has height to spare and no
│   │   │                        width to give. Drawn on the chassis rather
│   │   │                        than as a blob - the hole starts late at the
│   │   │                        top the way it starts late beside the sidebar,
│   │   │                        so menus drop out of it. The studio on top,
│   │   │                        each screen's workspaces and windows side by
│   │   │                        side, then a line of status items over their
│   │   │                        menus and the clock
│   │   └── StudioControls.qml   what the viewers get, in reach: going live and
│   │                            ending take a second click inside three
│   │                            seconds; camera, screen and the audio toggles
│   │                            act on the scene on air, and a muted mic or a
│   │                            hidden screen stays red until it is undone
│   ├── launcher/                grows out of the sidebar; the one keyboard grab
│   │   ├── Launcher.qml         which of the two concepts is live; forwards to it
│   │   ├── ListLauncher.qml     a search field that answers what you type;
│   │   │                        empty, it shows up to 12 pinned apps and a
│   │   │                        row of recent ones as icons
│   │   ├── LauncherSearch.qml   what a typed line means: apps, commands,
│   │   │                        settings (toggles flip in place), open
│   │   │                        windows, devices, timers, reminders, the
│   │   │                        time in a city, processes to kill, files and
│   │   │                        words inside them, a typed path, a link, and
│   │   │                        the fallbacks, every app's volume, and system
│   │   │                        switches (night light, dark mode, energy
│   │   │                        saver, airplane mode, sleep displays, quit
│   │   │                        all, dismiss notifications), the focused
│   │   │                        window's moves (halves, thirds, quarters and
│   │   │                        sixths cut from the monitor minus its
│   │   │                        reserved edges and gaps, one formula for
│   │   │                        every grid) and the tiling layouts; an alias lifts
│   │   │                        its row to the
│   │   │                        top. Ranked into sections, and what each row
│   │   │                        does. Apps, commands and settings have ids
│   │   │                        (app:firefox, command:lock) that a hotkey or
│   │   │                        the CLI runs without the launcher open
│   │   ├── shellcli.js          the CLI's own help header (cli/banditshell) read
│   │   │                        as usages, so typing bandit or banditshell in
│   │   │                        the launcher runs any command and completes
│   │   │                        the next word the way the terminal's Tab does
│   │   ├── sources/             one file per newer kind of result, plugged into
│   │   │                        LauncherSearch's `sources` list (section 19).
│   │   │                        NotificationSource.qml is the notification
│   │   │                        history: `notifications`, `unread`, `held`,
│   │   │                        `from <app>` and free text, one row per
│   │   │                        thread, with the card as its Peek
│   │   │                        The shell's own state is five of them: `keys
│   │   │                        <words>` (which chord does it, from the parsed
│   │   │                        binds), `tray` or an app name (Enter opens the
│   │   │                        item's menu), `scratchpad` and `special <name>`,
│   │   │                        `action <words>` (every stable action id) and
│   │   │                        `recent` (recently-used.xbel, secret names hidden).
│   │   │                        Each answers below 0.5 for a plain word and
│   │   │                        has a switch under `launcher.shell`
│   │   ├── search.js            the pure part of it: paths, links, sections,
│   │   │                        reading timer, reminder, volume, zone and
│   │   │                        kill phrases, a time moved between places
│   │   │                        (5pm ldn in sf, which date(1) converts so
│   │   │                        daylight saving is right), aliases, fallbacks
│   │   ├── AlphabetLauncher.qml  text before icons; the alphabet on a rail.
│   │   │                        Folders live in the favourites, a row carries
│   │   │                        its application's notifications, and a swipe
│   │   │                        across one clears them or opens the folder
│   │   ├── AnswerRow.qml        the sum you typed, answered under the field.
│   │   │                        Enter copies it; arrowing hands Return back to
│   │   │                        the list. Both concepts draw the same row
│   │   └── LaunchEdge.qml       the bottom band as the way to pull it out
│   ├── clipboard/               what you copied; the launcher's twin
│   │   ├── ClipboardPanel.qml   two tabs, a list, and `/` for the search that
│   │   │                        is not there until it is asked for; the list and
│   │   │                        the page are two halves of one strip
│   │   ├── ClipRow.qml          one thing copied: its kind, or the picture
│   │   │                        itself, which grows when it is the one you are on
│   │   └── ClipDetail.qml       one thing properly: whole, formatted, coloured.
│   │                            A right arrow or a swipe right away
│   ├── session/SessionMenu.qml  power, on the right edge, summoned by name
│   ├── calculator/              the keypad, out of the sidebar's flank: the power
│   │   └── CalculatorPanel.qml  panel's twin, mirrored. Summoned by name, so it
│   │                            takes the keyboard and the number row drives it.
│   │                            NOT a fifth gauge; a gauge answers a glance
│   ├── lock/                    the lock: one compositor surface per screen, one face.
│   │                            The face owns the whole screen and draws nothing
│   │                            of the shell: the wallpaper blurred under an ink
│   │                            veil, the time, and a field (LockField) of frosted
│   │                            glass: one round dot per character, each from a
│   │                            fixed pool so only the one that changed moves,
│   │                            centred with the caret as one group, with the
│   │                            keyboard layout as a tag at its end (click to
│   │                            switch) and "caps lock is on" under it when it is.
│   │                            Under that, LockInfo, in no box at all (the lock
│   │                            is the whole computer, not a pop-up): now playing
│   │                            dim until hovered, when its progress and controls
│   │                            unfold downward without moving the field (on a
│   │                            short screen the whole stack sits higher, by its
│   │                            unfolded height, so they clear the power row);
│   │                            battery
│   │                            while a laptop is unplugged; and the
│   │                            notifications as LockAlerts:
│   │                            one disc per app, the newest in front
│   │                            on the right with the total on its badge, the next
│   │                            two smaller and fainter behind it to the left,
│   │                            each peeking out by half of its OWN size, all on
│   │                            one baseline so the smaller ones ride lower; not a
│   │                            word of what they say. LockPower: sleep, restart
│   │                            and shut down as island bubbles that rise when
│   │                            the pointer reaches the bottom edge, each firing
│   │                            only after a held press fills its ring, so a
│   │                            guest can leave without a stray click costing
│   │                            the session its unsaved work. No glow anywhere. One family on the whole
│   │                            face, lock.font (Adwaita Sans, the desktop's own
│   │                            UI face): LockClock sets the time in it on its
│   │                            variable weight axis, sized from the screen's
│   │                            SHORTER side, in a row or stacked
│   │                            (lock.clockLayout); a changing digit thins out,
│   │                            swaps and fills back in, and the digits nearest
│   │                            the pointer run heavier. Two states, like an
│   │                            always-on display: awake (Lock.awake) after any
│   │                            key, move or touch, rested after lock.restAfter
│   │                            seconds of nothing, when the weight drops to a
│   │                            hairline and everything dims. It
│   │                            blooms out of the field over the live desktop
│   │                            and folds back into it on the way out, with the
│   │                            wallpaper's lobed reveal; Hyprland's
│   │                            session_lock_xray is on
│   │                            for exactly those two moments, so a dead lock
│   │                            client never shows what is behind it
│   ├── password/PasswordPrompt.qml the keyring's and polkit's password question,
│   │                            drawn as a page of the launcher (2026-10-19):
│   │                            the same chassis blob rising out of the band,
│   │                            the secret where the search row would be, the
│   │                            dictionary page's bold heading below it and its
│   │                            key-cap footer for the answers. The
│   │                            one panel nobody asks for: an application wants
│   │                            a secret and is BLOCKED on the answer, so it
│   │                            draws over everything, a fullscreen window
│   │                            included, a click off it is a NO rather than a
│   │                            dismissal, and every panel that takes the
│   │                            keyboard refuses it on the way in. Enter
│   │                            answers a yes-or-no card the way it answers the
│   │                            password field
│   ├── cheatsheet/              the hotkey sheet, read from the Lua config scrape
│   │   ├── CheatSheet.qml       the card, the two view choices, and the way out
│   │   ├── BindList.qml         every bind there is, grouped by how it is pressed
│   │   ├── Keyboard.qml          the same binds, on the keys your hands know; a row of
│   │   │                        it exists only when something is bound there
│   │   ├── KeyCap.qml           one key: a width in units, a legend, a state
│   │   └── Chord.qml            one chord, spoken in symbols
│   ├── keyboard/                the board for when the machine is folded over
│   │   ├── OnScreenKeyboard.qml the panel, out of the bottom band. THE ONE
│   │   │                        SURFACE THAT MUST NOT TAKE THE KEYBOARD: it
│   │   │                        types through it, so its absence from
│   │   │                        ShellWindow.keyboardFocus is load-bearing, and
│   │   │                        it has no catcher because a tap off it belongs
│   │   │                        to the window underneath
│   │   ├── Layouts.qml          what is on the board, as data. A key carries a
│   │   │                        width in UNITS and never a position
│   │   └── TabletKey.qml        one key. Fires on PRESS, repeats when held, and
│   │                            is a TapHandler rather than a MouseArea so that
│   │                            two thumbs can be down at once
│   ├── wallpaper/               the picker: the bottom edge's SECOND swipe up
│   │   ├── WallpaperWindow.qml  background layer, below every window; a
│   │   │                        WallpaperView, motion only on an empty workspace
│   │   ├── WallpaperPlayback.qml the video and sound kinds of WallpaperSource,
│   │   │                        loaded by URL so a machine without QtMultimedia
│   │   │                        keeps its pictures
│   │   ├── WallpaperPicker.qml  no panel at all, and kept low: the wallpaper
│   │   │                        you are on as a hero 30% of the height, the
│   │   │                        rest cropped to strips either side that never
│   │   │                        overlap, the row held to 80% of the width and
│   │   │                        collapsing smaller toward its ends. Colour
│   │   │                        swatches and a `/` search above it, the name,
│   │   │                        size, kind and the actions below, each on a
│   │   │                        capsule. While it is up the desktop's
│   │   │                        wallpaper covers the windows (WallpaperCover),
│   │   │                        so the pick is seen as it will look;
│   │   │                        everything but the picker is dimmed by a
│   │   │                        third, and the cards and capsules cast
│   │   │                        shadows. A focus ring only after an arrow key
│   │   ├── WallpaperCover.qml   the wallpaper over the windows while the picker
│   │   │                        is up, under the chassis: it blooms in from the
│   │   │                        bottom edge through the reveal blob once the
│   │   │                        picture is ready, and closes the same way
│   │   └── WallpaperView.qml    what the desktop shows on one output: five slots
│   │                            stacked by arrival, each with its own reveal
│   │                            blob, so a new picture sweeps in over one still
│   │                            arriving; the wallpaper window and the picker
│   │                            share it
│   ├── picker/                  screenshot: hover a window or drag a region. A
│   │                            finished picture raises `Screenshots.captured`;
│   │                            `picker taken <path>` does the same for
│   │                            `screenshot full`, which never reaches the shell
│   ├── settings/                the settings panel: a blob that melts out of the
│   │   │                        sidebar's edge like the menus do, ported from the
│   │   │                        settings-demo mockup. Rail, content and pane side
│   │   │                        by side; the pane slides over the content when
│   │   │                        narrow and the rail goes to icons when tiny. It
│   │   │                        has no catcher: the desktop stays usable, the X
│   │   │                        or the corner closes it, and it steps aside while
│   │   │                        another panel or a menu is up on its screen
│   │   ├── SettingsCorner.qml   the bottom-right corner as a way in: hover, press
│   │   ├── catalogue.js         every setting as data: ten categories, their hubs
│   │   │                        (tiles, one suggestion, page rows) and pages of
│   │   │                        grouped rows; search, aliases, formats. No QML
│   │   ├── boards.js            keyboards as KLE data: ansi, iso, split, the VIA
│   │   │                        reader, and which keys a bind lights
│   │   ├── screens.js           screens as rects on the desk: snapping to edges,
│   │   │                        corners and centres, settling a drop against a
│   │   │                        neighbour, nudging, and keeping a resized screen
│   │   │                        centred with what sat beside it
│   │   ├── SettingsState.qml    one value per row key, from config.json, a service
│   │   │                        or the planned store (settings with nothing behind
│   │   │                        them yet, see .scratch/settings-backends), plus
│   │   │                        recent changes with undo, in state/settings.json.
│   │   │                        Screen changes are staged and go out on Apply;
│   │   │                        a new picture asks to be kept, or goes back
│   │   ├── SettingsView.qml     which category or page is up, the hovered row,
│   │   │                        the pinned detail, search, the toast
│   │   ├── SettingsActions.qml  what the buttons do
│   │   ├── SettingsKeys.qml     shell binds and Files keys as rows, and rebinding
│   │   ├── SettingsPanel.qml    the blob, its reveal, the layout modes; the body
│   │   │                        unloads once closed so nothing scans behind it.
│   │   │                        On Screens it widens for the canvas, or, with no
│   │   │                        room, grows tall and folds the canvas into the page
│   │   ├── ScreenCanvas.qml     the screens to drag: guides, nudges, the ghost of
│   │   │                        where a screen is now, Reset and Apply
│   │   ├── SettingsRail.qml     search, categories unrolling their pages, the plate
│   │   ├── SettingsContent.qml  head, hub or sections of rows
│   │   ├── SettingsPane.qml     preview stage, what the hovered row does, or a pin
│   │   ├── SettingsEntry.qml    a row driven by a catalogue row; SettingsRowFrame
│   │   │                        is the row itself, wrapping its control when tight
│   │   ├── widgets/             rows that need more than one control
│   │   ├── pins/                details that take over the pane: network, scan,
│   │   │                        device, key (with a recorder)
│   │   ├── SidebarReplica.qml   the sidebar drawn for the pane at its natural
│   │   │                        height, wearing the sidebar settings (planned ones
│   │   │                        included); a tap names the setting it shows
│   │   └── scenes/              the preview in the pane, one per page. Each loop is
│   │                            one clock over keyframes copied from the mockup's
│   │                            CSS (keyframes.js)
│   ├── notifications/           discrete cards; none of it is part of the blob
│   │   │                        field, and the history is not here: it is a
│   │   │                        launcher mode (NotificationSource)
│   │   ├── NotificationCard.qml the one card, in four densities: alert (the
│   │   │                        island and the corner), page (the launcher's
│   │   │                        Peek, with the reply field), row and line (the
│   │   │                        lock screen)
│   │   ├── NotificationSwipe.qml the gesture under every card: tap, hold to
│   │   │                        pin, flick right to let go, flick left to keep,
│   │   │                        drag up or down to scroll, touchpad scroll
│   │   ├── NotificationMark.qml its picture with the app's mark as a corner
│   │   │                        badge, else the app's mark, else a bell
│   │   ├── NotificationCorner.qml  the opt-in host for placement `corner`: live
│   │   │                        popups at the top right on a plain plate, no
│   │   │                        history and no arms. It also runs the copier
│   │   └── NotificationCopier.qml keeps a copy of a borrowed or temporary
│   │                            picture so history outlives the sender
│   ├── menu/
│   │   ├── Menus.qml            which menu is open, where it sits, when it closes
│   │   ├── MenuPanel.qml        one panel: geometry and contents, NOT a shape
│   │   └── content/             one file per menu, all reading the real machine
│   │       ├── SoundMenu.qml    NetworkMenu.qml   in the bar: the four gauges
│   │       ├── BluetoothMenu.qml BatteryMenu.qml
│   │       ├── CalendarMenu.qml a month; the clock's date is its opener
│       ├── CalculatorMenu.qml the keypad. A menu BODY, so the panel above and
│       │                    a menu are one object; the answer stays on the line
│   │       ├── TrayMenu.qml     one tray item: what it says, and "show it"
│   │       ├── TrayEntries.qml  its own menu, off the bus. CONTAINS ITSELF
│   │       └── UpdateMenu.qml   the update's menu: the one-line summary of
│   │                            what is coming ("5 changes, restart
│   │                            needed, commands changed"), the What's new
│   │                            entries of the change BEFORE it is taken,
│   │                            one button that says Update or Update and
│   │                            restart, Go back to <id> once one is
│   │                            recorded, asked once in its place, and the
│   │                            outcome of the last update, a rollback
│   │                            included. The What's
│   │                            new card is marked seen when dismissed
│   ├── files/                   the file browser, in a window of its own. Four
│   │   │                        panels, one keyboard, one directory (see 17)
│   │   ├── FilesWindow.qml      the body: a real window, kept alive, because
│   │   │                        what is inside it is a shell SESSION
│   │   ├── FilesFace.qml        the layout, and the ONE place a key is routed
│   │   ├── FileGrid.qml         the files, in as many columns as fit
│   │   ├── FileTile.qml         one of them: a target, a picture, a name, and a
│   │   │                        handle to pick it up by
│   │   ├── FileMark.qml         what kind of thing it is, as one glyph in one
│   │   │                        colour - and the hue is COMPUTED from the class's
│   │   │                        share of the wheel, never listed
│   │   ├── PathBar.qml          where you are, every step back, a field to type
│   │   │                        one into, and the `/` search
│   │   ├── Sidebar.qml          places and mounted drives, down the left, each
│   │   │                        drive with a bar for how full it is
│   │   ├── FilesSettings.qml    the browser's OWN settings, inside it, and the
│   │   │                        one place the keymaps are written down
│   │   ├── Setting.qml          one row of that: label, meaning, control
│   │   ├── marks.js             which folder is which: home is a house
│   │   ├── SplitHandle.qml      the line between two panels, and the way to
│   │   │                        move it; a separator that is also a control
│   │   ├── NamePrompt.qml       one line of text, asked for: new, new, rename
│   │   ├── Properties.qml       everything known ABOUT a file, as opposed to
│   │   │                        what is in it
│   │   ├── PreviewPane.qml      the thing itself: picture, sound, or text
│   │   ├── PreviewPlayer.qml    its sound player, loaded by URL (QtMultimedia)
│   │   ├── TerminalPane.qml     the shell along the bottom; its height is in ROWS
│   │   ├── ChordHints.qml       hold a modifier, see what it does
│   │   └── HelpersMissing.qml   the one failure it cannot recover from
│   ├── gallery/                  the component gallery: every component the
│   │   │                         shell means to own, listed, drawn where it
│   │   │                         exists, argued with where it does not. The
│   │   │                         list is ~/material3-components-todo.md;
│   │   │                         the look is this shell's
│   │   ├── Gallery.qml           the face: register, stage, knobs
│   │   ├── Registry.qml          SINGLETON. every component as one entry:
│   │   │                         key, status (planned/draft/done), the
│   │   │                         checklist line it answers to. The source
│   │   │                         of truth; the md mirrors it
│   │   ├── Knobs.qml             the controls a page's demo answers to;
│   │   │                         toggle/choice/value, drawn out of the
│   │   │                         primitives themselves
│   │   └── pages/                one file per component, by name
│   │                             (key "icon-buttons" ->
│   │                             IconButtonsPage.qml); a missing page
│   │                             draws as a placeholder, not an error
│   └── sidebar/
│       ├── Sidebar.qml          layout of what sits in the chassis's left band
│       ├── SidebarClock.qml     stacked HH / mm / date; the date opens the calendar
│       ├── Workspaces.qml       picks which workspace style the sidebar wears
│       ├── WorkspaceModel.qml   the column's layout + motion, shared by all of them
│       ├── WorkspacePlates.qml  style: index tabs, length as state (`plates`/`icons`)
│       ├── WorkspaceMap.qml     style: a bar per window, as long as the window is wide
│       ├── WorkspaceBlocks.qml  style: one square per window, on the pixel grid
│       ├── StatusIcons.qml      the status section, rendered from data
│       ├── StatusIcon.qml       one indicator, service-agnostic
│       ├── UpdateIndicator.qml  the update, ABOVE the clock, and only while
│       │                        there is something to do: red while a push
│       │                        waits on GitHub, blue once downloaded, amber
│       │                        when it failed or cannot fast-forward, the
│       │                        accent while old binds wait. An update state
│       │                        always wins over the binds. Quiet, it is
│       │                        gone and its menu opens from the clock.
│       │                        That is sidebar.update "new", the default;
│       │                        "always" keeps a grey mark a size down
│       │                        instead, "never" hides even the alarms and
│       │                        leaves Settings to carry the update. The
│       │                        placement is the alarm - it
│       │                        stands where the eye already goes, wearing
│       │                        colours no ramp supplies
│       ├── TrayIcons.qml        the tray, at the TOP: what runs without a window
│       ├── TrayIcon.qml         one of them; StatusIcon's drawing, three buttons
│       ├── RailPips.qml         the rail at rest: one mark per workspace, drawn from
│       │                        WorkspaceModel, a bar as long as the windows it holds
│       ├── RailAnomalies.qml    the rail at rest: a status icon only while it is unusual
│       ├── RailGlance.qml       the glance inside the rail: time over a level bar, or wide's digits
│       ├── RestingGlance.qml    the glance outside it: the top pill and the rail tabs, as blobs
│       ├── anomalies.js         which marks are unusual, in what order, and how a gone
│       │                        one is held while it fades (tests/sidebar-anomalies)
│       ├── placement.js         the workspaces centred, lifted off the foot, and whether
│       │                        they fit under the tray at all (tests/sidebar-placement)
│       └── scrolling.js         a wheel turn as a step of volume or brightness
├── scripts/
│   ├── check-modules.js         the module boundary check: reads every module.json,
│   │                            decides who owns each file, and lists what imports,
│   │                            singletons, config keys and IPC targets cross a
│   │                            boundary the manifests do not allow; --matrix and
│   │                            --explain <package> show the edges (node, no
│   │                            dependencies; `banditshell dev modules`)
│   ├── lint-rules.js            the house rules as sixteen checks (L1 to L16: comments,
│   │                            Rectangle radius, motion outside Follow, spring easing,
│   │                            font sizes, colour literals, textGhost text, dashes,
│   │                            JS the engine lacks, qmldir drift, Name.member reads
│   │                            of a member the singleton does not declare, a pill
│   │                            drawn without an object or place role, a Button
│   │                            asking for a retired Material 3 emphasis, a variable
│   │                            font axis that follows an unsnapped value, an optional
│   │                            Qt module imported where a missing one would take the
│   │                            whole shell down, Quickshell's SystemClock), counted
│   │                            per rule and file against rules.baseline.json (node, no
│   │                            dependencies; `banditshell dev lint`)
│   ├── boot-check.js            the pure half of `banditshell dev check boot`: which
│   │                            ipc targets have a no-argument status call, and which
│   │                            log lines are runtime errors (node, no dependencies)
│   ├── boot-check-inner.sh      the other half: runs inside the private headless
│   │                            session beside the shell, makes the calls, writes
│   │                            PASS/FAIL rows to calls.tsv
│   ├── promote-stable.sh        checks that main may become the stable channel (node
│   │                            tests, check-modules, lint-rules, compile check, the
│   │                            boot check when gamescope is there, a
│   │                            what's-new id) on a clean export of it, then PRINTS
│   │                            the git push and git tag commands; pushes only with
│   │                            --push (`banditshell dev promote`)
│   ├── redact-config.js         config.json with every key named like a token, key,
│   │                            secret, password or cookie left out (node, no
│   │                            dependencies; `banditshell doctor --report`)
│   ├── qmldirs.sh               regenerates every */qmldir after a QML file
│   │                            is added, moved or renamed; run it, the LSP
│   │                            reads what it writes
│   ├── testbed.sh               A COMPOSITOR TO TEST IN: headless sway on its
│   │                            own display, so opening a window to check
│   │                            something never lands on the desktop somebody
│   │                            is using. grim shoots that display, wtype types
│   │                            into it, swaymsg moves its pointer
│   ├── zsh-completion.sh        the CLI's tab completion, GENERATED by parsing
│   │                            bin/banditshell's own `--help` block, so there is
│   │                            no second list of verbs to fall out of date
│   ├── bash-completion.sh       the same table for bash
│   ├── completion-rules.sh      the one parser of the help header; both of the above
│   │                            read its table, and `--write` saves it as
│   │                            cli/commands.tsv
│   ├── palette.py               a wallpaper's dominant colours
│   ├── spicy-lyrics.py          reads one track's lyrics out of Spicy Lyrics'
│   │                            cache in Spotify's own profile, by the cache's
│   │                            file name for that key; reads, never writes
│   ├── wallpaper-colours.py     which colour groups each wallpaper falls in:
│   │                            one hue if enough of it is vivid, black or white
│   │                            if it is dark or light; cached by file
│   ├── tablet-state.py          is the hinge folded RIGHT NOW: the one question
│   │                            that needs an ioctl, so it needs a process.
│   │                            Prints `unknown` without the `input` group, and
│   │                            that is the correct failure
│   ├── pen-buttons.py           the stylus buttons: a Remapper that is pure
│   │                            (right click, middle click, erase, nothing),
│   │                            and a loop that serves it from a grabbed pen
│   │                            to a uinput clone. Names itself `idle` and
│   │                            grabs nothing on the defaults
│   ├── pointing-devices.py      the mice and touchpads udev knows, and the
│   │                            size of each pad in millimetres, read from
│   │                            /run/udev/data with no privileges
│   ├── install-package.sh       one package by whichever manager is there:
│   │                            quietly with sudo -n, through pkexec, or typed
│   │                            in a terminal
│   ├── system-upgrade.sh        runs the system update in a pty under setsid,
│   │                            its input a fifo: answers go in as lines, a
│   │                            cancel as Ctrl-C, refused once pacman has
│   │                            started checking or installing. `watch` is
│   │                            the terminal's view: a tail, so closing it
│   │                            stops nothing
│   ├── polkit-takeover.sh       stops the other polkit agents of this user,
│   │                            units by systemctl, the rest by name, and says
│   │                            which, so they can be started again
│   ├── uninstall-app.sh         which package a desktop id came from, and its
│   │                            removal; refuses when apt or rpm would take
│   │                            other packages with it
│   ├── keyring-prompter.py      the keyring's prompter: owns the bus name gcr's
│   │                            GTK dialog would have been activated for, and
│   │                            reimplements gcr's `sx-aes-1` secret exchange
│   │                            (DH over the 1536-bit IKE group, HKDF-SHA256,
│   │                            AES-128-CBC) because gnome-keyring will not take
│   │                            a password as a plain string over the bus.
│   │                            `--selftest` holds a conversation with libgcr
│   │                            itself rather than with a memory of the spec.
│   │                            The shared key goes into HKDF without leading
│   │                            zero bytes, as libgcr writes it; padded, one
│   │                            exchange in 256 failed. A new password comes
│   │                            back with a password strength above zero, or
│   │                            gnome-keyring takes it for a blank one and
│   │                            offers to store everything unencrypted. It
│   │                            quits when the shell's end of its pipe is
│   │                            gone, and never queues for the name, so a
│   │                            helper outliving its shell cannot answer for it.
│   │                            It does not let anyone replace it either, so a
│   │                            late gcr-prompter cannot take a card away
│   │                            On start it writes a user D-Bus service file
│   │                            for both prompter names that runs the waiter,
│   │                            unless someone else's file is already there
│   ├── keyring-waiter.sh        what D-Bus starts when the keyring asks and the
│   │                            shell's prompter is not on the bus: it owns
│   │                            nothing, so the question stays queued for
│   │                            whoever claims the name first. It waits up to
│   │                            15 s while a banditshell instance is under 30 s
│   │                            old, 5 s otherwise, then starts gcr-prompter;
│   │                            gnome-keyring gives up at 25 s. A /bin/sh guard
│   │                            in the service file goes straight to
│   │                            gcr-prompter once this file is gone
│   └── clip-record.sh           one clipboard event, as one line of JSON: the
│                                MIME types, and the bytes when they are not text
├── src/                         the parts that need C (section 1), built by
│   │                            `banditshell dev build` for the same reason
│   │                            the shaders are: QML is loaded from a directory and
│   │                            has nowhere to run a build step
│   ├── bs-pty.c                 forkpty the user's own $SHELL, with the user's
│   │                            own config. QML has no pty, and down a pipe a
│   │                            shell fails isatty(), reads no rc file and has
│   │                            no line editor
│   ├── bs-ls.c                  one directory as JSON. QML has no readdir and no
│   │                            stat, and `ls` is output for a person
│   └── bs-b64.h                 the wire codec's other half
├── bin/
│   ├── banditshell              the CLI, a link to cli/banditshell
│   └── bs-pty, bs-ls            build output; NOT committed, unlike the .qsb
│                                shaders, because they are ELF for one machine
└── docs/
    ├── hyprland-binds.example.lua    the stable API as keybinds: a worked set to copy
    ├── hyprland-binds.example.conf   the same set for the legacy .conf parser, as
    │                                 `banditshell action <id>` lines
    └── whats-new.json                the What's new log, read out by the
                                       shell itself: one entry per push,
                                       newest first, written for the
                                       recipient. The rule for writing it
                                       is docs/agents/whats-new.md
```

Import paths: Quickshell exposes the config root as the module `qs`, so a directory is
`import qs.components`, `import qs.services`, `import qs.modules.sidebar`. There are no
`qmldir` files to maintain; Quickshell generates them.

**Configuration: no magic numbers, anywhere.**

`Config.qml` owns `~/.config/banditshell/config.json`. Edit it and the shell follows live; delete
it and it is rewritten from the defaults. The `defaults` object in that file *is* the schema:
a key not in it is not a setting, and a key in it always resolves, so a half-written config
still boots. `Config.set("sidebar.width", 90)` writes and persists, which is the entire API the
settings panel needs, and now uses: every row in modules/settings/catalogue.js names its key,
and SettingsState writes it through exactly this call.

Sizes are never listed, they are **derived**: each scale is a `base` and a list of multipliers,
so `small / normal / large` are indices into data rather than three hardcoded numbers, and
changing one base rescales everything proportionally.

Colour roles are **ramp indices**, not hex values. A theme supplies an eleven-stop luminance
ramp plus three saturated accents, and never names a widget. So adding a palette means adding
colours, not decisions, and `Config.theme` swaps the whole shell.

`Appearance.qml` is where those meet, and it contains no literals at all. Widgets read only
`Appearance`, never `Config`, `Compositor` or `Themes` directly.

**Geometry the compositor also has an opinion about comes from the compositor.** With
`compositor.follow` on, `Compositor.qml` reads Hyprland's `rounding`, `rounding_power` and
`gaps_out` (or scrapes niri's config) and those win over config.json, so the shell and the
windows can never disagree about how round a corner is. `rounding_power` is a superellipse
exponent and our smoothing is the Figma parameter; they describe the same thing, so one maps to
the other (2 = circular = 0, and an iOS-ish 5 = 0.6). If it can't be read, `available` stays
false and config.json wins, which is the correct failure.

**Depth is material, not decoration. REVISED 2026-08-01.**

The first attempt built depth out of gradients, bevels and engraved two-tone dividers: surfaces
lit from above, channels lit from below, specular hairlines. It read as **cheap**, and the
reason is worth keeping: those are decorations *imitating* a physical material. Imitation is
what looks cheap. A real material does not need to be drawn.

So depth now comes from transparency and layering:

- A panel is a **translucent material the compositor blurs** (`WlrLayershell.namespace` plus a
  `layerrule` in `~/.config/hypr/hyprland/rules.conf`). What you see through it is the actual
  desktop behind it, out of focus. That is depth you cannot fake with a gradient.
- Everything ON a panel is **one colour at three opacities**: the palette's light end at
  primary / secondary / tertiary (`Appearance.veil()`). That is the entire hierarchy, and it is
  why a translucent interface stays coherent over any wallpaper.
- **Fills** for hover and selection are the same light, turned down to 7-18%. A selection is
  never a saturated block: a big coloured shape shouts, and the only thing worth saying is
  "you are here".
- A **separator** is one hairline at a tenth opacity. Space does most of the separating.
- The **accent** is reserved for state that genuinely earns a colour. Colour in the bar should
  mean something is wrong.

The surface tint still has to sit high enough on the ramp that the theme reads through the
translucency; too low and a frosted panel is just grey, which is nobody's palette.

Icons use `Text.CurveRendering`. Native rendering gives them subpixel colour fringes, and
coloured fringes on a monochrome icon is exactly the sort of detail that reads as cheap.
Monocraft still uses `NativeRendering`, because a pixel font wants the pixel grid.

**The layering rule, and the reason the tree looks like this:**

```
modules   ->  can use everything below
services  ->  can use config + components, never modules
components->  can use config, nothing else
config    ->  uses nothing
```

Dependencies only ever point downward. A widget in `modules/` never talks to Hyprland
directly; it reads `services/Hypr.qml`. That keeps the "how do we know this" logic (which IPC
events force a refresh, id arithmetic) in one place, and leaves widgets purely visual.

`services/` is state that outlives any one widget. Mostly that is the outside world, but it
also holds `Shell.qml`, the registry of which windows exist: the things that need it (the IPC
handler, later keybinds) sit outside the window tree entirely, and threading a reference down
to them would couple files with nothing else to say to each other. A service that wants a window
or a screen does not name `Shell`, `Lock` or `Notifications`; it calls the small core
singletons `Panels`, `Focus`, `SessionControl` and `Notify`, which the package that owns the
thing answers (`docs/architecture/modules.md`).

**One surface, one field. REVISED TWICE on 2026-08-01.**

Everything the shell draws is in ONE window per screen, and the chassis (the band around the
screen, the sidebar, and every open panel) is ONE signed distance field, evaluated per pixel by
`components/blob/blob.frag`. See section 10.

The version before this had a window per panel, stacked. It was wrong in three ways that all
came from the same cause. Two translucent panels that abut **double their opacity** wherever
they overlap and show a bright seam. Where they merely touch, each draws its own hairline and
you get two lines along one join. And nothing could round as a single object, because there was
no single contour to round. Cutting one shape makes all three impossible rather than fixed.

- `ShellWindow` - full-screen, ignores others' exclusive zones, on the normal shell layer. Its
  `mask` is the chassis itself: everything except the content area, plus whatever is currently
  summoned. So every edge is a summon zone, the sidebar is reachable, and the region is
  contiguous, which matters because a gap in it would drop the cursor mid-gesture and dismiss
  what it was reaching for.
- `FrameExclusions` - four invisible one-edge surfaces that exist only to reserve space. An
  exclusive zone belongs to a surface anchored to one edge, and ShellWindow is anchored to four,
  so reserving has to be someone else's job (see the section 7 amendment). The left edge
  reserves the band and the sidebar together.

**Status 2026-08-01:** the sidebar is unconditionally visible and reserving space. That
contradicts section 2.1 ("nothing at a glance") on purpose, as scaffolding. Toggling comes
later; when it does, `exclusiveZone` drops to 0 while hidden and the whole thing slides behind
the left edge the way the top notch (now the island) already did at the top.

**Status 2026-09-29: the hiding is here, per screen; the animation is not.** `sidebar.enabled`
is the default every monitor follows and `sidebar.perScreen` holds the ones that disagree,
keyed by output name exactly like `wallpaper.perScreen` (`{ "DP-1": false }`), and
`services/SidebarState.qml` owns the answer. Hidden means FULLY, in the shape this section
promised: the chassis's left edge becomes the band the other three edges wear, the left
reservation (`FrameExclusions`) gives the width back to the windows, the column draws nothing
and takes no presses. `screen sidebar toggle` flips the monitor the keyboard is on, and it is bound
(`SUPER + K`, taking the calculator panel's old seat, which fell back to `SUPER + Z`). Two
things are still honest scaffolding: the change
is instant rather than the promised slide behind the left edge, which is still to come, and an
entry that agrees with the default is deleted rather than kept, so `sidebar.perScreen` stays
what its name says.

**THE RAIL, 2026-10-17: `sidebar.style` is `full` or `rail`.** The launcher and the island now
answer most of what the column used to be asked, so the column is allowed to be quiet. `full` is
the sidebar as it was. `rail` is the default since 2026-10-18 and rests as a thin strip of the band
(`sidebar.railWidth`, which is also what `FrameExclusions` reserves, so windows tile against the
rail and not against the full column): one mark per workspace, and below them a status icon for
whatever is unusual and nothing for what is normal. Unusual is decided in `anomalies.js`: the
microphone live or muted while something records from it, a
screen recording, a VPN, keep-awake, airplane mode (every radio off), quiet or a mode, an update
waiting or stuck. Every mark's tooltip says what it is and then what a press does ("VPN on,
click for settings"). Battery, sound, airplane and update open their sidebar menus, so the rail
grows under them; VPN, a mode and quiet open their Settings page; keep-awake and a screen
recording stop. Pointing at a mark holds the rail at rest so it can be pressed before the rail
grows; after the press the rail stays at rest until the pointer leaves it. The workspace marks
never move for a status mark: they keep their place, leave four status slots under them wherever
the rail is tall enough, and the status marks stay a clear gap below, so they read as their own
group and never as one more workspace. Every mark shows while
the rail has room for it between the workspace marks and its foot; when it runs out, the most
important stay by a fixed rank: the microphone, a screen recording, a low battery that is not
charging, quiet or a mode, a stuck update, then VPN, airplane, keep-awake, and last a charging
battery or an update that is only waiting. Privacy and anything that swallows notifications stay
in view. A `+N` under the marks counts what did not fit and names them on hover, and a mark
that goes leaves by shrinking, not by blinking out.

**THE GLANCE, 2026-10-24: the time and the battery show at rest.** People using the shell said
an empty screen is annoying when all they want is to look up and see what time it is and how much
battery is left, without pointing at anything. A plate the battery filled and digits drawn from
pips both failed: on a 5120 px screen they read as noise in a 32 px strip. What held was the plain
small time with the battery given a shape of its own, a level bar, beside other places that leave
the rail's width behind. Apple's iPhone Duo met the same problem in its side column and answered
it the same way: a small time on top, the battery as a level rather than a battery icon. `sidebar.glance` picks where (Settings, Sidebar, "Time at rest"):

- `rail` (the default): near the rail's foot, the time, and under it the battery as an upright
  level bar with a nub on top and its percent below. The time sits at the height of the open
  sidebar's clock, centre on centre, so it stays put while the rail grows; it only rises when the
  battery would otherwise fall off the foot. The resting clock (`sidebar.clock.style` and `size`)
  and the open one (`wideStyle` and `wideSize`) are chosen apart: stacked or one line, small or
  large. One line turns the time on its side so it reads as 14:32. The defaults are one line small
  at rest and stacked large when open, so the wide column is used for something.
- `rail top`: the same at the rail's head, where the Duo puts it.
- `top`: a pill melts out of the top band at the centre with the time and the battery meter and
  percent. It steps back while the island is out, since the island owns that spot.
- `tabs`: two tabs melt out of the rail near the bottom, one with the time and one with the
  battery. They overlap the windows a little and fold back into the rail as it grows.
- `wide`: the rail widens to 46 px so the hours and minutes fit stacked at the normal size, with
  the battery under them. Windows give up that width.
- `off`: the rail rests as bare marks.

The blobs go through the chassis like every panel, so the joins melt rather than butt. Without a
battery each place shows the time alone. The low-battery anomaly stays only for `top` and `off`,
where the battery can be out of view: the pill steps back for the island, and `off` shows
nothing. The clock style `off` and the sidebar's battery toggle still hide each half, and bare
mode draws no glance outside the rail. `wide` widens the rail but not its workspace marks. This
bends 2.1 for two readings everyone asks for; nothing else joins them at rest.

Pointing at the rail for `anim.dwell` grows it into the full column: the clock, tray, status
icons and mode icon, with the workspaces turning from marks into plates. It is not a new panel.
`Chassis` smooths one number (`railOpen`, through `Follow`) and the cutout's left edge simply
moves, so the growth is the band swelling over the windows, and the content fades in as the
edge passes it. Leaving for `anim.grace` collapses it, and it holds open while a menu opened
from one of its icons is up, so every door the full column has is still there. The windows do
not re-tile: the reservation stays at the rail, and the column only overlaps them while you are
pointing at it. Scrolling the sound icon changes the volume in both styles, and the optional
brightness icon (`sidebar.status.brightness`) does the same for the screen.

**BARE, same day, the rest of the promise.** `edge.bare` is the chrome's master switch: the
chassis draws nothing on any screen (a full-window hole, zero inset, zero radius, no
screen-corner frame, because corner pieces are border by another name), `FrameExclusions`
reserves nothing, and the six always-on edge grabs drop out of the mask. That last part is
functional, not tidy: with the windows flush against the screen edge, a live edge strip would
be invisible pixels stealing clicks from window scrollbars.

**The shell owns the compositor's half too - WITH ONE CAVEAT ABOUT LIFETIMES.** Bare squares
the WINDOWS (`decoration:rounding` to 0, which empirically takes the windowrule-rounded ones
with it - the rule caps against the global, so the global at zero squares everything) and
takes `gaps_out` to zero, in one `hl.config` eval, the dialect the border colours already
speak. The way BACK is `hyprctl reload`, deliberately: the user's lua owns those numbers
(look.lua's gap, theme's bezel, the global-rounding rule), and a reload is the one operation
that returns all of it to the file's truth at once and re-triangulates every open window with
it. Values stashed at bare time would go stale the day the file moved, and a shell that
started bare never saw them at all.

**REVERSED 2026-09-30. The shell owns NONE of the compositor's half.** The reasoning above was
right about the numbers and wrong about who applies them: the user's Hyprland config owns
gaps and rounding outright, and the shell does not write them - not on the toggle, not on
boot, not after a reload. `applyBare` and `reassertBare` are gone from Compositor.qml, and
the CLI's border verb is the chrome half only. The zeros and the reload live in the user's
own Lua bind (Hyprland 0.56's config Lua runs `hl.config` at keypress time as a dynamic call,
and `hl.exec_cmd("hyprctl reload")` takes the way back), which reads the flag out of
config.json and drives the shell's idempotent `screen border on`/`screen border off` beside it - the flag
is the pair's ONE authority and the compositor's numbers only follow, so a drifted pair
converges on the next press instead of flipping over together and staying inverted forever. The cost is said plainly: a machine that reboots bare boots with
look.lua's gaps and rounding and the chrome still down, because the flag was only ever the
chrome's and the numbers were never the shell's to remember. `screen border` still reads the
compositor live, so the two halves can be compared when they disagree.

**BUT THE TOGGLE'S OWN HALF CANNOT RUN IN THE SHELL.** A toggle writes the flag, the write
hot-reloads the shell, and the teardown eats that generation's in-flight eval - measured as
chrome down with the windows still rounded, which is exactly what a bare mode must not be.
So the compositor half of a TOGGLE runs in the CLI wrapper: a plain process after the IPC
call, applying the zeros on the way in and the reload on the way out, where nothing can kill
it. The shell's `applyBare` keeps the moments that are stable: boot (the flag says bare, the
compositor comes up dressed by the file, the shell squares it), parser-known, and the
reload-reassert below.

**PERSISTED, and held rather than set and forgotten.** The flag lives in config.json, so a
machine that reboots bare boots bare; and because a reload at any moment - the user's hand,
HyprConfig's write chain - re-applies the file's values, every reload while bare is answered
with the zeros again, the same contract `pushBorders` runs on. There is no half-applied state
to fall out of: the toggle, the boot and the reload all land in the same place. The pair is
bound (`SUPER + SHIFT + K`; the on-screen keyboard took its `SUPER + SHIFT + Z`). Bare is
persisted like `wallpaper.enabled`: a shell turned
off on purpose is off when it comes back. The lock face draws no chassis, so it looks the same
bare or not; a shell reduced to a wallpaper runner is still the machine looking like itself.

## 9. Driving it from a terminal

`bin/banditshell` wraps a Quickshell `IpcHandler`. It is a symlink to `cli/banditshell`, never a
copy: every start, restart and `doctor` recreates that link inside the checkout, so a merge that
changes the CLI cannot leave Hyprland's binds running an old copy (issue #20). The link in
`~/bin` is made by `doctor` alone, and `doctor` leaves a `~/bin/banditshell` that is a real file
(a wrapper someone wrote) as it is. Nothing used to put `banditshell` on a PATH, so `install.sh`
now links `~/.local/bin/banditshell` to `cli/banditshell` when no other `banditshell` is found,
and `doctor api` says whether the one on the PATH is this checkout.

It exists because **menus open on hover, and hover is impossible to assert**. You cannot script
a cursor into a corner and check what happened, so the gesture and the thing it opens have to
be separable. Every menu is reachable by name, which means a change to a panel can be checked
without reproducing the gesture, and a change to the gesture can be checked against a panel
already known to work.

```
banditshell                        the commands, one line each
banditshell <command> help         one command's page
banditshell panel                  every panel and menu by name
banditshell panel <name> [toggle|open|close|status] [screen]
banditshell panel close            every panel away - the rescue; one `panels closeAll`
                                   call, the old per-panel loop when the shell lacks it
banditshell panel <name> <action>  a panel's own: launcher run <app>; settings
                                   open [page]|page <page>; files open
                                   [dir]; keyboard dock|float|page <layer>;
                                   clipboard list|use|pin|remove <n>|clear;
                                   calculator full|compact|answer <expression>;
                                   launcher open [<query>]; notifications
                                   clear|open|toggle|close
banditshell output [speakers|headphones|toggle|list]|assign speakers|headphones <device>
banditshell screen [brightness [<pct>|+n|-n]|temperature [<kelvin>|off]
                   |border [on|off|toggle]|sidebar [on|off|toggle] [screen|all]
                   |stream on [screen]|stream off]
banditshell wallpaper [on|off|toggle|next|prev|clear [screen|all]
                      |set <file> [screen|all]|list [screen]|palette]
banditshell screenshot save|copy [--freeze]|full [file]
banditshell clock [timer start <duration> [label]|pause|resume|toggle|cancel
                  [handle]]|[alarm add <time> [--days ..] [--label ..] [--run
                  ..|--ask ..]|list|snooze|stop|enable|disable|remove <handle>]
                  |[zone list|find|add|remove <place>]
banditshell notifications [list [unread|held] [<app>]|open [<query>]|act
                          |dismiss [front|all]|reply <text>|snooze [<span>]
                          |mute <app> [hour|day|never]|unmute <app>|clear]
banditshell tablet [on|off|toggle [caller]|lid open|closed|toggle [caller]
                   |probe [lid]|pen [edit|commit|cancel|aspect|centre|follow
                   |area <x> <y> <w> <h>]]
banditshell config get <key>|set <key> <value>|theme [<name>|list]
banditshell start|stop|restart|status|log|doctor [--report|api|binds [rewrite]]
banditshell action <id> [args...]  a stable id, resolved when it runs (see below)
banditshell api [list [pattern]|show <id>|check]   the table of ids
banditshell version                which build is installed
banditshell events [--filter <names>]   one JSON line per event (docs/events.md)
banditshell completions install|print|status|remove [zsh|bash]
banditshell dev try [worktree]|back|worktrees|run|build|shaders|test
                |check [island [dir]|boot [--shots] [dir]]|inspect island [screen]|inspect close
banditshell dev preview lock|settings [WxH] [page]|files [dir]|gallery|menu <key>
banditshell dev menu [current|hover|list]
banditshell dev launcher scrub <fraction>
banditshell dev keyring|polkit [status|demo|close]
```

**The boot check, 2026-10-17.** Two bugs got past the compile check and every node test: a read of
a property that had moved (`Shell.offStageScreen` became `Focus.offStageScreen`), and
`win["notifications"]` after the tray was removed, a TypeError on every `banditshell panel close`.
Both fail only when the shell runs. `banditshell dev check boot [--shots] [dir]` runs it: the real
`shell.qml` of the checkout, in a private headless gamescope with its own D-Bus, fake home and
XDG directories, so nothing reaches the live session. It waits until `qs ipc show` lists
targets, calls the no-argument `status` of every target in `tests/fixtures/ipc-targets.json`
(a new target is covered without editing a list), drives a round of verbs through the
checkout's own CLI, and then fails on any TypeError, ReferenceError, "is not defined",
"Cannot read property", "Failed to load", "Unable to assign" or binding loop in the shell log.
The lines a headless box always prints (no Hyprland signature, pipewire, ext-idle-notify, a
wallpaper file missing under the fake home) are ignored; the classifier is `scripts/boot-check.js`
and has node tests. `--shots` also photographs the shell at rest and with the launcher open.
`banditshell dev promote` runs it as a last check when gamescope is installed.

**REVISED 2026-10-14: the thing first, in groups.** The verb-first grammar of 2026-10-01
fixed the noun-first one's inconsistency, and it paid for that by sorting every feature by
verb class. The wallpaper lived under five top-level verbs (`toggle`, `set`, `status`,
`list`, `dispatch`) plus the panel; `dispatch` had grown to seventeen targets, including the
most everyday things there are, locking and taking a screenshot; and the top level carried
twenty-nine words, thirteen of them for working on the shell rather than using it. To find a
command you first had to know how the shell implemented the thing. Now the grammar names the
THING first and the action after it, and the things come in groups, so `banditshell` alone
prints seventeen commands where there were thirty: seven everyday groups, `config`, the
lifecycle, `completions`, `dev` and `help`. Every one has a page of its own behind
`banditshell <command> help`.

Five rules hold it together, said plainly.

- **Typing less never acts.** A bare group says how it is: `banditshell screen` prints
  brightness, warmth, the border, the sidebar and streamer mode; `banditshell panel media`
  says whether the media panel is open. Only the words that are verbs themselves (`start`,
  `stop`, `restart`) act alone. This is the noun-first grammar's mistake not repeated: its
  bare nouns toggled some things, read others and listed others.
- **The same action words everywhere.** `on|off|toggle` for anything with two states,
  `toggle|open|close|status` for a panel, `list` for anything with many, and a level takes a
  number, `+n` or `-n`.
- **A fraction is a percent.** `screen brightness .5` is 50%, `+.1` is +10, and a bare `+` or
  `-` moves 10.
- **Panel or group.** This is what replaced `dispatch`. If a thing only exists inside a panel
  (the clipboard's history, the keyboard's layers, a settings page, the calculator's answer),
  its actions follow the panel's name: `panel clipboard pin 3`. If it goes on existing when
  the panel closes (the wallpaper, a running timer, the tablet's hinge), it is a group of its
  own. `panel wallpaper` is the picker; `wallpaper` is the picture.
- **Help at every level.** `banditshell <command> help` and `-h` print that command's page,
  and a word a command does not take prints the same page, not the whole list.

**The shell does not own what a standard tool already does.** Volume and mute are wpctl's,
the media keys playerctl's, and locking is logind's (`loginctl lock-session`; the lock screen
answers logind's Lock and sets LockedHint itself). The shell shows all three, in the sound
menu, the media panel and the lock screen, but a second CLI for them was a second thing to
maintain with nothing to add, so `set volume`, `toggle volume mute` and `dispatch lock` are
gone, with the IPC handlers behind them. What stays is what only the shell knows. `output`
switches between "the speakers" and "the headphones", roles set in `audio.speakers` and
`audio.headphones` that wpctl's node ids cannot name. `screen brightness` sets every DDC
display at once through the shell's own queue, and `screen temperature` moves a gamma ramp
the shell holds. Those two are also the shell's words for whatever backend comes next: a
machine that dims some other way gets a new backend under the same command, not a new
command.

**The picker lost its plural** in the verb-first rewrite and keeps it lost. The grammar before
that named the worn picture `wallpaper` and the panel that picks it `wallpapers`, one letter
apart. Now `wallpaper set <path>` wears it and `panel wallpaper toggle` opens the picker for
it. The IPC target stays `wallpapers`; only the words changed.

**Old binds are not dead, and the user is not sent to a manual.** Every shell start,
`services/CliMigration.qml` scans the config files `HyprConfig` read for binds still in an old
form. `services/cli-migration.js` is the ONE authority on old → new, a rule table that the
scanner, the rewriter and the CLI's own fallback all read. Until the user acts, those binds
work: the wrapper rewrites any old form through the map on the way in. A command that moved to
another program is rewritten to that program (`banditshell set volume +` becomes `wpctl
set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+`), and the fallback runs it and says so on stderr. The
sidebar's update icon wears a "published_with_changes" glyph in the accent colour while old
binds exist (any update state wins over it), and its menu offers the one-click rewrite (a dated
`.bak-YYYYMMDD-HHMMSS` beside the file, one per rewrite, never replacing an earlier one);
`banditshell doctor binds` lists them and `banditshell doctor binds rewrite` is the same rewrite.
Refusing is a two-click path - the second asks, because "no" means "I will fix the config by
hand" - and a confirmed refusal is written to `cli.bindsDeclinedGeneration` as the rules
generation it was made against (`CliMigration.generation`, mirrored by `GENERATION` in
`cli-migration.js`, a test holds them equal), so a later regroup asks again; a `true` left in
the old `cli.bindsDeclined` counts as generation 1.

The table maps the verb-first forms only. The noun-first rules were retired with this
revision, because every bind had already been through them and three of their nouns
(`wallpaper`, `tablet`, `clock`) are groups again with a different bare meaning: a noun-first
rule would now rewrite a correct bind into a wrong one. Two more guards keep the rewriter from
inventing commands: it stops at a redirection or a pipe, so `banditshell set border "$x"
>/dev/null` keeps its tail, and a named thing (`border`, `tablet`, `volume`...) never falls
through to `config set`, whatever its value looks like.

**Tab completion is generated, not written.** `scripts/completion-rules.sh` parses the comment
block at the top of `cli/banditshell` (the same block `banditshell help` reads) into a table,
and `scripts/zsh-completion.sh` and `scripts/bash-completion.sh` emit their functions from it,
so there is no second list of commands anywhere and no way for one to drift from the other.
The header's shape is therefore a contract. A section starts with a heading at column 0: the
command, or several separated by `|`, and a one-line summary at column 31. `banditshell help`
prints the headings and nothing else, `banditshell <command> help` prints one section, and
the summary is what completion shows beside the command. Under the heading come the lines:
two spaces, `banditshell`, the words, alternatives separated by `|`, and a description
starting at column 31. A word in `[...]` alone is a placeholder, so an optional literal is
written on a line of its own. The structure is entirely derived; the only hand-written part
is a small table saying what a *value* is, because no amount of parsing prose separates
`panel <panel>` from `config get <key>`.

Matching follows the grammar. Where several rules fit what has been typed, the words they
offer are offered together, so after `panel launcher` the launcher's own `run` sits beside
the `toggle|open|close|status` every panel has. A value is offered only from the most specific
rule, so after `panel settings open` the pages are offered and the screen names are not. And
a command that ends where the typing ends is not also read as a placeholder: `panel close`
is the rescue, not a panel called close, so nothing is offered after it.

The migration map is held to one more rule, learned the hard way during review: **a form that
only read must never be rewritten into one that acts.** `status migration` first mapped to
`doctor`, which repairs `bin/` and repoints `~/bin/banditshell`; a test now walks every
read-only old form and checks where it lands, and `doctor binds` reports while `doctor binds
rewrite` acts, the same split as every bare group.

It also **maintains itself**. The generated function stats its sources on the first Tab of a
shell and rebuilds when any of them is newer, so a command added to the CLI is complete-able
on the next Tab with nothing run and nothing clicked. `banditshell completions install` and
the row on the settings page's Terminal page exist for the first time, and for a machine where
the file cannot be rewritten in place. The same script is a row in `install.sh`'s table, which
is why a fresh install arrives with it already working.

A CLI open is always a **pinned** open. Nobody driving a terminal has a pointer resting on
anything, so an unpinned menu opened from here would be taken away by the grace timer a fifth
of a second after the command printed `open`.

The panels each follow a rule already stated elsewhere rather than inventing one.
`notch` writes the **pin** and nothing else: presence is a derived union (section 15), so a
keybind and a hand land in the same state and leave by the same doors. `notifications` has no
pin any more: its history is the launcher on `notifications `, so `open` and `toggle` open the
launcher there and `close` closes it when it is showing a notification query.
`settings` drives the service rather than any window, because the panel lives in each screen's
shell window and the service says which one shows it; `open` takes an optional page or any
setting's key, and `page` switches it without touching presence, so a keybind can walk the
panel while it stays put. A menu answers to the same words as a built-in panel: `panel calendar
toggle` toggles an ordinary menu registered in the sidebar, and `panel calendar` says whether it
is the open one.
`docs/hyprland-binds.example.lua` is a worked set of Hyprland binds onto all of it, written
against the stable API below; `docs/hyprland-binds.example.conf` is the same set for a Hyprland
still on the legacy parser. Neither is installed by the shell: the Settings action that the
old example promised never existed, and the example no longer says it does.

`wallpaper` is the one group whose whole job is **reading before writing**. Every action on it
is a write to `config.json` that `config set wallpaper.enabled` or `config set
wallpaper.current` could make by hand, so on the face of it the group is redundant; what a key
cannot do is ask for the opposite of a value it has not read, or the next one along a list.
`wallpaper toggle` and `wallpaper next` are those two questions, and the rest are there so the
group answers the whole thing rather than only the halves a hotkey needs. Turning it off is a
**light going out, not a surface going away**: the window stays, the images keep their
sources, `current` keeps its path, so what is left is the black `WallpaperWindow` was already
painting behind the picture and coming back is a fade rather than a decode. The lock screen
follows the same flag, because its ground is made of this same picture and the face lays it on
an ink floor of its own.

`panel wallpaper`, the picker, is a **surface** rather than a setting: everything on it opens
and closes something on the screen and writes nothing, where everything on `wallpaper` writes
something and draws nothing.

### A stable API for binds

The command line was the interface binds were written against, and it was regrouped twice in
thirteen days. Every regroup needed a rule table, an offer in the sidebar and a run-time shim,
and a bind written two generations back had no path at all. So a bind no longer names the
command line. It names an **action id**, and ids are the one thing promised never to change.

`api/actions.tsv` is the contract: `id`, `status`, `since` (the API number it appeared in), the
`argv` the id stands for today, and a description. `*` in an id matches one segment and shows up
as `$1`, `$2` in the argv, so `panel.*.toggle` is every panel at once. An id is never deleted:
a rename adds the new row and turns the old one into `deprecated=<new id>`, a removal turns it
into `removed=<new id>` and keeps it mapping to the closest replacement. `api/released.txt`
lists every id ever shipped and a test fails when the table loses one. The first line, `# api N`,
changes only when the module's own calling convention does.

`banditshell action <id> [args...]` is the one command line that is frozen. It looks the id up
when it runs, so a key pressed after an update resolves against the files that update left on
disk; a deprecated or removed id prints one notice per session and still works. `banditshell api
list|show|check` read the same table, and `check` holds every row against the help header the
completion is generated from. `tests/actions.test.js` also runs every row in a dry mode that
prints the `qs ipc` call instead of making it, and holds that target and function against the
handlers in `modules/Cli.qml`; that is the check that would have caught `panel settings float`,
which no handler answered for two weeks and which is gone now.

`lua/banditshell.lua` is what a Hyprland config requires. The ids are nested names that are
plain functions, so `hl.bind(keys, bs.launcher.toggle)` works as it stands, and a name with
arguments is called once to get the function to bind: `bs.wallpaper.set("/path")`. Pass an
action, never call it: `bs.launcher.toggle()` runs it at load. At press time the module does
one `hl.exec_cmd` and reads no file, because a bind callback has 100 ms before the compositor
gives up on it; everything else, the table and the checkout's path, is read when the config
loads. The command it runs finds the checkout again by itself (the load-time root, then the
pointer file, then the PATH), so a checkout that moved or updated after the config loaded still
answers. A name that does not exist, a removed id, a half id like `bs.panel.clipboard`, or a
missing table never raise: they give a function that does nothing and shows a notice once, and
the module wraps `hl.bind` so even a chain like `bs.volume.up` binds as that function. `bs.bind`
is `hl.bind` that also fills the description from the table, `bs.describe` reads one, and
`services/hyprland-lua.js` reads the same table so the hotkey sheet says "Open or close the
launcher" for a plain `hl.bind(keys, bs.launcher.toggle)`.

`api/shim.lua` is the only file placed in the user's config tree, as `<hypr dir>/banditshell.lua`,
so `require("banditshell")` works. It is frozen: no action, no verb, a format number in its first
line, replaced only by a higher format, and a `banditshell.lua` that is not ours (no such first
line, or a link) is never touched. It finds the checkout through `$BANDITSHELL_DIR`, then the
pointer file `$XDG_STATE_HOME/banditshell/root`, then the two usual homes of a clone, and with
none it returns a hollow object that never raises. A pointer file, because the repo is not always
where the owner keeps it, and a link would dangle after a move and make `require` raise in a
config we do not own. `ensure_lua` writes the pointer and the shim on `start`, `restart`,
`doctor` and a tried worktree (`dev try`, `dev back`), atomically, and never from the last good
copy. `banditshell doctor api` reports it, the table, the user's own binds and the PATH.

The rest of the CLI gives scripts the same footing. Exit codes are written in the header: 0 done,
1 failed, 2 usage, 3 the shell is not running, 4 the shell refused (a handler that answers
`refused:`, `no shell window` or `no such ...` is a 4, and a running shell that did not take the
call is a 4 that says so instead of claiming it is not running). `--json` after a status
command prints an object. `banditshell version` names the newest what's-new id, the commit, the
checkout, the API number and the Quickshell and Hyprland versions. The instance pid is cached in
`$XDG_RUNTIME_DIR/banditshell/pid` and checked with `kill -0`, so a bind no longer pays for
`qs list --all` first.

`cli-migration.js` can rewrite `exec_cmd("banditshell ...")` strings onto ids where exactly one
id fits (`--stable-scan`, `--stable-check`, `--stable-write`). Nothing calls those modes yet; the
write path wants the `Hyprland --verify-config` step `HyprConfig.commit` already has before it
touches a real file.

### One wallpaper per monitor: a default, plus the screens that disagree

`docs/superpowers/specs/2026-08-23-multi-monitor-design.md` put per-screen wallpaper out of
scope and cited `services/Wallpaper.qml`'s own argument for one picture everywhere. That
argument was about a **change** being one event, and it does not survive the question it was
never asked: what a landscape photograph looks like on a monitor stood on its end. It looks
like the middle third of itself. A shell that draws on every output and has exactly one opinion
about what to draw is a shell that is wrong on every output but one.

The shape is **not a path per output**. It is `wallpaper.current`, the one every screen wears,
plus `wallpaper.perScreen`, a map keyed by output name holding only the screens that disagree.
A map with an entry per monitor has to be edited once per monitor every time the picture
changes, so the second screen quietly keeps last month's wallpaper because nothing told it; a
default that screens fall back to keeps "all of them" as one write. It also answers two
different questions with no code: a monitor unplugged and plugged back in **has** an entry and
gets its wallpaper back, and a brand new one has none and joins the rest. `config/Config.qml`
already treats an **empty default object** as user data rather than a schema to merge into, so
the keys are whatever outputs this machine has and no list of them is declared anywhere.

Choosing the same picture everywhere **clears** the map rather than writing the same path N
times, and that is the part worth stating: a map that agreed with the default in every entry
would go on agreeing with the OLD default the moment the default moved. The map holds
disagreements, and there is no such thing as an entry that agrees.

**This shape is the shell's answer to per-monitor settings generally.** The sidebar's hide,
added 2026-09-29, is the second use: `sidebar.enabled` plus `sidebar.perScreen`, same
reasoning, same "an entry that agrees is not kept" rule, owned by `services/SidebarState.qml`. A
third per-monitor setting should start here rather than invent a fourth shape.

Three shell-wide slots stopped being one slot, all of them the same mistake the multi-monitor
spec names six times. **The preview** was the worst: the picker is a per-screen surface, so
scrubbing the strip on the left monitor repainted the right one, which means you were judging a
picture against the wrong screen's windows while a screen you were not looking at flickered.
**The origin** the reveal opens from was shared, on the argument that one normalised point
lands in the same relative place on every screen; that is right for a change that happens
everywhere and exactly backwards for one that happens on a monitor, where the blob is the shell
saying which. Both are maps keyed by screen now, and `WallpaperWindow` listens to a binding on
its **own** output rather than to the service's shell-wide `shown`: that listener could not
survive in either direction, since a change on another monitor would not fire it and merely
looking at another monitor would fire it on every surface at once.

The **palette** stayed single, and deliberately. One per screen is a python and an ffmpeg per
monitor on every change, feeding a switch (`themeFromWallpaper`) that is on purpose not wired
to anything, and then a shell that would have to decide what it means to be dressed in two
photographs. The shell is one shell; it wears the focused screen's.

### The card is the crop

A wallpaper is a file and a screen is a rectangle, and **every question about how the one meets
the other is answered where the picture is drawn**, never in the service. That is what keeps
the model correct for a setup it has never heard of: ten monitors at ten aspect ratios, a
rotation, a phone.

`WallpaperSource` decodes at the surface's own size and covers it, so a rotated output needs no
mention anywhere: it reports the other pair of numbers and everything downstream reads the
pair it is given. It decodes **through the device pixel ratio**, which it was not doing: a
surface's width is in logical pixels, so a 3840-wide panel at scale 2 was decoded at a quarter
of the pixels the compositor then scaled back up, and a HiDPI laptop wore a visibly soft
wallpaper beside a sharp one. `reveal.frag` already corrects for aspect, so the blob is round
on a phone in portrait and on a 32:9 panel alike.

The picker's card was **16:9, written down, "because screens are"**. Screens are not, and the
comment above that line already said what the cost was: a card that is not the shape of the
thing it depicts crops the picture twice. Drawn at the screen's own aspect the card **is** the
preview, because `PreserveAspectCrop` into the card and into the screen are the same operation
at two sizes: what you see in the strip is the crop you are going to get. The card is then
solved from **both** dimensions rather than picked from one (the width a share of the height
wants, capped by the width the room allows), so there is no branch on how big a screen is and
no mention of a phone anywhere. A phone is simply the case where the second term wins.

That change surfaced a **latent PathView bug** that had been reachable and unreached. `slots`
is the strip's capacity, and PathView has two position formulas and picks between them on
`pathItemCount < modelCount`; `place()` solves the first. A folder with fewer wallpapers than
the strip holds puts it in the second, and the strip goes wrong in the way that is hardest to
disbelieve: the caption names the wallpaper you chose, the desktop behind shows the wallpaper
you chose, and the card in the middle wearing the ring is somebody else's. Narrower cards mean
a panel holds more of them, so four wallpapers on a phone asked for seven slots and made an
exotic case ordinary. `slots` is clamped below the count.

None of this was argued from a diagram. It was run: a **headless nested compositor** with four
outputs at 1920x1080, a 1080x1920 made by rotating a panel, a 3840x1080 and a 720x1600, a
throwaway `HOME` because `Config` hardcodes `~/.config/banditshell`, and `grim -o` per output.
Both bugs above came out of the screenshots rather than out of the code.

### A screen is where a verb happens

`wallpaper next`, `prev`, `set` and `clear` take a screen in one argument slot with three
readings: empty means the focused one, exactly as `services/Shell.qml`'s `forScreen("")` argues
for the twenty verbs that go through it; a name means that one, exactly, or an error rather
than a near miss; and `all` means every screen as one decision. `all` is a screen NAME rather
than a flag because Quickshell's IPC hands a function a fixed list of typed arguments and has
no options, so a flag would be a second parameter that is meaningless whenever the first is
set, and two arguments that can contradict each other are two arguments somebody will make
contradict each other.

`wallpaper set <path> [screen]` exists because `config set wallpaper.current` **cannot** be it. That
key is the default and writing it moves every screen that has not been given its own; the
per-screen map is keyed by output name, and `Config.set` refuses a dotted path its defaults do
not name. `clear` is the verb the picker has nowhere sensible to put: the picker gives a
monitor its own wallpaper, and "actually, follow the others" is an undo, which is why the
Screens settings page carries it as the one wallpaper control on a page about monitors. That
page names the file only when the screen owns one, so the text and the button light on the same
condition and there is never a live control whose effect the row has not stated.

In the picker itself the scope is a **pill, not a toggle**, next to the caption: a toggle is a
switch you leave in a position, and this is the scope of the press you are about to make. It
resets when the panel closes, and it is gone rather than disabled on a single screen, where
"this screen" and "all screens" are the same deed.

### The folder predicts, and the prediction is inspectable

Once a wallpaper belongs to a monitor, the collection stops being one list. A folder worth
browsing holds pictures for every screen its owner has ever had, and on any one screen most of
them are wrong: a 32:9 panorama on a monitor stood on its end is the middle fourteenth of
itself. The strip is a row of things you are meant to recognise instantly, and filling it with
pictures that cannot go there is the one thing that makes it slower to use than a folder.

**The shape is measured, never read off the path.** A collection sorted into `32x9/` and `5x8/`
is telling you the answer and is not a source for it: the folder name is a human's filing, one
picture in it is always the one dropped in the wrong place, and a shell that trusted the
directory would hide the file that fits while offering the one that does not. One `ffprobe`
pass over the whole folder yields width over height per file, the same "one process, not one
per file" shape `makePosters` and `findFrozen` already have. ffprobe rather than `identify`
because ffmpeg is already a hard dependency and one tool answers for a jpg and an mp4 in the
same breath.

**A file with no measured shape fits everything**, which is a real answer rather than a missing
one. An SVG has no pixels of its own and rasterises into whatever rectangle it is given; an
audio file has no picture at all. Neither can fail to suit a screen, and anything else that
lands there is a file ffprobe could not open, where offering it is a better failure than
dropping it silently.

**Fit is a ratio through a log, not a difference.** Aspect is multiplicative: 32:9 and 21:9 are
1.2 apart and are obviously different screens, while 9:16 and 5:8 are 0.005 apart and are the
same one. `wallpaper.fit` is therefore a **factor** (1.25: a quarter wider or a quarter
narrower), so too-wide and too-tall are the same distance from home instead of one of them
being dozens of times further out. Nothing anywhere mentions rotation: a screen stood on its
end reports the other pair of numbers, so a 1920x1200 panel at transform 1 measures 0.625,
which is 5:8, which is what the pictures that suit it are. The rule falls out of the
measurement instead of being a case in it.

Two escape hatches, because a prediction that cannot be overridden has to be right every time.
A second **pill** beside the scope one shows the whole folder in a press, and it is named for
the state it is in ("fits this screen") rather than for the press, because that is a fact about
the strip you are looking at. And `show()` turns the filter off by itself when the wallpaper
the screen is already wearing would have been hidden: "start where you already are" outranks
the prediction, or the strip opens on somebody else's picture with no ring anywhere on it,
which reads as the shell having lost the wallpaper visibly on the screen behind it.

**A filter's failure is invisible by construction.** A wallpaper wrongly excluded does not
appear anywhere for you to notice it missing, and the strip looks exactly as correct as it
would if the rule were right. So `banditshell wallpaper list [screen]` prints every wallpaper
with its measured shape and whether the rule kept it, **including the ones it dropped**, which
is the only place the tolerance's consequences are all visible at once.

### A wallpaper is a file, and a path is one of its names

The listing goes **all the way down** and follows symlinks, where it used to stop at
`-maxdepth 1`. A collection that has outgrown one folder has been sorted into subfolders and is
nearly always sorted by shape, which is the one property per-screen wallpapers care about, so a
flat listing skipped precisely the folders that exist. `-L` because the folder is very often a
symlink and so is everything in it: a dotfiles repo checks the pictures in somewhere else and
links them into place, and `find` without it reports nothing at all.

That makes `realpath` on the way out **necessary rather than tidy**. Following symlinks means
one picture can be reached by two names, and this shell compares wallpapers by string
everywhere it matters: the ring on the card you are wearing, the index the picker opens at, the
position `next` steps from. Browse through `~/.config/wallpapers`, set through the dotfiles
path it points at, and every one of those comparisons quietly says no. Found exactly that way,
against a real collection. One name is picked and it is the real one; `-exec ... +` batches, so
it costs one more process for the folder rather than one per file, and the collector drops
repeats because two links to one picture are one wallpaper.

`wallpaper.dir` is also the first setting in this shell that is **a piece of text**. Everything
else on a settings page is a switch, a slider or a list of names, where the whole range is on
the screen; a folder path is unbounded, and the only honest control for one is a place to type.
The settings `path` row is a MenuRow until you press it, so a page does not grow a
permanently open text box for a setting changed twice a year. The keyboard is claimed on the
**edit** rather than on becoming visible, which is what `PasswordField` does and what would
have made the settings panel hold the keyboard for as long as the page was open: a password
field appears in answer to a press and is gone a second later, and this one sits there while
you read everything else.

### The picker stopped talking

A panel whose entire argument is that you recognise a wallpaper faster than you can read its
name had four badges set in capitals (`GIF`, `VIDEO`, `AUDIO`, `SVG · STILL`) and two pills
spelling out `this screen` / `all screens` and `fits this screen` / `all shapes`. Every one of
them is a thing Material Symbols already has a single mark for, and a strip you are flicking
through gives a badge about a tenth of a second, which is a glyph's native speed and well under
a word's. `Pill` grew an `icon`, and a pill with a mark and no words is a **circle**: the radius
was already half the height, so dropping the width to match needs no second rule.

`motion_photos_off` for the frozen SVG is the one worth pointing at. It is the same family as
the mark for a thing that moves, negated, which is exactly what that file is: it asked to move
and cannot. No pair of words in the old set carried that relationship. **FILL is the state
axis** throughout, so "on" is the same mark solid rather than a second glyph to learn, and the
badge uses fill and hue together because a badge is read in the corner of the eye, where a fill
survives and a hue does not.

**`components/AspectMark.qml` is the part that is not an icon at all.** "Fits this screen" is
four words for a fact with no words in it: a picture has a shape, a monitor has a shape, and
the honest way to say whether one suits the other is to draw both. The outline is the screen,
because that is what does not change while you scrub; the solid one is the picture. **Both fit
the same square** rather than sharing a height, or a 32:9 shape comes out eleven times wider
than a portrait one and the mark stops being a mark. The picture is fitted into a box one
stroke smaller on each side, which is not decoration: drawn at the same size, a perfect match
covered the outline exactly and left a single block saying nothing about a screen at all.

### The gap was the shrinkage

`pitch` was `cardWidth + cardGap`, and `cardWidth` is the size the **centre** card is drawn at.
The cards either side are at `nearScale` and the rest at `farScale`, so spacing them a full
unscaled card apart added the shrinkage to the gap: at 0.72 the far cards sat a quarter of a
card apart and the ends of the strip were mostly surface with pictures floating in it. Measured
off the card **as drawn** (`cardWidth * nearScale + cardGap`), the gap between ordinary cards is
the gap that was asked for, and the centre card, which is over one, rides **over** its
neighbours. That overlap is the point rather than a side effect: `cardZ` already lifts the
middle, so the strip reads as a stack with one card pulled out of it, which is what a wallpaper
you are considering is.

### Dismissing is choosing

Closing the picker **keeps** the wallpaper the strip is centred on. It used to put the old one
back, and that was wrong for a reason hiding in plain sight: the picture has already been on
your desktop, full size, behind the panel, since the card reached the middle. That is not a
preview in the usual sense of a small version of something that has not happened; it is the
thing itself, applied. Scrubbing to a wallpaper, judging it against your own windows, deciding
you liked it and dismissing the panel took it away again, and keeping what you were already
looking at required pressing it a second time.

So a tap is a **shortcut for leaving** rather than the only way to decide, and all it adds is a
point for the reveal to open out of. `accept` lost its path parameter with it: every caller
passed the centred card, because a tap on a side card centres it first and Enter has no card at
all. **There is no cancel, including Escape**, because a cancel would have to mean "the last
minute of your desktop was not real", which is the fiction being removed. Scrubbing back is the
undo, and it is the same gesture that got you there.

This made an ordering bug in `setOn` reachable on every single close, where before it needed a
tap. `shownOn` is preview-or-current, so clearing the preview **before** writing the config
hands the surface the old wallpaper for the length of one call: it loads into the back slot,
finds it already decoded, swaps it in, and then the config write swaps the new one in behind
it. Two reveals in opposite directions for one choice. Written first and cleared after, `shown`
never changes value at all, and committing what you were already looking at is correctly not an
event.

An opening that scrubbed nowhere must also not write, or merely **looking** at the picker would
pin a screen off the default it was happily following. `everywhere` is the exception, because
that deed is about the other screens and this one already agreeing says nothing about them.

### A wallpaper is not only a picture

Three kinds of file live behind one surface, and what separates them is only which Qt element
can draw the file, never anything about how it looks. Stills (png, jpg, webp, bmp, avif, and
**SVG**) are an `Image`; motion (gif, apng) is an `AnimatedImage`; video (mp4, webm, mkv, mov)
and the audio-only files that have no picture in them at all are a `MediaPlayer`. All of it is
behind `components/WallpaperSource.qml`, which exposes `path`, `playing` and `ready`, so
`WallpaperWindow`'s two-slot cross-fade knows about none of it: both slots answer the same
question, has this decoded far enough to show, and that question has three spellings and one
meaning.

SVG is a still like any other **once `sourceSize` is set**, and that one line is the whole of
what makes a vector wallpaper worth having. An SVG has no pixels of its own; Qt rasterises it
at whatever size it is told and then scales the result like any bitmap, so an unset
`sourceSize` rasterises at the document's few hundred pixels and a wallpaper-sized blur is what
reaches the screen.

**Motion runs only while the workspace is empty, per monitor.** A video behind a full screen of
windows is a decoder thread and a GPU surface producing frames that are, by definition,
entirely covered, and that is the whole of what makes animated wallpapers a bad idea on a
laptop. `Hypr.occupancy` answers it per monitor, because a window opened on the left screen has
no opinion about the picture on the right one. **Paused, never stopped**: the last frame stays
on screen, so a busy workspace shows a still rather than a hole, and coming back does not
restart the clip. The slot that leaves the front is let go a fade later, so a video that is no
longer on screen stops holding a decoder open.

An audio file shows the black behind the surface and is muted unless `wallpaper.audio` says
otherwise. It is a gimmick, and it costs one line to let it be one.

### A wallpaper arrives; it does not fade in

`components/reveal.frag` is a **mask on the incoming picture**, not a blend of two of them, and
that shape is the whole design. The outgoing wallpaper draws normally underneath and the new
one draws over it with its alpha eaten away outside a growing outline, so what you see through
the hole is simply the layer below: nothing is captured into a texture, nothing is kept live,
and a video underneath goes on playing through the hole because it is still the scene drawing
itself. It is a `layer.effect`, so it never has to know whether it is masking a photograph, an
SVG or a video.

**Not a circle.** A disc growing out of a point is the obvious shape and reads as a mechanism:
it is the one outline with no information in it, so the eye has nothing to follow and what it
sees is a wipe effect rather than an arrival. The radius is modulated by three sines in the
angle instead, at frequencies 3, 5 and 7 with halving amplitudes. Whole numbers keep the shape
closed (the modulation has to come back to itself over a turn or there is a seam down one
side); odd and coprime keeps it from reading as symmetrical; falling amplitudes make it a blob
rather than a flower. The lobes flatten as it grows, which is both what a drop of ink does and
what lets it reach every corner instead of leaving four bays of the old wallpaper in them. A
seed shifts the phases per transition, so no two changes arrive in the same shape.

**It opens from where the choice was made**: the card you pressed, the edge you are stepping
toward with `wallpaper next` or browsing toward in the picker, the middle for a keybind that has no place on the screen. That is
the thing a fade can never have, and it is what makes the change read as caused. swww does this
family of transitions and the shape is borrowed knowingly; what is not borrowed is the origin.

The trap, recorded because it was fallen into: padding the radius by the lobe depth looks
obviously right and is wrong, because the lobes are already zero at the end. It overshot by a
third, so the screen was covered at three quarters of the way through, which under a
front-loaded easing was a quarter of the DURATION.

### The picker's strip is a PathView, and that is three features

**It never ends.** A PathView's items run round the path, so the last wallpaper is followed by
the first and the strip can be thrown one way forever. A list has two ends, and an end is a wall
you hit while your hand is still moving.

**The middle is bigger, continuously.** Scale, opacity and z come off `PathAttribute`s
interpolated along the path, so a card grows every frame of its approach. Done as
`isCurrentItem ? a : b` with a `Behavior`, which is what it was, the size is a reaction running
on its own clock beside the scroll; done along the path it is a property of where the card is.

**It has momentum.** `SnapToItem` does not mean "settle on a card", it means "settle no more
than one card from where you let go", which is a cap on the coast: a throw was worth exactly as
much as a slow push of the same distance. `NoSnap` lifts it, and `StrictlyEnforceRange` is what
was holding a card in the middle all along.

Two more, because the other input devices have no momentum to be given back. A **wheel** says
only "forward" however hard it is spun, so notches arriving faster than a deliberate click are
worth more than one card each, to a cap. A **touchpad stream** has no release event, so the
velocity it ended at is spent over `coastMs` and converted to cards.

And the preview **waits for the strip to stop**. Once it could be thrown, the middle became
somewhere cards travel through, and every card that passed was a full-screen wallpaper being
decoded and put on the desktop.

The delegates carry a `TapHandler` and not a `MouseArea`, and that is not a style preference: a
MouseArea takes an exclusive grab on press, a Flickable knows to steal it back once the press
becomes a drag and **a PathView does not**, so every press that landed on a card was one the
carousel never saw and only the gaps between cards could be dragged.

`hotkeys` is the one target that is not a second way in but the **only** way in. The sheet it
opens recites the user's own config rather than the shell's state, so it is drawn from the
`HyprConfig` scrape of `hyprland.lua` and everything it requires - the config found by asking
the running compositor what it was actually handed, so `-c` overrides and moved
`$XDG_CONFIG_HOME`s are honoured wherever they point - the same scan the keybinds
editor writes through, rescan on every config reload - and not from `hyprctl binds`, which
reports every bind here as dispatcher `__lua` and says nothing this side can read. Opening
the sheet still runs `hyprctl devices -j`, for the keymap the footer names. A `.conf` setup,
or a Lua scrape that finds nothing, falls back to `hyprctl binds -j` on every open, which
is the one source those configs have. There is no gauge, edge or gesture that could
summon it; the keybind is the control, and it has to keep working across a config the shell
never sees. Each row carries the chord beside the Lua that runs under it, not a description:
the code is the one account of a bind that cannot be out of date with the bind. The board can
be given the user's own keyboard too: a VIA definition JSON, copied into the shell's config
and remembered, donates the physical shape - real rows, real widths and heights, the knob,
read as KLE means them: `x` and `y` move the cursor, `w` and `h` size the key. Its legends
come from the template by POSITION: the board says whether it is ISO (a two-row Enter) or
ANSI (a wide home-row Enter under a 1.5u backslash), the numpad is found by where its
columns sit and the arrows by their shape, and keys the template has no opinion about draw
their matrix spots and wait. A keymap saved from VIA (Save + Load, Save) is the exact answer
where position only guesses: its first layer maps each matrix spot to a keycode, which maps to
the keysym a bind names, so the keys the shell binds light on the user's own board; it must
carry the definition's vendorProductId, or it is refused. A woven bind lights the keys its loop variables and top-level
aliases resolve to, and only when its chord names the variable. Keys can also be struck
from the board in the config (`cheatsheet.blocked`, by keysym or matrix spot, each with an
optional why): they draw as an empty outline with the legend struck through, never light,
and say their why when tapped. `status`
therefore prints what the sheet *read* rather than whether it is up, because the failure this
panel actually has is a screen of chords with nothing beside them. Binding it is the one bind
with a trap in it, because `?` is a shifted character and which physical key it is shifted
from is a property of the keyboard LAYOUT: `SHIFT + slash` on US, `SHIFT + plus` on Danish,
and Hyprland says nothing at all about a key name it cannot resolve, it simply never fires.

`status` exists for one failure in particular: the shell deriving its geometry from the
compositor and quietly disagreeing with it. Printing rounding, smoothing, both gaps and the
window border side by side makes that visible instead of subtly wrong.

Three things worth keeping in mind, all learned the hard way:

- **`pkill -f` matches the command line of the shell that runs it.** `pkill -f 'qs -p …'`
  killed its own invoking shell before the rest of the command ran, which silently stopped a
  config reset from happening for several rounds of work. Use `pkill -x qs`.
- **Warping the pointer with `hyprctl dispatch movecursor` does not always deliver motion
  within a surface.** It is fine for entering the shell from elsewhere and useless for testing
  a slide from one icon to the next; `ydotool mousemove` produces real relative motion, and
  that is what exposed the hover race.
- **`hyprctl dispatch` speaks Lua here too, so every dispatcher you type by hand needs the new
  spelling.** The bullet in section 11 is about what the SHELL sends; this is the same fact
  pointed at your own terminal, and it catches every checklist written before 0.56. On this box
  `hyprctl dispatch togglespecialworkspace communication` comes back with `')' expected near
  'communication'` and does nothing at all; the form that works is
  `hyprctl dispatch 'hl.dsp.workspace.toggle_special("communication")'`, which is what
  `Hypr.toggleSpecial` sends and what the user's own SUPER+grave is bound to. Note the name as
  well: bare `togglespecialworkspace` with no argument toggles the unnamed `special` workspace,
  which is empty, so a check written that way would have proved nothing even on a compositor
  that accepted it. `hyprctl binds -j` reporting every bind as dispatcher `__lua` is the tell
  that a machine is in this world.

---

### How an update works

`banditshell update check` fetches and classifies the incoming change from facts: `restart` when
any qmldir changed, a QML file was added or removed, or `shell.qml` changed (a hot reload misses a
new qmldir entry), otherwise `reload`. The whats-new entries may carry an `impact` object that
can add a restart, a commands change, binds and packages; it never removes what the diff found.
`update apply` stages the target with `git archive` into `~/.cache/banditshell/staged`, runs
`scripts/qml-compile-check.sh` on it and builds the helpers there, and refuses when either fails,
so the live checkout is untouched until the new tree is known to load. Only then does it record the
previous HEAD in `~/.local/state/banditshell/update/previous`, set aside the edits the update also
touches (a fixed identity, so a fresh machine can stash), `git merge --ff-only`, copy the helpers,
refresh the completions and restart when the class says so. `launch()` counts a shell as up only
when it answers `shell status` over IPC within `BANDITSHELL_HEALTH_WAIT` seconds (8) and its log
shows no ReferenceError or "Failed to load" for `BANDITSHELL_HEALTH_SCAN` seconds (3); the last
good copy is refreshed after that and not before. A failed check goes back by itself: `git reset
--keep` to the recorded commit, relaunch, `update/result.json` for the next shell to read, and
`update/skip` plus `updates.skip` so the same commit is not offered again; a newer one is.

`BANDITSHELL_DRY=1` makes `stop`, `start`, `restart`, `update apply` and `update rollback` print
what they would do (`dry: ...`) and change nothing. `tests/update-cli.test.js` runs the whole loop
against a throwaway bare origin and clone with a fake `qs` (`tests/fixtures/update/fake-qs`), never
the real checkout or home.

## 10. The metaball chassis

**The shell's body is a field, not a set of shapes.** `components/blob/blob.frag` evaluates a
signed distance function per pixel: the chassis (everything outside the content area) combined
with each open panel using a **smooth minimum** rather than a plain one.

A plain union of two rounded boxes meets at a crease. A smooth union bulges into the join and
fillets it, and the fillet grows and shrinks by itself as the pieces move. That is the whole
difference between a menu that has been parked next to the bar and one that is separating out
of it.

**Three attempts, and why the first two were wrong**, because the wrongness is the useful part:

1. **A window per panel.** Two translucent surfaces that abut double their opacity along the
   join and show a bright seam, and each draws its own hairline so one join gets two lines.
2. **One vector path, panels as separate shapes with hand-placed corner wedges at the joins.**
   The picture was roughly right and it was a hack: the join was two shapes *agreeing* to
   touch. It could not blend, it could not react to the panel moving, and any slip in the
   agreement showed. This is the version that produced "things are not melting together".
3. **One field.** Nothing places a joint, because there is no joint. The melt is a property of
   the field, so it is correct at every frame of an animation for free.

Consequences worth knowing:

- **The sidebar is not an object.** The cutout simply starts further in on the left; whatever is
  left over is the bar. There is no bar-to-band join to get right because there is no join.
- **A panel opens by GROWING its width from nothing.** At small widths it is entirely inside the
  melt distance, so it reads as a bulge swelling out of the body. Sliding a finished panel out
  from behind the bar would not.
- **The input mask stays rectangular.** `Region` takes rectangles, so the mask approximates the
  field with the chassis rects plus the panel rect. caelestia does the same. Input does not need
  to follow a fillet.
- **`blob.frag.qsb` is build output committed next to its source.** Quickshell loads QML from a
  directory and has nowhere to run a build step, so `banditshell dev shaders` is that step. Run it
  after editing any `.frag`.
- **A rebuilt `.qsb` needs the PROCESS restarted, not a QML reload.** Qt caches the compiled
  shader program by URL for the life of the process, so `banditshell dev shaders` followed by the
  usual hot reload leaves the OLD shader running while the new QML properties bind to uniforms
  it does not have. It fails in the worst possible way: the config reloads, the properties
  exist, nothing errors, and nothing on screen changes, so you conclude the shader edit is
  wrong and go and change it again. The tell is a `ShaderEffect: 'x' does not have a matching
  property` warning naming a uniform you deleted. `qs -p . kill && qs -p . -d`. Verify a shader
  change by capturing the screen with the feature on and off and diffing the two, because "I
  can see it" is not reliable at 2px against a busy background; it was another window's border.
- **Qt hands a `QColor` uniform over premultiplied.** Multiplying rgb by alpha again in the
  shader looks like the surface has quietly lost its colour: the tint goes dark and desaturated
  while still obviously being there. Cost an hour; written down so it costs nothing next time.

caelestia's compiled `Caelestia.Blobs` plugin is where the idea came from: SDF panels melting
into a frame. The maths here is our own, a polynomial smooth-min and superellipse corners, and
it lives in a fragment shader, which is the answer to "why not C++": a shader is where
per-pixel maths belongs anyway.

**Still to come:** spring physics, so a panel squashes as it moves and settles. caelestia's
blobs do this; ours gets worked out from the physics, not ported. That is the next step, and
the field is what makes it possible.

### The workspace column: three attempts

Not a field in the end, and the two that were are worth keeping written down.

1. **A chain of beads on a rail**, one bead per workspace, smooth-unioned into the rail, the
   accent washed out of the active one, and a lagging copy melted in so it stretched when it
   moved. Every trick worked exactly as intended and the result looked like a gooey caterpillar.
   The lesson is not about the maths: **the shell's soul is a pixel font and precise geometry,
   and an organic blob is a different soul.** The metaball belongs to the chassis, where the
   thing genuinely is one body separating; a column of discrete states is not that.
2. **One tab on the edge**, crisp, square where it met the screen and rounded on its free end.
   Correct and thin: one small shape in a tall empty bar, which is where "flat and boring"
   came from in the first place.
3. **A stack of plates**, which is what is there now. Every workspace is a plate hinged just
   inside the frame, reaching in as far as it is worth: a short mark when empty, further when it
   holds windows, all the way out for the one you are on. Index tabs and a bar chart of how busy
   the machine is, which turn out to be the same drawing.

**The artwork was never the problem.** `icons` draws each window as its own application icon,
and the pack it draws from is the one the desktop already uses: Papirus, which files **8178**
applications, resolved through Qt's icon theme (`0ad` and `010editor` resolve here and neither is
in `hicolor`, which is how you tell). So the question is never "does a picture of this app
exist", it is **"does the name this window calls itself match the name the pack files it
under"**. A window says `org.telegram.desktop`; the pack has `telegram`. `Apps.iconSourceFor`
takes the id apart for that: whole, lowercased, then the last meaningful segment, dropping
`desktop`/`app`/`gui`/`client`/`bin` off the tail first, or the theme is asked for "desktop" and
cheerfully returns a picture of a computer. The desktop ENTRY is tried before any of that,
because an entry's own `Icon=` is the one authoritative answer and it is how `zen` (the window
class) reaches `zen-browser` (the file), which no string mangling would find. The category glyph
is what is left when all of it misses.

**An icon pack is fifty designers' palettes at once.** The application icons went in, looked
instantly wrong, and the reason is not that they are ugly: a bar full of other people's brand
colours stops reading as one interface. Desaturating them is not the fix either, which was the
next thing tried and is exactly as bad as it sounds: a greyscale photograph of a logo is still a
photograph of a logo.

**The fix was a different SET, not a filter.** `ttf-nerd-fonts-symbols` is several thousand line
glyphs drawn as one family and monochrome by construction, and it knows what Telegram is: there
is an `fa-telegram`, a `linux-mpv`, a `dev-vscode`, a `fa-magnet` for the torrent clients. A font
takes the shell's label colour the way Material Symbols already do, because the colour was never
baked into it. `Apps.brandGlyphs` maps a window class to a codepoint (a Nerd Font addresses
glyphs by codepoint, not by ligature, so `Icon.qml` grew a `glyph` property that skips the
name-verification path), and `sidebar.workspaces.iconMode` picks between:

- `brand` (default): the per-application line glyph. Telegram looks like Telegram AND like it
  belongs in this bar, which is the whole thing the icon theme could not do.
- `colour`: the icon theme's artwork exactly as shipped, brand palette and all.
- `glyph`: the Material Symbol for the freedesktop CATEGORY, which says "a browser" rather than
  "Firefox" and is still the fallback under both of the others, because no set has heard of
  every application.
- `apps.icons` beats all three: `{ "^zen$": "web" }`, regex against the window class. A MAP, not
  a list, because Quickshell's IPC reads a bracketed argument as an argument LIST and splats it,
  so `banditshell config set apps.icons '[...]'` can never arrive as an array. `Config.merge` grew the
  matching rule for both shapes: an empty default array or object is DATA, not a schema, so the
  user's keys survive instead of being walked away.

**A column that is centred cannot change height suddenly.** Switching to a workspace that was
not on the list yet (going to 6 when five are shown) added a slot, and the column is centred in
the bar, so everything above it jumped by half a slot instantly. New slots now start FLAT and
grow, and a slot that stops existing leaves a GHOST that collapses to nothing before it is
dropped, so the height only ever changes at the rate everything else moves. Two things this
needed: the padding has to be deferred with `Qt.callLater` (assigning `live` from inside
`onSlotsChanged` invalidates a binding mid-evaluation, and Qt calls that a loop and abandons it),
and the styles have to render `max(count, live.length)` delegates or the ghost has no plate to
shrink.

**A scratchpad is not a sixth workspace.** The first attempt drew special workspaces as a row of
pills above the numbered run, and it was wrong twice: it took slots in a column that is a list of
places you LIVE, and it pushed that column around every time one came or went. What a special
workspace actually does is lie OVER whatever you are looking at, so that is what it is drawn as
now: a card tucked behind the active plate with a sliver peeking out from under its edge, which
slides over the plate when you pull it open and tucks back when you put it away. The plate's own
marks fade while it is covered, because you cannot see those windows either. Two bugs came out
of building it, both of the same shape (asking the wrong object):

- **`activeId` was the FOCUSED workspace**, and opening a scratchpad focuses it, with a negative
  id. The active plate vanished, because there is no slot minus ninety-eight. The monitor's own
  `activeWorkspace` is the numbered one you are still on, which is the question being asked.
- **`activespecial` contains none of the words the event filter matched on**: not "workspace",
  not "window", not "mon". The shell knew a special workspace existed and never noticed one
  being pulled open. Worse, which one is open is a property of the MONITOR, so refreshing
  workspaces and toplevels left that answer exactly as stale as it was.

**The styles are switchable, and that is deliberate.** `sidebar.workspaces.style` picks between
whole alternatives (`plates`, `icons`, `map`, `blocks`), not combinable settings. They share
`WorkspaceModel.qml`, which owns the layout pass and the smoothing, so only the drawing is
written more than once and a new idea costs one file. `map` is the one that says something the
others cannot: the layout scrolls sideways, so a workspace holding one full-width editor and one
holding four thirds are identical as a stack of glyphs and nothing alike to work in, and drawing
each window as a bar as long as the window is wide puts that difference on screen.

What the plates get that the first two attempts did not:

- **Length is the state, and it is the only indicator.** There is no separate marker sliding
  over the plates: the plate you switch to grows, the one you left shrinks. A sliding tab over
  plates that stayed put meant the growth happened to a hidden element and nothing visibly
  changed at all.
- **The plates hinge INSIDE the frame, not on the screen's edge.** The band is drawn around the
  whole display, so a plate reaching into it makes the frame bulge in one place, which reads as
  a defect rather than as a tab. Hinging at `band` and stopping a band short of the bar's inner
  edge gives the same gap at both ends and, for free, puts a full-length plate exactly under the
  icon column.
- **The icons ride their plate.** They are children of it, centred in it, so a short plate is
  not a plate with its glyphs hanging off the end. That is what lets the lengths differ by a
  lot: with the icons pinned to the bar's centre line instead, no occupied plate could be
  shorter than about 0.72 of the bar, and the whole staircase collapsed into two near-identical
  steps. At full length the plate is centred in the bar anyway, so the workspace you are ON
  keeps the line the clock and the status icons hold, and the others tuck in behind it.
- **Animate the state, never the resolved pixels.** Width and height both resolve through the
  column's live height, which is already being smoothed frame by frame; a `Behavior` on the
  result restarts a 220ms animation on every one of those frames and the plate rubber-bands
  behind its own column. Animating the fraction (`reach`, `tall`) keeps the reflow exponential
  and the state change eased, with neither fighting the other. This was the "janky" version.
- **Depth is thickness and layering.** The plates are one sheet of material; the active one is
  two, with the accent in the upper sheet, and it is pulled further out than the rest. No
  shadow, no bevel, no gradient. Apple's rule for Liquid Glass, and the only depth cue this
  shell allows itself.
- **Colour is three pixels wide.** The plate carries a tint, but the saturated accent appears
  only as a mark hard on the screen's edge, at the one place in the bar it cannot be mistaken
  for decoration. A big coloured shape shouts; an edge does not.
- **Square where it meets the edge.** A rounded corner there curls the plate away and leaves a
  notch of dead space; the chassis's concave flare, which is the right answer at the screen's
  corners, needs more room than a 28px slot has and pinches the plate's own end off. Attached
  means flat against.

---

## 11. What the services taught

Every menu reads the real machine. Quickshell ships bindings for PipeWire,
UPower, NetworkManager, bluez and MPRIS, so almost none of it shells out.

Almost, and the exceptions are worth naming because the sentence used to claim
there were none. Two of them only READ: a pair of NetworkManager properties the
bindings do not carry (where the captive portal lives, and the passphrase behind
the share card) are asked for over `busctl`. The third WRITES, and it is the one
that had to be argued for: an 802.1X sign-in is a settings profile, Quickshell
exposes the type that carries one without exposing any way to build one, and
section 3 requires the feature anyway. So `Network.qml` builds that one profile
with `nmcli`, the way `~/bin/wifi` already did. A binding that does not exist is
not a reason to be missing a login type.

Four rules came out of writing them, and they are worth keeping:

**A service adapts, it does not relay.** The list NetworkManager gives is not the
list a menu wants: NM reports every BSSID, so one mesh appears four times, in
arrival order. `Network.qml` collapses to one entry per SSID and sorts it the way
a person reads: what you are on, then what you have joined, then by signal. Same
for bluez, which reports every passing stranger.

**Sampling is tied to what is on screen.** Wifi scanning, bluetooth discovery,
`/proc` reads and MPRIS position polling all start when the menu opens and stop
when it closes. A shell that scans in the background is a laptop's battery going
somewhere, and bluetooth discovery is visible to other people as well.

**Ask the source what it actually has.** Two bugs came from assuming:

- Material Symbols addresses glyphs by LIGATURE, so a name the font lacks does
  not fail, it renders as its own name in letters. The shell drew "ARGING_70"
  across a menu because `battery_charging_70` is not a symbol. `Icon.qml`
  measures the ligature now and falls back with a warning. The same check found
  the wifi bar glyphs are worse than missing: they exist and draw an outlined
  wedge whose filled bars are invisible at 18px, so every network looked
  identical. `SignalBars.qml` draws the meter instead, which reads faster down a
  column anyway. **The icon set constrains the design; find out what it has
  before deciding what to show.**
- `WifiSecurityType`'s "no security" member is `Open`, not `None`. Comparing
  against a member that does not exist yields `undefined`, every network compared
  unequal, and every one of them got a padlock.
- **A dispatch is fire and forget, so a dispatch that fails is silent.** Hyprland
  0.56 made its config parser Lua and took the dispatch socket with it: a request
  is now a Lua expression, so `workspace 3` comes back as a syntax error and
  `hl.dsp.focus({ workspace = 3 })` is the same instruction spelled the new way.
  Every click in the workspace column had been landing, being sent, and being
  refused for weeks, and nothing in the shell could tell: the clicks worked, the
  hover worked, the plate lit up, and the compositor quietly said no in a log
  nobody was reading. `Hypr.send()` keeps both spellings and probes ONCE at
  startup with `hyprctl dispatch hl.dsp.no_op()`, a dispatcher that exists in
  both worlds and does nothing in either. Not Quickshell's `Hyprland.usingLua`,
  which reports whether IT is speaking Lua and is false on a compositor that
  accepts nothing else. **When an action goes out on a socket that cannot answer,
  something has to go and ask.**
- **A tray icon that re-registers while the shell is starting can name a bus
  connection it has already dropped**, and every shell start logs one
  `quickshell.service.sni.watcher: Ignoring invalid StatusNotifierItem
  registration of :1.NNN/StatusNotifierItem`. It is not this repo's line and
  there is nothing here to fix: Quickshell hosts the watcher, and its
  `RegisterStatusNotifierItem` looks the named service up with `GetNameOwner`
  before accepting it, so a client that reconnects in the same breath as it
  registers is correctly refused under the name that no longer exists. The
  clients here that do it are Telegram and blueman-tray, both of which rebuild
  their D-Bus connection when the watcher reappears, and both of which are in the
  tray a moment later under their new names. **Check
  `RegisteredStatusNotifierItems` before believing an icon is missing:** the
  warning names the registration that failed, not the item that is gone, and on
  this machine the five that should be there are all there.

**A record outlives the thing it describes.** A notification belongs to the
sender, and a sender that quits takes its object with it, so a card bound
straight to the live handle loses its summary, its body and its icon the moment
the app that sent it closes: what is left in the history is a bare bell over an
empty line. `services/NotificationEntry.qml` copies the content at arrival and re-copies
it whenever the live object changes, keeping the handle itself only for talking
back to the sender, so a notification whose sender dies simply stops updating.
**A sender's death is not the shell's amnesia.**

**Still placeholder: nothing.** Every menu in the sidebar is live, and the
notification daemon and the launcher (DESIGN.md sections 4 and 5) are built.

---

## 12. Measured against the standards

A research pass over Apple's HIG, macOS Control Center geometry, WCAG 2.2 and
Material's token set. The numbers below are the ones that changed the code.

**The pixel font was off its own grid, which was the worst finding.** Monocraft
has `unitsPerEm` 1080 with every metric on a 120-unit lattice: one design pixel
is 120 units and the em is exactly **9** of them. Cap height 840 (7px), x-height
600 (5px), advance 720 (6px). 1440 of its 1468 glyphs sit entirely on that grid;
the 28 that do not are `f i k l t` and their accents, which need a half-pixel.

So a pixel font's scale can only be **integer multiples**. 12/16/24 were 1.33x,
1.78x and 2.67x, and 16 was the worst of them: even the character advance came
out fractional at 10.67px, so glyphs did not begin on pixel boundaries.
`NativeRendering` cannot rescue an off-grid size. Now **9 / 18 / 27**, with the
line box at **4/3 the size**, which is the font's own hhea ratio and therefore
lands whole. The font's `lineGap` is off-grid and is ignored.

**Corner smoothing and corner boxiness are different knobs, and I had conflated
them.** Figma-style smoothing extends the transition ALONG the edge; it does not
move the curve closer to the corner vertex at any value. A superellipse does. At
r=15 a circular corner clears the vertex by 6.21px, Hyprland's `rounding_power`
of 4 clears it by 3.38px, and **no smoothing value closes that gap**. The chassis
was visibly rounder than the windows it framed while claiming to be concentric.

The chassis is a field, so it can draw the real thing: `blob.frag` takes the
corner as a **p-norm** rather than a length, which is a superellipse for any
exponent above 2, and takes the exponent straight from the compositor. The
vector primitive still uses the Figma construction, which is fine because menus
and rows do not nest with window corners.

The concentric ARITHMETIC was already right, and matches what SwiftUI's
`ConcentricRectangle` computes: 15 (+2 border) = 17, +10 gap = 27, +10 band = 37.

**Contrast failed only over light wallpapers.** At `surfaceAlpha` 0.72 the
secondary label came out at 3.14:1 against white where WCAG wants 4.5, and the
accent at 2.59:1 where SC 1.4.11 wants 3. Over a dark wallpaper the same tokens
pass at 6.33 and 7.36, which is exactly why it went unnoticed for a day. Now
0.88, which is also Apple's own rule: a thicker material under text.

**The fill ladder had too small a first step.** Apple's entire fill range is
0.070 to 0.145 and Material's state layers are additive, so a 0.07 container plus
an 0.08 hover lands on 0.145, which IS Apple's `systemFill`. Hover at 0.12 was a
1.18:1 step above its own container and barely read.

Numbers that were already right, recorded so they do not get "fixed":

- **Separator 0.1.** macOS `separatorColor` in dark mode is white at 0.098.
- **Menu width 300.** Sequoia's Control Center panel measures 298pt.
- **Padding base 10 (now 6, same lattice).** Sequoia uses a single 10pt constant
  for panel padding, card padding, gutters and group gaps.
- **Fills as one light at several opacities**, rather than as separate colours.
- **The thumbless fill slider**, which is what iOS Control Center uses.
- **`SignalBars`**, and the reason for it. Signal strength is not in the
  freedesktop icon spec at all.
- **The metaball chassis.** Apple shipped `GlassEffectContainer` in 2025 to
  "fluidly morph Liquid Glass shapes into each other". Same construction.

**The spacing ladder rebased onto 4** (2026-09-27, from the research pass in
`docs/research/`): padding is 8 / 12 / 16 / 24 / 32 (`base: 4`, scale `[2,3,4,6,8]`),
with a semantic band per tier - small is icon-to-text and label-to-control, normal
is blocks within a group, `card` (new, 16) is the inside of a boxed thing, large is
component padding pairs, huge is the group-to-group break and the page gutter. The
old 6 and 36 exist on no published ladder (Carbon, Atlassian, Polaris), and 6 was
not a multiple of the industry's 4px base or our own 9px glyph grid. 12 within
groups / 32 between them stays a decisive 1:2.7 under proximity's 1:2 floor.

**Group headers are tracked-caps overlines.** UPPERCASE + one font stem of
letterspacing (2px ≈ 0.11em at the body tier), at the faint tier. The sources allow
exactly two header forms - tracked caps or a full-alpha heading - and GNOME/Fluent
both discourage caps generally; this shell is a terminal's child, so the caps here
are a deliberate idiom choice. The asymmetry under it is the law: the gap above a
group is the page's huge tier, the gap from heading to its first child one small
tier, so a heading always owns what follows. Shared component:
`modules/settings/SettingsGroup.qml` (pages' hand-rolled label+column pairs were
folded into it).

**Tertiary label lifted to the WCAG floor: 0.45.** Apple's NSColor tertiary
(0.247) is for placeholders and empty states; ours was carrying settings' secondary
sentences and group headers at ~3:1. Informative text now sits at 4.5:1 or above;
the quaternary tier (0.16) is ghost text, disabled and decorative only.

**Still owed to this list:** Apple's Liquid Glass guidance says a material
becomes *thicker* as it morphs to a larger size. Our chassis and its menus are
one surface at one alpha, so a menu should be more opaque than the band it grew
out of. The field would need a per-blob colour to do it, and that is the next
cheap large win.

---

## 13. Rounding: one radius, two distances

The word "rounding" was doing three jobs and they disagreed. Settled vocabulary:

| name | what it is |
|---|---|
| `windowRadius` | the compositor's `rounding` plus its `border_size`. The outer edge of a window, and **the only radius in the shell**. |
| `gap` | the compositor's `gaps_out`. |
| `band` | how thick the chassis band is, which is the gap. |

Everything else is an **offset** of that one curve, never a radius of its own:

```
the window          d
the content area    d - gap          the chassis's inner edge
```

**The display's edge is the same construction on a different rectangle.** It reads
like the third line of that table (`d - gap - band`) and it is not one: that is
only the screen's edge where the shell is a band, which is three sides of four.
Down the left the shell is a band PLUS the sidebar, so the content's offset curve
falls `sidebarWidth` inside the display, and a frame drawn on it blacks out the
whole bar. It is measured off the surface instead - inset by `gap + band`, at
`windowRadius`, offset back out by `gap + band` - which is the same line to the
pixel on the three sides that were right.

**"Content radius = window radius + gap" is the trap.** It is true for circles and
false for every other superellipse. At the compositor's `rounding_power` of 4 it
opens a gap 19% wider along the 45 degree diagonal than along the straight edges,
which on screen is a wedge of wallpaper at every corner. The straight edges stay
perfect, which is why it reads as a rounding value being slightly off rather than
as a category error.

An offset curve is at a constant distance; a larger radius is not. In a distance
field the offset is one subtraction, so the shader derives all three boundaries
from the single window curve and the chassis cups a window corner at a constant
distance whatever the exponent is. This is the strongest argument yet for the
chassis being a field rather than a path.

## 14. Where the melt does NOT belong

The chassis field is for things that **grow out of** the shell: a menu from the
sidebar, the notch from the top band, the launcher. It works because there are
two bodies and one of them is leaving the other, so the fillet between them says
"these are connected".

Notification popups were built the same way and it was wrong. Three peers in a
stack, each within melt distance of the next, do not read as three things
connected to the shell. They fuse into one lumpy mass with pinches where the
boundaries should be, and you cannot tell where one notification ends and the
next begins.

**Peers have to be individually legible, and that is worth more than consistency
with a technique.** They are discrete cards now, each with its own background, in
a plain spaced stack, which is what caelestia does and what every other shell
does, for this reason. The island's deck and the optional corner host both draw
them that way, and the corner host sits on a plate of its own that is not part of
the blob field. The history is not drawn in the corner at all: it is rows in the
launcher, so there is no panel for the cards to melt into or out of.

The rule: melt where one thing emerges from another. Never between siblings.

## 15. Drag before click

**The primary gesture is a drag; the click is the fallback.**

A drag is one continuous gesture, it is identical with a finger, a touchpad or a
mouse, and it is *reversible right up until you let go*. A click is none of those
things. So where something can be thrown away, throwing it is the designed path:
a notification is dismissed by dragging it off the edge it arrived from, and it
follows the pointer and fades as it goes, so the gesture says what it will do
before it is finished. Dragging back cancels.

Clicking still dismisses. A mouse user who expects that should not be told they
are holding it wrong.

**And the other direction is the opposite decision, not a second dismissal.** A
notification card is dragged *right*, out through the edge it hangs off, to
throw it away, and *left* to **keep** it. Keeping stops the countdown and lets the
card leave the *screen* while the notification stays in the history, which is the
launcher on `notifications `. A press and hold pins it, because a finger has no
other way of saying "I am reading this": a pinned card survives one dismissal, and
a swipe left again takes the pin back off.

The two gestures differ by direction alone, so the card has to say which one is
happening before you let go: a rightward pull fades the card out, a leftward one
deliberately does *not*. A dismissal that looked identical to a
keep until the instant it committed would be a coin toss with a hand on it.

In the history the pin means nothing, because the history is launcher rows and a
row is let go with its Dismiss action or the card's close mark. A pin was only ever
keeping a notification on screen; honouring one there would answer a deliberate
dismissal by putting the row straight back.

The touch-friendliness that follows is mostly free, and the rest is arithmetic:
targets meet WCAG 2.2 SC 2.5.8's 24px floor, and the drag threshold is 6px rather
than Qt's mouse-tuned 10, because a touchpad flick covers less distance than a
finger and should still commit.

**A two-finger scroll on a touchpad IS a swipe.** Anywhere this shell answers a
drag it answers the same motion made with two fingers, in the same direction,
with the same recognition, the same tracking the whole way through, the same
right to change your mind halfway, and the same commit at the end. Put the
pointer over the calendar, move two fingers sideways, and the month pages. Put it
in the strip along the bottom of the screen, push two fingers up, and the
launcher rises with them exactly as far as they went and comes back down if they
do. A laptop has no touchscreen edge to push and no third hand free to hold a
button while it swipes, so a gesture that exists only for a press is a gesture
that does not exist on the machine this shell is used on most.

**It lives in ONE component, and that is the whole of the decision.**
`components/ScrollGesture.qml` is a non-visual item you feed wheel events to, and
what it reports back is a gesture: `began` is the press, `moved(dx, dy)` is the
delta, `ended` is the release. `Pull` adopts it once, so the settings corner, the
notch and its push-back, both launcher panels,
the wallpaper picker, the cheatsheet, the menus and the clock's summon all answer
two fingers without a line changing at any of those call sites. That is exactly
why it is a component and not a paragraph in this document: the rule is about
everything added LATER as much as about what is here now, and the next thing
built on a pull inherits it before anyone has thought about touchpads at all. A
site with its own hand-rolled drag adopts it in four lines and gets the same
feel, rather than a second opinion about what a swipe is. Written out per site it
would be nine slightly different opinions, and the tenth would forget.

What it hands out is the TOTAL travel since the gesture began, never the
individual steps, because the total is the shape a drag already hands out: every
consumer here computes "where the pointer is now, less where it started" and runs
its slack test, its angle test and its progress against that one number.
Reporting steps would be the same running sum written once per site and rounded
slightly differently at each.

It hands out one thing a drag does not, and only because a stream is the one
place it cannot be recovered afterwards: a SPEED, in pixels per millisecond. A
site that differences the totals it is given gets pixels per event, which is
pixels times whatever rate the device happened to send at, and the sending rate
is the single thing that provably differs between a compressed stream of pointer
moves and a touchpad's own stream. Position is the same question on both inputs;
speed is not, so the primitive answers it once, on the clock, and every consumer
that wants a flick threshold can ask a number that means the same thing from both
hands. The honest state of that today is that the existing sites do NOT agree
with each other and did not before any of this: `flickVelocity` is documented in
pixels per event and read at face value by the calendar and the settings pager,
while the notification card and `pullReversal` are already per millisecond.
Nothing converts silently between them, and the primitive's own field is the one
place a new site can start out right.

**Three facts make it work, and every one of them is easy to get wrong twice.**

*Pixels tell a touchpad from a wheel.* A mouse wheel reports an angle and no
pixels; a touchpad reports both. `pixelDelta.x !== 0 || pixelDelta.y !== 0` is the
entire test, and `VolumeRail` had already written it before the primitive existed.

*Natural scrolling has to be asked two ways.* Qt sets `inverted` when the input
stack has already flipped the axis, which is the direct answer where it is
present and is simply absent on some setups, so the compositor is asked what a
touchpad is set to as well (`Compositor.naturalScrollTouchpad`) and either one
saying yes is enough. After that a single line covers both axes, because natural
scrolling is precisely the statement that the content follows the fingers:
`finger = pixelDelta * (natural ? 1 : -1)`. Get that sign backwards and every
gesture in the shell runs the wrong way round, which is why it was read off
libinput's own header, off Qt's installed Plasma slider for the x axis, and off
this shell's two already-shipped scroll consumers, rather than recalled.

*A scroll stream has no release, so its end has to be inferred.* Fingers that
lift send no farewell, and fingers that merely stop moving send nothing either,
so the only evidence in both cases is silence. The end is therefore a timer
restarted by every event and lapsing at `anim.fast`, which is precisely what
`GlideList`'s coast once did for the identical question, under a floor of
fifty milliseconds that no setting can get below: every duration in this shell is
a tier off `anim.base`, `banditshell config set anim.base 0` is accepted as written, and
a lapse of zero would make every single event its own complete gesture and stop
every touchpad gesture in the shell working with nothing in the logs. A feel
token is allowed to be zero; a gesture timer is not. It also tells the
two silences apart by itself, without asking: fingers that slowed to a stop
before they left have spent their velocity and end a slow gesture, and fingers
that lifted mid-motion leave behind the speed they were making, which is what a
throw is.

The honest cost of that timer is that a scroll-pull cannot be HELD. A finger can
sit at forty percent indefinitely and change its mind a second later; a stream
that goes quiet for `anim.fast`, 150ms at the default scale, is declared over and
committed. The outcome still matches the drag, because a drag released while
stationary has no backward velocity and commits too, but the timing does not. Qt
does deliver a scroll PHASE, and `ScrollEnd` would land the commit at the lift
itself instead of a beat after it; it is deliberately unused, because a stack
that brackets every frame rather than every gesture would fragment a swipe into
one-event gestures too short to be recognised at all, and that is the feature
silently not working rather than working differently. A timeout can only ever
feel slightly late. It is the first thing to revisit when someone can watch real
phases on real hardware.

**And the one thing this must never do is take the mouse wheel.** A notch already
means something nearly everywhere a gesture lives: the right edge is volume, a
`GlideList` scrolls, the settings pager scrolls the page it is over, a slider
steps, a tray icon hands the notch to the application that owns it. Redefining
the wheel as "swipe" would break all of that at once and buy nothing, because a
wheel has one axis and no motion in it to track. So an event carrying no
`pixelDelta` is handed straight back with `accepted` false and falls through to
whoever wanted it, and every site that had a wheel meaning keeps it unchanged:
the touchpad branch is tried first, and a wheel simply arrives where it always
did.

**Priority is stated, not stacked.** The primitive takes its events from a
function the consumer calls, never from a handler of its own, because a handler
would insert itself into the delivery order by GEOMETRY: wheel events go to the
topmost item under the pointer and stop at the first thing that accepts, so an
instance parked beside a list, inside the settings pager or over the volume rail
would win or lose the event depending on where it happened to sit in the tree.
Those sites own their wheel already and only they can say whether a given scroll
is a swipe or is scrolling. This shell has paid once before for input decided by
stacking rather than said out loud, when the volume rail lost its own hover to
its own readout.

Two structural rules follow, and both are load-bearing. **Declaration order is
input order**, so a scrollable declared AFTER a gesture keeps its scrolling and
the gesture answers only the surface the list does not cover, which is what every
pull consumer already asks for its presses. And **a surface lying OVER a gesture
that refuses the drag must refuse the scroll out loud**: a `MouseArea` with no
`onWheel` leaves `accepted` false and the scroll falls through it to whatever is
underneath, so the one surface that ignores a press would be the one surface a
swipe went straight through. The open scratchpad card in `WorkspacePlates` is the
live example, and it accepts the wheel purely to eat it. The inverse is the
quieter trap: a surface that accepts a wheel and then does nothing with it
silently kills the gesture underneath, and nothing reports it.

**Declaration order covers presses better than it covers scrolls, and that gap is
where this rule leaks.** A press lands on exactly one item, so declaring the
gesture FIRST protects every child from it without any child knowing the
arrangement exists. A wheel walks DOWN the stack until something accepts, so the
same arrangement protects only the children that accept wheels, and any child
that takes presses and not wheels hands its scrolls to the gesture underneath.
The two inputs then disagree in the most confusing direction available: the drag
does nothing on that child, and the scroll moves the panel the child is sitting
on. So the second rule above is not only about surfaces that refuse a drag.
**Anything that owns a press over a gesture owns the wheel as well**, to answer
it, to eat it, or to hand it on deliberately, and a surface that owns a whole
drag of its own owns it twice over. The alphabet launcher's alphabet rail was the
live instance and now eats it; `MenuRow` and the launcher's search field are the
remaining ones, named below.

**Adopting it by hand is four lines and four obligations, and the obligations are
the part nobody guesses.** All five sites that own their own drag had to discover
every one of them, so they are written down here once rather than a sixth time.

- **Split the gesture into `begin` / `advance(total)` / `settle` and let both
  inputs run the same three.** The seam falls exactly where the two inputs
  differ, which is only the origin: a press has a place on the surface and has to
  remember it, a stream has motion and nothing to remember. Everything after the
  subtraction is common, and a second copy of it is the copy without the
  corrections in it.
- **A press must conclude a running stream before it touches any state.**
  `scroll.finish()` is the first line of every `onPressed` here. Leave it out and
  the press zeroes state that a live stream is still measuring against, so the
  stream's next event hands a total measured from where the fingers began to a
  gesture that has since started over, and the panel jumps its whole travel in
  one step. Ending it by its own rule also ANSWERS a pull two fingers had
  half-opened, rather than abandoning it halfway with nothing ever saying which
  way it went.
- **The tap stays in `onReleased` and must NEVER move into the shared end.** A
  press that travelled nowhere was a click; a stream that travelled nowhere did
  nothing at all, because there was no press for it to have been instead. This is
  the most dangerous line in the whole adoption: with the tap in the shared
  settle, two fingers brushing the bottom of the screen open the launcher, two
  fingers resting on a notification delete it, and two fingers on a menu row
  activate it. None of that reads as a gesture bug from the outside. The shell
  simply starts doing things by itself.
- **Gate the stream on the press.** `armed: !x.pressed` on the `ScrollGesture`,
  or the same test written into `onWheel`, is what stops two inputs steering one
  gesture from two origins; the press is the more deliberate of them and keeps
  it. A running stream is not refused by that gate and cannot be, because the
  press above has already finished it.

**Where the rule holds today, honestly.**

Free, through `Pull`, with nothing at the call site: the settings corner, the
notch's pull-down and its push-back,
both launcher panels' put-away, the wallpaper picker's put-away, the cheatsheet's
push, the menus' put-back, and the clock's summon of the calendar.

Adopted by hand, because each of these owns its own drag: the bottom edge that
raises the launcher and then the wallpapers (`LaunchEdge`), the notification
card's throw (`NotificationCard`), the calendar's month paging (`CalendarMenu`),
the settings pager's horizontal pages and vertical page scroll together
(`SettingsFace`), and the workspace scrub (`WorkspaceModel`, driving
`WorkspacePlates`).

Deliberately not swipes, and none of these is a gap. A `Slider`'s bead and the
volume rail track an absolute POSITION rather than a motion, so a wheel over them
already steps the value and a touchpad steps it the same way down the same path,
which is the same answer reached without the primitive. The screenshot picker's
region drag is two absolute corners, and a scroll has no position to give it. A
tray icon's wheel belongs to the application behind it under the
StatusNotifierItem protocol and is not ours to reinterpret. The alphabet
launcher's letter rail is the same case as the bead, one level up: it scrubs
the list to the letter UNDER the pointer rather than by a distance, so a stream
that reports motion and never a position has nothing to give it. It swallows the
wheel rather than ignoring it, because the launcher's put-away pull lies under
the whole rail and a two-finger push down the rail is a downward swipe pointed
straight at it. And a `GlideList` scrolling when you scroll it is the correct
answer, not a missing one.

Genuinely uncovered, named rather than smoothed over:

- **A control that takes presses but not wheels leaks its scrolls to the pull
  underneath it.** `MenuRow`'s row-wide click target is the live one: a menu that
  fits its panel leaves the viewport non-interactive, so a leftward two-finger
  scroll begun on a ROW falls through the row and the inert `Flickable` to the
  menu's put-back and pushes the menu away, while a leftward drag on that same
  row does nothing at all, because the row owns the press. The launcher's search
  field and the notch's contents have the same shape. Eating the wheel on the row
  is not the fix and was rejected: the rows are most of what a menu that DOES
  overflow gets scrolled by, so the row would have to know whether the panel
  around it overflows, which is a question it currently has no way to ask.

- **The wallpaper picker's carousel.** Its `WheelHandler` steps one card per
  event off `angleDelta`, which a touchpad reports as well, so a two-finger
  scroll across the strip steps as many cards as it sends events instead of one
  card per swipe. The panel's put-away pull is covered; the strip inside it is
  not.
- **The `map` and `blocks` workspace styles have no scrub at all**, on either
  input. They satisfy the rule only in the sense that there is no drag there for
  a scroll to match, which is not the same as satisfying it.
- **A vertical drag on the calendar grid still does nothing** while a vertical
  scroll now scrolls the menu behind it, which is the one place in the shell
  where the two inputs knowingly disagree. The cause predates all of this
  (`preventStealing` plus a `MouseArea` that cannot hand a grab back) and the fix
  is a press-path change nobody has been able to exercise.
- **None of it has been driven by a real hand.** Two-finger scroll events cannot
  be synthesised here, so every claim above rests on reading the real event
  fields, on the sign derivation, and on the components building and binding
  cleanly in the live shell. The x axis has no previously shipped consumer in
  this codebase: if horizontal gestures run backwards, the single fix is the
  `sign` line in `ScrollGesture.feed()`, and everything downstream follows it.

**One open question, and it needs a hand rather than a file.** The rule was asked
for with the sentence "imagine putting my mouse at the calendar and then i swipe
with two fingers to the right it should then go to the next month". The
calendar's drag has always been direct manipulation: push the strip right and the
earlier month arrives from the left, which is what a sheet of paper does and what
natural scrolling means by "the content follows the fingers". The scroll now does
exactly what the drag does, which is this rule working correctly, and it means
two fingers rightward currently give the PREVIOUS month. Flipping it is two lines
in `CalendarMenu`, the travel term in `advance` and the momentum product in
`settle`, and it would flip BOTH inputs at once, which is the only acceptable way
to do it: the same physical motion meaning opposite things depending on which
device made it is this rule broken at the very first site that adopts it. It was
left alone rather than guessed at.

**A corner is only the cheapest target on the screen if there is a cursor to
throw at it.** Fitts's law is an argument about a pointing device, and a finger
brings none of it: there is no hover, so a corner that answers a cursor resting
in it answers a touch with nothing at all, and the hover swell that says the
corner is a control is invisible until after you have already committed to
pressing it. So every corner has a second way in, and it is the same gesture in
both hands: press in the corner and push away from it, roughly along the
corner's own diagonal, and what lives there comes out with you.

The direction is what makes it unambiguous. The corner offers ninety degrees of
"into the screen" and the diagonal is the middle of them, so a tolerance either
side of it can be generous and still leave the ends of the arc to the gestures
that run ALONG an edge: a pull up the right-hand side is still the volume rail's.
Which way it went is decided ONCE, at the moment the press travels far enough to
be a gesture at all, because a press that set off along an edge and then curved
inward was never a corner pull and must not become one retroactively.

Everything about it is one vector. `dirX`/`dirY` say which way the gesture goes,
the unit direction is that pair over its own length, the angle test is a dot
product against it and the travel is the projection onto it; there is no
per-corner branch anywhere, so a corner nobody has used yet works the day it is
given one (see `~/.claude/rules/math-over-hardcoding.md`).

**And it runs both ways, which is the whole reason it is a vector rather than a
corner.** Putting a panel away is not a second gesture to design: it is this one
pointed the other direction. So the rule for the whole shell is that **everything
goes back into the edge or corner it came out of, by the gesture that brought it
out, reversed.** The settings page pushes back down into its corner, the
launcher back down into the bottom
edge it rose from, a menu back into the sidebar. Nothing has to be learned twice,
and nothing needs a close button drawn on it, which matters because a close
button is exactly the sort of small permanent control this shell is trying not to
have (2.1, nothing at a glance).

It also means the answer to "how do I get rid of this" is always the same answer,
and it is always available: a panel that is on screen is a panel you can push,
whereas a dismiss target has to be found first.

**What the gesture opens decides how it closes.** A hover-opened panel closes
when the pointer leaves, because the pointer leaving is the only thing that could
have meant "done". Applied to a panel that was deliberately swiped open, that
same rule takes it away the instant you reach for anything inside it, and on a
touchscreen there is no pointer to leave in the first place. So a pulled panel is
PINNED: hover no longer has an opinion about it, and it stays until it is pushed
back where it came from.

**Escape is the pin's other door.** A pinned panel has no pointer holding it and
nothing that will take it away on its own, so the push back into its edge is one
way out and the keyboard is the other: **Escape closes whatever is open, however
it was opened.** One sentence covers the launcher, the power panel, the hotkey
sheet, a pinned menu and a pinned notch, and it has
to hold for the routes that have no pointer in them at all, because a keybind
running `banditshell panel notch open` leaves the cursor resting on somebody else's
window.

**Pinned is the whole set, and hover is deliberately not in it.** A panel the
cursor is merely resting in is closed by the cursor leaving; it needs no key, and
giving it one would cost far more than it saves. A layer surface receives no keys
at all unless its window asks the compositor for them, and asking is not free:
while the shell holds the keyboard the window underneath does not, so a shell
that took it every time a pointer crossed a corner would be swallowing somebody's
typing on behalf of a panel they never asked for. A pin is somebody having said
so, and it is the one state that does not expire, which is exactly what makes it
the set worth spending the keyboard on. The grab lasts precisely as long as the
pin, and not one moment longer.

The cost of a grab is that a pinned thing left up while you go back to typing
swallows the keystrokes, and clicking the other window does not win the keyboard
back, because an exclusive layer surface keeps it. For the panels that cover the
work (the launcher, the power panel, the hotkey sheet) that is the point, and they
still grab. For the island it was not: it sits beside
the work, it stays pinned while you go on using the screen, and a pinned island
made the whole screen feel dead until it was put away. So it asks for keys
only once the shell has been clicked (on demand). The price is the case the old
rule existed for: one summoned by a keybind has never been clicked, so Escape does
nothing until it has been touched; the strip, the gesture reversed and the CLI
still close it.

The media card sits between the two. It is summoned by a key and driven by keys
(space, arrows), so it has to win the keyboard at once, but it floats beside
the island rather than covering the work. An exclusive grab is not only about
keys in Hyprland: while any layer surface holds one, every pointer event goes
to that surface, and if none of it is under the pointer the event goes there
anyway. With the card up, the island, a surface of its own, never saw the
pointer again and closed the moment it opened. So the card grabs exclusively
only until its window is active (or 400 ms), then holds the keys on demand.
The card's click-away catcher covers the screen, so with the pointer following
focus the keys stay with the card, and the island, which never asks for keys,
can take the pointer without taking them.

**One surface, one answer.** Qt gives active focus to exactly one item, so two
pinned things can never both be listening, and a panel that hands the focus back
after closing hands it nowhere. The shell's root item is therefore a focus scope
holding the fallback: focus cleared inside a scope lands on the scope, so the
surface answers for whichever panel is not holding it. Escape then takes one
thing per press, in the order the press would have found if the focus had been
where it belonged.

**Do not use `drag.target` on an item whose `x` is bound.** Qt's built-in drag
assigns `x` imperatively, which destroys the binding and then fights whatever
re-establishes it; the card did not move at all. Track the pointer and drive the
offset instead, and keep the anchor in the PARENT's coordinates: `mouse.x` is
relative to the item that is moving, so as the card slides right by d, `mouse.x`
falls by d for the same physical pointer. `item.x + mouse.x` is the invariant.

**And that invariant only holds while the PARENT is still.** `item.x + mouse.x`
compensates for the item moving inside its parent; nothing in it compensates for
the parent moving in the world. So a drag handler must never live inside the
panel it is dragging: the panel is the thing the gesture moves, the handler would
be measuring itself against its own effect, and the delta for a finger that never
went anywhere comes out as whatever the panel did last frame. Declare it as a
sibling wearing the panel's geometry instead. A parent that *scales* is worse
again, because it rescales the child's coordinates as well as shifting them.

This is the same bug as the `drag.target` one seen from the other end, and it is
easy to reintroduce, because putting the handler inside the thing it drags is
what looks tidy.

**A drag's travel must come from the panel's SETTLED size, never its live one.**
If the number the fraction is divided by is a dimension the gesture is itself
collapsing, the scale shrinks as the push proceeds and the panel accelerates away
from the hand: it runs off faster the further you push, which reads as the shell
snatching it. Take the resting height, not the current one.

**The feel is data, not code.** The pull's whole personality lives in a handful
of numbers in Config's control block, read through `Appearance.sizes`:
`pullSlack` is how far a press travels before it is a pull at all, which is how
early the surface starts tracking the hand; `pullAngleCorner` and
`pullAngleEdge` are how far off the gesture's own axis still counts, sized to
the ninety degrees a corner has to spend and the hundred and eighty an edge
does; `pullTravel` is what a full pull is, as a fraction of the surface, so the
same swipe means the same thing on any display; `pullCommit` is how far along a
pull letting go keeps it, so lift-off recoil cannot take back a gesture that
obviously happened; `pullReversal` is how fast the hand must actually be moving
backward at the lift to read as a change of mind rather than as noise; and
`flickVelocity` is how fast a throw has to be to count regardless of distance,
because a flick is intention expressed as speed. Together they say: recognition
early, rejection rare, commitment generous. A gesture is a feel rather than a
rule, but the rules are what create the feel.

## 16. The clipboard records itself, and the reason is TYPES

The clipboard menu was the first panel built on somebody else's data, and it
ended up not being. Worth writing down, because the pull to read an existing
store is strong and the argument against it is not obvious until you look at
what a clipboard actually carries.

A selection is not a value. It is an OFFER, made in several MIME types at once,
and the receiving application picks the one it can use. Drag a song out of a file
manager and the clipboard offers `text/uri-list` **and** `text/plain`; a
screenshot offers `image/png`; a copied paragraph offers four spellings of text.
That type list is the only place in the entire system where the difference
between a file, a picture, a sound and a sentence is written down.

Every clipboard manager throws it away. `clipse` stores four fields, `value` /
`recorded` / `filePath` / `pinned`, and not one of them is a type: a path, a URL
and a paragraph all arrive as `value` and come back indistinguishable. So a menu
built on that store cannot answer "is this audio" except by looking at the text
and guessing from the extension, which is wrong for every file without one and
for every sentence that happens to contain a dot. **The feature that was asked
for was not implementable on the available data**, which is the only good reason
to go one layer down.

So `scripts/clip-record.sh` runs under `wl-paste --watch` and asks
`wl-paste --list-types`, and `services/Clipboard.qml` decides what the answer
means. The split follows section 8's layering exactly one notch further out than
usual: the script answers what only the compositor can answer (the type list,
percent-decoding a URI, `file` on the far end of it, saving bytes that are not
text), and every judgement about that answer is QML. "Audio" is therefore a MIME
test in a service and not a filename test in a shell, and changing what counts as
audio does not involve a shell script.

Four things fell out of owning the recorder that could not have been retrofitted:

- **`CLIPBOARD_STATE=sensitive` is honoured.** wl-clipboard tells a watcher when
  a selection is a password, and the right answer is to record nothing, silently.
  A manager that stored it and a menu that hid it would still have written the
  secret to disk.
- **Deduplication is by content.** A picture is named by the hash of its bytes,
  so the same screenshot copied twice is one file, and re-copying anything moves
  it rather than adding it. A history that grew a duplicate every time you
  re-copied the same command buries everything else within a day.
- **A pin means something.** It survives the cap, it survives `clear`, and
  re-copying the pinned thing does not lose it, because the identity carries
  forward. A promise that a thing stays cannot be conditional on how much has
  been copied since.
- **The offer is not the value.** A browser offers the same selection as markup
  and as text, and one that lists `text/html` first once made the history record
  elements instead of sentences. So the recorder prefers `text/plain` over every
  other `text/*` type, and some sources put markup into the flavors they claim
  are plain, so anything that opens like a document (`<meta http-equiv>`,
  `<!DOCTYPE`, `<html>`) is coerced down to its rendered text before it is
  stored. The type list says what a selection is; only the text says what it
  says.

The existing clipse history is imported once, and the pictures are **copied**
rather than referenced. Referencing them in place was the obvious thing and it is
wrong: it would leave a third of the imported history owned by the tool being
replaced, so `clipse -clean`, whose whole job is reaping exactly those files,
would quietly empty twenty-eight rows of history months later. Importing means
taking a copy, or it is not importing.

The honest cost is a second watcher on the session if the old manager is left
running. That is harmless (both see every selection, neither can disturb the
other's store) and it is why `panel clipboard` reports whether this one is
actually recording: a history that has quietly stopped growing looks exactly like
an afternoon in which nothing was copied, and it is the one failure the panel
itself cannot show.

## 17. The file browser, and the one directory

**Added 2026-08-27.** The first thing in this shell that is an APPLICATION rather
than a surface: its own window, four panels, a focus, a keymap, and a terminal
inside it. Everything else here appears in answer to a gesture and goes away
again; this is a place you sit in for a while.

### The shell owns the directory

The central decision, and everything else follows from it. Clicking a folder does
not set a path and then tell the terminal about it. It types `cd`, and the
browser moves when the pty reports that the shell moved.

So there is exactly one answer to "where am I", and the two halves of the window
cannot drift apart - which is the failure every file-manager-with-a-terminal has:
two ideas of the current directory that agree right up until the moment one of
them is used. It also means `cd` typed by hand, `z`, an alias, a script that
changes directory, and a folder clicked in the grid are all the SAME event as far
as the code is concerned. None of them is a special case, and nothing had to be
taught about zsh's jump plugins for any of them to work.

The handshake at birth goes the other way, once: the first directory report from
a new session moves the SHELL to where the browser is, because at that moment the
browser knows where the user is and the shell has just been started somewhere.
Without it, opening the terminal yanked the grid to wherever the shell landed -
and under an `.zshrc` that attaches to tmux, that is not even the directory the
process was started in, it is wherever that session was last left.

### A real pty, running the user's own shell

QML can run a process and read a file, and that is the whole of its access to a
filesystem: no readdir, no stat, no pty. A shell down a pipe fails `isatty()`, so
it starts non-interactive, reads no rc file, draws no prompt, and has no line
editor - which means no completion, which is most of what a terminal is for.

So there are two small C programs (section 1 said C is for the parts that need
it, and this is what that meant). `src/bs-pty.c` forkpty()s `$SHELL` with the
user's own config and nothing of ours injected into it: their prompt, their
aliases, their plugins, however slow or strange. `src/bs-ls.c` answers one
directory as JSON, because that is the one format QML parses with no parser.

Which is also why the working directory is READ rather than asked for. The usual
route is OSC 7, and the usual way to get OSC 7 is to install a precmd hook -
which is writing into the user's shell after all. `/proc/<pid>/cwd` needs no
cooperation and is right for any shell. Except under tmux, where the process on
our pty is a client holding whatever directory it started in forever, and the
shell that moves lives under a server we are not related to; there the question
goes to the server, addressed by our own slave tty.

### Every key goes somewhere, and only one thing can intercept

Three steps, in order, in one file (`modules/files/FilesFace.qml`):

1. **A bound chord.** Read whatever has focus, and the only thing in the window
   that can take a key away from a panel. Only chords actually in the keymap are
   taken, which is what leaves `Ctrl+C`, `Ctrl+R` and `Ctrl+D` to the shell - the
   defaults are Ctrl with a DIGIT for exactly that reason.
2. **The terminal, if it has focus.** All of it. No exceptions, no "except
   Escape", no "except the arrows". A terminal that swallows three keys for the
   convenience of the window around it is a terminal you cannot trust with the
   fourth.
3. **The grid otherwise**, where there is no shell waiting and vim's vocabulary
   is free to mean what it means.

`Ctrl+J` is the one knowing exception: it is the linefeed character, so a shell
reads it as Return. Intercepting it costs nothing, because Return still submits,
and it is the chord that has to work from inside the terminal - it is how you get
back out.

The keymap is config, which is what lets the modifier be the way in: hold Ctrl
and the chords it starts fade up, read off the SAME map the router uses, so the
overlay cannot describe a binding that does not exist.

### Colour, rationed differently

A file browser has to be colourful - colour is what lets you find the picture
among the forty text files without reading a name - and this shell rations colour
to state that has earned it (section 8). Both are right, and they live together
by putting the colour on the GLYPH and never on the tile: the material stays the
shell's, hover and selection stay the shell's fills, and what is coloured is a
mark the size of a word.

The hues are COMPUTED, not listed. Each class takes the accent's hue turned by
its own share of the wheel, at a saturation well below the accent's, so the set
rotates with the palette and a new class costs one line and no colour picking. A
table of twelve hex values would be twelve decisions that stop agreeing with the
theme the moment the accent moves.

The one exception is the terminal's sixteen colours, which are config and do NOT
come from the ramp - the only place in this shell where that is the right answer.
`git diff` says a removed line is colour 1 and a compiler says an error is colour
1; colour is carrying MEANING there rather than identity, and a green-family ramp
would paint deletions green.

### It has to be usable, which is more than browsable

A file browser that can only look at files is a viewer. The working parts, and
the one decision behind each:

**Selection is a set.** Ctrl-click adds, Shift-click takes a range, a rubber band
from empty space takes what it crosses, and every action - drag, copy, trash -
acts on the whole of it. Two states are drawn rather than one: `picked` is what
an action would act on and `cursored` is where the keyboard is, which stop being
the same fact the moment there is more than one of them. The set is held as
NAMES, not indices, because the listing is retaken after anything that might
have changed it and an index into the previous listing is a different file in the
next one.

**Right click opens components/ActionSheet.qml**, the same sheet the clipboard
and the launcher open on a row - so it arrived knowing how to be arrowed through,
and the actions are handed in as data exactly as they are there.

**Every operation goes through the shell**, which is the whole point of building
this on a terminal: `mkdir`, `mv` and `rm` land in the history where they can be
read, repeated, or undone by hand. A file manager that does something to your
disk and tells you nothing is the thing this is not. Deletion goes to the trash
through `gio`; permanent deletion is a separate verb that asks you to type the
word, because it is the one action here that reading the history cannot reverse.

**The path bar takes a path.** The crumbs stay - they go back several steps in one
press, and they are drop targets - but the strip is a field as well, on Ctrl+L or
a press on the empty part of it. Both, because they answer different questions
and a browser you cannot paste a path into is a browser that will be closed in
favour of the terminal beside it.

**Two views, and a list is a grid with one column.** Icons for a folder of
pictures, a compact list with size and date columns for a folder of two hundred
config files. Worth saying that it is one view rather than two: the rubber
band's arithmetic, the drop hit-test and the keyboard's idea of up and down are
all written against a column count and a cell height, and every one of them keeps
working when the count is one and the cell is a row. The tile is one component
with two layouts for the same reason - two components would be two copies of the
drag, the clicks and the menu, and the copy nobody was looking at would be the
one that stopped matching.

**Colour says what permission is, because nothing else can.** A folder's class is
always "directory", so a folder's class colour is a hue spent saying what the
icon's shape already says. Permission is the thing about a directory that is
invisible and that matters, so that is what the colour carries: unreadable stops
you dead and wears the alarm, world-writable is a thing to be suspicious of,
root-owned means look but do not touch, and not-writable takes a shade and a lock
badge - because "which of these greys means read-only" is not a question anybody
should answer from memory. A file you own and may write is ordinary and keeps its
type colour, which is what makes the marked ones visible at all. The flags come
from the kernel via faccessat rather than from the mode bits, which cannot answer
"may I write this" without knowing your groups.

**Ctrl+= and Ctrl+- scale the grid**, and one number does it: tile and text
together, because a tile is a picture with a name under it and scaling the
picture alone gives you a large icon labelled in fine print. It is written back
to config, so the size you settled on is the size it opens at.

**The sidebar is places and drives**, split the classic way because the split is
right: places are directories you chose to care about, drives are hardware that
happens to be mounted, and they change for completely different reasons. Both are
drop targets, because both are directories.

**A folder's preview is its contents.** Anything else was answering the wrong
question about the one kind of thing the window is mostly full of.

The editing chords live in the GRID's keymap rather than the window's, and that
placement is the whole reason they can exist: Ctrl+C is a shell's interrupt,
Ctrl+X its kill-line and Ctrl+V its literal-next. A window-level bind would take
all three away from the terminal permanently; read only where the grid has focus,
they are only ever seen when no shell is waiting for them.

### Drag before click, again

Section 15's rule, applied to files: the drag is the primary gesture and the
click is what happens when you let go without having moved. A ghost follows the
pointer by exponential smoothing so the thing in your hand has weight, a folder
under it outlines itself rather than filling harder (an outline survives being
covered by the thing you are dropping), and letting go runs a real `mv` through
the shell, where it lands in history and can be read, repeated or reversed by
hand. Dragging out of the window hands the gesture to the compositor as a
`text/uri-list`, after a DWELL rather than instantly: leaving by a pixel on the
way somewhere else is not a request to give the file to another application.

Four things about Qt's pointer handling were learned the hard way here and are
worth not learning twice. A GridView is a Flickable and claims the grab for
scrolling unless a handler is given `grabPermissions` to take it back.
`onCentroidChanged` is not a per-move signal. `centroid.position` is (0, 0) at
activation and garbage after the first move; `pressPosition` plus
`activeTranslation` are the reliable pair. And some pointer moves arrive at
exactly (0, 0), which is why samples that miss the window by a thousand pixels
are discarded as the noise they are.

**The settings are in the window, not in the shell's settings page.** This is an
application; its preferences belong to it, and somebody wondering how to open the
preview looks in the window they are standing in. Everything lands in the same
config.json as the rest of the shell - same storage, reached from where it is
being used.

THE KEYMAPS ARE THE POINT OF IT. Every other row there is a switch that could
have been found by right-clicking, but a chord written down nowhere is a chord
that does not exist: the preview panel was on Ctrl+4 and there was no way at all
to discover that. Both maps are listed in full, sorted by what the action DOES
rather than by which key does it, and every row rebinds by pressing the chord you
would rather have.

Which turned up a real bug in the shell's config, not in the browser: `merge`
walks the DEFAULTS' keys, so removing a binding was impossible - rebinding "back"
wrote a map without Alt+Left in it, the merge found Alt+Left in the defaults and
put it straight back, and the setting saved correctly and did nothing. Config now
has a short list of paths whose keys are the user's DATA rather than a schema,
and takes those whole. It is the same rule the file already had for empty default
objects, extended to the ones that ship populated.

**Markdown reads both ways.** It is written to be read as text and as a
document, and which one you want depends on whether you are reading it or
editing it - a question the panel cannot answer, so it asks, with a toggle that
appears only on markdown. Qt renders it natively, so the rendered half is a text
item with a format set rather than a parser. It is the one place in the shell
that departs from StyledText on purpose: StyledText pins a line box to the pixel
font's grid, which is right for interface text and wrong for a document that sets
its own heading sizes. The three-size rule is about the interface; this is
content.

### The shell is a shell, not a socket

Three things follow from the terminal being somebody's real shell rather than a
command channel, and all three were wrong until they were used.

**Its environment must not be this window's.** The shell drawing the browser was
itself started from a terminal, and on this machine that terminal was inside
tmux - so TMUX and TERM_PROGRAM were inherited straight through, and an .zshrc
whose auto-start reads `[[ -z "$TMUX" ]]` correctly did nothing. The config was
being read perfectly and then declining to do the thing it was being judged on. A
new terminal window inherits none of that, so neither does this one.

**A line may already have something on it.** Typing a command and then clicking a
folder produced `swswcd 'folder'`: the browser was appending to a line it could
not see. zsh's PUSH-LINE is the right primitive - it sets the half-typed line
aside and gives it back on the prompt after ours has run - so navigating in the
middle of composing a command now costs nothing at all.

**And something may be RUNNING in it.** `mv` at a prompt uses the shell; `mv`
into an open vim corrupts a file, and from outside the two are
indistinguishable unless somebody asks. The helper reports whether the foreground
process is the shell itself (under tmux, whether the pane's command is), and
while it is busy commands run beside the session rather than through it.

Navigation is OPTIMISTIC, and that is the difference between the window feeling
instant and feeling like a remote control. Typing `cd`, waiting for the shell to
run it, waiting for the next poll to notice and only then listing is up to a
third of a second of nothing after a double click. The grid moves now and the
shell catches up behind it; the stale report that follows is recognised and
ignored, and a `cd` that failed expires and hands authority back to the shell,
which is where it belongs.

### Three ways to lose the keyboard

All found by pressing keys rather than by reading code, and all the same shape:
something that looks focused is not.

A **Loader** is an item in the focus chain. The face asks for focus; a Loader
that has none has none to give, so not one keystroke reached the window while
every mouse gesture worked perfectly. It never showed in testing because the
preview harness has the face as a direct child, so the one arrangement exercised
was the one arrangement not shipped.

**An invisible item cannot take focus.** The rename prompt appeared, correctly
filled, and swallowed nothing: `visible` was bound to an opacity that a Behavior
starts at zero, so at the instant `forceActiveFocus()` ran the item was not yet
visible. Everything typed went to the grid behind it.

**A field that lets go does not hand focus back** - it goes nowhere, and the
window stops answering keys entirely. Search once and the grid was dead until
something was clicked, which reads as "Enter does not open folders" and sends you
looking in the wrong place.

---

## 18. The island

**Added 2026-10-14.** The top notch used to be a summon zone for the clock and a
small player. It is now the island: the one place where anything that pops up
arrives. An app opening, dictation, a finished download, a BanditShell update, a
new kernel, and notifications if you want them there.

The reason is the monitor. On a 32:9 screen the top-right corner is a head-turn
away from where I work, so notifications went by unseen. The top centre is where
the eye already is.

### A floating pill, never a notch

The first version melted out of the band like the notch it replaced and stacked
cards inside it. It read as a notch with things in it, and that is what it was.
The island is its own object: the theme's surface colour, the one the panels
wear, opaque, floating a gap below the band with a soft shadow and the chassis'
sheen along its edge. It is not part of the chassis field, so it never bridges
into the band. It was the darkest stop of the ramp until 2026-10-18, and against
a coloured theme that read as a black hole cut out of the screen rather than a
thing of ours; `colour.island` names the surface it wears now.

It has three sizes and no others. Compact is a capsule as tall as a button.
Large is one width, `island.width`, for a notification or for the overview. A
dot is where it goes when there is nothing to say: it shrinks toward a circle
and fades, and grows back out of one. The shape morphs between sizes on its own
Follows while the content of each size cross-fades, leaving faster than it
arrives, so two layouts are never fully visible at once. Content is laid out at
its final size and the shader cuts it to the shape, which is why the edges of a
growing island reveal text rather than squeeze it.

Compact ends are true round ends (power 2, as the round buttons are) and ease
into the shell's own corner power as the shape grows tall, so a capsule reads as
a capsule and a large card reads as one of ours.

### It drips out of the band

Floating free from the first frame read as something that arrived from nowhere.
So the island is born in the band: it swells out of it as a bulge, drops on one
Follow while a second, slower one shortens the reach of the smooth union between
the two, and the neck stretches nearly to the resting place before it snaps. On
the way back the reach grows fast and the pill sinks into the band and is
absorbed. The neck shades from the band's colour to the island's own, and the
shadow only arrives once it floats, because a drop still attached to the band
casts nothing.

### One anatomy

Every activity is a mark, words and a sign: Firefox's icon, "Firefox" and a ring
that fills, then a check; a microphone, the live bars and the language; a cover,
the title and an equalizer; a running timer, its name, the time left and a pause
sign that a tap answers. The compact island is one ActivityRow, or a few of
them when the centre holds several of one kind (two apps opening are two lines).
The overview lists the same rows.

Everything else that is live sits beside the centre as a bubble, one per kind,
in a chain that buds off the right end: each bubble melts out of the shape
before it through a smooth union whose reach is shorter than the gap, so the
bridge forms and snaps on the way out and is gone at rest. A bubble is not just
a mark. It still shows its state: an opening app carries its progress ring and
gets a check or a red mark when it lands or fails, dictation has a ring that
breathes with the voice and spins while the words are being made, music has its
cover with the track's progress around it, a waiting stack of notifications or
a download with more files carries a count, an update carries how many commits.
Several of one kind (two apps, three notifications) are a stack of bubbles: the
front one sits a little high and one or two more peek out straight down below
it. Hovering a bubble names it underneath ("Opening Firefox", "Dictating", "3
notifications"), because a mark alone does not always say what it is.
ActivityLook, ActivityMark and ActivityBubble hold how each kind looks, so a row
and a bubble can never disagree.

### Lit by the music

The media card made the cover its light, and the island borrows that. Behind
everything in the overview sits a field of the cover's own colours: its main
colours are picked out (the same clustering the wallpaper theming uses, run on a
tiny copy of the cover) and blended into a slow, soft wash, each colour as large
as its share of the cover, darkened enough to keep the words readable. A blurred
cover read as a smudge of the picture; the colours read as the song. The island
takes that tint, a track-change glance in compact form glows the same way more
faintly, and the card itself uses the same field (`ArtGlow`). The player in the overview is the card's anatomy at a
smaller scale, without the lyrics: those belong to the card. Its words are never
cut to the cover's height; a long title takes two lines and the row grows to
hold it. The expand
mark in its corner, a click on the song's words, or a click on a track-change
row opens the card, and the island becomes it. A plate swelling from where the
cover sat, with only the cover flying, read as something new appearing next to
the island rather than the island turning into the card. Now the island's own
body detaches: its outline, edge, shadow and colour wash move and grow into the
card's, and every part of the player travels from where it sat in the island to
its place on the card, the cover, the title, artist and album, the equalizer,
the seek bar and the buttons. The card is laid out at its final size the
whole way and the travelling body cuts it to shape, so what the island had no
place for, the lyrics and the player chips, is uncovered by the growing edge
and fades in over the last part. A compact row has no artist, album or seek bar, so
those ride with its title and with the body. At that moment the island lets go
of its body and drips out of the band afresh, and both colour washes run on one
clock, so the hand-over shows no seam.

Resting the pointer on the music, the card in the overview or a track-change
row, builds the card and asks for its lyrics before anything is clicked, so the
click only starts the move: the cover is already decoded and the card already
knows how wide its lyrics make it.

The card is not the island. Closing it fades it near where it is and nothing
flies back, but it drifts toward where it came from: up toward the island when
the island opened it, down when a key raised it from below. The island stays
usable while the card is up: the card's click-away
catcher leaves the island's shape and the strip above it alone, and the card
only briefly holds the keyboard exclusively (see the keyboard section), so the
pointer on the island is on the island. An island that just handed its body
over and re-forms under a pointer that has not moved does not open by itself.

### How the overview is laid out

Everything sits on two lines, one per side: the clock, the cover, the start of
the seek bar and the elapsed time on the left; the date, the weather, the
expand mark, the level meter, the end of the seek bar and the length on the right.
They are aligned by ink, not by text boxes, so a digit's side bearing or a round
cap on the seek bar never pokes out past the line. The top margin is larger than the
sides (24 against 16), because a clock that large needs room above it. Sections
are 16 apart and rows inside a list 8, so what belongs together reads together.
The title is the thing that matters while a song plays, so it takes the top of
the cover on its own; artist and album are one fact (who, and from where), so
they sit together as a tight pair on the cover's bottom. None of them ever
wraps or ends in dots: a line too long for its room fades out at the edge, and
once the overview is showing it waits two seconds, scrolls through to the end and
round to the start again, and pauses there two seconds before the next pass
(`ScrollingText`). Headless photographs
copy the compositor's rounding, so their corners are the same G2 curve as on the
screen.

### Which screen answers

Launches and dictation go to the focused screen. Notifications and notices go to
`Shell.offStageScreen`, the rule the corner host and the launcher rows follow, so streamer
mode keeps them off the streamed screen. Every screen keeps its own clock.

### While I dictate

The words land in the focused window, so while dictation holds the big spot
the island slides along the band to sit over that window's middle. Focus
follows the mouse, so it is the window under the pointer, and I can see where
the words will go before they are typed. It keeps the band's padding from the
screen's sides, appears straight over the window rather than sliding there from
the centre, and glides back to the centre once anything else takes the big spot
or the overview opens. The summon strip stays at the top centre wherever the
island is, because the overview always opens there; going up to a trailing
island is how I look past it, not how I open it. The island's surface moves by
its left margin. A
screen-wide surface would have let the scene slide inside it, but then the
whole strip would redraw every frame the voice moves; the margin costs one frame
per step of a glide and nothing in between. Each step asks for that frame,
because Qt skips frames when nothing in the scene changed and the new margin
would wait unsent.

When dictation is the only thing in the island, it gets out of the pointer's
way. Bringing the pointer up to it, anywhere from the top of the screen down to
just under the pill, sinks it back into the band, the drip in reverse, and only
a lip stays below the band to say it is still listening. It drips out again
once the pointer leaves. The island is click-through then and has no hover of
its own, so the pointer is read from Hyprland's request socket about twelve
times a second, only while dictation is alone. Anything else in the island, a
notification, an app opening, a bubble, keeps it where it is: then it has
something to say, and the pointer may well be going for it.

When a view fills the island, the notifications, the media, the timers, the
calendar, dictation steps out of it: its row slides out from behind the island's
right edge into a capsule of its own beside the top of the view, mark, live bars
and language, in the island's colour with the same sheen and shadow. Before, a
view simply covered it, and dictating into a window with the history open gave
no sign the microphone was listening. Back in the overview it is a row again.

### Summoning, and what passes through

Cursor to the top centre with a dwell, a tap on the strip to pin, a pull down to
drag the overview out of whatever size it is, a pull up to put it back. The
island is a spring while it opens and closes: a pull holds it exactly under the
finger instead of chasing it, a press on the strip or the open island catches
it wherever it is on the way, and letting go throws it open or shut with the
finger's speed, the open edge swinging a little past its place before it
settles. While the pointer is on it, every timer inside it stops. Hovering a notification never
opens the overview over it, it spreads a stack instead; a tap or a pull still
opens it.

The island takes input only while it is open or holds something pressable. A
launch or the dictation bars passing over a browser's tabs never eat the click
meant for them, which is what the old launch notice and mic pill did too. Its
surface stays mapped while empty, because Hyprland animates a layer surface
appearing and that would fight the island's own bloom.

### Notifications are a choice

`notifications.placement` defaults to `island`. The first version defaulted to `corner`,
because moving everyone's notifications is a big change for people who did not ask
for it; it moved once the corner no longer held the history, since a corner that
only shows popups has nothing the island does not do better. Set to `island`, a
notification takes the island at its large size. Its actions sit under the text
from the start, and on hover a close mark appears in its corner.

**A tap opens, it never dismisses.** It used to run the default action and then
delete the notification, and when there was no app to open the tap simply threw
it away, which is the opposite of what a press means everywhere else in the
shell. Now a tap runs the app's own default action, or brings its window forward,
or starts it, and the notification steps back into the history marked read.
With nothing to open (a script's `notify-send`, an app with no desktop entry) the
island becomes the notification: the whole text, its actions and reply, and a
dismiss button. Only a sideways swipe, the close mark, a right click or dismiss
lets one go. Nothing about a card's height depends on the pointer: when actions
came out on hover, moving down a spread list grew and shrank the card under the
pointer, so everything below it jumped up and down.

**History is reached by intent, not by a corner.** The launcher is the shell's
keyboard home and the island its pointer home, and the old corner tray was neither:
it opened when the cursor swept past on the way to a window's close button. The
overview shows the three apps that spoke last as real cards under the player, so
opening the island shows what came in without a second press; a notification used
to be visible there only while it was still arriving. A row under the three says
how many more there are and opens the island's history. The whole history is also
the launcher with `notifications ` already typed (section 19, and
`banditshell notifications open`). Other doors lead there from the island: the
"all notifications" button at the foot of a spread stack, and the "N held while
quiet" notice that shows for a moment when quiet ends and something was kept back,
which opens `notifications held `. `Launcher.show`
takes the text to start with. A person who chooses `corner` still gets the live
popups in a slim `NotificationCorner` at the top right, with no history, no arms
and no pin; reading the history is the launcher either way.

**Each notification is its own tile, and the tiles are joined.** In the
overview and the history a notification is a tile of `colour.tile`, a veil of
paper over whatever the island shows, so the cover's colour field behind the
overview comes through the cards as it does through the rest of the island;
they were solid at first and read as grey slabs on a coloured island. A tile is
set a small padding in from the island's
edge so the column's corners are concentric with the island's. Tiles that
border each other are joined into one column, as on Android: a hairline seam
between them and nearly square corners where they meet, full corners only at
the column's two ends. A tile comes loose when it is touched: dragging it
sideways rounds all four of its corners, and the corners of its neighbours that
faced it round too, so it reads as a card lifted out of the column. The
neighbours are tugged a little after it, the next ones a fifth of its travel
and the ones beyond less, each on its own spring, and once it is pulled past
the throw point they let go and swing home, the way Android 16 lets a swiped
notification come off its column. Let go
early and it springs back and joins again; throw it and the column closes up
behind it and its neighbours square their corners as they meet. The anatomy
borrows the phone's: the app's mark large on the left, the title first with the
time on its line, the text under it, and the app's name with its count at the
foot. The tile is only for lists: a single notification arriving at the
island's large size keeps the island as its card and uses the same order of
lines. Picked on 2026-10-18 from three mocks, then joined the same day; plates
under a folded app went with the joining, since they split the column, and the
count at the foot is what says an app is folded.

**One card per app.** The overview and the history fold notifications by app:
the app that spoke last is on top, and its card is its newest notification with
a count beside the name. A click on a folded card opens the group up to all of
them, newest first, instead of opening the notification, and the count folds it
again. A sideways swipe on a folded card clears the whole app, so forty finished
downloads go in one gesture; unfold the group to let one go. Folding is also what
keeps the history quick: it built a full card for every notification on the
click that opened it, a quarter of a second with forty of them, and now it
builds one per app. The rows of the list are placed from one running sum that is
redone whenever a row comes or goes; each row used to add up the rows above it
on its own, and a row born while another was being removed kept a stale sum and
sat on top of its neighbour or left a gap.

Message text on a screen is private, so the rows appear only when the query is
clearly about notifications (`notifications`, `unread`, `held`, with `from <app>` and
free words after them). A plain word never finds a message unless
`launcher.typing.notifications` is on, the same opt-in that
`launcher.typing.clipboard` is for copied text; it is off by default. Free words
list single messages, and a query with none lists one row per conversation, whose
Enter drills into that conversation. On a screen the stream keeps private the rows
are not offered at all.

Letting one go is a sideways gesture, animated before anything changes
underneath. Flick it either way and it follows the pointer, fading as it goes;
past a fifth of its width, or thrown fast, it flies off that side and is gone,
and only then does its row close up or the island fold away. Every list does
this, the history included: a left swipe there used to fly the card off and
leave its empty row behind. Short of a throw the card springs back to the
middle with the finger's speed and a small bounce, and a press catches it
anywhere on the way, flying off included, which takes the throw back. The close
mark and a right click do the same flick to the right.
Up and down never dismiss: a vertical drag on a card scrolls a spread list the
way a finger scrolls a phone, and a throw keeps it gliding. Past the top of the
list the stack gives, stretching down under the finger with growing
resistance, and springs back when let go. Swiping up to put a
card away used to share that direction, and it read as the card vanishing
instead of the list moving, so it is gone; a card that times out still lands in
the history. A stack carries "clear all" at its foot, folded or spread and
inside the overview.

### More than one

The first version showed one at a time and retired the one before to the
history, so a burst of three messages flashed past as one. Now they stack. The
newest sits in front, and a critical one goes in front of everything. The cards
behind it peek out under the island as one or two thinner layers, and a footer
says how many more there are and whose, one mark per app. Rest the pointer on a
stack and after the dwell the cards unfold under the front one into a list,
each with its own hover, close mark and actions. The unfolding is a reveal, not a
regrowth: every card is already laid out in its final place, and the island's
edge sweeps down over them with "clear all" riding it, so no text moves or
appears line by line; folding is the same sweep upward. The island's height
follows the sweep exactly instead of chasing it, and the window is sized for the
whole spread up front, so nothing resizes mid-sweep. They fold back once the
pointer has been gone for the grace. Every card keeps its own timer, so a burst drains
in about one timeout, not one timeout each.

A new one is dealt like a new card on a pile. The island itself, carrying the
new notification, drops down from behind the screen's top edge, and the card
it lands on is a real card that stays where it was: it keeps its own text and
outline, steps back, narrows and sinks until it is the first layer peeking out
underneath, its text fading as it goes. The layer that was there moves one
place back, and the backmost tucks up behind it and is gone. Crossfading the
text inside a pill that never moved read as everything shuddering with nothing
actually moving. Letting the front one go runs the roll the other way: the
next card starts rising from behind the moment the flick begins, not after the
old one has finished leaving, and the island's height follows the new card
without dipping in between.

A long pile stays on screen. The spread stops at a little over half the
screen's height, its edges fade where there is more, and it scrolls: a wheel
notch moves about four lines, a touchpad moves with the fingers, and at either
end the wheel passes through to whatever is under it. The overview holds the
same capped list. Clear all throws every card at once, the ones on screen
twenty milliseconds apart from top to bottom so the sweep reads as a wave, and
the ones scrolled out of view with the first. The list holds still while they
go; closing it up after each one made clear all look like a fast scroll.

A card outside the visible part of the list is made transparent, never
invisible. An invisible item drops out of its column's layout, so a card's
measured height collapsed whenever it scrolled out of view and grew back when
it returned, and the cards around it overlapped while that happened.

A card being dragged or flung counts as the pointer resting on the island,
wherever the pointer actually is, so a held drag never unpauses the timers,
reshuffles the island or spreads the stack under the finger. A release only
counts as a throw when the pointer was still moving: holding still and letting
go springs back.

### Every situation is its own

The first version had one rule for arrivals, "a notification takes the island",
and it was wrong in most places it ran. It threw away the overview I had just
opened and covered the bars while I was speaking. The second waited every
notification out behind dictation in a bare icon. Neither is how it should feel.
The rule now is that the newest thing always gets the big spot, and then things
settle where they belong. `arrange()` in Island.qml keeps the order (the centre
first, then the bubbles beside it, nearest first) and which arrivals are still
having their moment; `situation` names what the island shows.
`banditshell island status` prints it. `banditshell dev inspect island` makes
each one up on the live island to look at, hover and click, and plays a thirty
beat story through all of it; `banditshell dev check island` walks through them
headlessly, checks each and photographs it.

| Something arrives | What happens |
| --- | --- |
| A notification | takes the big spot at once as the card; whatever had it glides into the nearest bubble and pushes the others out |
| Dictation or an app, while a notification shows | appears as a row below the card ("Opening Firefox") for a moment, then glides into its bubble beside it; the notification keeps the big spot while it is being shown |
| Dictation or an app, while something else has the big spot | appears as a row below it for a moment, then takes the big spot; the old one glides into the nearest bubble and the newcomer slides up |
| Another of a kind that already has the big spot (a second app) | another line, at the bottom |
| Another of a kind that sits in a bubble | only the newcomer has its moment below; the bubble keeps the others |
| An activity someone posted, or a running timer | the same as an app opening: below the big spot for a moment, then in it, and a bubble once something newer takes over |
| A timer in its last ten seconds | comes to the big spot at once, whatever it was in |
| An alarm, or a timer that ended | takes the big spot whatever is happening, even from a critical notification, with its buttons |
| A music change, a download, an update, the kernel | a row at the bottom of the big spot, or the big spot itself if nothing else is live, for as long as its moment lasts; then it is gone, never a bubble. A music change only counts when its player is not the focused window |
| Anything while the pointer is on the island | has its moment below and then waits as the nearest bubble, its timer held; nothing moves under the pointer, and it takes the big spot once the pointer leaves |
| A critical notification | takes the big spot whatever is happening |
| Anything while the overview is open | lands inside it, notifications under the clock |

| Something leaves | What happens |
| --- | --- |
| What held the big spot | the nearest bubble glides back into it |
| A bubble | it is absorbed, and the ones further out slide in |
| A row | it fades where it is and the rows under it slide up |
| The last one under the pointer | the overview does not open by itself; the dwell waits for the pointer to leave and come back |

The story that set this: dictating, a notification comes in and takes the big
spot while dictation becomes a bubble; the notification goes and dictation comes
back; an app opens, shows below dictation and then takes the big spot; a second
app opens, two lines; the music changes and has its moment below; then a
notification on top of it all, and the apps glide aside. A moment lasts 2.5
seconds (`announceMs`); a music change or a download lasts as long as its glance.

A notification in a bubble keeps its timer held. Pressing any bubble brings it
to the big spot now. Timers also stop while the pointer is on the island; a
pinned overview with the pointer elsewhere lets its arrivals time out, so it
works as a feed.

### Things move, they do not swap

Opening the overview over a compact activity used to fade the compact row out
and fade the same row in at its place in the list. Now one row travels from the
capsule to its slot in the overview and widens on the way. The list's own copy
only takes over once the two sit exactly on top of each other. The voice never
stretches. It is one smooth mirrored curve drawn by a single shader, and a wider
row shows more of it rather than a wider copy: the newest voice comes in on the
right and the oldest leaves on the left, both through a soft fade that never
goes fully dark. It used to be 128 bars that each jumped a whole bar with every
level, and then a curve through every level, and both read as choppy. Now each
pair of levels is one point and the curve is a B-spline, so a syllable is one
soft swell; the levels land in a ring that never shifts, and a playhead glides
through it at the rate they arrive, a couple of levels behind the newest, so
uneven arrivals never make it jump. Dictation keeps 128 levels so the overview's
row has enough history to fill.

Going into a bubble does not move anything: the row fades where it is while the
bubble morphs out of the island with its mark already on it. It swells out of the
island's edge, pulls away on a liquid neck (each bubble melts with a reach that is
wide while it grows and short at rest) and snaps free; coming back is the same in
reverse. Rows never jump: each keeps its own slot and slides when one above it
leaves. Badges and rings fade, and so do the layers of a stack. A stack of cards
shows at most two behind the front one, the nearer lighter and the further darker
and underneath, cut with the card's own corners; resting the pointer on it unfolds
every card straight down, revealed at full strength while the island follows the
stack's height.

Opening the overview carries everything with it. Rows in the big spot travel to
their rows in the list. The notification cards move down under the clock before
the clock fades in. Bubbles slide into the island's side and melt into it as it
widens, and their rows fade in once the overview is open; closing buds them back
out of the side. A music change's cover grows into the player's cover. The
overview opens width first: the island reaches its full width in the first half
of the way, then grows down, and its contents fade in only in the second half,
so nothing is ever laid out wider than the island holding it. A row that has no
place in the overview fades where it is rather than drifting through the player.
Live rows sit right under the clock, the player under them, then the newest
notifications and the row for the rest last, so the rows travelling in from the
capsule have the shortest way to go.

### Hover

Everything in the island answers the pointer. The capsule widens a little under
it, leaning toward the dwell, and a bubble grows under it. In the overview a row
lifts a plate behind itself, its mark grows and its chevron nudges right. The
date next to the clock reads out in full, the song's words get a plate, and the
transport and scrubber keep the hover they already had. A notification card
lifts a plate and shows its close mark. Rows that do nothing get no plate, so a
plate always means a click. A finished launch focuses its window, the dictation
row opens the transcription history, and a waiting notification comes out when
pressed. The clock, the date and the weather lift a plate too, because each of
them opens something (see below).

### The island becomes what you press

Pressing something in the island used to send me somewhere else: the shell's
update notice opened the update menu on the left, and the notifications row
opened the history away from the island. The eye was on the top centre and the
answer turned up somewhere else. Now the island turns into the thing pressed, the way it
already turned into the media card. The sidebar keeps its menus; this is the
place I am moving to, things shown when looked at.

| Pressed | The island becomes |
| --- | --- |
| The system update row | the update: stages, progress, questions, cancel |
| The shell's update notice | the shell update: what is new, download, restart |
| The notifications row | the history, as the island's own stack of cards |
| The clock | timers and alarms, the same composer the sidebar clock has |
| The date | the month, the same calendar the sidebar has |
| The weather | the week ahead |

Each is a view the island hosts in place of the overview: the rows travel out,
the bubbles melt into its side, notifications wait with their timers held, and
the island widens to what the view asks for (the update half again its width,
the week of weather as much, the calendar its usual width) and grows to the
view's height, capped at seven tenths of the screen with the rest scrolling.
The views carry a header with their name and a close mark. Escape, the close
mark, a tap on the strip or a pull up leave the view; a view opened from the
overview goes back to the overview first, so stepping in and out reads as
going down a level and back up. While a view is up the island takes the
keyboard on demand, so the timer composer's fields can be typed into.

The weather shows the next seven days from Open-Meteo, located by the
coordinates wttr.in already sends with the current weather, and falls back to
wttr.in's own three days when Open-Meteo cannot be reached. A town the
weather service does not know says Place not found, and its Change place
opens the Place row in Settings (Focus, Clock, Weather), where the place,
the units, the refresh and the weather itself are set.

### Music I am already looking at

A new track glances in the island so I hear about the player I am not looking
at: Spotify on another workspace, a video in a background tab. When the player
is the focused window I started it myself, and telling me what it plays is
noise. So the glance only comes when the player is somewhere else.

The player and the window are matched by process: the MPRIS name's owner on the
bus against the focused window's pid, with the window class against the
player's desktop entry for apps whose bus name belongs to a sandbox proxy. A
browser holds many tabs in one process, so for a browser the focused window's
title also has to carry the track's title, which is what a browser shows for
the tab in front. Titles lag a little behind a new video, so a browser match
that is not certain yet waits a second and a half for the title to catch up
before the glance goes out. A shell that just started has no focus event yet,
so the window Hyprland lists first in its focus history stands in.

### Anything can post to it

The island used to know ten kinds, all written into it. Now it has a front door.
`Activities` is a registry: a script, a build, an agent or a download manager
posts `{id, text, detail, progress, icon, priority, until, act}` and the island
draws it with the anatomy everything else has, a mark, words and a sign.
`banditshell island push --id build --text "Building" --progress 0.4` does it
from a terminal, `update` moves the progress or the words, `end` finishes it,
`list` says what is up. The same four verbs are the `activity` IPC target
(`ActivityIpc.qml`), so a program that can run a command can use the island.

Progress is a ring in the row and around the bubble; left out, the ring spins.
Ending is a mark, not a disappearance: a check, a red mark or a cross takes the
ring's place for a moment, then the row goes. `until` is how long a forgotten
activity may stay. Posting an id again replaces it, twelve is the most, and the
thirteenth pushes out a finished one first, then the weakest. Pressing the row
runs the command it was given, and a row with none does nothing, so it never
gets a plate. The rules are in `activities.js`.

A timer from the clock menu shows as a ring around a small timer mark with the
time left on the right, always as wide as its longest reading so the capsule
does not breathe every second. Beside something else it is a bubble with its
ring around the edge and the time as its badge. In its last ten seconds it
comes to the big spot, and pressing it pauses or resumes. When it ends, and
when an alarm rings, the island holds an alarm row: Stop, and Snooze for a real
alarm. That row takes the big spot from everything, a critical notification
included, which waits in a bubble; the clock's own notification still lands in
the history. Quiet timers, the pomodoro's, stay out.

Volume, mute, brightness and mic mute are a moment, not a thing that stays: a
row with a mark, a bar and the number, for a second, at the bottom of whatever
holds the big spot. Nothing in the shell answered the volume keys before, which
read as dead. `Levels` watches Audio, Display and Backlight and keeps quiet when
a surface that already shows that level is open (the sound menu, the quick
controls, the settings volume row declare it with `LevelCover`), when the device
just changed, and for the first seconds after the shell starts.
`island.levels` turns it off.

Five more things post through the same door, as `Moments` and `Privacy`, and each
has its own switch under `island.moments`. A screenshot shows the picture small
through `SquircleImage`, with Copy, Edit (the picker's editor), Folder and Delete,
for six seconds; pressing the row opens the picture, and Delete moves it to the
trash. It runs after `screenshot save`, `copy` and `full`. Copying anything from
the shell gives a short Copied row with the first twenty characters; text that
was copied as sensitive shows eight dots instead of the text. An audio device
that connects over Bluetooth gets its name and battery for three seconds. A
Wi-Fi join that fails says Wi-Fi failed in red, with the Wi-Fi-but-not-connected
mark and Try again. Like a failed update it waits until it is seen: pressing it
turns the island into the failed join, which names the network and says the
cause in a sentence ("The router did not answer") with Close and Try again, and
it also goes once that network connects. Only joins a
person started count, through `Network.join`, so a dropped connection or a
background retry stays quiet, and a wrong password typed into the join prompt
goes back to the prompt instead. The fifth is not a moment but a state: while a program holds the microphone, the
camera or a screen cast open in PipeWire, a privacy activity stays up, coloured
(the camera and the screen alarm red, the microphone accent), naming the app. It
is kind `privacy`, so it sits in the island like dictation does, but it joins
the others as a bubble and never takes the big spot from what is already
there; hovering the bubble names the apps, and pressing the microphone's opens
the sound menu. Dictation and the screen recorder already show themselves, so
the microphone is left out while dictation runs, and the screen share while the
shell records. What counts as a camera, a microphone or a cast is in
`privacy.js`: a stream that an active link feeds from a device. A program that
reads the camera without PipeWire (a raw video4linux grab) is not seen.

The microphone is announced, not kept on show. A voice assistant listening for
its wake word holds the microphone all day, so when a program starts listening
the island says "Microphone on" for one glance (`island.glanceSeconds`) and then
goes; it comes back only when a program that was not listening before starts.
The overview keeps a "Microphone on" row for as long as anything listens, and
pressing it, there or during the glance, turns the island into the microphone:
the input device, and each program that listens, named by the systemd unit it
runs in (`diablo-voice`), then its binary, with its command line. That list is
asked of `pw-dump` and `/proc` when the view opens, never polled. The labels are
short on purpose ("Microphone on", "Camera on", "Screen shared"): what PipeWire
calls a stream is often a library's name, not a program's. The rail's
microphone mark follows the glance, except that a muted microphone something
still listens to stays marked. The camera and a screen cast are rare and stay
up for as long as they run.

### The kernel, and the update it starts

`services/Pacman.qml` runs checkupdates every `packages.interval` minutes. Only
the package of the kernel actually running counts, so linux-zen and linux-lts
users get the same notice. Pressing it starts the system update, `pacman -Syu`
and never a single-package upgrade: Arch does not support partial upgrades.
Once the running kernel's vmlinuz is gone from its modules folder, the island
asks for a restart. Pressing that opens the power panel instead of restarting,
because when to restart is not the shell's call.

The update used to open a terminal. Now the shell's own password prompt asks,
the way the launcher does when it installs something, because pacman runs
through pkexec. Without the shell's polkit agent, or without pkexec, it falls
back to the terminal running `packages.upgrade`. So does a `packages.upgrade`
that is not a plain pacman full upgrade: an AUR helper someone chose, or extra
flags, keep the terminal, because the island only knows how to read pacman. A
plain one in any spelling (`sudo pacman -Suy`, `--sync --sysupgrade`) runs in
the island, and its `--noconfirm` is kept: pacman then takes its defaults and
asks nothing.

While it runs, the island carries it as a row: the kernel's mark, the stage in
words ("Downloading 12 of 87", "Installing 34 of 87") and a ring for how far it
has come. An update can take a while, so the row stays for one glance
(`island.glanceSeconds`) and then goes up into the band, where it takes no
room. Pressing it turns the island into the update: it widens to half again its usual width,
everything else in it fades or melts away, and its notifications wait with
their timers held. The update shows four stages, download, verify, install and
finish, as one bar cut into four, with what is happening under it and the
overall share on the right. Hiding it, a tap on the strip, Escape or a pull up
puts the island back and leaves the update running.

### A long job goes up into the band

Once the update has had its glance, the island lets go of the row and sinks
into the band, and the band itself becomes the progress bar: a line at its top
centre, inside the band's own thickness, so the frame gets no wider or
thicker. The line is half as long as the large island, a track in the dim
accent that the accent fills from left to right, and it fades in where the pill sank, so
the eye follows the update up. Opening the island lists the row
again with its ring, and pressing it opens the update as before; the line
steps aside while the update view is open. Whatever needs me brings the row
back down: the password prompt keeps it until it is answered, a question from
pacman drops it back into the island, and the end of the update comes back as
a row, a good one for its glance and a failed one until it is seen. A band too
thin to hold a line (no band, or the stream band covering it) keeps the row in
the island the way it was.

The island decides what goes up and the band only draws it: `Island.lifted` is
the share of the job, or -1 for nothing, and `BandProgress` draws it. One job
holds the band at a time. Only the system update goes up today; the next long
job that should follow it gets a line in `lifting` and nothing else.

pacman runs in a pty, so it draws its own progress bars, and the shell reads
those. It also means a question pacman asks reaches the island: a conflict, a
replacement, a provider to choose come up as buttons with pacman's default as
the filled one. "Proceed with installation?" is the one question it answers by
itself, because pressing the notice already said yes, and only after the
prompt has sat unanswered for a moment, so replaying a log after a reload can
never push a stray yes into a later question.

Cancel works until pacman starts checking packages. It sends Ctrl-C through the
pty, and pacman stops before it has changed anything. After that, Ctrl-C would
stop it between two packages and leave half an upgrade behind; pacman even
exits 0 when that happens. So from the first check on, the cancel button is
greyed out and says why, and the runner itself refuses a late cancel by
reading the log, so a press that loses the race to pacman still does nothing.

The terminal is not gone, it is just not the main way in. "Watch in terminal"
opens one that tails the same log, progress bars and colour included. It only
reads, so closing it stops nothing. The update runs under setsid, outside the
shell, so a reload or a restart cannot kill it either; the shell picks it back
up from the runtime dir. A finished update stays until it has been seen: a good
one goes after its glance, a failed one waits with what went wrong in plain
words, a way to try again and a way to run it in a terminal.

### What went

SummonZone, MicIndicator, LaunchNotice and MediaPreview, whose only home was
the notch. The mic pill's two habits, following the focused window and tucking
away from the pointer, went with it at first. Both came back on 2026-10-17
(see While I dictate): a click-through island still covers what is under it,
and a fixed one at the centre no longer says which window the words are for.
The island hangs under the stream band the way the notch did.

## 19. Launcher sources

`modules/launcher/LauncherSearch.qml` grew to sixteen hundred lines because
every kind of result lived in it. New kinds of result go in their own file
under `modules/launcher/sources/` instead, and LauncherSearch lists them in
`sources`. A source is a plain QtObject; every member is optional except
`search`:

- `required property var search` is the LauncherSearch hub. Read
  `search.text` (the trimmed query), `search.query`, `search.screenName`,
  `search.windowTarget()`. Call `search.launch(fn)` to start something and
  close the launcher, `search.leave(fn)` to close it first and then run `fn`,
  `search.retype(text)` to replace what is typed.
- `groups`: an array of `{ key, title, items }`. Each item is a row: `key`,
  `kind`, `label`, `detail`, `icon` or `iconSource`, `score` (Infinity puts
  it first, -Infinity last), `toggle` for a switch, and `slider` (`{ value,
  set, to }`, where `value()` reads the live level and `set(v)` changes it)
  for a level the row can drag; Left and Right nudge the selected one by
  `step` (0.05 unless set), a fifth of that with Shift. `text()` replaces the
  percentage beside it, and `warnAbove` moves the marker that is at 1.
  `nudge(offset)` takes the keys' step instead of `set`, for levels that are
  not a clamped fraction (seeking), and `bare: true` hides the bar while the
  label and the keys stay. A
  row can also carry `glyph` (a character, such as an emoji, drawn as its
  icon) and `ask` (`{ prompt, icon, suggestion, take }`): Enter on it turns
  the field into a one-line question and hands the answer to `take(text)`.
  `peekPath` (with `peekDir: true` for a folder) or `peekText` fills the card
  beside the launcher when the row is selected: a picture, the first lines of
  a text file, a folder's contents, or the full text. `peekImage` shows a
  picture by URL (cover art), and `peekColour` opens the card as a colour
  picker; what is picked there lands in `search.colourEdit` under the row's
  key. The card sits level with the launcher's top edge. With Animate
  preview on, its frame grows or shrinks to the next preview over content
  already laid out at its final size. `peekCard` is a
  Component whose root has an `entry` property; the card hosts it with the
  row's `entry` set, for a row whose preview is a live item rather than text
  (the notification rows show their card at page density this way). An action
  can start the same one-line question as `ask` through `search.inquire(row)`,
  where the row carries `ask`; the notification Reply, Snooze and Mute use it.
  `search.onStage` is false on a screen the stream keeps private, and a source
  whose rows carry message text returns nothing there; `search.copyText(text)`
  closes the launcher and copies.
  `columns` (`[{ text, chars, tone }]`) replaces the detail with fixed
  columns `chars` digits wide, so the same fields line up from row to row;
  `tone` is `"lit"` (accent) or `"dim"`. `swatch` (a colour) draws a colour
  chip in place of the icon, and `tab:
  true` lets the row take Tab even when another row is selected. In
  `actionsFor`, a first action with `button: true` also shows as a button,
  for rows whose Enter action belongs next to the others (Pause beside Skip
  and Stop). Groups are ordered by their best score, like the built-in
  ones.
- `kinds`: the row kinds this source owns. The hub hands `activate(row)`,
  `actionsFor(row)` and `complete(row)` for those kinds to this source.
  `actionsFor` returns `{ icon, label, short?, run, tucked? }`; the first is
  what Enter does, the rest become row buttons, and tucked ones sit under
  More. `complete` is Tab; return true when it handled it.
- `confirmActionsFor(row)`: the buttons an armed row shows (the hub adds
  Cancel). A dangerous action sets `search.armed` to a key on the first
  Enter and only runs on the second; the row reads "Press Enter again to
  ..." while armed.
- `commands`: entries for the shared command list, `{ id, icon, label,
  words, detail?, toggle?, stay?, confirm?, run }`. These get aliases and
  hotkeys for free.
- `rowById(id)`: rebuild one of this source's rows from its key, so its
  rows can take aliases and hotkeys too.
- `intent`: true when the query is clearly meant for this source, which
  stops the calculator from answering it.
- `caps`: `{ groupKey: n }` to show more or fewer rows than the default.
- `phrases`: `{ head, picks }` entries Tab completion offers, like
  `{ head: "emoji ", picks: ["smile", "heart"] }`.

Scores: apps rank about 1 to 4 (4 for an exact name). Files whose name
matches rank 0 down to -3, settings sit under every matching file (-4 to
-7), and lines found inside files come last. A row that shows up for a plain word the user did not clearly mean for a
source stays near or below 0.5 (an emoji whose name starts with the word, or
a plain question for the AI, may reach 0.8, still under an app prefix match);
a clear ask of a source puts its first row at Infinity. Rows the user
runs get a small lift next time from `services/LauncherMemory.qml`, which
skips typed text, links, files and anything positional.

The result list is not a binding: `arrangeInputs` lists everything
`arrangement()` reads, and a change schedules one rebuild per event loop
turn. Key handlers call `arrangeNow()` first. A source whose groups read a
property the hub does not already list must still expose it through
`groups`, which is in `arrangeInputs`.

Five sources read the shell's own state and live in the `launcher-shell` package
(`packages/launcher-shell.json`), switched under `launcher.shell`: `keys`,
`tray`, `workspaces`, `actions` and `recent`, each true by default. `ActionsSource`
turns an action row with a required argument into an `ask` row and arms the ones
that empty something (clear, remove, cancel) before they run through
`banditshell action <id>`; ids under `launcher.` and `shell.` are never rows, and
neither are ids that only print. The hotkey sheet has no open-at call, so Enter
on a keybind copies the chord and the sheet is a second button.

A hotkey runs a row through a LauncherSearch that the CLI makes and throws
away at once, so anything that outlives the call (a Process, a timer) belongs
in a singleton service, not in the source. `FallbackSource.qml` is the
smallest example; `SoundSource.qml` shows sliders. Typing into the window
the user came from goes through `services/Typist.qml`, which waits for that
window to have focus again and copies instead when wtype is missing. Text
with characters outside the keyboard map, such as an emoji, is pasted
instead into Chromium and Electron windows, which ignore the keymap wtype
swaps in, and the clipboard is put back a moment later.

---

*Relevant portable rules to re-read when building: `~/.claude/rules/animation-smoothing.md`
(exponential smoothing), `~/.claude/rules/math-over-hardcoding.md` (compute zones/positions),
`~/.claude/rules/g2-corners.md` (G2/squircle corners, never a plain radius),
`~/.claude/rules/type-scale.md` (at most three font sizes),
`~/.claude/rules/working-style.md` (just-try-then-iterate, preserve the distinctive style,
explicit line breaks). Memory pointer: `project-custom-shell-plan`.*
