# Typography hierarchy & secondary text — research notes

*Research pass: 2026-09-27. Question: how do the major design systems build type
hierarchy, and specifically how do they do **secondary / supporting text**,
**label–value rows**, and **group headers** — translated to our constraints
(Monocraft, 9px design pixel, sizes locked to integer multiples of 9: 9/18/27).*

**Method note / source health.** All numbers below come from pages actually
fetched during this pass, cited inline. Three corporate sites render only with
JavaScript and could not be read directly — their numbers were recovered from
the system teams' own primary source code instead, which is more precise than
the prose anyway:

- `m2.material.io` / `m3.material.io` (JS-blocked, including via Wayback) →
  recovered from Google's AndroidX implementation source on GitHub, which is
  the generated materialization of the Material spec tokens
  ([Typography.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/Typography.kt),
  [TypeScaleTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt),
  [ContentAlpha.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ContentAlpha.kt),
  [ListItem.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ListItem.kt)).
- Apple HIG current pages are a JS SPA; the 2019/2020 macOS & iOS HIG snapshots
  were readable on the Wayback Machine and are cited below. Apple's *numeric*
  text-style tables are no longer published as web tables (they ship inside the
  Sketch/Photoshop "Design Resources" downloads) — recorded as a gap.
- IBM Carbon's web docs moved and 404'd; Carbon numbers come from the
  [`@carbon/type`](https://github.com/carbon-design-system/carbon/tree/main/packages/type)
  package source (`_scale.scss`, `_styles.scss`).
- `typescale.com` (the modular-scale calculator) is a JS app and renders
  nothing fetchable; the ratio ladders it popularizes are covered by the
  fetched system ladders instead. One correction to the brief:
  **1.125 is a major second, not a minor third; 1.2 is the minor third**
  (standard music-interval naming used by typescale.com-style tools).

Contrast figures in this doc were computed with the WCAG 2.x formula
(`(L1+0.05)/(L2+0.05)`, sRGB linearization) rather than quoted; the method is
from [W3C's Understanding SC 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

---

## TL;DR — laws with numbers

1. **Real systems step sizes by ~1.12–1.33, never by 2×.** Material 2: 16/14/12/10 sp ([AndroidX source](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/Typography.kt)). Material 3: 16/14/12/11 sp body/label roles ([TypeScaleTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt)). Fluent: 12/14/18/20/28/40/68 epx ([Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography)). Carbon: 12/14/16/18/20/24… px via a formula ([`_scale.scss`](https://raw.githubusercontent.com/carbon-design-system/carbon/main/packages/type/scss/_scale.scss)). A 2× jump (18→9) is bigger than any adjacent step in any shipped ladder.
2. **Because size steps are small, secondary text is de-emphasized by opacity, not size.** Material's implementation literally renders secondary list text at the same font size and applies alpha 0.60 ([ListItem.kt: secondary = `body2` at `ContentAlpha.medium`](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ListItem.kt)); the Material emphasis ladder is **0.87 high / 0.60 medium / 0.38 disabled** ([ContentAlpha.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ContentAlpha.kt)).
3. **4.5:1 is the floor for anything that carries information.** WCAG 2.2 SC 1.4.3: ≥4.5:1 for text, ≥3:1 only for "large" text (≥18pt ≈ 24px, or ≥14pt bold ≈ 18.66px), 7:1 for AAA ([W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)). 18px regular is **not** large text → our secondary text must clear 4.5:1.
4. **Thin strokes must overshoot.** WCAG, same page: "particularly thin or unusual fonts may be rendered… much fainter than the actual text color… best practice would be… to aim for a foreground/background combination that exceeds the normative requirements." A pixel font's 1px stem is the extreme case of this warning.
5. **On a near-black panel, white @ 60% ≈ 6.8–7.3:1 (AAA), white @ 45% ≈ 4.5:1, white @ 38% ≈ 3.5:1 (fails).** Computed this pass (table in §3). Practical ladder: **0.87 primary, 0.60 secondary, 0.38 only for genuinely disabled things** — and ≥0.45 is the hard floor.
6. **Group headers don't need to be bigger — they need to be distinct.** GNOME: headings are the same size as body, differentiated by weight/color; and "use smaller and/or lighter text for less important information… minimize the number of font sizes and weights" ([GNOME HIG Typography](https://developer.gnome.org/hig/guidelines/typography.html)). Material's title roles are body-size + medium weight ([TypeScaleTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt)).
7. **If a header is a small overline, it's uppercase + tracked.** Material overline: **10sp, letter-spacing 1.5sp (= 0.15em)** ([AndroidX Typography.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/Typography.kt)); Carbon label-01: **12px, letter-spacing 0.32px** ([`_styles.scss`](https://raw.githubusercontent.com/carbon-design-system/carbon/main/packages/type/scss/_styles.scss)); Butterick: **add 5–12% (0.05–0.12em) letterspacing to all caps, particularly at small sizes** ([Practical Typography](https://practicaltypography.com/letterspacing.html)).
8. **All-caps is contested.** Butterick: caps fine for headers/labels shorter than one line ([All caps](https://practicaltypography.com/all-caps.html)); GNOME: "do not capitalize every letter" ([GNOME HIG](https://developer.gnome.org/hig/guidelines/typography.html)); Fluent: "sentence casing for all UI text, including titles" ([Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography)). Caps+tracking is a valid *overline* idiom; sentence-case + faint is the modernist idiom. Pick one, shell-wide.
9. **Secondary text goes UNDER the label in settings rows; the value/control goes BESIDE.** Material two-line list: primary `subtitle1` (16sp) + supporting `body2` (14sp) stacked, 20dp baseline-to-baseline, 16dp horizontal padding, min height 72dp with icon ([ListItem.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ListItem.kt)). GNOME boxed lists (the GNOME Settings pattern): "Action rows include a title, subtitle, and a control" — subtitle stacked under title; "differentiate them using text size, weight and color" ([GNOME HIG Boxed Lists](https://developer.gnome.org/hig/patterns/containers/boxed-lists.html)).
10. **Line length: 45–90 characters** (Butterick, [Line length](https://practicaltypography.com/line-length.html)); Fluent is stricter: **50–60, never below 20 or above 60** ([Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography)). For UI line *heights*, every shipped ladder lands at 1.14–1.5×; the dense-UI end is ~1.33 (Carbon caption 12/16), the reading end ~1.43–1.5 (Fluent body 14/20, M2 body1 16/24).
11. **Pixel fonts: render native, no AA, integer sizes only.** Qt: only `Text.NativeRendering` may disable antialiasing, and hinting preferences apply only to NativeRendering ([Qt Text docs](https://doc.qt.io/qt-6/qml-qtquick-text.html)). Monocraft's TTF is generated from per-character pixel grids (FontForge), em = 1080 units = exactly **9 design px**, advance = 720 units = 6 design px (verified this pass via fontTools on the installed font) → integer pixel sizes (9/18/27) put design pixels on whole device pixels.
12. **WCAG floor ≠ design target.** Material itself ships only *disabled* text at ~3.5:1 contrast (alpha 0.38) — everything else sits far above 4.5:1. Disabled state is explicitly exempted by WCAG (inactive UI components, [W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)).

---

## 1. Type scales — the ladders as tables

### Material 2 (13 styles) — from Google's AndroidX implementation of the M2 spec

Source: [Typography.kt (AndroidX Compose Material, generated from Material tokens)](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/Typography.kt). Sizes in sp; same numbers are the M2 web spec's.

| Role | Size | Line height | Weight | Tracking |
|---|---|---|---|---|
| h1 | 96 | 112 | Light | −1.5 |
| h2 | 60 | 72 | Light | −0.5 |
| h3 | 48 | 56 | Regular | 0 |
| h4 | 34 | 36 | Regular | 0.25 |
| h5 | 24 | 24 | Regular | 0 |
| h6 | 20 | 24 | Medium | 0.15 |
| subtitle1 | 16 | 24 | Regular | 0.15 |
| subtitle2 | 14 | 24 | Medium | 0.1 |
| body1 | 16 | 24 | Regular | 0.5 |
| body2 | 14 | 20 | Regular | 0.25 |
| button | 14 | 16 | Medium | 1.25 |
| caption | 12 | 16 | Regular | 0.4 |
| overline | 10 | 16 | Regular | 1.5 |

Adjacent body/label steps: 16→14→12→10 — ratios 0.875, 0.857, 0.833. **No step smaller than ~0.83×.**

### Material 3 (15 roles) — from Google's token source

Source: [TypeScaleTokens.kt (AndroidX Compose M3, generated from the M3 token JSON)](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt). These are the exact values published on [m3.material.io/styles/typography/type-scale-tokens](https://m3.material.io/styles/typography/type-scale-tokens) (page itself JS-blocked).

| Role | Size | Line height | Weight | Tracking |
|---|---|---|---|---|
| display large | 57 | 64 | Regular | −0.2 |
| display medium | 45 | 52 | Regular | 0 |
| display small | 36 | 44 | Regular | 0 |
| headline large | 32 | 40 | Regular | 0 |
| headline medium | 28 | 36 | Regular | 0 |
| headline small | 24 | 32 | Regular | 0 |
| title large | 22 | 28 | Regular | 0 |
| title medium | 16 | 24 | Medium | 0.2 |
| title small | 14 | 20 | Medium | 0.1 |
| body large | 16 | 24 | Regular | 0.5 |
| body medium | 14 | 20 | Regular | 0.2 |
| body small | 12 | 16 | Regular | 0.4 |
| label large | 14 | 20 | Medium | 0.1 |
| label medium | 12 | 16 | Medium | 0.5 |
| label small | 11 | 16 | Medium | 0.5 |

Note the *smallest type in the whole M3 system is 11sp*, and it's medium-weight, not faint — tiny text is made **heavier**, not lighter.

### Fluent / Windows 11 type ramp

Source: [Typography in Windows — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography). Sizes in effective px, "size/line height".

| Style | Weight | Size/line |
|---|---|---|
| caption | small | 12/16 |
| body | regular | 14/20 |
| body strong | semibold | 14/20 |
| body large | regular | 18/24 |
| subtitle | semibold | 20/28 |
| title | semibold | 28/36 |
| title large | semibold | 40/52 |
| display | semibold | 68/92 |

Plus Windows' legibility floors: **"Minimum values: 14px semibold, 12px regular — text smaller than these sizes and weights are illegible in some languages"**, and **"Use Semibold for titles"** (bold/italic are not in the ramp; italic excluded for readability). Also: **"Keep to 50–60 letters per line… don't use fewer than 20 or more than 60"**, sentence case everywhere, semibold-not-bold for emphasis.

### IBM Carbon

Source: [`@carbon/type` `_scale.scss` and `_styles.scss`](https://github.com/carbon-design-system/carbon/tree/main/packages/type/scss). Scale steps are computed: step 1 = 12px, each step grows by an increasing 2px increment (12, 14, 16, 18, 20, 24, 28, 32, 36, 42 …).

| Token | Size | Line height | Tracking |
|---|---|---|---|
| label-01 / caption-01 / helper-text-01 | 12px | 1.333 | 0.32px |
| label-02 / caption-02 / helper-text-02 | 14px | 1.286 | 0.16px |
| body-01 (long) | 14px | 1.429 | 0.16px |
| body-02 (long) | 16px | 1.5 | 0 |
| heading-01 (productive) | 14px | 1.286 | 0.16px, **semibold** |
| heading-02 (productive) | 16px | 1.375 | 0, **semibold** |

Key Carbon fact for us: **heading-01 is the same size as body-01** — hierarchy by weight alone. And "helper text" is literally the same token as label-01 (12px + 0.32px tracking).

### Apple (qualitative — numeric tables not web-published)

Sources: [macOS HIG Typography, 2019 snapshot](https://web.archive.org/web/20191207124021/https://developer.apple.com/design/human-interface-guidelines/macos/visual-design/typography/), [iOS HIG Typography, 2020 snapshot](https://web.archive.org/web/20200109185003/https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/typography/).

- SF is split into **Text (for text < 20pt) and Display (≥ 20pt)** optical variants — even Apple changes letterforms for small sizes rather than shrinking display type.
- "Emphasize important information. Use font weight, size, and color."
- "Use a single typeface, if possible… just a few font variants and sizes."
- "Make sure custom fonts are legible… make sure it's easily readable, even at small sizes" (twice — both macOS and iOS pages).
- Built-in styles exist ("headline, body, callout, and several sizes of title") with the numbers shipped in the Design Resources downloads, **not** as web tables. Community-measured values for the iOS secondary text color (`secondaryLabel`) put it at ~55–60% alpha of the label color — **not verified against an Apple primary source this pass** (Apple's color pages are JS-blocked); treat as folklore-with-consensus, not a citation.

### Modular scales (typescale.com-style)

The tool ([typescale.com](https://typescale.com/)) generates ladders from musical-interval ratios: 1.067 minor second, **1.125 major second**, **1.2 minor third**, **1.25 major third**, 1.333 perfect fourth. (The brief called 1.125 "minor third" — that's the 1.2.) No shipped OS ladder uses a pure geometric scale end-to-end; every real system above hand-picks values on a 4px-ish line-height grid and flattens the small end (steps get *smaller* in ratio as sizes get smaller). The useful import of modular-scale thinking for us is the opposite of its premise: **ratios below ~1.4 are indistinguishable-ish at pixel-font sizes**, so systems distinguish adjacent tiers by weight and color instead.

---

## 2. The roles: headline vs title vs body vs label vs supporting text

Material's own role definitions (KDoc on the same sources):

- **Display/headline** — "largest… reserved for short, important text or numerals" (M3 headline = page/window-level statements). Used once per view, at most a few times.
- **Title** — "medium-emphasis text that is shorter in length" — row headers, card titles, dialog titles. In lists, this is the *primary* text role.
- **Body** — "long-form writing… works well for small text sizes."
- **Label** — "call to action… in buttons… and tabs" (labelLarge) and "used sparingly to annotate imagery or to introduce a headline" (labelSmall) — i.e., button text, tabs, overline/eyebrow headers.
- **Supporting/secondary text in list rows** — Material's list component styles it as `body2` (14sp, one step below the row's `subtitle1` 16sp) at **`ContentAlpha.medium` (0.60)**, while primary text gets `ContentAlpha.high` (0.87) ([ListItem.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ListItem.kt) + [ContentAlpha.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ContentAlpha.kt)).

Apple's list-row roles are the same shape (text style roles + a `secondaryLabel` color for the de-emphasized line); GNOME's are the same shape again: **ActionRow/SwitchRow = "a title, subtitle, and a control"**, with the HIG saying multi-text rows are differentiated "using text size, weight and color" ([Boxed Lists](https://developer.gnome.org/hig/patterns/containers/boxed-lists.html)).

So a settings-type UI's working vocabulary is only five roles: *display/one-off, row title, row subtitle (supporting), value/control text, group header*. Everything else is decoration.

---

## 3. Secondary text: the mechanics of de-emphasis, with numbers

There are four knobs: **size, weight, color/opacity, tracking**. The systems use them in a strict order of preference: *color/opacity first, weight second, size third, tracking last*.

### 3a. Material's emphasis ladder (the canonical opacity tiers)

Source: [ContentAlpha.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ContentAlpha.kt) — Google's implementation of the M2 "text legibility" guidance (m2.material.io/design/color/text-legibility.html, JS-blocked).

| Emphasis | Alpha (grayscale surfaces) | Alpha (on colored/high-contrast surfaces) | Used for |
|---|---|---|---|
| high | **0.87** | 1.00 | primary/body text |
| medium | **0.60** | 0.74 | secondary/placeholder text |
| disabled | **0.38** | 0.38 | disabled components only |

Note the design intelligence in that table: on colored surfaces the *whole ladder shifts up*, because contrast is context-dependent. The alpha is not the design — **the resulting contrast is**.

### 3b. What those alphas actually yield on dark panels (computed this pass)

Using the WCAG formula on white text blended at alpha a over background rgb(bg): `fg = a·255 + (1−a)·bg`.

| White alpha | on #121212 | on #0a0a0a | on #1e1e1e |
|---|---|---|---|
| 1.00 | 18.73:1 | 19.80:1 | 16.67:1 |
| 0.87 (high) | 14.22:1 | 14.88:1 | 12.84:1 |
| 0.74 (medium on color) | 10.45:1 | 10.80:1 | 9.61:1 |
| 0.60 (medium) | **7.18:1** | **7.30:1** | **6.77:1** |
| 0.38 (disabled) | 3.57:1 | 3.51:1 | 3.54:1 |

Floor alphas (white text): **0.45 alpha ⇒ 4.5:1; 0.59 alpha ⇒ 7:1** (nearly identical across #0a0a0a–#1e1e1e).

Readings:

- Material's medium 0.60 sits **just above the 7:1 AAA line** on true dark surfaces. The ladder is engineered against WCAG with headroom.
- The disabled 0.38 tier ≈ 3.5:1 — it **fails** SC 1.4.3 for normal text, which is legal because WCAG exempts "inactive user interface components" ([W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)). Never use the 38% tier for text that still informs.
- WCAG's own caveat for our case: "particularly thin or unusual fonts may be rendered… much fainter… best practice… aim for a… combination that exceeds the normative requirements." A pixel font is the thinnest font class there is (1px stems), so its rendered contrast *is* its nominal contrast — there is no anti-aliasing to soften it — but perceptually, 1px stems at low alpha vanish first. Budget contrast above the floor, not at it.

### 3c. Size vs weight vs color

- **Size**: every system steps secondary text down exactly one small step when space allows: M2 supporting text 14 vs 16 primary (0.875×); M3 supporting 14 vs 16, or 12 vs 14 (0.83–0.86×). Never more than one step for the *same* content unit.
- **Weight**: used to *raise* emphasis within one size (M3 titleMedium = bodyLarge size + Medium weight; Carbon heading-01 = body-01 size + semibold; Fluent "semibold for titles"). Weight is the *positive* knob; opacity is the *negative* knob. They're two directions of the same axis — pick per direction, don't stack (a faint bold line reads as an error).
- **Color/opacity**: the default secondary-text mechanism (§3a). Compose's own list implementation: same size, same family, alpha 0.60.
- **Tracking**: only for uppercase micro-labels (§5). Never a body-text de-emphasis tool.

### 3d. "Never de-emphasize below 4.5:1"

As a practitioner rule this is just WCAG applied honestly: since secondary text is usually *small* text, it gets no large-text discount; and disabled-tier opacities (0.38) are only for things that are actually inert. The one published number-ladder (Material's) keeps every informative tier ≥ ~7:1 on dark surfaces. The stronger practitioner version — and what the WCAG thin-font note implies — is: **on a dark panel, informative text should live between 60% and 87% alpha of white**, i.e. between AAA (7:1) and Material's high tier.

---

## 4. Label vs value pairs in settings rows

### Material's list-item internals (the hardest numbers available)

Source: [ListItem.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/ListItem.kt) (M2 spec implementation).

| Property | Value |
|---|---|
| Horizontal content padding | 16dp both sides |
| One-line item min height | 48dp (56dp with icon) |
| Two-line item min height | 64dp (72dp with icon) |
| Three-line item min height | 88dp |
| Primary text style | subtitle1 (16sp) @ ContentAlpha.high |
| Secondary text style | body2 (14sp) @ ContentAlpha.medium |
| Overline text style | overline (10sp) @ ContentAlpha.high |
| Baseline-to-baseline, primary→secondary | **20dp** (with or without icon) |
| Baseline-to-baseline, overline→primary | 20dp |
| Trailing (value/control) | caption (12sp) @ high, right-aligned, 16dp end padding |

20dp baseline gap between a 24-line-height subtitle1 and a 20-line-height body2 leaves ~2–4dp of visual air — the "text stack spacing 2–4dp" the brief guessed is about right, and the *structure* is: **secondary text stacked UNDER primary, always; values/metadata/trailing controls BESIDE, right-aligned**.

### GNOME boxed lists (the actual GNOME Settings pattern)

Source: [GNOME HIG — Boxed Lists](https://developer.gnome.org/hig/patterns/containers/boxed-lists.html).

- Predefined rows are explicitly **title + subtitle + control** (SwitchRow, ActionRow, ComboRow, SpinRow, PropertyRow "include a property name and a value").
- "If a list row includes multiple text elements, differentiate them using text size, weight and color."
- Row = one control (max two); clicking the row background triggers it; group headings: "each list can be given a heading."

### Beside or under?

- **Supporting sentence (description): UNDER** the label. Both Material and GNOME stack it. Reasons visible in the sources' numbers: the supporting text is one step smaller, wraps to arbitrary length, and must not push the row's trailing control around.
- **Value / control: BESIDE**, right-aligned (Material trailing slot; GNOME PropertyRow "property name and a value"; every macOS/iOS settings row). A value is short, fixed-width-ish, and scannable in a column — putting values in a right column is what makes a settings pane scannable.
- **Never beside-and-under both for the same text**: if the sentence is important enough to read, it's a subtitle (under); if it's data, it's a value (beside).

macOS System Settings rows follow the same shape (label + optional description stacked; value/control right); this is observable platform practice — the 2019 macOS HIG [Preferences page](https://web.archive.org/web/20191206123610/https://developer.apple.com/design/human-interface-guidelines/macos/app-architecture/preferences/) covers window/pane behavior but not row typography (gap recorded).

---

## 5. Group / section headers ("subtitles")

### The two idioms on record

| Idiom | Example | Numbers |
|---|---|---|
| **Overline/eyebrow**: small, uppercase, tracked, often faint | Material overline | 10sp, tracking 1.5sp (0.15em), regular ([M2 Typography.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material/material/src/commonMain/kotlin/androidx/compose/material/Typography.kt)) |
| | Carbon label-01 | 12px, tracking 0.32px (~0.027em) ([`_styles.scss`](https://raw.githubusercontent.com/carbon-design-system/carbon/main/packages/type/scss/_styles.scss)) |
| | M3 labelSmall (annotating/introducing role) | 11sp, Medium weight, tracking 0.5sp ([TypeScaleTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt)) |
| **Heading**: same size as body, heavier (and/or brighter) | GNOME `heading` | "standard style for UI headings, such as… headings for groups of controls" — same size as body, differentiated by weight ([GNOME HIG Typography](https://developer.gnome.org/hig/guidelines/typography.html)) |
| | M3 titleSmall/titleMedium | 14/16sp Medium vs body 14/16sp Regular ([TypeScaleTokens.kt](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt)) |
| | Fluent subtitle | 20/28 semibold — the one place Fluent steps a header up ([Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography)) |

### Uppercase + tracking mechanics

- Butterick: **always add 5–12% letterspacing (0.05–0.12em) to all caps**; "particularly important at small sizes"; lowercase below ~9pt also wants added tracking ([Letterspacing](https://practicaltypography.com/letterspacing.html), [All caps](https://practicaltypography.com/all-caps.html)).
- Material's overline (0.15em at 10sp) overshoots Butterick's range slightly — overlines run tighter than body-caps would.
- Carbon's 0.32px at 12px is only ~0.027em — an order of magnitude less; Carbon distinguishes labels by size+color instead of caps.
- **Disagreement on caps, recorded**: Butterick says caps are fine for headers/labels ("suitable for headings shorter than one line… other labels") and GNOME says flatly "do not capitalize every letter (all caps)"; Fluent wants sentence case "for all UI text, including titles." Material's overline tradition vs GNOME/Fluent's sentence-case modernism. Both camps agree on: no caps for *paragraphs*, and if caps then track them.

### Small+faint or large? What the sources imply

No fetched source makes group headers *larger* than the content they head. The overline idiom makes them *smaller* and compensates with caps+tracking; the heading idiom keeps them *equal* and compensates with weight. "Large header" is reserved for page/display level (Fluent subtitle 20 = one step above body; M3 titleLarge 22). For a dense settings panel: **group header = body-size text, one emphasis notch ABOVE content, with the gap doing the grouping** — and if we want the overline look instead, it's small + uppercase + 0.05–0.12em tracking + faint.

Spacing above/below the header: no fetched source publishes a header-margin token (gap recorded). The only number-bearing adjacent fact: all ladders' line heights sit on a 4px-ish grid, so headers get one or two whole line-boxes of air. This is a "design by eye" zone in every system I could read.

---

## 6. Line height and line length

### Line height (from the ladders in §1, as ratios)

| Context | Ratio | Example |
|---|---|---|
| Display/very large text | 1.05–1.25 | Carbon display-04 1.05–1.19; M2 h1 96/112 = 1.17 |
| Titles/subtitles | 1.27–1.33 | Fluent subtitle 20/28 = 1.4, title 28/36 = 1.29; M3 titleLarge 22/28 = 1.27 |
| Compact UI text / captions / labels | 1.33 | Carbon caption 12/16; M3 labelSmall 11/16; M2 caption 12/16 |
| Body / reading text | 1.43–1.5 | Fluent body 14/20 = 1.43; M2 body1 16/24 = 1.5; Carbon body-long 1.5 |
| Two-line list stacks | secondary line same ratio, stack gap 2–4px visual | M2 list: 20dp baseline gap for 14–16sp text |

So the "1.2 UI vs 1.4–1.6 reading" folk rule shows up as: **single-line UI text ≈ 1.3×, multi-line reading text ≈ 1.43–1.5×** — and line-height values themselves sit on multiples of 4 in Material and Fluent and on whole-ish px in Carbon. That's the baseline grid: not a mystical grid file, just "line boxes are round numbers."

### Line length

- Butterick: **45–90 characters per line (2–3 alphabets)**; "shorter lines are more comfortable to read… as line length increases, your eye has to travel farther from the end of one line to the beginning of the next" ([Line length](https://practicaltypography.com/line-length.html)).
- Fluent: **50–60 letters; don't go below 20 or above 60** ([Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/design/style/typography)).
- Binding on two-line rows: the *subtitle* is the wrapping element. At our sizes, if a row is ~300–360px of text column, an 18px monospace char cell ≈ 12px wide (Monocraft advance = 6 design px × 2) → 25–30 chars/line — comfortably under the 45-char minimum, i.e. our rows will wrap early and often; the fix is width, not font size.

---

## 7. Pixel fonts specifically

Primary sources are thin here, as the brief predicted; what follows is what could be *verified*.

### Rendering facts (primary)

- **Qt**: `Text.NativeRendering` is the only render type that may disable antialiasing ("Only Text with renderType of Text.NativeRendering can disable antialiasing"), and font hinting preferences only take effect with NativeRendering ([Qt 6 Text QML docs](https://doc.qt.io/qt-6/qml-qtquick-text.html)). The distance-field renderer (default `QtRendering`) has no notion of a pixel grid — matching DESIGN.md's mush finding.
- **Monocraft's own construction** (verified this pass): the font is generated from per-character *pixel* configuration files via FontForge ([Monocraft README](https://github.com/IdreesInc/Monocraft)); the upstream Minecraft-style font project describes hand-checking "how converting from a bitmap font to an OpenType font can affect metrics such as kerning, intended weight, and line height" ([Minecraft-Font README](https://github.com/IdreesInc/Minecraft-Font)). Local metrics of the installed `Monocraft.otf`: `unitsPerEm = 1080`, glyph advance = 720, win ascent/descent = 1200/240. That means:
  - **em = 9 design px** (1080 = 9 × 120), advance = 6 design px → font.pixelSize must be an integer multiple of 9 for design pixels to land on device pixels. The 9/18/27 ladder is the font's native 1×/2×/3×.
  - **Bold in this family is literal pixel-shifting** ("each character becomes thicker by shifting the pixels one pixel to the right" — Minecraft-Font README): weight contrast exists but is crude; it reads as +1px stem, not as a typographic semibold.
  - **Default line box = win metrics = (1200+240)/1080 = 1.333em** → 12px at 9, **24px at 18, 36px at 27** (Qt uses win metrics by default per the same docs) — 24/36 are multiples of 4, coincidentally on the Material/Fluent line grid; 12 is too.

### Scale steps with a pixel font (inference, flagged)

No shipped design system documents hierarchy under a pixel font; retro-game UIs (Stardew Valley, Undertale) and terminal UIs do carry hierarchy, but via color and weight with a *fixed* glyph size, not via size ladders — consistent with what the pixel-grid forces. **Flagged as practitioner inference, not a citable source**: with integer-only sizes, the coarsest usable ladder is 2× per step, which is coarser than any system in §1; therefore *within* a size, hierarchy must be alpha/weight/spacing, exactly as DESIGN.md §6 already prescribes. The one external anchor: WCAG's thin-font note (§3b) says faint thin text fails first — so a pixel font leans on alpha *less*, not more: keep faintness moderate and take hierarchy the rest of the way with spacing.

### What 9px text can and cannot be used for

- 9px = below every system's smallest role (M3 labelSmall 11sp, Carbon caption 12px, Fluent caption 12px) and far below Fluent's "12px regular" legibility floor. WCAG treats it as small text: 4.5:1 required, 3:1 unavailable.
- Legitimate uses: status glyphs, keycap-style chips, metadata that's redundant elsewhere — i.e., text that never carries unique information alone. Not settings subtitles.

---

## APPLIES TO OUR PANEL

Our current choices: ladder 9/18/27; body & labels 18; secondary/detail 18 @ fainter color; group headers 18 @ fainter; opacity tiers available; nothing below 9px; NativeRendering everywhere.

**Verdict on the 9/18/27 ladder: correct, and the only correct one.** Verified against the font itself: Monocraft's em is exactly 9 design px (unitsPerEm 1080), so 9/18/27 is the complete set of integer scales ≤ 3×. All three sizes land line boxes on the 4px grid (12/24/36). The ladder's 2.0 step ratio is coarser than any shipped system's (1.12–1.33), which is not a violation of the sources — it's the pixel-grid tax — but it *changes what the sources' remaining knobs must do* (below).

**Secondary text: 18px @ ~60% opacity is exactly what the sources prescribe — do it with precision.**
- Material renders supporting text at the *same* size as adjacent primary and applies alpha 0.60; our 18px-faint matches that mechanism. The size-down option (M2: 14 vs 16) is unavailable to us (18→9 = 0.5×, more than double any sanctioned step), which *strengthens* the case for the opacity mechanism.
- Contrast math (computed): white @ 0.60 on near-black panels = **6.8–7.3:1** — clears WCAG AA (4.5:1) comfortably, and clears AAA (7:1) on true black. The WCAG thin-font caveat says thin strokes should *exceed* the norm — 0.60 does.
- **Define "faint" as a token, not a vibe**: high = 0.87 (14.2–14.9:1), secondary = 0.60 (≥6.8:1), and reserve anything below **0.45 alpha (4.5:1)** for genuinely disabled/inert text only. Material's 0.38 "disabled" tier ≈ 3.5:1 and is only legal because WCAG exempts inactive UI.
- If our panel color is ever lighter than ~#1e1e1e, recompute: the 0.60 tier degrades toward the floor (0.457 alpha is 4.5:1 at #1e1e1e). The token should be expressed as *minimum contrast*, with alpha derived per surface — that's what ContentAlpha.kt's luminance-conditional does.

**9px text: demote to glyph/decoration tier.** Every source's smallest informative text is 11–12px+; Fluent calls sub-12px "illegible in some languages." Use 9px only where the information is redundant or non-textual (status dots with tooltips, keycaps, decorative counters), and never as the only carrier of a setting's description.

**Group headers: 18px faint is defensible, but it's the weakest of our current three choices.** The sources split two ways and neither is "faint same-size sentence-case": the overline idiom is small + **uppercase + tracking** (Material overline: 10sp/0.15em; Butterick: caps need 5–12% added tracking, "particularly at small sizes"), the heading idiom is same-size + **weight** (GNOME heading, M3 titleSmall = body-size + Medium). Two ways to fix it inside our grid:
- *Overline look*: keep 18px, go uppercase + letterspacing ~1–2px (at 18px, 0.05–0.12em = 0.9–2.16px; **2px ≈ 0.11em** is the nearest on-grid value) + faint (0.60). Monospace pixel caps at this tracking read as classic terminal section headers. Warning: GNOME and Fluent both discourage all-caps UI text — this is a deliberate idiom choice, record it in DESIGN.md when made.
- *Heading look*: 18px at full 0.87 alpha (or DemiBold +1px-stem weight), with a whole line box of air above. This is GNOME-Settings-shaped and caps-free.
- Either way, the header should NOT be dimmer than the dimmest body text *in its own group* — a header fainter than its content inverts the hierarchy it exists to state. Today's "18px faint group header" only works if secondary text is fainter still.

**Label + description rows: stack the description UNDER, put values BESIDE.**
- Material list internals to copy as ratios: horizontal padding 16dp-equivalent; primary→secondary baseline gap 20dp at 16/14sp — at our 18/18 that's a baseline gap of ~24px, i.e. **the description sits one 24px line box below the label with no extra margin** (visual air 2–6px).
- Descriptions wrap; values don't. Right-align values/controls in their own column (Material trailing slot; GNOME PropertyRow). Keep the text column ≤ ~60 chars/line (Fluent's hard cap; Butterick's 45–90 band): at 18px Monocraft (12px advance) that's a ~720px max column — our panel is narrower, so descriptions will wrap at 25–35 chars; that's fine, it's what the under-label position is for, but keep it to two lines.
- Line height: 18px single-line labels can ride the font's default 1.33 line box (24px); multi-line descriptions should get explicit `lineHeight` 24–27px (1.33–1.5×) per the body-text ratios in §6.

**One DISAGREEMENT to carry forward**: uppercase group headers (Butterick/Material-overline tradition) vs GNOME/Fluent's sentence-case-only stance. The pixel-grid tiebreaker: at 9px design px, uppercase Monocraft is 5px wide per glyph vs 6px advance — caps waste horizontal resolution we don't have at 18px… but at 18px the math is fine. Choose by idiom (terminal heritage says tracked caps are *on brand*), not by claim.

**Open items the sources didn't answer** (gap list): exact above/below spacing tokens for group headers; Apple's numeric text-style/alpha tables (JS-blocked, downloads-only); any design-system-grade guidance for pixel fonts (none found in primary sources — flagged inference only).
