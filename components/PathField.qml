import QtQuick
import qs.config

// A SETTING THAT IS A PIECE OF TEXT, which is a shape this shell did not have.
//
// Everything on a settings page so far is a switch, a slider or a list of
// names: a control whose whole range is on the screen, where the page can offer
// you every value it will accept. A folder path is the first setting whose
// value is unbounded, and the only honest control for one is a place to type.
//
// TWO STATES, and the resting one is a row like any other. It reads as a
// MenuRow because it IS one until you press it, so a page does not grow a
// permanently open text box for a setting that gets changed twice a year, and
// the value spends its life being READ rather than being edited. Pressing it
// swaps the row for the field; Enter keeps what you typed, Escape puts it back.
//
// THE KEYBOARD IS CLAIMED ONLY WHILE EDITING, and that is not a detail.
// A shell surface gets no key events until its window asks the compositor for
// them (see Prompts), and a field that claimed on becoming VISIBLE, which is
// what components/PasswordField.qml does, would make the settings panel hold
// the keyboard for the whole time the page is open: a password field appears in
// answer to a press and is gone a second later, and this one sits on the page
// for as long as you are looking at anything else on it. So the claim follows
// the EDIT rather than the existence, which is also the only reason the page's
// other rows go on answering the arrow keys.
Item {
    id: root

    property string icon: ""
    property string label: ""

    // What is stored. The field is seeded from this every time editing starts,
    // so an edit abandoned halfway leaves nothing behind and the next opening
    // shows the setting rather than the last thing typed at it.
    property string value: ""

    // Said under the label while not editing: what this path currently amounts
    // to, which for a wallpaper folder is how many pictures came out of it. A
    // path is a claim about the disk and the count is the only thing on the row
    // that can contradict it.
    property string detail: ""

    property string placeholder: ""

    // What the row says on hover, MenuRow's contract.
    property string tip: ""

    signal committed(string path)

    property bool editing: false

    implicitHeight: editing ? Appearance.sizes.rowHeight : row.implicitHeight

    function begin(): void {
        input.text = root.value;
        root.editing = true;
        // DEFERRED for the launcher's reason: the window asks the compositor
        // for the keyboard as a consequence of the claim below, and focus taken
        // in this same pass is focus in a surface that has no keys to give yet.
        Qt.callLater(input.forceActiveFocus);
    }

    function finish(): void {
        root.editing = false;
        Prompts.release(root);
    }

    // Asking for the keyboard and having it are a round trip apart, so focus is
    // taken again when the surface actually becomes active. PasswordField
    // carries the same handler and the same note.
    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.editing)
        input.forceActiveFocus()

    onEditingChanged: if (root.editing)
        Prompts.request(root);

    // A page closing destroys its rows outright, without them passing through
    // anything that would let go of the claim.
    Component.onDestruction: Prompts.release(root)

    MenuRow {
        id: row

        width: root.width
        visible: !root.editing
        icon: root.icon
        label: root.label
        detail: root.detail
        tip: root.tip
        onActivated: root.begin()
    }

    // THE FIELD, which borrows PasswordField's shape rather than its behaviour:
    // the same strong fill, the same radius, the same three-sizes body type, so
    // a page with one of each on it does not look like two shells.
    Item {
        id: field

        width: root.width
        height: Appearance.sizes.rowHeight
        visible: root.editing

        G2Rect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: input

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

            // WHAT YOU TYPED IS WHAT IS STORED, tilde and all.
            //
            // Not expanded here, and not trimmed into an absolute path either.
            // `~/Pictures/Wallpapers` is the value a settings file should hold:
            // it survives the home directory moving, it is what the defaults
            // already say, and services/Wallpaper.qml expands it at the point of
            // use precisely so that the stored form can stay the one a person
            // would write. Turning it absolute here would silently rewrite the
            // setting the moment you opened the row to read it.
            onAccepted: {
                root.committed(text);
                root.finish();
            }

            // NOTHING IS KEPT. `value` never moved, so leaving is enough.
            Keys.onEscapePressed: root.finish()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                text: root.placeholder
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }
}
