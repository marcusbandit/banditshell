import QtQuick
import Quickshell
import qs.config

Item {
    id: root

    property string path: ""
    property bool readOnly: false

    signal committed(string path)

    property bool editing: false

    implicitWidth: root.editing ? field.implicitWidth : shown.implicitWidth
    implicitHeight: Math.max(shown.implicitHeight, root.editing ? field.implicitHeight : 0)

    function expand(p: string): string {
        return p.startsWith("~") ? `${Quickshell.env("HOME")}${p.slice(1)}` : p;
    }

    SettingsPath {
        id: shown

        anchors.verticalCenter: parent.verticalCenter
        visible: !root.editing
        path: root.path
        readOnly: root.readOnly
        onOpened: Quickshell.execDetached(["xdg-open", root.expand(root.path)])
        onBrowsed: {
            root.editing = true;
            Qt.callLater(field.take);
        }
    }

    SettingsField {
        id: field

        anchors.verticalCenter: parent.verticalCenter
        visible: root.editing
        width: 260
        text: root.path
        onCommitted: t => {
            root.editing = false;
            if (t.trim() && t !== root.path)
                root.committed(t.trim());
        }
        onEditingChanged: if (!editing)
            root.editing = false
    }
}
