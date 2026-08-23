pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components.blob
import qs.components
import qs.services

// Area selection, over one screen.
//
// Two gestures, and hovering is the first of them: with nothing pressed the
// selection SNAPS to whatever window is under the cursor, so the common case
// (capture that window) is a hover and a click rather than a careful drag along
// four edges. Press and drag for a free region. This is caelestia's model, and
// it is the right one.
//
// The dim outside the selection reuses the chassis's own field, so the selection
// gets the compositor's corner curve for free and matches the window it is
// snapped to instead of approximating it.
MouseArea {
    id: root

    required property PickerState state
    required property ShellScreen screen

    // True while the selection is locked to a window rather than freely dragged.
    property bool onWindow: false

    property real pressX: 0
    property real pressY: 0

    // WHETHER THIS PRESS EVER BECAME A DRAG, which is the one thing the release
    // could not previously ask. Set false by every press and true by the same
    // threshold test `onPositionChanged` already applies, hoisted out of it so
    // there is one answer rather than two places that each compute their own.
    property bool dragged: false

    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0

    readonly property real rx: Math.min(sx, ex)
    readonly property real ry: Math.min(sy, ey)
    readonly property real rw: Math.abs(sx - ex)
    readonly property real rh: Math.abs(sy - ey)

    // A window's own corner when snapped to one, square when free: a free region
    // is a crop, and a crop with rounded corners would be a lie about what the
    // file will contain.
    readonly property real radius: onWindow ? Appearance.sizes.windowRadius : 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    focus: true

    Keys.onEscapePressed: root.state.close()

    function snapTo(x: real, y: real): void {
        for (const client of Hypr.clientsOn(root.screen)) {
            const at = client.lastIpcObject.at;
            const size = client.lastIpcObject.size;
            const cx = at[0] - root.screen.x;
            const cy = at[1] - root.screen.y;
            if (x >= cx && y >= cy && x <= cx + size[0] && y <= cy + size[1]) {
                root.onWindow = true;
                root.sx = cx;
                root.sy = cy;
                root.ex = cx + size[0];
                root.ey = cy + size[1];
                return;
            }
        }
    }

    // Take what is currently selected, whatever chose it.
    function commit(): void {
        root.state.capture(root.screen, Math.round(root.rx), Math.round(root.ry), Math.round(root.rw), Math.round(root.rh));
    }

    // THE FIRST REGION COMES FROM A REAL POINTER EVENT OR IT DOES NOT HAPPEN.
    //
    // This used to run at Component.onCompleted, off `mouseX`/`mouseY`, and lay
    // down a two-hundred-pixel box in the middle of the screen when that found
    // no window. Both halves were wrong, and together they were a bug with teeth.
    // A MouseArea's mouseX/mouseY are whatever the last event left in them, and
    // at completion this surface has had no events at all; a touchscreen never
    // produces a hover, so they stay at zero for its whole life. The picker
    // therefore started out holding either whatever window happens to sit at the
    // origin or a rectangle nobody had chosen, and a press that never became a
    // drag then CAPTURED that rectangle and, outside clipboard mode, opened the
    // editor on it.
    //
    // An enter is the first moment the surface actually knows where a pointer
    // is, and a finger never sends one. So a pointer gets its snap the instant
    // it arrives and a finger starts with NO region at all, which is the honest
    // state and which onReleased below now reads correctly as "nothing chosen".
    onEntered: root.snapTo(root.mouseX, root.mouseY)

    // The same seed for the case an enter cannot cover: a pointer already inside
    // the surface before this had finished being built. Guarded on
    // `containsMouse`, which is the toolkit stating that a pointer is genuinely
    // there, rather than this inferring one from coordinates that may never have
    // been written.
    Component.onCompleted: {
        if (root.containsMouse)
            root.snapTo(root.mouseX, root.mouseY);
    }

    onPressed: event => {
        // SNAP FIRST, before this press records anything about itself.
        //
        // With a pointer this is idempotent: the hover below has already snapped
        // to whatever is under the cursor and asking again in the same place
        // finds the same window. With a finger it is the only chance the picker
        // ever gets. The hover snap runs only while nothing is pressed, and a
        // finger produces motion ONLY while it is down, so there is no such
        // thing as a hovering finger and window snapping was simply unreachable
        // by touch. Snapping here makes press-then-lift on a window capture that
        // window, which is the natural touch reading of "point at the thing you
        // want".
        root.snapTo(event.x, event.y);

        root.pressX = event.x;
        root.pressY = event.y;
        // Nothing has been dragged yet, and the release has to be able to tell.
        root.dragged = false;
    }

    onPositionChanged: event => {
        if (!root.pressed)
            return root.snapTo(event.x, event.y);

        // Past the drag threshold this stops being a click on a window and
        // becomes a free region.
        if (Math.abs(event.x - root.pressX) + Math.abs(event.y - root.pressY) < Appearance.sizes.dragThreshold)
            return;

        root.dragged = true;
        root.onWindow = false;
        root.sx = root.pressX;
        root.sy = root.pressY;
        root.ex = event.x;
        root.ey = event.y;
    }

    // THREE THINGS A RELEASE CAN MEAN, and it used to be able to tell two of
    // them apart while doing the wrong thing for the third.
    //
    // The old test was the SIZE of the region, which cannot answer the question:
    // a region that nobody dragged is still a region with a size, so a press and
    // a release with no movement in between captured whatever the selection
    // happened to be holding, and what it was holding at that moment was
    // whatever had been seeded before any input arrived. What matters is not how
    // big the rectangle is but whether anything actually chose it.
    onReleased: {
        // IT WAS DRAGGED: take the region that was dragged, exactly as before. A
        // rectangle with no area is still not a region, so the degenerate case
        // cancels rather than asking grim for a zero-pixel crop.
        if (root.dragged) {
            if (root.rw < 2 || root.rh < 2)
                return root.state.close();
            return root.commit();
        }

        // IT WAS NOT, AND A WINDOW IS SNAPPED: take the window. This is the
        // existing pointer flow (hover a window, click it) and it is unchanged;
        // it is also now the touch flow, because the press above snaps first.
        if (root.onWindow)
            return root.commit();

        // IT WAS NOT, AND NOTHING IS SNAPPED: a tap on empty space is the one
        // gesture that plainly means "not this", so it cancels.
        root.state.close();
    }

    // The frozen frame, when the picker was opened in freeze mode: THIS
    // screen's, asked for by name. Underneath everything, so the dim and the
    // selection sit on top of it exactly as they would over the live screen.
    //
    // Every surface used to read one shared path, which held the whole layout
    // as a single image, so filling this surface with it drew both monitors
    // squeezed across one of them. The state keeps a frame per output now (see
    // PickerState), and the only one this surface has any business drawing is
    // the one taken from the output it is on.
    //
    // Which is also what makes Stretch honest rather than a squash: the source
    // is this screen and nothing else, so the two differ only by the output's
    // scale, the same factor on both axes, and filling the surface puts every
    // pixel back where it came from.
    Image {
        id: frozen

        readonly property string path: root.state.frozenByScreen[root.screen.name] ?? ""

        anchors.fill: parent
        visible: frozen.path !== ""
        source: frozen.path ? `file://${frozen.path}` : ""
        fillMode: Image.Stretch
        cache: false
    }

    // Everything except the selection, dimmed. The chassis's own field: give it
    // the selection as its content area and no band, and what it draws is the
    // hole's complement with the right corner curve.
    BlobField {
        anchors.fill: parent

        colour: Appearance.colour.scrim
        content: Qt.vector4d(root.rx, root.ry, root.rw, root.rh)
        baseRadius: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
        gap: 0
        band: 0
        frameOn: 0
        smoothing: 0
        // The selection is a hard edge, not a melt: it has to say exactly where
        // the crop will be.
        outlineWidth: Appearance.sizes.pickerOutline
        outlineColour: Appearance.colour.accent
    }

    // What it will do, where you are looking. Follows the selection rather than
    // sitting in a corner, because a hint you have to go and find is not a hint.
    //
    // AND IT IS THE WAY OUT. Escape was the only cancel this had, and escape is
    // a key a tablet does not have; a tap on empty space cancels now (see
    // onReleased), but that is a thing you have to be told, and this readout is
    // already the one place on the screen doing the telling. So it says both
    // routes and answers the one it can. Deliberately NOT a new button: the
    // shell does not draw close buttons on things (DESIGN.md 2.1), and this is
    // the same surface, the same text and the same corner curve it always was,
    // one phrase longer.
    Item {
        id: readout

        x: Math.min(root.width - width, Math.max(0, root.rx + root.rw / 2 - width / 2))
        // Measured against THIS box rather than against the text inside it,
        // which is what it used to read: the box is what has to fit on the
        // screen, and it is taller than its text by the padding and, on a short
        // line, by the target floor below.
        y: root.ry + root.rh + Appearance.padding.normal > root.height - readout.height ? root.ry - height - Appearance.padding.normal : root.ry + root.rh + Appearance.padding.normal

        implicitWidth: hint.implicitWidth + Appearance.padding.large * 2
        // Never under the minimum size anything in this shell is allowed to be,
        // now that it is something you press rather than something you read. The
        // padded text clears that on its own today; the floor is here so it goes
        // on clearing it if the type scale is ever turned down.
        implicitHeight: Math.max(Appearance.sizes.minTarget, hint.implicitHeight + Appearance.padding.normal * 2)
        width: implicitWidth
        height: implicitHeight

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            // One step up under the pointer, which is the whole of what says
            // this is a control. A cursor that lands on it should be able to see
            // that it does something before finding out by pressing.
            color: cancel.containsMouse ? Appearance.colour.fill : Appearance.colour.surface

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: hint

            anchors.centerIn: parent
            text: `${root.rw} x ${root.rh}   ${root.onWindow ? "window" : "region"}   ${root.state.clipboardOnly ? "to clipboard" : "to editor"}   tap here or esc to cancel`
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }

        // DECLARED LAST, so it is on top of the surface and the text it covers.
        // Both of those are inert, so there is nothing here to sit in front of
        // and steal from; the order is only so that this is the thing the press
        // reaches.
        MouseArea {
            id: cancel

            anchors.fill: parent
            hoverEnabled: true
            // Not the crosshair the rest of the overlay wears. The crosshair
            // says "this is where you cut", and this is the one patch of the
            // screen where that is not what will happen.
            cursorShape: Qt.PointingHandCursor
            onClicked: root.state.close()
        }
    }
}
