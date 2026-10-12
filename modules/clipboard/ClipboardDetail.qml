pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var entry: null

    signal back
    signal accepted

    readonly property bool isImage: !!root.entry && root.entry.kind === "image" && !!root.entry.file
    readonly property bool isColour: !!root.entry && root.entry.kind === "colour"
    readonly property bool isFiles: !!root.entry && (root.entry.paths ?? []).length > 0
    readonly property bool isJson: !!root.entry && root.entry.kind === "json"

    readonly property string body: {
        if (!root.entry)
            return "";
        const tidy = Clipboard.formatted(root.entry);
        return tidy ? tidy : (root.entry.text ?? "");
    }

    readonly property string language: root.isJson ? "json" : root.entry?.kind === "code" ? "" : ""

    onEntryChanged: if (root.entry)
        Clipboard.beautify(root.entry)

    Item {
        id: head

        x: Appearance.padding.large
        y: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
        height: Math.max(backOut.height, caption.implicitHeight)

        Item {
            id: backOut

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
            height: width

            SquircleRect {
                anchors.fill: parent
                radius: height / 2
                color: Appearance.colour.fill
                opacity: backPress.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "chevron_left"
                size: Appearance.font.iconSize
                color: backPress.containsMouse ? Appearance.colour.text : Appearance.colour.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: backPress

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }

            HoverTip {
                text: "Back to the list"
                asked: backPress.containsMouse
            }
        }

        Column {
            id: caption

            anchors.left: backOut.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: useIt.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width
                elide: Text.ElideRight

                font.pixelSize: Appearance.font.size.normal
                text: root.entry ? Clipboard.summarise(root.entry).replace(/\s+/g, " ").trim().slice(0, 80) || root.entry.kind : ""
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                color: Appearance.colour.textFaint
                text: {
                    if (!root.entry)
                        return "";
                    const bits = [root.entry.kind];
                    if (root.entry.w > 0)
                        bits.push(`${root.entry.w} × ${root.entry.h}`);
                    const size = Clipboard.size(root.entry.bytes);
                    if (size)
                        bits.push(size);
                    if (!root.isImage && (root.entry.text ?? "").length) {
                        const n = root.body.split("\n").length;
                        bits.push(n === 1 ? "1 line" : `${n} lines`);
                    }
                    bits.push(Clipboard.age(root.entry.recorded));
                    return bits.join("  ·  ");
                }
            }
        }

        Button {
            id: useIt

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Copy"
            onClicked: root.accepted()
        }
    }

    Separator {
        id: rule

        anchors.top: head.bottom
        anchors.topMargin: Appearance.padding.normal
        x: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
    }

    Item {
        id: stage

        anchors.top: rule.bottom
        anchors.topMargin: Appearance.padding.normal
        x: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
        height: Math.max(0, parent.height - y - Appearance.padding.large)
        clip: true

        SquircleImage {
            anchors.fill: parent
            visible: root.isImage
            source: root.isImage ? `file://${root.entry.file}` : ""
            radius: Appearance.rounding.normal
            fillMode: Image.PreserveAspectFit

            decodeWidth: stage.width
            decodeHeight: stage.height
        }

        Item {
            anchors.fill: parent
            visible: root.isColour

            SquircleRect {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: Math.min(parent.width, parent.height * 0.6)
                height: Math.max(0, parent.height - swatchLabel.height - Appearance.padding.large)
                radius: Appearance.rounding.large
                color: root.isColour ? root.swatch : "transparent"
                stroke: Appearance.colour.separator
                strokeWidth: Appearance.font.stem
            }

            StyledText {
                id: swatchLabel

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Appearance.font.size.normal
                text: root.entry ? (root.entry.text ?? "").trim() : ""
            }
        }

        GlideList {
            anchors.fill: parent
            visible: root.isFiles && !root.isImage
            model: root.entry ? (root.entry.paths ?? []) : []
            clip: true

            delegate: Item {
                required property string modelData
                required property int index

                width: ListView.view.width
                height: Math.max(Appearance.sizes.rowHeight, line.implicitHeight + Appearance.padding.normal)

                readonly property string mime: root.entry ? ((root.entry.mimes ?? [])[index] ?? "") : ""
                readonly property bool gone: mime === ""

                Icon {
                    id: fileMark

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: parent.gone ? "help" : parent.mime.startsWith("image/") ? "image" : parent.mime.startsWith("audio/") ? "graphic_eq" : parent.mime.startsWith("video/") ? "movie" : "draft"
                    size: Appearance.font.iconSize
                    color: parent.gone ? Appearance.colour.textGhost : Appearance.colour.textFaint
                }

                Column {
                    id: line

                    anchors.left: fileMark.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small / 2

                    StyledText {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: modelData
                        color: gone ? Appearance.colour.textFaint : Appearance.colour.text
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Appearance.colour.textFaint
                        text: gone ? "not there any more" : mime
                    }
                }
            }
        }

        CodeBlock {
            anchors.fill: parent
            visible: !root.isImage && !root.isColour && !root.isFiles
            text: root.body
            language: root.language
            wrap: root.entry?.kind !== "json" && root.entry?.kind !== "code"
            gutter: root.entry?.kind === "json" || root.entry?.kind === "code"
        }
    }

    readonly property color swatch: {
        const t = root.entry ? (root.entry.text ?? "").trim() : "";
        const hex = t.startsWith("#") ? t : `#${t}`;
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : Appearance.colour.textFaint;
    }
}
