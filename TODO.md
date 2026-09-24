# TODO

One step at a time. Each item gets looked at, understood, then handled —
not batched. Update this file as work happens: notes, decisions, and
done-marks go under the item they belong to.

- [ ] Settings menu
- [ ] Peak
- [ ] Media Viewer
  - 2026-09-24: empty state reworked — no MPRIS player at all now keeps the
    card's track layout in ghost tones instead of a collapsed card with a
    lone apology. "nothing is playing" is the headline; a music quip ("enjoy
    the silence", "the tape ran out", 60 in the book) rides beneath it as a
    quoted subtitle, rolled fresh per summon. No instruction line — the user
    was explicit. Chords strip only promises what works with no player
    (volume, mute, esc). Card widened 420 -> 560 so nothing wraps hard.
    Next: user is mid-thought about the small subtitles — item still open.
  - RULE from the user, standing: no small subtitles that do nothing but
    clutter. Every faint line must earn its place by doing work. Applies to
    the whole shell, not just this card.
  - Header is gone entirely (user: "just don't have a header") — the card
    opens straight onto the track, or onto the empty state's fact + quip.
    App name survives as the track's third line. Chords strip also removed
    (cheatsheet carries the binds). Empty card = ghost art, the fact, the
    quip. Nothing else.
  - Playing-state fix: Firefox/zen reports tracks with no length (and live
    streams never have one); position/0 clamped to "the end", pip jumped to
    the far edge, then the scrubber hid entirely. Media.progress is guarded
    and the Scrubber has a live shape now: full-width travelling wave,
    elapsed only, no pip/total/drag. Timed tracks unchanged (total shows,
    pip scrubs). Verified against the real zen-firefox bridge.
  - Title wraps to two lines (maximumLineCount 2, then elide) and the track
    block grows to its text — "The Greatest Episode Yet" reads whole now.
    Notch keeps its elide; it has no room.
  - Transport: spread-to-edges was REVERTED (user invoked Gestalt proximity,
    rightly — a skip at the edge groups with the edge, not the ring). The
    whole transport group now scales up on the card (zoom 1.4): width spent
    on presence, not distance. Notch/menu keep zoom 1.
  - Seek thrash fixed: zen bridge drops mpris:length mid-seek and reports
    stale positions; length now held per track, elapsed label rides the
    pip's smoothing, so end time and pip hold still through arrow presses.
- [ ] Notifications rehaul
- [ ] Sidepanel — simplified mode, and expand-mode changes
- [ ] Keybind previewer rehaul
