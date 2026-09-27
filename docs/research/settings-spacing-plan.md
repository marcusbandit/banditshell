# Settings spacing & type: implementation plan

Research base: `docs/research/spacing-systems.md`, `docs/research/proximity-grouping.md`,
`docs/research/typography-secondary-text.md` (all claims cited there). This file turns those
findings into ordered, concrete changes to `modules/settings/`. Nothing here is applied yet.

## The validated foundation (keep, don't touch)

| Choice | Verdict | Source |
| --- | --- | --- |
| 12 within groups / bigger between | The only citable proximity law is the inequality (related < unrelated); we satisfy it decisively | nngroup, lawsofux |
| Gutter 32 | Inside the official desktop range (Material 24dp, Fluent 24, Win11 Settings 56epx) | Atlassian "large" band starts at 32 |
| Rail 264 | Slightly under Windows NavigationView defaults (280–320) but in-band for a utility panel | learn.microsoft.com |
| Row 42 | Monocraft's exact line box is 24px (1.333 × 18), so a 42px row keeps 9px/side ≥ the 8dp floor | Material row formula |
| minTarget 24 | Clears WCAG 2.5.8 (24px) and Apple macOS minimum (20pt) | W3C, HIG |
| Whitespace-only grouping (no cards) | Common region is a fix for ambiguity, not a default; our 1:3 spacing + headers is unambiguous | nngroup common-region |
| Hairlines only inside repeating row lists | Already SettingsRow's behaviour | Polaris |

## The changes, in order

### 1. Rebase the spacing ladder onto 4px (the real fix)

The research's one hard criticism of our tokens: **6 and 36 exist on no published ladder** —
6 is not a multiple of the industry 4px base *nor* of our own 9px glyph grid (6 = 2/3 of 9,
land between cells); 36 sits between steps in Carbon/Atlassian/Polaris (all jump 32→40).

Proposed ladder (base 4, scale ×1/×2/×3/×4/×6/×8), with semantic bands per Atlassian:

| New tier | px | Band | Job |
| --- | --- | --- | --- |
| micro | 4 | small | icon-to-text inside text stacks, pixel-grid micro gaps |
| small | 8 | small | label→its control, header→first child of its group |
| normal | 12 | medium | blocks within a group, row horizontal padding |
| card | 16 | medium | padding inside cards, M3 card inner |
| large | 24 | large | component padding pairs, handover margin |
| page | 32 | large | group-to-group break, page gutter |

Blast radius: `Appearance.padding` is global. Two ways to go:

- **(a) Global rebase** — one change in `config/Config.qml` (`padding: base 4, scale [1,2,3,4,6,8]`)
  plus tier renames, then audit the whole shell for tier-role drift. Cleanest; touches everything.
- **(b) Settings-scoped** — keep the global 6/12/24/36; settings reads new settings-only tokens.
  No collateral, but now two ladders live in one shell, which is how drift starts.

**Recommend (a)**, applied in one commit, settings first, then the rest of the shell swept in
the same pass (the token names are the same everywhere; only the values move).

Consequence: 12/36 becomes 12/32 — ratio 1:2.67, still decisively above the 1:2 proximity floor.

### 2. Give every page group the same anatomy (the big structural one)

The NN/g asymmetry rule is mandatory and we half-violate it: on pages where the group label is
a bare child of the page column (Sound's "Output", "Input", ...), the gap above the label and
the gap label→card are BOTH the page spacing (32/36) — the header is equidistant and owns
nothing. KeysPage's `Section` component is already right.

Build one `SettingsGroup` component (heading, optional footer, body) and convert every page:

- gap above group (page spacing): 32
- heading→first child: 8 (small) — the 4:1 asymmetry the law needs
- optional footer text (Apple's grouped-list footer idiom): 12 below body, faint
- heading idiom: see §3

### 3. Group headers: pick one idiom (typography decision)

Sources allow exactly two header forms, and neither is "same-size, sentence-case, faint":

- **(a) Tracked-caps overline (recommended)** — 18px, UPPERCASE, `letterSpacing: 2px`
  (≈0.11em, on-grid), textFaint. Terminal-section idiom; matches the shell's pixel-font
  heritage. Record in DESIGN.md that caps here is a deliberate idiom choice (GNOME/Fluent
  discourage caps generally).
- **(b) Heading** — 18px at textDim or full text alpha, GNOME-Settings-shaped, caps-free.

Hard rule regardless of choice, from the typography research: **a header must never be dimmer
than the dimmest body text inside its own group** — today's faint header only survives if
secondary text is fainter still.

### 4. Codify secondary text as contrast, not vibes

- Define the faint tier as **0.60 alpha ≈ 6.8–7.3:1 on our surfaces** (Material's supporting-text
  mechanism: same size, alpha 0.60). Floor: nothing informative below **0.45 (4.5:1 WCAG AA)** —
  thin pixel strokes should exceed the norm, not sit at it. Below 0.45 is `textGhost`, for
  disabled/decoration only (Material's 0.38 disabled tier).
- Audit `material.label[]` weights in config against these numbers; if a tier falls between
  0.45 and 0.60, it either rises to 0.60 or drops to ghost. No third meaning.
- Secondary text stays **18px** (18→9 would be an unsanctioned 0.5× step; every system's
  smallest informative text is 11–12px+ and 9px Monocraft is decorative-grade). Under the
  label, 4–6px visual air, wraps to two lines, line box 24px. Values/controls sit BESIDE,
  right-aligned, never wrapping — already SettingsRow's shape.

### 5. Rows and cards, on the research numbers

- SettingsRow internals already match Material's list ratios (16dp-equiv horizontal padding at
  our 12; primary→secondary gap 4–6; hairline between rows). Keep.
- Card inner padding: 12 → 16 (`card` tier) wherever a G2Rect wraps content for its own sake
  (wallpaper current/preview cards). M3: 16dp inner, ≤8dp between sibling cards, filled-not-
  outlined emphasis.
- Row height: keep 42 (documented above). The standard-density alternative is 48; if rows ever
  feel cramped after living with it, 48 is the defensible bump — not today.

### 6. Rail, after the ladder moves

- Head: 32 above title (done), title→search 8, search→first group 8.
- Group labels in the rail get the §3 idiom and the §2 asymmetry (32 above, 8 below).
- Handover zone recomputes from the tokens (row 42 + margin 24 + breath 8).
- Mark: height stays 0.6 × row; its math reads `sizes.rowHeight` so it moves with any row change.

### 7. The verification ritual (per step, not at the end)

`banditshell restart && sleep 5`, close-then-open on DP-1, `grim -o DP-1`, zoom the crop, and
the **squint test**: group headers must still visibly own their group; secondary text must
still read; the rail's mark must be findable in one glance. Screenshot before AND after each
number change — this pass is mostly ±4px, exactly the size of change that's invisible in a
memory and obvious in a diff.

## Explicitly rejected (folklore, with sources in the research docs)

- "The ratio must be exactly 1:2.5" — untraceable.
- "Labels must sit 4–8px from fields" as a law — the documented forms are the inequality and
  the shipped-system numbers, not this.
- iOS "13pt section header" as an Apple-specified value — folklore; Apple publishes no numbers.

## Open decisions (ask before applying)

1. Ladder: global rebase to 4/8/12/16/24/32 (recommended) vs settings-scoped tokens?
2. Inter-group 36 → 32? (Recommended; 32 is citable in all three ladders, 36 in none.)
3. Header idiom: tracked caps overline (recommended) vs plain heading?
4. Card padding 12 → 16 where cards exist? (Recommended, M3.)
