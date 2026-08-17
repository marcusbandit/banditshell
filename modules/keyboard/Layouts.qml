import QtQuick

// WHAT IS ON THE BOARD. Data only: this file has no opinion about where any of
// it goes, because nothing here knows a pixel.
//
// A row is a list of keys and a key carries a WIDTH IN UNITS, never a position.
// Where a key lands is the running total of the units to its left, times a pitch
// the panel works out from its own width, which is the whole reason a board can
// be redrawn at any size and on any screen without a second set of numbers
// (~/.claude/rules/math-over-hardcoding.md). Every row here sums to the same
// `units` total; the panel checks that rather than trusting it, because a row
// that quietly summed to 14.75 would draw a board with one short line and the
// cause would not be visible on screen.
//
// FOUR KINDS OF KEY, distinguished by which field they carry:
//
//   lo / up   a PRINTABLE key: the character it types unshifted, and the one it
//             types shifted. Sent as a literal character rather than as a
//             keysym, so what the cap says is what arrives regardless of which
//             xkb layout the focused window is using. See services/Keystrokes.type.
//   sym       a NAMED key with no character: Return, BackSpace, F5, Left. Sent
//             as a keysym, because there is nothing else to send.
//   mod       a MODIFIER, which types nothing and latches instead.
//   act       something the BOARD does rather than something the window
//             receives: turn to the other page, take up room, or go away.
//
// `icon` is a Material Symbols name and wins over the cap text when present.
// Modifiers are named in WORDS rather than drawn, and that is the one place this
// board deliberately parts company with a phone's: "ctrl" is a word people look
// for, and there is no glyph for it that anyone would recognise faster. The keys
// that DO take icons are the ones whose marks are universal (backspace, enter,
// shift, tab, the arrows) or that have no word short enough to fit.
//
// `tone` is almost never written here. It is derived from what the key is (see
// OnScreenKeyboard.toneOf) so that adding a letter cannot forget to say it is
// one; Return carries it explicitly because "this is the key that means done"
// is a fact about the key rather than about its type.
QtObject {
    id: root

    // THE ONE PLACE THE BOARD'S WIDTH IS DECIDED. Every row must total this, and
    // the number itself is arbitrary: it is the ISO board's own proportions, so
    // that the letters sit where a hand expects them relative to each other.
    readonly property real units: 15

    // Which layer a board starts on, and the one `abc` returns to.
    readonly property string base: "letters"

    readonly property var layers: ({
            // The ordinary board. Danish and the function row live one layer
            // away rather than on a modifier, because a tablet has no modifier
            // to hold: every extra character has to be reachable in one tap
            // from somewhere, and a layer is the only somewhere there is.
            letters: [
                [
                    {
                        sym: "Escape",
                        cap: "esc"
                    },
                    {
                        lo: "1",
                        up: "!"
                    },
                    {
                        lo: "2",
                        up: "@"
                    },
                    {
                        lo: "3",
                        up: "#"
                    },
                    {
                        lo: "4",
                        up: "$"
                    },
                    {
                        lo: "5",
                        up: "%"
                    },
                    {
                        lo: "6",
                        up: "^"
                    },
                    {
                        lo: "7",
                        up: "&"
                    },
                    {
                        lo: "8",
                        up: "*"
                    },
                    {
                        lo: "9",
                        up: "("
                    },
                    {
                        lo: "0",
                        up: ")"
                    },
                    {
                        lo: "-",
                        up: "_"
                    },
                    {
                        lo: "=",
                        up: "+"
                    },
                    // REPEATS, like the arrows and unlike everything else. A
                    // held backspace is how a line gets deleted, and a board
                    // that made you tap forty times would be one nobody used
                    // for anything longer than a search box.
                    {
                        sym: "BackSpace",
                        icon: "backspace",
                        units: 2,
                        repeats: true
                    }
                ],
                [
                    {
                        sym: "Tab",
                        icon: "keyboard_tab",
                        units: 1.5
                    },
                    {
                        lo: "q",
                        up: "Q"
                    },
                    {
                        lo: "w",
                        up: "W"
                    },
                    {
                        lo: "e",
                        up: "E"
                    },
                    {
                        lo: "r",
                        up: "R"
                    },
                    {
                        lo: "t",
                        up: "T"
                    },
                    {
                        lo: "y",
                        up: "Y"
                    },
                    {
                        lo: "u",
                        up: "U"
                    },
                    {
                        lo: "i",
                        up: "I"
                    },
                    {
                        lo: "o",
                        up: "O"
                    },
                    {
                        lo: "p",
                        up: "P"
                    },
                    {
                        lo: "[",
                        up: "{"
                    },
                    {
                        lo: "]",
                        up: "}"
                    },
                    {
                        lo: "\\",
                        up: "|",
                        units: 1.5
                    }
                ],
                [
                    {
                        mod: "ctrl",
                        cap: "ctrl",
                        units: 1.75
                    },
                    {
                        lo: "a",
                        up: "A"
                    },
                    {
                        lo: "s",
                        up: "S"
                    },
                    {
                        lo: "d",
                        up: "D"
                    },
                    {
                        lo: "f",
                        up: "F"
                    },
                    {
                        lo: "g",
                        up: "G"
                    },
                    {
                        lo: "h",
                        up: "H"
                    },
                    {
                        lo: "j",
                        up: "J"
                    },
                    {
                        lo: "k",
                        up: "K"
                    },
                    {
                        lo: "l",
                        up: "L"
                    },
                    {
                        lo: ";",
                        up: ":"
                    },
                    {
                        lo: "'",
                        up: "\""
                    },
                    {
                        sym: "Return",
                        icon: "keyboard_return",
                        tone: "accent",
                        units: 2.25
                    }
                ],
                [
                    {
                        mod: "shift",
                        icon: "shift",
                        units: 2
                    },
                    {
                        lo: "z",
                        up: "Z"
                    },
                    {
                        lo: "x",
                        up: "X"
                    },
                    {
                        lo: "c",
                        up: "C"
                    },
                    {
                        lo: "v",
                        up: "V"
                    },
                    {
                        lo: "b",
                        up: "B"
                    },
                    {
                        lo: "n",
                        up: "N"
                    },
                    {
                        lo: "m",
                        up: "M"
                    },
                    {
                        lo: ",",
                        up: "<"
                    },
                    {
                        lo: ".",
                        up: ">"
                    },
                    {
                        lo: "/",
                        up: "?"
                    },
                    {
                        mod: "shift",
                        icon: "shift"
                    },
                    {
                        sym: "Up",
                        icon: "arrow_upward",
                        repeats: true
                    },
                    {
                        sym: "Delete",
                        cap: "del",
                        repeats: true
                    }
                ],
                [
                    {
                        mod: "ctrl",
                        cap: "ctrl",
                        units: 1.25
                    },
                    {
                        mod: "super",
                        cap: "super",
                        units: 1.25
                    },
                    {
                        mod: "alt",
                        cap: "alt",
                        units: 1.25
                    },
                    {
                        lo: " ",
                        up: " ",
                        icon: "space_bar",
                        units: 4.5
                    },
                    // `?123` AND `ABC` RATHER THAN `more` AND `abc`, which is
                    // the phone convention and worth borrowing: it says what is
                    // ON the other page instead of merely that there is one.
                    {
                        act: "page",
                        to: "more",
                        cap: "?123",
                        units: 1.25
                    },
                    // DOES THE BOARD TAKE UP ROOM. Lit while it does, the same
                    // way a held modifier is lit, because it is the same kind of
                    // fact: a state that outlasts the tap. See Tablet.docked.
                    {
                        act: "dock",
                        icon: "splitscreen",
                        units: 1.25
                    },
                    // THE WAY OUT, and it has to be ON the board. Every other
                    // panel in this shell is dismissed by clicking off it, which
                    // this one cannot be: it is the panel you keep open while
                    // working in the window underneath, so a click outside must
                    // reach that window. Without this key a folded machine with
                    // no physical Escape has nothing to press.
                    {
                        act: "hide",
                        icon: "keyboard_hide",
                        units: 1.25
                    },
                    {
                        sym: "Left",
                        icon: "arrow_back",
                        repeats: true
                    },
                    {
                        sym: "Down",
                        icon: "arrow_downward",
                        repeats: true
                    },
                    {
                        sym: "Right",
                        icon: "arrow_forward",
                        repeats: true
                    }
                ]
            ],

            // The second layer: the function row, the letters this machine's
            // other keyboard layout has that US does not, and the navigation
            // block. Same silhouette as the first, so the modifiers, space and
            // the way out do not move under a hand that has learnt where they
            // are: only the middle of the board changes.
            more: [
                [
                    {
                        sym: "Escape",
                        cap: "esc"
                    },
                    {
                        sym: "F1",
                        cap: "F1"
                    },
                    {
                        sym: "F2",
                        cap: "F2"
                    },
                    {
                        sym: "F3",
                        cap: "F3"
                    },
                    {
                        sym: "F4",
                        cap: "F4"
                    },
                    {
                        sym: "F5",
                        cap: "F5"
                    },
                    {
                        sym: "F6",
                        cap: "F6"
                    },
                    {
                        sym: "F7",
                        cap: "F7"
                    },
                    {
                        sym: "F8",
                        cap: "F8"
                    },
                    {
                        sym: "F9",
                        cap: "F9"
                    },
                    {
                        sym: "F10",
                        cap: "F10"
                    },
                    {
                        sym: "F11",
                        cap: "F11"
                    },
                    {
                        sym: "F12",
                        cap: "F12"
                    },
                    {
                        sym: "BackSpace",
                        icon: "backspace",
                        units: 2,
                        repeats: true
                    }
                ],
                [
                    {
                        sym: "Tab",
                        icon: "keyboard_tab",
                        units: 1.5
                    },
                    {
                        lo: "æ",
                        up: "Æ"
                    },
                    {
                        lo: "ø",
                        up: "Ø"
                    },
                    {
                        lo: "å",
                        up: "Å"
                    },
                    {
                        lo: "ä",
                        up: "Ä"
                    },
                    {
                        lo: "ö",
                        up: "Ö"
                    },
                    {
                        lo: "ü",
                        up: "Ü"
                    },
                    {
                        lo: "ß",
                        up: "ẞ"
                    },
                    {
                        lo: "é",
                        up: "É"
                    },
                    {
                        lo: "è",
                        up: "È"
                    },
                    {
                        lo: "ñ",
                        up: "Ñ"
                    },
                    {
                        sym: "Home",
                        icon: "first_page"
                    },
                    {
                        sym: "End",
                        icon: "last_page"
                    },
                    {
                        lo: "\\",
                        up: "|",
                        units: 1.5
                    }
                ],
                [
                    {
                        mod: "ctrl",
                        cap: "ctrl",
                        units: 1.75
                    },
                    {
                        lo: "€",
                        up: "€"
                    },
                    {
                        lo: "£",
                        up: "£"
                    },
                    {
                        lo: "¥",
                        up: "¥"
                    },
                    {
                        lo: "¤",
                        up: "¤"
                    },
                    {
                        lo: "°",
                        up: "°"
                    },
                    {
                        lo: "§",
                        up: "§"
                    },
                    {
                        lo: "±",
                        up: "±"
                    },
                    {
                        lo: "«",
                        up: "«"
                    },
                    {
                        lo: "»",
                        up: "»"
                    },
                    {
                        sym: "Insert",
                        cap: "ins"
                    },
                    {
                        sym: "Delete",
                        cap: "del",
                        repeats: true
                    },
                    {
                        sym: "Return",
                        icon: "keyboard_return",
                        tone: "accent",
                        units: 2.25
                    }
                ],
                [
                    {
                        mod: "shift",
                        icon: "shift",
                        units: 2
                    },
                    {
                        lo: "¡",
                        up: "¡"
                    },
                    {
                        lo: "¿",
                        up: "¿"
                    },
                    {
                        lo: "·",
                        up: "·"
                    },
                    {
                        lo: "‹",
                        up: "‹"
                    },
                    {
                        lo: "›",
                        up: "›"
                    },
                    {
                        lo: "“",
                        up: "“"
                    },
                    {
                        lo: "”",
                        up: "”"
                    },
                    {
                        lo: ",",
                        up: "<"
                    },
                    {
                        lo: ".",
                        up: ">"
                    },
                    {
                        lo: "/",
                        up: "?"
                    },
                    {
                        mod: "shift",
                        icon: "shift"
                    },
                    {
                        sym: "Prior",
                        icon: "keyboard_double_arrow_up",
                        repeats: true
                    },
                    {
                        sym: "Print",
                        cap: "prtsc"
                    }
                ],
                [
                    {
                        mod: "ctrl",
                        cap: "ctrl",
                        units: 1.25
                    },
                    {
                        mod: "super",
                        cap: "super",
                        units: 1.25
                    },
                    {
                        mod: "alt",
                        cap: "alt",
                        units: 1.25
                    },
                    {
                        lo: " ",
                        up: " ",
                        icon: "space_bar",
                        units: 4.5
                    },
                    {
                        act: "page",
                        to: "letters",
                        cap: "ABC",
                        units: 1.25
                    },
                    {
                        act: "dock",
                        icon: "splitscreen",
                        units: 1.25
                    },
                    {
                        act: "hide",
                        icon: "keyboard_hide",
                        units: 1.25
                    },
                    {
                        sym: "Home",
                        icon: "first_page"
                    },
                    {
                        sym: "Next",
                        icon: "keyboard_double_arrow_down",
                        repeats: true
                    },
                    {
                        sym: "End",
                        icon: "last_page"
                    }
                ]
            ]
        })
}
