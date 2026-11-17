import QtQuick
import qs.config
import qs.components
import qs.services
import "../../../services/notes.js" as Logic

Item {
    id: root

    property string typed: ""
    property string query: ""
    property string selection: ""
    property var view: null

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)
    signal asks(Item item, var actions, real x, real y)

    readonly property string text: root.query.trim()
    readonly property string fileName: Logic.quickFileName(root.text, Date.now())

    implicitHeight: Appearance.sizes.rowHeight * 6

    function save(): void {
        const text = root.text;
        if (text)
            root.launch(() => Notes.capture(text));
    }

    function claimKey(event: var): bool {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
            return false;
        root.save();
        return true;
    }

    SquircleRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.margins: Appearance.padding.normal
        radius: Appearance.rounding.small
        color: Appearance.colour.fill

        StyledText {
            anchors.fill: parent
            anchors.margins: Appearance.padding.normal
            text: root.text || "Type your note above"
            font.pixelSize: Appearance.font.size.normal
            color: root.text ? Appearance.colour.text : Appearance.colour.textFaint
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }
    }

    PageFooter {
        id: footer

        anchors.bottom: parent.bottom
        width: root.width
        icon: "edit_note"
        title: root.text ? `${Notes.quickFolder}/${root.fileName}.md` : Notes.quickFolder
        primary: root.text ? "Save" : ""
        onPrimed: root.save()
    }
}
