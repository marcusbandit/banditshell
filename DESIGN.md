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

Animation implementation for all this motion/summon/tracking: **exponential smoothing, always**
(see `~/.claude/rules/animation-smoothing.md`) -
`position += (target - position) * (1 - Math.exp(-speed * dt))`. Moves fast when far, settles
gently when close, safe at any dt.

**This is a rule, not a default.** Anything in this shell that moves, tracks, reveals, resizes
or follows goes through `components/Follow.qml`. A `NumberAnimation` or a `Behavior` on a
position is a bug, with exactly one exception: a **looping clock** with no target being chased
at all (the mic indicator's processing ripple and typing caret are the whole list). Spring and
bounce are not in this shell.

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
  - **A PICTURE cannot go through the primitive, so it is masked by one.** An image is a
    texture, not a path, so album art or a notification's thumbnail dropped into a rounded
    plate keeps its own square corners over the plate's curve, a pixel away from a G2 corner
    for comparison. `components/G2Image.qml` renders the picture to a texture and lets a
    G2Rect of the same size eat it. Same shape, applied differently.
  - **An OUTLINE is allowed on a control, never on the body.** `G2Rect` grew a stroke for the
    transport's play ring. The old "fill only" rule was about the chassis: a hairline on a
    contour that joins another shape reads as a seam through one object. A ring around a
    button joins nothing, and it is how to give a control a boundary without a solid fill.
    It is stroked INSIDE the item's bounds, because a ring is laid out as a target.
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
│   ├── G2Rect.qml               the ONE rounded-rect primitive; fill and/or outline
│   ├── G2Image.qml              a picture cut to that same corner, by mask
│   ├── CornerWedge.qml          a corner's leftover; rounds off the screen corners
│   ├── blob/
│   │   ├── blob.frag            the chassis as a signed distance field
│   │   ├── blob.frag.qsb        compiled; rebuild with `banditshell shaders`
│   │   └── BlobField.qml        the ShaderEffect that draws it
│   ├── AppMark.qml             one window's mark, from a spec: symbol/glyph/mono/image
│   ├── Follow.qml               a value that chases a target by exponential smoothing
│   ├── Pull.qml                 a directional swipe; the way in, and back out, that needs no hover
│   ├── ScrollGesture.qml        two fingers on a touchpad, delivered as that same swipe
│   ├── GlideList.qml            a list that scrolls by pixels and coasts when let go
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
│   ├── highlight.js             what language is this, and where are its tokens
│   ├── CodeBlock.qml            that, coloured from the theme, one delegate per
│   │                            line so a 60,000-line paste costs 30 of them
│   ├── Tooltips.qml             what is hovered and what it says; one, shell-wide
│   ├── PasswordField.qml        inline secret entry
│   ├── QrScanner.qml            the camera, and whatever code it finds; needs
│   │                            zxing-cpp's `ZXingReader` on PATH to decode
│   └── QrCode.qml               the same square the other way round: a string as
│                                a card, ink on paper, every module a G2 corner
│                                that asks its neighbours; needs `qrencode`
├── services/                    state that outlives any one widget
│   ├── Hypr.qml                 Hyprland IPC -> clean workspace state
│   ├── Tray.qml                 StatusNotifierItem host: what runs without a window
│   ├── AppIcons.qml             what each app looks like: seen, picked, suggested
│   ├── Audio.qml                PipeWire: sinks, sources, volume, mute
│   ├── Battery.qml              UPower
│   ├── Network.qml              NetworkManager: wifi, one entry per SSID
│   ├── Bluetooth.qml            bluez: adapter and devices
│   ├── Media.qml                MPRIS, with a stable choice of player
│   ├── SysInfo.qml              /proc and /sys: cpu, memory, temperature
│   ├── Wallpaper.qml            the current wallpaper and the list to pick from;
│   │                            what kind each file is, and a poster frame per video
│   ├── Notifs.qml               the notification DAEMON (a server, not a reader)
│   ├── AppNotifs.qml            the index over it: which application each one
│   │                            came from, so a launcher row can carry its own
│   ├── Usage.qml                when this machine was awake, kept for the calendar
│   ├── Apps.qml                 desktop entries, and ranked search over them
│   ├── Clipboard.qml            what has been copied, and what each of them IS;
│   │                            runs its own wl-paste watcher, because the type
│   │                            list is the only place "file" differs from "text"
│   ├── Settings.qml             the settings page's state, and its handover
│   ├── Power.qml                the ways a session can end, and how each is done
│   ├── Calc.qml                 arithmetic, once: how a number is written, what an
│   │                            operator does, and what a TYPED expression means.
│   │                            Two inputs onto one question, so they cannot
│   │                            disagree; the keypad's own state is not here
│   ├── Lock.qml                 whether the screen is locked, and what decides it
│   ├── Tablet.qml               whether the machine is FOLDED OVER. The changes
│   │                            come from the compositor (a switch bind execs
│   │                            the CLI); the state at startup comes from
│   │                            scripts/tablet-state.py, and is allowed to fail.
│   │                            Also owns `docked`, which FrameExclusions reads:
│   │                            an exclusive zone belongs to a one-edge surface
│   │                            and the board is drawn in the four-edge one, so
│   │                            the two ends need one answer between them
│   ├── Keystrokes.qml           the one service that types OUTWARD, and it needs
│   │                            TWO transports: wtype for characters (the
│   │                            compositor never acts on them, so no bind can
│   │                            fire) and ydotool for chords (a real uinput
│   │                            keyboard, so SUPER+1 works). Queued so two
│   │                            cannot race. NOT named `Keys`, which is QML's
│   │                            own attached type and would shadow every
│   │                            Keys.onPressed in the repo
│   └── Shell.qml                which ShellWindows exist
├── modules/                     actual shell UI
│   ├── ShellWindow.qml          THE surface: everything visible, all the input
│   ├── Chassis.qml              the band + sidebar as ONE shape
│   ├── FrameExclusions.qml      invisible; reserves the room the chassis occupies
│   ├── Ipc.qml                  the control surface the CLI talks to
│   ├── Tooltip.qml              the one tooltip, drawn wherever it was asked for
│   ├── TopNotch.qml             summon zone: cursor to top-centre -> the time descends
│   ├── media/
│   │   ├── MediaPreview.qml     what is playing, Niagara's block, under the time
│   │   └── MediaTransport.qml   the ONE set of media buttons: a ring and two glyphs
│   ├── VolumeRail.qml           scroll the right edge; a pill three glyphs tall answers
│   ├── MicIndicator.qml         dictation, while the microphone is actually open
│   ├── SettingsCorner.qml       the bottom-right corner as a way in: hover, press, or pull
│   ├── WallpaperWindow.qml      background layer, below every window; two slots
│   │                            that cross-fade, motion only on an empty workspace
│   ├── launcher/                grows out of the sidebar; the one keyboard grab
│   │   ├── Launcher.qml         which of the two concepts is live; forwards to it
│   │   ├── ListLauncher.qml     a search field over everything installed
│   │   ├── NiagaraLauncher.qml  text before icons; the alphabet on a rail.
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
│   ├── lock/                    the lock: one compositor surface per screen, one face
│   ├── cheatsheet/              the hotkey sheet, read off hyprctl on every open
│   │   ├── CheatSheet.qml       the card, the two view choices, and the way out
│   │   ├── BindList.qml         every bind there is, grouped by how it is pressed
│   │   ├── KeyBoard.qml         the same binds, on the keys your hands know
│   │   ├── KeyCap.qml           one key: a width in units, a legend, a state
│   │   └── Chord.qml            one chord, in whichever vocabulary is being spoken
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
│   │   └── WallpaperPicker.qml  a strip of big cards you throw; the centred one
│   │                            is on the real desktop while you decide about it
│   ├── picker/                  screenshot: hover a window or drag a region
│   ├── settings/                the page that is a shell surface OR a window
│   │   ├── SettingsFace.qml     the card; a plain Item, drawn by both of the below
│   │   ├── SettingsPanel.qml    the shell's copy, in ShellWindow, centred in the hole
│   │   ├── SettingsFloat.qml    the window's copy; shell-wide, hidden until pulled out
│   │   └── pages/               one file per page; Settings.pages is the register,
│   │       │                    and key "icons" loads IconsPage.qml by convention
│   │       ├── IconsPage.qml    what each app looks like; grew out of the settings
│   │       │                    gauge's old menu (a place, not a glance, so it left the bar)
│   │       └── AppearancePage.qml  which palette the shell wears, and the two
│                               switches a wallpaper has (WHICH one is the picker's)
│   ├── notifications/           discrete cards; NOT part of the blob field
│   ├── menu/
│   │   ├── Menus.qml            which menu is open, where it sits, when it closes
│   │   ├── MenuPanel.qml        one panel: geometry and contents, NOT a shape
│   │   └── content/             one file per menu, all reading the real machine
│   │       ├── SoundMenu.qml    NetworkMenu.qml   in the bar: the four gauges
│   │       ├── BluetoothMenu.qml BatteryMenu.qml
│   │       ├── CalendarMenu.qml a month; the clock's date is its opener
│       ├── CalculatorMenu.qml the keypad. A menu BODY, so the panel above and
│       │                    a menu are one object; the answer stays on the line
│   │       ├── MediaMenu.qml    SystemMenu.qml    parked for the dashboard,
│   │       ├── PowerMenu.qml    NotificationMenu.qml   not reachable from the bar
│   │       ├── TrayMenu.qml     one tray item: what it says, and "show it"
│   │       └── TrayEntries.qml  its own menu, off the bus. CONTAINS ITSELF
│   └── sidebar/
│       ├── Sidebar.qml          layout of what sits in the chassis's left band
│       ├── Clock.qml            stacked HH / mm / date; the date opens the calendar
│       ├── Workspaces.qml       picks which workspace style the sidebar wears
│       ├── WorkspaceModel.qml   the column's layout + motion, shared by all of them
│       ├── WorkspacePlates.qml  style: index tabs, length as state (`plates`/`icons`)
│       ├── WorkspaceMap.qml     style: a bar per window, as long as the window is wide
│       ├── WorkspaceBlocks.qml  style: one square per window, on the pixel grid
│       ├── StatusIcons.qml      the status section, rendered from data
│       ├── StatusIcon.qml       one indicator, service-agnostic
│       ├── TrayIcons.qml        the tray, at the TOP: what runs without a window
│       └── TrayIcon.qml         one of them; StatusIcon's drawing, three buttons
├── scripts/
│   ├── palette.py               a wallpaper's dominant colours
│   ├── tablet-state.py          is the hinge folded RIGHT NOW: the one question
│   │                            that needs an ioctl, so it needs a process.
│   │                            Prints `unknown` without the `input` group, and
│   │                            that is the correct failure
│   └── clip-record.sh           one clipboard event, as one line of JSON: the
│                                MIME types, and the bytes when they are not text
├── bin/
│   └── banditshell              the CLI (linked into ~/bin)
└── docs/
    └── hyprland-binds.example.conf   the CLI as keybinds: a worked set to copy
```

Import paths: Quickshell exposes the config root as the module `qs`, so a directory is
`import qs.components`, `import qs.services`, `import qs.modules.sidebar`. There are no
`qmldir` files to maintain; Quickshell generates them.

**Configuration: no magic numbers, anywhere.**

`Config.qml` owns `~/.config/banditshell/config.json`. Edit it and the shell follows live; delete
it and it is rewritten from the defaults. The `defaults` object in that file *is* the schema:
a key not in it is not a setting, and a key in it always resolves, so a half-written config
still boots. `Config.set("sidebar.width", 90)` writes and persists, which is the entire API the
settings panel needs, and now uses: its pages (modules/settings/pages/) are drawn over exactly
this call.

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
the left edge the way `TopNotch` already does at the top.

## 9. Driving it from a terminal

`bin/banditshell` (linked into `~/bin`) wraps a Quickshell `IpcHandler`.

It exists because **menus open on hover, and hover is impossible to assert**. You cannot script
a cursor into a corner and check what happened, so the gesture and the thing it opens have to
be separable. Every menu is reachable by name, which means a change to a panel can be checked
without reproducing the gesture, and a change to the gesture can be checked against a panel
already known to work.

```
banditshell start|stop|restart|run|log
banditshell menu list|open <key>|close|toggle <key>|current|hover
banditshell launcher toggle|open|close|scrub <0..1>
banditshell clipboard toggle|open|close|list|use <n>|pin <n>|remove <n>|clear|status
banditshell session toggle|open|close
banditshell settings toggle|open [page]|close|page <key>|pull|put|status
banditshell notifications toggle|open|close|clear|status
banditshell notch toggle|open|close|status
banditshell hotkeys toggle|open|close|status
banditshell calendar               sugar for `menu toggle calendar`
banditshell volume up|down [n]|set <pct>|mute [on|off]|status
banditshell lock [status]          one direction; `loginctl unlock-session` is the way back
banditshell picker open|freeze|clip|freezeclip|close
banditshell wallpaper toggle|on|off|next|prev|status
banditshell wallpapers toggle|open|close|status   the picker; the edge's second swipe
banditshell status                 what the shell thinks the compositor said
banditshell theme [name] | themes
banditshell get <key> | set <key> <value>
banditshell shot [file]
banditshell demo <key>             open, screenshot, close
banditshell lockpreview            the lock screen's look, without the lock
banditshell shaders                recompile components/blob/*.frag
```

A CLI open is always a **pinned** open. Nobody driving a terminal has a pointer resting on
anything, so an unpinned menu opened from here would be taken away by the grace timer a fifth
of a second after the command printed `open`.

The newer targets each follow a rule already stated elsewhere rather than inventing one.
`notifications` and `notch` write the **pin** and nothing else: presence on both is a derived
union (section 15), so a keybind and a hand land in the same state and leave by the same doors.
`settings` drives the service rather than any window, because the page can be held by a real
window instead of the shell; `open` takes an optional page, and `page` switches it without
touching presence, so a keybind can walk the panel while it stays put. `volume` moves by the
same configured step the wheel and the sound menu's slider use, so a keybind is the same
control rather than a second one. `calendar` is sugar for `menu toggle calendar`: the calendar
is an ordinary menu registered in the sidebar, and the thing you bind to a key deserves a
shorter name than the thing it is implemented as. `docs/hyprland-binds.example.conf` is a
worked set of Hyprland binds onto all of it.

`wallpaper` is the one target whose whole job is **reading before writing**. Every verb on it
is a write to `config.json` that `set wallpaper.enabled` or `set wallpaper.current` could make
by hand, so on the face of it the target is redundant; what a key cannot do is ask for the
opposite of a value it has not read, or the next one along a list. `toggle` and `next` are
those two questions, and the rest are there so the target answers the whole thing rather than
only the halves a hotkey needs. Turning it off is a **light going out, not a surface going
away**: the window stays, the images keep their sources, `current` keeps its path, so what is
left is the black `WallpaperWindow` was already painting behind the picture and coming back is
a fade rather than a decode. The lock screen follows the same flag, because its ground is made
of this same picture and `LockSurface` is black underneath it.

`wallpapers`, plural, is the picker, and it is a **surface** rather than a setting: everything
on it opens and closes something on the screen and writes nothing, where everything on the
singular target writes something and draws nothing.

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
toward with `wallpaper next`, the middle for a keybind that has no place on the screen. That is
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
opens recites the user's own config rather than the shell's state, so it is drawn from
`hyprctl binds -j` on every open and there is no gauge, edge or gesture that could summon it;
the keybind is the control, and it has to keep working across a config the shell never sees.
`status` therefore prints what the sheet *read* rather than whether it is up, because the
failure this panel actually has is a screen of chords with nothing beside them, and from a
screenshot that looks identical whatever caused it: a bind registered from Lua or a plugin is
reported with no dispatcher this side can read, which is the compositor declining to say and
not the shell failing to parse. Binding it is the one bind with a trap in it, because `?` is a
shifted character and which physical key it is shifted from is a property of the keyboard
LAYOUT: `SHIFT + slash` on US, `SHIFT + plus` on Danish, and Hyprland says nothing at all about
a key name it cannot resolve, it simply never fires.

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
- **A rebuilt `.qsb` needs the PROCESS restarted, not a QML reload.** Qt caches the compiled
  shader program by URL for the life of the process, so `banditshell shaders` followed by the
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

This is the same technique as caelestia's compiled `Caelestia.Blobs` plugin. Ours is a fragment
shader instead, which is the answer to "why not C++": the maths is identical, and a shader is
where per-pixel maths belongs anyway.

**Still to come:** caelestia's blobs also carry spring physics (`damping`, `stiffness`,
`deformMatrix`), so a panel squashes as it moves and settles. That is the next step, and the
field is what makes it possible.

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
  so `banditshell set apps.icons '[...]'` can never arrive as an array. `Config.merge` grew the
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
UPower, NetworkManager, bluez and MPRIS, so none of it shells out.

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
empty line. `services/NotifEntry.qml` copies the content at arrival and re-copies
it whenever the live object changes, keeping the handle itself only for talking
back to the sender, so a notification whose sender dies simply stops updating.
**A sender's death is not the shell's amnesia.**

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

**And the other direction is the opposite decision, not a second dismissal.** A
notification card is dragged *right*, out through the edge the tray hangs off, to
throw it away, and *left* to **pin** it. Pinning stops the countdown and buys the
notification one dismissal's worth of protection: thrown away afterwards it only
leaves the *screen*, and it is still in the hub when you go looking. A press and
hold pins it too, because a finger has no other way of saying "I am reading this",
and a swipe left again takes the pin back off.

The two gestures differ by direction alone, so the card has to say which one is
happening before you let go: a rightward pull fades the card out, a leftward one
deliberately does *not*, and the pin's own mark rides in with the pull so it is
fully drawn exactly at the commit line. A dismissal that looked identical to a
keep until the instant it committed would be a coin toss with a hand on it.

In the hub the pin means nothing, and a swipe there forgets. The hub is where a
pin was keeping the notification in the first place; honouring one there would
answer a deliberate swipe by putting the row straight back.

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
notch and its push-back, the notification tray both ways, both launcher panels,
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
`GlideList`'s coast already does for the identical question, under a floor of
fifty milliseconds that no setting can get below: every duration in this shell is
a tier off `anim.base`, `banditshell set anim.base 0` is accepted as written, and
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
drag of its own owns it twice over. The Niagara launcher's alphabet rail was the
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
notch's pull-down and its push-back, the notification tray's corner and its push,
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
StatusNotifierItem protocol and is not ours to reinterpret. The Niagara
launcher's alphabet rail is the same case as the bead, one level up: it scrubs
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
notification tray back up into its own, the launcher back down into the bottom
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
sheet, a pinned menu, a pinned notification tray and a pinned notch, and it has
to hold for the routes that have no pointer in them at all, because a keybind
running `banditshell notch open` leaves the cursor resting on somebody else's
window.

**Pinned is the whole set, and hover is deliberately not in it.** A tray the
cursor is merely resting in is closed by the cursor leaving; it needs no key, and
giving it one would cost far more than it saves. A layer surface receives no keys
at all unless its window asks the compositor for them, and asking is not free:
while the shell holds the keyboard the window underneath does not, so a shell
that took it every time a pointer crossed a corner would be swallowing somebody's
typing on behalf of a panel they never asked for. A pin is somebody having said
so, and it is the one state that does not expire, which is exactly what makes it
the set worth spending the keyboard on. The grab lasts precisely as long as the
pin, and not one moment longer.

The honest cost is that a pinned tray or notch left up while you go back to
typing swallows the keystrokes, and clicking the other window does not win the
keyboard back, because an exclusive layer surface keeps it. Asking for keys only
once the shell has been CLICKED is the alternative, and it is rejected for being
dead in the case the rule exists for: a panel summoned by a keybind has never
been clicked, so Escape would do nothing until you had gone and touched the very
thing you were trying to get rid of. What is left is a grab that is always
visible on screen and has four ways out: Escape, the corner or strip that
summoned it, the summoning gesture reversed, and the CLI.

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

Three things fell out of owning the recorder that could not have been retrofitted:

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

The existing clipse history is imported once, and the pictures are **copied**
rather than referenced. Referencing them in place was the obvious thing and it is
wrong: it would leave a third of the imported history owned by the tool being
replaced, so `clipse -clean`, whose whole job is reaping exactly those files,
would quietly empty twenty-eight rows of history months later. Importing means
taking a copy, or it is not importing.

The honest cost is a second watcher on the session if the old manager is left
running. That is harmless (both see every selection, neither can disturb the
other's store) and it is why `clipboard status` reports whether this one is
actually recording: a history that has quietly stopped growing looks exactly like
an afternoon in which nothing was copied, and it is the one failure the panel
itself cannot show.

---

*Relevant portable rules to re-read when building: `~/.claude/rules/animation-smoothing.md`
(exponential smoothing), `~/.claude/rules/math-over-hardcoding.md` (compute zones/positions),
`~/.claude/rules/g2-corners.md` (G2/squircle corners, never a plain radius),
`~/.claude/rules/type-scale.md` (at most three font sizes),
`~/.claude/rules/working-style.md` (just-try-then-iterate, preserve the distinctive style,
explicit line breaks). Memory pointer: `project-custom-shell-plan`.*
