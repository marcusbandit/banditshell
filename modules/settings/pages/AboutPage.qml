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
// A masthead, what it runs on, and where to read the rest. The machine
// underneath is DevicePage's subject and the compositor, the type and
// the file paths of the running checkout are DeveloperPage's; this page
// repeats none of them. It used to also SAY what the shell is for, a card of
// paragraphs; nobody asked for that, and a settings page that explains itself
// uninvited is a manifesto, so the rows that remain are the ones that state a
// fact or DO something.
//
// The name and version are a masthead rather than a card. A row is a mark, a
// name and a detail about something else, and "banditshell" is not a fact
// about something else, it is the thing the page is about; the large size and a
// mark of its own beside it is how the page says so.
//
// The "Read more" rows are the ones that DO something: they hand a path to
// xdg-open -- which editor, which file manager and which viewer are the
// desktop's decisions, not the shell's. One Process for all of them, because
// `exec` replaces the command each time and three idle processes for three
// rows would be three of something for no reason. The hotkeys row is the
// exception, opening a panel of the shell's own on the screen that holds
// this page; the Keys page, not this one, is where binds are edited.
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
        spacing: Appearance.padding.huge

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

        // ------------------------------------------------------- running on

        // WHAT THE SHELL IS RUNNING ON, and what that means it can do. The
        // machine underneath is DevicePage's subject, so the rows here name
        // only what bears on SUPPORT: which compositor this is, and which
        // config language it speaks. The same compositor name appears on
        // DevicePage; the fact there is hardware, the fact here is a
        // capability, and a settings app that kept them apart only by page
        // would be keeping them apart by accident.
        //
        // NOT HYPRLAND IS ONE QUIET ROW. It is a flag, not a warning: for as
        // long as Hyprland is the only compositor this shell integrates
        // with, running anything else means some things do not work, and
        // saying that once, inertly, is the whole of the announcement.
        SettingsCard {
            title: "Running on"

            SettingsRow {
                icon: "desktop_windows"
                label: "Compositor"
                value: [Compositor.name, Device.compositorVersion].filter(p => p).join(" ")
                interactive: false
            }

            // Hyprland only, because the dialect is nobody else's question.
            // Three-way, for the reason DeveloperPage's identical row gives:
            // "legacy" before the probe comes back would be a guess stated
            // as a fact.
            SettingsRow {
                visible: Compositor.isHyprland
                icon: "code"
                label: "Config dialect"
                value: !Hypr.parserKnown ? "asking" : Hypr.lua ? "lua" : "legacy"
                interactive: false
            }

            // The quiet flag. One row, no exclamation: not Hyprland.
            SettingsRow {
                visible: !Compositor.isHyprland
                icon: "info"
                label: "Hyprland-only features are off"
                detail: "the shell runs, and everything that speaks to the compositor waits for Hyprland"
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
    }
}
