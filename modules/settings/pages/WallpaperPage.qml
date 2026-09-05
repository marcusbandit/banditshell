pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// WALLPAPER: what the shell is seen against.
//
// Its own section rather than rows on Appearance, because a wallpaper is the
// one appearance decision you answer by LOOKING, and looking wants a picture
// per choice rather than a name per row. The bottom edge's second swipe
// (modules/wallpaper/) is still the surface for judging one at full size
// against your own windows; this page is the same folder at a glance, plus the
// two facts about a wallpaper that are settings rather than choices.
//
// The current one is shown at the top as a picture and not as a row, for the
// same reason: "which one is it" is a question a filename answers badly.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        // --------------------------------------------------------- current

        // A plain card rather than a SettingsCard: a picture is not a row, and
        // a card of rows would give it row corners and a row highlight.
        G2Rect {
            width: parent.width
            height: current.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            Column {
                id: current

                x: Appearance.padding.small
                y: Appearance.padding.small
                width: parent.width - Appearance.padding.small * 2
                spacing: Appearance.padding.small

                // Widescreen, whatever the picture's own shape: the thumbnail
                // is a stand-in for a monitor and should be shaped like one.
                G2Image {
                    id: picture

                    // Judged by the picture, not the setting: a configured
                    // file that is not on disk any more is a blank card, and
                    // the placeholder is what a blank card should say.
                    visible: picture.ready
                    width: parent.width
                    height: width * 9 / 16
                    radius: Appearance.rounding.normal
                    fillMode: Image.PreserveAspectCrop
                    source: Wallpaper.faceOf(Wallpaper.current)
                }

                // The same shape with nothing in it, saying so, rather than a
                // card that collapses to two lines and looks like a bug.
                G2Rect {
                    visible: !picture.ready
                    width: parent.width
                    height: width * 9 / 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    StyledText {
                        anchors.centerIn: parent
                        // A name with no picture behind it is a file that has gone
                        // missing, which is worth saying differently from nothing
                        // ever having been chosen.
                        text: Wallpaper.ready ? "the file is not on disk" : "no wallpaper set"
                        color: Appearance.colour.textFaint
                    }
                }

                StyledText {
                    width: parent.width
                    text: Wallpaper.name || "nothing set"
                    wrapMode: Text.Wrap
                    color: Appearance.colour.text
                }

                // What KIND it is, for the three that are not simply a
                // picture: a file that turns out to be a video behaves
                // differently once it is up, and this is where that is worth
                // knowing.
                StyledText {
                    width: parent.width
                    visible: !!Wallpaper.kind
                    text: Wallpaper.kind
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                }
            }
        }

        // -------------------------------------------------------- switches

        // The row itself flips it as well as the toggle on it: the whole line
        // is the target, because the switch alone is 34px of it.
        SettingsCard {
            title: "Wallpaper"

            // The choice survives being turned off (services/Wallpaper.qml),
            // so the picture above goes on saying what the choice is rather
            // than going blank and making the setting look lost.
            SettingsRow {
                icon: "wallpaper"
                label: "Show a wallpaper"
                onActivated: Wallpaper.toggle()

                Toggle {
                    checked: Wallpaper.enabled
                    onToggled: Wallpaper.toggle()
                }
            }

            // THE ONE RULE THAT MAKES A MOVING WALLPAPER AFFORDABLE, offered
            // as a switch because it is the only part of it worth arguing
            // with. What it costs when it is on is stated rather than left to
            // be discovered: the whole reason animated wallpapers are usually
            // a bad idea is a decoder running behind a full screen of windows,
            // and this row is the shell saying it does not do that.
            //
            // Shown only when it could matter. A folder of photographs has
            // nothing to animate, and a switch for a thing you do not have is
            // a setting you have to think about for no reason.
            SettingsRow {
                visible: Wallpaper.available.some(p => Wallpaper.movesOf(p)) || Wallpaper.moves
                icon: "motion_photos_on"
                label: "Play animated wallpapers"
                detail: "only on an empty workspace"
                onActivated: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)

                Toggle {
                    checked: Config.values.wallpaper.animate
                    onToggled: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)
                }
            }
        }

        // ---------------------------------------------------------- choose

        // NOT A SettingsCard. Its body is a Column of rows, and a Grid dropped
        // in it would be handed the Positioner attached properties meant for a
        // row. So this is the card's look built by hand: the same faint title
        // with the same left padding, then the same fill at the same radius.
        Column {
            width: parent.width
            spacing: Appearance.padding.small

            StyledText {
                text: `Choose, ${Wallpaper.available.length} in the folder`
                color: Appearance.colour.textFaint
                leftPadding: Appearance.padding.small
            }

            // WHICH FOLDER, and the one setting on this page you have to type
            // rather than press.
            //
            // It sits under that count on purpose: the count is a claim about
            // the disk and this is the claim it was counted from, so a folder
            // that lists nothing is a typo, a moved collection or a permission,
            // and all three look identical until the two lines are read
            // together. The second number is the one per-screen wallpapers
            // added, because a folder can be full and still hold nothing for
            // the monitor you are standing at.
            //
            // OUTSIDE the SettingsCard above rather than a row in it, for the
            // reason the comment on this Column already gives: it is not a
            // SettingsRow and would be handed Positioner properties meant for
            // one, which is what draws a card's corners onto its first and last
            // rows. Here it is a row belonging to this hand-built section.
            PathField {
                width: parent.width
                icon: "folder"
                label: "Wallpaper folder"
                value: Config.values.wallpaper.dir
                placeholder: "~/Pictures/Wallpapers"
                tip: "type a different folder"
                detail: {
                    const n = Wallpaper.available.length;
                    if (!n)
                        return "nothing usable in it";
                    const fit = Wallpaper.fittedFor(Wallpaper.screenAspect(Wallpaper.here)).length;
                    return fit < n ? `${fit} of them fit ${Wallpaper.here}` : "read all the way down";
                }
                onCommitted: path => Config.set("wallpaper.dir", path)
            }

            G2Rect {
                width: parent.width
                height: grid.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                // AS MANY COLUMNS AS THE WIDTH ALLOWS, computed from it and
                // never counted: a cell wants about half the settings pane,
                // so a phone-narrow face gets two across and a wide one gets
                // as many as fit, and the cells stretch to close the remainder
                // rather than leaving a gutter on the right.
                Grid {
                    id: grid

                    readonly property int cell: Math.floor((width - (columns - 1) * spacing) / columns)

                    x: Appearance.padding.small
                    y: Appearance.padding.small
                    width: parent.width - Appearance.padding.small * 2
                    columns: Math.max(2, Math.floor(width / (Appearance.sizes.settingsPane / 2)))
                    spacing: Appearance.padding.small

                    Repeater {
                        model: Wallpaper.available

                        delegate: Item {
                            id: tile

                            required property string modelData

                            readonly property bool current: Wallpaper.current === tile.modelData

                            width: grid.cell
                            height: grid.cell * 9 / 16

                            G2Image {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                fillMode: Image.PreserveAspectCrop
                                source: Wallpaper.faceOf(tile.modelData)
                            }

                            // The one that is up wears a ring in the accent,
                            // a stem's pair thick so it weighs the same as
                            // the type beside it.
                            G2Rect {
                                anchors.fill: parent
                                visible: tile.current
                                radius: Appearance.rounding.small
                                color: "transparent"
                                stroke: Appearance.colour.accent
                                strokeWidth: Appearance.font.stem * 2
                            }

                            // From the middle: a thumbnail is not on the
                            // screen it changes, so there is no point on that
                            // screen for the reveal to come from.
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpaper.setFrom(tile.modelData, 0.5, 0.5)
                            }
                        }
                    }
                }
            }
        }
    }
}
