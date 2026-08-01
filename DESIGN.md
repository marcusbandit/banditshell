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
│   ├── CornerWedge.qml          a corner's leftover; rounds off the screen corners
│   ├── blob/
│   │   ├── blob.frag            the chassis as a signed distance field
│   │   ├── blob.frag.qsb        compiled; rebuild with `banditshell shaders`
│   │   └── BlobField.qml        the ShaderEffect that draws it
│   ├── Follow.qml               a value that chases a target by exponential smoothing
│   ├── Separator.qml            a hairline divider
│   ├── StyledText.qml           the ONE text element
│   ├── Icon.qml                 the ONE icon glyph; verifies the name exists
│   ├── SignalBars.qml           a drawn strength meter (the font's is illegible)
│   ├── Slider.qml               a value you drag, or a read-only gauge
│   ├── Toggle.qml               a switch
│   ├── MenuRow.qml              icon + label + detail + trailing slot
│   └── PasswordField.qml        inline secret entry
├── services/                    state that outlives any one widget
│   ├── Hypr.qml                 Hyprland IPC -> clean workspace state
│   ├── Audio.qml                PipeWire: sinks, sources, volume, mute
│   ├── Battery.qml              UPower
│   ├── Network.qml              NetworkManager: wifi, one entry per SSID
│   ├── Bluetooth.qml            bluez: adapter and devices
│   ├── Media.qml                MPRIS, with a stable choice of player
│   ├── SysInfo.qml              /proc and /sys: cpu, memory, temperature
│   ├── Wallpaper.qml            the current wallpaper and the list to pick from
│   ├── Notifs.qml               the notification DAEMON (a server, not a reader)
│   ├── Apps.qml                 desktop entries, and ranked search over them
│   └── Shell.qml                which ShellWindows exist
├── modules/                     actual shell UI
│   ├── ShellWindow.qml          THE surface: everything visible, all the input
│   ├── Chassis.qml              the band + sidebar as ONE shape
│   ├── FrameExclusions.qml      invisible; reserves the room the chassis occupies
│   ├── Ipc.qml                  the control surface the CLI talks to
│   ├── TopClock.qml             summon zone: cursor to top-centre -> time slides out
│   ├── WallpaperWindow.qml      background layer, below every window
│   ├── launcher/Launcher.qml    grows out of the sidebar; the one keyboard grab
│   ├── picker/                  screenshot: hover a window or drag a region
│   ├── notifications/           discrete cards; NOT part of the blob field
│   ├── menu/
│   │   ├── Menus.qml            which menu is open, where it sits, when it closes
│   │   ├── MenuPanel.qml        one panel: geometry and contents, NOT a shape
│   │   └── content/             one file per menu, all reading the real machine
│   │       ├── SoundMenu.qml    MicMenu.qml    NetworkMenu.qml
│   │       ├── BluetoothMenu.qml MediaMenu.qml SystemMenu.qml
│   │       └── BatteryMenu.qml  PowerMenu.qml
│   └── sidebar/
│       ├── Sidebar.qml          layout of what sits in the chassis's left band
│       ├── Clock.qml            stacked HH / mm / date
│       ├── Workspaces.qml       Hyprland workspace indicators
│       ├── StatusIcons.qml      the status section, rendered from data
│       └── StatusIcon.qml       one indicator, service-agnostic
└── bin/
    └── banditshell              the CLI (linked into ~/bin)
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

`services/` is state that outlives any one widget. Mostly that is the outside world, but it
also holds `Shell.qml`, the registry of which windows exist: the things that need it (the IPC
handler, later keybinds) sit outside the window tree entirely, and threading a reference down
to them would couple files with nothing else to say to each other.

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
the left edge the way `TopClock` already does at the top.

## 9. Driving it from a terminal

`bin/banditshell` (linked into `~/bin`) wraps a Quickshell `IpcHandler`.

It exists because **menus open on hover, and hover is impossible to assert**. You cannot script
a cursor into a corner and check what happened, so the gesture and the thing it opens have to
be separable. Every menu is reachable by name, which means a change to a panel can be checked
without reproducing the gesture, and a change to the gesture can be checked against a panel
already known to work.

```
banditshell start|stop|restart|run|log
banditshell menu list|open <key>|close|toggle <key>|current
banditshell status                 what the shell thinks the compositor said
banditshell get <key> | set <key> <value>
banditshell shot [file]
banditshell demo <key>             open, screenshot, close
```

`status` exists for one failure in particular: the shell deriving its geometry from the
compositor and quietly disagreeing with it. Printing rounding, smoothing, both gaps and the
window border side by side makes that visible instead of subtly wrong.

Two things worth keeping in mind, both learned the hard way:

- **`pkill -f` matches the command line of the shell that runs it.** `pkill -f 'qs -p …'`
  killed its own invoking shell before the rest of the command ran, which silently stopped a
  config reset from happening for several rounds of work. Use `pkill -x qs`.
- **Warping the pointer with `hyprctl dispatch movecursor` does not always deliver motion
  within a surface.** It is fine for entering the shell from elsewhere and useless for testing
  a slide from one icon to the next; `ydotool mousemove` produces real relative motion, and
  that is what exposed the hover race.

---

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
  directory and has nowhere to run a build step, so `banditshell shaders` is that step. Run it
  after editing any `.frag`.
- **Qt hands a `QColor` uniform over premultiplied.** Multiplying rgb by alpha again in the
  shader looks like the surface has quietly lost its colour: the tint goes dark and desaturated
  while still obviously being there. Cost an hour; written down so it costs nothing next time.

This is the same technique as caelestia's compiled `Caelestia.Blobs` plugin. Ours is a fragment
shader instead, which is the answer to "why not C++": the maths is identical, and a shader is
where per-pixel maths belongs anyway.

**Still to come:** caelestia's blobs also carry spring physics (`damping`, `stiffness`,
`deformMatrix`), so a panel squashes as it moves and settles. That is the next step, and the
field is what makes it possible.

