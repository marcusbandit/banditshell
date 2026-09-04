pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// APPEARANCE: what the shell wears.
//
// The theme picker first, because it is the one people actually swap, and
// because `banditshell set theme slate` proving the live re-dress works is
// exactly the kind of thing that deserves a surface with no terminal in it.
//
// THE WALLPAPER ROWS ARE NOT HERE ANY MORE. What the shell is seen against is
// its own section now (pages/WallpaperPage.qml, key `wallpaper`), because it
// grew a picker and a picker is not a row: the two switches went with it so a
// wallpaper question has one place to be answered.
//
// Every other appearance decision already lives in config.json behind
// Appearance's tokens, so the page grows a control only when a setting earns
// one.
//
// Rows come FROM Themes.availableNames, which is every theme the machine's
// renderer can build, so a theme dropped into ~/.config/theme/themes appears
// here without this file changing: the page renders data, it does not keep a
// second list of what the data contains.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        // -------------------------------------------------------- palettes

        // WORN IMMEDIATELY, AND NOT ONLY HERE. There is no apply step: the
        // press runs `theme-set`, which re-renders the colours for every app
        // on the machine and reloads them, so the shell re-binds in the same
        // breath as the terminal and the window borders. That is the one thing
        // a picker cannot show, and the reason a row here is the whole gesture.
        SettingsCard {
            title: "Palette"

            Repeater {
                model: Themes.availableNames

                delegate: SettingsRow {
                    id: row

                    required property string modelData

                    readonly property var accents: Themes.accentsFor(row.modelData)

                    label: row.modelData
                    selected: Themes.activeName === row.modelData
                    onActivated: Themes.apply(row.modelData)

                    // WHAT THE THEME LOOKS LIKE, said in its own saturated
                    // end: dim, mid, bright, the three accents a theme
                    // supplies, and ITS OWN whether or not it is the one being
                    // worn, so the row shows what pressing it would do rather
                    // than what is already true. Drawn from the theme's data
                    // rather than listed by hand, so it cannot lie here. The
                    // ramp is deliberately not swatched: eleven near-neighbour
                    // greys in an 18px chip read as dirt, and the accents are
                    // where palettes actually differ.
                    Row {
                        spacing: Appearance.padding.small / 2

                        Repeater {
                            model: [row.accents.dim, row.accents.mid, row.accents.bright]

                            delegate: G2Rect {
                                required property color modelData

                                // Sized from the type it sits beside rather
                                // than a number of its own: a swatch here is
                                // punctuation next to the name, not an exhibit.
                                width: Appearance.font.size.small
                                height: width
                                radius: Appearance.rounding.small
                                color: modelData
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ type

        // One row that leads somewhere. The families a machine has are a list
        // hundreds long and a page of their own (pages/FontPage.qml); this row
        // says which one is worn and is the way in.
        SettingsCard {
            title: "Type"

            SettingsRow {
                icon: "text_fields"
                label: "Font"
                value: Appearance.font.family
                detail: "the face every word in the shell is set in"
                chevron: true
                onActivated: Settings.setPage("font")
            }
        }

        // ------------------------------------------------------ compositor

        // WHAT FLOWS BETWEEN THE SHELL AND HYPRLAND, in both directions, and
        // an appearance question because both switches are about what the
        // desktop looks like: whose corners the panels wear, and whose colour
        // the focused window's border does. Two switches rather than one
        // because they answer opposite questions; config/Compositor.qml owns
        // the argument, and the `compositor` block in config/Config.qml owns
        // the reason `pushBorders` had to be declared before it could be set.
        //
        // The row itself flips it as well as the toggle on it: the whole line
        // is the target, because the switch alone is 34px of it.
        SettingsCard {
            title: "Compositor"

            SettingsRow {
                icon: "crop_square"
                label: "Corners and gaps from the compositor"
                detail: "read rounding, its power and the gap from hyprland rather than config.json"
                onActivated: Config.set("compositor.follow", !Config.values.compositor.follow)

                Toggle {
                    checked: Config.values.compositor.follow
                    onToggled: Config.set("compositor.follow", !Config.values.compositor.follow)
                }
            }

            SettingsRow {
                icon: "border_color"
                label: "Push the theme onto window borders"
                detail: "the focused window wears the accent; off, hyprland.conf's colours stand"
                onActivated: Config.set("compositor.pushBorders", !Config.values.compositor.pushBorders)

                Toggle {
                    checked: Config.values.compositor.pushBorders
                    onToggled: Config.set("compositor.pushBorders", !Config.values.compositor.pushBorders)
                }
            }
        }

        // ---------------------------------------------- theme from wallpaper

        // THE SWITCH THAT DOES NOT WORK YET, and the thing that makes it worth
        // having on the page anyway.
        //
        // The measurement is real: the wallpaper's dominant colours are pulled
        // out of it on every change (scripts/palette.py) and drawn in this row
        // as the swatches it WOULD wear. What is not built is everything after
        // that, which is which of six colours is a surface and which is an
        // accent, and what a shell does when a photograph offers no pair that
        // clears the contrast this one holds itself to. See config/Config.qml.
        //
        // So the row says so. A setting that lies about being wired up is worse
        // than one that is missing, and a row that shows you the answer it has
        // and admits it cannot use it yet is neither.
        //
        // Shown only when there is a measurement to show: with no wallpaper
        // there are no colours, and a switch with nothing on its right would
        // be a promise with no evidence.
        SettingsCard {
            title: "Theme from wallpaper"
            visible: Wallpaper.palette.length > 0

            SettingsRow {
                icon: "colorize"
                label: "Theme from wallpaper"
                detail: "not worn yet"
                onActivated: Config.set("themeFromWallpaper", !Config.values.themeFromWallpaper)

                // If the swatches and the switch together outgrow the line,
                // SettingsRow drops them under the text on its own.
                Row {
                    spacing: Appearance.padding.normal

                    // WHAT IT FOUND, in the order it found it, biggest share
                    // first.
                    //
                    // Sized by SHARE rather than all alike, because that is
                    // the one fact a row of equal chips throws away: these are
                    // not six colours the wallpaper contains, they are six
                    // colours it is made of in wildly different amounts, and a
                    // picture that is four fifths one blue should say so. The
                    // width runs between a stem and a full swatch, so even the
                    // smallest is still a colour rather than a line.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.font.stem

                        Repeater {
                            model: Wallpaper.palette

                            delegate: G2Rect {
                                required property var modelData

                                readonly property real swatch: Appearance.font.size.normal

                                width: Math.max(Appearance.font.stem * 2, Math.round(swatch * Math.min(1, modelData.share * 2.5)))
                                height: swatch
                                radius: Appearance.rounding.small
                                color: modelData.colour
                            }
                        }
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Config.values.themeFromWallpaper
                        onToggled: Config.set("themeFromWallpaper", !Config.values.themeFromWallpaper)
                    }
                }
            }
        }
    }
}
