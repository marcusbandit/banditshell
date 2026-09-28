pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The settings page itself: everything you can see of it, and nothing about
// where it is being drawn.
//
// A PLAIN Item, the way LockFace is. The page lives in a real window
// (SettingsFloat) and in the preview harness (settingspreview.qml), and the
// face is what both of them fill: nothing here may know which of them it is
// on.
//
// THE DESKTOP SHAPE, and the phone's is gone. The old face was a phone's
// settings app: a list that stacked over its sections on a narrow card and
// sat beside them on a wide one. That answered a question a desktop never
// asks -- "which of the two fits?" -- at the price of a page that was two
// different objects depending on its width. This face has ONE shape: a rail
// of sections down the left, always; the page's content beside it, always;
// a search over every section above the rail. Nothing slides, nothing
// stacks, and a window dragged narrower is a window dragged narrower, not a
// phone.
//
// WHICH page is showing lives on the Settings singleton, not here, so that
// the CLI, a keybind and the face all answer the same question.
Item {
    id: root

    // ESCAPE ESCAPES, from wherever the focus happens to be. The window's item
    // holds the keyboard (SettingsFloat asks for it on every open), and a key
    // event walks up the PARENT chain from the focused item: focus in the
    // search field -- the one place in here that takes it -- would walk up
    // through the rail and out of reach of anything that did not sit above
    // it. So the face answers, as the ancestor every focused descendant walks
    // up to.
    //
    // "BACK" BEFORE "CLOSE": a sub-page is one level in and the key that
    // leaves a level leaves that one first; from a section the first press
    // closes.
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape)
            return;
        if (root.deep)
            Settings.back();
        else
            Settings.hide();
        event.accepted = true;
    }

    // THE PAGE'S OWN TOKENS, snapped: the gutter is config's (32, a half-step
    // past `large` that belongs to this page alone), the rail keeps the large
    // tier as its horizontal inset, and every height is the row height
    // itself -- the search field and the rows share one grid line so the rail
    // reads as columns of one lattice, not neighbouring sizes.
    readonly property real gutter: Appearance.sizes.settingsGutter
    readonly property real pad: Appearance.padding.large
    readonly property real railWidth: Appearance.sizes.settingsRail
    // The rail's own pitch: nav rows, a small tier under the content's.
    readonly property real railRow: Appearance.sizes.settingsRailRow

    // THE RAIL'S FOOT: one pad of air below the scrolling band, so the last
    // section never sits on the window's own edge.
    readonly property real railFoot: Appearance.padding.large

    // What the content pane is showing, and whether Escape means "back a
    // level" (a sub-page is open) or "close". The Escape handler above asks.
    readonly property string current: Settings.page || Settings.pages[0].key
    readonly property var entry: Settings.entry(root.current)
    readonly property bool deep: !!root.entry?.parent

    // THE SEARCH, over every section the shell has: title, blurb, group, and
    // any keywords a page declares. While it holds text the rail shows only
    // the matches, and the first match is one Enter away.
    property string query: ""

    // THE SLIDING MARK's target: the current row's own y, in the rail's
    // frame, published by the row that is current. One bar for the whole
    // rail, chasing its section -- which is why it is a PERSISTENT element
    // and not each row's ornament: changing pages moves one thing.
    property real currentRowY: 0
    property bool currentRowSeen: false
    readonly property real markHeight: root.railRow * 0.6

    onQueryChanged: railSlide.snap() // a reflowed rail: place, do not travel

    // THE RAIL REVEALS ITS ROW. A rail that scrolls must answer for the row
    // it is pointing at: if the current row's band is not inside the pane's
    // view, the pane scrolls just far enough to bring the whole row in - and
    // otherwise holds still, so a page change among visible rows never
    // jiggles the rail. Called wherever the row's position is (re)published.
    function revealRow(y: real): void {
        if (y < railBody.position)
            railBody.scrollTo(y - Appearance.padding.small);
        else if (y + root.railRow > railBody.position + railBody.height)
            railBody.scrollTo(y + root.railRow - railBody.height + Appearance.padding.small);
    }

    function matches(p: var): bool {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return true;
        return p.title.toLowerCase().includes(q)
            || p.blurb.toLowerCase().includes(q)
            || (p.group ?? "").toLowerCase().includes(q)
            || (p.keywords ?? []).some(k => k.toLowerCase().includes(q));
    }

    // The groups that still have something to show, query applied.
    readonly property var shownGroups: Settings.groups.filter(g => Settings.pages.some(p => p.group === g && root.matches(p)))

    G2Rect {
        anchors.fill: parent

        // SQUARE and opaque: the face fills a real window's frame, and the
        // compositor draws the border, the corner and the shadow around it.
        // Rounding here would be a card's edge drawn inside the window's own.
        radius: 0
        color: Appearance.colour.surfaceSolid

        // ------------------------------------------------------------ rail

        Item {
            id: rail

            x: 0
            y: 0
            width: root.railWidth
            height: parent.height

            // THE RAIL'S HEAD, pinned: the page's name, the close affordance,
            // and the search. These never scroll; the sections under them do.
            //
            // The head wears the page's own gutter above it, so this title and
            // the content pane's stand on one line across the separator --
            // anything less and the card reads as if its top were cut off.
            Column {
            id: railHead

            width: parent.width
            topPadding: root.gutter
            spacing: 0

            // The header: the page's name, and nothing else. Escape closes,
            // the corner opens; a dismiss button beside the title was a
            // second answer to a question the shell already asks.
            StyledText {
                id: titleText

                x: root.pad
                text: "Settings"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.text
            }

            // AIR between the header band and the search field.
            Item {
                width: parent.width
                height: Appearance.padding.small
            }

            // THE SEARCH FIELD: a place to type, PathField's shape in
            // miniature. Live: the rail filters as the letters land. One row
            // tall, the rail rows' own height, and inset by the rail's own
            // pad, so its box lines up with the names under it instead of
            // running into the rail's edges.
            Item {
                x: root.pad
                width: parent.width - root.pad * 2
                height: root.railRow

                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Appearance.colour.fillStrong
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText

                    onTextChanged: root.query = text

                    Keys.onEscapePressed: {
                        if (text !== "") {
                            text = "";
                            root.query = "";
                        } else
                            Settings.hide();
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !searchInput.text
                        text: "search settings"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }

            Item {
                width: parent.width
                height: Appearance.padding.small
            }
            }

            // THE SECTIONS' BAND: the part of the rail that scrolls. A
            // SettingsPane because that is what one is -- a column that
            // scrolls -- and the rail has no back gesture to add. Pinned
            // between the head above and the rail's foot of air below, so a
            // fourteenth section turns into scroll rather than off the edge.
            SettingsPane {
                id: railBody

                x: 0
                y: railHead.height
                width: rail.width
                height: rail.height - railHead.height - root.railFoot

                // THE FOLD, said honestly: when the sections outrun the band,
                // the last row fades into the surface instead of stopping
                // mid-glyph against the window's edge. A fade is the universal
                // "there is more below" - a plain clip reads as a rendering
                // bug, a scrollbar as clutter. It holds no event handlers, so
                // it never eats a row's press or hover.
                Rectangle {
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Appearance.padding.huge
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: Appearance.colour.surface
                        }
                    }
                }

                Column {
                id: sections

                width: railBody.width
                spacing: 0

                // THE SECTIONS, grouped, the groups from the pages themselves.
                // Filtered live by the search; a group with nothing left to show
                // is not drawn.
                Repeater {
                    model: root.shownGroups

                    delegate: Column {
                        id: groupCol

                        required property string modelData

                        width: rail.width
                        spacing: 0

                        StyledText {
                            x: root.pad
                            width: rail.width - root.pad * 2
                            // The rail's group names wear the same
                            // tracked-caps overline the pages' cards do: the
                            // idiom is shell-wide, and so is the asymmetry -
                            // one large tier of air above the label, one small
                            // tier holding it to its rows.
                            text: groupCol.modelData.toUpperCase()
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                            font.letterSpacing: Appearance.font.stem
                            topPadding: Appearance.padding.large
                            bottomPadding: Appearance.padding.small
                        }

                        Repeater {
                            model: Settings.pages.filter(p => p.group === groupCol.modelData && root.matches(p))

                            delegate: RailRow {}
                        }
                    }
                }

                // NOTHING FOUND, said quietly rather than by an empty rail.
                StyledText {
                    visible: root.query !== "" && root.shownGroups.length === 0
                    x: root.pad
                    width: parent.width - root.pad * 2
                    text: `nothing matches "${root.query}"`
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                    topPadding: Appearance.padding.normal
                }
                }

                // THE MARK: the accent, as the rail's own persistent "you are
                // here". It chases the current row with the house smoother
                // (Follow, never a Behaviour on a position), snaps when the
                // panel is revealed or the rail reflows, and hides while the
                // row it belongs to is filtered out. It lives IN the scrolled
                // content -- beside its row, riding the same pan -- so scrolling
                // moves row and mark together and the chase is never spent on
                // distance the scroller itself covered.
                G2Rect {
                    id: slideMark

                    x: 0
                    y: railSlide.value + (root.railRow - root.markHeight) / 2
                    width: Appearance.font.stem * 2
                    height: root.markHeight
                    radius: Appearance.font.stem
                    color: Appearance.colour.accent
                    opacity: root.currentRowSeen ? 1 : 0
                }


                Follow {
                    id: railSlide

                    target: root.currentRowY
                    // railSpeed, not revealSpeed: measured at 18 this crossed a
                    // 290px rail inside two frames and read as a teleport. The
                    // slide IS the feature; it gets its own clock.
                    speed: Appearance.anim.railSpeed
                    epsilon: 0.5
                }

                Connections {
                    target: Settings

                    // Revealed, not travelled to: a page changed while the panel
                    // was away is a PLACEMENT (Follow's own first-layout rule),
                    // and only a change on a live rail is a journey.
                    function onOpenChanged(): void {
                        railSlide.snap();
                        root.revealRow(root.currentRowY);
                    }
                }
            }
        }

        // The rule between rail and content, one device pixel, whole height.
        Rectangle {
            x: root.railWidth
            width: Appearance.font.stem
            height: parent.height
            color: Appearance.colour.separator
        }

        // -------------------------------------------------------- content

        SettingsPane {
            id: content

            x: root.railWidth + Appearance.font.stem
            width: parent.width - root.railWidth - Appearance.font.stem
            height: parent.height
            inset: root.gutter

            Column {
                x: root.gutter
                y: root.gutter
                width: content.width - root.gutter * 2
                spacing: Appearance.padding.normal

                // THE HEADER: the way back, for a sub-page, and the section's
                // name at the title's size.
                Item {
                    readonly property bool arrow: !!root.entry?.parent

                    width: parent.width
                    height: name.implicitHeight

                    Item {
                        id: back

                        readonly property real slot: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.arrow ? back.slot + Appearance.padding.small : 0
                        height: back.slot
                        visible: parent.arrow

                        G2Rect {
                            width: back.slot
                            height: back.slot
                            radius: Appearance.rounding.normal
                            color: Appearance.colour.fill
                            opacity: backTap.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Icon {
                            x: (back.slot - width) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: "arrow_back"
                            color: backTap.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        MouseArea {
                            id: backTap

                            width: back.slot
                            height: back.slot
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.back()
                        }
                    }

                    StyledText {
                        id: name

                        anchors.left: back.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.entry?.title ?? ""
                        font.pixelSize: Appearance.font.size.large
                        color: Appearance.colour.text
                        wrapMode: Text.Wrap
                    }
                }

                Loader {
                    id: pageLoader

                    width: parent.width

                    // THE DISPATCH TABLE IS A SPELLING RULE, not a switch: key
                    // "general" loads pages/GeneralPage.qml, and every page
                    // named in Settings.pages resolves the same way, so adding
                    // one never adds a case here.
                    source: root.current ? `pages/${root.current.charAt(0).toUpperCase() + root.current.slice(1)}Page.qml` : ""

                    // A new section fades up rather than cutting in.
                    onLoaded: arrive.restart()

                    NumberAnimation {
                        id: arrive

                        target: pageLoader
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.anim.fast
                    }
                }
            }

            // A page change starts its scroll at the top: the previous
            // page's depth means nothing here.
            onPageChanged: content.drag(0)
            readonly property string page: root.current
        }
    }

    // One row of the rail: mark, name, and the highlight that says "here".
    component RailRow: Item {
        id: railRow

        // Supplied by the sections' Repeater as the page entry.
        required property var modelData

        signal activated

        readonly property bool isCurrent: Settings.sectionOf(root.current) === modelData.key

        width: rail.width
        height: root.railRow

        // THE MARK'S TARGET, published up while this row is current: its own
        // y in the rail's frame, through the group Columns between. The
        // Deferred is Config.qml's FileView lesson generalised: a Column's
        // children are placed during polish, so the position is read on the
        // NEXT pass, not inside the one that moved it.
        onIsCurrentChanged: publish()
        onYChanged: publish()
        // A panel that was opened with its page already chosen never flipped
        // isCurrent while visible: the publish that ran did so against an
        // unrealized, hidden layout, and the mark inherited a position from
        // geometry that was never on the screen. Becoming visible is itself
        // news about position, so publish again -- and through the same
        // double hop the map uses, since a single callLater can still land
        // inside the polish it is waiting on.
        onVisibleChanged: if (isCurrent)
            Qt.callLater(publish)

        Component.onCompleted: publish()

        function publish(): void {
            if (!isCurrent)
                return;
            root.currentRowSeen = visible;
            Qt.callLater(() => {
                root.currentRowY = railRow.mapToItem(sections, 0, 0).y;
                root.revealRow(root.currentRowY);
            });
        }

        G2Rect {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            radius: Appearance.rounding.small
            color: Appearance.colour.fill
            opacity: railRow.isCurrent || rowTap.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // (The per-row accent is GONE, deliberately: the rail's one sliding
        // mark below owns "you are here" now. Two bars -- one teleporting
        // per row, one sliding for the rail -- were exactly the bug this
        // edit removed; the row keeps only the plate and the highlight.)

        Icon {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            name: railRow.modelData.icon
            color: railRow.isCurrent ? Appearance.colour.text : Appearance.colour.textDim
        }

        StyledText {
            x: root.pad + Appearance.font.iconSize + root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - root.pad
            text: railRow.modelData.title
            color: railRow.isCurrent ? Appearance.colour.text : Appearance.colour.textDim
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.query = "";
                searchInput.text = "";
                Settings.setPage(railRow.modelData.key);
                railRow.activated();
            }
        }
    }
}
