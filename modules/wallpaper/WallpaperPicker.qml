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

    readonly property var shelf: root.predicted ? root.fitted : Wallpaper.available

    property string colour: ""
    property string query: ""
    property bool searching: false

    readonly property var entries: root.shelf.filter(path => root.matches(path))

    readonly property var swatches: [
        {
            name: "red",
            colour: "#e5484d"
        },
        {
            name: "orange",
            colour: "#f76b15"
        },
        {
            name: "yellow",
            colour: "#ffc53d"
        },
        {
            name: "green",
            colour: "#30a46c"
        },
        {
            name: "blue",
            colour: "#3e63dd"
        },
        {
            name: "purple",
            colour: "#8e4ec6"
        },
        {
            name: "pink",
            colour: "#d6409f"
        },
        {
            name: "black",
            colour: "#111113"
        },
        {
            name: "white",
            colour: "#eeeef0"
        }
    ]

    readonly property var offered: root.swatches.filter(swatch => root.countOf(swatch.name) > 0)

    function countOf(colour: string): int {
        return root.shelf.filter(path => Wallpaper.coloursOf(path).indexOf(colour) >= 0).length;
    }

    function titleOf(path: string): string {
        const file = Wallpaper.nameOf(path);
        const dot = file.lastIndexOf(".");
        return dot > 0 ? file.slice(0, dot) : file;
    }

    function matches(path: string): bool {
        if (root.colour && Wallpaper.coloursOf(path).indexOf(root.colour) < 0)
            return false;
        return !root.query || root.titleOf(path).toLowerCase().indexOf(root.query.toLowerCase()) >= 0;
    }

    function keepPlace(change: var): void {
        const kept = strip.currentPath;
        change();
        strip.jumpTo(Math.max(0, root.entries.indexOf(kept)));
        if (strip.currentPath !== kept)
            root.touched = true;
    }

    function pickColour(colour: string): void {
        root.keepPlace(() => {
            root.colour = root.colour === colour ? "" : colour;
        });
    }

    function startSearch(): void {
        root.searching = true;
        Qt.callLater(query.forceActiveFocus);
    }

    function stopSearch(): void {
        root.searching = false;
        query.text = "";
        if (root.shown)
            Qt.callLater(root.forceActiveFocus);
    }

    function kindWords(path: string): string {
        const kind = Wallpaper.kindOf(path);
        if (kind === "motion")
            return "animated";
        if (kind === "video")
            return "video";
        if (kind === "audio")
            return "sound only";
        return Wallpaper.isFrozen(path) ? "animated SVG, shown still" : "picture";
    }

    function detailsOf(path: string): string {
        const parts = [];
        const size = Wallpaper.sizeOf(path);
        if (size.width > 0)
            parts.push(`${size.width} x ${size.height}`);
        parts.push(root.kindWords(path));
        parts.push(`${strip.centre + 1} of ${root.entries.length}`);
        return parts.join("  ·  ");
    }

    readonly property string emptyWords: root.query ? `Nothing called "${root.query}"` : root.colour ? `No ${root.colour} wallpapers` : `Nothing in ${Wallpaper.dir}`

    readonly property real screenAspect: root.height > 0 ? root.width / root.height : 16 / 9

    readonly property real heroHeight: Math.round(root.height * 0.3)
    readonly property real heroWidth: Math.round(root.heroHeight * root.screenAspect)

    readonly property real pitch: Math.round(root.width * 0.08)

    readonly property real rowGap: Appearance.padding.large

    readonly property real dimming: 0.35
    readonly property real stripCentre: root.height - Appearance.sizes.border - Appearance.padding.huge - details.height - root.rowGap - root.heroHeight / 2

    readonly property real gap: Appearance.padding.normal
    readonly property real stripWidth: Math.round(root.width * 0.8)
    readonly property real room: Math.max(0, (root.stripWidth - root.heroWidth - root.gap) / 2)

    readonly property real farScale: 0.62

    readonly property int maxSides: 5
    readonly property int slots: Math.min(root.entries.length, 2 * root.maxSides + 2)
    readonly property real sides: Math.min(root.maxSides, root.slots / 2 - 1)

    function folded(t: real): real {
        const beyond = Math.abs(t) - 0.5;
        if (beyond <= 0 || root.sides <= 0)
            return 0;
        return 1 - Math.pow(1 - Math.min(beyond / root.sides, 1), 2);
    }

    function scaleAt(t: real): real {
        return 1 - (1 - root.farScale) * root.folded(t);
    }

    function edgeAt(t: real): real {
        const along = Math.min(Math.abs(t), 0.5) * (root.heroWidth + root.gap) + root.room * root.folded(t);
        return t < 0 ? -along : along;
    }

    function gapAt(t: real): real {
        return root.gap * root.scaleAt(t);
    }

    readonly property real panelWidth: root.width

    readonly property real riseDistance: root.height - filters.y

    readonly property Item maskItem: catcher

    readonly property var blobs: []

    property bool keyboardNavigating: false

    function stepByKey(delta: int): void {
        root.keyboardNavigating = true;
        strip.step(delta);
    }

    function show(): void {
        if (root.shown)
            return;
        root.shown = true;
        root.keyboardNavigating = false;
        root.touched = false;

        Wallpaper.refresh();

        root.settle();

        Qt.callLater(root.forceActiveFocus);
    }

    function settle(): void {
        const worn = Wallpaper.currentOn(root.screen);
        root.showAll = worn !== "" && root.fitted.indexOf(worn) < 0;

        strip.jumpTo(Math.max(0, root.entries.indexOf(worn)));
    }

    property bool touched: false
    property bool accepted: false

    function resettle(): void {
        if (root.shown && !root.touched)
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
        root.accepted = false;

        root.everywhere = false;
        root.showAll = false;
        root.colour = "";
        root.stopSearch();
    }

    Component.onDestruction: Wallpaper.clearPreview(root.screen)

    function commit(): void {
        if (!root.touched && !root.accepted) {
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
        root.accepted = true;
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

    Keys.onLeftPressed: root.stepByKey(-1)
    Keys.onRightPressed: root.stepByKey(1)

    Keys.onReturnPressed: root.accept(null)
    Keys.onEnterPressed: root.accept(null)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Slash && !root.searching) {
            root.startSearch();
            event.accepted = true;
        }
    }

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
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.dimming * root.revealed
        visible: opacity > 0
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

        Item {
            id: strip

            readonly property string currentPath: root.entries[strip.centre] ?? ""

            property real scrubSpent: 0

            property real goal: 0
            property bool placing: false

            onGoalChanged: if (!strip.placing)
                root.touched = true

            Follow {
                id: glide

                target: strip.goal
                speed: Appearance.animation.scrollSpeed

                epsilon: 0.002
            }

            function wrapped(i: int): int {
                const n = root.entries.length;
                return n ? ((i % n) + n) % n : 0;
            }

            function step(delta: int): void {

                strip.goal = Math.round(strip.goal) + delta;
            }

            function jumpTo(i: int): void {
                strip.placing = true;
                strip.goal = strip.wrapped(i);
                glide.value = strip.goal;
                strip.placing = false;
            }

            function cardAt(x: real, y: real): Item {
                for (let i = 0; i < cards.count; i++) {
                    const card = cards.itemAt(i);
                    if (card && card.visible && x >= card.x && x < card.x + card.width && y >= card.y && y < card.y + card.height)
                        return card;
                }
                return null;
            }

            readonly property int centre: strip.wrapped(Math.round(glide.value))

            y: root.stripCentre - root.heroHeight / 2
            width: parent.width
            height: root.heroHeight

            function scrub(dx: real): void {

                const steps = Math.round((-dx - strip.scrubSpent) / root.pitch);
                if (steps === 0)
                    return;

                strip.scrubSpent += steps * root.pitch;
                strip.step(steps);
            }

            function coast(vx: real): void {
                const cards = Math.round(-vx * Config.values.control.coastMs / root.pitch);
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

            onCurrentPathChanged: settle.restart()

            Timer {
                id: settle

                interval: 90

                onTriggered: {
                    if (root.open && strip.currentPath)
                        Wallpaper.setPreview(root.screen, strip.currentPath);
                }
            }

            Repeater {
                id: cards

                model: root.slots

                Item {
                    id: card

                    required property int index

                    readonly property real offset: {
                        const m = root.slots;
                        return (((card.index - glide.value + m / 2) % m) + m) % m - m / 2;
                    }
                    readonly property int entry: Math.round(glide.value + card.offset)
                    readonly property string path: root.entries[strip.wrapped(card.entry)] ?? ""

                    readonly property real leftEdge: root.edgeAt(card.offset - 0.5) + root.gapAt(card.offset - 0.5) / 2
                    readonly property real rightEdge: root.edgeAt(card.offset + 0.5) - root.gapAt(card.offset + 0.5) / 2

                    x: strip.width / 2 + card.leftEdge
                    y: (strip.height - card.height) / 2
                    width: Math.max(0, card.rightEdge - card.leftEdge)
                    height: root.heroHeight * root.scaleAt(card.offset)
                    visible: card.width >= 1

                    DropShadow {
                        anchors.fill: parent
                        radius: Math.min(Appearance.rounding.normal, card.width / 2)
                        opacity: Math.min(1, card.width / Appearance.padding.huge)
                    }

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fill
                        visible: !face.ready
                    }

                    SquircleImage {
                        id: face

                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        source: Wallpaper.faceOf(card.path)
                        fillMode: Image.PreserveAspectCrop
                        decodeWidth: root.heroWidth
                        decodeHeight: root.heroHeight
                    }

                    Button {
                        id: badge

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Appearance.padding.small

                        visible: !!root.badgeFor(card.path) && card.width >= badge.width + 2 * Appearance.padding.small
                        interactive: false
                        paint: Wallpaper.isFrozen(card.path) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                        icon: root.badgeFor(card.path)
                        iconFill: Wallpaper.isFrozen(card.path) ? 0 : 1
                    }

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        stroke: Appearance.colour.accent
                        strokeWidth: Appearance.stroke.ring * 2
                        visible: root.keyboardNavigating && card.entry === Math.round(strip.goal)
                    }
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
                root.keyboardNavigating = false;
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

                if (!swipe.dragging && Math.abs(mouse.x - swipe.fromX) < Config.values.control.dragThreshold)
                    return;
                swipe.dragging = true;

                glide.value = swipe.from - (mouse.x - swipe.fromX) / root.pitch;
                strip.goal = glide.value;
            }

            onReleased: mouse => {
                if (!swipe.dragging) {

                    const hit = strip.cardAt(mouse.x, mouse.y - strip.y);
                    if (!hit) {
                        root.hide();
                        return;
                    }
                    if (hit.entry === Math.round(glide.value))

                        root.acceptAt(swipe.mapToItem(root, mouse.x, mouse.y));
                    else
                        strip.goal = hit.entry;
                    return;
                }

                const thrown = -swipe.velocity * Config.values.control.coastMs / root.pitch;
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
                    root.keyboardNavigating = false;

                    if (scroll.feed(event))
                        return;

                    event.accepted = true;

                    const back = event.angleDelta.y > 0 || event.angleDelta.x < 0;
                    strip.step(back ? -strip.spin() : strip.spin());
                }
            }
        }

        HoverHandler {
            id: pointer

            property point resting: Qt.point(-1, -1)

            onPointChanged: {
                const at = pointer.point.position;
                if (at.x === pointer.resting.x && at.y === pointer.resting.y)
                    return;
                pointer.resting = at;
                root.keyboardNavigating = false;
            }
        }

        ScrollGesture {
            id: scroll

            onBegan: {
                root.keyboardNavigating = false;
                strip.scrubSpent = 0;
            }
            onMoved: dx => strip.scrub(dx)
            onEnded: strip.coast(scroll.vx)
        }

        Item {
            id: filters

            anchors.horizontalCenter: parent.horizontalCenter
            y: strip.y - root.rowGap - filters.height
            width: filterRow.implicitWidth + Appearance.padding.small * 2
            height: filterRow.implicitHeight + Appearance.padding.small * 2

            MouseArea {
                anchors.fill: parent
            }

            DropShadow {
                anchors.fill: parent
                radius: height / 2
            }

            SquircleRect {
                anchors.fill: parent
                radius: height / 2
                cornerPower: 2
                color: Appearance.colour.surface
            }

            Row {
                id: filterRow

                anchors.centerIn: parent
                spacing: Appearance.padding.small

                Repeater {
                    model: root.offered

                    Item {
                        id: swatch

                        required property var modelData

                        readonly property bool picked: root.colour === swatch.modelData.name

                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.button.height(0)
                        height: width

                        SquircleRect {
                            anchors.fill: parent
                            radius: width / 2
                            cornerPower: 2
                            color: "transparent"
                            stroke: Appearance.colour.text
                            strokeWidth: Appearance.stroke.ring
                            visible: swatch.picked
                        }

                        SquircleRect {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.6)
                            height: width
                            radius: width / 2
                            cornerPower: 2
                            color: swatch.modelData.colour
                            stroke: Appearance.colour.textGhost
                            strokeWidth: Appearance.stroke.line
                            scale: tap.containsMouse ? 1.15 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Appearance.animation.fast
                                }
                            }
                        }

                        MouseArea {
                            id: tap

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickColour(swatch.modelData.name)
                        }

                        FloatingTooltip {
                            text: swatch.picked ? "Show every colour" : `${swatch.modelData.name[0].toUpperCase()}${swatch.modelData.name.slice(1)} (${root.countOf(swatch.modelData.name)})`
                            shown: tap.containsMouse
                        }
                    }
                }

                Button {
                    id: searchButton

                    anchors.verticalCenter: parent.verticalCenter
                    size: 0
                    style: "text"
                    icon: "search"
                    iconFill: root.searching ? 1 : 0
                    onClicked: root.searching ? root.stopSearch() : root.startSearch()

                    FloatingTooltip {
                        text: root.searching ? "Stop searching" : "Search by name   /"
                        shown: searchButton.hovered
                    }
                }

                Item {
                    id: field

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.searching
                    width: visible ? Math.round(root.heroWidth * 0.45) : 0
                    height: Appearance.button.height(0)

                    SquircleRect {
                        anchors.fill: parent
                        radius: height / 2
                        cornerPower: 2
                        color: Appearance.colour.fill
                    }

                    TextInput {
                        id: query

                        anchors.fill: parent
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.rightMargin: Appearance.padding.normal
                        verticalAlignment: TextInput.AlignVCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        onTextChanged: root.keepPlace(() => {
                            root.query = query.text;
                        })

                        Keys.onEscapePressed: event => {
                            root.stopSearch();
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: root.forceActiveFocus()
                        Keys.onEnterPressed: root.forceActiveFocus()

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text
                            text: "Search by name"
                            color: Appearance.colour.textFaint
                        }
                    }
                }
            }
        }

        Item {
            id: details

            readonly property real inner: Appearance.padding.large + Appearance.padding.huge + Appearance.padding.small

            anchors.horizontalCenter: parent.horizontalCenter
            y: strip.y + strip.height + root.rowGap
            width: Math.min(root.stripWidth, Math.max(root.heroWidth, about.implicitWidth + actions.implicitWidth + details.inner))
            height: Math.max(about.implicitHeight, actions.implicitHeight) + Appearance.padding.small * 2

            MouseArea {
                anchors.fill: parent
            }

            DropShadow {
                anchors.fill: parent
                radius: height / 2
            }

            SquircleRect {
                anchors.fill: parent
                radius: height / 2
                cornerPower: 2
                color: Appearance.colour.surface
            }

            Row {
                id: about

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.large
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.padding.normal

                AspectMark {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!strip.currentPath
                    aspect: Wallpaper.aspectOf(strip.currentPath)
                    reference: root.screenAspect
                    fits: Wallpaper.fits(strip.currentPath, root.screenAspect)

                    size: Appearance.font.size.small * 2
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: Math.min(implicitWidth, root.stripWidth - actions.implicitWidth - details.inner - Appearance.font.size.small * 3)
                        elide: Text.ElideRight
                        text: strip.currentPath ? root.titleOf(strip.currentPath) : root.emptyWords
                        color: Appearance.colour.text
                    }

                    StyledText {
                        visible: !!strip.currentPath
                        text: strip.currentPath ? root.detailsOf(strip.currentPath) : ""
                        color: Appearance.colour.textDim
                    }
                }
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.padding.small

                Button {
                    id: shuffle

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.entries.length > 2
                    size: 0
                    style: "text"
                    icon: "shuffle"
                    onClicked: {
                        const n = root.entries.length;
                        strip.step(1 + Math.floor(Math.random() * (n - 1)));
                    }

                    FloatingTooltip {
                        text: "Jump to a random wallpaper"
                        shown: shuffle.hovered
                    }
                }

                Button {
                    id: shapes

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.fitted.length > 0 && root.fitted.length < Wallpaper.available.length
                    size: 0
                    checkable: true
                    checked: root.predicted
                    icon: "fit_screen"
                    iconFill: root.predicted ? 1 : 0
                    text: root.predicted ? "Fits this screen" : "Every shape"
                    onToggled: root.keepPlace(() => {
                        root.showAll = !root.showAll;
                    })

                    FloatingTooltip {
                        text: root.predicted ? `Only the ${root.fitted.length} shaped like this screen; click for all ${Wallpaper.available.length}` : `All ${Wallpaper.available.length}, whatever their shape; click for the ${root.fitted.length} that fit`
                        shown: shapes.hovered
                    }
                }

                Button {
                    id: scope

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.manyScreens
                    size: 0
                    checkable: true
                    checked: root.everywhere
                    icon: root.everywhere ? "devices" : "monitor"
                    iconFill: root.everywhere ? 1 : 0
                    text: root.everywhere ? "Every screen" : "This screen"
                    onToggled: root.everywhere = !root.everywhere

                    FloatingTooltip {
                        text: root.everywhere ? "Setting it on every screen; click for just this one" : "Setting it on this screen only; click for every screen"
                        shown: scope.hovered
                    }
                }

                Button {
                    id: choose

                    anchors.verticalCenter: parent.verticalCenter
                    interactive: !!strip.currentPath
                    size: 0
                    style: "filled"
                    icon: "check"
                    text: "Set"
                    onClicked: root.acceptAt(null)

                    FloatingTooltip {
                        text: "Set this wallpaper   Enter"
                        shown: choose.hovered
                    }
                }
            }
        }
    }

}
