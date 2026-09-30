import QtQuick

QtObject {
    id: root

    readonly property real units: 15

    readonly property string base: "letters"

    readonly property var layers: ({

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

                    {
                        act: "page",
                        to: "more",
                        cap: "?123",
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
