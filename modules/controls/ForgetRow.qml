import QtQuick

MenuRow {
    id: root

    property bool armed: false

    signal confirmed

    label: root.armed ? "Press again to forget" : "Forget it"
    selected: root.armed

    onActivated: {
        if (root.armed) {
            root.armed = false;
            root.confirmed();
        } else {
            root.armed = true;
        }
    }

    onVisibleChanged: if (!root.visible)
        root.armed = false

    Timer {
        interval: 4000
        running: root.armed
        onTriggered: root.armed = false
    }
}
