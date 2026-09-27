# Proximity grouping: spacing, cards, and group headers in settings UIs

Research pass for the banditshell settings panel (1280×820, left nav rail, content pane of
grouped cards/rows). Question: what does the literature and design-system practice actually say
about spacing within vs. between groups, group-header treatment, and cards vs. whitespace-only
grouping?

Method: primary pages were fetched and read in full (NN/g articles, Laws of UX, Material 3 specs
via reader proxy, Apple HIG via the developer docs JSON API, AOSP settings guidelines, libadwaita
docs, A List Apart, Europe PMC for perceptual research). Claims are cited inline by URL. Where a
popular "rule" could not be traced to a primary source, that is recorded explicitly — this report
distinguishes *measured/specified numbers* from *practitioner folklore*.

---

## TL;DR — the laws, with numbers where numbers exist

1. **Proximity is an inequality, not a fixed ratio.** Items near each other are perceived as one
   group; items spaced apart are perceived as separate groups. The derived rule is directional:
   *space between related items must be clearly smaller than space between unrelated items*
   — every source states the inequality; none of the primary sources states a mandatory ratio.
   (nngroup.com — /articles/gestalt-proximity/)
2. **The popular multipliers (1:2, 1:2.5, 1:3) are practitioner folklore, not measured law.**
   I could not trace them to a primary source in this pass. They are consistent with the
   inequality and with shipped design systems; treat them as heuristics, with 1:2 as the floor
   and 1:3 as a comfortable target. (See §5.2 for what could and couldn't be verified.)
3. **A header belongs to the group below it.** NN/g: text "from the corresponding section is
   usually placed closer to the heading than the text from the preceding section" — i.e., the
   gap above a group header must exceed the gap between the header and its first child.
   (nngroup.com — /articles/gestalt-proximity/)
4. **Common region (a card) is the strongest grouping cue and overpowers proximity and
   similarity** — use it when whitespace alone cannot make the grouping clear, not as a
   default decoration. (nngroup.com — /articles/common-region/, citing Palmer 1992)
5. **Prefer whitespace-only grouping; containers add clutter and "false floors."** NN/g
   explicitly warns that borders "aren't necessary" when proximity suffices, and that
   full-width blocks can stop scrolling because the page looks finished.
   (nngroup.com — /articles/common-region/)
6. **Material 3 ships a hard number for card gaps: "padding between cards: 8dp max."** Card
   padding is 16dp left/right, radius 12dp. (m3.material.io — components/cards/specs)
7. **Material 3 list rows are tight inside a group:** item heights 56/72/88dp, 16dp leading /
   24dp trailing padding, **0dp** padding above/below dividers, 48dp minimum target.
   (m3.material.io — components/lists/specs, overview)
8. **Android platform Settings: dividers cluster, not separate.** Dividers are used to *bind a
   group* of related settings; a group heading should always be paired with a divider; footer
   explanatory text is separated by a divider; >10–15 items per screen is overwhelming.
   (source.android.com — devices/tech/settings/settings-guidelines)
9. **Apple's grouped lists express grouping as headers + footers + additional space, and
   Apple publishes no pixel values.** Inset grouped = "grouped sections … inset with rounded
   corners." (developer.apple.com — HIG lists-and-tables; UIKit groupedHeader())
10. **GNOME/libadwaita's settings pattern is a "PreferencesGroup": a title + description riding
    above a visually boxed list of rows** — i.e., the desktop-Linux canon pairs a header with a
    contained list, with an option to split rows into separate boxes.
    (gnome.pages.gitlab.gnome.org — libadwaita Adw.PreferencesGroup)
11. **Grouping by proximity is bistable and hysteretic in perception research** on dot lattices:
    small changes in distance flip perceived grouping, and the perception persists briefly
    (hysteresis) — spacing decisions are perceptually "sticky," so get the inequality clearly
    right rather than marginally right. (Moazzen et al. 2025, Sci Rep, PMC12705819)
12. **Whitespace is itself the hierarchy device:** macro whitespace (between groups) vs. micro
    whitespace (within groups) is the standard vocabulary, and adding macro whitespace around an
    element is an emphasis/structuring act. (Boulton, A List Apart — /article/whitespace/)

---

## 1. Gestalt proximity and common region: originals and modern UX form

### 1.1 The law

- Laws of UX (Law of Proximity): "Objects that are near, or proximate to each other, tend to be
  grouped together." Takeaways: proximity "helps establish a relationship with nearby objects";
  elements in close proximity "are perceived to share similar functionality or traits"; it helps
  users "understand and organize information faster." Origins: the principles of grouping were
  first proposed by the Gestalt psychologists (Proximity, Similarity, Continuity, Closure,
  Connectedness), tied to Prägnanz.
  https://lawsofux.com/law-of-proximity/
- NN/g (Aurora Harley, Aug 2020): "Principle of proximity: items close together are likely to be
  perceived as part of the same group — sharing similar functionality or traits." Key additions:
  - Proximity "can overpower competing visual cues such as similarity of color or shape."
  - "Using varying amounts of whitespace to either unite or separate elements is key."
  - Headings: "the text from the corresponding section is usually placed closer to the heading
    than the text from the preceding section" — the quantitative asymmetry behind "space above a
    header must exceed the space below it."
  - Forms: related fields grouped by whitespace make a 15-field form read as 3 short forms;
    "a minimal amount of spacing between a top-aligned label and its corresponding form field
    makes that relationship apparent compared to a larger margin before the next label-field
    pair."
  - Far-away elements are overlooked ("tunnel vision"); users "only look at one item within a
    perceived grouping and use that to make a judgement about what the other items in that group
    must be."
  - Responsive layouts can "destroy grouping relationships" by stretching the gaps.
  https://www.nngroup.com/articles/gestalt-proximity/

### 1.2 Common region (Palmer 1992 → UX)

- NN/g (Aurora Harley, Jul 2020): "The principle of common region says that items within a
  boundary are perceived as a group and assumed to share some common characteristic or
  functionality." Findings:
  - "Common region is a strong visual cue that **can overpower other grouping principles** such
    as proximity or similarity" — the documented demo flips proximity grouping with two boxes.
  - Cards fixed the Food Network tablet app's proximity failure ("the card-layout style to
    create a common region" for title + byline + rating).
  - **Caution:** "When possible, using whitespace alone to create clear groupings reduces the
    visual complexity of a design"; the Backcountry example shows removable borders; overuse
    "can result in busy, cluttered designs"; full-width blocks create "false floors" that stop
    scrolling. Checklist before adding a border: "are they necessary to understand the
    grouping? Can I communicate this grouping by simply adding or removing whitespace?"
  - Primary reference: Palmer, S.E. (1992). "Common region: A new principle of perceptual
    grouping." *Cognitive Psychology*, 24(3), 436–447.
  https://www.nngroup.com/articles/common-region/

### 1.3 The quantitative "rule" people derive

- The inequality: NN/g's framing — whitespace "unite or separate" — implies
  `gap(related) < gap(unrelated)` *clearly enough to be perceived*. That is the entire rule.
- Circulating multipliers (1:2, 1:2.5, 1:3) could **not** be verified against a primary source
  in this pass; they recur in design-system blogs and social media as rules of thumb. Where
  this report needs a number, it uses numbers that design systems actually publish (see §4–5
  tables) rather than the folklore ratios.
- Closest citable quantitative anchors found:
  - Material 3 cards: "Padding between cards **8dp max**" — i.e., sibling cards in a grid behave
    like *one* group at ≤8dp; contrast with section-level spacing in practice (24–48dp).
    https://m3.material.io/components/cards/specs
  - NN/g form rule: the label-to-field gap must be the smallest gap in the row stack.
    https://www.nngroup.com/articles/form-design-white-space/

## 2. Common region vs. containment: cards vs. whitespace-only grouping

- Decision rule from NN/g (§1.2): whitespace first; container when proximity alone is ambiguous
  (wrapped text of variable length, heterogeneous content, competing groupings) or when
  whitespace is constrained.
- Material 3 cards give a graded vocabulary of containment:
  - **Filled** card = "subtle separation from the background. This has less emphasis than
    elevated or outlined cards."
  - **Elevated** card = "drop shadow, providing more separation from the background than filled
    cards, but less than outlined."
  - **Outlined** card = "visual boundary around their container … greater emphasis."
  https://m3.material.io/components/cards/overview
- NN/g's definition of the card pattern as a grouping device:
  https://www.nngroup.com/articles/cards-component/ (referenced from the common-region article
  as the standard fix for ambiguous proximity).
