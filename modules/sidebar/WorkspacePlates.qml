pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.services

// STYLE: plates. A stack of index tabs, and the one you are on is pulled out.
//
// A workspace is not a number, it is the windows you left there, so each plate
// carries one mark per window. Nothing here is labelled 1..N: the column IS the
// order.
//
// LENGTH IS THE STATE, and it is the only thing that says it: a short mark for a
// workspace with nothing on it, further in when it holds windows, all the way out
// for the one you are on. Index tabs, and a bar chart of how busy the machine is,
// which turn out to be the same drawing. There is no separate indicator sliding
// around on top: the plate you go to IS the indicator, and it grows.
//
// THE PLATES BORDER THE SCREEN'S EDGE. They start at x = 0 and end flat there:
// this item spans the chassis's whole left band, and the band is shell material
// all the way out to the display, so a plate hinged at zero is hinged on the edge
// of the screen itself. They stop one band short of the bar's inner edge, so the
// free end has somewhere to be.
//
// Depth is thickness and layering, never a shadow or a bevel: an inactive plate
// is one sheet of material, the active one is two with the accent in the upper
// sheet, and it is longer than the rest. Where you are is literally more glass,
// pulled further out.
Item {
    id: root

    // WHAT A WINDOW IS DRAWN AS: its own icon in the shell's colour (`theme`),
    // its own icon as shipped (`colour`), or the Material Symbol for what kind of
    // thing it is (`glyph`). See config.json.
    readonly property string iconMode: Appearance.sizes.wsIconMode
    readonly property bool artwork: iconMode !== "glyph"

    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int iconSize: Appearance.sizes.wsIcon
    readonly property int pitch: Appearance.sizes.wsWindowPitch
    readonly property int tick: Appearance.sizes.wsTick

    // WHERE A PLATE STARTS AND HOW FAR IT CAN GO. It starts ON the screen's edge,
    // and the room it has is everything up to one band short of the bar's inner
    // edge: the shell's own lattice at the far end, nothing at the near one,
    // because there is nothing between a plate and the edge it is hinged on.
    readonly property real hinge: 0
    readonly property real span: width - Appearance.sizes.band

    // The other two states, as fractions of that span. The active one is the
    // whole span by definition: it is what "pulled all the way out" means.
    readonly property real emptyReach: Appearance.sizes.wsEmptyReach
    readonly property real busyReach: Appearance.sizes.wsBusyReach

    property int hovered: -1

    implicitHeight: layout.total

    WorkspaceModel {
        id: layout

        base: root.slot
        pitch: root.pitch
    }

    Repeater {
        // Modelled by a COUNT, not by the slot array: a Repeater over a JS array
        // rebuilds every delegate whenever the array is reassigned, and that array
        // is reassigned on every window event. Keyed by an int, the slots persist
        // and only their bindings update.
        //
        // The count includes any GHOST the model is still collapsing, so a
        // workspace that has just stopped existing shrinks away with the column
        // instead of vanishing while the column glides.
        model: Math.max(layout.count, layout.live.length)

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: layout.slots[index] ?? ({
                    id: index + 1,
                    windows: [],
                    rest: 0
                })
            readonly property var geom: layout.at(index)
            readonly property bool isActive: Hypr.activeId === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0 || slotItem.info.rest > 0

            y: slotItem.geom.y
            width: root.width
            height: slotItem.geom.h

            // The click target is the whole width, plate or no plate: a 12px mark
            // is a mark, not a button, and reaching for a workspace should not
            // mean hitting it.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            G2Rect {
                id: plate

                // An EMPTY workspace gets a mark, not a plate: half as tall,
                // centred on the slot it stands for. Length alone did not carry
                // it, a short plate at full height is just a fat nub. Going there
                // makes it a plate like any other.
                readonly property bool solid: slotItem.isOccupied || slotItem.isActive

                // THE STATE IS ANIMATED, NOT THE PIXELS. Both of these resolve
                // through the slot's live height, which is already being smoothed
                // frame by frame; a Behavior on the resulting height would restart
                // a 220ms animation on every one of those frames and the plate
                // would rubber-band behind its own column. Animating the fractions
                // instead keeps the two motions independent: the reflow stays
                // exponential, the state change eases, neither fights the other.
                // Hover pulls the plate a little further out and swells it a
                // little taller: the tab answers the cursor before it is clicked,
                // and it answers by moving, which is the only thing in this shell
                // that ever means "yes, this one".
                readonly property real swell: root.hovered === slotItem.index ? Appearance.sizes.wsHover : 0
                readonly property real reachTarget: (slotItem.isActive ? 1 : slotItem.isOccupied ? root.busyReach : root.emptyReach) + swell
                readonly property real tallTarget: (solid ? 1 : 0.5) + swell

                property real reach: reachTarget
                property real tall: tallTarget

                x: root.hinge
                width: Math.round(root.span * reach)
                height: Math.round(parent.height * tall)
                y: (parent.height - height) / 2

                // SQUARE at the hinge, convex on the free end. A rounded corner at
                // the hinge would curl the plate off the screen's edge and leave a
                // notch of dead space behind it; the chassis's concave flare,
                // which is the right answer where a whole panel meets that edge,
                // needs more room than a 28px slot has and pinches the plate's own
                // end off. Attached means flat against.
                topLeftRadius: 0
                bottomLeftRadius: 0
                topRightRadius: Appearance.rounding.normal
                bottomRightRadius: Appearance.rounding.normal

                color: root.hovered === slotItem.index || slotItem.isActive ? Appearance.colour.fillStrong : Appearance.colour.fill

                Behavior on reach {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on tall {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // The second sheet: the accent, over the neutral one rather than
                // instead of it, so the active plate reads as thicker glass with
                // colour in it and not as a stain on the bar.
                G2Rect {
                    anchors.fill: parent
                    topLeftRadius: plate.topLeftRadius
                    bottomLeftRadius: plate.bottomLeftRadius
                    topRightRadius: plate.topRightRadius
                    bottomRightRadius: plate.bottomRightRadius
                    color: Appearance.colour.accentFill
                    opacity: slotItem.isActive ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // The one saturated thing in the sidebar, and it is three pixels
                // wide, on the plate's hinge.
                G2Rect {
                    x: 0
                    width: root.tick
                    height: parent.height
                    radius: 0
                    color: Appearance.colour.accent
                    opacity: slotItem.isActive ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // One row per window, CENTRED IN THE PLATE, which is why they are
                // children of it: the icons ride the plate out as it grows rather
                // than sitting at a fixed place it happens to cover. A plate long
                // enough to hold them is then not a constraint on how short the
                // others can be.
                Repeater {
                    // A ScriptModel, NOT the array: the array is rebuilt on every
                    // Hyprland event, and a plain-array Repeater would tear down
                    // and rebuild every icon each time. This diffs it, so a window
                    // opening touches only its own row.
                    model: ScriptModel {
                        values: slotItem.info.windows
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool focused: Hypr.isFocused(modelData)
                        readonly property bool lit: focused || winMouse.containsMouse
                        // An OVERRIDE beats the artwork: if the config names a
                        // glyph for this window, the theme has nothing to add.
                        readonly property bool overridden: Apps.overrideFor(Hypr.classOf(modelData)) !== ""
                        readonly property string source: root.artwork && !overridden ? Apps.iconSourceFor([Hypr.classOf(modelData), modelData.lastIpcObject?.initialClass ?? ""]) : ""

                        x: (plate.width - root.slot) / 2
                        y: (root.slot - root.pitch) / 2 + index * root.pitch
                        width: root.slot
                        height: root.pitch

                        // The application's own icon. Drawn straight in `colour`
                        // mode, and used as the effect's source in `theme` mode,
                        // where it is never itself on screen.
                        Image {
                            id: image

                            anchors.centerIn: parent
                            width: root.iconSize
                            height: width
                            source: row.source
                            sourceSize.width: width * 2
                            sourceSize.height: width * 2
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            visible: root.iconMode === "colour" && status === Image.Ready
                            opacity: row.lit ? 1 : 0.55

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // THE APP'S OWN ARTWORK, IN OUR COLOUR. An icon pack is
                        // fifty designers' palettes at once, and a bar full of
                        // them stops looking like one interface; this keeps each
                        // app's SHAPE, which is what you actually recognise, and
                        // throws away its colour, which is what was fighting.
                        //
                        // Luminance is preserved rather than flattened: a
                        // silhouette would turn Telegram into a disc and
                        // qBittorrent into a square, which is worse than a
                        // category glyph, not better.
                        MultiEffect {
                            id: effect

                            anchors.fill: image
                            source: image
                            visible: root.iconMode === "theme" && image.status === Image.Ready
                            // Luminance is what is left after the colour goes, so
                            // it has to be left alone: a brightness lift here
                            // blows every icon that has a filled badge behind it
                            // into a white disc, which is the shape of a disc and
                            // not the shape of the app.
                            saturation: -1
                            colorization: 1
                            colorizationColor: row.lit ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on colorizationColor {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // What KIND of thing it is, for a window the icon theme
                        // has nothing for, and for `glyph` mode, and for anything
                        // the config picked a mark for by hand.
                        Icon {
                            anchors.centerIn: parent
                            visible: !image.visible && !effect.visible
                            size: root.iconSize
                            name: Apps.iconFor(Hypr.classOf(row.modelData))

                            // The focused window is the only thing in the column
                            // at full label weight. That is the whole hierarchy:
                            // the plate says which workspace you are on, this says
                            // which window you are in.
                            color: row.lit ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // Clicking a window goes to THAT window, not merely to its
                        // workspace. Hyprland's focuswindow brings the workspace
                        // along with it, so this is strictly more than the plate's
                        // own click does.
                        MouseArea {
                            id: winMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hovered = slotItem.index
                            onExited: if (root.hovered === slotItem.index)
                                root.hovered = -1
                            onClicked: Hypr.focusClient(row.modelData)
                        }
                    }
                }

                // "and more". Sits in the row after the last icon, so an
                // overflowing workspace is capped rather than truncated silently.
                Icon {
                    visible: slotItem.info.rest > 0
                    x: (plate.width - root.slot) / 2
                    y: (root.slot - root.pitch) / 2 + slotItem.info.windows.length * root.pitch
                    width: root.slot
                    height: root.pitch
                    name: "more_horiz"
                    size: root.iconSize
                    color: Appearance.colour.textFaint
                }
            }
        }
    }
}
