import QtQuick

QtObject {
    id: root

    property bool active: false
    property var kinds: []

    function sync(): void {
        if (root.active)
            Levels.cover(root, root.kinds);
        else
            Levels.uncover(root);
    }

    onActiveChanged: root.sync()
    onKindsChanged: root.sync()

    Component.onCompleted: root.sync()
    Component.onDestruction: Levels.uncover(root)
}