- Apple: the *inset grouped* list style is the settings canon — a contained, rounded group of
  rows on a contrasting background, per UIKit: "A table view where the grouped sections are
  inset with rounded corners."
  https://developer.apple.com/documentation/uikit/uitableview/style-swift.enum/insetgrouped
- GNOME: `AdwPreferencesGroup` = "a group of tightly related preferences … represented by
  AdwPreferencesRow", optionally "boxed lists" (rows on one card) vs. `.boxed-list-separate`
  (each row its own card). https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/class.PreferencesGroup.html

## 3. Group headers / section labels: how design systems treat them

| System | Header treatment | Paired with | Source |
|---|---|---|---|
| Android platform Settings | Group heading inside a settings list | "If you use a group heading, you should **always** include a divider"; dividers "cluster settings in a group, rather than separating individual settings" | source.android.com/devices/tech/settings/settings-guidelines |
| Apple grouped lists | Small header (system default config: `groupedHeader()`; prominent variants exist for inset grouped) | "grouped style uses **headers, footers, and additional space** to separate groups of data"; footers carry explanatory text | developer.apple.com HIG lists-and-tables; UIKit groupedHeader() |
| GNOME/libadwaita | `title` + optional `description` above a boxed list | The box itself; the header rides on the page background, *outside* the box | libadwaita Adw.PreferencesGroup |
| Material 3 | Lists don't do headers; grouping is by containment/dividers (0dp divider padding inside a list) | Divider, 16/24dp inset | m3.material.io components/lists/specs |

