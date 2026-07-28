# myshell - Design Document

> A from-scratch desktop shell to eventually replace caelestia.
> Written 2026-07-28 as a reference. **Nothing is being built yet** - this is the
> captured plan and philosophy to return to when work actually starts.

Why this exists at all: caelestia is finished and excellent, but building it myself is
the point. I want to be proud of my system and understand how the *entire* thing works.
The constant urge to tweak caelestia is the tell that I'd rather own the whole mental
model than live in someone else's. This document is so that intent survives the gap
between now and whenever I actually start.

---

## 0. How I want AI to help (hard rule for this project)

**I type the code myself.** I want AI assistance, but I write every line. This is
non-negotiable for myshell specifically, because the entire point is understanding my own
system - and I can't understand code I didn't write.

So the assistant's role here is:
- explain how things work, sketch approaches, point at the right Quickshell/QML/DBus/Hypr APIs
- debug, review, rubber-duck the design, answer "how / why" questions
- write pseudocode or tiny illustrative snippets *to teach a concept*, not to be pasted in as
  the implementation

The assistant's role here is **NOT**:
- writing the widgets / files for me
- producing paste-ready implementations of the actual shell
- editing myshell source files on my behalf

If in doubt: hand me the understanding, let me type the code.

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

The thin border caelestia always draws around the screen: I'm not a fan. I may keep an
**invisible interaction region** (a hit-target ring / edge zones) for summoning things, but
it must be **fully transparent until interacted with**. The border can exist as a mechanism;
it must not exist as decoration-at-rest.

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
- Persistence/state store for notifications (Tier 4) and saved networks/devices.
- How much goes in **C** vs QML (start pure QML; drop to C only where measured need appears).

---

*Relevant portable rules to re-read when building: `~/.claude/rules/animation-smoothing.md`
(exponential smoothing), `~/.claude/rules/math-over-hardcoding.md` (compute zones/positions),
`~/.claude/rules/working-style.md` (just-try-then-iterate, preserve the distinctive style,
explicit line breaks). Memory pointer: `project-custom-shell-plan`.*
