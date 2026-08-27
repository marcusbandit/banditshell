pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// ONE LINE OF TEXT, ASKED FOR.
//
// New folder, new file, rename: three questions with the same shape, so they
// share the one card rather than growing three dialogs that drift apart. The
// caller hands in what to ask, what the field should start as, and what to do
// with the answer.
//
// It takes the keyboard while it is up - it is a field, and a field that routed
// through the window's key handler would need that handler to reimplement
// editing - and hands it back on the way out. See FilesFace's note on why that
// handover has to be explicit.
Item {
    id: root

    property string title: ""
    property var accepted: null

    // UP BEFORE IT IS VISIBLE, and that is not a duplicate of `opacity`.
    // `visible` bound to the animated opacity is false at the instant ask() is
    // called - the Behavior starts the fade at 0 - and an INVISIBLE ITEM CANNOT
    // TAKE FOCUS. The field appeared, correctly filled, and swallowed nothing:
    // everything typed went to the grid behind it.
    property bool up: false

    signal dismissed

    function ask(question: string, initial: string, select: int, onAccept: var): void {
        root.title = question;
        root.accepted = onAccept;
        field.text = initial;
        root.up = true;
        root.opacity = 1;

        // After the item is actually visible, which is the next turn of the
        // event loop rather than this one.
        Qt.callLater(() => {
            field.forceActiveFocus();
            // SELECT THE PART THAT CHANGES. Renaming "photo.jpg" is almost
            // always renaming "photo", and a field that selects the extension
            // too makes you put it back by hand every time.
            if (select > 0)
                field.select(0, select);
            else
                field.selectAll();
        });
    }

    function close(): void {
        root.up = false;
        root.opacity = 0;
        root.accepted = null;
        root.dismissed();
    }

    function commit(): void {
        const answer = field.text.trim();
        const run = root.accepted;
        root.close();
        if (answer && run)
            run(answer);
    }

    visible: root.up || root.opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutQuad
        }
    }

    // The scrim, which is also the way out: pressing off the card is a cancel,
    // the same as it is for every other sheet in this shell.
    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    G2Rect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 420)
        implicitHeight: body.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.font.stem

        Column {
            id: body

            anchors.centerIn: parent
            width: parent.width - Appearance.padding.large * 2
            spacing: Appearance.padding.normal

            StyledText {
                width: parent.width

                text: root.title
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            G2Rect {
                width: parent.width
                implicitHeight: field.implicitHeight + Appearance.padding.normal * 2

                radius: Appearance.rounding.small
                color: Appearance.colour.fill

                TextInput {
                    id: field

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.padding.normal

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    selectByMouse: true
                    renderType: Text.NativeRendering

                    Keys.onReturnPressed: root.commit()
                    Keys.onEnterPressed: root.commit()
                    Keys.onEscapePressed: root.close()
                }
            }

            StyledText {
                width: parent.width

                text: "Enter to confirm  ·  Escape to cancel"
                color: Appearance.colour.textFaint
            }
        }
    }
}
