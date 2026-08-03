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
//
// SCRATCHPADS GET A RACK OF THEIR OWN, under the column and clear of it. They
// used to hide behind the plate you were on and peek out below it, which is a
// fine drawing of ONE card and stops being one at two: each further sheet had to
// peek further, the second already reached the next plate's edge, and a third
// would have lain across it. Worse, every sliver looked like every other sliver,
// so the answer to "which of these is Spotify" was to click one and find out.
//
// So they come out from under the plate and lie in a row at the end of the
// column: one bar each, half the column's rhythm and a whole slot's width of
// room, carrying their own marks. Three fit without crowding and a fourth costs
// one bar's height, not a redesign. They keep the plates' grammar, because it is
// the same grammar: length is state, a bar with nothing on it is a stub, a bar
// with windows is as long as its marks need, and the one you have pulled open is
// gone from the rack because it is out on the plate you are on.
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
    readonly property int maxWindows: Appearance.sizes.wsMaxWindows

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

    // THE RACK'S OWN RHYTHM. A bar is one window row tall, which is half a slot
    // and change: thin enough that the rack can never be mistaken for more
    // workspaces, thick enough to carry a mark. The stand-off from the end of the
    // column is a whole tier above the gap inside it, because the same ratio that
    // groups a workspace's windows has to separate the rack from all of them.
    readonly property int barH: root.pitch
    readonly property int barGap: Math.round(Appearance.padding.small / 2)
    readonly property int rackGap: Appearance.padding.large

    // Marks on a bar run ACROSS it: the bar is a horizontal thing, so its
    // contents lie along it, the same way a plate is vertical and stacks its own
    // down. Smaller than a plate's, because a scratchpad is answering "which one
    // is this" and not "what is on this workspace".
    readonly property int barMark: Math.round(root.iconSize * 0.7)
    readonly property int barPitch: root.barMark + root.barGap

    // How much of the plate underneath stays visible past the end of an open
    // card. Small: this is still a card on a card.
    readonly property real overhang: Appearance.padding.normal

    // HOW MUCH THE PLATE YOU ARE ON STEPS BACK while a scratchpad lies over it.
    //
    // The accent means the thing you are looking at, and while a scratchpad is
    // pulled over the screen the thing you are looking at is the scratchpad. So
    // the accent goes with it, and what the plate keeps is the ghost of its own:
    // enough to say you are still on that workspace and it is still what you
    // come back to, not enough to argue with the card about which is which.
    readonly property real ceded: 0.35

    // Where the plate you are on currently IS, smoothed like everything else, so
    // a card lying on it travels with it rather than after it.
    readonly property var activeGeom: layout.at(Hypr.activeId - 1)

    property int hovered: -1
    property int racked: -1

    // WHICH SCRATCHPADS THERE ARE, IN AN ORDER THAT HOLDS STILL.
    //
    // Hyprland lists them in the order they were created, so closing Spotify and
    // opening it again moves it past Discord and the rack you learned last week
    // is a different rack today. Names listed in `sidebar.workspaces.specials`
    // are pinned to their place in that list and KEEP it while they are empty, so
    // a scratchpad that is not open yet leaves its own slot rather than shoving
    // the others along when it arrives. Anything unlisted follows, by name, which
    // is at least the same order every session.
    readonly property var deck: {
        const want = Appearance.sizes.wsSpecials;
        const live = Hypr.specials;
        const out = [];
        for (const name of want)
            out.push(live.find(s => s.label === name) ?? ({
                        id: 0,
                        name: `special:${name}`,
                        label: name,
                        windows: []
                    }));
        for (const s of live.slice().sort((a, b) => a.label.localeCompare(b.label)))
            if (want.indexOf(s.label) < 0)
                out.push(s);
        return out;
    }

    readonly property real rackTop: layout.total + root.rackGap
    readonly property real rackHeight: root.deck.length ? root.deck.length * root.barH + (root.deck.length - 1) * root.barGap : 0

    function barY(i: int): real {
        return root.rackTop + i * (root.barH + root.barGap);
    }

    // HOW MANY MARKS FIT ON A BAR, which is not a setting: the rack is as wide as
    // the sidebar and no wider, so the cap is the arithmetic of the room. A plate
    // caps at `maxWindows` because it can always grow another row downwards; a
    // bar cannot grow sideways past the edge of the shell.
    readonly property int barFits: Math.max(1, Math.floor((root.span - root.barGap) / root.barPitch))

    function barMarks(entry: var): int {
        const n = entry.windows.length;
        // Over the cap, the last cell says "and more" instead of showing one
        // arbitrary window of several.
        return n > root.barFits ? root.barFits - 1 : n;
    }

    function barRest(entry: var): int {
        return entry.windows.length - root.barMarks(entry);
    }

    function barCells(entry: var): int {
        return root.barMarks(entry) + (root.barRest(entry) > 0 ? 1 : 0);
    }

    // HOW LONG A BAR IS, in the plates' own language: a stub when there is
    // nothing on it, a full reach when it is carrying something, and longer than
    // that only when what it carries needs the room. Length is the state here
    // too, it is just measured along the other axis.
    function barWidth(entry: var): real {
        const cells = root.barCells(entry);
        if (!cells)
            return root.span * root.emptyReach;
        const content = root.barGap * 2 + cells * root.barMark + (cells - 1) * root.barGap;
        return Math.min(root.span, Math.max(root.span * root.busyReach, content));
    }

    function barMarkX(i: int): real {
        return root.barGap + i * root.barPitch;
    }

    readonly property real barMarkY: Math.round((root.barH - root.barMark) / 2)

    implicitHeight: layout.total + (root.deck.length ? root.rackGap + root.rackHeight : 0)

    WorkspaceModel {
        id: layout

        base: root.slot
        pitch: root.pitch
    }

    // THE RACK: one bar per scratchpad, at the end of the column.
    //
    // A special workspace is not a sixth workspace, and this is not a sixth slot:
    // it is thinner than any plate, it is the other side of a gap wide enough to
    // be a break rather than a step, and it is a ROW where the column is a
    // column. What it shares with a plate is the only thing worth sharing, which
    // is that the length of the thing tells you the state of the thing.
    //
    // A bar is where the card sleeps. Pulling one open lifts it out of the rack
    // and onto the plate you are on, which is drawn further down this file
    // because a card on top of a plate cannot also be under it; the bar it left
    // stays empty until it comes back, because that is where it is not.
    Repeater {
        // Modelled by a COUNT, for the same reason the plates are: `deck` is
        // rebuilt whenever anything happens to a window, and a Repeater over the
        // array itself would throw away every bar and build it again each time,
        // taking the animation it was in the middle of and the hover it was under
        // with it.
        model: root.deck.length

        delegate: G2Rect {
            id: bar

            required property int index
            readonly property var entry: root.deck[bar.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })
            readonly property bool open: !!bar.entry.name && Hypr.openSpecial === bar.entry.name
            readonly property bool lit: root.racked === bar.index
            readonly property int marks: root.barMarks(bar.entry)

            x: root.hinge
            y: root.barY(bar.index)
            // Hover swells it the same fraction a plate swells by, so the rack
            // answers the cursor in the language the column already speaks.
            //
            // A bar whose card is OUT falls back to the empty stub rather than
            // disappearing: the rack is a set of slots and one of them is empty
            // right now, which is a different thing from the rack being shorter.
            // Where the card itself is, is answered by the card.
            width: Math.round((bar.open ? root.span * root.emptyReach : root.barWidth(bar.entry)) * (1 + (bar.lit ? Appearance.sizes.wsHover : 0)))
            height: root.barH

            // Square on the screen's edge, like everything else hinged there.
            // The free end takes the plates' radius, which the corner budget
            // clamps to half a bar, so a bar this thin ends in a full round.
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: Appearance.rounding.normal
            bottomRightRadius: Appearance.rounding.normal

            // The same one sheet a plate is, and the same answer to the cursor.
            // A scratchpad is not more important than the workspace it will lie
            // on, so it cannot be brighter than one: what separates a full bar
            // from an empty one here is length and a mark, exactly as it is up
            // the column.
            color: bar.lit ? Appearance.colour.fillStrong : Appearance.colour.fill

            Behavior on width {
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

            // What the bar is carrying, which is nothing at all while its card is
            // out: the marks are ON the card and they went with it.
            Item {
                anchors.fill: parent
                opacity: bar.open ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: bar.entry.windows.slice(0, bar.marks)
                    }

                    delegate: AppMark {
                        required property var modelData
                        required property int index

                        x: root.barMarkX(index)
                        y: root.barMarkY
                        size: root.barMark
                        spec: AppIcons.markFor(Hypr.classOf(modelData))
                        fallback: Apps.iconFor(Hypr.classOf(modelData))
                        color: Hypr.isFocused(modelData) ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }

                // "and more", in the cell after the last mark, exactly as a plate
                // does it: a bar that ran out of room says so.
                Icon {
                    visible: root.barRest(bar.entry) > 0
                    x: root.barMarkX(bar.marks)
                    y: root.barMarkY
                    width: root.barMark
                    height: root.barMark
                    name: "more_horiz"
                    size: root.barMark
                    color: Appearance.colour.textFaint
                }
            }

            // The whole row, band-wide and half the gap either side, for the same
            // reason a plate's target is: a 20px lozenge is a mark, not a button,
            // and a stub has to be as easy to hit as a full bar. Nothing else in
            // the rack's rows is reachable, so there is nothing to hit by mistake.
            MouseArea {
                x: 0
                y: -root.barGap
                width: root.width
                height: parent.height + root.barGap * 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.racked = bar.index
                onExited: if (root.racked === bar.index)
                    root.racked = -1
                onClicked: Hypr.toggleSpecial(bar.entry.name)

                // The one thing in the rack that says a name out loud. Position
                // is what you actually navigate by once you know it; this is how
                // you come to know it.
                HoverTip {
                    text: bar.entry.label
                    host: bar
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
            // A scratchpad is lying on this plate, so its windows are behind
            // one: you cannot see them, and neither should their marks, which
            // would otherwise show through the card and read as two icons in the
            // same place.
            readonly property bool covered: slotItem.isActive && Hypr.openSpecial !== ""

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
                    opacity: slotItem.isActive ? (slotItem.covered ? root.ceded : 1) : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // The one saturated thing in the sidebar, and it is three pixels
                // wide, on the plate's hinge. It dims with the sheet while a card
                // is over it, and the card carries the bright piece of it, so the
                // ruler runs unbroken down the edge and is brightest where the
                // thing you are actually looking at is.
                G2Rect {
                    x: 0
                    width: root.tick
                    height: parent.height
                    radius: 0
                    color: Appearance.colour.accent
                    opacity: slotItem.isActive ? (slotItem.covered ? root.ceded : 1) : 0

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
                        opacity: slotItem.covered ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.normal
                            }
                        }

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

    // THE OPEN SCRATCHPAD, over everything, because that is where it is.
    //
    // It takes the height ITS OWN windows need rather than the height of the
    // plate it covers: a scratchpad is not in the column and does not have to
    // fit the column's rhythm, and a terminal and a notes window in there should
    // look like two things. Slightly shorter than the plate underneath, so the
    // end of what it is covering stays visible past it and the stack reads as a
    // stack.
    //
    // IT IS THE BAR, MOVED. Every number here is one end of a line between where
    // this scratchpad lies in the rack and where it lies on the plate you are on,
    // and `shown` is how far along that line it is, so opening and closing is one
    // card travelling rather than one appearing where another vanished. Its marks
    // travel too, and they swing as they go: a row along a bar is a column down a
    // card, and the same interpolation carries them between the two.
    Repeater {
        model: root.deck.length

        delegate: Item {
            id: pad

            required property int index
            readonly property var entry: root.deck[pad.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })
            readonly property bool open: !!pad.entry.name && Hypr.openSpecial === pad.entry.name

            readonly property var windows: pad.entry.windows.slice(0, root.maxWindows)
            readonly property int rows: Math.max(1, pad.windows.length)

            // The two ends of the journey: the bar in the rack, and the card on
            // the plate.
            readonly property real full: root.slot + (pad.rows - 1) * root.pitch
            readonly property real cardW: Math.round(root.span) - root.overhang
            readonly property real cardY: root.activeGeom.y + (root.activeGeom.h - pad.full) / 2
            readonly property real barW: root.barWidth(pad.entry)

            property real shown: pad.open ? 1 : 0

            function reach(from: real, to: real): real {
                return from + (to - from) * pad.shown;
            }

            x: root.hinge
            width: pad.reach(pad.barW, pad.cardW)
            height: pad.reach(root.barH, pad.full)
            y: pad.reach(root.barY(pad.index), pad.cardY)
            visible: pad.shown > 0

            Behavior on shown {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.toggleSpecial(pad.entry.name)
            }

            // THE SHADOW, which is the only one in this shell and is here because
            // everything else in the sidebar is a sheet lying flat ON the bar. A
            // scratchpad is the one thing that is off it, and a card resting on a
            // plate with nothing under its edge reads as a hole cut in the plate
            // instead of a card on it.
            //
            // Cast from the card's own silhouette rather than drawn as a darker
            // shape behind it, because a shape behind a translucent card shows
            // straight through it. It is also why the card stopped being glass:
            // see below.
            MultiEffect {
                anchors.fill: card
                source: card
                // Opaque by the halfway point rather than over the whole trip:
                // the card is TRAVELLING, and a card you can see through most of
                // the way is a card that is not there yet.
                opacity: Math.min(1, pad.shown * 2)

                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.35
                // Soft and barely offset: this is a card lifted off a plate by
                // its own thickness, not a dialog floating over a page. A tight
                // blur at this size comes out as a dark outline around the card,
                // which is a border, and a border is the one thing the chassis
                // spent so long learning not to draw.
                blurMax: Appearance.padding.normal
                shadowBlur: 1
                shadowVerticalOffset: Math.round(Appearance.padding.small / 3)
            }

            G2Rect {
                id: card

                anchors.fill: parent
                // Drawn by the effect above, which needs it as a texture, so the
                // scene must not also draw it directly. Multisampled, because a
                // curve that antialiases itself into the scene has to be given
                // the samples to do it with once it is drawing into a buffer.
                layer.enabled: true
                layer.samples: 4
                visible: false

                topLeftRadius: 0
                bottomLeftRadius: 0
                topRightRadius: Appearance.rounding.normal
                bottomRightRadius: Appearance.rounding.normal

                // A SURFACE, not more glass. Two veils at 14 and 18 percent over
                // a plate is a card you can see the plate through, and the whole
                // claim being made here is that this is in front of it: the marks
                // underneath showed through their own cover, and a shadow cast on
                // a plate would have shown through it too. So the card is the
                // shell's panel material, which is what everything else that
                // floats is made of, and the plate genuinely disappears behind it.
                color: Appearance.colour.surface

                G2Rect {
                    anchors.fill: parent
                    topLeftRadius: card.topLeftRadius
                    bottomLeftRadius: card.bottomLeftRadius
                    topRightRadius: card.topRightRadius
                    bottomRightRadius: card.bottomRightRadius
                    color: Appearance.colour.fillStronger
                }

                // THE ACCENT, WHICH CAME WITH IT. Same two pieces the active
                // plate is wearing, the sheet and the three bright pixels on the
                // hinge, because this is now the thing they mean: the plate is a
                // workspace you are on, this is the one you are looking at.
                G2Rect {
                    anchors.fill: parent
                    topLeftRadius: card.topLeftRadius
                    bottomLeftRadius: card.bottomLeftRadius
                    topRightRadius: card.topRightRadius
                    bottomRightRadius: card.bottomRightRadius
                    color: Appearance.colour.accentFill
                    opacity: pad.shown
                }

                G2Rect {
                    x: 0
                    width: root.tick
                    height: parent.height
                    radius: 0
                    color: Appearance.colour.accent
                    opacity: pad.shown
                }

                Repeater {
                    model: ScriptModel {
                        values: pad.windows
                    }

                    delegate: AppMark {
                        id: mark

                        required property var modelData
                        required property int index

                        readonly property real markSize: pad.reach(root.barMark, root.iconSize)

                        x: pad.reach(root.barMarkX(mark.index), (card.width - mark.markSize) / 2)
                        y: pad.reach(root.barMarkY, root.slot / 2 + mark.index * root.pitch - mark.markSize / 2)
                        size: Math.round(mark.markSize)
                        spec: AppIcons.markFor(Hypr.classOf(mark.modelData))
                        fallback: Apps.iconFor(Hypr.classOf(mark.modelData))
                        color: Hypr.isFocused(mark.modelData) ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
