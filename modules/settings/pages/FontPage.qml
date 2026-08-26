pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// FONT: which face every word in the shell is set in.
//
// A sub-page of Appearance rather than a row on it, because the answer is a
// list as long as the machine's font directory and a list that long is a page,
// not a control. The row on Appearance says which one is worn and leads here.
//
// THE FAMILIES COME FROM fontconfig, not from Qt. `fc-list : family` is the
// list every other program on the box draws from, so the page cannot offer a
// face Qt would fail to find, and cannot miss one that was installed after the
// shell started being written. One process, once, when the page is built.
//
// A LINE IS ONE FONT AND CAN NAME IT SEVERAL WAYS: fontconfig prints every
// family name a file carries, comma-separated ("FiraCode Nerd Font,FiraCode
// Nerd Font Ret"), and the first is the canonical one the others alias. Only
// the first is kept, so one file is one row. Styles share a family and are not
// printed at all, which is why the list is families and not weights.
//
// WORN IMMEDIATELY, like the palettes: the press writes `font.family` and
// every StyledText in the shell re-binds. There is no preview mode, because
// the whole shell IS the preview and it is a second press to go back.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // Sorted without regard to case, because fontconfig's own order is file
    // order and "adobe" after "Zilla" is a list nobody can scan.
    property var families: []

    Process {
        id: lister

        command: ["fc-list", ":", "family"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                for (const line of text.split("\n")) {
                    const name = line.split(",")[0].trim();
                    if (!name || seen[name])
                        continue;
                    seen[name] = true;
                    out.push(name);
                }
                out.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
                root.families = out;
            }
        }
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        // What the shell wears now. A fact, not a control: pressing it would
        // choose what is already chosen.
        SettingsCard {
            title: "Current"

            SettingsRow {
                label: Appearance.font.family
                detail: "this is what the shell wears now; tap a family below to wear it"
                interactive: false
            }
        }

        // THE ONE THING A LIST OF FACES CANNOT SAY: that changing the face does
        // not change the sizes. The three tiers are whole multiples of the
        // font base (config/Config.qml's font block explains why 9), chosen so
        // a pixel font sits on the device grid; a face that is not a pixel
        // font does not need that and is not hurt by it, it simply takes the
        // same three sizes.
        SettingsCard {
            title: "About sizes"

            SettingsRow {
                icon: "info"
                label: "Sizes stay on the pixel grid"
                detail: "the shell's three text sizes are whole multiples of the font base, so a pixel face like Monocraft stays crisp; another family simply takes those same sizes"
                interactive: false
            }
        }

        // Hundreds of rows, and that is fine: the page scrolls, and a picker
        // that hid most of its options behind a search box would be a picker
        // for faces you already know the name of.
        SettingsCard {
            title: `Families, ${root.families.length} installed`

            Repeater {
                model: root.families

                delegate: SettingsRow {
                    id: row

                    required property string modelData

                    label: row.modelData
                    selected: Config.values.font.family === row.modelData
                    onActivated: Config.set("font.family", row.modelData)

                    // THE FACE ITSELF, on the right, because a family's name
                    // says nothing about what it looks like and this is the
                    // one page where that is the whole question. Qt loads a
                    // family by name on demand, so this costs nothing until
                    // the row is on screen. Sample text rather than the name
                    // again: a face is judged on its figures and its
                    // lowercase, not on how it spells itself.
                    StyledText {
                        text: "Aa Bb 0123"
                        font.family: row.modelData
                        color: Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
