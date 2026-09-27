# Spacing Systems: Laws, Scales, and Concrete Numbers

Research compiled 2026-09-27. Context: spacing a desktop settings panel (1280×820, left nav rail 264px, content pane) in a QML desktop shell (Hyprland/Quickshell). Current tokens: padding tiers 6/12/24/36, row height 42, page gutter 32, two-tier rhythm (12 between blocks in a group, 36 between groups), Monocraft pixel font, body 18px on a 9px glyph grid.

Every claim is cited inline. Where sources disagree, the disagreement is recorded.

---

## TL;DR — 12 laws with numbers

1. **Align everything to a base grid.** Material: 8dp baseline grid everywhere, 4dp for icons/type ([m1.material.io/layout/metrics-keylines.html](https://m1.material.io/layout/metrics-keylines.html)). Carbon: "multiples of two, four, and eight" ([carbondesignsystem.com/elements/spacing/overview](https://carbondesignsystem.com/elements/spacing/overview/)). Atlassian: 8px base unit ([atlassian.design/foundations/spacing](https://atlassian.design/foundations/spacing)). Shopify Polaris: base-4px ladder ([polaris.shopify.com/tokens/spacing](https://polaris.shopify.com/tokens/spacing), archived). Our 6/12/24/36 straddles the 4px world (12/24 ✓) with two odd steps (6, 36) — see §8.
2. **Proximity is law: space between related < space between unrelated.** Gestalt via [lawsofux.com/law-of-proximity](https://lawsofux.com/law-of-proximity/), [nngroup.com/articles/gestalt-proximity](https://www.nngroup.com/articles/gestalt-proximity/). Carbon: "As more space is added between elements, their perceived relationship weakens." Our 12 vs 36 obeys this; ratio 1:3.
3. **Concrete proximity numbers (Material):** 8dp between content areas vs 48–72dp rows and 16/24dp margins ([m1.metrics-keylines](https://m1.material.io/layout/metrics-keylines.html)); list internal padding 16dp, divider insets 16/24dp, targets 48dp ([m3 lists specs](https://m3.material.io/components/lists/specs)).
4. **Spacing = hierarchy.** Carbon: elements with more surrounding space read as more important; important items get extra surrounding space to attract focus (Carbon spacing overview, "Creating hierarchy").
5. **Grouping beats dividers.** M3: implicit grouping (proximity/open space) preferred; explicit grouping (outlines/dividers) for interactive clarity ([m3 grids-spacing/spacing](https://m3.material.io/foundations/layout/grids-spacing/spacing)). Polaris: dividers only in tables/indexes ([Polaris layout](https://polaris.shopify.com/design/layout), archived).
6. **Density steps in 4px decrements; never below 48dp target by default.** M3 density scale 0/-1/-2/-3 shrinks "top and bottom padding or overall height by 4dp"; don't drop below 48×48 CSS px ([m3 grids-spacing/density](https://m3.material.io/foundations/layout/grids-spacing/density)).
7. **Target-size floors disagree by platform — know your floor:** W3C WCAG 2.5.8 AA minimum **24×24 CSS px** with a spacing exception ([W3C Understanding 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)); Material default **48×48dp** (40dp dense desktop icon targets, [m1 icons](https://m1.material.io/style/icons.html)); Apple iOS **44×44pt default** but **macOS default 28×28pt, minimum 20×20pt** ([Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)). Desktop mouse reality: Apple macOS numbers, not the touch numbers.
8. **Desktop rows are shorter than touch rows:** Material single-line 48dp → dense 40dp (13sp type); two-line 72 → 60 dense; three-line 88 → 76 dense ([m1 lists](https://m1.material.io/components/lists.html)). Fluent/Windows: NavigationView header is 52px, content margins 24px expanded ([learn.microsoft.com NavigationView](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview)). Our 42px row sits in the dense-desktop band.
9. **Apple spacing-between-controls rule:** ~**12pt** padding around bezelled elements, ~**24pt** around bare elements ([Apple HIG Accessibility, Mobility](https://developer.apple.com/design/human-interface-guidelines/accessibility)).
10. **Windows 11 Settings is a left-nav silhouette with generous content margins:** 56epx margins where content cohesion matters (expanders), smaller where it doesn't; utility apps use 12epx ([learn.microsoft.com app silhouettes](https://learn.microsoft.com/en-us/windows/apps/design/basics/app-silhouette)). Fluent desktop density is notably tighter than Material touch defaults.
11. **Optical spacing is sanctioned practice:** Material system icons live in a 24dp box with a 20dp live area + 4dp padding (2dp dense) and permit optical stroke corrections ([m1 icons](https://m1.material.io/style/icons.html)); Atlassian: "Use optical adjustment… optical adjustments should be used to correct imbalances" ([atlassian spacing](https://atlassian.design/foundations/spacing)).
12. **Scales are ladders with semantic bands, not uniform steps.** Carbon: 2→160 with tokens $spacing-01…13; Atlassian: 0→80 with small (0–8, icon-to-text), medium (12–24, component padding), large (32–80, page layout) bands; Polaris: 0→128 in mostly 4px steps. Semantic banding (not the raw ladder) is the transferable idea for our 6/12/24/36.

---

## 1. The 4pt/8pt grid systems

### Origins and rationale (Material)

- **Material 1 spec:** "All components align to an 8dp square baseline grid for mobile, tablet, and desktop. Iconography in toolbars align to a 4dp square baseline grid. Type aligns to a 4dp baseline grid." — [m1.material.io/layout/metrics-keylines.html](https://m1.material.io/layout/metrics-keylines.html)
- The 8dp increment was chosen for screen-density math: a dp equals one physical pixel at 160dpi, and 8dp ≈ 1mm at default densities; halving to 4dp gives a finer grid for icons and type without losing on-pixel rendering. M3 keeps the same dp logic: "A dp is equal to one physical pixel on a screen with a density of 160" — [m3.material.io/foundations/layout/grids-spacing/density](https://m3.material.io/foundations/layout/grids-spacing/density)
- **Why 4/8 specifically:** both divide cleanly into common component heights (24 icon, 36 button, 48 target, 56 toolbar, 72/88 rows — all multiples of 4, see numbers above from m1 metrics/list specs), which is what makes composite layouts land back on the grid.

### Material 3 spacing system

- M3 frames spacing as a tool with three jobs: **group content, direct attention, shape personality** ("A denser layout can feel more serious and focused, while a more spacious layout can feel calm and open"). Desktop layouts "can use more generous spacing than mobile layouts." — [m3.material.io/foundations/layout/grids-spacing/spacing](https://m3.material.io/foundations/layout/grids-spacing/spacing)
- M3's published mechanisms: explicit grouping (outlines/dividers/shadows) vs implicit grouping (proximity/open space); rhythm (consistent spacing between related elements); similarity (same spacing+size for similar elements, leading elements always aligned); proximity ("buttons should be close to the content they're affecting"). Same URL.
- M3 replaces a flat numeric ladder with **rulers** (margin, bar/safety, title, content 1..n) and breakpoint-adaptive margins; "Rulers can also be used to create more immersive experiences… a photo grid can take the full width of the screen, while components like search use wider margins" — [m3.material.io/foundations/layout/grids-spacing/grids](https://m3.material.io/foundations/layout/grids-spacing/grids). The M3 token tables (spacing tokens like 4/8/16/…) render only via JS on the live site; the numeric component specs that came through are in §4/§6.
- **Desktop gutter/margin numbers (Material 2, still the most concrete):** mobile margins 16dp; tablet/desktop 24dp; "space between content areas: 8dp"; content-indent keyline 72dp for icon-led lists — [m1 metrics-keylines](https://m1.material.io/layout/metrics-keylines.html).

### How it applies to padding, gaps, sizing

- Padding inside components and gaps between them are both drawn from the same grid (Carbon: "Spacing tokens can be used inside of components for building and between components for layout spacing" — [Carbon spacing overview](https://carbondesignsystem.com/elements/spacing/overview/)).
- Component sizing is grid-locked too: Material button 36dp inside a 48dp touch target; list rows 48/72/88dp; toolbar 56dp (m1 metrics-keylines + lists).

## 2. Apple HIG layout metrics

From [developer.apple.com/design/human-interface-guidelines/layout](https://developer.apple.com/design/human-interface-guidelines/layout) and […/accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), […/sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars):

- **Hierarchy via alignment/indentation, not just space:** "Align elements to make them easier to scan, and use indentation to convey hierarchy… People assume that aligned items are related to each other, and… perceive indented items as subordinate to the item they follow." "Group related items… use negative space, container shapes, or separator lines."
- **Numeric control sizes (current HIG):**

  | Platform | Default control size | Minimum control size |
  | --- | --- | --- |
  | iOS/iPadOS | 44×44 pt | 28×28 pt |
  | **macOS** | **28×28 pt** | **20×20 pt** |
  | tvOS | 66×66 pt | 56×56 pt |
  | visionOS | 60×60 pt | 28×28 pt |
  | watchOS | 44×44 pt | 28×28 pt |

- **Spacing between controls:** "In general, it works well to add about **12 points** of padding around elements that include a bezel. For elements without a bezel, about **24 points** of padding works well around the element's visible edges." (Accessibility → Mobility)
- **macOS sidebar rows** come in three sizes — "A sidebar's row height, text, and glyph size depend on its overall size, which can be small, medium, or large" — HIG does not publish the pt values (they live in Apple Design Resources templates: [developer.apple.com/design/resources](https://developer.apple.com/design/resources/)). Sidebars page otherwise governs behavior: max two hierarchy levels, group titles succinct, allow hiding.
- **Type floors (macOS):** default 13pt, minimum 10pt (Accessibility → Vision) — directly relevant to our 18px body.
- tvOS safe-area numbers (60pt top/bottom, 80pt sides) and visionOS "button centers at least 60 points apart" exist but are not desktop-applicable.
- **Note (disagreement):** the famous "44pt touch target" is now documented as the iOS *default*, not a macOS rule; the HIG does not give macOS a 44pt floor. Sources quoting 44pt for desktop are importing iOS numbers.

## 3. Spacing scales from real design systems

### IBM Carbon (base 2px, "multiples of two, four, and eight")

Source: [carbondesignsystem.com/elements/spacing/overview/](https://carbondesignsystem.com/elements/spacing/overview/)

| Token | px | | Token | px |
| --- | --- | --- | --- | --- |
| $spacing-01 | 2 | | $spacing-08 | 40 |
| $spacing-02 | 4 | | $spacing-09 | 48 |
| $spacing-03 | 8 | | $spacing-10 | 64 |
| $spacing-04 | 12 | | $spacing-11 | 80 |
| $spacing-05 | 16 | | $spacing-12 | 96 |
| $spacing-06 | 24 | | $spacing-13 | 160 |
| $spacing-07 | 32 | | | |

Stated semantics: "small increments needed to create appropriate spatial relationships for detail-level designs as well as larger increments used to control the density of a design." Deviation is discouraged but allowed ("There are always exceptions to the rule"); jumping a step at breakpoints is explicitly sanctioned. Hierarchy rules: "Elements that have more spacing around them tend to be perceived as higher in importance… if you have an element or content of high importance… consider giving it extra surrounding space."

### Atlassian (base 8px, named bands)

Source: [atlassian.design/foundations/spacing](https://atlassian.design/foundations/spacing)

| Token | px | Band |
| --- | --- | --- |
| space.025 | 2 | Small (0–8px) |
| space.050 | 4 | Small |
| space.075 | 6 | Small |
| space.100 | 8 | Small — base unit |
| space.150 | 12 | Medium (12–24px) |
| space.200 | 16 | Medium |
| space.250 | 20 | Medium |
| space.300 | 24 | Medium |
| space.400 | 32 | Large (32–80px) |
| space.500 | 40 | Large |
| space.600 | 48 | Large |
| space.800 | 64 | Large |
| space.1000 | 80 | Large |

Stated semantics, verbatim:
- **Small (0–8px):** "Gap between small icons and text; container padding of small components (badges, icon buttons, table cells); gap between repeating elements (button groups); padding within input components; vertical spacing between elements in a card; gap between the trigger and elevated element."
- **Medium (12–24px):** "Container padding of larger components (buttons); space between avatar/large icon and content; vertical spacing between elements in cards; spacing between items in less densely packed or larger components."
- **Large (32–80px):** "The space between content on the page (ie spacing between top of page and header); alignment within larger pieces of content."
- Usage laws: group by similarity, group by proximity, create order and hierarchy, introduce visual rhythm, and **"Use optical adjustment"** ("optical adjustments should be used to correct these imbalances and maintain the page's flow").

### Shopify Polaris (base 4px)

Source: [polaris.shopify.com/tokens/spacing](https://polaris.shopify.com/tokens/spacing) (archived 2023; current docs redirected to shopify.dev)

| Token | px | | Token | px |
| --- | --- | --- | --- | --- |
| p-space-0 | 0 | | p-space-6 | 24 |
| p-space-025 | 1 | | p-space-8 | 32 |
| p-space-05 | 2 | | p-space-10 | 40 |
| p-space-1 | 4 | | p-space-12 | 48 |
| p-space-2 | 8 | | p-space-16 | 64 |
| p-space-3 | 12 | | p-space-20 | 80 |
| p-space-4 | 16 | | p-space-24 | 96 |
| p-space-5 | 20 | | p-space-28 | 112 |
| | | | p-space-32 | 128 |

Semantics (from Polaris design/layout foundations, archived): "Space defines proximity — the closer objects are, the stronger their perceived relationship"; dividers "rarely for dividing information elsewhere" outside tables; "Software, not website — elements need to be sized appropriately based on their job… compact elements add detail, larger elements command attention."

### Fluent 2 / Windows (semantic, not ladder-published)

Microsoft's Fluent 2 site publishes no numeric spacing ladder ([fluent2.microsoft.design](https://fluent2.microsoft.design/)); the concrete published numbers are component/layout metrics on Microsoft Learn:
- NavigationView: header **52px** fixed; content margins **12px** (minimal mode) / **24px** (all other modes); expanded left pane at window widths ≥1008px — [learn.microsoft.com/…/navigationview](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview)
- App silhouettes: Windows 11 Settings uses a **left navigation silhouette** with content margins that "can vary… This example uses **56epx** margins… Use smaller margins when content cohesion is less of a concern"; utility apps (Notepad) use **12epx** — [learn.microsoft.com/…/app-silhouette](https://learn.microsoft.com/en-us/windows/apps/design/basics/app-silhouette)
- Disagreement note: Fluent's de-facto internal grid is 4px (visible in XAML control templates), but Microsoft documents spacing guidance per-control rather than as a token ladder, unlike Carbon/Atlassian/Polaris.

**Cross-system comparison:**

| px | Carbon | Atlassian | Polaris |
| --- | --- | --- | --- |
| 2 | ✓ | ✓ | ✓ |
| 4 | ✓ | ✓ | ✓ |
| 6 | — | ✓ | — |
| 8 | ✓ | ✓ (base) | ✓ |
| 12 | ✓ | ✓ | ✓ |
| 16 | ✓ | ✓ | ✓ |
| 24 | ✓ | ✓ | ✓ |
| 32 | ✓ | ✓ | ✓ |
| 36 | — | — | — |
| 40/48 | ✓/✓ | ✓/✓ | ✓/✓ |

Our tokens 6 and 36 exist in only one of the three ladders (6 = Atlassian space.075; 36 = none).

## 4. Spacing steps vs type size

- **The pairing rule with numbers (Material):** single-line list row = body text 16sp with 24sp line box → **48dp** row (48 = 2× line-height, 16px top/bottom padding); two-line row with 14sp secondary → **72dp**; three-line → **88dp**; dense variants at 13sp type → 40/60/76dp — [m1 lists](https://m1.material.io/components/lists.html). I.e., row height is a function of line-height × lines + padding, all snapped to 4/8.
- **Label-to-field vs group-to-group (NN/g):** "a minimal amount of spacing between a top-aligned label and its corresponding form field makes that relationship apparent compared to a larger margin before the next label-field pair" — [nngroup.com/articles/gestalt-proximity](https://www.nngroup.com/articles/gestalt-proximity/). The Gestalt law itself: "Objects that are near, or proximate to each other, tend to be grouped together" — [lawsofux.com/law-of-proximity](https://lawsofux.com/law-of-proximity/).
- **Material's section rhythm:** "Space between content areas: 8dp" *within* a screen section vs list rows 48–72dp tall and 24dp tablet/desktop margins between regions — [m1 metrics-keylines](https://m1.material.io/layout/metrics-keylines.html). M3 list internals: 16dp label padding, 8dp leading-icon top padding, 0dp around dividers, trailing right padding 24dp — [m3 lists specs](https://m3.material.io/components/lists/specs).
- **Carbon's internal/external pairing:** the same ladder tokens serve both, but hierarchy is produced by band: detail-level (2–8) inside components, density-controlling (16+) between them; "Space can also be used to denote groups of associated information. This creates content sections on a page without having to use lines" — [Carbon spacing overview](https://carbondesignsystem.com/elements/spacing/overview/).
- **Rule of thumb extraction (consistent across sources):** related-element gap ≈ 0.5–1× line-height; group gap = 2–3× the intra-group gap; heading binds to the text *below* it (space above heading > space below heading — NN/g heading-proximity example in gestalt-proximity). Atlassian's banding (12–24 medium for "vertical spacing between elements in cards", 32+ large for page spacing) is the same idea tokenized.
- Our 12 (intra-group, at 18px body ≈ 0.67× line box) vs 36 (inter-group, 3×) fits this pattern; see §8.

## 5. Optical vs mathematical spacing

- **Atlassian codifies it:** "Use optical adjustment — while using a spacing system improves consistency, the visual harmony of a page may not be perfect the first time… Optical adjustments require using the spacing scale units and visual intuition to make minor changes to the spacing between objects in order to create visual harmony." — [atlassian spacing](https://atlassian.design/foundations/spacing)
- **Material icon system is optical by construction:** system icons are 24dp boxes but the *live area* is only 20×20 with 4dp padding (dense: 16dp live + 2dp) — "Content should only extend into the padding… if additional visual weight is needed"; keyline shapes differ per geometry (square 18dp vs circle 20dp diameter vs rectangles 20×16) precisely so a circle *looks* the same size as a square; "Optical corrections: extreme scenarios that call for subtle tweaks… the paperclip icon… is only using 1.5dp of the possible 2dp stroke area" — [m1 icons](https://m1.material.io/style/icons.html)
- **Consequence for panels:** equal-box centering of icons vs text is not "equal spacing" — the systems *pre-compensate* icon padding (4dp) versus text (16dp to the keyline, 72dp icon-content indent in lists) — [m1 lists](https://m1.material.io/components/lists.html), [m1 metrics-keylines](https://m1.material.io/layout/metrics-keylines.html)
- **Alignment over arithmetic:** Apple: "People assume that aligned items are related"; Polaris "Do vertically align / don't align invisible containers" (card-layout spacing imagery, archived); Atlassian's optical-adjustment do/don't. NN/g's grouping studies show grouping perception survives even without seeing the actual content (gray-boxes figure) — [nngroup gestalt-proximity](https://www.nngroup.com/articles/gestalt-proximity/)
- Disagreement: none on the principle; the *degree* varies — Atlassian says optical tweaks should still land on scale units; Material's icon keylines openly use non-grid values (20dp live area inside 24dp) to achieve optical equality.

## 6. Density and touch targets

| Source | Floor | Context |
| --- | --- | --- |
| W3C WCAG 2.2 SC 2.5.8 (AA) | **24×24 CSS px**, or spacing exception (24px circles around undersized targets must not intersect) | [w3.org Understanding 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) |
| Material (default) | **48×48dp**; "8dp or more space between them"; dense desktop: icon 20dp with 40dp target | [m1 metrics-keylines](https://m1.material.io/layout/metrics-keylines.html), [m1 icons](https://m1.material.io/style/icons.html), [m3 density](https://m3.material.io/foundations/layout/grids-spacing/density) |
| Material (M3 restated) | "The default target size should be at least 48×48 CSS pixels"; "Don't scale layouts below 48×48dp by default" | [m3 density](https://m3.material.io/foundations/layout/grids-spacing/density) |
| Apple iOS/iPadOS | 44×44pt default, 28×28pt minimum | [HIG accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) |
| Apple macOS | **28×28pt default, 20×20pt minimum** | same |
| Physical anchor | "about 9mm regardless of screen size. The recommended target size for touchscreen objects is 7–10mm" | [m1 metrics-keylines](https://m1.material.io/layout/metrics-keylines.html) |

- **Comfortable desktop list rows with numbers:** Material single-line 48dp (dense 40dp), two-line 72 (dense 60), three-line 88 (dense 76) — [m1 lists](https://m1.material.io/components/lists.html); M3 expressive/baseline list internals: 16dp horizontal padding, 48dp targets, label top-aligned at ≥88dp — [m3 lists specs](https://m3.material.io/components/lists/specs). Windows NavigationView header 52px; content margins 12/24px — [learn.microsoft.com](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview).
- **Desktop-density guidance:** Material — "When the mouse and keyboard are the primary input methods, measurements may be condensed to accommodate denser layouts" (m1 lists/icons; dense specs = type drops 16sp→13sp and rows drop 8dp each); M3 — density scale numbered 0,-1,-2,-3, each step "decreasing the top and bottom padding or overall height by 4dp", with a hard rule "Don't increase density in UIs that involve focused tasks, such as selecting from a menu" and "Don't increase the density in components that alert a person of changes" — [m3 density](https://m3.material.io/foundations/layout/grids-spacing/density). Carbon — larger scale increments "used to control the density of a design" — [Carbon spacing](https://carbondesignsystem.com/elements/spacing/overview/). Fluent/Windows — Settings margins 56epx, utility 12epx — [app silhouettes](https://learn.microsoft.com/en-us/windows/apps/design/basics/app-silhouette).
- **WCAG spacing exception detail (useful for tight rows):** targets of 20×20px pass if 4px gaps keep the imaginary 24px circles from intersecting; menu items below 24px height fail when stacked — [W3C 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).

## 7. Desktop settings-page conventions

- **Windows 11 Settings:** left navigation silhouette (NavigationView); "Content margins can vary. This example uses **56epx** margins… Use smaller margins when content cohesion is less of a concern" — [learn.microsoft.com/…/app-silhouette](https://learn.microsoft.com/en-us/windows/apps/design/basics/app-silhouette). NavigationView itself: pane items with headers/separators as grouping devices, header 52px, content margins 24px expanded — [NavigationView docs](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview). (Official numeric documentation of Windows 11 Settings internals beyond this does not exist; these are the framework defaults the app is built on.)
- **GNOME Settings pattern:** preferences are **boxed lists** — "Boxed lists are a common type of list that can contain both controls and information. Examples include app preferences"; "Multiple lists can be included in the same view, to act as different sections. If necessary, each list can be given a heading"; rows carry at most two controls; "If icons are included in a list row, they should typically have the symbolic style" (low visual footprint) — [developer.gnome.org/hig/patterns/containers/boxed-lists.html](https://developer.gnome.org/hig/patterns/containers/boxed-lists.html). Navigation between pages: **sidebars** — "A sidebar is a vertical panel which contains a list of different locations… Order the list according to what is most useful" — […/patterns/nav/sidebars.html](https://developer.gnome.org/hig/patterns/nav/sidebars.html). The GNOME HIG deliberately does not publish px spacing (Libadwaita constants are non-API).
- **macOS System Settings:** Apple publishes no numeric spacing spec for the app. The HIG-level facts: sidebars have three sizes (small/medium/large) that scale row height, text, and glyph size together ([HIG sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)); macOS control defaults 28×28pt (min 20×20pt) and the ~12pt/24pt padding-between-controls rules ([HIG accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)); exact metrics ship in the Apple Design Resources templates ([developer.apple.com/design/resources](https://developer.apple.com/design/resources/)). Anything more precise circulating online is reverse-engineered, not official.
- **Common convention extracted:** all three use (a) a left rail of fixed width for top-level destinations, (b) group headers belonging to the group *below* them, (c) boxed/inset rows with icon+label+trailing control, (d) more space above a group than between its rows.

---

## APPLIES TO OUR PANEL

Mapping each law to our tokens: padding tiers **6/12/24/36**, row **42**, page gutter **32**, rail **264**, rhythm **12 intra-group / 36 inter-group**, body **18px Monocraft (9px glyph grid)**, canvas **1280×820**.

### What validates

| Our token | Law | Verdict |
| --- | --- | --- |
| 12 intra-group | Material intra-section spacing ("8dp between content areas" scaled up for desktop/body 18px); Atlassian "medium 12–24" band = "vertical spacing between elements in cards" | ✓ Textbook |
| 36 inter-group | Proximity ratio: inter-group = 3× intra-group (12→36); Carbon "Creating hierarchy"; Atlassian "large" band starts 32 | ✓ Strong |
| Gutter 32 | Material tablet/desktop margins 24dp; Windows Settings 56epx; Fluent NavigationView 24px; Atlassian large-band page spacing 32 | ✓ Inside the official range (24–56) |
| Rail 264 | M3 navigation drawer region; Windows NavigationView pane defaults 280–320px (56epx content margins imply a rail well above 240) | ✓ In-band, slightly compact |
| Row 42 | Dense-desktop band: Material dense single-line 40dp (13sp), standard 48dp (16sp); Fluent 52px header rows | ✓ Between dense and standard — right for a mouse-first panel |
| Body 18px | Apple macOS default 13pt is smaller; Material body 16sp. 18px is generous for a desktop panel but consistent with a "spacious = calm" M3 personality at pixel-font sizes | ✓ Acceptable; keep rows ≥42 to host it |
| Two-tier rhythm only | M3: implicit grouping via open space is the preferred device; Carbon: sections without dividers | ✓ Matches |

### What contradicts (with receipts)

1. **6 is off-grid.** No Material/Carbon/Polaris ladder step is 6; only Atlassian includes it (space.075). Worse: our glyph grid is 9px, so 6px is not a multiple of either the 4px industry base or our own 9px grid. 6 = 2/3 of 9 — it lands glyphs on half-cells. **Candidate fix: 9 or 4/8.** (Sources: all three ladders, §3; 9px grid from our own font.)
2. **36 is on no published ladder** (Carbon jumps 32→40; Atlassian 32→40; Polaris 32→40). It's *between* steps everywhere. If we want a third tier, 32 or 40 are the citable numbers. (§3 comparison table.)
3. **Gutter 32 vs Windows Settings 56epx:** we're at the tight end of the official range. Defensible for a dense utility panel (Fluent "12epx for utility"), but if groups are nested in boxed containers the Windows guidance says margins should grow, not shrink. (§7.)
4. **Row 42 with 18px body:** Material's formula (row = lines×line-height + 2×padding) gives 18px text a ~24–27px line box → a single-line row of 42 leaves ~7.5px vertical padding, below the dense-48/40 pattern's 8dp minimum and below Apple's "~12pt padding around bezelled elements" for any row that acts as a bezelled control. 44–48px is the defended number at 18px body. (§4, §6; Apple accessibility.)
5. **Touch-target floors don't apply, mouse floors do:** our 42px row and any 20px icons are fine against Apple macOS 20×20pt minimum, but icons smaller than 20px in rows would fail Apple's desktop minimum, and sub-24px row targets would fail WCAG 2.5.8 if stacked with <4px gaps. (§6.)

### Direct implications if we tighten to the research

- A **4/8-based ladder** that still respects the 9px glyph grid: 4 (icon-to-text), 9 or 12 (intra-row gaps / intra-group), 24 (group padding), 32 or 36→32 (inter-group), 32 gutter, rail 264, rows 44 (or 48 with standard-density ambition).
- Keep the 12/36 relationship (1:3) — that ratio is the strongest-validated thing we already do.
- If adding a third tier: heading-to-group space above should exceed the 36 between groups' rows (NN/g heading proximity), e.g. 36 above a group header, 9–12 below it.
- Divider policy: only inside tables/lists of repeating data (Polaris), prefer open space (M3).
- Optical: icon boxes get extra padding relative to text (Material live-area pattern); don't center icon and text boxes identically.

## Source list

Primary: m1.material.io (metrics-keylines, lists, icons), m3.material.io via md3e-skill mirror (grids-spacing/spacing, grids, density; components/lists/specs; components/navigation-rail/specs), carbondesignsystem.com (elements/spacing/overview), atlassian.design (foundations/spacing), polaris.shopify.com/tokens/spacing + /design/layout (via web.archive.org), developer.apple.com HIG (layout, sidebars, accessibility), learn.microsoft.com (windows app silhouettes; navigationview), developer.gnome.org HIG (boxed-lists, sidebars), w3.org (WCAG 2.2 Understanding SC 2.5.8), lawsofux.com (law-of-proximity), nngroup.com (articles/gestalt-proximity), fluent2.microsoft.design (root; no spacing ladder published).
