pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "urls.js" as Urls

SquircleRect {
    id: root

    property string label: ""
    property string path: ""
    property string name: ""
    property bool folder: false
    property bool picture: false
    property var facts: null
    property bool newer: false

    readonly property string detail: {
        if (!root.facts)
            return "";
        const size = root.facts.count >= 0 ? (root.facts.count === 1 ? "1 item" : `${root.facts.count} items`) : Files.humanSize(root.facts.size);
        return `${size} · ${Files.humanTime(root.facts.modified)}`;
    }

    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2

    radius: Appearance.rounding.normal
    color: Appearance.colour.fill

    Row {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.padding.normal

        Item {
            id: picture

            width: Appearance.font.line.small * 3
            height: width
            anchors.verticalCenter: parent.verticalCenter

            SquircleImage {
                id: thumb

                anchors.fill: parent
                visible: root.picture && status === Image.Ready

                source: root.picture && root.path ? Urls.fileUrl(root.path) : ""
                radius: Appearance.rounding.small
                decodeWidth: Appearance.sizes.filesThumbnail
                decodeHeight: Appearance.sizes.filesThumbnail
            }

            FileMark {
                anchors.centerIn: parent
                visible: !thumb.visible

                fileClass: root.folder ? "directory" : root.picture ? "image" : "unknown"
                path: root.path
                name: root.name
                size: parent.width * 0.7
            }
        }

        Column {
            width: row.width - picture.width - row.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width

                text: root.label
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width

                text: root.detail
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: root.newer

                text: "Newer"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.accent
            }
        }
    }
}
