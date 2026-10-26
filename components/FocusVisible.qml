import QtQuick

Item {
    id: root

    property bool active: false

    property point resting: Qt.point(-1, -1)

    function keyed(): void {
        root.active = true;
    }

    function clear(): void {
        root.active = false;
    }

    HoverHandler {
        id: pointer

        parent: root.parent

        onPointChanged: {
            const at = pointer.point.scenePosition;
            if (at.x === root.resting.x && at.y === root.resting.y)
                return;
            root.resting = at;
            root.clear();
        }
    }

    PointHandler {
        parent: root.parent
        acceptedButtons: Qt.AllButtons
        onActiveChanged: if (active)
            root.clear()
    }
}
