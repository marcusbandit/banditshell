pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.components.blob
import qs.modules.media
import qs.services

Item {
    id: root

    property int border: Appearance.sizes.border

    property real edge: root.border

    property bool keyboardHeld: false

    signal chosen(var activity)

    readonly property var host: QsWindow.window?.screen ?? null
    readonly property string screenName: root.host?.name ?? ""

    readonly property bool focused: !root.screenName || !Hypr.focusedScreen || root.screenName === Hypr.focusedScreen
    readonly property bool offStage: !root.screenName || !Shell.offStageScreen || root.screenName === Shell.offStageScreen

    readonly property bool notifies: Config.values.notifications.placement === "island"

    readonly property int launchMax: 3

    readonly property var activities: {
        const out = [];
        if (root.focused && Dictation.live)
            out.push({
                key: "dictation",
                kind: "dictation"
            });
        if (root.focused)
            for (const rec of Launching.shown.slice(-root.launchMax).reverse())
                out.push({
                    key: `launch:${rec.id}`,
                    kind: "launch",
                    name: rec.name,
                    mark: rec.mark,
                    state: rec.state,
                    rec: rec
                });
        if (root.offStage)
            out.push(...Notices.fresh);
        return out;
    }

    readonly property var alert: root.notifies && root.offStage ? (Notifications.popups.find(e => !e.leaving) ?? null) : null

    readonly property var overviewRows: [...root.activities.filter(a => a.kind !== "music"), ...(root.offStage ? Notices.settled : []), ...(Notifications.count > 0 ? [
                {
                    key: "notifications",
                    kind: "notifications",
                    count: Notifications.count
                }
            ] : [])]

    property bool pinned: false
    property bool pulling: false
    property real pullProgress: 0

    readonly property bool hovering: stripHover.hovered || islandHover.hovered
    property bool dwelt: false
    property bool spent: false

    onHoveringChanged: if (!root.hovering)
        root.spent = false

    readonly property bool expanded: root.pinned || (root.dwelt && !root.alert)
    readonly property real openness: root.pulling ? root.pullProgress : root.expanded ? 1 : 0

    readonly property string base: root.alert ? "alert" : root.activities.length > 0 ? "compact" : "hidden"
    readonly property string presentation: root.openness > 0.5 ? "overview" : root.base

    readonly property var lead: root.activities[0] ?? null
    readonly property var second: root.base === "alert" ? (root.activities[0] ?? null) : root.base === "compact" ? (root.activities[1] ?? null) : null

    readonly property bool out: root.base !== "hidden" || root.openness > 0

    readonly property bool attending: root.hovering || root.openness > 0

    readonly property bool wantsEscape: root.pinned

    readonly property Item grabItem: zone

    function pressable(kind: string): bool {
        return ["music", "download", "update", "kernel", "restart"].includes(kind);
    }

    readonly property bool interactive: presence.value > 0.5 && (root.openness > 0 || root.base === "alert" || root.pressable(root.lead?.kind ?? "") || root.pressable(root.second?.kind ?? ""))

    readonly property real compactHeight: Appearance.font.line.small + Appearance.padding.small * 2
    readonly property real largeWidth: Config.values.island.width
    readonly property real cornerMax: Appearance.rounding.large * 1.5
    readonly property real islandTop: root.edge + Appearance.padding.small
    readonly property real budGap: Appearance.padding.normal
    readonly property real shadowRoom: Appearance.padding.huge * 2

    readonly property real lift: alertView.lift

    readonly property real baseWidth: root.base === "alert" ? root.largeWidth + (root.compactHeight - root.largeWidth) * root.lift : root.base === "compact" ? measure.implicitWidth : root.compactHeight
    readonly property real baseHeight: root.base === "alert" ? alertView.implicitHeight + (root.compactHeight - alertView.implicitHeight) * root.lift : root.compactHeight

    readonly property real targetWidth: root.baseWidth + (root.largeWidth - root.baseWidth) * root.openness
    readonly property real targetHeight: root.baseHeight + (overview.implicitHeight - root.baseHeight) * root.openness

    readonly property real fieldWidth: Math.ceil(root.largeWidth * 1.2 + (root.compactHeight + root.budGap + root.shadowRoom) * 2)
    readonly property real fieldHeight: Math.ceil(root.islandTop + Math.max(root.compactHeight, overview.implicitHeight, alertView.implicitHeight) + root.shadowRoom)
    readonly property real centreX: surface.width / 2

    readonly property real pillWidth: wide.value
    readonly property real pillHeight: tall.value
    readonly property real pillX: root.centreX - root.pillWidth / 2
    readonly property real tuckedY: root.edge - root.pillHeight - Appearance.padding.small
    readonly property real pillY: root.tuckedY + (root.islandTop - root.tuckedY) * presence.value
    readonly property real neck: Appearance.sizes.melt * (1 - settle.value)
    readonly property real pillRadius: Math.min(root.pillHeight / 2, root.cornerMax)
    readonly property real pillPower: 2 + (Appearance.rounding.power - 2) * Math.max(0, Math.min(1, (root.pillHeight / 2 - root.cornerMax) / root.cornerMax))

    readonly property real budSize: root.compactHeight * (0.6 + 0.4 * bud.value)
    readonly property real budX: root.pillX + root.pillWidth - root.budSize + (root.budSize + root.budGap) * bud.value
    readonly property real budY: root.pillY + (root.compactHeight - root.budSize) / 2

    property var shownLead: null
    property var shownSecond: null
    property var shownAlert: null

    function swapLead(): void {
        if (!root.lead)
            return;
        if (!root.shownLead || root.shownLead.key === root.lead.key || compactFade.value < 0.01) {
            root.shownLead = root.lead;
            swap.target = 1;
            return;
        }
        swap.target = 0;
    }

    function close(): void {
        root.pinned = false;
        root.dwelt = false;
        root.spent = root.hovering;
    }

    function dragTo(fraction: real): void {
        root.pulling = true;
        root.pullProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        if (!root.pulling)
            return;
        root.pulling = false;
        root.pullProgress = 0;
        root.pinned = open;
        if (!open)
            root.dwelt = false;
    }

    function claimKeys(): void {
        if (root.wantsEscape && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    property bool holdingLyrics: false

    readonly property bool wantsLyrics: overviewFade.target > 0 && Media.hasTrack

    onWantsLyricsChanged: {
        if (root.wantsLyrics === root.holdingLyrics)
            return;
        root.holdingLyrics = root.wantsLyrics;
        if (root.holdingLyrics)
            Lyrics.hold();
        else
            Lyrics.release();
    }

    onLeadChanged: root.swapLead()

    onSecondChanged: if (root.second)
        root.shownSecond = root.second

    onAlertChanged: {
        if (!root.alert)
            return;
        root.shownAlert = root.alert;
        for (const entry of Notifications.popups)
            if (entry !== root.alert)
                Notifications.expire(entry);
    }

    onExpandedChanged: if (root.expanded)
        Media.sync()

    onAttendingChanged: {
        if (root.attending) {
            Notices.hold(root);
            Notifications.pause(root);
        } else {
            Notices.release(root);
            Notifications.resume(root);
        }
    }

    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    Component.onCompleted: {
        root.shownLead = root.lead;
        root.shownSecond = root.second;
        root.shownAlert = root.alert;
    }

    Component.onDestruction: {
        Notices.release(root);
        Notifications.resume(root);
        if (root.holdingLyrics)
            Lyrics.release();
    }

    Timer {
        interval: Appearance.animation.dwell
        running: root.hovering && !root.dwelt && !root.spent
        onTriggered: root.dwelt = true
    }

    Timer {
        interval: Appearance.animation.grace
        running: !root.hovering && root.dwelt
        onTriggered: root.dwelt = false
    }

    Follow {
        id: presence

        speed: Appearance.animation.revealSpeed * 0.55
        target: root.out ? 1 : 0
        epsilon: 0.004
    }

    Follow {
        id: settle

        speed: settle.target > settle.value ? Appearance.animation.revealSpeed * 0.2 : Appearance.animation.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.004
    }

    readonly property real morphSpeed: Appearance.animation.resizeSpeed * 0.7

    function fadeSpeed(fade: Follow): real {
        return fade.target < fade.value ? Appearance.animation.revealSpeed * 2 : Appearance.animation.revealSpeed;
    }

    Follow {
        id: wide

        speed: root.morphSpeed
        target: root.out ? root.targetWidth : root.compactHeight
    }

    Follow {
        id: tall

        speed: root.morphSpeed
        target: root.out ? root.targetHeight : root.compactHeight
    }

    Follow {
        id: compactFade

        speed: root.fadeSpeed(compactFade)
        epsilon: 0.004
        target: root.base === "compact" ? 1 - root.openness : 0
    }

    Follow {
        id: swap

        speed: Appearance.animation.revealSpeed * 1.5
        epsilon: 0.004
        target: 1

        onValueChanged: if (swap.value === 0) {
            root.shownLead = root.lead ?? root.shownLead;
            swap.target = 1;
        }
    }

    Follow {
        id: alertFade

        speed: root.fadeSpeed(alertFade)
        epsilon: 0.004
        target: root.base === "alert" ? (1 - root.openness) * (1 - root.lift) : 0

        onValueChanged: if (alertFade.value === 0 && !root.alert)
            root.shownAlert = null
    }

    Follow {
        id: overviewFade

        speed: root.fadeSpeed(overviewFade)
        epsilon: 0.004
        target: root.openness
    }

    Follow {
        id: bud

        speed: Appearance.animation.trackSpeed
        epsilon: 0.004
        target: root.second && root.openness === 0 ? 1 : 0
    }

    Follow {
        id: glow

        speed: Appearance.animation.revealSpeed * 0.6
        epsilon: 0.004
        target: !Media.hasTrack ? 0 : root.openness > 0 ? 0.62 * root.openness : root.base === "compact" && root.shownLead?.kind === "music" ? 0.45 : 0
    }

    Pull {
        id: zone

        z: 1

        hoverEnabled: true
        height: Config.values.control.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border
        width: Math.max(root.pillWidth, root.largeWidth / 2)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        dirX: 0
        dirY: 1
        angle: Config.values.control.pullAngleEdge
        travel: Math.max(1, overview.implicitHeight - root.compactHeight)

        onTapped: root.pinned = !root.pinned
        onPulled: fraction => root.dragTo(fraction)
        onFinished: open => root.dragEnd(open)

        HoverHandler {
            id: stripHover
        }
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.pinned = false;
                event.accepted = true;
            }
        }
    }

    PanelWindow {
        id: surface

        screen: root.host

        anchors.top: true
        margins.top: root.y

        implicitWidth: root.fieldWidth
        implicitHeight: root.fieldHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "banditshell-island"

        mask: Region {
            item: root.interactive ? hit : null
        }

        Item {
            anchors.fill: parent

            DropShadow {
                x: root.pillX
                y: root.pillY
                width: root.pillWidth
                height: root.pillHeight
                radius: root.pillRadius
                opacity: settle.value * 0.8
            }

            DropShadow {
                x: root.budX
                y: root.budY
                width: root.budSize
                height: root.budSize
                radius: root.budSize / 2
                opacity: settle.value * bud.value * 0.8
                visible: bud.value > 0.01
            }

            IslandField {
                anchors.fill: parent

                pillRect: Qt.rect(root.pillX, root.pillY, root.pillWidth, root.pillHeight)
                budRect: bud.value > 0.01 ? Qt.rect(root.budX, root.budY, root.budSize, root.budSize) : Qt.rect(0, 0, 0, 0)
                pillRadius: root.pillRadius
                power: root.pillPower
                budRadius: root.budSize / 2
                smoothing: root.budGap * 0.8

                edge: root.edge
                neck: root.neck

                source: inkSource
                visible: presence.value > 0.001
            }

            ShaderEffectSource {
                id: inkSource

                sourceItem: ink
                hideSource: true
                live: true
                visible: false
            }

            Item {
                id: ink

                anchors.fill: parent

                ArtCrossfade {
                    x: root.centreX - root.largeWidth / 2
                    y: root.pillY
                    width: root.largeWidth
                    height: Math.max(root.compactHeight, overview.implicitHeight)
                    radius: 0
                    blurred: true
                    brightness: -0.32
                    tame: 0.85
                    source: Media.hasTrack ? Media.artUrl : ""
                    opacity: glow.value
                    visible: glow.value > 0.005
                }

                Pull {
                    x: root.pillX
                    y: root.pillY
                    width: root.pillWidth
                    height: root.pillHeight
                    enabled: root.expanded

                    dirX: 0
                    dirY: -1
                    angle: Config.values.control.pullAngleEdge
                    travel: Math.max(1, overview.implicitHeight - root.compactHeight)

                    onPulled: fraction => root.dragTo(1 - fraction)
                    onFinished: open => root.dragEnd(!open)
                }

                ActivityRow {
                    id: measure

                    visible: false
                    activity: root.lead
                    live: false
                }

                ActivityRow {
                    x: root.centreX - width / 2
                    y: root.pillY
                    width: implicitWidth
                    activity: root.shownLead
                    live: root.focused && compactFade.value > 0
                    opacity: compactFade.value * swap.value * presence.value
                    visible: opacity > 0.005
                    enabled: root.base === "compact" && root.openness === 0

                    onChosen: root.chosen(root.shownLead)
                }

                NotificationAlert {
                    id: alertView

                    x: root.centreX - root.largeWidth / 2
                    y: root.pillY
                    width: root.largeWidth
                    entry: root.shownAlert
                    hovered: islandHover.hovered
                    opacity: alertFade.value * presence.value
                    visible: opacity > 0.005
                    enabled: root.base === "alert" && root.openness === 0

                    onDismissed: if (root.shownAlert)
                        Notifications.dismiss(root.shownAlert)
                }

                IslandOverview {
                    id: overview

                    x: root.centreX - root.largeWidth / 2
                    y: root.pillY
                    width: root.largeWidth
                    activities: root.overviewRows
                    watched: overviewFade.value > 0.01
                    opacity: overviewFade.value * presence.value
                    visible: opacity > 0.005
                    enabled: root.expanded

                    onChosen: activity => root.chosen(activity)
                }

                Item {
                    x: root.budX
                    y: root.budY
                    width: root.budSize
                    height: root.budSize
                    clip: true
                    opacity: bud.value
                    visible: bud.value > 0.01

                    ActivityRow {
                        id: budRow

                        x: (parent.width - budRow.inset * 2 - budRow.slot) / 2
                        y: (parent.height - height) / 2
                        width: implicitWidth
                        activity: root.shownSecond
                        live: false
                        enabled: !!root.second

                        onChosen: root.chosen(root.shownSecond)
                    }
                }
            }

            Item {
                id: hit

                x: root.pillX
                y: root.pillY
                width: bud.value > 0.01 ? root.budX + root.budSize - root.pillX : root.pillWidth
                height: Math.max(root.pillHeight, root.compactHeight)

                HoverHandler {
                    id: islandHover
                }
            }
        }
    }
}
