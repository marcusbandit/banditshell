pragma ComponentBehavior: Bound

import QtQuick
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

    // WHAT A WINDOW IS DRAWN AS: the Nerd Fonts mark for the application itself
    // (`brand`), the icon theme's artwork as shipped (`colour`), or the Material
    // Symbol for what kind of thing it is (`glyph`). See config.json.
    readonly property string iconMode: Appearance.sizes.wsIconMode

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

    // The scratchpad group: how far its pills sit off the edge, how much air
    // separates them from each other, and how much separates the group from the
    // numbered run below it. That last one is wider than a plate gap on purpose:
    // it is the boundary between two kinds of thing.
    readonly property real inset: Appearance.sizes.band
    readonly property int gapSize: Appearance.sizes.wsGap
    readonly property int specialGap: Hypr.specials.length ? Appearance.padding.large : 0

    property int hovered: -1

    // The numbered run sits under the scratchpads, which is why it is offset
    // rather than starting at zero.
    implicitHeight: specials.height + layout.total

    WorkspaceModel {
        id: layout

        base: root.slot
        pitch: root.pitch
    }

    // SCRATCHPADS, which are not workspace 6. A special workspace is not
    // somewhere you go and stay, it is something you pull over whatever you are
    // already doing and then put away, and it exists only while something is on
    // it. So they do not join the numbered run: they FLOAT above it, rounded at
    // both ends and off the screen's edge, because the one thing the plates say
    // by being hinged is "this is one of the places you live".
    //
    // No layout pass and no smoothing here on purpose. A scratchpad appears when
    // you put something in it and is gone when you take it out; there is no
    // rearranging to follow, and the numbered column below simply starts lower.
    Column {
        id: specials

        width: root.width
        spacing: root.gapSize
        bottomPadding: root.specialGap

        Repeater {
            model: Hypr.specials

            delegate: Item {
                id: pad

                required property var modelData
                readonly property bool isOpen: Hypr.openSpecial === pad.modelData.name

                width: root.width
                height: root.slot

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.toggleSpecial(pad.modelData.name)
                }

                G2Rect {
                    id: pill

                    // Inset from the edge and rounded at both ends: a plate is
                    // attached to the screen, this is lying on top of it.
                    x: root.inset
                    width: Math.round(root.span * root.busyReach) - root.inset
                    height: parent.height
                    radius: Appearance.rounding.normal

                    color: pad.isOpen ? Appearance.colour.fillStrong : Appearance.colour.fill

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    G2Rect {
                        // `pill.radius`, not `parent.radius`: children declared
                        // inside a G2Rect land in its inner item, which is a
                        // plain Item and has no radius to read.
                        anchors.fill: parent
                        radius: pill.radius
                        color: Appearance.colour.accentFill
                        opacity: pad.isOpen ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // One mark, not a stack: a scratchpad is usually one window,
                    // and if it is three the point is still "the scratchpad",
                    // not which of the three is in front.
                    AppMark {
                        anchors.centerIn: parent
                        size: root.iconSize
                        spec: pad.modelData.windows.length ? AppIcons.markFor(Hypr.classOf(pad.modelData.windows[0])) : ""
                        fallback: pad.modelData.windows.length ? Apps.iconFor(Hypr.classOf(pad.modelData.windows[0])) : "layers"
                        color: pad.isOpen ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    // How many are in there, when it is more than one. A number
                    // rather than a stack of marks, because the stack would make
                    // a scratchpad look like a workspace.
                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.small / 2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pad.modelData.windows.length > 1
                        text: pad.modelData.windows.length
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textFaint
                    }
                }
            }
        }
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

            y: specials.height + slotItem.geom.y
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
                        readonly property string appClass: Hypr.classOf(modelData)

                        x: (plate.width - root.slot) / 2
                        y: (root.slot - root.pitch) / 2 + index * root.pitch
                        width: root.slot
                        height: root.pitch

                        // THE MARK, whatever kind of thing it turns out to be:
                        // what you picked for this application in settings, what
                        // the config named, what the current mode works out, or
                        // the category glyph. One component draws all of them, so
                        // the sidebar cannot disagree with the picker.
                        AppMark {
                            anchors.centerIn: parent
                            size: root.iconSize
                            spec: AppIcons.markFor(row.appClass)
                            fallback: Apps.iconFor(row.appClass)

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
