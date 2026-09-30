pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string screen

    readonly property bool open: shown
    property bool shown: false

    readonly property var fitted: Wallpaper.fittedFor(root.screenAspect)

    property bool showAll: false

    readonly property bool predicted: !root.showAll && root.fitted.length > 0

    readonly property var entries: root.predicted ? root.fitted : Wallpaper.available

    readonly property real screenAspect: root.height > 0 ? root.width / root.height : 16 / 9

    readonly property real heroHeight: Math.round(root.height * 0.5)
    readonly property real heroWidth: Math.round(root.heroHeight * root.screenAspect)

    readonly property real pitch: Math.round(root.heroWidth * 0.16)

    readonly property real nearScale: 0.92
    readonly property real farScale: 0.62

    readonly property real span: root.width + root.heroWidth * root.farScale + root.pitch

    readonly property int slots: Math.max(1, Math.min(root.entries.length - 1, Math.max(3, Math.round(root.span / root.pitch))))

    readonly property real panelWidth: root.width

    readonly property real riseDistance: root.height / 2 + root.heroHeight / 2 + Appearance.padding.large + caption.implicitHeight

    readonly property Item maskItem: catcher

    readonly property var blobs: []

    function show(): void {
        if (root.shown)
            return;
        root.shown = true;

        Wallpaper.refresh();

        root.settle();

        Qt.callLater(root.forceActiveFocus);
    }

    function settle(): void {
        const worn = Wallpaper.currentOn(root.screen);
        root.showAll = worn !== "" && root.fitted.indexOf(worn) < 0;

        strip.jumpTo(Math.max(0, root.entries.indexOf(worn)));
        root.settled = strip.goal;
    }

    property real settled: -1

    function resettle(): void {
        if (root.shown && strip.goal === root.settled)
            root.settle();
    }

    Connections {
        target: Wallpaper

        function onAvailableChanged(): void {
            root.resettle();
        }

        function onShapesChanged(): void {
            root.resettle();
        }
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.commit();
        root.shown = false;
        root.chosenAt = null;

        root.everywhere = false;
        root.showAll = false;
    }

    function commit(): void {
        if (strip.goal === root.settled) {
            Wallpaper.clearPreview(root.screen);
            return;
        }

        const path = strip.currentPath;
        const all = root.everywhere && root.manyScreens;
        if (!path || (!all && path === Wallpaper.currentOn(root.screen))) {
            Wallpaper.clearPreview(root.screen);
            return;
        }

        const at = root.chosenAt;
        const x = at ? at.x / Math.max(1, root.width) : 0.5;
        const y = at ? at.y / Math.max(1, root.height) : 0.5;

        if (all)
            Wallpaper.setFromAll(path, x, y);
        else
            Wallpaper.setFrom(root.screen, path, x, y);
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function accept(from: var): void {
        root.acceptAt(from);
    }

    property bool everywhere: false

    readonly property bool manyScreens: Quickshell.screens.length > 1

    property var chosenAt: null

    function acceptAt(at: var): void {
        root.chosenAt = at;
        root.hide();
    }

    function badgeFor(path: string): string {
        const k = Wallpaper.kindOf(path);
        if (k === "motion")
            return "gif";
        if (k === "video")
            return "movie";
        if (k === "audio")
            return "music_note";
        return Wallpaper.isFrozen(path) ? "motion_photos_off" : "";
    }

    Keys.onLeftPressed: strip.step(-1)
    Keys.onRightPressed: strip.step(1)

    Keys.onReturnPressed: root.accept(null)
    Keys.onEnterPressed: root.accept(null)

    property bool dragging: false
    property real dragProgress: 0

    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        rise.value = root.dragProgress;
        if (open)
            root.show();
        else
            root.hide();
        root.dragProgress = 0;
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Item {
        id: body

        width: root.width
        height: root.height
        y: (1 - root.revealed) * root.riseDistance
        visible: root.revealed > 0.001

        PathView {
            id: strip

            readonly property string currentPath: root.entries[strip.centre] ?? ""

            property real scrubSpent: 0

            property real goal: 0

            Follow {
                id: glide

                target: strip.goal
                speed: Appearance.anim.scrollSpeed

                epsilon: 0.002
            }

            function wrapped(i: int): int {
                const n = root.entries.length;
                return n ? ((i % n) + n) % n : 0;
            }

            function wrapReal(x: real): real {
                const n = root.entries.length;
                return n ? ((x % n) + n) % n : 0;
            }

            function shortest(i: int): int {
                const n = root.entries.length;
                if (!n)
                    return 0;
                let d = strip.wrapped(i - strip.centre);
                return d > n / 2 ? d - n : d;
            }

            function step(delta: int): void {

                strip.goal = Math.round(strip.goal) + delta;
            }

            function jumpTo(i: int): void {
                strip.goal = strip.wrapped(i);
                glide.value = strip.goal;
            }

            function place(): void {
                strip.offset = strip.wrapReal(root.slots / 2 - glide.value);
            }

            Connections {
                target: glide

                function onValueChanged(): void {
                    strip.place();
                }
            }

            Connections {
                target: root

                function onSlotsChanged(): void {
                    strip.place();
                }
            }

            Component.onCompleted: strip.place()

            readonly property int centre: strip.wrapped(Math.round(glide.value))

            anchors.fill: parent

            model: root.entries
            pathItemCount: root.slots

            highlightRangeMode: PathView.NoHighlightRange
            snapMode: PathView.NoSnap
            interactive: false

            function scrub(dx: real): void {

                const steps = Math.round((-dx - strip.scrubSpent) / root.pitch);
                if (steps === 0)
                    return;

                strip.scrubSpent += steps * root.pitch;
                strip.step(steps);
            }

            function coast(vx: real): void {
                const cards = Math.round(-vx * Appearance.sizes.coastMs / root.pitch);
                if (cards)
                    strip.step(cards);
            }

            property real lastNotch: 0
            property int notchStep: 1

            function spin(): int {
                const now = Date.now();
                const gap = now - strip.lastNotch;
                strip.lastNotch = now;

                strip.notchStep = gap < 120 ? Math.min(5, strip.notchStep + 1) : 1;
                return strip.notchStep;
            }

            cacheItemCount: Math.max(0, Math.min(root.entries.length, 40) - root.slots)

            path: Path {
                id: line

                readonly property real span: root.slots * root.pitch
                readonly property real cy: strip.height / 2
                readonly property real cx: strip.width / 2

                startX: line.cx - line.span / 2
                startY: line.cy

                PathAttribute {
                    name: "cardScale"
                    value: root.farScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }

                PathLine {
                    x: line.cx - root.pitch
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.nearScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 1
                }

                PathLine {
                    x: line.cx
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: 1
                }
                PathAttribute {
                    name: "cardZ"
                    value: 2
                }

                PathLine {
                    x: line.cx + root.pitch
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.nearScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 1
                }

                PathLine {
                    x: line.cx + line.span / 2
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.farScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }
            }

            onCurrentPathChanged: settle.restart()

            Timer {
                id: settle

                interval: 90

                onTriggered: {
                    if (root.open && strip.currentPath)
                        Wallpaper.setPreview(root.screen, strip.currentPath);
                }
            }

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool centred: card.index === strip.centre

                width: root.heroWidth
                height: root.heroHeight

                scale: card.PathView.cardScale ?? root.farScale
                z: card.PathView.cardZ ?? 0

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                }

                SquircleImage {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Wallpaper.faceOf(card.modelData)
                    fillMode: Image.PreserveAspectCrop
                }

                Button {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.padding.small

                    visible: !!root.badgeFor(card.modelData)
                    interactive: false
                    paint: Wallpaper.isFrozen(card.modelData) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                    icon: root.badgeFor(card.modelData)
                    iconFill: Wallpaper.isFrozen(card.modelData) ? 0 : 1
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    stroke: Appearance.colour.accent
                    strokeWidth: Appearance.font.stem * 2
                    visible: card.modelData === Wallpaper.currentOn(root.screen)
                }

            }
        }

        MouseArea {
            id: swipe

            anchors.fill: parent
            enabled: root.open
            cursorShape: Qt.PointingHandCursor

            property real from: 0
            property real fromX: 0
            property bool dragging: false

            property real velocity: 0
            property real lastX: 0
            property real lastAt: 0

            onPressed: mouse => {
                swipe.from = glide.value;
                swipe.fromX = mouse.x;
                swipe.lastX = mouse.x;
                swipe.lastAt = Date.now();
                swipe.velocity = 0;
                swipe.dragging = false;
            }

            onPositionChanged: mouse => {
                if (!swipe.pressed)
                    return;

                const now = Date.now();
                const dt = Math.max(1, now - swipe.lastAt);
                swipe.velocity += ((mouse.x - swipe.lastX) / dt - swipe.velocity) * 0.4;
                swipe.lastX = mouse.x;
                swipe.lastAt = now;

                if (!swipe.dragging && Math.abs(mouse.x - swipe.fromX) < Appearance.sizes.dragThreshold)
                    return;
                swipe.dragging = true;

                glide.value = swipe.from - (mouse.x - swipe.fromX) / root.pitch;
                strip.goal = glide.value;
            }

            onReleased: mouse => {
                if (!swipe.dragging) {

                    const i = strip.indexAt(mouse.x, mouse.y);
                    if (i < 0) {
                        root.hide();
                        return;
                    }
                    if (i === strip.centre)

                        root.acceptAt(swipe.mapToItem(root, mouse.x, mouse.y));
                    else
                        strip.step(strip.shortest(i));
                    return;
                }

                const thrown = -swipe.velocity * Appearance.sizes.coastMs / root.pitch;
                strip.goal = Math.round(glide.value + thrown);
                swipe.dragging = false;
            }

            onCanceled: {
                if (swipe.dragging)
                    strip.goal = Math.round(glide.value);
                swipe.dragging = false;
            }

            WheelHandler {
                onWheel: event => {

                    if (scroll.feed(event))
                        return;

                    event.accepted = true;

                    const back = event.angleDelta.y > 0 || event.angleDelta.x < 0;
                    strip.step(back ? -strip.spin() : strip.spin());
                }
            }
        }

        ScrollGesture {
            id: scroll

            onBegan: strip.scrubSpent = 0
            onMoved: dx => strip.scrub(dx)
            onEnded: strip.coast(scroll.vx)
        }

        Row {
            id: caption

            anchors.horizontalCenter: parent.horizontalCenter
            y: strip.height / 2 + root.heroHeight / 2 + Appearance.padding.large
            spacing: Appearance.padding.normal

            AspectMark {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!strip.currentPath
                aspect: Wallpaper.aspectOf(strip.currentPath)
                reference: root.screenAspect
                fits: Wallpaper.fits(strip.currentPath, root.screenAspect)

                size: Appearance.font.size.small * 2
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.currentPath ? strip.currentPath.split("/").pop() : `nothing in ${Wallpaper.dir}`
                color: Appearance.colour.text
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.manyScreens
                icon: root.everywhere ? "devices" : "monitor"
                iconFill: root.everywhere ? 1 : 0
                paint: root.everywhere ? Appearance.colour.accentFill : Appearance.colour.fillStrong
                onClicked: root.everywhere = !root.everywhere
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.fitted.length > 0 && root.fitted.length < Wallpaper.available.length
                icon: root.predicted ? "fit_screen" : "photo_library"
                iconFill: root.predicted ? 1 : 0
                paint: root.predicted ? Appearance.colour.accentFill : Appearance.colour.fillStrong
                onClicked: root.showAll = !root.showAll
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.badgeFor(strip.currentPath)
                interactive: false
                paint: Wallpaper.isFrozen(strip.currentPath) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                icon: root.badgeFor(strip.currentPath)
                iconFill: Wallpaper.isFrozen(strip.currentPath) ? 0 : 1
            }
        }
    }

}
