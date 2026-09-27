pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE ARRANGEMENT CANVAS: the layout, drawn as the compositor holds it.
//
// Windows asked for this page's shape and Windows gets it: a top-down map
// where every output is a rectangle at its layout position, at one scale that
// fits them all, sized as they are sized (a 4K panel beside a vertical 1200x1920
// reads as the different animals they are). The rectangles are the monitors --
// CLICK one to make it the one the property card edits, DRAG one to move it.
//
// THE DRAG IS SECTION 15'S GESTURE, not a list-reorder DnD: one continuous
// pointer motion, the rect following the hand the whole way, the layout
// unchanged until release. Reversible right up until it is not, which is the
// whole argument; the 6px threshold before it starts is the same one
// DESIGN.md sets for every other drag here, because a touchpad flick covers
// less ground than a mouse and should still commit.
//
// SNAP keeps the map honest about what dragging is FOR. Monitors are placed
// edge to edge or not at all, so while a rect travels its edges seek the
// other rects' edges -- left to right, right to left, tops to tops -- within
// a 12 screen-pixel reach, and settle against the nearest claim per axis.
// A candidate that would overlap another output is refused ON ITS AXIS
// (x keeps x, y keeps y), which is not a limitation worked around but the
// honest model of what a physical desk can do: two panels cannot occupy the
// same glass, and sliding one sideways past another stops at it.
//
// ALL COORDINATES ARE LAYOUT PIXELS inside this file, converted at the edge:
// the canvas is one scale factor over the layout's bounding box, and the drag
// divides the pointer's travel by it. `x`/`y` on a Hyprland monitor are
// already logical, transform applied, so no rectangle here re-derives its
// size from the mode.
Item {
    id: root

    implicitHeight: 240

    // Which output is the one the property card edits.
    property string selected: ""

    // A click on a rect, and a drag let go of: the new top-left corner, in
    // layout pixels. The page owns what each means; the canvas owns only the
    // geometry of getting there.
    signal picked(string name)
    signal placed(string name, int x, int y)

    // Air between the drawn layout and the canvas's own edge, and the reach
    // of a snap, in SCREEN pixels -- divided by the fit scale at the moment
    // of use, because a threshold that made sense at 0.16 is invisible at
    // 0.4 and would swallow a whole screen at 0.05. The ZOOM is the fit's
    // own retreat: 0.85 of what would fill the box, so the map reads as a
    // map with air around it rather than as rectangles maxing out their
    // frame -- and there is room to see a dragged rect travel.
    readonly property real pad: Appearance.padding.normal
    readonly property real zoom: 0.85
    readonly property real reach: 12

    // The rects, from the service's polled truth. Position is layout already;
    // the SIZE is derived (mode over scale, swapped for the odd transforms),
    // because the json's width and height are what the panel is driven at,
    // not what it occupies.
    readonly property var rects: Monitors.outputs.filter(m => !m.disabled).map(m => ({
            name: m.name,
            x: m.x,
            y: m.y,
            w: Monitors.layoutOf(m).w,
            h: Monitors.layoutOf(m).h
        }))

    // THE BOUNDING BOX of the layout as it stands. The fit is computed from
    // this COMMITTED state, never from a drag in flight: a scale that chased
    // the dragged rect would breathe the whole map while you moved one thing,
    // and the map is the one part of the page that must hold still.
    readonly property var bounds: {
        let minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (const r of root.rects) {
            minx = Math.min(minx, r.x);
            miny = Math.min(miny, r.y);
            maxx = Math.max(maxx, r.x + r.w);
            maxy = Math.max(maxy, r.y + r.h);
        }
        return {
            minx,
            miny,
            maxx,
            maxy
        };
    }

    readonly property real fitScale: {
        const bw = Math.max(1, root.bounds.maxx - root.bounds.minx);
        const bh = Math.max(1, root.bounds.maxy - root.bounds.miny);
        return root.zoom * Math.min((root.width - root.pad * 2) / bw, (root.height - root.pad * 2) / bh);
    }

    // THE DRAWN LAYOUT IS CENTRED in the canvas, not pinned to its top-left:
    // with the fit scaled back to 0.85 the map has air on every side, and
    // centre placement is what makes that air even. Every mapping goes
    // through this origin, the drag's clamp included, so the canvas and the
    // rects cannot disagree about where the middle is.
    readonly property real originX: (root.width + root.pad * 2 - (root.bounds.maxx - root.bounds.minx) * root.fitScale) / 2
    readonly property real originY: (root.height + root.pad * 2 - (root.bounds.maxy - root.bounds.miny) * root.fitScale) / 2

    function mapX(layoutX: real): real {
        return root.originX + (layoutX - root.bounds.minx) * root.fitScale;
    }

    function mapY(layoutY: real): real {
        return root.originY + (layoutY - root.bounds.miny) * root.fitScale;
    }

    // The inverse mapping, for the drag: pointer travel arrives in canvas
    // pixels and the layout lives in its own.
    function unmapX(canvasX: real): real {
        return root.bounds.minx + (canvasX - root.originX) / root.fitScale;
    }

    function unmapY(canvasY: real): real {
        return root.bounds.miny + (canvasY - root.originY) / root.fitScale;
    }

    // One drag's live state. `active` gates the whole thing, `who` names the
    // rect, and the candidate position is LAYOUT pixels: the pointer's travel
    // divided by the fit scale, snapped, and refused per axis on overlap.
    property bool dragging: false
    property string who: ""
    property real startX: 0
    property real startY: 0
    property real baseX: 0
    property real baseY: 0
    property real liveX: 0
    property real liveY: 0

    // THE SNAP, one axis at a time, and the claims are every relationship a
    // monitor can have to another on this axis: MY EDGES to THEIR EDGES
    // (abutting, and corner meetings fall out of x and y doing it together),
    // and MY CENTRE to THEIR CENTRE (what a monitor stacked above or beside
    // one of a different size wants). Nearest claim within reach wins;
    // nothing within reach, the candidate stands as the hand left it.
    function snap(candidate: real, span: real, others: var): real {
        const t = root.reach / root.fitScale;
        let best = candidate;
        let bestD = t;
        const myEdges = [candidate, candidate + span, candidate + span / 2];
        for (const o of others) {
            const theirEdges = [o.x, o.x + o.w, o.x + o.w / 2];
            for (const mine of myEdges)
                for (const theirs of theirEdges) {
                    const d = theirs - mine;
                    if (Math.abs(d) < Math.abs(bestD)) {
                        bestD = d;
                        best = candidate + d;
                    }
                }
        }
        return best;
    }

    // OVERLAP IS REFUSED, axis by axis. The candidate rectangle on ONE axis
    // moved is tested against every other rect; an interior intersection
    // (sharing an edge is adjacency, not collision) refuses that axis and
    // keeps the other, which is how a drag along a wall of monitors slides
    // instead of stopping dead.
    function collides(x: real, y: real, w: real, h: real, others: var): bool {
        for (const o of others)
            if (x < o.x + o.w - 1 && x + w > o.x + 1 && y < o.y + o.h - 1 && y + h > o.y + 1)
                return true;
        return false;
    }

    Repeater {
        model: root.rects

        delegate: G2Rect {
            id: rect

            required property var modelData

            // The dragged rect draws at the candidate; everything else draws
            // at the truth. A NaN test rather than an identity test because
            // the candidate is two reals, not an object with one.
            readonly property bool isDrag: root.dragging && root.who === rect.modelData.name
            readonly property bool isSelected: root.selected === rect.modelData.name

            x: root.mapX(isDrag ? root.liveX : rect.modelData.x)
            y: root.mapY(isDrag ? root.liveY : rect.modelData.y)
            width: Math.max(Appearance.font.stem * 8, rect.modelData.w * root.fitScale)
            height: Math.max(Appearance.font.stem * 8, rect.modelData.h * root.fitScale)
            radius: Appearance.rounding.small

            // SELECTED IS THE ACCENT, unmistakably: tinted fill and the
            // accent stroke, because the property card beside the canvas has
            // a title and the canvas has to agree with it. Unselected is the
            // surface, quieter, with a faint stroke -- present, not asking.
            color: isSelected ? Appearance.colour.accentFill : Appearance.colour.surfaceAlt
            stroke: isSelected ? Appearance.colour.accent : Appearance.colour.textGhost
            strokeWidth: isSelected ? Appearance.font.stem : 1

            Column {
                anchors.centerIn: parent

                // Clipped by the rect: a label that outgrew a small monitor
                // would draw over its neighbours' glass.
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: rect.modelData.name
                    color: rect.isSelected ? Appearance.colour.text : Appearance.colour.textDim
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const m = Monitors.outputs.find(o => o.name === rect.modelData.name);
                        return m ? `${m.width}×${m.height}` : "";
                    }
                    color: Appearance.colour.textFaint
                }
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                onPressed: mouse => {
                    root.dragging = true;
                    root.who = rect.modelData.name;
                    root.startX = mouse.x;
                    root.startY = mouse.y;
                    root.baseX = rect.modelData.x;
                    root.baseY = rect.modelData.y;
                    root.liveX = rect.modelData.x;
                    root.liveY = rect.modelData.y;
                }

                onPositionChanged: mouse => {
                    if (!root.dragging || root.who !== rect.modelData.name)
                        return;

                    const others = root.rects.filter(r => r.name !== rect.modelData.name);

                    // Pointer travel, back into layout pixels.
                    let cx = root.baseX + (mouse.x - root.startX) / root.fitScale;
                    let cy = root.baseY + (mouse.y - root.startY) / root.fitScale;

                    // Snap first, refuse overlap second: a snap that landed on
                    // a neighbour's edge is exactly where monitors live.
                    cx = root.snap(cx, rect.modelData.w, others);
                    cy = root.snap(cy, rect.modelData.h, others);

                    // HELD INSIDE THE CANVAS, in mapped pixels -- and not one
                    // layout-bound further. The clamp used to hold the rect to
                    // the COMMITTED bounding box, which quietly froze
                    // whichever monitor owned an edge of it: the vertical
                    // panel at the origin could not leave, because every
                    // direction out was "outside the layout". The canvas is
                    // the extent now: a monitor can be carried anywhere it
                    // stays visible, the bounds grow with it, and the fit
                    // re-zooms once the compositor confirms.
                    const w = rect.width;
                    const h = rect.height;
                    const mx = Math.max(0, Math.min(root.width - w, root.mapX(cx)));
                    const my = Math.max(0, Math.min(root.height - h, root.mapY(cy)));

                    if (!root.collides(cx, root.liveY, rect.modelData.w, rect.modelData.h, others))
                        root.liveX = root.unmapX(mx);
                    if (!root.collides(root.liveX, cy, rect.modelData.w, rect.modelData.h, others))
                        root.liveY = root.unmapY(my);
                }

                onReleased: {
                    const moved = Math.abs(root.liveX - root.baseX) > 0.5 || Math.abs(root.liveY - root.baseY) > 0.5;
                    const who = root.who;
                    const x = Math.round(root.liveX);
                    const y = Math.round(root.liveY);
                    root.dragging = false;
                    root.who = "";
                    if (moved)
                        root.placed(who, x, y);
                }

                onClicked: root.picked(rect.modelData.name)
            }
        }
    }
}
