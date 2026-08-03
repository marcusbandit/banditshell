pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE NIAGARA CONCEPT: everything installed, in one sectioned column, indexed by
// an alphabet rail.
//
// After the Android launcher of the same name. Its argument is not that icons
// are bad, it is that a GRID is: several hundred squares in an arbitrary order
// is a filing cabinet you have to read left to right. So it keeps the icons and
// throws away the grid. One column, alphabetical, each letter announced in the
// margin, and a rail down the edge that jumps to any of them.
//
// Three things carry it across to a desktop:
//
//   THE STAR. The list does not begin at A. It begins with what you actually
//   use, under a star, and the alphabet follows underneath. Niagara asks you to
//   choose those; the shell already knows, off the same frecency the list
//   concept ranks by.
//
//   THE RAIL IS AN INDEX, NOT A FILTER. Everything is in the column the whole
//   time; running down the rail scrolls to a letter rather than replacing what
//   is on screen, so the list being looked at is always the same list.
//
//   THE MARGIN. Letters sit outside the column of icons rather than in it, so
//   every name starts at one x and the sections read as annotations on a
//   continuous list instead of as headings that chop it into blocks.
//
// It rises out of the BOTTOM band and the search sits at the bottom, where a
// phone puts what it expects to be reached.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real panelWidth: Config.values.launcher.niagara.width
    readonly property real railWidth: Config.values.launcher.niagara.rail
    readonly property int favouriteCount: Config.values.launcher.niagara.favourites
    readonly property real iconSize: Config.values.launcher.niagara.icon
    readonly property real bowDepth: Config.values.launcher.niagara.bow
    readonly property real bowSpread: Config.values.launcher.niagara.bowSpread
    readonly property real badgeSize: Config.values.launcher.niagara.badge

    // The letter's column, outside the icons'. Wide enough for the character and
    // no wider, so the names sit as close to the edge as the annotation allows.
    readonly property real gutter: Appearance.font.size.large + Appearance.padding.normal

    readonly property real rowPitch: root.iconSize + Appearance.padding.normal
    readonly property real sectionPitch: Appearance.font.size.large + Appearance.padding.large

    // The mark for the favourites section. Not a letter, because they are not
    // filed under one.
    //
    // Held as a KEY, drawn as an icon: Monocraft is a pixel face with no star in
    // it, so setting one as text renders the missing-glyph box, which is a
    // perfectly good way to make a launcher look broken. The key is what the
    // sections and the rail agree on; what gets drawn for it is a separate
    // question and belongs to the icon font.
    readonly property string star: "favourites"
    readonly property string starIcon: "star"

    // The last mark on the rail: everything you have put away. Held the same way
    // the star is, and for the same reason, and it appears only when there is
    // something in it, exactly like a letter.
    //
    // A drawer rather than a delete. Hiding an application you use twice a year
    // has to be a cheap decision or nobody makes it, and it is only cheap if
    // undoing it is one gesture away rather than a config file away.
    readonly property string vault: "hidden"
    readonly property string vaultIcon: "visibility_off"

    // A section key drawn as a GLYPH rather than as itself, or "" when the key
    // is already the thing to draw.
    //
    // The letters are text. The two keys that are not letters are icons: the
    // star because Monocraft is a pixel face with no star in it and setting one
    // renders the missing-glyph box, and the drawer because "hidden" is a word
    // and the rail is a ruler with single marks on it.
    function keyIcon(key: string): string {
        if (key === root.star)
            return root.starIcon;
        if (key === root.vault)
            return root.vaultIcon;
        return "";
    }

    readonly property Item maskItem: catcher

    // The blob the chassis melts in. This concept draws no background of its
    // own, exactly like every other panel in the shell.
    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    // The alphabet, as the applications actually installed make it. Everything
    // non-alphabetic lands under "#". Built from the data rather than from a
    // hardcoded A-Z, so the rail has no dead letters on it.
    //
    // WITHIN a letter, most-used first rather than alphabetical.
    //
    // The initial is the whole of what the rail asked for, so sorting by the
    // rest of the name adds nothing: it is a second alphabetical sort applied to
    // a set that was chosen alphabetically. Ranking by use makes the top of
    // every letter the answer you probably wanted, which is what lets the first
    // row under a letter be the selected one (see markSection).
    readonly property var byLetter: {
        const out = {};
        for (const entry of Apps.visible) {
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
            out[key] = Apps.byUse(out[key]);
        return out;
    }

    readonly property var letters: Object.keys(root.byLetter).sort()
    readonly property var favourites: Apps.search("").slice(0, root.favouriteCount)

    // What the rail offers: the star, then whatever letters exist, then the
    // drawer if anything is in it.
    readonly property var keys: [root.star, ...root.letters, ...(Apps.buried.length ? [root.vault] : [])]

    // ONE FLAT LIST of rows, sections included, rather than a list of lists.
    //
    // A ListView cannot scroll to something it has no row for, and the rail's
    // whole job is to scroll to a letter. Flattening puts the sections in the
    // same coordinate space as the applications, so "where is T" is arithmetic
    // rather than a search through nested delegates.
    readonly property var rows: {
        if (query.text)
            return Apps.search(query.text).map(entry => ({
                        section: "",
                        entry: entry
                    }));

        const out = [];
        if (root.favourites.length) {
            out.push({
                section: root.star,
                entry: null
            });
            for (const entry of root.favourites)
                out.push({
                    section: "",
                    entry: entry
                });
        }
        for (const key of root.letters) {
            out.push({
                section: key,
                entry: null
            });
            for (const entry of root.byLetter[key])
                out.push({
                    section: "",
                    entry: entry
                });
        }
        if (Apps.buried.length) {
            out.push({
                section: root.vault,
                entry: null
            });
            for (const entry of Apps.buried)
                out.push({
                    section: "",
                    entry: entry
                });
        }
        return out;
    }

    // Where each section starts and how tall it is WITH its applications, in the
    // list's own coordinates. Accumulated once per change rather than measured
    // off the delegates, which only exist for the part of the list currently on
    // screen.
    //
    // The height is the whole point: a section is a BLOCK, not a heading, and
    // centring a letter means centring the letter and everything filed under it.
    readonly property var sectionSpan: {
        const out = {};
        let y = 0;
        let key = "";
        for (const row of root.rows) {
            if (row.section) {
                key = row.section;
                out[key] = {
                    y: y,
                    h: root.sectionPitch
                };
                y += root.sectionPitch;
            } else {
                if (key)
                    out[key].h += root.rowPitch;
                y += root.rowPitch;
            }
        }
        return out;
    }

    // How tall the whole column wants to be. From the COUNT, never measured off
    // the list: contentHeight is an estimate until every delegate has been
    // built, and this is what decides whether the list is tall enough to need
    // scrolling at all.
    readonly property real needed: root.rowY(root.rows.length)

    // SLACK UNDER THE LAST SECTION, so the last letter can sit in the middle of
    // the view like every other one.
    //
    // Without it the bottom of the list is the bottom of the list: scrolling to
    // Z pins Z's two applications to the floor, and the one section that cannot
    // be centred is the one you reach by running the rail all the way down.
    // Half a view minus half the block is exactly the room that costs.
    readonly property real tail: {
        if (root.needed <= list.height)
            return 0;
        for (let i = root.rows.length - 1; i >= 0; i--) {
            const key = root.rows[i].section;
            if (key)
                return Math.max(0, (list.height - root.sectionSpan[key].h) / 2);
        }
        return 0;
    }

    // Which section the rail is pointing at, and where the HANDLE is: how far
    // down the rail, and how far out of it.
    //
    // Both axes come from the drag, which is the whole gesture. Hover did the
    // job with one axis and a constant for the other, and that is a different,
    // worse gesture wearing the same picture: the curve was always the same
    // depth, so there was nothing to feel. How far you pull it out is how far
    // you have committed to the rail, and it is yours to vary.
    property string marked: ""
    property real scrubY: 0
    property real depth: 0
    property bool grabbing: false

    // WHICH ROW THE POINTER IS OVER, which is a different question from which
    // row is selected, and this is the whole of the difference.
    //
    // Hover used to move the selection, guarded by a "has the pointer moved
    // yet" flag. The guard could not work, because the pointer is not the only
    // thing that moves: type a letter and the list under a perfectly still
    // cursor is a different list, so a row you never pointed at arrives under
    // the pointer, reports an enter, and takes the selection you were about to
    // press Return on. The launcher opened whatever the mouse happened to be
    // parked on.
    //
    // So hover is now only a LOOK. Selection moves for the keyboard, for the
    // rail, and for a click, all of which are things you did on purpose.
    property int hovered: -1

    // Being pulled out of the bottom edge by hand, and how far.
    //
    // While this is true the panel's height is the POINTER'S, not the reveal
    // animation's: the top edge has to be where the finger is or the gesture is
    // a switch with a picture of a drag on it. The animation takes over at the
    // moment of release, from wherever the drag left it.
    property bool dragging: false
    property real dragProgress: 0

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        // Hand the animation the position the drag ended at, so it carries on
        // from there instead of snapping back to start the journey again.
        rise.value = root.dragProgress;
        if (open)
            root.show();
        else
            root.hide();
        // Back to nothing, so the NEXT press starts from the bottom. Left at the
        // last drag's depth, a plain click would hand the animation a starting
        // point half way up and the panel would appear already half open.
        root.dragProgress = 0;
    }

    // Held out by the CLI rather than by a cursor.
    //
    // The rail answers to hover, and hover is the one input that cannot be
    // scripted: a warped pointer delivers no motion inside a surface it is
    // already in, so nothing about the bow can be seen from the terminal
    // without this. Same reason `banditshell menu open` exists.
    // A LATCH, because the CLI has no release: a terminal hands over a position
    // and walks away, so something has to decide when the hold is over. A real
    // hand arriving on the rail is that something, and so is the panel closing.
    // Left latched, the bow never falls back to straight after a drag, because
    // the drag was not what was holding it out.
    property bool scrubbing: false

    function scrubTo(fraction: real): void {
        root.scrubbing = fraction >= 0;
        if (!root.scrubbing)
            return;
        root.scrubY = Math.max(0, Math.min(fraction, 1)) * rail.height;
        root.depth = root.bowDepth * 0.55;
        root.scrubAt(root.scrubY);
    }

    // The handle, from a point on the rail. x is measured INWARD from the rail's
    // own centre, so dragging toward the middle of the panel deepens the curve
    // and letting the pointer drift back toward the edge flattens it.
    function grabAt(x: real, y: real): void {
        root.scrubY = Math.max(0, Math.min(y, rail.height));
        root.depth = Math.max(0, Math.min(rail.width / 2 - x, root.bowDepth));
        root.scrubAt(root.scrubY);
    }

    property int selected: 0

    // For `banditshell status`.
    readonly property real drawnHeight: panel.height
    readonly property int resultCount: root.rows.filter(r => !!r.entry).length
    // The VIEW and the TAIL as well as the position, because the whole question
    // about this list is whether a section is in the middle of it, and that
    // cannot be read off a scroll offset alone.
    readonly property string scrollInfo: `${query.text ? "search" : root.marked || "top"}, row ${root.selected} of ${root.rows.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}, view ${Math.round(list.height)}px, tail ${Math.round(root.tail)}px, section at ${Math.round(root.sectionSpan[root.marked]?.y ?? -1)}+${Math.round(root.sectionSpan[root.marked]?.h ?? 0)}`

    // What had the keyboard before this took it; see ListLauncher, same reason.
    property string restoreTo: ""

    function show(): void {
        root.restoreTo = Hypr.focusedAddress;
        root.shown = true;
        query.text = "";
        root.marked = "";
        root.hovered = -1;
        root.scrubbing = false;
        root.grabbing = false;
        root.selected = root.firstApp(0, 1);
        list.reset();
        Qt.callLater(query.forceActiveFocus);
    }

    function hide(): void {
        root.shown = false;
        query.focus = false;
        root.scrubbing = false;
        root.grabbing = false;
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
        const entry = root.rows[root.selected]?.entry;
        if (entry) {
            Apps.launch(entry);
            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    // The next row that is an application, because a section is a label and
    // selecting one would mean pressing Return on a letter.
    function firstApp(from: int, step: int): int {
        const n = root.rows.length;
        for (let i = 0; i < n; i++) {
            const at = ((from + i * step) % n + n) % n;
            if (root.rows[at]?.entry)
                return at;
        }
        return 0;
    }

    function move(delta: int): void {
        if (root.rows.length)
            root.selectRow(root.firstApp(root.selected + delta, delta >= 0 ? 1 : -1));
    }

    // Where a row starts, accumulated. NOT GlideList.reveal, which divides the
    // content height by the count and so assumes every row is the same size:
    // true of a plain list and false the moment sections are in it, where it
    // would put the selection progressively further off the further down you
    // went.
    function rowY(index: int): real {
        let y = 0;
        for (let i = 0; i < index && i < root.rows.length; i++)
            y += root.rows[i].section ? root.sectionPitch : root.rowPitch;
        return y;
    }

    function selectRow(index: int): void {
        root.selected = index;

        const top = root.rowY(index);
        const height = root.rows[index]?.section ? root.sectionPitch : root.rowPitch;
        // A section is worth scrolling to WITH its row, so arrowing into the
        // first application under a letter brings the letter along.
        const lead = index > 0 && root.rows[index - 1]?.section ? root.sectionPitch : 0;

        if (top - lead < list.anchor)
            list.scrollTo(top - lead);
        else if (top + height > list.anchor + list.height)
            list.scrollTo(top + height - list.height);
    }

    // GO TO A SECTION: put its block in the middle of the view, and put the
    // selection on the first thing in it.
    //
    // Centred rather than scrolled-to-top because a heading pinned to the top
    // edge reads as the end of the list above it rather than as the start of the
    // one below, and because the eye is already in the middle of the panel: that
    // is where the rail's own handle is. Short sections then sit where you are
    // looking instead of two hundred pixels above it.
    //
    // The selection follows because the sections are ranked by use now. The
    // first row under a letter is the one you most likely meant, so arriving at
    // the letter and pressing Return should open it without an arrow key in
    // between.
    function markSection(key: string): void {
        root.marked = key;

        const span = root.sectionSpan[key];
        if (!span)
            return;
        list.scrollTo(span.y - Math.max(0, (list.height - span.h) / 2));

        // The row straight after the heading, which is the first application
        // filed under it. No search needed: the flat list puts them adjacent.
        const at = root.rows.findIndex(row => row.section === key);
        if (at >= 0 && root.rows[at + 1]?.entry)
            root.selected = at + 1;
    }

    // Which key a point on the rail is, computed from where it falls rather than
    // from a stack of hit areas: one area, one division, and it stays right
    // whatever the alphabet turns out to contain.
    function scrubAt(y: real): void {
        const n = root.keys.length;
        if (n <= 0 || query.text)
            return;
        const index = Math.max(0, Math.min(Math.floor(y / rail.height * n), n - 1));
        const key = root.keys[index];
        if (key === root.marked)
            return;
        root.markSection(key);
    }

    // A new set of rows is a new selection, but not necessarily a new PLACE: a
    // section still marked is where you are, so hiding something while browsing
    // K leaves you in K rather than throwing you back to the favourites.
    function reselect(): void {
        // The row that WAS under the pointer is a different row now, or gone.
        // Whatever the pointer is over, it will say so on the next enter.
        root.hovered = -1;

        if (root.marked && root.sectionSpan[root.marked])
            root.markSection(root.marked);
        else
            root.selected = root.firstApp(0, 1);
    }

    onRowsChanged: root.reselect()

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // How far out the rail is bowed, 0 to 1. Eased rather than snapped, so
    // arriving on the rail draws the curve out and leaving lets it fall back.
    Follow {
        id: bow

        // Held out while the handle is held, eased back when it is let go. The
        // DEPTH itself is never animated: that is the pointer's own position,
        // and smoothing it would put the handle behind the finger dragging it.
        target: root.grabbing || root.scrubbing ? 1 : 0
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

        // Grows UPWARD out of the bottom band and stays joined to it the whole
        // way: a column rising out of the shell rather than a sheet arriving
        // over it.
        height: fullHeight * (root.dragging ? root.dragProgress : rise.value)
        y: bandY - height

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            // THE RAIL. Down the right edge, full height, the only thing in the
            // panel that is always in the same place.
            MouseArea {
                id: rail

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large
                width: root.railWidth

                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeVerCursor

                // PRESS AND DRAG, not hover. Passing a cursor over the rail is
                // not a request to go anywhere, and treating it as one made the
                // list bolt away from under anyone who crossed the right edge on
                // their way somewhere else. Grabbing it is unambiguous, it is
                // the gesture the phone has, and it is what lets the pull depth
                // mean anything.
                onPressed: mouse => {
                    // The hand takes the rail off the CLI; see root.scrubbing.
                    root.scrubbing = false;
                    root.grabbing = true;
                    root.grabAt(mouse.x, mouse.y);
                }

                onPositionChanged: mouse => {
                    if (root.grabbing)
                        root.grabAt(mouse.x, mouse.y);
                }

                onReleased: root.grabbing = false
                onCanceled: root.grabbing = false

                Repeater {
                    model: root.keys

                    delegate: Item {
                        id: mark

                        required property string modelData
                        required property int index

                        readonly property string glyph: root.keyIcon(modelData)
                        readonly property bool active: modelData === root.marked
                        readonly property color tint: active ? Appearance.colour.accent : rail.containsMouse ? Appearance.colour.textDim : Appearance.colour.textFaint

                        // Evenly divided by count, so the rail fills its height
                        // whether it carries twelve marks or twenty-eight.
                        readonly property real slot: rail.height / root.keys.length

                        // THE BOW. Marks are pulled toward the middle of the
                        // panel, furthest under the cursor and less either side,
                        // so the rail reads as a line being dragged rather than
                        // as a column with one item highlighted. A Gaussian
                        // rather than a linear falloff: the taper has to have no
                        // corner in it, or the curve looks like a tent.
                        readonly property real fromCursor: (index + 0.5) * slot - root.scrubY

                        x: -root.depth * bow.value * Math.exp(-Math.pow(fromCursor / (slot * root.bowSpread), 2))
                        y: index * slot
                        width: rail.width
                        height: slot

                        // Centred on the INK, not on the line box: a rail is a
                        // ruler, and marks that are level with each other by
                        // luck of which letters have descenders is not a ruler.
                        StyledText {
                            id: letter

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: letter.inkOffsetX
                            anchors.verticalCenterOffset: letter.inkOffsetY
                            visible: !mark.glyph
                            text: mark.modelData
                            font.pixelSize: Appearance.font.size.small
                            color: mark.tint
                        }

                        Icon {
                            id: markGlyph

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: markGlyph.inkOffsetX
                            anchors.verticalCenterOffset: markGlyph.inkOffsetY
                            visible: !!mark.glyph
                            size: Appearance.font.size.small
                            name: mark.glyph
                            color: mark.tint
                        }
                    }
                }
            }

            // The mark you are on, on a disc, at the far end of the bow. It is
            // the one thing in this concept drawn in the accent: the rail is a
            // scrubber, and a scrubber needs a handle you can see without
            // looking away from the list it is moving.
            G2Rect {
                id: disc

                // NOT `parent.isStar` down in the children. G2Rect's default
                // property is `content`, so anything declared inside it is a
                // child of an inner item and `parent` is that item, not this
                // one. The lookup silently yielded undefined, and an undefined
                // binding on `visible` leaves the property at its default, which
                // is true: the star was drawn over every letter, always.
                readonly property string glyph: root.keyIcon(root.marked)

                // BEYOND the deepest letter, not on top of it. The disc is the
                // handle and the letters are the line it is pulling, so it has
                // to lead them: parked at the same depth it simply covered the
                // one letter you were reading.
                x: rail.x + rail.width / 2 - (root.depth + width / 2 + Appearance.padding.normal) * bow.value - width / 2
                y: rail.y + root.scrubY - height / 2
                width: root.badgeSize
                height: width
                radius: width / 2

                visible: bow.value > 0.01 && !!root.marked
                opacity: bow.value
                color: Appearance.colour.accent

                // In the middle of the DISC, which means the middle of the
                // letter, not the middle of the box the letter is delivered in.
                // See StyledText.inkOffsetX.
                StyledText {
                    id: discLetter

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discLetter.inkOffsetX
                    anchors.verticalCenterOffset: discLetter.inkOffsetY
                    visible: !disc.glyph
                    text: root.marked
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.accentText
                }

                Icon {
                    id: discGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discGlyph.inkOffsetX
                    anchors.verticalCenterOffset: discGlyph.inkOffsetY
                    visible: !!disc.glyph
                    size: Appearance.font.size.large
                    name: disc.glyph
                    color: Appearance.colour.accentText
                }
            }

            // The search, at the BOTTOM, where a phone puts the thing you reach
            // for. Everything else stacks upward off it.
            Item {
                id: field

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.bottomMargin: Appearance.padding.large
                height: Appearance.font.size.normal + Appearance.padding.normal

                Icon {
                    id: searchGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.gutter
                    size: Appearance.font.size.normal
                    name: "search"
                    color: query.text ? Appearance.colour.accent : Appearance.colour.textGhost
                }

                StyledText {
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !query.text
                    text: "Search, or run the rail"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
                }

                TextInput {
                    id: query

                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: Appearance.font.family
                    // The BODY size. It was set as a headline, which is what a
                    // search field is on a phone where it is the only thing on
                    // the screen. Here it sits under a hundred and forty rows
                    // set smaller than it, and it was shouting over all of them.
                    font.pixelSize: Appearance.font.size.normal
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    clip: true

                    // Typing means you have stopped browsing. The column is a new
                    // column, so it starts at its own top rather than at
                    // whatever offset the last letter left behind.
                    onTextChanged: {
                        if (text)
                            root.marked = "";
                        list.reset();
                    }

                    Keys.onPressed: event => {
                        const page = Math.max(1, Math.floor(list.height / root.rowPitch) - 1);

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
                        case Qt.Key_PageDown:
                            root.move(page);
                            break;
                        case Qt.Key_PageUp:
                            root.move(-page);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }

            // THE ROOM the column has. The list is placed inside it rather than
            // stretched to it; see list.height for why.
            Item {
                id: well

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.top: parent.top
                anchors.bottom: field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                StyledText {
                    anchors.centerIn: parent
                    visible: !root.rows.length
                    text: query.text ? "nothing matches" : "no applications found"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
                }

                // EVERYTHING, in one column. The rail moves this; it never
                // replaces it.
                GlideList {
                    id: list

                    width: well.width
                    anchors.verticalCenter: well.verticalCenter

                    // AS TALL AS IT NEEDS, up to the room available, and CENTRED
                    // in what is left over.
                    //
                    // A search that returns three things used to leave them
                    // pinned to the top of a panel the height of the screen,
                    // with two feet of nothing under them: the results were as
                    // far from the field you typed into as it is possible to put
                    // them, and the panel read as mostly empty rather than as
                    // mostly answer. Sized to the content, the three sit in the
                    // middle of the column, where the eye already is.
                    //
                    // From the row COUNT, never from contentHeight: a ListView's
                    // is an estimate until every delegate has been built, so
                    // binding the height to it is a height that changes as you
                    // scroll.
                    height: Math.min(well.height, root.needed)

                    clip: true
                    model: ScriptModel {
                        values: root.rows
                    }
                    reuseItems: true
                    cacheBuffer: root.rowPitch * 4

                    // The room under the last section, so it can be centred like
                    // every other one. See root.tail.
                    footer: Item {
                        width: list.width
                        height: root.tail
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool isSection: !!modelData.section
                        readonly property var entry: modelData.entry
                        readonly property string glyph: root.keyIcon(modelData.section)

                        // THE THREE STATES, and they are three, not two. Chosen
                        // is what Return opens; under is where the pointer
                        // happens to be; away is filed in the drawer.
                        readonly property bool chosen: index === root.selected
                        readonly property bool under: index === root.hovered
                        readonly property bool away: !!entry && Apps.isHidden(entry)

                        // WHICH END of the row the pointer is on, from the row's
                        // own coordinates rather than from a second MouseArea
                        // over the button.
                        //
                        // A nested hovering MouseArea TAKES the hover off the one
                        // under it, so arriving at the button read as leaving the
                        // row, which un-hovered the row, which took the button
                        // away, which handed the hover back to the row, which
                        // brought the button back. It flashed for as long as you
                        // held still on it. One area cannot fight itself.
                        readonly property bool atStow: pointer.containsMouse && pointer.mouseX >= stow.x

                        width: list.width
                        height: isSection ? root.sectionPitch : root.rowPitch

                        // DECLARED FIRST, deliberately: declaration order is
                        // input order in QML, so a row-wide target that comes
                        // last sits on top of the control inside it and eats its
                        // clicks.
                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            enabled: !row.isSection
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            // A LOOK, and only a look. See root.hovered.
                            onEntered: root.hovered = row.index
                            onExited: if (root.hovered === row.index)
                                root.hovered = -1

                            onClicked: mouse => {
                                // Right anywhere on the row does what the button
                                // does, without having to aim at it.
                                if (mouse.button === Qt.RightButton || row.atStow) {
                                    Apps.setHidden(row.entry, !row.away);
                                    return;
                                }
                                root.selected = row.index;
                                root.accept();
                            }
                        }

                        // The letter, in the MARGIN. Outside the icons rather than
                        // above them, so every name in the list starts at one x and
                        // the sections annotate a continuous column instead of
                        // chopping it into blocks.
                        StyledText {
                            id: heading

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: heading.inkOffsetY
                            width: root.gutter

                            visible: row.isSection && !row.glyph
                            text: row.modelData.section
                            font.pixelSize: Appearance.font.size.large
                            color: row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim
                        }

                        Icon {
                            id: headingGlyph

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: headingGlyph.inkOffsetY
                            width: root.gutter

                            visible: row.isSection && !!row.glyph
                            size: Appearance.font.size.large
                            name: row.glyph
                            color: row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim
                        }

                        G2Rect {
                            id: badge

                            anchors.left: parent.left
                            anchors.leftMargin: root.gutter
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.iconSize
                            height: width
                            // Half the width: the squircle at its roundest, which is
                            // a circle that was never cut from one.
                            radius: width / 2

                            visible: !row.isSection
                            // The fill ladder is HOVER, and the ring is
                            // SELECTION. They have to be told apart at a glance
                            // now that they are no longer the same thing: one
                            // step along a fill ladder is not a difference you
                            // can see, and a boundary is the one way to mark a
                            // control without painting a disc that shouts.
                            color: row.under ? Appearance.colour.fillStrong : Appearance.colour.fill
                            stroke: row.chosen ? Appearance.colour.accent : "transparent"
                            strokeWidth: row.chosen ? 2 : 0

                            Image {
                                id: art

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                source: row.entry?.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                                sourceSize.width: width * Screen.devicePixelRatio
                                sourceSize.height: height * Screen.devicePixelRatio
                            }

                            Icon {
                                id: fallbackGlyph

                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: fallbackGlyph.inkOffsetX
                                anchors.verticalCenterOffset: fallbackGlyph.inkOffsetY
                                visible: !art.visible
                                size: root.iconSize / 2
                                name: "apps"
                                color: Appearance.colour.textDim
                            }
                        }

                        StyledText {
                            anchors.left: badge.right
                            anchors.leftMargin: Appearance.padding.large
                            // Stops at the button, whether or not the button is
                            // showing: a name that reflows the moment a cursor
                            // crosses it is worse than one that is short.
                            anchors.right: stow.left
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter

                            visible: !row.isSection
                            text: row.entry?.name ?? ""
                            font.pixelSize: Appearance.font.size.normal
                            color: row.chosen || row.under ? Appearance.colour.text : Appearance.colour.textDim
                            elide: Text.ElideRight
                        }

                        // PUT AWAY, or put back.
                        //
                        // Under the pointer only. A launcher is a list you scan,
                        // and a column of identical buttons down the right edge
                        // is a column you have to read past every time; one that
                        // is only ever on the row you are already looking at
                        // costs nothing to have. Right-clicking the row is the
                        // same action for anyone who has found it.
                        G2Rect {
                            id: stow

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.iconSize * 0.72
                            height: width
                            radius: width / 2

                            visible: !row.isSection
                            opacity: row.under ? 1 : 0
                            color: row.atStow ? Appearance.colour.fillStronger : Appearance.colour.fillStrong

                            // BOTH EASED. A control that arrives faded in and
                            // then snaps its contents to a new colour reads as
                            // two events, and the second one is a flash. It is
                            // one thing lighting up, so it lights up at one
                            // speed.
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            Icon {
                                id: stowGlyph

                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: stowGlyph.inkOffsetX
                                anchors.verticalCenterOffset: stowGlyph.inkOffsetY
                                size: Appearance.font.size.small
                                name: row.away ? "visibility" : root.vaultIcon
                                // One step, not a jump to full strength: the
                                // disc under it is already saying the pointer is
                                // here, and both of them shouting is the flash.
                                color: row.atStow ? Appearance.colour.text : Appearance.colour.textFaint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }
                        }

                        // Said once the pointer has clearly settled on the
                        // button, which is what Tooltips is for; asking on the
                        // way past would put a label on every row you cross.
                        onAtStowChanged: {
                            if (row.atStow)
                                Tooltips.request(row, row.away ? "put back in the list" : "hide from the list");
                            else
                                Tooltips.release(row);
                        }

                        Component.onDestruction: Tooltips.release(row)
                    }
                }
            }
        }
    }
}
