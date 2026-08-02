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
    readonly property var favourites: Apps.search("").slice(0, root.favouriteCount)

    // What the rail offers: the star, then whatever letters exist.
    readonly property var keys: [root.star, ...root.letters]

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
        return out;
    }

    // Where each section starts, in the list's own coordinates. Accumulated once
    // per change rather than measured off the delegates, which only exist for
    // the part of the list currently on screen.
    readonly property var sectionY: {
        const out = {};
        let y = 0;
        for (const row of root.rows) {
            if (row.section) {
                out[row.section] = y;
                y += root.sectionPitch;
            } else {
                y += root.rowPitch;
            }
        }
        return out;
    }

    // Which section the rail is pointing at.
    property string marked: ""

    property int selected: 0

    // For `banditshell status`.
    readonly property real drawnHeight: panel.height
    readonly property int resultCount: root.rows.filter(r => !!r.entry).length
    readonly property string scrollInfo: `${query.text ? "search" : root.marked || "top"}, row ${root.selected} of ${root.rows.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}`

    // What had the keyboard before this took it; see ListLauncher, same reason.
    property string restoreTo: ""

    function show(): void {
        root.restoreTo = Hypr.focusedAddress;
        root.shown = true;
        query.text = "";
        root.marked = "";
        root.selected = root.firstApp(0, 1);
        list.reset();
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
        root.marked = key;
        list.scrollTo(root.sectionY[key] ?? 0);
    }

    onRowsChanged: root.selected = root.firstApp(0, 1)

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

        // Grows UPWARD out of the bottom band and stays joined to it the whole
        // way: a column rising out of the shell rather than a sheet arriving
        // over it.
        height: fullHeight * rise.value
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
                // MOTION only, not entry. The panel rises when it opens, so the
                // rail arrives under whatever the cursor happened to be sitting
                // on, and an entry-triggered scrub means the launcher opens on a
                // letter nobody chose. Reaching the rail requires moving to it,
                // and moving to it is a position event.
                onPositionChanged: mouse => root.scrubAt(mouse.y)

                Repeater {
                    model: root.keys

                    delegate: Item {
                        id: mark

                        required property string modelData
                        required property int index

                        readonly property bool isStar: modelData === root.star
                        readonly property bool active: modelData === root.marked
                        readonly property color tint: active ? Appearance.colour.accent : Appearance.colour.textFaint

                        // Evenly divided by count, so the rail fills its height
                        // whether it carries twelve marks or twenty-eight.
                        readonly property real slot: rail.height / root.keys.length

                        y: index * slot
                        width: rail.width
                        height: slot

                        StyledText {
                            anchors.centerIn: parent
                            visible: !mark.isStar
                            text: mark.modelData
                            font.pixelSize: Appearance.font.size.small
                            color: mark.tint
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: mark.isStar
                            size: Appearance.font.size.small
                            name: root.starIcon
                            color: mark.tint
                        }
                    }
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
                height: Appearance.font.size.large + Appearance.padding.normal

                Icon {
                    id: searchGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.gutter
                    size: Appearance.font.size.large
                    name: "search"
                    color: query.text ? Appearance.colour.accent : Appearance.colour.textGhost
                }

                StyledText {
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !query.text
                    text: "Search, or run the rail"
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.textGhost
                }

                TextInput {
                    id: query

                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.large
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    clip: true

                    // Typing means you have stopped browsing.
                    onTextChanged: if (text)
                        root.marked = ""

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

            // EVERYTHING, in one column. The rail moves this; it never replaces
            // it.
            GlideList {
                id: list

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.top: parent.top
                anchors.bottom: field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                clip: true
                model: ScriptModel {
                    values: root.rows
                }
                reuseItems: true
                cacheBuffer: root.rowPitch * 4

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool isSection: !!modelData.section
                    readonly property var entry: modelData.entry

                    width: list.width
                    height: isSection ? root.sectionPitch : root.rowPitch

                    // The letter, in the MARGIN. Outside the icons rather than
                    // above them, so every name in the list starts at one x and
                    // the sections annotate a continuous column instead of
                    // chopping it into blocks.
                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.gutter

                        visible: row.isSection && row.modelData.section !== root.star
                        text: row.modelData.section
                        font.pixelSize: Appearance.font.size.large
                        color: row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim
                    }

                    Icon {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.gutter

                        visible: row.isSection && row.modelData.section === root.star
                        size: Appearance.font.size.large
                        name: root.starIcon
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
                        color: row.index === root.selected ? Appearance.colour.fillStrong : Appearance.colour.fill

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
                            anchors.centerIn: parent
                            visible: !art.visible
                            size: root.iconSize / 2
                            name: "apps"
                            color: Appearance.colour.textDim
                        }
                    }

                    StyledText {
                        anchors.left: badge.right
                        anchors.leftMargin: Appearance.padding.large
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        visible: !row.isSection
                        text: row.entry?.name ?? ""
                        font.pixelSize: Appearance.font.size.normal
                        color: row.index === root.selected ? Appearance.colour.text : Appearance.colour.textDim
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.isSection
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: {
                            root.selected = row.index;
                            root.accept();
                        }
                    }
                }
            }
        }
    }
}
