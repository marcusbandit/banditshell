pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// APPEARANCE: what the shell wears, and what it stands on.
//
// The theme picker first, because it is the one people actually swap, and
// because `banditshell set theme slate` proving the live re-dress works is
// exactly the kind of thing that deserves a surface with no terminal in it.
// The wallpaper switch above it is the other half of the same question: a
// palette is what the shell is made of, a wallpaper is what it is seen
// against, and turning the picture off is the fastest way to look at either
// one honestly.
//
// Every other appearance decision already lives in config.json behind
// Appearance's tokens, so the page grows a control only when a setting earns
// one.
//
// Rows come FROM Themes.names, so a palette added to config/Themes.qml appears
// here without this file changing: the page renders data, it does not keep a
// second list of what the data contains.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        // ------------------------------------------------------- wallpaper

        // SWITCHES, not a picker. WHICH wallpaper is a question you answer by
        // looking at wallpapers, and that belongs on a surface the size of the
        // screen with the candidate actually on the desktop behind it: it is
        // the bottom edge's second swipe, see modules/wallpaper/. What is left
        // here is the two things about a wallpaper that are settings rather
        // than choices, both of them a switch you flip and unflip in a second.
        //
        // The row itself flips it as well as the toggle on it, MenuRow's usual
        // contract: the whole line is the target, because the switch alone is
        // 34px of it.
        MenuRow {
            width: list.width
            icon: "wallpaper"
            label: "Wallpaper"
            // What it would show, even while it is off, and what KIND that is
            // for the three that are not simply a picture: a file that turns
            // out to be a video behaves differently once it is up, and the
            // detail line is where that is worth knowing. The choice survives
            // being turned off, so the row goes on saying what the choice is
            // rather than going blank and making the setting look lost.
            detail: Wallpaper.name ? (Wallpaper.kind === "still" ? Wallpaper.name : `${Wallpaper.name} · ${Wallpaper.kind}`) : "nothing set"
            tip: Wallpaper.enabled ? "turn it off" : "turn it on"
            onActivated: Wallpaper.toggle()

            Toggle {
                checked: Wallpaper.enabled
                onToggled: Wallpaper.toggle()
            }
        }

        // THE ONE RULE THAT MAKES A MOVING WALLPAPER AFFORDABLE, offered as a
        // switch because it is the only part of it worth arguing with. What it
        // costs when it is on is stated rather than left to be discovered: the
        // whole reason animated wallpapers are usually a bad idea is a decoder
        // running behind a full screen of windows, and this row is the shell
        // saying it does not do that.
        //
        // Shown only when it could matter. A folder of photographs has nothing
        // to animate, and a switch for a thing you do not have is a setting you
        // have to think about for no reason.
        MenuRow {
            width: list.width
            visible: Wallpaper.available.some(p => Wallpaper.movesOf(p)) || Wallpaper.moves
            icon: "motion_photos_on"
            label: "Play animated wallpapers"
            detail: "only on an empty workspace"
            tip: Config.values.wallpaper.animate ? "stop playing them" : "play them"
            onActivated: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)

            Toggle {
                checked: Config.values.wallpaper.animate
                onToggled: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)
            }
        }

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
        MenuRow {
            width: list.width
            visible: Wallpaper.palette.length > 0
            icon: "colorize"
            label: "Theme from wallpaper"
            detail: "not worn yet"
            tip: "the colours it would use are on the right"
            onActivated: Config.set("themeFromWallpaper", !Config.values.themeFromWallpaper)

            Row {
                spacing: Appearance.padding.normal

                // WHAT IT FOUND, in the order it found it, biggest share first.
                //
                // Sized by SHARE rather than all alike, because that is the one
                // fact a row of equal chips throws away: these are not six
                // colours the wallpaper contains, they are six colours it is
                // made of in wildly different amounts, and a picture that is
                // four fifths one blue should say so. The width runs between a
                // stem and a full swatch, so even the smallest is still a
                // colour rather than a line.
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

        // -------------------------------------------------------- palettes

        // The one boundary space alone would not carry: a switch and a list of
        // rows are the same shape, so without a rule the palettes read as more
        // settings rather than as a different question. The rule sits in the
        // middle of its own air, which is the only way a Column can give a
        // hairline room on both sides.
        Item {
            width: list.width
            height: Appearance.padding.large

            Separator {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }
        }

        // The same quiet eyebrow the icons page opens with, saying the one
        // thing a picker cannot show: there is no apply step. The write goes
        // straight to config.json and the whole shell re-binds.
        StyledText {
            text: `${Themes.names.length} palettes, worn immediately`
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        Repeater {
            model: Themes.names

            delegate: Item {
                id: row

                required property string modelData

                readonly property var theme: Themes.get(row.modelData)
                readonly property bool current: Config.values.theme === row.modelData
                readonly property bool hovered: press.containsMouse

                width: list.width
                // MenuRow's own maximum: the rowHeight floor, grown if the
                // label's line box plus its air ever outgrows it, so a type
                // scale change cannot quietly crop the row it is named in.
                height: Math.max(Appearance.sizes.rowHeight, name.implicitHeight + Appearance.padding.small * 2)

                // The full radius, for MenuRow's reason: at a small radius the
                // G2 ramp has no room to read and renders as the plain arc it
                // exists to replace.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                    opacity: row.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // Before the content, MenuRow's lesson: a row-wide target
                // declared last would sit on top of whatever the row grows
                // later and eat its clicks. The swatches take no input today;
                // the order is so that stays a fact about the swatches.
                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.set("theme", row.modelData)
                }

                // The active row is marked by its NAME going accent, not by a
                // tinted row. A whole-row tint is the selection treatment, and
                // this is not a selection you are moving through a list: it is
                // a fact about one row, and the accent is the shell's colour
                // for state genuinely worth a colour. It is also self-proving:
                // the accent IS the active theme's, so the mark is drawn in
                // the very paint it is announcing.
                StyledText {
                    id: name

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    text: row.modelData
                    color: row.current ? Appearance.colour.accent : row.hovered ? Appearance.colour.text : Appearance.colour.textDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // WHAT THE THEME LOOKS LIKE, said in its own saturated end:
                // dim, mid, bright, the three accents a Theme block supplies,
                // drawn from the theme's data rather than listed by hand so a
                // theme cannot lie about itself here. The ramp is deliberately
                // not swatched: eleven near-neighbour greys in an 18px chip
                // read as dirt, and the accents are where palettes actually
                // differ.
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small / 2

                    Repeater {
                        model: [row.theme.dim, row.theme.mid, row.theme.bright]

                        delegate: G2Rect {
                            required property color modelData

                            // Sized from the type it sits beside rather than a
                            // number of its own: a swatch here is punctuation
                            // next to the name, not an exhibit.
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
}
