pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The settings page itself: everything you can see of it, and nothing about
// where it is being drawn.
//
// A PLAIN Item, the way LockFace is, and for the same reason. The page is drawn
// twice in this shell - once by the shell's own surface and once by a real
// window - and the only way two surfaces can be trusted to be showing the same
// thing is for it to literally be the same component. Anything that leaked into
// here about which surface it was on would be the first thing to drift.
//
// It also means the page can be dropped into an ordinary window and
// screenshotted, which is how anything in here gets checked
// (settingspreview.qml).
//
// SHAPED LIKE A PHONE'S SETTINGS APP, because that is the one settings surface
// everybody already knows how to use and it is also the one that already had
// to solve this page's problem: the same app is a single column on a phone,
// two columns on the same phone unfolded, and a window on a desktop. The
// answer there is a LIST OF SECTIONS and ONE SECTION, and how many of the two
// are on screen at once is decided by the width and nothing else.
//
//   narrow   the list. Tap a section and it slides in over the list from the
//            right; drag it back to the right, tap the arrow, or press Escape,
//            and the list is underneath where it was.
//   wide     the list stands on the left as a pane and the section beside it,
//            the way the unfolded phone or an iPad lays it out. Nothing slides.
//
// The threshold is two of the narrowest pane the config allows (settings.pane),
// which is what an unfolded phone offers each half; a 560px desktop card is
// just wide enough to split, a portrait phone is not, and a window dragged
// narrower by hand becomes a phone.
//
// WHICH page is showing lives on the Settings singleton, not here, because the
// face is drawn twice and the two copies must agree. Whether the list is
// beside it or under it does not: that is a fact about this copy's width.
Item {
    id: root

    // WHICH SIDE OF THE HANDOVER THIS COPY IS ON. What the handover row offers
    // differs, and so does the boundary of the page, and only the boundary: a
    // card on the shell's blurred band owns its own edge, a window does not
    // (the compositor draws a border, a corner and a shadow around it), so in
    // a window the page fills its frame, opaque and square.
    property bool windowed: false

    signal handover

    // THE GRIP, HANDED OUT AS A RECTANGLE. The tap that closes the page lives
    // on SettingsPanel's Pull, not here (see the grip below for why the grip
    // cannot own a press), so the panel needs to know where the grip IS.
    readonly property Item gripItem: grip

    // Lit while the panel's Pull is holding a press that began on the grip;
    // written by the panel, because the face cannot see that press.
    property bool gripHeld: false

    readonly property real pad: Appearance.padding.large

    // THE ONE DECISION, from the width alone.
    readonly property bool split: root.width >= Appearance.sizes.settingsPane * 2

    // The list's share of a split face: the smaller golden section, clamped
    // so that neither pane is ever narrower than a pane may be. At 560 that
    // is two equal halves; on a wide window the list settles to about a third
    // and the section takes the rest.
    readonly property real listWidth: root.split ? Math.max(Appearance.sizes.settingsPane, Math.min(root.width * (1 - 1 / 1.618), root.width - Appearance.sizes.settingsPane)) : root.width

    // What the section pane is showing: the chosen page, or on a split face
    // with nothing chosen, the first one, because an empty pane is not a
    // state worth drawing.
    readonly property string current: Settings.page || (root.split ? Settings.pages[0].key : "")
    readonly property var entry: Settings.entry(root.current)

    // Whether the face is showing a section OVER the list, which is the one
    // case where "back" is a thing this face can do. The panel asks this to
    // decide what Escape means.
    readonly property bool deep: !root.split && Settings.page !== ""

    // HOW FAR THE SECTION HAS SLID IN over the list, 0 to 1. The smoother's
    // number, except while a hand is dragging the section away, when it is the
    // hand's: a pane that lagged the finger by an easing's worth would be a
    // switch wearing a picture of a drag. Pinned at 0 on a split face, where
    // the section does not slide at all.
    readonly property real shown: root.split ? 0 : section.backing ? 1 - section.backFraction : depth.value

    Follow {
        id: depth

        target: root.deep ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // Placed, never travelled to: the first layout has no "from", and a face
    // created while Settings.page rests on a section would otherwise open
    // mid-glide toward it. A change of shape is the same case: a window
    // dragged across the threshold reflows, it does not animate.
    Component.onCompleted: depth.snap()
    onSplitChanged: depth.snap()

    G2Rect {
        anchors.fill: parent

        radius: root.windowed ? 0 : Appearance.rounding.large
        color: root.windowed ? Appearance.colour.surfaceSolid : Appearance.colour.surface

        // THE LIST OF SECTIONS. On a narrow face it is the whole page until a
        // section is opened, and then it is what the section slides over,
        // creeping a little to the left and dimming as the section covers it,
        // which is the phone's way of saying the list is still there
        // underneath rather than gone.
        SettingsPane {
            id: index

            x: -root.shown * root.width * 0.3
            width: root.listWidth
            height: parent.height
            // Gone by the time the section has arrived, not merely dimmed:
            // the card's material is translucent, so a list left under an
            // opaque-looking section would ghost through it.
            opacity: 1 - root.shown
            visible: root.split || root.shown < 0.999
            inset: root.windowed || root.split ? root.pad : grip.span + root.pad

            Column {
                x: root.pad
                y: root.pad
                width: index.width - root.pad * 2
                spacing: Appearance.padding.normal

                // The title sits in the pane's own top-left rather than being
                // centred, because a page is read from its corner and a
                // dialog is read from its middle, and this is a page.
                StyledText {
                    text: "Settings"
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.text
                }

                StyledText {
                    text: root.windowed ? "a window, for now" : "drawn by the shell"
                    color: Appearance.colour.textFaint
                    bottomPadding: Appearance.padding.small
                }

                // ONE CARD PER GROUP, the grouped-list idiom every phone's
                // settings app uses, and the groups come from the pages
                // themselves (Settings.groups) rather than from a list kept
                // here. Sub-pages name no group and are not in the list.
                Repeater {
                    model: Settings.groups

                    delegate: SettingsCard {
                        id: card

                        required property string modelData

                        title: card.modelData

                        Repeater {
                            model: Settings.pages.filter(p => p.group === card.modelData)

                            delegate: SettingsRow {
                                id: stop

                                required property var modelData

                                icon: stop.modelData.icon
                                label: stop.modelData.title
                                detail: stop.modelData.blurb
                                chevron: true
                                // On a split face the section beside the
                                // list is marked in it (a sub-page marks its
                                // parent); on a narrow one nothing is,
                                // because the list is only ever seen with no
                                // section open.
                                selected: root.split && Settings.sectionOf(root.current) === stop.modelData.key
                                onActivated: Settings.setPage(stop.modelData.key)
                            }
                        }
                    }
                }

                // THE HANDOVER, as a row of the list rather than a button
                // beside the title. What it does is change what kind of thing
                // the page is, which is a decision about the page, so it sits
                // at the end of it where the decisions go, in a card of its own
                // because it is not a section.
                SettingsCard {
                    SettingsRow {
                        // Out of the shell and into the desktop, or back in
                        // again. Two directions of one gesture, so two arrows
                        // of one drawing.
                        icon: root.windowed ? "close_fullscreen" : "open_in_new"
                        label: root.windowed ? "Put it back" : "Pull it out"
                        detail: root.windowed ? "onto the shell, where a keybind can summon it" : "into a window you can tile, move and leave open"
                        onActivated: root.handover()
                    }
                }
            }
        }

        // The rule between the two panes of a split face, one device pixel of
        // the separator colour, the whole height.
        Rectangle {
            visible: root.split
            x: root.listWidth
            width: Appearance.font.stem
            height: parent.height
            color: Appearance.colour.separator
        }

        // THE SECTION. Beside the list on a split face; over it, slid in from
        // the right by `shown`, on a narrow one.
        SettingsPane {
            id: section

            x: root.split ? root.listWidth + Appearance.font.stem : root.width * (1 - root.shown)
            width: root.split ? root.width - root.listWidth - Appearance.font.stem : root.width
            height: parent.height
            visible: root.split || root.shown > 0.001
            backable: !root.split
            inset: root.windowed ? root.pad : grip.span + root.pad

            // The hand let go: give the smoother the depth the drag ended at
            // so the pane carries on from there, and if it was far or fast
            // enough, the list is where it lands.
            onBacked: committed => {
                depth.value = 1 - section.backFraction;
                if (committed)
                    Settings.back();
            }

            // A section's scroll starts at the top when a new one comes in:
            // the previous section's depth means nothing here.
            onPageChanged: section.drag(0)

            readonly property string page: root.current

            // ITS OWN SURFACE while it slides over the list, in the card's
            // own material so that once it has arrived it is
            // indistinguishable from the card. On a split face there is
            // nothing under it and the rule beside it is the only edge.
            G2Rect {
                anchors.fill: parent
                visible: !root.split
                radius: root.windowed ? 0 : Appearance.rounding.large
                color: root.windowed ? Appearance.colour.surfaceSolid : Appearance.colour.surface
            }

            Column {
                x: root.pad
                y: root.pad
                width: section.width - root.pad * 2
                spacing: Appearance.padding.normal

                // THE HEADER: the way back, and the section's name at the
                // title's size. The arrow exists where there is somewhere to
                // go back to that is not already in view: the list, on a
                // narrow face, or a sub-page's parent on any face.
                Item {
                    readonly property bool arrow: !root.split || !!root.entry?.parent

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
                            opacity: tap.containsMouse ? 1 : 0

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
                            color: tap.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        MouseArea {
                            id: tap

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
                        // Wrapped, never cut: a title that ends in "..." on
                        // the one screen narrow enough to need it is the page
                        // failing at its own name.
                        wrapMode: Text.Wrap
                    }
                }

                Loader {
                    id: content

                    width: parent.width

                    // THE DISPATCH TABLE IS A SPELLING RULE, not a switch: key
                    // "general" loads pages/GeneralPage.qml, and every page
                    // named in Settings.pages resolves the same way, so adding
                    // one never adds a case here.
                    source: root.current ? `pages/${root.current.charAt(0).toUpperCase() + root.current.slice(1)}Page.qml` : ""

                    // A new section fades up rather than cutting in, on the
                    // split face where nothing slides to mark the change.
                    onLoaded: arrive.restart()

                    NumberAnimation {
                        id: arrive

                        target: content
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.anim.fast
                    }
                }
            }
        }

        // WHICH CORNER THE PAGE GOES BACK INTO, said as a mark rather than as a
        // control. The page is closed by pushing it down and right into the
        // corner it grew out of (SettingsPanel's Pull), and a gesture nobody
        // can discover is no better than the keyboard shortcut nobody can
        // press. A CORNER GRIP is the one mark that says a diagonal. Only
        // while the shell draws it: in a window the page cannot be pushed
        // anywhere.
        //
        // IT TAKES NO PRESSES OF ITS OWN, AND YET IT IS THE PAGE'S ONE TAP
        // TARGET: a press here is ambiguous until it moves (the tap that
        // closes, or the first inch of the shove that closes by dragging), and
        // only the Pull behind the card can tell those apart. So the press
        // falls through to SettingsPanel's Pull, and the panel answers the
        // Pull's `tapped` gated to this rectangle.
        Item {
            id: grip

            // SIZED FROM THE RIBS, never the ribs from the size, floored at the
            // minimum target so the whole thing is never smaller than
            // something you could aim at.
            readonly property int ribs: 3
            readonly property real pitch: Appearance.padding.small
            readonly property real span: Math.max(Appearance.sizes.minTarget, grip.pitch * Math.SQRT2 * (grip.ribs + 1))

            x: parent.width - grip.span - root.pad
            y: parent.height - grip.span - root.pad
            width: grip.span
            height: grip.span

            visible: !root.windowed

            // Qt.NoButton is the entire trick: the press is never taken and
            // falls through to the Pull, while hover and the cursor shape
            // still work. This area is a sign, not a control.
            MouseArea {
                id: feel

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            Repeater {
                model: grip.ribs

                G2Rect {
                    id: rib

                    required property int index

                    // How far this rib is from the corner along the push's own
                    // diagonal; everything else follows from that one number.
                    // A chord across a square corner at perpendicular distance
                    // d is exactly 2d long, so the ribs widen as the corner
                    // opens out.
                    readonly property real reach: (rib.index + 1) / (grip.ribs + 1) * grip.span / Math.SQRT2

                    width: rib.reach * 2
                    height: Appearance.font.stem
                    radius: rib.height / 2

                    x: grip.span - rib.reach / Math.SQRT2 - rib.width / 2
                    y: grip.span - rib.reach / Math.SQRT2 - rib.height / 2
                    rotation: -45

                    color: root.gripHeld ? Appearance.colour.text : feel.containsMouse ? Appearance.colour.textDim : Appearance.colour.textFaint

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }
            }
        }
    }
}
