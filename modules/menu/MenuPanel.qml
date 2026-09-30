pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string title: ""
    property Component body: null

    property string key: ""

    property var warm: []

    readonly property int spare: 2

    readonly property var pageModel: {
        const list = [];
        for (let i = 0; i < root.spare; i++)
            list.push({});
        return list.concat(root.warm);
    }

    function pageFor(key: string): int {
        for (let i = 0; i < root.warm.length; i++)
            if (root.warm[i].key === key)
                return root.spare + i;
        return root.slot < root.spare ? (root.slot + 1) % root.spare : 0;
    }

    property real reveal: 0

    readonly property real fullWidth: Appearance.sizes.menuWidth
    readonly property real cornerRadius: Appearance.rounding.large

    property real available: Appearance.sizes.menuMaxHeight

    property int slot: 0
    property int prevSlot: -1

    property real pageHeight: 0

    property bool unsized: false

    implicitWidth: fullWidth
    implicitHeight: Math.max(Appearance.sizes.menuMinHeight, Math.min(Math.min(Appearance.sizes.menuMaxHeight, available), pageHeight + Appearance.padding.large * 2))

    width: fullWidth * reveal
    height: grow.value
    visible: reveal > 0

    onImplicitHeightChanged: if (root.unsized) {
        root.unsized = false;
        grow.value = root.implicitHeight;
    }

    onRevealChanged: if (root.reveal === 1)
        root.unsized = false

    onBodyChanged: root.swap()

    function swap(): void {
        const next = root.pageFor(root.key);
        const page = pages.itemAt(next);
        if (page) {
            page.pageTitle = root.title;

            if (!page.warm) {
                page.pageBody = null;
                page.pageBody = root.body;
            }
        }

        const closed = root.reveal === 0;
        fade.value = closed ? 1 : 0;
        fade.target = 1;
        root.unsized = closed;
        root.prevSlot = root.slot;
        root.slot = next;
    }

    Follow {
        id: grow

        target: root.implicitHeight
        speed: Appearance.anim.resizeSpeed
    }

    Follow {
        id: fade

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Item {
        anchors.fill: parent
        clip: true

        Repeater {
            id: pages

            model: root.pageModel

            delegate: Item {
                id: page

                required property int index
                required property var modelData

                readonly property bool warm: !!page.modelData.body

                property string pageTitle: ""

                property Component pageBody: page.modelData.body ?? null

                readonly property bool current: index === root.slot

                readonly property bool leaving: index === root.prevSlot && !fade.settled

                readonly property bool live: root.reveal > 0 && (page.current || page.leaving)

                property bool believed: false

                onLiveChanged: settle.restart()

                Timer {
                    id: settle

                    interval: Appearance.anim.settle
                    onTriggered: page.believed = page.live
                }

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.fullWidth - Appearance.padding.large * 2

                implicitHeight: view.y + view.contentHeight

                opacity: current ? 1 : leaving ? (1 - fade.value) * (1 - fade.value) : 0

                visible: opacity > 0

                z: current ? 1 : 0

                onImplicitHeightChanged: if (current)
                    root.pageHeight = implicitHeight

                onCurrentChanged: if (current) {

                    if (bodyLoader.status === Loader.Loading)
                        bodyLoader.forceCompletion();
                    root.pageHeight = implicitHeight;

                    view.contentY = 0;
                }

                onPageBodyChanged: view.contentY = 0

                StyledText {
                    id: heading

                    text: page.pageTitle.toUpperCase()
                    color: Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                }

                Separator {
                    id: rule

                    y: heading.height + Appearance.padding.normal
                    width: page.width
                }

                Flickable {
                    id: view

                    readonly property real overflowSlack: 0.5

                    y: rule.y + rule.height + Appearance.padding.normal
                    width: page.width

                    height: Math.max(0, root.implicitHeight - Appearance.padding.large * 2 - y)

                    contentHeight: bodyLoader.height

                    interactive: page.current && contentHeight > height + overflowSlack

                    clip: contentHeight > height + overflowSlack

                    boundsBehavior: Flickable.StopAtBounds

                    onContentHeightChanged: if (!dragging)
                        returnToBounds()
                    onHeightChanged: if (!dragging)
                        returnToBounds()

                    Loader {
                        id: bodyLoader

                        width: page.width
                        active: page.warm || page.live

                        asynchronous: page.warm
                        sourceComponent: page.pageBody

                        onLoaded: {
                            item.width = Qt.binding(() => page.width);
                            if (item.showing !== undefined)
                                item.showing = Qt.binding(() => page.believed);
                        }
                    }
                }
            }
        }
    }
}
