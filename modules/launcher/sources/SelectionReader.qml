import QtQuick
import qs.services

QtObject {
    id: root

    required property var search

    property bool wanted: false

    property bool asked: false
    property double askedAt: 0

    onWantedChanged: {
        if (!root.wanted || root.asked)
            return;
        root.asked = true;
        root.askedAt = Date.now();
        Assistant.readSelection();
    }

    property Connections opening: Connections {
        target: root.search

        function onStartedChanged(): void {
            if (!root.search.started)
                root.asked = false;
        }
    }

    readonly property bool fresh: root.asked && Assistant.selectionAt >= root.askedAt

    readonly property string text: root.fresh && Assistant.selection.trim() && Assistant.selection !== root.search.query ? Assistant.selection : ""

    readonly property bool nothing: root.fresh && !root.text
}
