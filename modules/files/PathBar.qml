pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// WHERE YOU ARE, every step of the way back, and a place to type one.
//
// The crumbs do the thing a field cannot - go back several steps in one press,
// and be a drop target while you do. The FIELD does the thing crumbs cannot:
// take a path you already know, or one you pasted, and go straight there. Both,
// because they are answers to different questions and a browser that offered
// only the first is a browser you cannot paste a path into.
//
// Typing a path here is still `cd` in the end (see services/Files.qml): the
// shell owns the directory, and this is one more way of asking it to move.
Item {
    id: root

    // The crumb something is currently being dragged over, or -1.
    property int receiving: -1
    property bool editing: false

    implicitHeight: Math.max(buttons.implicitHeight, crumbs.implicitHeight, field.implicitHeight + Appearance.padding.small * 2)

    function edit(): void {
        root.editing = true;
        entry.text = Files.cwd;
        entry.forceActiveFocus();
        entry.selectAll();
    }

    function stopEditing(): void {
        root.editing = false;
        Files.focus = "grid";
    }

    // BACK, FORWARD, UP. The three that every file browser has, in the order
    // every file browser has them, because this is not the place to be
    // interesting. Dimmed rather than hidden when there is nowhere to go: a
    // control that disappears moves everything beside it.
    Row {
        id: buttons

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Repeater {
            model: [
                {
                    icon: "arrow_back",
                    enabled: Files.back.length > 0,
                    run: () => Files.goBack()
                },
                {
                    icon: "arrow_forward",
                    enabled: Files.forward.length > 0,
                    run: () => Files.goForward()
                },
                {
                    icon: "arrow_upward",
                    enabled: Files.cwd !== "/",
                    run: () => Files.go(Files.parentOf(Files.cwd))
                }
            ]

            delegate: Item {
                id: button

                required property var modelData

                implicitWidth: Appearance.sizes.minTarget
                implicitHeight: Appearance.sizes.minTarget

                G2Rect {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.small / 2

                    radius: Appearance.rounding.small
                    color: press.containsMouse && button.modelData.enabled ? Appearance.colour.fill : "transparent"
                }

                Icon {
                    id: glyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: glyph.inkOffsetX
                    anchors.verticalCenterOffset: glyph.inkOffsetY

                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textGhost
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor

                    onClicked: button.modelData.run()
                }
            }
        }
    }

    Row {
        id: crumbs

        anchors.left: buttons.right
        anchors.leftMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.normal

        visible: !Files.searching && !root.editing
        spacing: 0

        Repeater {
            model: Files.crumbs

            delegate: Item {
                id: crumb

                required property int index
                required property var modelData

                readonly property bool last: crumb.index === Files.crumbs.length - 1

                implicitWidth: label.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: label.implicitHeight + Appearance.padding.small * 2

                G2Rect {
                    anchors.fill: parent

                    radius: Appearance.rounding.small
                    color: root.receiving === crumb.index ? Appearance.colour.accentFill : hover.hovered ? Appearance.colour.fill : "transparent"
                    stroke: root.receiving === crumb.index ? Appearance.colour.accent : "transparent"
                    strokeWidth: root.receiving === crumb.index ? Appearance.font.stem : 0
                }

                StyledText {
                    id: label

                    anchors.centerIn: parent

                    text: crumb.modelData.name
                    font.pixelSize: Appearance.sizes.filesText
                    // THE LAST CRUMB IS WHERE YOU ARE; the rest are where you
                    // have been. Weight rather than size carries that, which is
                    // the whole reason the type scale can stay at three
                    // (~/.claude/rules/type-scale.md).
                    color: crumb.last ? Appearance.colour.text : Appearance.colour.textFaint
                }

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: Files.go(crumb.modelData.path)
                }
            }
        }
    }

    // THE REST OF THE STRIP IS A WAY IN. Pressing the empty space to the right
    // of the crumbs turns the line into a field, which is where a pasted path
    // goes. Ctrl+L does the same thing from the keyboard, because that is the
    // chord every browser and every file manager has agreed on.
    MouseArea {
        anchors.left: crumbs.left
        anchors.right: crumbs.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        visible: !root.editing
        acceptedButtons: Qt.LeftButton
        // Not over the crumbs themselves: those have their own press, and this
        // sits under them so it only ever sees what they did not take.
        z: -1

        onClicked: root.edit()
    }

    G2Rect {
        anchors.left: buttons.right
        anchors.leftMargin: Appearance.padding.small
        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        implicitHeight: entry.implicitHeight + Appearance.padding.small * 2
        visible: root.editing

        radius: Appearance.rounding.small
        color: Appearance.colour.fill
        stroke: Appearance.colour.accent
        strokeWidth: Appearance.font.stem

        TextInput {
            id: entry

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.normal

            font.family: Appearance.font.family
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            selectByMouse: true
            renderType: Text.NativeRendering

            // A PATH IS A PATH, whatever spelling you have. `~` is the one
            // abbreviation everybody types and no directory is called, and a
            // trailing slash is what a completion leaves behind.
            function resolve(text: string): string {
                let out = text.trim();
                if (out.startsWith("~"))
                    out = Files.home + out.slice(1);
                if (out.length > 1 && out.endsWith("/"))
                    out = out.slice(0, -1);
                return out;
            }

            Keys.onReturnPressed: {
                const to = entry.resolve(entry.text);
                root.stopEditing();
                if (to)
                    Files.go(to);
            }

            Keys.onEscapePressed: root.stopEditing()
        }
    }

    // The search, when it is asked for. Not present otherwise: a field sitting
    // empty in the corner of every window is a field advertising itself, and
    // this shell's whole argument is that things appear when they are asked for.
    Item {
        id: search

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Files.searching ? root.width * 0.4 : glass.implicitWidth + Appearance.padding.normal
        implicitHeight: field.implicitHeight + Appearance.padding.small * 2


        G2Rect {
            anchors.fill: parent
            visible: Files.searching

            radius: Appearance.rounding.small
            color: Appearance.colour.fill
        }

        Icon {
            id: glass

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            name: "search"
            color: Files.searching ? Appearance.colour.text : Appearance.colour.textGhost
        }

        TextInput {
            id: field

            anchors.left: glass.right
            anchors.right: parent.right
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            visible: Files.searching
            // THE FIELDS ARE THE ONE PLACE IN THIS WINDOW THAT TAKE KEYS FOR
            // THEMSELVES. Everything else routes through the face's own handler;
            // a text field that did that would need the face to reimplement
            // editing, selection and the cursor.
            focus: Files.searching
            activeFocusOnTab: false

            font.family: Appearance.font.family
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            renderType: Text.NativeRendering

            text: Files.search
            onTextChanged: Files.setSearch(text)

            // Both ways out land on the grid, and differ in what they leave
            // behind: Return keeps the filter and hands the keys back, Escape
            // takes the filter off as well.
            Keys.onReturnPressed: {
                Files.setSearching(false);
                Files.focus = "grid";
            }

            Keys.onEscapePressed: {
                Files.setSearch("");
                Files.setSearching(false);
                Files.focus = "grid";
            }
        }

        TapHandler {
            onTapped: {
                Files.setSearching(true);
                Files.focus = "grid";
            }
        }
    }

    // WHICH CRUMB IS UNDER A POINT, asked of the row rather than of each crumb:
    // during a drag the ghost is under the cursor and takes every hover with it,
    // so a crumb cannot know on its own that it is the one being aimed at.
    //
    // One function answers it for both the highlight and the drop, because those
    // two disagreeing is a file landing somewhere other than where the outline
    // said it would.
    function crumbAt(position: point): int {
        if (Files.searching || root.editing)
            return -1;
        const local = crumbs.mapFromItem(root, position.x, position.y);
        const item = crumbs.childAt(local.x, local.y);
        return item && item.index !== undefined ? item.index : -1;
    }

    function pathAt(position: point): string {
        const index = root.crumbAt(position);
        return index < 0 ? "" : Files.crumbs[index].path;
    }
}
