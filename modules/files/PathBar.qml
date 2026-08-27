pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// WHERE YOU ARE, and every step of the way back.
//
// A breadcrumb rather than an editable path field, because the path is not this
// window's to edit: the shell owns the directory (see services/Files.qml), so
// the way to type a path here is to type `cd` in the terminal, which is the same
// gesture and already exists. What a crumb does is the one thing a field cannot:
// go back several steps in one press, and be a drop target while you do.
//
// It is also where the SEARCH lives when there is one, in the same strip rather
// than in a bar of its own. `/` is a filter over what is in front of you, and
// putting it anywhere but on the line that says what is in front of you would
// make it look like a different question.
Item {
    id: root

    // The crumb something is currently being dragged over, or -1.
    property int receiving: -1

    implicitHeight: Math.max(crumbs.implicitHeight, field.implicitHeight)

    Row {
        id: crumbs

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: search.left
        anchors.rightMargin: Appearance.padding.normal

        visible: !Files.searching
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

    // The search, when it is asked for. Not present otherwise: a field sitting
    // empty in the corner of every window is a field advertising itself, and
    // this shell's whole argument is that things appear when they are asked for.
    Item {
        id: search

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Files.searching ? root.width * 0.5 : glass.implicitWidth
        implicitHeight: field.implicitHeight + Appearance.padding.small * 2

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutQuad
            }
        }

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
            // THE FIELD IS THE ONE PLACE IN THIS WINDOW THAT TAKES KEYS FOR
            // ITSELF. Everything else routes through the face's own handler; a
            // text field that did that would need the face to reimplement
            // editing, selection and the cursor.
            focus: Files.searching
            activeFocusOnTab: false

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText
            renderType: Text.NativeRendering

            text: Files.search
            onTextChanged: Files.search = text

            // Both ways out land on the grid, and differ in what they leave
            // behind: Return keeps the filter and hands the keys back, Escape
            // takes the filter off as well.
            Keys.onReturnPressed: {
                Files.searching = false;
                Files.focus = "grid";
            }

            Keys.onEscapePressed: {
                Files.search = "";
                Files.searching = false;
                Files.focus = "grid";
            }
        }

        TapHandler {
            onTapped: {
                Files.searching = true;
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
        if (Files.searching)
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
