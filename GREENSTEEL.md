# GREENSTEEL

A design system for this machine: cool anodised-green metal, pixel type, smooth corners.

**Source of truth for colour is `theme/greensteel.conf`.** That file is Hyprland syntax and is
sourced by `hyprland.conf` before everything else. This document explains the system and gives
paste-ready translations for every other stack on this box. If a value here and a value there
ever disagree, `greensteel.conf` wins and this file is the thing to fix.

---

## 1. The idea

Metal does not read as metal because of its hue. It reads as metal because of a **luminance
ramp with a specular spike**: a broad dark body, and one small very bright region where a
light source catches an edge. Change the hue of that arrangement and you get anodised metal,
which is what this is. Paint a mid-green over a flat surface and you get green plastic.

Three rules follow, and they are the whole system:

1. **One hue family.** Everything sits near 158 degrees, green leaning cyan. Cyan-lean is what
   makes it read cool and metallic rather than olive or lime.
2. **Chroma only at the top.** The dark end of the ramp is nearly neutral, tinted just enough
   to not be grey. Saturation appears only in the accents. Saturated dark greens read as
   plastic or as a terminal from 1983.
3. **Spend most of the surface dark.** The bright stop only reads as a highlight if it is
   outnumbered. A gradient that is 50 percent bright is a gradient. A gradient that is 15
   percent bright is a lit edge.

---

## 2. Palette

### The ramp

Near-black to silvery white, one hue family. `L` is relative luminance (0 to 1), which is what
actually determines whether two of these are distinguishable.

| Token        | Hex       | L      | Role                                              |
| ------------ | --------- | ------ | ------------------------------------------------- |
| `gsVoid`     | `#070C0A` | 0.0033 | Deepest background, the space behind everything   |
| `gsAbyss`    | `#0D1512` | 0.0067 | Default window and panel background               |
| `gsDark`     | `#16211C` | 0.0134 | Raised surface, card, input well                  |
| `gsBody`     | `#22322B` | 0.0280 | The metal body itself, unlit                      |
| `gsBrushed`  | `#33493F` | 0.0583 | Brushed texture, hairlines, dividers              |
| `gsEdge`     | `#4C6B5C` | 0.1282 | Borders, outlines, disabled text                  |
| `gsLit`      | `#6E9384` | 0.2585 | Lit edge, secondary text at large sizes           |
| `gsPale`     | `#9DBDAF` | 0.4666 | Muted body text                                   |
| `gsSilver`   | `#C9E2D7` | 0.7172 | Default body text                                 |
| `gsChrome`   | `#EAF6F0` | 0.8970 | Emphasised text                                   |
| `gsWhite`    | `#F7FDFA` | 0.9693 | Specular highlight only, not a text colour        |

The ramp roughly doubles in luminance per step, which is why adjacent tokens are always
distinguishable but never jarring. If you need a value between two steps, you almost certainly
need a different token instead.

### Accents

Where the green is actually allowed to saturate.

| Token         | Hex       | Role                                                       |
| ------------- | --------- | ---------------------------------------------------------- |
| `gsVerdigris` | `#3FBF8F` | Deep accent, fills, active backgrounds                     |
| `gsLush`      | `#5FD99A` | Primary accent, the main "this is on" colour               |
| `gsPhosphor`  | `#8CFFC0` | Brightest accent, pixel text, anything that should glow     |

### Secondary metals

For states that must not be mistaken for a normal window. Different metals, not different
hues, which is what keeps them inside the system.

| Token        | Hex       | Role                                     |
| ------------ | --------- | ---------------------------------------- |
| `gsMint`     | `#5FF2C4` | Floating windows, transient surfaces     |
| `gsMintDim`  | `#1E6B57` | Floating, unfocused                      |
| `gsBrass`    | `#D8C48C` | Pinned windows, warnings, "held" states  |
| `gsBrassDim` | `#6B5C36` | Pinned, unfocused                        |

---

## 3. Contrast: what is allowed on what

Measured WCAG ratios. These are not suggestions, they are the reason the system stays legible
when you use it somewhere new.

Against `gsAbyss` `#0D1512`, the default background:

| Foreground    | Ratio    | Verdict                          |
| ------------- | -------- | -------------------------------- |
| `gsBrushed`   | 1.91:1   | **Never text.** Dividers only.   |
| `gsEdge`      | 3.15:1   | UI borders and disabled text only |
| `gsLit`       | 5.44:1   | AA body                          |
| `gsPale`      | 9.12:1   | AAA body                         |
| `gsSilver`    | 13.54:1  | AAA body                         |
| `gsChrome`    | 16.71:1  | AAA body                         |
| `gsVerdigris` | 8.00:1   | AAA body                         |
| `gsLush`      | 10.48:1  | AAA body                         |
| `gsPhosphor`  | 15.16:1  | AAA body                         |
| `gsMint`      | 13.22:1  | AAA body                         |
| `gsBrass`     | 10.76:1  | AAA body                         |

