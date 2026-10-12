pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var entry
    required property int index

    property bool selected: false

    signal activated
    signal pinned
    signal discarded

    signal menu(real mx, real my)

    signal expanded

    signal entered
    signal exited

    readonly property bool isImage: root.entry.kind === "image" && !!root.entry.file
    readonly property bool hovered: hover.hovered

    property real thrown: 0
    property bool throwing: false

    readonly property real throwFull: Math.max(1, root.width * Appearance.sizes.dragDismissFraction)
    readonly property real throwFraction: Math.min(1, Math.abs(root.thrown) / root.throwFull)

    readonly property bool focused: root.selected || root.hovered

    implicitHeight: (root.isImage ? Appearance.sizes.clipboardPreview : Math.max(Appearance.sizes.rowHeight, body.implicitHeight + Appearance.padding.normal * 2)) + Appearance.padding.small

    Follow {
        id: slide

        speed: Appearance.anim.revealSpeed
        target: root.throwing ? root.thrown : 0
    }

    readonly property real offset: slide.value * Appearance.sizes.dragResistance

    Item {
        id: card

        x: root.offset
        width: root.width
        height: root.height - Appearance.padding.small

        opacity: root.thrown < 0 ? 1 - root.throwFraction * 0.7 : 1

        SquircleRect {
            anchors.fill: parent

            radius: Appearance.rounding.normal
            color: root.selected ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: root.focused ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        SquircleRect {
            x: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.font.stem
            height: parent.height - Appearance.padding.normal * 2
            radius: width / 2
            color: Appearance.colour.accent
            visible: Clipboard.current === root.entry.id
        }

        Item {
            id: markSlot

            x: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            readonly property real minAspect: 0.5
            readonly property real maxAspect: 2.5

            readonly property real known: root.entry.w > 0 && root.entry.h > 0 ? root.entry.w / root.entry.h : root.entry.aspect > 0 ? root.entry.aspect : 0
            readonly property real aspect: known > 0 ? Math.max(minAspect, Math.min(known, maxAspect)) : 1

            width: root.isImage ? Math.round(height * aspect) : Appearance.sizes.clipboardIcon
            height: root.isImage ? parent.height - Appearance.padding.normal * 2 : Appearance.sizes.clipboardIcon

            SquircleImage {
                id: thumb

                anchors.fill: parent
                visible: root.isImage
                source: root.isImage ? `file://${root.entry.file}` : ""
                radius: Appearance.rounding.small
                fillMode: Image.PreserveAspectCrop

                decodeWidth: 0
                decodeHeight: markSlot.height

                onStatusChanged: if (thumb.status === Image.Ready && thumb.implicitSourceHeight > 0)
                    Clipboard.noteAspect(root.entry.id, thumb.implicitSourceWidth / thumb.implicitSourceHeight)
            }

            Icon {
                anchors.centerIn: parent
                visible: root.isImage && thumb.status === Image.Error
                name: "broken_image"
                size: Appearance.sizes.clipboardIcon
                color: Appearance.colour.textFaint
            }

            SquircleRect {
                anchors.centerIn: parent
                width: Appearance.font.iconSize
                height: width
                radius: height / 2
                visible: root.entry.kind === "colour"
                color: root.swatch
                stroke: Appearance.colour.separator
                strokeWidth: Appearance.font.stem
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.isImage && root.entry.kind !== "colour"
                name: Clipboard.markFor(root.entry.kind)
                size: Appearance.sizes.clipboardIcon
                color: root.selected ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }

        Column {
            id: body

            anchors.left: markSlot.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: trailing.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width
                text: root.title
                color: root.selected ? Appearance.colour.text : Appearance.colour.textDim

                maximumLineCount: root.isImage ? 1 : Appearance.sizes.clipboardLines
                wrapMode: Text.Wrap
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            StyledText {
                width: parent.width
                text: root.detail
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Item {
                width: Appearance.sizes.minTarget
                height: Appearance.sizes.minTarget
                visible: root.entry.pinned || root.hovered

                Icon {
                    anchors.centerIn: parent
                    name: "keep"
                    fill: root.entry.pinned ? 1 : 0
                    size: Appearance.font.iconSize
                    color: root.entry.pinned ? Appearance.colour.accent : pinPress.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                MouseArea {
                    id: pinPress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pinned()
                }

                HoverTip {
                    text: root.entry.pinned ? "Let go of this" : "Keep this"
                    asked: pinPress.containsMouse
                }
            }
        }
    }

    readonly property string title: {
        if (!root.isImage)
            return Clipboard.summarise(root.entry);

        if (root.entry.w > 0)
            return `${root.entry.w} × ${root.entry.h}`;
        return thumb.status === Image.Error ? "Picture (missing)" : "Picture";
    }

    readonly property string detail: {
        const parts = [];
        parts.push(root.entry.kind);
        const bytes = Clipboard.size(root.entry.bytes);
        if (bytes)
            parts.push(bytes);
        if (root.entry.kind === "files" || root.entry.kind === "audio" || root.entry.kind === "video" || root.entry.kind === "document") {
            const missing = (root.entry.mimes ?? []).filter(m => !m).length;
            if (missing)
                parts.push(missing === (root.entry.paths ?? []).length ? "gone" : `${missing} gone`);
        }
        parts.push(Clipboard.age(root.entry.recorded));
        return parts.join("  ·  ");
    }

    readonly property color swatch: {
        const t = (root.entry.text ?? "").trim();
        const hex = t.startsWith("#") ? t : `#${t}`;
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : Appearance.colour.textFaint;
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered)
                root.entered();
            else
                root.exited();
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        property real fromX: 0
        property real fromY: 0
        property bool moved: false
        property bool spent: false
        property bool held: false
        property real velocity: 0
        property real lastAt: 0
        property real lastX: 0

        onPressed: mouse => {
            press.fromX = mouse.x;
            press.fromY = mouse.y;
            press.moved = false;
            press.spent = false;
            press.held = false;
            press.velocity = 0;
            press.lastX = 0;
            press.lastAt = Date.now();
        }

        onPositionChanged: mouse => {
            if (!press.pressed || press.spent)
                return;

            const dx = mouse.x - press.fromX;
            const dy = mouse.y - press.fromY;

            if (!press.moved && Math.hypot(dx, dy) < Appearance.sizes.dragThreshold)
                return;

            if (!press.moved) {
                if (Math.abs(dx) <= Math.abs(dy)) {
                    press.spent = true;
                    return;
                }
                press.moved = true;
                root.throwing = true;
                press.preventStealing = true;
            }

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - press.lastAt));
            press.lastAt = now;
            press.velocity += ((dx - press.lastX) / dt - press.velocity) * 0.4;
            press.lastX = dx;

            root.thrown = dx;
        }

        onReleased: mouse => {
            press.preventStealing = false;

            if (!press.moved) {

                if (!press.held && !press.spent && mouse.button === Qt.LeftButton)
                    root.activated();
                press.spent = false;
                root.throwing = false;
                return;
            }

            const away = Math.sign(root.thrown) === Math.sign(press.velocity) && Math.abs(press.velocity) > Appearance.sizes.flickVelocity;
            const far = root.throwFraction >= 1 && Math.abs(press.velocity) < Appearance.sizes.pullReversal;

            if (away || far) {

                if (root.thrown < 0) {

                    root.thrown = -root.width;
                    root.discarded();
                    return;
                }

                root.throwing = false;
                root.thrown = 0;
                root.expanded();
                return;
            }

            root.throwing = false;
            root.thrown = 0;
        }

        onCanceled: {

            press.preventStealing = false;
            press.moved = false;
            press.spent = false;
            root.throwing = false;
            root.thrown = 0;
        }

        onPressAndHold: mouse => {
            press.held = true;
            root.menu(mouse.x, mouse.y);
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.menu(mouse.x, mouse.y);
        }
    }
}
