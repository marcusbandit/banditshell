pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE WAIT BETWEEN PRESSING RETURN AND A WINDOW APPEARING.
//
// You asked for something, the launcher went back into the bottom band, and
// until the window maps there is nothing on screen that says the key registered.
// This is what stands in that gap: the icon of what you asked for, its name, and
// a bar filled against how long THIS application took last time (see
// services/Launching.qml). It leaves when the window lands, and it says so
// instead of quietly vanishing when nothing ever comes.
//
//   rows        one pill per launch in flight, oldest at the top of the stack
//   rise        the whole stack coming out of the bottom band and going back
//   bar         progress, against the app's own measured start-up time
//
// A blob in the shell's distance field, like the notch and the mic indicator, so
// it melts out of the same edge the launcher just went into rather than being
// drawn on top of the shell.
Item {
    id: root

    property int border: Appearance.sizes.border

    // Nothing is drawn until an application has had its grace period, so the
    // things that open instantly never flash a pill.
    //
    // CAPPED, because every pill costs a slot in the shell's distance field and
    // there are twelve for the whole shell (see BlobField.capacity). The NEWEST
    // are kept: the one you just asked for is the one you are waiting on.
    readonly property int stackMax: 3
    readonly property var rows: Launching.shown.slice(-root.stackMax)
    readonly property bool out: root.rows.length > 0

    // ------------------------------------------------------------------
    // WHAT A PILL SAYS
    //
    // One sentence shape in all three states, so only the verb in front of the
    // name changes. The width arithmetic below measures THIS table rather than a
    // number typed beside it: reword a verb and the pill still fits it.
    readonly property var verbs: ({
            waiting: "Opening",
            here: "Opened",
            lost: "Gave up on"
        })

    function tone(state: string): color {
        return state === "lost" ? Appearance.colour.alarm : Appearance.colour.accent;
    }

    // ------------------------------------------------------------------
    // SIZE KNOBS

    // The launcher's own icon size: this is its echo, so it uses its scale.
    readonly property real markSize: Appearance.sizes.launcherIcon

    // TEXT WIDTH IN CHARACTERS, which Monocraft being monospaced makes exact
    // rather than a guess: the pill is as wide as the longest sentence it could
    // ever say about THIS application, so it fits its name and still cannot
    // resize (and reflow the chassis) when the verb in front of it changes.
    //
    // The ceiling is where a name starts being elided instead.
    readonly property int maxChars: 40
    readonly property int verbChars: Math.max(...Object.values(root.verbs).map(v => v.length))

    function charsFor(rec: var): int {
        return Math.min(root.maxChars, root.verbChars + 1 + (rec.name ?? "").length);
    }

    function textWidthFor(rec: var): real {
        return em.advanceWidth * root.charsFor(rec);
    }

    function pillWidthFor(rec: var): real {
        return Appearance.padding.huge * 2 + root.markSize + Appearance.padding.large + root.textWidthFor(rec);
    }

    readonly property real barHeight: Appearance.font.stem

    readonly property real lineHeight: em.height
    readonly property real contentHeight: Math.max(root.markSize, root.lineHeight + Appearance.padding.small + root.barHeight)

    // The bottom `border` of the pill is inside the band, which is what makes it
    // read as something the edge produced rather than a card sitting on it.
    readonly property real pillHeight: Appearance.padding.large * 2 + root.contentHeight + root.border

    readonly property real stackGap: Appearance.padding.small

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    // ------------------------------------------------------------------
    // WHERE EACH PILL SITS
    //
    // Slot 0 is against the band; the stack grows upward, oldest at the top. A
    // pill leaving from the middle of a stack reflows the ones above it in one
    // frame, which is a jump nobody has yet seen: launches come one at a time.
    function slotY(slot: int): real {
        return root.height - root.pillHeight - slot * (root.pillHeight + root.stackGap);
    }

    // Off the bottom by a full melt distance when retracted, for the reason the
    // mic indicator states: a blob that merely shrinks in place still drags the
    // band toward it and leaves a permanent bulge.
    function rowY(slot: int): real {
        const settled = root.slotY(slot);
        return settled + (root.height + Appearance.sizes.melt - settled) * (1 - rise.value);
    }

    function slotOf(i: int): int {
        return root.rows.length - 1 - i;
    }

    readonly property var blobs: rise.value <= 0.001 ? [] : root.rows.map((rec, i) => ({
                x: (root.width - root.pillWidthFor(rec)) / 2,
                y: root.rowY(root.slotOf(i)),
                w: root.pillWidthFor(rec),
                h: root.pillHeight,
                radius: Appearance.rounding.large
            }))

    Follow {
        id: rise

        speed: Appearance.anim.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.005
    }

    Repeater {
        model: root.rows

        Item {
            id: pill

            required property int index
            required property var modelData

            readonly property real pillWidth: root.pillWidthFor(pill.modelData)
            readonly property real textWidth: root.textWidthFor(pill.modelData)

            x: (root.width - pill.pillWidth) / 2
            y: root.rowY(root.slotOf(pill.index))
            width: pill.pillWidth
            height: root.pillHeight
            opacity: rise.value

            Item {
                id: content

                x: Appearance.padding.huge
                y: Appearance.padding.large
                width: pill.pillWidth - Appearance.padding.huge * 2
                height: root.contentHeight

                AppMark {
                    id: art

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    spec: pill.modelData.mark
                    size: root.markSize
                    fallback: Apps.genericIcon
                    // A lost launch is still the application you asked for, so
                    // the artwork stays: which one failed is the useful half.
                    opacity: pill.modelData.state === "lost" ? 0.5 : 1
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: Appearance.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    width: pill.textWidth
                    spacing: Appearance.padding.small

                    Row {
                        spacing: em.advanceWidth

                        StyledText {
                            id: lead

                            text: root.verbs[pill.modelData.state] ?? root.verbs.waiting
                            color: root.tone(pill.modelData.state)
                        }

                        StyledText {
                            width: pill.textWidth - lead.width - em.advanceWidth
                            text: pill.modelData.name
                            elide: Text.ElideRight
                        }
                    }

                    // THE BAR. Square ends on purpose: it is a rule drawn beside
                    // pixel type, not a capsule (see the G2 corner rule - the
                    // only radius allowed here would be a plain circular one).
                    Item {
                        width: pill.textWidth
                        height: root.barHeight

                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.colour.fill
                        }

                        Rectangle {
                            width: parent.width * Launching.progress(pill.modelData)
                            height: parent.height
                            color: root.tone(pill.modelData.state)
                        }
                    }
                }
            }
        }
    }
}
