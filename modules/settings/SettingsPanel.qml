import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

FocusScope {
    id: root

    required property real originX
    required property real band

    property bool yielded: false

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property bool shown: Settings.open && Settings.screenName === root.screenName
    readonly property bool open: root.shown

    readonly property real room: root.width - root.originX - root.band
    readonly property bool narrow: root.width < 640
    readonly property real baseWidth: Math.max(0, Math.min(Appearance.sizes.settingsWidth, root.room - (root.room > 900 ? 24 : 0)))
    readonly property real baseHeight: root.narrow ? root.height - root.band * 2 : Math.min(Appearance.sizes.settingsHeight, root.height - root.band * 2 - 80)
    readonly property real tallest: root.narrow ? root.baseHeight : root.height - root.band * 2 - 48

    readonly property bool arranging: SettingsView.current === "screens"
    readonly property real spare: root.room - 24 - root.baseWidth
    readonly property bool spread: root.arranging && !root.compact && root.spare >= 320
    readonly property bool fold: root.arranging && !root.spread
    readonly property real foldHeight: Math.round(Math.max(300, Math.min(460, (root.compact ? root.baseWidth - root.railWidth - root.gutter : root.baseWidth - root.railWidth - root.paneWidth - 96) * 0.62)))

    readonly property real panelWidth: root.baseWidth + (root.spread ? Math.min(560, root.spare) : 0)
    readonly property real panelHeight: root.fold ? Math.max(root.baseHeight, Math.min(root.tallest, root.baseHeight + root.foldHeight + root.gutter)) : root.baseHeight
    readonly property real farEdge: body.x + root.panelWidth

    readonly property real liveHeight: grow.height
    readonly property real panelY: root.narrow ? root.band : Math.max(root.band + (root.fold ? 24 : 40), Math.round((root.height - root.liveHeight) / 2))

    readonly property real padding: root.tiny ? Appearance.padding.normal : Appearance.padding.large
    readonly property real gutter: root.tiny ? Appearance.padding.normal : Appearance.sizes.settingsGutter
    readonly property real railSlim: 52
    readonly property bool railFolded: root.tiny || SettingsState.railFolded
    readonly property real railWidth: root.railFolded ? root.railSlim : Appearance.sizes.settingsRail
    readonly property real paneWidth: Appearance.sizes.settingsPane

    readonly property bool compact: root.baseWidth - 48 - root.railWidth - root.paneWidth - 64 < 480
    readonly property bool tiny: root.baseWidth < 640

    readonly property var blobs: {
        const out = [];
        if (body.width > 0.5)
            out.push({
                x: body.x,
                y: body.y,
                w: body.width,
                h: body.height,
                radius: Appearance.rounding.large,
                smooth: Math.min(Appearance.sizes.melt, Math.min(body.width, body.height) / 2)
            });
        return out.concat(root.shown ? toast.blobs : []);
    }

    readonly property Item maskItem: body
    readonly property bool holdsKeys: root.shown && !root.yielded && bodyHover.hovered
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
        SettingsView.spread = root.spread;
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

    onYieldedChanged: if (!root.yielded && root.shown)
        Qt.callLater(root.forceActiveFocus)

    onCompactChanged: if (root.shown)
        root.claim()
    onTinyChanged: if (root.shown)
        root.claim()
    onSpreadChanged: if (root.shown)
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
            else if (SettingsView.paneOut && root.compact)
                SettingsView.paneOut = false;
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

        x: Appearance.bare ? root.originX + Appearance.padding.normal : root.originX
        y: root.panelY
        width: grow.width * reveal.value
        height: grow.height
        visible: width > 0.5
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        HoverHandler {
            id: bodyHover
        }

        Loader {
            id: inside

            width: grow.width
            height: parent.height
            active: root.shown || reveal.value > 0.002
            opacity: Math.min(1, reveal.value * 1.6)

            sourceComponent: Item {
                id: page

                function focusSearch(): void {
                    rail.focusSearch();
                }

                SettingsRail {
                    id: rail

                    x: root.padding
                    y: root.padding
                    width: railGrow.value
                    height: page.height - root.padding * 2
                    tiny: root.tiny || root.railFolded && railGrow.value < root.railSlim + 1
                    foldable: !root.tiny
                    folded: root.railFolded
                }

                SettingsContent {
                    id: content

                    x: rail.x + rail.width + root.gutter
                    y: root.padding
                    width: (root.compact ? page.width - root.padding : paneHolder.home - root.gutter) - x
                    height: page.height - root.padding * 2
                    compact: root.compact
                    onDetailsWanted: SettingsView.paneOut = true
                }

                Item {
                    id: paneHolder

                    readonly property real edge: Appearance.padding.large
                    readonly property real inset: Appearance.padding.card
                    readonly property real plate: root.tiny ? page.width - paneHolder.edge : Math.min(root.paneWidth, page.width * 0.7)
                    readonly property real margin: root.compact ? paneHolder.edge + paneHolder.inset : root.padding
                    readonly property real wide: root.compact ? paneHolder.plate - paneHolder.inset * 2 : root.paneWidth + page.width - root.baseWidth
                    readonly property real home: page.width - paneHolder.margin - paneHolder.wide

                    x: root.compact ? home + slide.value * (paneHolder.plate + paneHolder.edge * 2) : home
                    y: paneHolder.margin
                    width: paneHolder.wide
                    height: page.height - paneHolder.margin * 2
                    z: 4

                    Follow {
                        id: slide

                        target: root.compact && !(SettingsView.paneOut || SettingsView.pin) ? 1 : 0
                        speed: Appearance.animation.revealSpeed
                        epsilon: 0.002
                    }

                    SquircleRect {
                        anchors.fill: parent
                        anchors.margins: root.compact ? -paneHolder.inset : 0
                        visible: root.compact
                        radius: Appearance.rounding.large
                        color: Appearance.colour.surfaceSolid
                    }

                    SettingsPane {
                        anchors.fill: parent
                        compact: root.compact
                        showing: root.shown
                        covered: root.yielded
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