---

## 11. What the services taught

Every menu reads the real machine. Quickshell ships bindings for PipeWire,
UPower, NetworkManager, bluez and MPRIS, so none of it shells out.

Three rules came out of writing them, and they are worth keeping:

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

**Still placeholder: nothing.** Every menu in the sidebar is live. Notifications
and the launcher (DESIGN.md sections 4 and 5) are the remaining capstones and
have not been started.

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
the screen's edge   d - gap - band   where the black corners begin
```

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
does, for this reason.

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

The touch-friendliness that follows is mostly free, and the rest is arithmetic:
targets meet WCAG 2.2 SC 2.5.8's 24px floor, and the drag threshold is 6px rather
than Qt's mouse-tuned 10, because a touchpad flick covers less distance than a
finger and should still commit.

**Do not use `drag.target` on an item whose `x` is bound.** Qt's built-in drag
assigns `x` imperatively, which destroys the binding and then fights whatever
re-establishes it; the card did not move at all. Track the pointer and drive the
offset instead, and keep the anchor in the PARENT's coordinates: `mouse.x` is
relative to the item that is moving, so as the card slides right by d, `mouse.x`
falls by d for the same physical pointer. `item.x + mouse.x` is the invariant.

---

*Relevant portable rules to re-read when building: `~/.claude/rules/animation-smoothing.md`
(exponential smoothing), `~/.claude/rules/math-over-hardcoding.md` (compute zones/positions),
`~/.claude/rules/g2-corners.md` (G2/squircle corners, never a plain radius),
`~/.claude/rules/type-scale.md` (at most three font sizes),
`~/.claude/rules/working-style.md` (just-try-then-iterate, preserve the distinctive style,
explicit line breaks). Memory pointer: `project-custom-shell-plan`.*
