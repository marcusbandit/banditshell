pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    required property var entry

    property string density: "alert"
    property bool collapses: false
    property bool keepLeaves: true
    property string family: Appearance.font.family
    property int count: 1
    property bool countOpen: false
    property bool folded: false
    property bool tiled: false
    property bool joinedAbove: false
    property bool joinedBelow: false
    property bool aboveLoose: false
    property bool belowLoose: false

    property real tug: 0
    property bool hushing: false

    readonly property bool loose: swipe.dragging || swipe.flinging || root.leaving || Math.abs(swipe.shift) > Appearance.padding.hair
    readonly property real pull: swipe.dragging && Math.abs(swipe.pulled) < swipe.throwDistance ? swipe.shift : 0
    readonly property real drift: swipe.shift + tugged.value

    signal countTapped
    signal released
    signal kept
    signal scrolled(real by)
    signal scrollEnded(real speed)

    readonly property bool alert: root.density === "alert"
    readonly property bool page: root.density === "page"
    readonly property bool row: root.density === "row"
    readonly property bool line: root.density === "line"
    readonly property bool roomy: root.alert || root.page
    readonly property bool interactive: !root.line

    readonly property var notification: root.entry?.notification ?? null
    readonly property bool live: root.entry?.live ?? false
    readonly property bool urgent: root.entry?.urgency === NotificationUrgency.Critical
    readonly property bool wordless: !root.entry?.appName && !root.entry?.summary && !root.entry?.body
    readonly property bool pinned: root.entry?.pinned ?? false
    readonly property bool unfolded: root.entry?.unfolded ?? false
    readonly property string age: Notifications.ageOf(root.entry?.time ?? 0)

    readonly property var actions: root.live && root.roomy ? (root.entry?.pressable(root.notification?.actions) ?? []) : []

    readonly property string appName: root.entry?.appName || "this app"
    readonly property string appMutedLabel: root.entry ? Notifications.mutedLabel(Notifications.ruleKeyFor(root.entry)) : ""
    readonly property bool appMuted: root.appMutedLabel !== ""

    property double hushAt: Date.now()
    readonly property var hushEnds: [...new Set([Notifications.hushUntil("hour", root.hushAt), Notifications.hushUntil("tomorrow", root.hushAt)])].sort((a, b) => a - b)

    readonly property real tileInset: root.tiled ? Appearance.padding.small : 0
    readonly property real tileGap: root.tiled ? Appearance.stroke.line : 0
    readonly property real tileBottom: root.height - root.tileGap
    readonly property real seamRadius: Appearance.padding.hair / 2
    readonly property real topRound: root.seamRadius + (Appearance.rounding.normal - root.seamRadius) * topOpen.value
    readonly property real bottomRound: root.seamRadius + (Appearance.rounding.normal - root.seamRadius) * bottomOpen.value
    readonly property real pad: root.tiled ? Appearance.padding.normal : root.roomy ? Appearance.padding.card : root.row ? Appearance.padding.small : 0
    readonly property real gap: Appearance.padding.normal
    readonly property real closeSize: Appearance.font.line.small + Appearance.padding.small
    readonly property real closeRoom: root.roomy ? root.closeSize + Appearance.padding.small : 0
    readonly property real markSize: root.line ? Appearance.font.line.small : root.row ? Appearance.font.line.small + Appearance.padding.small * 2 : Appearance.sizes.notificationBadge * (root.page && (root.entry?.picture ?? "") !== "" ? 2 : 1)
    readonly property real radius: Math.max(Appearance.rounding.small, Appearance.rounding.large - Appearance.padding.normal)

    readonly property real textX: root.tileInset + root.pad + root.markSize + root.gap
    readonly property real textWidth: root.width - root.textX - root.pad - root.tileInset - root.closeRoom

    readonly property bool hovered: swipe.hovered
    readonly property bool handling: swipe.handling
    readonly property bool flinging: swipe.flinging
    readonly property real shiftFade: swipe.fade

    readonly property bool leaving: root.entry?.leaving ?? false

    readonly property real open: root.collapses ? Math.max(0, arrive.value - depart.value) : 1

    readonly property bool held: root.interactive && (swipe.hovered || swipe.pressed || root.pinned)

    property var holding: null

    function holdEntry(): void {
        const want = root.held ? root.entry : null;
        if (root.holding === want)
            return;
        root.holding?.release(root);
        root.holding = want;
        root.holding?.hold(root);
    }

    onHeldChanged: root.holdEntry()
    onEntryChanged: {
        root.hushing = false;
        root.holdEntry();
    }

    function hush(kind: string, until: double): void {
        root.hushing = false;
        Notifications.hush(root.entry, kind, until);
    }

    onHushingChanged: root.hushAt = Date.now()

    Timer {
        interval: 10000
        repeat: true
        running: root.hushing
        onTriggered: root.hushAt = Date.now()
    }

    function pin(on: bool): void {
        if (root.entry)
            root.entry.pinned = on;
    }

    function unfold(on: bool): void {
        if (root.entry)
            root.entry.unfolded = on;
    }

    function fling(direction: int): void {
        swipe.fling(direction);
    }

    function dismissAfter(act: var): void {
        if (root.live)
            act();
        Notifications.answered(root.entry);
    }

    implicitHeight: (root.compact ? slim.height : full.implicitHeight) + root.pad * 2 + root.tileGap * 2
    height: root.collapses ? implicitHeight * root.open : implicitHeight

    readonly property bool compact: root.row || root.line

    clip: root.collapses && root.open < 0.999
    opacity: root.open * (1 - swipe.fade * 0.9)

    onLeavingChanged: if (!root.leaving)
        swipe.reset()

    Component.onCompleted: arrive.target = 1
    Component.onDestruction: root.holding?.release(root)

    Follow {
        id: arrive

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: depart

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
        target: root.leaving ? 1 : 0
    }

    Spring {
        id: tugged

        target: root.tug
        epsilon: 0.25
    }

    Follow {
        id: topOpen

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
        target: !root.joinedAbove || root.loose || root.aboveLoose ? 1 : 0
        startsAtTarget: true
    }

    Follow {
        id: bottomOpen

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
        target: !root.joinedBelow || root.loose || root.belowLoose ? 1 : 0
        startsAtTarget: true
    }

    Follow {
        id: glow

        speed: Appearance.animation.revealSpeed * 1.5
        epsilon: 0.005
        target: root.interactive && swipe.hovered && !swipe.moved ? 1 : 0
    }

    NotificationSwipe {
        id: swipe

        anchors.fill: parent
        z: -1
        enabled: root.interactive
        keepLeaves: root.keepLeaves

        onTapped: {
            if (root.folded)
                root.countTapped();
            else
                Notifications.activate(root.entry);
        }
        onHeld: root.pin(true)
        onReleased: root.released()
        onKept: root.kept()
        onScrolled: by => root.scrolled(by)
        onScrollEnded: speed => root.scrollEnded(speed)
    }

    Item {
        id: content

        x: root.drift
        width: root.width
        height: root.height

        SquircleRect {
            x: root.tileInset
            y: root.tileGap
            width: root.width - root.tileInset * 2
            height: root.tileBottom - root.tileGap
            topLeftRadius: root.topRound
            topRightRadius: root.topRound
            bottomLeftRadius: root.bottomRound
            bottomRightRadius: root.bottomRound
            color: Appearance.colour.tile
            visible: root.tiled
        }

        SquircleRect {
            x: root.tiled ? root.tileInset : root.alert ? Appearance.padding.small : 0
            y: root.tiled ? root.tileGap : root.alert ? Appearance.padding.small : 0
            width: root.width - x * 2
            height: (root.tiled ? root.tileBottom : root.height) - y * (root.tiled ? 1 : 2)
            radius: root.radius
            topLeftRadius: root.tiled ? root.topRound : root.radius
            topRightRadius: root.tiled ? root.topRound : root.radius
            bottomLeftRadius: root.tiled ? root.bottomRound : root.radius
            bottomRightRadius: root.tiled ? root.bottomRound : root.radius
            color: swipe.pressed && !swipe.moved || root.pinned ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: root.page ? 1 : glow.value
            visible: root.interactive && opacity > 0.01
        }

        Item {
            id: slim

            x: root.pad
            y: root.pad
            width: root.width - root.pad * 2
            height: root.markSize
            visible: root.compact

            NotificationMark {
                id: slimMark

                size: root.markSize
                radius: Appearance.rounding.small
                entry: root.entry
            }

            StyledText {
                id: slimTail

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.row
                text: root.entry?.appName ? (root.age ? `${root.entry.appName} · ${root.age}` : root.entry.appName) : root.age
                color: Appearance.colour.textFaint
                font.family: root.family
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width / 3)
                horizontalAlignment: Text.AlignRight
            }

            StyledText {
                anchors.left: slimMark.right
                anchors.leftMargin: root.gap
                anchors.right: slimTail.visible ? slimTail.left : parent.right
                anchors.rightMargin: slimTail.visible ? root.gap : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.wordless ? "(no message)" : (root.entry?.summary || root.entry?.body || "")
                color: root.wordless ? Appearance.colour.textFaint : Appearance.colour.text
                font.family: root.family
                elide: Text.ElideRight
            }
        }

        Item {
            id: full

            x: root.tileInset + root.pad
            y: root.tileGap + root.pad
            width: root.width - (root.tileInset + root.pad) * 2
            implicitHeight: Math.max(mark.height + (fold.visible ? Appearance.padding.small + fold.height : 0), words.implicitHeight)
            visible: root.roomy

            NotificationMark {
                id: mark

                size: root.markSize
                entry: root.entry
                scale: 1 + 0.06 * glow.value
            }

            Expander {
                id: fold

                anchors.horizontalCenter: mark.horizontalCenter
                anchors.top: mark.bottom
                anchors.topMargin: Appearance.padding.small

                visible: root.page && (message.foldable || headline.foldable)
                open: root.unfolded

                onToggled: root.unfold(!root.unfolded)
            }

            Column {
                id: words

                x: root.markSize + root.gap
                y: Math.max(0, (root.markSize - Math.min(root.markSize, implicitHeight)) / 2)
                width: root.textWidth
                spacing: Appearance.padding.small / 2

                Item {
                    id: headRow

                    readonly property real ageRoom: Math.max(ageText.text ? ageText.implicitWidth : 0, root.roomy ? root.closeSize : 0)
                    readonly property real room: headRow.width - (headRow.ageRoom ? headRow.ageRoom + Appearance.padding.small : 0) - (pinMark.visible ? pinMark.width + Appearance.padding.small : 0)

                    width: parent.width
                    height: Math.max(Appearance.font.line.small, headline.visible ? headline.implicitHeight : 0, heading.visible ? heading.implicitHeight : 0)

                    StyledText {
                        id: ageText

                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Appearance.font.line.small
                        verticalAlignment: Text.AlignVCenter
                        text: root.age
                        color: Appearance.colour.textFaint
                        font.family: root.family
                        opacity: root.roomy ? 1 - hushButton.opacity : 1
                    }

                    Icon {
                        id: pinMark

                        anchors.right: parent.right
                        anchors.rightMargin: headRow.ageRoom ? headRow.ageRoom + Appearance.padding.small : 0
                        anchors.verticalCenter: ageText.verticalCenter
                        name: "push_pin"
                        size: Appearance.font.size.small
                        fill: 1
                        color: Appearance.colour.accent
                        opacity: root.pinned ? 1 : root.keepLeaves ? 0 : Math.min(1, Math.max(0, -swipe.pulled / Math.max(1, swipe.throwDistance)))
                        visible: opacity > 0.01
                    }

                    FoldedText {
                        id: headline

                        width: headRow.room
                        visible: root.page && !!full
                        full: root.wordless ? "(no message)" : (root.entry?.summary ?? "")
                        color: root.wordless ? Appearance.colour.textFaint : Appearance.colour.text
                        font.pixelSize: Appearance.font.size.normal
                        font.family: root.family
                        unfolded: root.unfolded
                        lines: 4
                    }

                    StyledText {
                        id: heading

                        width: headRow.room
                        visible: root.alert && text !== ""
                        text: root.entry?.summary || (!root.entry?.body ? "(no message)" : "")
                        font.family: root.family
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Item {
                    id: meter

                    readonly property real pct: root.entry?.progress ?? -1

                    width: parent.width
                    visible: pct >= 0
                    height: visible ? gaugeRow.implicitHeight + Appearance.padding.small : 0

                    Follow {
                        id: chase

                        target: meter.pct
                        speed: Appearance.animation.revealSpeed
                    }

                    Component.onCompleted: chase.snap()

                    Item {
                        id: gaugeRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: Math.max(gauge.implicitHeight, figure.implicitHeight)
                        height: implicitHeight

                        Gauge {
                            id: gauge

                            anchors.left: parent.left
                            anchors.right: figure.left
                            anchors.rightMargin: Appearance.padding.small
                            anchors.verticalCenter: parent.verticalCenter

                            value: chase.value / 100
                        }

                        StyledText {
                            id: figure

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            text: `${Math.round(meter.pct)}%`
                            color: Appearance.colour.textDim
                            font.family: root.family
                        }
                    }
                }

                FoldedText {
                    id: message

                    width: parent.width + root.closeRoom
                    visible: !!root.entry?.body

                    full: root.entry?.body ?? ""
                    brief: root.entry?.brief ?? ""
                    textFormat: Text.StyledText
                    unfolded: root.page && root.unfolded

                    font.pixelSize: Appearance.font.size.small
                    font.family: root.family
                    color: Appearance.colour.textDim
                    topPadding: Appearance.padding.small / 2

                    lines: root.page ? 12 : 2
                }

                Item {
                    id: who

                    width: parent.width + root.closeRoom
                    height: Appearance.font.line.small + Appearance.padding.small / 2
                    visible: !!root.entry?.appName || root.count > 1

                    Item {
                        id: tally

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: tally.visible ? tallyCount.implicitWidth + tallyMark.width + Appearance.padding.small * 2 : 0
                        height: Appearance.font.line.small
                        visible: root.count > 1

                        SquircleRect {
                            anchors.fill: parent
                            pill: "object"
                            color: tallyArea.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
                        }

                        StyledText {
                            id: tallyCount

                            x: Appearance.padding.small
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.count
                            font.family: root.family
                        }

                        Icon {
                            id: tallyMark

                            anchors.left: tallyCount.right
                            anchors.verticalCenter: parent.verticalCenter
                            name: "expand_more"
                            size: Appearance.font.size.small
                            rotation: root.countOpen ? 180 : 0
                            color: Appearance.colour.textDim
                        }

                        MouseArea {
                            id: tallyArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.countTapped()
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: tally.visible ? tally.left : parent.right
                        anchors.rightMargin: Appearance.padding.small
                        anchors.verticalCenter: tally.verticalCenter
                        text: root.entry?.appName ?? ""
                        color: root.urgent ? Appearance.colour.alarm : Appearance.colour.textFaint
                        font.family: root.family
                        elide: Text.ElideRight
                    }
                }

                Flow {
                    id: buttons

                    width: parent.width + root.closeRoom
                    visible: root.actions.length > 0
                    topPadding: Appearance.padding.normal
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.actions

                        delegate: Button {
                            required property var modelData

                            size: 0
                            text: modelData.text
                            width: Math.min(implicitWidth, buttons.width)

                            onClicked: root.dismissAfter(() => modelData.invoke())
                        }
                    }
                }

                Item {
                    id: reply

                    readonly property bool shown: root.page && root.live && (root.entry?.canReply ?? false)

                    function submit(): void {
                        const said = input.text.trim();
                        if (said && Notifications.reply(root.entry, said))
                            input.text = "";
                    }

                    width: parent.width + root.closeRoom
                    visible: reply.shown
                    height: reply.shown ? send.height + Appearance.padding.normal : 0

                    SquircleRect {
                        anchors.left: parent.left
                        anchors.right: send.left
                        anchors.rightMargin: Appearance.padding.small
                        anchors.bottom: parent.bottom
                        height: send.height
                        radius: Appearance.rounding.small
                        color: Appearance.colour.fillStrong

                        TextInput {
                            id: input

                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.rightMargin: Appearance.padding.normal
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            font.family: root.family
                            font.pixelSize: Appearance.font.size.small
                            renderType: Text.NativeRendering
                            color: Appearance.colour.text
                            selectionColor: Appearance.colour.accent
                            selectedTextColor: Appearance.colour.accentText

                            onAccepted: reply.submit()
                            onActiveFocusChanged: if (!input.activeFocus)
                                Prompts.release(input)
                            Keys.onEscapePressed: input.focus = false
                            Component.onDestruction: Prompts.release(input)

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !input.text && !input.activeFocus
                                text: root.entry?.replyPlaceholder ?? "Reply"
                                color: Appearance.colour.textFaint
                                font.family: root.family
                            }

                            TapHandler {
                                onTapped: {
                                    Prompts.request(input);
                                    Qt.callLater(input.forceActiveFocus);
                                }
                            }
                        }
                    }

                    Button {
                        id: send

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        size: 0
                        icon: "send"
                        interactive: input.text.trim() !== ""

                        onClicked: reply.submit()
                    }
                }

                Column {
                    id: hushPanel

                    width: parent.width + root.closeRoom
                    visible: root.hushing && root.roomy
                    topPadding: Appearance.padding.normal
                    spacing: Appearance.padding.small

                    Repeater {
                        model: [
                            {
                                label: "Remind me",
                                timed: root.hushEnds.map(until => ["snooze", until, `at ${Notifications.endsAt(until, root.hushAt)}`]),
                                lasting: []
                            },
                            {
                                label: root.appMuted ? `${root.appName} muted ${root.appMutedLabel}` : `Mute ${root.appName}`,
                                timed: root.appMuted ? [["unmute", 0, "unmute"]] : root.hushEnds.map(until => ["mute", until, `until ${Notifications.endsAt(until, root.hushAt)}`]),
                                lasting: root.appMuted ? [] : [["mute", 0, "until I unmute"]]
                            }
                        ]

                        delegate: Column {
                            id: group

                            required property var modelData

                            width: hushPanel.width
                            spacing: Appearance.padding.small / 2

                            StyledText {
                                width: group.width
                                text: group.modelData.label
                                color: Appearance.colour.textDim
                                font.family: root.family
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: [group.modelData.timed, group.modelData.lasting].filter(line => line.length > 0)

                                delegate: Flow {
                                    id: line

                                    required property var modelData

                                    width: group.width
                                    spacing: Appearance.padding.small

                                    Repeater {
                                        model: line.modelData

                                        delegate: Button {
                                            required property var modelData

                                            size: 0
                                            style: "ring"
                                            text: modelData[2]
                                            onClicked: root.hush(modelData[0], modelData[1])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component CornerButton: Item {
        id: corner

        property string icon: ""
        property string title: ""
        property bool on: false

        signal clicked

        visible: opacity > 0.01

        Follow {
            id: cornerScale

            speed: Appearance.animation.revealSpeed * 1.5
            epsilon: 0.001
            target: cornerArea.pressed ? Appearance.press.ring : cornerArea.containsMouse ? Appearance.press.ringHover : 1
        }

        Component.onCompleted: cornerScale.snap()

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: corner.on ? Appearance.colour.accent : cornerArea.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
            scale: cornerScale.value
        }

        Icon {
            anchors.centerIn: parent
            name: corner.icon
            size: Appearance.font.size.small
            color: corner.on ? Appearance.colour.accentText : cornerArea.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
        }

        MouseArea {
            id: cornerArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: corner.clicked()
        }

        FloatingTooltip {
            x: corner.width - width
            y: corner.height + gap
            text: corner.title
            shown: cornerArea.containsMouse
        }
    }

    CornerButton {
        id: close

        x: root.drift + root.width - root.tileInset - root.pad - width + Appearance.padding.small / 2
        y: root.tileGap + root.pad - Appearance.padding.small / 2
        width: root.closeSize
        height: root.closeSize
        icon: "close"
        title: "Dismiss"
        opacity: root.roomy ? glow.value : 0

        onClicked: root.fling(1)
    }

    CornerButton {
        id: hushButton

        x: close.x - Appearance.padding.small * 1.5 - width
        y: close.y
        width: root.closeSize
        height: root.closeSize
        icon: "snooze"
        title: "Remind me or mute"
        on: root.hushing
        opacity: !root.roomy ? 0 : root.hushing ? 1 : glow.value

        onClicked: root.hushing = !root.hushing
    }
}
