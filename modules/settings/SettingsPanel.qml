import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import "floating.js" as Floating

FocusScope {
    id: root

    required property real originX
    required property real band

    property bool yielded: false

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property bool shown: Settings.open && Settings.screenName === root.screenName
    readonly property bool open: root.shown

    readonly property real margin: Appearance.padding.large
    readonly property var room: ({
            x: root.originX + root.margin,
            y: root.band + root.margin,
            w: Math.max(0, root.width - root.originX - root.band - root.margin * 2),
            h: Math.max(0, root.height - root.band * 2 - root.margin * 2)
        })
    readonly property bool narrow: root.width < 640
    readonly property real wantedWidth: Appearance.sizes.settingsWidth
    property real settledWidth: Appearance.sizes.settingsWidth
    readonly property real baseWidth: Math.max(0, Math.min(root.settledWidth, root.room.w))
    readonly property real baseHeight: root.narrow ? root.room.h : Math.min(Appearance.sizes.settingsHeight, root.room.h)

    readonly property bool arranging: SettingsView.current === "screens"
    readonly property bool fold: root.arranging
    readonly property real contentWidth: root.baseWidth - root.padding * 2 - root.railRest - root.gutter
    readonly property real foldHeight: Math.round(Math.max(300, Math.min(460, root.contentWidth * 0.5)))

    readonly property real panelWidth: root.baseWidth
    readonly property real panelHeight: root.fold ? Math.max(root.baseHeight, Math.min(root.room.h, root.baseHeight + root.foldHeight / 2)) : root.baseHeight

    readonly property real padding: root.tiny ? Appearance.padding.normal : Appearance.padding.large
    readonly property real gutter: root.tiny ? Appearance.padding.normal : Appearance.sizes.settingsGutter
    readonly property real railSlim: 52
    readonly property bool railFolded: root.tiny || SettingsState.railFolded
    readonly property bool searchOpen: root.railFolded && SettingsView.searching
    readonly property real railFull: Math.min(Appearance.sizes.settingsRail, root.baseWidth - root.padding * 2)
    readonly property real railRest: root.railFolded ? root.railSlim : root.railFull
    readonly property real railWidth: root.railFolded && !root.searchOpen ? root.railSlim : root.railFull
    readonly property real paneWidth: Appearance.sizes.settingsPane

    readonly property bool tiny: root.baseWidth < 640
    readonly property bool compact: root.contentWidth < 560

    property var dragSpot: null
    readonly property var spot: root.dragSpot ?? SettingsState.spot
    readonly property var at: root.narrow ? {
        x: root.room.x,
        y: root.room.y
    } : Floating.place(root.room, grow.width, grow.height, root.spot, root.baseHeight)
    readonly property real farEdge: root.at.x + root.panelWidth

    readonly property var blobs: {
        const out = [];
        if (body.width > 0.5)
            out.push({
                x: body.x,
                y: body.y,
                w: body.width,
                h: body.height,
                radius: Math.min(Appearance.rounding.large, Math.min(body.width, body.height) / 2),
                smooth: Math.min(Appearance.sizes.melt, Math.min(body.width, body.height) / 2)
            });
        return out.concat(root.shown ? toast.blobs : []);
    }

    readonly property Item maskItem: body
    readonly property bool holdsKeys: root.shown && !root.yielded && (bodyHover.hovered || move.active)
    readonly property Item toastMask: toast.maskItem

    function show(): void {
        Settings.show(root.screenName, "");
    }

    function hide(): void {
        if (root.shown)
            Settings.hide();
    }

    function toggle(): void {
        Settings.toggle(root.screenName);
    }

    function claim(): void {
        SettingsView.compact = root.compact;
        SettingsView.tiny = root.tiny;
        SettingsView.fold = root.fold;
        SettingsView.foldHeight = root.foldHeight;
    }

    onShownChanged: {
        if (root.shown) {
            root.claim();
            grow.snap();
            railGrow.snap();
            SettingsState.wake();
            Qt.callLater(root.forceActiveFocus);
        } else {
            root.focus = false;
            SettingsView.unpin();
            SettingsView.query = "";
            SettingsState.closed();
        }
    }

    onWantedWidthChanged: if (!SettingsView.sliding)
        root.settledWidth = root.wantedWidth

    Connections {
        target: SettingsView

        function onSlidingChanged(): void {
            if (!SettingsView.sliding)
                root.settledWidth = root.wantedWidth;
        }
    }

    onYieldedChanged: if (!root.yielded && root.shown)
        Qt.callLater(root.forceActiveFocus)

    onCompactChanged: if (root.shown)
        root.claim()
    onTinyChanged: if (root.shown)
        root.claim()
    onFoldChanged: if (root.shown)
        root.claim()
    onFoldHeightChanged: if (root.shown)
        root.claim()
    Component.onCompleted: {
        if (root.shown) {
            root.claim();
            grow.snap();
            railGrow.snap();
            SettingsState.wake();
            Qt.callLater(root.forceActiveFocus);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Appearance.instantly();
            if (SettingsView.pin)
                SettingsView.unpin();
            else if (SettingsView.query)
                SettingsView.query = "";
            else
                root.hide();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
            inside.item?.focusSearch();
            event.accepted = true;
        }
    }

    Follow {
        id: reveal

        target: root.shown && !root.yielded ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
    }

    Follow {
        id: railGrow

        target: root.railWidth
        speed: Appearance.animation.revealSpeed
        epsilon: 0.5
    }

    QtObject {
        id: grow

        readonly property real width: wide.value
        readonly property real height: tall.value

        function snap(): void {
            wide.snap();
            tall.snap();
        }
    }

    Follow {
        id: wide

        target: root.panelWidth
        speed: Appearance.animation.revealSpeed
        epsilon: 0.5
    }

    Follow {
        id: tall

        target: root.panelHeight
        speed: Appearance.animation.revealSpeed
        epsilon: 0.5
    }

    Item {
        id: body

        x: root.at.x + grow.width * (1 - reveal.value) / 2
        y: root.at.y + grow.height * (1 - reveal.value) / 2
        width: grow.width * reveal.value
        height: grow.height * reveal.value
        visible: width > 0.5
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        HoverHandler {
            id: bodyHover
        }

        Item {
            id: grip

            width: parent.width
            height: root.padding + 52
            enabled: !root.narrow

            DragHandler {
                id: move

                property var start: null

                target: null
                cursorShape: Qt.ClosedHandCursor

                onActiveChanged: {
                    if (move.active) {
                        move.start = Floating.drawn(root.room, grow.width, grow.height, SettingsState.spot, root.baseHeight);
                        return;
                    }
                    if (root.dragSpot)
                        SettingsState.place(root.dragSpot);
                    root.dragSpot = null;
                }

                onCentroidChanged: if (move.active)
                    root.dragSpot = Floating.dragged(root.room, grow.width, grow.height, move.start, move.centroid.scenePosition.x - move.centroid.scenePressPosition.x, move.centroid.scenePosition.y - move.centroid.scenePressPosition.y, root.baseHeight)
            }

            TapHandler {
                onDoubleTapped: SettingsState.place(null)
            }

            HoverHandler {
                id: gripHover
            }

            SquircleRect {
                x: (body.width - width) / 2
                y: Math.round((root.padding - height) / 2)
                width: 44
                height: 4
                pill: "place"
                color: handleTone.value
                visible: !root.narrow

                FollowColour {
                    id: handleTone

                    target: move.active || gripHover.hovered ? Appearance.colour.textDim : Appearance.colour.textGhost
                    speed: Appearance.animation.revealSpeed
                }
            }
        }

        Loader {
            id: inside

            x: (body.width - grow.width) / 2
            y: (body.height - grow.height) / 2
            width: grow.width
            height: grow.height
            active: root.shown || reveal.value > 0.002
            opacity: Math.max(0, Math.min(1, (reveal.value - 0.35) / 0.5))

            sourceComponent: Item {
                id: page

                function focusSearch(): void {
                    rail.focusSearch();
                }

                SquircleRect {
                    x: rail.x - Appearance.padding.small
                    y: rail.y - Appearance.padding.small
                    width: rail.width + Appearance.padding.small * 2
                    height: rail.height + Appearance.padding.small * 2
                    z: 3
                    radius: Appearance.rounding.large
                    color: Appearance.colour.surfaceSolid
                    visible: root.tiny && rail.width > root.railSlim + 1
                }

                SettingsRail {
                    id: rail

                    readonly property real held: root.tiny ? Math.min(root.railSlim, width) : width

                    x: root.padding
                    y: root.padding
                    z: 4
                    width: railGrow.value
                    height: page.height - root.padding * 2
                    tiny: railGrow.value < root.railSlim + 1
                    foldable: !root.tiny
                    folded: root.railFolded
                }

                Rectangle {
                    x: rail.x + rail.held + Math.round(root.gutter / 2)
                    y: root.padding
                    width: 1
                    height: page.height - root.padding * 2
                    color: Appearance.colour.separator
                }

                SettingsContent {
                    id: content

                    x: rail.x + rail.held + root.gutter
                    y: root.padding
                    width: page.width - root.padding - x
                    height: page.height - root.padding * 2
                    trailRoom: close.width + Appearance.padding.normal
                    covered: root.yielded || !!SettingsView.pin
                    showing: root.shown
                }

                SettingsTool {
                    id: close

                    x: page.width - root.padding - width + Appearance.padding.small
                    y: root.padding - Appearance.padding.small
                    z: 5
                    icon: "close"
                    tip: "close settings"
                    onClicked: Settings.hide()
                }

                Item {
                    id: paneHolder

                    readonly property real inset: Appearance.padding.card
                    readonly property real plate: root.tiny ? page.width - root.padding * 2 : Math.min(root.paneWidth, content.width * 0.8)

                    x: page.width - root.padding - paneHolder.plate + slide.value * (paneHolder.plate + root.padding + paneHolder.inset * 2)
                    y: root.padding
                    width: paneHolder.plate
                    height: page.height - root.padding * 2
                    z: 6
                    visible: slide.value < 0.999

                    Follow {
                        id: slide

                        target: SettingsView.pin ? 0 : 1
                        speed: Appearance.animation.revealSpeed
                        epsilon: 0.002
                        startsAtTarget: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -paneHolder.inset
                    }

                    SquircleRect {
                        anchors.fill: parent
                        anchors.margins: -paneHolder.inset
                        radius: Appearance.rounding.large
                        color: Appearance.colour.surfaceSolid
                        stroke: Appearance.colour.separator
                        strokeWidth: 1
                    }

                    SettingsPane {
                        anchors.fill: parent
                    }
                }
            }
        }
    }

    SettingsToast {
        id: toast

        anchors.fill: parent
        band: root.band
        visible: root.shown
    }
}
