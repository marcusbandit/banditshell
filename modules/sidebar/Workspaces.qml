pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    required property string screen

    readonly property string style: Appearance.sizes.wsStyle

    readonly property var blobs: content.item?.blobs ?? []

    implicitHeight: content.item?.implicitHeight ?? 0

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.implicitHeight

        sourceComponent: root.style === "map" ? map : root.style === "blocks" ? blocks : plates
    }

    Component {
        id: plates

        WorkspacePlates {
            screen: root.screen
        }
    }

    Component {
        id: map

        WorkspaceMap {
            screen: root.screen
        }
    }

    Component {
        id: blocks

        WorkspaceBlocks {
            screen: root.screen
        }
    }
}
