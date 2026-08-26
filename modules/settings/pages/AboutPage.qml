pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// ABOUT: the shell itself.
//
// What it is, why it is built the way it is, and where to read the rest. The
// machine underneath is DevicePage's subject and the compositor, the type and
// the file paths of the running checkout are DeveloperPage's; this page repeats
// none of them. It is the one page that is allowed to say what the shell is FOR,
// in the words DESIGN.md uses, because a settings app that only ever lists
// switches never says what the switches are attached to.
//
// The name and version are a masthead rather than a card. A row is a mark, a
// name and a detail about something else, and "banditshell" is not a fact
// about something else, it is the thing the page is about; the large size and a
// mark of its own beside it is how the page says so.
//
// The "Read more" rows are the only ones that DO anything, and what they do is
// hand a path to xdg-open: which editor, which file manager and which viewer
// are the desktop's decisions, not the shell's. One Process for all of them,
// because `exec` replaces the command each time and three idle processes for
// three rows would be three of something for no reason. The hotkeys row is the
// exception, opening a panel of the shell's own on the screen that holds this
// page.
//
// WIDTH COMES FROM THE FACE, like every page here: fill what the pager hands
// you and ask only for height.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Process {
        id: opener
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        // -------------------------------------------------------- masthead

        Row {
            width: list.width
            spacing: Appearance.padding.normal

            // A PLACEHOLDER UNTIL THE LOGO EXISTS. Rather than a blank square
            // or a stock glyph, the shell's own corner grip, the mark that
            // SettingsFace draws where the page is pushed back into its corner:
            // three ribs across a diagonal, sized from the ribs and not the
            // ribs from the size, in exactly SettingsFace's arithmetic so the
            // two are one drawing at two scales. When a logo is drawn it takes
            // this square and nothing else moves.
            G2Rect {
                id: mark

                readonly property int ribs: 3
                readonly property real pitch: Appearance.padding.small
                readonly property real span: Appearance.font.size.large * 2

                width: mark.span
                height: mark.span
                radius: Appearance.rounding.normal
                color: Appearance.colour.accentFill
                stroke: Appearance.colour.accent
                strokeWidth: Appearance.font.stem

                Repeater {
                    model: mark.ribs

                    G2Rect {
                        id: rib

                        required property int index

                        // Distance from the corner along the diagonal; a chord
                        // across a square corner at perpendicular distance d is
                        // 2d long, so the ribs widen as the corner opens out.
                        readonly property real reach: (rib.index + 1) / (mark.ribs + 1) * mark.span / Math.SQRT2

                        width: rib.reach * 2
                        height: Appearance.font.stem
                        radius: rib.height / 2

                        x: mark.span - rib.reach / Math.SQRT2 - rib.width / 2
                        y: mark.span - rib.reach / Math.SQRT2 - rib.height / 2
                        rotation: -45

                        color: Appearance.colour.accent
                    }
                }
            }

            Column {
                width: list.width - mark.width - Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "banditshell"
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.text
                }

                // `describe` gives a tag or a short hash and appends "-dirty"
                // when the tree has uncommitted edits; the date is the last
                // commit's, which is the version line a hash alone cannot carry.
                StyledText {
                    width: parent.width
                    text: (Device.version || "unknown version") + (Device.commitDate ? ` · ${Device.commitDate}` : "")
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                }

                StyledText {
                    width: parent.width
                    text: "a desktop shell written to be understood"
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textDim
                }
            }
        }

        // ------------------------------------------------------ what it is

        // Inert rows whose detail is a paragraph each, which is what a
        // SettingsRow is for: nothing here is a control, and a claim about the
        // shell that had to fit on one line would be a slogan. Every one of
        // them is a sentence DESIGN.md already makes, shortened, not a new one.
        SettingsCard {
            title: "What it is"

            SettingsRow {
                icon: "architecture"
                label: "Built from scratch, on Quickshell"
                detail: "every widget is written here, so the whole mental model is owned rather than borrowed; caelestia stays on disk as the reference for the hard parts"
                interactive: false
            }

            SettingsRow {
                icon: "gesture"
                label: "Every surface is a gesture"
                detail: "at rest the screen is empty: no bar, no clock, nothing served before it is asked for. Edges and corners are pulled, and the interaction is the request"
                interactive: false
            }

            SettingsRow {
                icon: "blur_on"
                label: "One material"
                detail: "panels are a translucent material the compositor blurs, and everything on them is the palette's light end at an opacity tier; depth comes from layering, never from bevels or gradients"
                interactive: false
            }

            SettingsRow {
                icon: "rounded_corner"
                label: "G2 corners everywhere"
                detail: "every rounded shape is a squircle drawn by one primitive, at the compositor's own rounding, so a panel corner and the window beside it agree"
                interactive: false
            }

            SettingsRow {
                icon: "terminal"
                label: "Everything has a verb"
                detail: "every menu and panel opens from `banditshell <thing>`; hover cannot be scripted, so that is how each one is checked"
                interactive: false
            }
        }

        // ------------------------------------------------------- read more

        SettingsCard {
            title: "Read more"

            SettingsRow {
                icon: "menu_book"
                label: "Design notes"
                detail: "DESIGN.md: the reasons behind every part of it"
                onActivated: opener.exec(["xdg-open", `${Device.shellDir}/DESIGN.md`])
            }

            SettingsRow {
                icon: "folder"
                label: "Source"
                detail: Device.shellDir
                onActivated: opener.exec(["xdg-open", Device.shellDir])
            }

            SettingsRow {
                icon: "description"
                label: "Settings file"
                detail: Config.path
                onActivated: opener.exec(["xdg-open", Config.path])
            }

            // The same call `banditshell hotkeys open` makes, on the screen
            // this page is held on rather than the focused one: the sheet
            // should come up beside the row that asked for it, and with the
            // page pulled out into a window the focus can be anywhere.
            SettingsRow {
                icon: "keyboard"
                label: "Hotkeys"
                detail: "every bind the compositor knows, drawn live"
                onActivated: Shell.forScreen(Settings.screenName)?.hotkeys.show()
            }
        }

        // --------------------------------------------------------- made by

        SettingsCard {
            title: "Made by"

            SettingsRow {
                icon: "person"
                label: "Marcus Rosado"
                detail: "with Claude writing the code and Marcus owning the structure (DESIGN.md section 0)"
                interactive: false
            }
        }
    }
}