Against `gsBody` `#22322B`, if you ever put text on the metal itself, everything drops about
1.4x: `gsLit` falls to 3.96:1 and stops being body text, `gsVerdigris` falls to 5.81:1.

**The hard rules:**

- Never put text on `gsBrushed` or `gsEdge`. They are structure, not surface.
- Text goes on `gsVoid`, `gsAbyss`, or `gsDark`. Those three are the only backgrounds.
- `gsWhite` is a highlight, not a text colour. Using it as text throws away the one value that
  makes the specular spike special.

---

## 4. Type

**The font is Monocraft**, `/usr/share/fonts/TTF/Monocraft.ttf`, family name `Monocraft`.

### The pixel grid is real, and it constrains sizes

Monocraft has `unitsPerEm = 1080`, and every glyph coordinate in the font is a multiple of 120
units (verified against the outlines, the gcd is exactly 120). So **one source pixel is 120
units, and one em is exactly 9 source pixels.**

That means the font renders crisply only when the font size in **device** pixels is a multiple
of 9. At any other size, one source pixel maps to a fractional number of device pixels and the
renderer has to smear stems that were designed to be exactly one pixel wide.

The crisp ladder:

| Size  | Device px per source px | Feel                                        |
| ----- | ----------------------- | ------------------------------------------- |
| 9px   | 1x                      | Dense readouts only, very small             |
| 18px  | 2x                      | **The workhorse.** Bars, body, most UI      |
| 27px  | 3x                      | Headings, the one thing a view is about     |
| 36px  | 4x                      | Clocks, splash, large display               |

Watch out for fractional display scaling. The commented ultrawide line in `hyprland.conf` uses
`scale 0.8`, and at that scale an 18px request lands on 14.4 device pixels and the crispness is
gone. Pixel type wants integer scale factors.

### Three sizes, and probably only two

The house rule is at most three font sizes in a project, from one token file, with hierarchy
carried by weight, colour and spacing rather than size. Monocraft makes that easier than usual,
because the ladder above is coarse: there is no crisp size between 9 and 18, so the usual drift
into 14/15/16 is simply not available.

Practical recommendation for anything on this machine:

- `normal` = **18px**. Nearly everything.
- `large` = **27px**. One per view.
- For "small", do **not** drop to 9px. Keep 18px and demote with colour instead: `gsPale` or
  `gsLit` instead of `gsSilver`. A dim `normal` reads as smaller without being smaller, and it
  stays crisp. Reserve 9px for genuinely dense numeric readouts.

Monocraft is a single weight, so bold is unavailable as a hierarchy tool. That pushes even more
work onto colour and spacing, which is the correct place for it anyway.

---

## 5. Corners

**Every rounded corner is G2 continuous. Never a plain circular arc.**

A default rounded rectangle is G1: the straight edge meets the arc with the curvature jumping
instantly from 0 to 1/r. The eye catches that as a "pinch", most visibly at large radii, on
dark surfaces, and under blur or a shadow, which describes this entire theme. G2 ramps the
curvature in and out, so the corner reads as one continuous form.

### Hyprland

Hyprland gives this natively. `decoration:rounding_power` is the exponent of a superellipse,
`|x|^p + |y|^p = r^p`:

- `p = 2` is a plain circular arc. Curvature jumps at the join. This is G1, do not use it.
- `p > 2` drives curvature to **zero** where the corner meets the straight edge, which is
  exactly the G2 condition.
- Current setting: `rounding = 15`, `rounding_power = 4.0`.

Radius needs compensating when you raise the power. The diagonal bite of a superellipse is
`sqrt(2) * r * (1 - 2^(-1/p))`, so at the same `r`, `p = 4` cuts only 0.225r off the corner
versus 0.414r at `p = 2`. That is why the radius went 10 to 15 when the power went 2 to 4: to
keep the corner looking the same size.

### Everywhere else

| Stack        | How                                                                        |
| ------------ | -------------------------------------------------------------------------- |
| CSS          | `border-radius` is G1 only. Use an SVG or `clip-path` squircle, or a mask. `corner-shape: squircle` is not broadly shippable, check support before relying on it. |
| QML / Qt     | `Rectangle.radius` is G1. Use `Shape` + `ShapePath { PathSvg { ... } }` with `preferredRendererType: Shape.CurveRenderer`. |
| SVG / canvas | Emit the squircle path directly.                                           |
| GTK          | CSS, so same limitation as CSS.                                            |

Build one smooth-corner primitive per project and route every rounded shape through it. A
corner that is not going through that primitive is a bug. The full Figma-squircle construction
(arc plus curvature-easing Beziers, with the per-corner budget maths) is in
`~/.claude/rules/g2-corners.md`.

