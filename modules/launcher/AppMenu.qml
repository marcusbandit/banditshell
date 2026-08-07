pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// WHAT A ROW CAN HAVE DONE TO IT, asked for by holding the row down.
//
// The launcher used to carry its one context action as a disc on the right end
// of every row: a hover-only button that hid the application. That worked and it
// could not grow. A second action needs a second disc, a third needs a third,
// and a column of small round buttons down the right edge of a list is a column
// you have to read past on every row you were only scanning. Worse, the disc is
// invisible to a finger by construction (see the row's `atStow` note), so on a
// touchscreen the only way to reach it was a long press that did one fixed thing
// with no way to say what.
//
// So the long press opens THIS instead, and it is also what a right button does.
// Both are the gesture the hand already has for "tell me about this one", the
// list gets its right-hand margin back, and hiding stops being the single
// privileged action and becomes one line in a list of them.
//
// IT IS RENDERED FROM DATA. `actions` below is the whole menu; nothing about the
// sheet knows how many rows there are or what any of them do. Folders make that
// necessary rather than tidy: the number of "move to" lines is the number of
// folders you happen to have made.
Item {
    id: root

    // WHAT THE MENU IS ABOUT, and exactly one of these is set. An application
    // row hands over its entry; a folder row hands over its key.
    property var entry: null
    property string folder: ""

    property bool shown: false

    signal openFolder(string key)

    // A sheet is a MENU, which means it goes away when it has been used. Every
    // action closes it; the ones that need a name open the second face first.
    signal acted

    // THE NAME FIELD IS DONE WITH THE KEYBOARD. The launcher owns it the rest of
    // the time and has to be told when to take it back; this is that, and it is
    // a signal rather than a reach upward because a sheet has no business
    // knowing what is above it.
    signal releaseKeys

    // WHICH LINE THE KEYBOARD IS ON.
    //
    // The sheet can be opened with a key (the launcher's Menu / Shift+F10), and
    // a menu you can open but not drive without reaching for the mouse is worse
    // than no key at all: it puts your hand on the mouse anyway, one step later.
    property int at: 0

    function step(delta: int): void {
        const n = root.actions.length;
        if (n > 0)
            root.at = ((root.at + delta) % n + n) % n;
    }

    function activate(): void {
        const action = root.actions[root.at];
        if (action)
            root.run(action);
    }

    readonly property var folderMap: Apps.folders

    // THE MENU, as data.
    //
    // `act` is what the row does and `key` is whichever folder it does it to.
    // Ordered by how often it is the answer: the star first, because that is the
    // reason this menu exists, and the drawer last, because putting an
    // application away is the one thing here you rarely do twice.
    //
    // THE SUBJECT'S STATE IS READ IN HERE, as locals, and that is a correctness
    // requirement rather than a style. It was three properties of its own, and
    // three properties is three separate bindings which do not update in step:
    // opening the sheet changes `entry`, this list re-evaluated on that change
    // while `favourite` was still answering about the LAST subject, and the row
    // it built said "put it on the star" about something already starred. The
    // right value arrived one pass later and by then the rows had been made.
    // Read as locals there is only one evaluation, so the question and the
    // answer are about the same application by construction.
    //
    // EMPTY WHEN THERE IS NO SUBJECT, which is both true and load-bearing: a
    // Repeater over a plain array reuses its delegates when the new array is the
    // same LENGTH as the old one, so a menu that always had five rows could hand
    // the second application the first one's labels. Closing sets the subject to
    // nothing, the list goes to zero, and the next open is built from scratch.
    readonly property var actions: {
        const subject = root.entry;
        if (!subject && !root.folder)
            return [];

        const out = [];

        if (root.folder) {
            out.push({
                act: "open",
                icon: "folder_open",
                label: "Open it",
                detail: ""
            });
            out.push({
                act: "rename",
                icon: "edit",
                label: "Rename it",
                detail: ""
            });
            out.push({
                act: "dissolve",
                icon: "folder_delete",
                label: "Break it up",
                // Said out loud, because "delete" is the word the eye expects
                // here and this is emphatically not that: the members keep
                // their stars and go back to sitting loose. Short enough to
                // survive MenuRow's detail cap, which is a share of the row's
                // width and so is narrow in a sheet this size.
                detail: "apps stay"
            });
            return out;
        }

        const starred = Apps.isFavourite(subject);
        const away = Apps.isHidden(subject);
        const home = Apps.folderOf(subject?.id ?? "");

        out.push({
            act: "star",
            icon: "star",
            label: starred ? "Take off the star" : "Put it on the star",
            detail: ""
        });

        if (home)
            out.push({
                act: "unfile",
                icon: "folder_off",
                label: `Take it out of ${root.folderMap[home]?.name ?? "the folder"}`,
                detail: ""
            });

        for (const key in root.folderMap) {
            if (key === home)
                continue;
            out.push({
                act: "file",
                key: key,
                icon: "folder",
                label: `Move it to ${root.folderMap[key].name}`,
                detail: ""
            });
        }

        out.push({
            act: "new",
            icon: "create_new_folder",
            label: "New folder with it",
            detail: ""
        });

        out.push({
            act: "hide",
            icon: away ? "visibility" : "visibility_off",
            label: away ? "Put it back in the list" : "Hide it from the list",
            detail: ""
        });

        return out;
    }

    // THE SECOND FACE: a name being typed, for the two actions that need one.
    // Not a separate popup, because it is the same decision continuing: the
    // sheet stays exactly where it is and its contents change.
    property bool naming: false

    readonly property real rowPitch: Appearance.sizes.rowHeight
    readonly property real framePad: Appearance.padding.normal

    // AS TALL AS WHICHEVER FACE IS SHOWING. Read by the launcher, which is what
    // decides where the sheet can sit without leaving the panel.
    implicitHeight: (root.naming ? root.rowPitch * 2 : root.rowPitch * root.actions.length) + root.framePad * 2

    visible: reveal.value > 0.001

    // ASKED AGAIN, at the moment of acting, rather than acting on what the row
    // was labelled with when it was drawn. Same reason the labels are locals
    // above: a toggle that carries its own idea of the current state is a toggle
    // that can be wrong, and this one is one press away from writing that wrong
    // idea to disk.
    function run(action: var): void {
        switch (action.act) {
        case "star":
            Apps.setFavourite(root.entry, !Apps.isFavourite(root.entry));
            break;
        case "hide":
            Apps.setHidden(root.entry, !Apps.isHidden(root.entry));
            break;
        case "file":
            Apps.fileInFolder(action.key, root.entry);
            break;
        case "unfile":
            Apps.takeOutOfFolder(root.entry);
            break;
        case "new":
            root.ask("");
            return;
        case "rename":
            root.ask(root.folderMap[root.folder]?.name ?? "");
            return;
        case "dissolve":
            Apps.dissolveFolder(root.folder);
            break;
        case "open":
            root.openFolder(root.folder);
            break;
        }
        root.acted();
    }

    function ask(prefill: string): void {
        root.naming = true;
        name.text = prefill;
        name.selectAll();
        Qt.callLater(name.forceActiveFocus);
    }

    // The name landed. Renaming keeps the folder it was opened on; naming a new
    // one makes it AND puts the application in it in one go, because "new folder
    // with it" is one decision and finishing it in two would leave an empty
    // folder behind every time the second half was abandoned.
    function commit(): void {
        const text = name.text.trim();
        if (!text) {
            root.naming = false;
            return;
        }

        if (root.folder)
            Apps.renameFolder(root.folder, text);
        else
            Apps.fileInFolder(Apps.createFolder(text), root.entry);

        root.naming = false;
        root.acted();
    }

    onShownChanged: {
        if (!root.shown)
            root.naming = false;
        // AT THE TOP every time it opens. A menu that remembers where you left
        // the highlight is a menu that acts on the wrong line the one time you
        // press Return without looking.
        root.at = 0;
    }

    // Leaving the name field is the launcher's cue to take the keyboard back,
    // whether the name was committed or abandoned.
    onNamingChanged: if (!root.naming)
        root.releaseKeys()

    Follow {
        id: reveal

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // GROWS OUT OF THE ROW IT WAS ASKED FOR, rather than fading in over it: the
    // sheet is the row saying more about itself, so it leaves from the row's own
    // edge. A short rise plus opacity, both off the one Follow, so there is
    // nothing for the two to disagree about.
    G2Rect {
        id: sheet

        anchors.fill: parent
        anchors.topMargin: (1 - reveal.value) * Appearance.padding.large

        opacity: reveal.value
        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: 1

        // The sheet eats every press that lands on it, including the ones that
        // miss a row. Without this a tap on the sheet's own padding falls
        // through to the launcher's catcher and closes the whole launcher, which
        // is the same bug the panel's put-away Pull was added to fix one level
        // up.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        Column {
            id: face

            anchors.fill: parent
            anchors.margins: root.framePad

            visible: !root.naming

            Repeater {
                model: root.actions

                delegate: MenuRow {
                    required property var modelData
                    required property int index

                    width: face.width
                    rowHeight: root.rowPitch
                    icon: modelData.icon
                    label: modelData.label
                    detail: modelData.detail
                    inlineDetail: true
                    labelSize: Appearance.font.size.small
                    selected: index === root.at

                    // The pointer MOVES the highlight rather than ignoring it,
                    // so the two inputs never disagree about which line is next:
                    // arrive with the mouse, press Return, and it acts on the row
                    // you are looking at.
                    onHoveredChanged: if (hovered)
                        root.at = index

                    onActivated: root.run(modelData)
                }
            }
        }

        // THE NAME. One line, and the keyboard is already here: the launcher
        // holds it exclusively while it is open, so a field inside it does not
        // have to ask for anything, only take the focus.
        Item {
            anchors.fill: parent
            anchors.margins: root.framePad

            visible: root.naming

            StyledText {
                id: prompt

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.rowPitch

                text: root.folder ? "What is it called?" : "Name the folder"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                verticalAlignment: Text.AlignVCenter
            }

            G2Rect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: prompt.bottom
                height: root.rowPitch

                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                TextInput {
                    id: name

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.normal
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    verticalAlignment: Text.AlignVCenter
                    clip: true

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.commit();
                            break;
                        case Qt.Key_Escape:
                            // BACK, not out. The naming face was reached from
                            // the actions and Escape should walk the same way it
                            // came; a second Escape then closes the sheet, and a
                            // third closes the launcher.
                            root.naming = false;
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
