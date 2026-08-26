pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// ABOUT: the shell itself.
//
// What is running, what it is running on top of, and where its files are. The
// machine underneath is DevicePage's subject; this page is the checkout, so a
// version line is the first thing on it and a hostname is nowhere on it.
//
// The name and version are a header rather than a row. A row is an icon, a
// label and a detail, and "banditshell" is not a fact about something else, it
// is the thing the page is about; giving it the large size and no glyph is how
// the page says so without a heading component this shell does not have.
//
// The file rows are the only ones that DO anything, and what they do is hand a
// path to xdg-open: which editor, which file manager and which viewer are the
// desktop's decisions, not the shell's. One Process for the three of them,
// because `exec` replaces the command each time and three idle processes for
// three rows would be three of something for no reason.
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
        spacing: Appearance.padding.small / 2

        // ---------------------------------------------------------- header

        Column {
            width: list.width
            bottomPadding: Appearance.padding.normal

            StyledText {
                text: "banditshell"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.text
            }

            // `describe` gives a tag or a short hash and appends "-dirty" when
            // the tree has uncommitted edits; the date is the last commit's,
            // which is the version line a hash alone cannot carry.
            StyledText {
                text: (Device.version || "unknown version") + (Device.commitDate ? ` · ${Device.commitDate}` : "")
                color: Appearance.colour.textFaint
            }
        }

        // ------------------------------------------------------ running on

        StyledText {
            text: "Running on"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        // Which config dialect Hyprland is on matters because Hypr's parser has
        // to match it; it only says so once it actually knows.
        MenuRow {
            width: list.width
            icon: "layers"
            label: "Compositor"
            detail: Compositor.name + (Compositor.isHyprland && Hypr.parserKnown ? ` · ${Hypr.lua ? "lua config" : "legacy config"}` : "")
            inlineDetail: true
            interactive: false
        }

        // `follows` is the switch behind Appearance's rounding and gaps: on,
        // the shell reads them off the compositor so a panel corner matches
        // the window beside it; off, config.json is the only word.
        MenuRow {
            width: list.width
            icon: "tune"
            label: "Corners and gaps"
            detail: Appearance.follows ? "taken from the compositor" : "from config.json"
            inlineDetail: true
            interactive: false
        }

        MenuRow {
            width: list.width
            icon: "text_fields"
            label: "Type"
            detail: `${Appearance.font.family}, ${Appearance.font.size.small}/${Appearance.font.size.normal}/${Appearance.font.size.large}px`
            inlineDetail: true
            interactive: false
        }

        // ----------------------------------------------------------- files

        StyledText {
            text: "Files"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "description"
            label: "Settings file"
            detail: Config.path
            tip: "open it in your editor"
            onActivated: opener.exec(["xdg-open", Config.path])
        }

        MenuRow {
            width: list.width
            icon: "folder"
            label: "Shell source"
            detail: Device.shellDir
            tip: "open the folder"
            onActivated: opener.exec(["xdg-open", Device.shellDir])
        }

        MenuRow {
            width: list.width
            icon: "menu_book"
            label: "Design notes"
            detail: "DESIGN.md, the reasons behind every part of it"
            tip: "open it"
            onActivated: opener.exec(["xdg-open", `${Device.shellDir}/DESIGN.md`])
        }

        StyledText {
            text: "made by Marcus Rosado"
            color: Appearance.colour.textGhost
            topPadding: Appearance.padding.large
        }
    }
}
