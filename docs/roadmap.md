# banditshell roadmap

## Where it is going

One shell that feels natural from whatever is in your hand. Today that is a
keyboard, a mouse, a pen tablet, a touchscreen and a touchpad. Later it is
voice and bare hands. Everything answers at once, moves only to teach where
things live, and leaves the way it came.

## The design system: six rules every input shares

1. **Every action is an intent with a stable name.** Keys, pointer, pen,
   touch, touchpad, voice and hands are only ways to fire intents. Nothing may
   be reachable from one input alone. This builds on the 122 stable action ids
   in `api/actions.tsv` from the audit branch, draft PR #44.
2. **Everything lives at an edge or grows from a source.** Pull it from that
   edge, click its home, or press its key to summon it. The music card's home
   is the island. Push it back toward the edge, or press Esc, to put it away. The same direction works for mouse, pen, finger and
   touchpad. No pointer can overshoot a screen edge, so the edges carry the
   surfaces used most.
3. **Hover is a bonus, never a requirement.** Touch has no hover, and a pen
   only has it while it is near the tablet. Every hover reveal has a press or a
   tap that does the same.
4. **Targets scale with the input.** The mouse minimum is 24 px, the WCAG 2.2
   floor, set in `control.minTarget`. Pen and touch get larger. Density follows
   the last input you used, not a setting. That part is not built yet.
5. **Direct manipulation is 1:1.** While a finger, pen or cursor holds
   something, it moves exactly with it. Any motion can be grabbed mid-flight
   and stopped or reversed. Two curves cover the rest. Ease-out, by exponential
   smoothing, answers an input. A critically damped ease-in-out, with no
   bounce, moves something already on screen somewhere new.
6. **Snappy, with no play for now.** A hotkey opens a surface instantly, with
   no animation, and a hotkey or Esc closes it just as fast. A pull or a click
   shows up in the first frame and settles in about 200 ms, with no extra
   stages. Nothing overshoots or bounces, rare moments included. Reduced motion
   means no motion at all, fades included. What the motion meant stays as a
   colour, a state or a still mark.

Rules 5 and 6 come from DESIGN.md section 15, "Drag before click", and
section 2.5, "Motion: animate to teach, never to decorate", tightened by my
motion calls of 18 October. Section 2.5 sits on branch `design-motion-rules`
(commit fe484bf) and is not merged yet.

## Inputs

| Input | Role | Today | Next |
|---|---|---|---|
| Keyboard and mouse | Main | Everything works. | A parity check across every surface. A visible focus ring everywhere. |
| Keyboard alone | Full control | The launcher, Settings and the file browser run from the keyboard. Everything else is a bind or an IPC call. Menus only take Esc. | Every surface opens and closes by key. Arrow keys in menus. One focus model across surfaces. |
| Mouse alone | Full control | Screen edges, the sidebar, the island and menus. Right-click or hold opens a menu on tray icons, launcher rows, clipboard rows and files. | Right-click or press-and-hold reaches what only keys reach today. |
| Pen tablet, screenless, on the desk | Replacing the mouse, for the wrist | PenMap maps the tablet to one screen, all screens or a window. PenOverlay lets you drag and resize that area on screen. PenButtons remaps the two side buttons to right click, middle click or erase. | Pen buttons open the launcher and a radial menu of top intents. Hover dwell tuned for pen jitter. Text and confirm without a keyboard. |
| Touchscreen, laptop | Secondary | Finger-sized edges (`control.touchEdges`) widen the island and quick controls strips. Drag a window up from the bottom edge. The on-screen keyboard shows in tablet mode. | Bigger targets in touch mode. No hover-only paths. An edge swipe for every edge surface. |
| Touchpad, laptop | Secondary | A two-finger scroll is a swipe. Anything that answers a drag answers two fingers the same way, through ScrollGesture. | Three- and four-finger swipes in the same directions as edge pulls. |
| Voice, later | Accessibility, text without keys | gvoice dictation types into the focused window. The island shows that you are dictating, with a level ring. | Voice commands that fire intents: "open settings", "hide notifications". |
| Hands by camera, later | VR-style pointing | Nothing yet. | The index finger is the pointer, a pinch is a press, a swipe is a pull. Same intents, same edges. |

