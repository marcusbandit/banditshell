# banditshell - Design Document

> A from-scratch desktop shell to eventually replace caelestia.
> Written 2026-07-28 as a reference. **Nothing is being built yet** - this is the
> captured plan and philosophy to return to when work actually starts.

Why this exists at all: caelestia is finished and excellent, but building it myself is
the point. I want to be proud of my system and understand how the *entire* thing works.
The constant urge to tweak caelestia is the tell that I'd rather own the whole mental
model than live in someone else's. This document is so that intent survives the gap
between now and whenever I actually start.

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
- Code should be written to be *read*: comments explain the non-obvious *why* (why a separate
  window, why a mask and not opacity), not the obvious *what*.

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
a specific widget that demands it. **caelestia stays on disk as a reference implementation**
- a working, readable answer for the hard parts (wallpaper backend, lock screen, IPC
face-unlock pill), not something to delete.

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

This is deliberately close to caelestia's construction. **We are rebuilding caelestia's main
parts, with more control, because they are ours.** The point was never that caelestia is wrong;
it is that I want the whole mental model. Where caelestia solved something well, copy the
solution and understand it, don't invent a worse one to be different.

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

Animation implementation for all this motion/summon/tracking: **exponential smoothing** by
default (see `~/.claude/rules/animation-smoothing.md`) -
`position += (target - position) * (1 - Math.exp(-speed * dt))`. Moves fast when far, settles
gently when close, safe at any dt. Use spring/bounce or fixed-duration only where a specific
effect calls for it.

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
- **Corners are G2, never circular.** Every rounded shape goes through `components/G2Rect.qml`
  (a squircle drawn with `QtQuick.Shapes`). `Rectangle.radius` is banned in this project: it's
  a circular arc, so curvature jumps at the corner and the eye reads a pinch.
  Portable rule: `~/.claude/rules/g2-corners.md`.
  - **Where a panel meets a screen edge, the corner is CONCAVE** (a negative radius in
    `G2Rect`). A convex corner there curls the panel away from the edge and leaves a notch of
    dead space, which is wrong: nothing is floating, the panel is part of the edge. Concave
    makes the panel's free edge sweep outward and arrive tangent to the screen edge. Convex is
    for things that genuinely float.
- **At most three font sizes, shell-wide.** `small` / `normal` / `large` in
  `config/Appearance.qml` and nothing else. Hierarchy is carried by colour, weight and
  spacing instead. Portable rule: `~/.claude/rules/type-scale.md`.
- **Palette: GREENSTEEL, shared with the compositor.** The colours are not invented here. They
  are taken verbatim from `~/.config/hypr/theme/greensteel.conf` into
  `config/Appearance.qml`, so the shell and Hyprland's window borders are the same object
  rather than two things that happen to both be green. Cool anodised-green metal: one hue
  family climbing near-black to silvery white, with a saturated end (`verdigris` / `lush` /
  `phosphor`) spent sparingly so a bright stop reads as a specular highlight.
  - **The Monocraft constraint is load-bearing.** greensteel.conf says it: pixel-font stems are
    one device pixel, so anti-aliasing has nothing to work with and mid-tones turn text to
    mush. Pixel text goes `phosphor` or `silver` on `abyss` or `void`. **Never on `body` or
    `brushed`.** That is why the panel is `abyss` and not a mid moss green.
  - Rounding matches too: `Appearance.rounding.normal` is 15, which is Hyprland's
    `rounding = 15`. Hyprland is already drawing superellipse corners there
    (`rounding_power = 4.0`), the same idea as our G2 smoothing.
  - If greensteel.conf changes, `Appearance.qml` changes to match. Same names, one direction.
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
├── config/
│   ├── Config.qml               SINGLETON. ~/.config/banditshell/config.json, live.
│   ├── Compositor.qml           SINGLETON. What Hyprland/niri say about rounding + gaps.
│   ├── Themes.qml               SINGLETON. Named palettes (ramp + accents).
│   └── Appearance.qml           SINGLETON. Config x Compositor x Themes -> the tokens.
├── components/                  generic, reusable, know nothing about the shell
│   ├── squircle.js              G2 corner geometry (pure maths, no QML)
│   ├── G2Rect.qml               the ONE rounded-rect primitive
│   ├── ScreenCorner.qml         one black piece of the display's rounded corner
│   ├── Separator.qml            a hairline divider
│   ├── StyledText.qml           the ONE text element
│   └── Icon.qml                 the ONE icon glyph (separate face from text)
├── services/                    the outside world, adapted
│   └── Hypr.qml                 SINGLETON. Hyprland IPC -> clean workspace state
└── modules/                     actual shell UI
    ├── ShellWindow.qml          THE surface: everything visible, all the input
    ├── Chassis.qml              the band + sidebar as ONE shape
    ├── FrameExclusions.qml      invisible; reserves the room the chassis occupies
    ├── TopClock.qml             summon zone: cursor to top-centre -> time slides out
    └── sidebar/
        ├── Sidebar.qml          layout of what sits in the chassis's left band
        ├── Clock.qml            stacked HH / mm / date
        ├── Workspaces.qml       Hyprland workspace indicators
        ├── StatusIcons.qml      the status section, rendered from data
        └── StatusIcon.qml       one indicator, service-agnostic
```

Import paths: Quickshell exposes the config root as the module `qs`, so a directory is
`import qs.components`, `import qs.services`, `import qs.modules.sidebar`. There are no
`qmldir` files to maintain; Quickshell generates them.

**Configuration: no magic numbers, anywhere.**

`Config.qml` owns `~/.config/banditshell/config.json`. Edit it and the shell follows live; delete
it and it is rewritten from the defaults. The `defaults` object in that file *is* the schema:
a key not in it is not a setting, and a key in it always resolves, so a half-written config
still boots. `Config.set("sidebar.width", 90)` writes and persists, which is the entire API the
future settings menu needs.

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

**One shape, one surface. REVISED 2026-08-01.**

Everything the shell draws is in ONE window per screen, and the chassis (the band around the
screen plus the sidebar) is ONE shape: the screen with the content area cut out of it.

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
the left edge the way `TopClock` already does at the top.

---

*Relevant portable rules to re-read when building: `~/.claude/rules/animation-smoothing.md`
(exponential smoothing), `~/.claude/rules/math-over-hardcoding.md` (compute zones/positions),
`~/.claude/rules/g2-corners.md` (G2/squircle corners, never a plain radius),
`~/.claude/rules/type-scale.md` (at most three font sizes),
`~/.claude/rules/working-style.md` (just-try-then-iterate, preserve the distinctive style,
explicit line breaks). Memory pointer: `project-custom-shell-plan`.*