Known gap on this box: `scripts/roundmask.py` draws the screen corners as plain cairo arcs, so
the screen corners are still G1 while every window is G2.

---

## 6. Motion

Default to **exponential smoothing** for anything that tracks a position or value:

```javascript
position += (target - position) * (1 - Math.exp(-speed * dt));
```

It moves fast when far and slow when close, and it is safe at any framerate or timestep.
Typical `speed` is 5 to 15, `dt` about 0.016 at 60fps. Use fixed-duration easing only when the
timing itself is the point, and springs only when you actually want overshoot.

The theme's own motion is the border sheen: `animation = borderangle, 1, 500, linear, loop`
rotates the active window's gradient so the specular stop travels around the frame like light
moving over metal. The number is a period in deciseconds, so **higher is slower**. 500 is one
rotation per 50 seconds, slow enough that you notice it only when you look for it. Delete the
line for a static highlight.

---

## 7. Terminal palette

Derived from the ramp above, with the non-green hues pulled toward the same cool, slightly
desaturated register so they sit inside the system instead of on top of it. Every entry except
bright black clears AA body contrast on `gsAbyss`; bright black is a decoration colour, not a
text colour, so its 1.91:1 is intentional.

| ANSI | Name           | Hex       | On `gsAbyss` |
| ---- | -------------- | --------- | ------------ |
| 0    | black          | `#0D1512` | background   |
| 8    | bright black   | `#33493F` | 1.91:1       |
| 1    | red            | `#E06B7A` | 5.78:1       |
| 9    | bright red     | `#FF8C99` | 8.35:1       |
| 2    | green          | `#5FD99A` | 10.48:1      |
| 10   | bright green   | `#8CFFC0` | 15.16:1      |
| 3    | yellow         | `#D8C48C` | 10.76:1      |
| 11   | bright yellow  | `#F0DCA6` | 13.67:1      |
| 4    | blue           | `#6FA9C7` | 7.22:1       |
| 12   | bright blue    | `#93C8E2` | 10.24:1      |
| 5    | magenta        | `#B08CC9` | 6.57:1       |
| 13   | bright magenta | `#CBA8E0` | 9.02:1       |
| 6    | cyan           | `#5FF2C4` | 13.22:1      |
| 14   | bright cyan    | `#93FFDF` | 15.54:1      |
| 7    | white          | `#C9E2D7` | 13.54:1      |
| 15   | bright white   | `#F7FDFA` | 17.99:1      |

---

## 8. Paste-ready translations

### Hyprland (live)

Already wired. `hyprland.conf` sources `theme/greensteel.conf`, and `hyprland/general.conf` and
`hyprland/rules.conf` refer to `$gs*` variables. Never write a literal hex into those files.

### CSS: waybar, GTK 3/4, any web surface

```css
:root {
  --gs-void: #070C0A;   --gs-abyss: #0D1512;  --gs-dark: #16211C;
  --gs-body: #22322B;   --gs-brushed: #33493F; --gs-edge: #4C6B5C;
  --gs-lit: #6E9384;    --gs-pale: #9DBDAF;   --gs-silver: #C9E2D7;
  --gs-chrome: #EAF6F0; --gs-white: #F7FDFA;

  --gs-verdigris: #3FBF8F; --gs-lush: #5FD99A; --gs-phosphor: #8CFFC0;
  --gs-mint: #5FF2C4;      --gs-brass: #D8C48C;

  /* three sizes, no inline values anywhere else */
  --fs-small: 18px;  /* demote with colour, not size */
  --fs-normal: 18px;
  --fs-large: 27px;

  --font-pixel: "Monocraft", monospace;
}

/* The metal edge, as a border-image so the specular stop survives */
.metal-edge {
  border: 2px solid transparent;
  border-image: linear-gradient(45deg,
    #16211C 0%, #3FBF8F 25%, #F7FDFA 50%, #5FD99A 75%, #22322B 100%) 1;
}
```

Remember `border-radius` is G1. Route rounded shapes through a squircle mask, see section 5.

### QML: quickshell, caelestia, myshell

