# VIA boards: light the bound keys

Status: done

Rows: Input › Keyboard › Board (from file), and the keyboard preview. An
imported VIA definition labels keys by matrix position, so the preview cannot
light the keys the shell binds.

## What to build

- Read the board's keymap (VIA's saved keymap .json, or over raw HID) to map
  matrix positions to keycodes, then light keys the way the built-in boards do.

## Built

- A second, optional import under the VIA layout row: a path field for the
  keymap VIA's Save writes (`{name, vendorProductId, macros, layers: [[keycode
  strings in matrix order]], encoders}`, from the-via/app `save-load.tsx`).
  It is stored as `cheatsheet.keymap` in `~/.config/banditshell/keyboards/`,
  named after the stored definition (`<name>.keymap.json`), the way
  `Keyboards.use` stores the definition.
- `keyboards.js`: `parseKeymap`, `keymapLegends`, `applyLegends`. The keymap
  must carry the definition's vendorProductId (`vendorId * 65536 + productId`)
  and fill its `rows * cols` matrix; position `n` is matrix `row,col` with
  `row = n / cols`. Layer 0 is read. Keycodes map to the keysyms Hyprland
  binds use: letters, digits, F1 to F24, punctuation, mods, arrows, nav, numpad,
  media and brightness keys. Mod-taps and layer-taps act as their tap key,
  `MO(n)` and friends draw `Fn<n>`, and KC_NO, KC_TRNS and anything unknown
  bind nothing and keep their matrix spot as the legend.
- Refusals use the definition import's voice: "the file has no layers, so it
  is not a VIA keymap", "the file is a definition, not a keymap · import it
  under VIA layout", the reverse for a keymap given as the definition, and a
  vendorProductId or size mismatch. A stored keymap that stops matching the
  definition (another board imported) is dropped with the reason.
- The sheet takes legends, roles and mods from the keymap. The panel preview
  lights by keysym through `Boards.withLegends` and `Boards.struck`.
  Without a keymap the preview stays unlit, as before.
- Tested in node against a hand-built definition and keymap
  (`tests/fixtures/via_bandit_mini*.json`). Not built: reading the keymap over
  raw HID.
- To check: a real VIA export from a real board (only the format, taken from
  VIA's source, and a hand-made fixture were used), and lit keys in the panel
  preview with real binds (headless render had no binds).
