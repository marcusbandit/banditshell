pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var launcher

    required property var modelData
    required property int index

    readonly property bool isSection: !!modelData.section
    readonly property var entry: modelData.entry
    readonly property string glyph: root.launcher.keyIcon(modelData.section)
    readonly property string folder: modelData.folder
    readonly property var folderData: root.folder ? Apps.folders[root.folder] : null
    readonly property var inside: root.folder ? Apps.folderApps(root.folder) : []

    readonly property bool actionable: !!root.entry || !!root.folder

    readonly property bool isBack: root.isSection && modelData.section === root.launcher.opened

    readonly property bool chosen: index === root.launcher.selected
    readonly property bool under: index === root.launcher.hovered
    readonly property bool away: !!entry && Apps.isHidden(entry)
    readonly property color ring: Appearance.colour.accent

    readonly property int unread: root.folder ? AppNotifications.countForAll(root.inside) : root.entry ? AppNotifications.countFor(root.entry) : 0
    readonly property var newest: root.entry ? AppNotifications.newestFor(root.entry) : null

    readonly property bool canOpen: !!root.folder
    readonly property bool canClear: root.unread > 0

    property real slide: 0
    property bool swiping: false

    readonly property real commitAt: Math.max(1, root.width * Appearance.sizes.dragDismissFraction)
    readonly property bool past: Math.abs(root.slide) >= root.commitAt

    function armed(dx: real): bool {
        return dx > 0 ? root.canOpen || root.canClear : root.canClear;
    }

    function resist(dx: real): real {
        if (!root.armed(dx))
            return 0;
        const far = Math.abs(dx);
        const over = far - root.commitAt;
        const travel = over <= 0 ? far : root.commitAt + over * Appearance.sizes.dragResistance;
        return dx < 0 ? -travel : travel;
    }

    function settleSwipe(): void {
        const acting = root.past;
        const open = root.slide > 0 && root.canOpen;
        const clear = root.canClear && !open;

        root.swiping = false;
        root.slide = 0;

        if (!acting)
            return;
        if (open)
            root.launcher.enterFolder(root.folder);
        else if (clear)
            root.clear();
    }

    function clear(): void {
        if (root.folder)
            AppNotifications.dismissForAll(root.inside);
        else
            AppNotifications.dismissFor(root.entry);
    }

    height: isSection ? root.launcher.sectionPitch : root.launcher.rowPitch

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.actionable || root.isBack

        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property bool held: false

        property real fromX: 0
        property real fromY: 0
        property bool deciding: false

        onPressed: mouse => {
            pointer.held = false;
            pointer.fromX = mouse.x;
            pointer.fromY = mouse.y;
            pointer.deciding = true;
            root.swiping = false;
        }

        preventStealing: root.swiping

        onPositionChanged: mouse => {
            if (!pointer.pressed)
                return;

            if (pointer.deciding) {
                const dx = mouse.x - pointer.fromX;
                const dy = mouse.y - pointer.fromY;
                if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                    return;

                if (Math.abs(dx) <= Math.abs(dy))
                    return;
                pointer.deciding = false;
                root.swiping = true;

                pointer.held = true;
            }

            root.slide = root.resist(mouse.x - pointer.fromX);
        }

        onReleased: root.settleSwipe()
        onCanceled: root.settleSwipe()

        onPressAndHold: mouse => {
            if (root.swiping)
                return;
            pointer.held = true;
            root.launcher.askRow(root, mouse.x, mouse.y);
        }

        onClicked: mouse => {

            if (pointer.held)
                return;

            if (mouse.button === Qt.RightButton) {
                root.launcher.askRow(root, mouse.x, mouse.y);
                return;
            }
            if (root.isBack) {
                root.launcher.leaveFolder();
                return;
            }

            root.launcher.answerHolds = false;
            root.launcher.selected = root.index;
            root.launcher.accept();
        }
    }

    HoverHandler {
        id: hover

        enabled: (root.actionable || root.isBack) && !root.launcher.asking

        onHoveredChanged: {
            if (hover.hovered)
                root.launcher.hoverRow(root.index, root.y);
            else if (root.launcher.hovered === root.index)
                root.launcher.hovered = -1;
        }
    }

    onYChanged: if (root.under)
        root.launcher.hoverY = root.y

    Item {
        id: marks

        anchors.fill: parent

        readonly property real reach: Math.min(1, Math.abs(sled.x) / root.commitAt)
        readonly property bool ready: Math.abs(sled.x) >= root.commitAt

        visible: marks.reach > 0.001

        Icon {
            id: leadMark

            anchors.left: parent.left
            anchors.leftMargin: root.launcher.gutter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: leadMark.inkOffsetY

            visible: sled.x > 0
            size: root.launcher.iconSize / 2
            name: root.canOpen ? "folder_open" : "clear_all"
            opacity: marks.reach
            color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            id: trailMark

            anchors.right: parent.right
            anchors.rightMargin: root.launcher.gutter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: trailMark.inkOffsetY

            visible: sled.x < 0
            size: root.launcher.iconSize / 2
            name: "clear_all"
            opacity: marks.reach
            color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    Item {
        id: sled

        x: root.slide
        width: root.width
        height: root.height

        Behavior on x {
            enabled: !root.swiping

            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        StyledText {
            id: heading

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: heading.inkOffsetY
            width: root.launcher.gutter

            visible: root.isSection && !root.glyph
            text: root.modelData.section
            font.pixelSize: Appearance.font.size.large
            color: root.modelData.section === root.launcher.marked ? Appearance.colour.accent : Appearance.colour.textDim

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            id: headingGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: headingGlyph.inkOffsetY
            width: root.launcher.gutter

            visible: root.isSection && !!root.glyph
            size: Appearance.font.size.large
            name: root.glyph
            color: root.isBack && root.under ? Appearance.colour.text : root.modelData.section === root.launcher.marked ? Appearance.colour.accent : Appearance.colour.textDim

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: headingLabel

            anchors.left: parent.left
            anchors.leftMargin: root.launcher.gutter
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: headingLabel.inkOffsetY

            visible: root.isBack
            text: root.launcher.openedFolder?.name ?? ""
            font.pixelSize: Appearance.font.size.large
            color: root.under ? Appearance.colour.text : Appearance.colour.textDim
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        SquircleRect {
            id: badge

            anchors.left: parent.left
            anchors.leftMargin: root.launcher.gutter
            anchors.verticalCenter: parent.verticalCenter
            width: root.launcher.iconSize
            height: width

            radius: width / 2

            visible: !root.isSection

            color: art.visible ? "transparent" : root.under ? Appearance.colour.fillStrong : Appearance.colour.fill

            stroke: root.chosen ? root.ring : Qt.rgba(root.ring.r, root.ring.g, root.ring.b, 0)
            strokeWidth: 2

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Behavior on stroke {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Image {
                id: art

                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                source: root.entry?.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
            }

            Item {
                id: stack

                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                visible: !!root.folder

                readonly property var shown: root.inside.slice(0, 4)
                readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(stack.shown.length)))
                readonly property int lines: Math.max(1, Math.ceil(stack.shown.length / stack.cols))
                readonly property real cell: stack.width / stack.cols
                readonly property real gridY: (stack.height - stack.cell * stack.lines) / 2

                Repeater {
                    model: stack.shown

                    delegate: Image {
                        required property var modelData
                        required property int index

                        x: (index % stack.cols) * stack.cell
                        y: stack.gridY + Math.floor(index / stack.cols) * stack.cell
                        width: stack.cell
                        height: stack.cell

                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: height * Screen.devicePixelRatio
                    }
                }
            }

            Icon {
                id: fallbackGlyph

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: fallbackGlyph.inkOffsetX
                anchors.verticalCenterOffset: fallbackGlyph.inkOffsetY

                visible: root.folder ? stack.shown.length === 0 : !art.visible
                size: root.launcher.iconSize / 2
                name: root.folder ? "folder" : "apps"
                color: Appearance.colour.textDim
            }

            SquircleRect {
                id: unread

                x: badge.width - width * 0.78
                y: -height * 0.22
                width: root.launcher.iconSize * 0.46
                height: width
                radius: width / 2

                visible: root.unread > 0
                color: Appearance.colour.accent

                StyledText {
                    id: unreadCount

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: unreadCount.inkOffsetX
                    anchors.verticalCenterOffset: unreadCount.inkOffsetY

                    text: root.unread > 9 ? "9+" : `${root.unread}`
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.accentText
                }
            }
        }

        StyledText {
            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.large

            anchors.right: notice.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.isSection
            text: root.folder ? (root.folderData?.name ?? "") : (root.entry?.name ?? "")
            font.pixelSize: Appearance.font.size.normal
            color: root.chosen || root.under ? Appearance.colour.text : Appearance.colour.textDim
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: notice

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter

            width: notice.visible ? Math.min(noticeInk.width, root.width * 0.34) : 0
            horizontalAlignment: Text.AlignRight

            visible: !root.isSection && !root.folder && !!root.newest
            text: root.newest?.summary ?? ""
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            elide: Text.ElideRight

            TextMetrics {
                id: noticeInk

                font: notice.font
                text: notice.text
            }
        }
    }
}