## Keyboard-light desktop, pen first

Goal: a working day with the pen in hand and the keyboard only for long text.

- Pen side buttons: one opens the launcher, one opens a radial menu of the
  most-used intents. Today they can only become right click, middle click or
  erase.
- Every edge surface opens by pulling from its edge with the pen. That works
  today for the launcher, the island, the notification tray and the calendar.
  Menus, quick controls and Settings open on click or hover, so they need a
  pull too.
- Text: dictation first, the on-screen keyboard as the fallback, and a
  launcher that takes voice.
- Confirm and cancel without keys: tap to accept, push back to cancel.
- Wrist budget: count key presses per feature for a week, then remove the top
  ten.

## Now (in flight)

PR #53, on branch `motion-fixes`, carries the motion work. Built on the branch
so far:

- **Island notifications go back up.** Push them up to hide them all. They
  stay in history.
- **Lock hold.** The power buttons need the full hold again with reduced
  motion on.
- **Launcher exit.** It sinks back into the bottom edge instead of shrinking
  to its centre.
- **Tooltips.** Once one is open, its neighbours show at once.
- **Controls.** Toggles, sliders and chevrons stop bouncing.
- **Loops.** Reduced motion stops them, and what they meant stays visible.

Being built now, from my motion calls of 18 October:

- **No play for now.** Every other overshoot and bounce goes too, rare
  moments included.
- **Hotkeys are instant.** A surface opened by a hotkey appears with no
  animation, and a hotkey or Esc close is instant too. A pull from its edge or
  a click on its home still brings it out of its origin, and the gesture
  follows the finger 1:1.
- **Two curves.** Ease-out, by exponential smoothing, for anything that
  answers an input. A critically damped ease-in-out, with no bounce, for things
  already on screen that move somewhere new.
- **Reduced motion is no motion.** Fades go too.
- **The workspace slide.** It leaves my Hyprland config and becomes a
  banditshell Settings row, at most 250 ms.

Also in flight:

- **PR #52, spatial fixes.** Clipboard paging, the peek highlight, quick
  controls and the session menu centred, Settings panes matched to the mockup.
- **Branch `design-motion-rules`.** DESIGN.md section 2.5, "animate to teach,
  never to decorate". No PR yet.
- **Draft PR #44, the full audit.** A stable bind API, notifications in the
  launcher, island moments, module boundaries. It stays off main until I make
  the five calls it lists.

## Next (decided, not built)

- One text edge in menus and the island overview. Rows hang their highlight
  outside the text column, the way Settings does.
- One row height for menu rows. MenuRow comes out at 44, a 20 px icon plus
  its padding, while the row token says 42.
- DESIGN.md's spacing bands rewritten to the Settings mockup: icon to label
  12, heading to rows 8, gap between groups 16. Section 12 says 8, 8 and 32
  today.
- Same part, same size. The notification card is 440 wide with 16 padding on
  the island and 376 with 12 in the tray. Tooltips, keycaps and text fields
  differ the same way. The sidebar's status and tray slots are 29 px, its
  workspace slots 32.
- Grab anything mid-motion. Every moving surface can be caught mid-flight and
  stopped, the way Apple's can.
- An input parity matrix: for every surface and every input, how you summon
  it, move in it, act and dismiss.

## To decide

- Settings unrolls out of the sidebar on the left, but you summon it from the
  bottom-right corner. Grow it from the corner, or move the corner.
- Notifications arrive two ways: dropping from the top in the island, or
  sliding in from the right edge in the corner tray. Pick one route.
- The corner tray goes back on a push to the right. Should a swipe up hide it
  too, like the island? Draft PR #44 deletes the tray and keeps history in the
  launcher, which would settle it.
- With the stream bar on, a menu opened from it drops from the top. From the
  sidebar the same menu unrolls sideways.
- The lock screen calls a password wrong if PAM has not answered in 300 ms,
  and counts it as a failure. Slow machines will hit that. A late yes still
  unlocks.

## Later

- Voice commands that fire the same intents.
- Hand tracking through the camera.
- Touch mode: density that follows the last input.
- Playfulness again, tuned on purpose.
- Springs, once the two curves are in.
