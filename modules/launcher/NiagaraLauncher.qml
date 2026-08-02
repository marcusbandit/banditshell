pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE NIAGARA CONCEPT: text before icons, and the alphabet as the interface.
//
// After the Android launcher of the same name, whose argument is that a grid of
// several hundred identical squares is a filing cabinet, not a home. So it does
// not show you one. At rest there are a handful of names, and everything else
// lives behind an A-Z RAIL you scrub with your thumb: the letter under it is
// what you are looking at, and the apps under that letter appear beside it.
//
// Three things carry it across to a desktop:
//
//   TEXT. No icons at all here, which is the deliberate opposite of the list
//   concept sitting next to it. A name read is faster than a picture recognised
//   once you already know what you want, and a column of names is quiet in a way
//   a column of logos cannot be.
//
//   FEW. At rest this shows only what you actually use, taken from the same
//   frecency the other concept ranks by. Niagara calls them favourites and asks
//   you to pick them; the shell already knows.
//
//   THE RAIL. On a phone it is a thumb gesture. On a desktop the cursor is
//   already precise, so hovering it is enough: no click, no drag, run down the
//   edge and the list follows. Letters with nothing under them are not drawn, so
//   the rail is the shape of what is installed.
//
// It hangs the full height of the content area and fills from the BOTTOM, which
// is where a phone puts things it expects to be reached. The emptiness above is
// the design, not an unfinished part of it.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real panelWidth: Config.values.launcher.niagara.width
    readonly property real railWidth: Config.values.launcher.niagara.rail
    readonly property int favouriteCount: Config.values.launcher.niagara.favourites

    readonly property Item maskItem: catcher

    // The blob the chassis melts in. Without it the panel has no surface at all
    // and the names hang in the middle of the desktop: this concept draws no
    // background of its own, exactly like every other panel in the shell.
    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    // The whole alphabet, as the apps actually installed make it.
    //
    // Keyed by first letter, everything non-alphabetic under "#". Built from the
    // data rather than from a hardcoded A-Z, so the rail has no dead letters on
    // it and a machine with no Q applications does not offer you a Q.
    readonly property var byLetter: {
        const out = {};
        for (const entry of Apps.all) {
            const name = (entry.name ?? "").trim();
            if (!name)
                continue;
            const first = name[0].toUpperCase();
            const key = first >= "A" && first <= "Z" ? first : "#";
            if (!out[key])
                out[key] = [];
            out[key].push(entry);
        }
        for (const key in out)
            out[key].sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
        return out;
    }

    readonly property var letters: Object.keys(root.byLetter).sort()

    // Which letter the rail is on. Sticky once set: on a phone you let go and it
    // goes home, but here you have to be able to leave the rail and cross the
    // panel to click what you came for.
    property string letter: ""

    // What the list is showing, and why. Typing beats scrubbing beats resting.
    readonly property var entries: {
        if (query.text)
            return Apps.search(query.text);
        if (root.letter)
            return root.byLetter[root.letter] ?? [];
        return Apps.search("").slice(0, root.favouriteCount);
    }

    property int selected: 0

    readonly property real rowPitch: Appearance.font.size.large + Appearance.padding.large

    // For `banditshell status`.
    readonly property real drawnHeight: panel.height
    readonly property int resultCount: entries.length
    readonly property string scrollInfo: `${root.letter ? `letter ${root.letter}` : query.text ? "search" : "favourites"}, row ${root.selected} of ${root.entries.length}`

    // What had the keyboard before this took it; see ListLauncher, same reason.
    property string restoreTo: ""

    function show(): void {
        root.restoreTo = Hypr.focusedAddress;
        root.shown = true;
        query.text = "";
        root.letter = "";
        root.selected = 0;
        Qt.callLater(query.forceActiveFocus);
    }

    function hide(): void {
        root.shown = false;
        query.focus = false;
        Hypr.focusAddress(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function accept(): void {
        const entry = root.entries[root.selected];
        if (entry) {
            Apps.launch(entry);
            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    function move(delta: int): void {
        const n = root.entries.length;
        if (n > 0)
            root.selected = (root.selected + delta + n) % n;
    }

    // Which letter a point on the rail is, computed from where it falls rather
    // than from a stack of hit areas: one area, one division, and it stays right
    // whatever the alphabet turns out to contain.
    function scrubAt(y: real): void {
        const n = root.letters.length;
        if (n <= 0)
            return;
        const index = Math.max(0, Math.min(Math.floor(y / rail.height * n), n - 1));
        const next = root.letters[index];
        if (next !== root.letter) {
            root.letter = next;
            root.selected = 0;
            query.text = "";
        }
    }

    onEntriesChanged: root.selected = 0

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // Under the panel, so a click anywhere else puts it away.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real fullHeight: root.height - root.inset * 2

        x: (root.width - width) / 2
        width: root.panelWidth

        // Grows UPWARD out of the bottom band, and stays joined to it the whole
        // way: the panel is a column rising out of the shell rather than a sheet
        // arriving over it.
        height: fullHeight * rise.value
        y: bandY - height

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            // THE RAIL. Down the right edge, full height, and the only thing in
            // the panel that is always in the same place.
            MouseArea {
                id: rail

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.large
                width: root.railWidth

                hoverEnabled: true
                // Hover, not press. The gesture on a phone is a drag because a
                // thumb has to commit to the edge; a cursor is already there.
                //
                // Driven off mouseY rather than the positionChanged signal. The
                // signal is only emitted for real motion, so a pointer that
                // arrives on the rail by any other route (a warp, a workspace
                // switch landing under it) gets an enter and nothing else, and
                // the rail sits there doing nothing under a cursor that is
                // plainly on it. The property is true whenever the pointer is
                // inside, however it got there.
                // EVENTS ONLY, never a binding on mouseY. Driving it from the
                // position property looked more robust and was worse: the panel
                // rises when it opens, so the rail moves under a cursor that is
                // not moving, mouseY changes every frame of the animation, and
                // the launcher opens already scrubbed to a letter nobody asked
                // for. A pointer event happens because the pointer did
                // something.
                // MOTION only, not entry. The panel rises when it opens, so
                // the rail arrives under whatever the cursor happened to be
                // sitting on and an entry-triggered scrub means the launcher
                // opens on a letter nobody chose. Reaching the rail requires
                // moving to it, and moving to it is a position event.
                onPositionChanged: mouse => root.scrubAt(mouse.y)

                Repeater {
                    model: root.letters

                    delegate: StyledText {
                        required property string modelData
                        required property int index

                        // Evenly divided by count, so the rail fills its height
                        // whether there are twelve letters on it or twenty-seven.
                        readonly property real slot: rail.height / root.letters.length

                        y: index * slot + (slot - implicitHeight) / 2
                        width: rail.width
                        horizontalAlignment: Text.AlignHCenter

                        text: modelData
                        font.pixelSize: Appearance.font.size.small
                        color: modelData === root.letter ? Appearance.colour.accent : Appearance.colour.textFaint
                    }
                }
            }

            // The query, at the BOTTOM, where a phone puts the thing you reach
            // for. Everything else stacks upward off it.
            Item {
                id: field

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.large
                height: Appearance.font.size.large + Appearance.padding.normal

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !query.text
                    text: root.letter ? root.letter : "Type, or run the rail"
                    font.pixelSize: Appearance.font.size.large
                    color: root.letter ? Appearance.colour.accent : Appearance.colour.textGhost
                }

                TextInput {
                    id: query

                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.large
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    clip: true

                    // Typing means you have stopped browsing.
                    onTextChanged: if (text)
                        root.letter = ""

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.hide();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.accept();
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            root.move(1);
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            root.move(-1);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }

            // The names, stacked UP off the field. Bottom-aligned, so a short
            // list sits low and a long one grows into the empty space above
            // rather than the list starting somewhere different every time.
            Column {
                id: names

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                spacing: Appearance.padding.normal

                Repeater {
                    model: ScriptModel {
                        // Only what fits. The rail is how you get to the rest,
                        // so a letter with forty applications under it is a
                        // reason to type, not a reason to scroll.
                        values: root.entries.slice(0, Math.max(1, Math.floor((panel.fullHeight - field.height - Appearance.padding.large * 3) / root.rowPitch)))
                    }

                    delegate: StyledText {
                        required property var modelData
                        required property int index

                        width: names.width
                        text: modelData.name ?? ""
                        font.pixelSize: Appearance.font.size.large
                        color: index === root.selected ? Appearance.colour.text : Appearance.colour.textDim
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Appearance.padding.small
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = parent.index
                            onClicked: {
                                root.selected = parent.index;
                                root.accept();
                            }
                        }
                    }
                }
            }
        }
    }
}