```qml
// Greensteel.qml, a singleton. pragma Singleton + qmldir entry.
pragma Singleton
import QtQuick

QtObject {
    readonly property color void_:     "#070C0A"
    readonly property color abyss:     "#0D1512"
    readonly property color dark:      "#16211C"
    readonly property color body:      "#22322B"
    readonly property color brushed:   "#33493F"
    readonly property color edge:      "#4C6B5C"
    readonly property color lit:       "#6E9384"
    readonly property color pale:      "#9DBDAF"
    readonly property color silver:    "#C9E2D7"
    readonly property color chrome:    "#EAF6F0"
    readonly property color white_:    "#F7FDFA"

    readonly property color verdigris: "#3FBF8F"
    readonly property color lush:      "#5FD99A"
    readonly property color phosphor:  "#8CFFC0"
    readonly property color mint:      "#5FF2C4"
    readonly property color brass:     "#D8C48C"

    readonly property string fontPixel: "Monocraft"
    readonly property int fsSmall:  18   // demote with colour, not size
    readonly property int fsNormal: 18
    readonly property int fsLarge:  27

    readonly property real cornerRadius: 15
    readonly property real cornerSmoothing: 0.6
}
```

`Rectangle.radius` is G1. Use a `Shape` with a squircle `PathSvg` and
`preferredRendererType: Shape.CurveRenderer`.

### kitty

```conf
font_family      Monocraft
font_size        18.0

background       #0D1512
foreground       #C9E2D7
cursor           #8CFFC0
selection_background #33493F
selection_foreground #EAF6F0
active_border_color   #5FD99A
inactive_border_color #33493F
url_color        #5FF2C4

color0  #0D1512
color8  #33493F
color1  #E06B7A
color9  #FF8C99
color2  #5FD99A
color10 #8CFFC0
color3  #D8C48C
color11 #F0DCA6
color4  #6FA9C7
color12 #93C8E2
color5  #B08CC9
color13 #CBA8E0
color6  #5FF2C4
color14 #93FFDF
color7  #C9E2D7
color15 #F7FDFA
```

### rofi (`.rasi`)

```rasi
* {
    gs-abyss:    #0D1512;
    gs-dark:     #16211C;
    gs-brushed:  #33493F;
    gs-silver:   #C9E2D7;
    gs-chrome:   #EAF6F0;
    gs-lush:     #5FD99A;
    gs-phosphor: #8CFFC0;

    background-color: @gs-abyss;
    text-color:       @gs-silver;
    font:             "Monocraft 18";
}
window   { border: 2px; border-color: @gs-lush; border-radius: 15px; }
element selected { background-color: @gs-dark; text-color: @gs-phosphor; }
```

### fuzzel

```ini
[main]
font=Monocraft:size=18
[colors]
background=0D1512ff
text=C9E2D7ff
match=8CFFC0ff
selection=16211Cff
selection-text=EAF6F0ff
border=5FD99Aff
[border]
radius=15
```

### tmux

```conf
set -g status-style              "bg=#0D1512,fg=#9DBDAF"
set -g window-status-current-style "bg=#22322B,fg=#8CFFC0"
set -g pane-border-style         "fg=#33493F"
set -g pane-active-border-style  "fg=#5FD99A"
set -g message-style             "bg=#16211C,fg=#EAF6F0"
set -g mode-style                "bg=#33493F,fg=#F7FDFA"
```

### btop

```conf
theme_background = False
# or point theme_file at a generated greensteel.theme using the ANSI table above
```

---

## 9. Extending the system

When you need a colour that is not here, in order of preference:

1. **Use an existing token.** Most "I need a new colour" moments are a token you have not read
   the table for yet.
2. **Move along the ramp.** Need something dimmer than `gsSilver`? That is `gsPale`, not a new
   hex.
3. **Reach for a secondary metal.** A state that must stand apart is mint or brass, not a new
   hue invented on the spot.
4. **Only then add a token,** and add it to `theme/greensteel.conf` first, then here. A hex
   literal living in an app config is how a system dies.

Checklist for any new surface on this machine:

- [ ] Background is `gsVoid`, `gsAbyss`, or `gsDark`. Nothing else.
- [ ] Text is `gsPale` or lighter. Never on `gsBrushed` or `gsEdge`.
- [ ] Font size is 18 or 27, from a token, never inline.
- [ ] Corners go through a G2 primitive, not a raw radius.
- [ ] Motion uses exponential smoothing unless there is a reason not to.
- [ ] The bright end is used sparingly. If the highlight is everywhere, it is not a highlight.

---

## 10. Files

| Path                                    | What                                          |
| --------------------------------------- | --------------------------------------------- |
| `theme/greensteel.conf`                 | **Source of truth.** Palette, Hyprland syntax |
| `hyprland.conf`                         | Sources the palette before anything else      |
| `hyprland/general.conf`                 | Borders, corners, shadow, sheen animation     |
| `hyprland/rules.conf`                   | Per-window borders: mint floating, brass pinned |
| `theme/backups/2026-08-01-purple-cyan/` | The previous purple/cyan theme, with a restore note |
| `~/.claude/rules/g2-corners.md`         | Full squircle construction and per-stack detail |
| `~/.claude/rules/type-scale.md`          | The three-sizes rule in full                  |
| `~/.claude/rules/animation-smoothing.md` | The smoothing rule in full                    |
