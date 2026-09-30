import QtQuick
import qs.config

Item {
    id: root

    property string icon: ""
    property string label: ""

    property string value: ""

    property string detail: ""

    property string placeholder: ""

    property string tip: ""

    signal committed(string path)

    property bool editing: false

    implicitHeight: editing ? Appearance.sizes.rowHeight : row.implicitHeight

    function begin(): void {
        input.text = root.value;
        root.editing = true;

        Qt.callLater(input.forceActiveFocus);
    }

    function finish(): void {
        root.editing = false;
        Prompts.release(root);
    }

    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.editing)
        input.forceActiveFocus()

    onEditingChanged: if (root.editing)
        Prompts.request(root);

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

    Item {
        id: field

        width: root.width
        height: Appearance.sizes.rowHeight
        visible: root.editing

        SquircleRect {
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

            onAccepted: {
                root.committed(text);
                root.finish();
            }

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