- Header *typography numbers* (pt/px size, weight, color) are **not published** by Apple, GNOME
  docs, or AOSP. iOS's familiar 13pt-uppercase-secondary-label header is community-measured
  folklore, not Apple documentation — treat it as unverified.
- What *is* documented: the header's spatial relationship (closer to its group than to the
  previous group — NN/g §1.1) and the header+divider pairing (AOSP §3 table).

## 4. Settings pages specifically

### Apple (HIG, fetched via developer docs JSON)
- Settings philosophy: minimize settings; defaults first; infrequent settings in a custom
  settings area; task-specific options in context; macOS custom settings windows use a toolbar
  of panes; "Dim a settings window's minimize and maximize buttons"; "Restore the most recently
  viewed pane."
  https://developer.apple.com/design/human-interface-guidelines/settings
  (text via https://developer.apple.com/tutorials/data/design/human-interface-guidelines/settings.json)
- Anatomy of grouping (HIG Lists and tables): "the grouped style uses headers, footers, and
  additional space to separate groups of data" — grouping = header + footer text + extra space.
  https://developer.apple.com/design/human-interface-guidelines/lists-and-tables

### Android (AOSP settings guidelines, fetched)
- https://source.android.com/devices/tech/settings/settings-guidelines
- Page-level numbers: >10–15 items per screen is overwhelming; frequently used at top.
- Grouping: dividers cluster; heading + divider together; footer text always separated by a
  divider at top.
- (The old M2 preference spec — 72dp preference rows, category headers — is superseded by M3
  list geometry: 56/72/88dp heights. https://m3.material.io/components/lists/overview)

### GNOME
- `AdwPreferencesGroup`: title + description + grouped rows; `separate-rows` splits the box.
  This is the concrete implementation of GNOME's grouped-preferences pattern.
  https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/class.PreferencesGroup.html

## 5. Whitespace as hierarchy

### 5.1 Vocabulary and mechanism
- Boulton (A List Apart, 2007): **macro whitespace** = "space between major elements";
  **micro whitespace** = "space between smaller elements: between list items, between a caption
  and an image." Active whitespace (adding macro space around an element) is an emphasis
  device. https://alistapart.com/article/whitespace/
- NN/g: paragraphs are grouped by whitespace; headings are associated by asymmetric gaps (§1.1);
  chunking makes long forms feel shorter.
  https://www.nngroup.com/articles/form-design-white-space/

### 5.2 "How much extra space reads as a break?"
- No primary source found publishes a measured section-break threshold. The verifiable
  guidance:
  - the inequality `between > within`, "clearly" (NN/g §1);
  - "2x/3x line-height" and "1:2 / 1:2.5 / 1:3" figures circulate in practitioner writing but
    **could not be traced to a primary source in this pass** — record them as folklore;
  - shipped-system comparison (the only table of real numbers):

| Quantity | Value | System | Source |
|---|---|---|---|
| Gap between sibling cards | ≤8dp | Material 3 | m3.material.io/components/cards/specs |
| Card inner padding (L/R) | 16dp | Material 3 | m3.material.io/components/cards/specs |
| List row heights | 56 / 72 / 88dp | Material 3 | m3.material.io/components/lists/specs |
| List divider padding | 0dp above/below | Material 3 | m3.material.io/components/lists/specs |
| List min touch target | 48dp | Material 3 | m3.material.io/components/lists/specs |
| Max settings items per screen | 10–15 | Android AOSP | source.android.com …settings-guidelines |
| Group header↔divider pairing | always | Android AOSP | source.android.com …settings-guidelines |

## 6. Labels inside vs. outside components

- Verified (NN/g, forms): "place the label closer to the associated text field than to other
  text fields" — proximity between label and field must beat all neighboring gaps; top-aligned
  labels recommended; left-aligned labels must still sit "as close to the text fields as
  possible." No px number given. https://www.nngroup.com/articles/form-design-white-space/
- The often-quoted "field labels 4–8px from the field" could not be verified in this pass;
  record as folklore. The structural version (label gap is the smallest gap) is the citable
  form.
- Group label ↔ first child vs. previous sibling: NN/g's heading rule is the citable form —
  header-to-own-group < previous-section-to-header (§1.1, §3).

## 7. Applied perceptual research (grouping thresholds)

- Wagemans, Elder, Kubovy, Palmer, Peterson, Singh, von der Heydt (2012). "A century of Gestalt
  psychology in visual perception: I. Perceptual grouping and figure–ground organization."
  *Psychological Bulletin* 138(6), 1172–1217. The modern authoritative review of grouping laws
  incl. proximity (Wertheimer 1923 origins). DOI 10.1037/a0029333 (Europe PMC PMC3482144).
- Kubovy, M. (1994). "The perceptual organization of dot lattices." *Psychon Bull Rev* 1(2),
  182–190. DOI 10.3758/bf03200772 — proximity quantified as multistable perception in dot
  lattices.
- Kubovy, M., & Yu, M. (2012). "Multistability, cross-modal binding and the additivity of
  conjoined grouping principles." *Phil Trans R Soc B* 367, 954–964. DOI 10.1098/rstb.2011.0365
  — grouping principles combine additively.
- Moazzen, Gharibzadeh, Bakouie (2025). "Bistability and hysteresis in the proximity-based
  grouping of dot lattices." *Scientific Reports* 15, 43751. DOI 10.1038/s41598-025-25575-3
  (open access, PMC12705819) — grouping by distance is bistable near threshold and shows
  hysteresis: once grouped, the grouping survives further spacing change.
- Palmer, S.E. (1992). "Common region: A new principle of perceptual grouping."
  *Cognitive Psychology* 24(3), 436–447. (via NN/g common-region reference, §1.2)

---

## APPLIES TO OUR PANEL

Our current choices: 12px between blocks within a group, 36px between groups, small faint group
headers above each group, plain rows (no cards).

**1. The 12 vs. 36 spacing (1:3) — validated.** The inequality rule is the only citable law and
we satisfy it comfortably: 36/12 = 3:1, above the folklore 1:2 floor and matching the
"comfortable target" end. Nothing in Material, AOSP, Apple, or NN/g suggests 36px is too much
at our scale; AOSP even allows generous breaks between 10–15 item screens. The one caution is
the opposite direction: NN/g's tunnel-vision finding — over-separating related content makes it
overlooked. 36px is a *break*, not a page split; keep it whitespace, not a full-width divider or
background band (false-floor risk, §1.2).

**2. Small, faint group headers — half-wrong, per the sources.** Small is right (Apple's system
header config is deliberately small; GNOME's title is modest). Faint is a contrast decision the
sources don't dictate, but two documented constraints apply: (a) the header must be *spatially
owned* by its group — gap above header must exceed gap between header and first child (NN/g
§1.1). If we place 36px above the header and 12px between header and first block, we comply;
(b) AOSP pairs group headings with dividers *always*; Apple pairs them with footers+extra space.
If we keep faint headers, strengthen the break with either the asymmetric spacing (mandatory) or
a hairline divider above each group header (AOSP-style), not both-heavy chrome. A too-faint
header plus a big uniform gap risks the header reading as belonging to *neither* group —
exactly the grouping failure NN/g illustrates with text layouts.

**3. Plain rows vs. cards — validated for our case, with a documented fallback.** NN/g's rule:
whitespace-only grouping when proximity is unambiguous; containers "overpower other groupings"
and add clutter/false floors. With a 1:3 spacing ratio and distinct headers, our groups are
already unambiguous — cards would be "borders added in abundance of caution." The fallback
triggers if (a) rows get heterogeneous (wrapped multi-line content, like NN/g's Food Network
example), (b) we need dual groupings at once, or (c) the pane is wide enough that row-to-row
proximity weakens. If we card a group, M3 numbers apply: ≤8dp between sibling cards, 16dp inner
padding, 12dp radius; filled = subtle, outlined = strongest emphasis.

**4. Within-group rhythm — consistent with M3/AOSP.** M3 keeps intra-list gaps at 0dp
(divider-touching) with 56–72dp rows; our 12px between *blocks* within a group is larger than
M3's row gap but we're spacing blocks, not rows. The watch-item: any label/heading inside a
group (e.g., a sub-block title) must sit closer to its own block than 12px — that is NN/g's
label-proximity rule.

**5. What to change, concretely:** keep 12/36; enforce header asymmetry (≥ 12px header→first
child, 36px previous group→header, i.e., 1:3 repeated at the header level); consider a faint
hairline above each header only if the faint text alone doesn't survive squint-testing; stay
card-free unless rows become visually ragged; don't introduce full-width bands between groups.

**6. Unverified folklore to ignore in review discussions:** "labels must be 4–8px from fields,"
"the ratio must be exactly 1:2.5," iOS's "13pt header" as an Apple-specified value — none of
these trace to a primary source; the documented forms are the inequality, the asymmetry rule,
and the shipped-system numbers tabulated in §5.2.

---

## Source list

- https://lawsofux.com/law-of-proximity/
- https://www.nngroup.com/articles/gestalt-proximity/
- https://www.nngroup.com/articles/common-region/ (ref: Palmer 1992, *Cognitive Psychology* 24(3))
- https://www.nngroup.com/articles/form-design-white-space/
- https://m3.material.io/components/cards/overview
- https://m3.material.io/components/cards/specs
- https://m3.material.io/components/lists/overview
- https://m3.material.io/components/lists/specs
- https://developer.apple.com/design/human-interface-guidelines/settings
- https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- https://developer.apple.com/documentation/uikit/uilistcontentconfiguration-swift.struct/groupedheader()
- https://developer.apple.com/documentation/uikit/uitableview/style-swift.enum/insetgrouped
- https://source.android.com/devices/tech/settings/settings-guidelines
- https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/class.PreferencesGroup.html
- https://alistapart.com/article/whitespace/
- https://doi.org/10.1038/s41598-025-25575-3 (Moazzen et al. 2025, Sci Rep)
- https://doi.org/10.1037/a0029333 (Wagemans et al. 2012, Psych Bull)
- https://doi.org/10.3758/bf03200772 (Kubovy 1994, Psychon Bull Rev)
- https://doi.org/10.1098/rstb.2011.0365 (Kubovy & Yu 2012, Phil Trans R Soc B)

Note on fetch quality: m3.material.io and developer.apple.com render via JS; their content was
obtained through a rendering reader proxy and Apple's JSON doc API respectively; NN/g, AOSP,
libadwaita, and A List Apart were fetched directly. The requested NN/g URL
`/articles/gestalt-proximity-common-region/` and Carbon "section indexing" page do not exist at
those paths; the correct NN/g slugs (used here) are `/articles/gestalt-proximity/` and
`/articles/common-region/`.
