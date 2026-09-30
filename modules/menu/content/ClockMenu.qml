pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    function token(name: string, fallback: var): var {
        const value = Appearance.sizes[name];
        if (value === undefined)
            return fallback;
        return Array.isArray(value) && value.length === 0 ? fallback : value;
    }

    readonly property var timerPresets: root.token("timerPresets", [1, 5, 10, 25])

    readonly property var dayBand: root.token("dayBand", [6, 18])

    readonly property int zoneListMax: root.token("zoneListMax", 8)

    readonly property int scrubDetent: root.token("scrubDetent", 5)

    readonly property int hoursInDay: 24
    readonly property int oneMinute: 60000

    readonly property int mark: Appearance.font.stem

    readonly property real scrubHeight: Math.max(Appearance.sizes.rowHeight, Math.round(Appearance.font.size.large * 4 / 3))

    SystemClock {
        id: clock

        precision: SystemClock.Minutes

        enabled: root.visible
    }

    readonly property double now: clock.date.getTime()

    readonly property real localHour: clock.date.getHours() + clock.date.getMinutes() / 60

    readonly property double beat: Clock.tick > 0 ? Clock.tick : root.now

    property bool picking: false

    readonly property string query: filter.value

    property string editing: ""

    property int setHours: 0
    property int setMinutes: 0
    property int setSeconds: 0

    readonly property int composedSeconds: root.setHours * 3600 + root.setMinutes * 60 + root.setSeconds

    readonly property var alarmRows: Clock.alarms.slice().sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute))

    readonly property var matches: {
        if (!root.picking)
            return [];
        const q = root.query.toLowerCase();
        return Clock.allZones.filter(z => z !== Clock.localZone && !Clock.places.includes(z) && z.toLowerCase().includes(q)).slice(0, root.zoneListMax);
    }

    function clockText(ms: double): string {
        const total = Math.max(0, Math.ceil(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return h > 0 ? `${h}:${Clock.pad2(m)}:${Clock.pad2(s)}` : `${m}:${Clock.pad2(s)}`;
    }

    function zoneDetail(delta: int, dayDelta: int): string {
        const offset = Clock.offsetLabel(delta);
        if (dayDelta === 0)
            return offset;
        return `${offset} · ${dayDelta > 0 ? "tomorrow" : "yesterday"}`;
    }

    function alarmDetail(alarm: var): string {
        if (alarm.missed)
            return "missed";
        if (alarm.days.length > 0)
            return alarm.days.map(d => Qt.locale().dayName(d + 1, Locale.ShortFormat)).join(" ");
        if (!alarm.armed)
            return "once";
        const next = Clock.nextFor(alarm, root.now);
        return next > 0 ? `in ${Clock.spanLabel(next - root.now)}` : "once";
    }

    function addPlace(id: string): void {
        Clock.addZone(id);
        root.picking = false;
    }

    component Eyebrow: StyledText {
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    component DayBar: Item {
        id: bar

        required property real hourOfDay

        implicitHeight: root.mark * 3
        height: implicitHeight

        Rectangle {
            y: (bar.height - height) / 2
            width: bar.width
            height: root.mark
            color: Appearance.colour.textGhost
        }

        Rectangle {
            x: root.dayBand[0] / root.hoursInDay * bar.width
            y: (bar.height - height) / 2
            width: (root.dayBand[1] - root.dayBand[0]) / root.hoursInDay * bar.width
            height: root.mark
            color: Appearance.colour.fillStrong
        }

        Rectangle {
            x: bar.hourOfDay / root.hoursInDay * (bar.width - width)
            width: root.mark * 2
            height: bar.height
            color: Appearance.colour.text
        }
    }

    component Card: Item {
        id: card

        property real rowHeight: Appearance.sizes.rowHeight

        property bool tappable: false

        default property alias content: slot.data

        readonly property real discSize: Appearance.sizes.minTarget
        readonly property real discSpace: card.discSize + Appearance.padding.small

        signal tapped
        signal dismissed

        property real dragX: 0
        property real pulled: 0

        readonly property real throwDistance: Math.max(1, card.width) * Appearance.sizes.dragDismissFraction

        readonly property real fade: {
            const held = card.throwDistance * Appearance.sizes.dragResistance;
            const past = Math.max(0, card.dragX - held);
            return Math.max(0, 1 - past / Math.max(1, card.width - held));
        }

        function resist(delta: real): real {
            const commit = card.throwDistance;
            const k = Appearance.sizes.dragResistance;
            return delta < commit ? delta * k : commit * k + (delta - commit);
        }

        implicitWidth: parent ? parent.width : 0
        implicitHeight: card.rowHeight
        height: implicitHeight

        Follow {
            id: settle

            speed: Appearance.anim.revealSpeed
            onValueChanged: if (!drag.throwing)
                card.dragX = value
        }

        MouseArea {
            id: drag

            property real fromX: 0
            property real fromY: 0
            property real startedAt: 0

            property bool throwing: false

            property bool wandered: false

            property bool scrolling: false

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor

            function begin(): void {
                drag.startedAt = card.dragX;
                drag.throwing = false;
                drag.wandered = false;
                drag.scrolling = false;

                settle.value = card.dragX;
                settle.target = card.dragX;
            }

            function advance(dx: real, dy: real): void {
                if (!drag.throwing) {
                    if (Math.abs(dy) >= Appearance.sizes.dragThreshold)
                        drag.wandered = true;

                    if (Math.abs(dy) > dx)
                        return;
                    if (dx < Appearance.sizes.dragThreshold)
                        return;
                    drag.throwing = true;
                }

                card.pulled = dx;
                card.dragX = card.resist(Math.max(0, drag.startedAt + dx));
            }

            function stream(dx: real, dy: real): void {
                if (!drag.throwing) {
                    if (drag.scrolling)
                        return;
                    if (Math.abs(dy) > dx && Math.abs(dy) >= Appearance.sizes.dragThreshold) {
                        drag.scrolling = true;
                        return;
                    }
                }
                drag.advance(dx, dy);
            }

            function conclude(): void {
                if (!drag.throwing)
                    return;

                if (card.pulled >= card.throwDistance) {
                    card.dismissed();
                    return;
                }

                settle.value = card.dragX;
                settle.target = 0;
                card.pulled = 0;
                drag.throwing = false;
            }

            onPressed: mouse => {

                scroll.finish();
                drag.fromX = drag.x + mouse.x;
                drag.fromY = drag.y + mouse.y;
                drag.begin();
            }

            onPositionChanged: mouse => {
                if (drag.pressed)
                    drag.advance(drag.x + mouse.x - drag.fromX, drag.y + mouse.y - drag.fromY);
            }

            onReleased: {

                if (!drag.throwing) {
                    if (!drag.wandered && card.tappable)
                        card.tapped();
                    return;
                }
                drag.conclude();
            }

            onCanceled: {
                settle.value = card.dragX;
                settle.target = 0;
                card.pulled = 0;
                drag.throwing = false;
                drag.wandered = false;
                drag.scrolling = false;
            }

            onWheel: wheel => {
                if (drag.pressed) {
                    wheel.accepted = false;
                    return;
                }

                if (!scroll.feed(wheel))
                    return;

                wheel.accepted = drag.throwing;
            }

            ScrollGesture {
                id: scroll

                armed: !drag.pressed

                onBegan: drag.begin()
                onMoved: (dx, dy) => drag.stream(dx, dy)
                onEnded: drag.conclude()
            }
        }

        Item {
            id: shifted

            x: card.dragX
            width: card.width
            height: card.height
            opacity: card.fade

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                opacity: drag.containsMouse || drag.pressed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Item {
                id: slot

                anchors.fill: parent
            }

            Item {
                id: disc

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter

                width: card.discSize
                height: width
                opacity: drag.containsMouse || discPress.containsMouse ? 1 : 0

                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                G2Rect {
                    anchors.fill: parent
                    radius: height / 2
                    color: discPress.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
                }

                Icon {
                    anchors.centerIn: parent

                    name: "close"

                    size: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }

                MouseArea {
                    id: discPress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismissed()
                }
            }
        }
    }

    component ScrubField: Item {
        id: field

        property int value: 0
        property int from: 0
        property int to: 59
        property int detent: 1
        property bool wrap: true

        property bool zeroIsEmpty: true

        signal moved(int v)

        readonly property real pitch: Appearance.sizes.minTarget / Math.max(1, field.detent)
        readonly property int span: field.to - field.from + 1

        implicitWidth: Math.max(Appearance.sizes.minTarget, digits.implicitWidth + Appearance.padding.small * 2)
        implicitHeight: root.scrubHeight
        width: implicitWidth
        height: implicitHeight

        function fold(v: int): int {
            if (!field.wrap)
                return Math.max(field.from, Math.min(field.to, v));
            return field.from + ((v - field.from) % field.span + field.span) % field.span;
        }

        function magnet(raw: real): int {
            const step = Math.max(1, field.detent);
            const nearest = Math.round(raw / step) * step;
            return Math.abs(raw - nearest) * field.pitch <= Appearance.sizes.dragThreshold ? nearest : Math.round(raw);
        }

        function ask(raw: real): void {
            field.moved(field.fold(field.magnet(raw)));
        }

        function nudge(units: int): void {
            if (units !== 0)
                field.moved(field.fold(field.value + units));
        }

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            opacity: pointer.containsMouse || pointer.pressed || scroll.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: digits

            anchors.centerIn: parent

            text: Clock.pad2(field.value)
            font.pixelSize: Appearance.font.size.large
            color: field.zeroIsEmpty && field.value === 0 ? Appearance.colour.textFaint : Appearance.colour.text
        }

        MouseArea {
            id: pointer

            property real fromY: 0
            property int startValue: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            preventStealing: true

            onPressed: mouse => {
                scroll.finish();
                pointer.fromY = mouse.y;
                pointer.startValue = field.value;
            }

            onPositionChanged: mouse => {
                if (pointer.pressed)
                    field.ask(pointer.startValue - (mouse.y - pointer.fromY) / field.pitch);
            }

            onWheel: wheel => {

                if (!scroll.feed(wheel)) {
                    const notches = wheel.angleDelta.y / 120;
                    field.nudge(Math.round(notches) || (notches > 0 ? 1 : notches < 0 ? -1 : 0));
                    wheel.accepted = true;
                    return;
                }

                wheel.accepted = Math.abs(scroll.dy) >= Math.abs(scroll.dx);
            }

            ScrollGesture {
                id: scroll

                armed: !pointer.pressed

                onBegan: pointer.startValue = field.value
                onMoved: (dx, dy) => {
                    if (Math.abs(dy) >= Math.abs(dx))
                        field.ask(pointer.startValue - dy / field.pitch);
                }
            }
        }
    }

    component StatePill: Item {
        id: pill

        property string label: ""
        property bool on: false

        signal clicked

        implicitWidth: Math.max(Appearance.sizes.minTarget, text.implicitWidth + Appearance.padding.normal * 2)
        implicitHeight: Math.max(Appearance.sizes.minTarget, text.implicitHeight + Appearance.padding.small * 2)
        width: implicitWidth
        height: implicitHeight

        scale: press.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        G2Rect {
            anchors.fill: parent
            radius: height / 2
            color: pill.on ? Appearance.colour.fillStronger : press.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: text

            anchors.fill: parent

            text: pill.label
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: pill.on ? Appearance.colour.text : Appearance.colour.textFaint

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component Field: Item {
        id: entry

        property string placeholder: ""

        property bool autoFocus: true

        property string seed: ""

        readonly property string value: input.text

        signal accepted(string text)
        signal committed(string text)
        signal cancelled

        implicitHeight: input.implicitHeight + Appearance.padding.small * 2
        height: implicitHeight

        function claim(): void {
            if (entry.visible && entry.autoFocus) {

                input.text = entry.seed;
                Prompts.request(entry);
                input.forceActiveFocus();
            } else if (!entry.visible) {
                Prompts.release(entry);
            }
        }

        readonly property bool surfaceActive: entry.Window.active
        onSurfaceActiveChanged: if (entry.surfaceActive && entry.visible && entry.autoFocus)
            input.forceActiveFocus()

        onVisibleChanged: entry.claim()
        Component.onCompleted: {
            input.text = entry.seed;
            entry.claim();
        }
        Component.onDestruction: Prompts.release(entry)

        onSeedChanged: if (!input.activeFocus)
            input.text = entry.seed

        G2Rect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            verticalAlignment: TextInput.AlignVCenter
            clip: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            onAccepted: entry.accepted(input.text)
            onEditingFinished: entry.committed(input.text)

            Keys.onEscapePressed: entry.cancelled()

            onActiveFocusChanged: {
                if (input.activeFocus)
                    Prompts.request(entry);
                else if (!entry.autoFocus)
                    Prompts.release(entry);
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                visible: !input.text && !input.activeFocus
                text: entry.placeholder
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !entry.autoFocus
            cursorShape: Qt.IBeamCursor
            onClicked: {
                Prompts.request(entry);
                input.forceActiveFocus();
            }
        }
    }

    G2Rect {
        id: ringing

        readonly property var alarm: Clock.ringing

        readonly property double due: Clock.ringingSince - Clock.ringingLate

        visible: !!ringing.alarm
        width: parent.width
        height: visible ? answers.y + answers.height + Appearance.padding.normal : 0
        radius: Appearance.rounding.normal

        color: Appearance.colour.accentFill

        StyledText {
            id: ringTime

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.top: parent.top
            anchors.topMargin: Appearance.padding.normal

            text: ringing.visible ? Qt.formatDateTime(new Date(ringing.due), "HH:mm") : ""
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.accent
        }

        StyledText {
            id: ringLabel

            anchors.left: ringTime.left
            anchors.top: ringTime.bottom
            anchors.right: ringLate.left
            anchors.rightMargin: Appearance.padding.normal

            visible: !!text
            text: ringing.alarm?.label ?? ""
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        StyledText {
            id: ringLate

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.baseline: ringLabel.baseline

            visible: Clock.ringingLate >= root.oneMinute
            text: visible ? `late by ${Clock.spanLabel(Clock.ringingLate)}` : ""
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        Item {
            id: answers

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.top: ringLabel.visible || ringLate.visible ? ringLabel.bottom : ringTime.bottom
            anchors.topMargin: Appearance.padding.normal

            height: stop.height

            Button {
                anchors.left: parent.left

                width: parent.width - stop.width - Appearance.padding.large
                text: "Snooze"
                onClicked: Clock.snooze()
            }

            Button {
                id: stop

                anchors.right: parent.right

                text: "Stop"
                onClicked: Clock.stop()
            }
        }
    }

    Item {
        id: here

        width: parent.width
        height: hereTime.implicitHeight + Appearance.padding.small + hereBar.height

        StyledText {
            id: hereTime

            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Appearance.font.size.large
        }

        StyledText {
            anchors.right: parent.right
            anchors.baseline: hereTime.baseline

            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        DayBar {
            id: hereBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            hourOfDay: root.localHour
        }
    }

    Eyebrow {
        visible: Clock.zones.length > 0
        text: "ELSEWHERE"
    }

    Item {
        id: elsewhere

        visible: Clock.zones.length > 0
        width: parent.width
        height: zoneRows.implicitHeight

        Rectangle {
            x: root.localHour / root.hoursInDay * (elsewhere.width - root.mark * 2) + root.mark / 2
            width: root.mark
            height: elsewhere.height
            color: Appearance.colour.textGhost
        }

        Column {
            id: zoneRows

            width: parent.width
            spacing: 0

            Repeater {
                model: Clock.zones

                delegate: Card {
                    id: zoneCard

                    required property var modelData

                    readonly property var at: Clock.zoneTime(zoneCard.modelData.offsetMinutes, root.now)

                    width: zoneRows.width
                    rowHeight: Math.max(Appearance.sizes.rowHeight, names.implicitHeight + Appearance.padding.small * 2 + zoneBar.height + Appearance.padding.small)

                    onDismissed: Clock.removeZone(zoneCard.modelData.id)

                    Column {
                        id: names

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: timeThere.left
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        spacing: 0

                        StyledText {
                            width: parent.width
                            text: zoneCard.modelData.city
                            color: Appearance.colour.textDim
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.zoneDetail(zoneCard.modelData.deltaMinutes, zoneCard.at.dayDelta)
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        id: timeThere

                        anchors.right: parent.right
                        anchors.rightMargin: zoneCard.discSpace
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        text: zoneCard.at.text
                        font.pixelSize: Appearance.font.size.normal
                    }

                    DayBar {
                        id: zoneBar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Appearance.padding.small

                        hourOfDay: zoneCard.at.hourOfDay
                    }
                }
            }
        }
    }

    Button {
        width: parent.width
        text: root.picking ? "Never mind" : "Add a place"
        onClicked: {
            root.picking = !root.picking;
            if (root.picking)
                Clock.loadZoneList();
        }
    }

    Item {
        id: picker

        visible: root.picking
        width: parent.width
        height: visible ? filter.height + zoneList.implicitHeight : 0

        Field {
            id: filter

            width: parent.width

            placeholder: "filter cities"
            onAccepted: if (root.matches.length > 0)
                root.addPlace(root.matches[0])

            onCancelled: root.picking = false
        }

        Column {
            id: zoneList

            anchors.top: filter.bottom
            width: parent.width

            Repeater {
                model: root.matches

                delegate: MenuRow {
                    required property var modelData

                    width: zoneList.width
                    label: Clock.cityOf(modelData)

                    detail: modelData.slice(0, Math.max(0, modelData.lastIndexOf("/"))).replace(/_/g, " ")
                    onActivated: root.addPlace(modelData)
                }
            }
        }
    }

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "TIMER"
    }

    Repeater {
        model: Clock.timers

        delegate: Card {
            id: timerCard

            required property var modelData

            readonly property double remainingMs: Clock.remainingOf(timerCard.modelData, root.beat)
            readonly property real fraction: timerCard.modelData.total > 0 ? Math.max(0, Math.min(1, timerCard.remainingMs / timerCard.modelData.total)) : 0

            width: root.width
            rowHeight: Math.max(Appearance.sizes.rowHeight, remaining.implicitHeight + Appearance.padding.small * 2 + track.height + Appearance.padding.small)
            tappable: true

            onTapped: Clock.toggleTimer(timerCard.modelData.id)
            onDismissed: Clock.removeTimer(timerCard.modelData.id)

            StyledText {
                id: remaining

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.top: parent.top
                anchors.topMargin: Appearance.padding.small

                text: root.clockText(timerCard.remainingMs)
                font.pixelSize: Appearance.font.size.large

                color: timerCard.modelData.finished ? Appearance.colour.accent : timerCard.modelData.paused ? Appearance.colour.textFaint : Appearance.colour.text
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: timerCard.discSpace
                anchors.baseline: remaining.baseline

                text: `of ${root.clockText(timerCard.modelData.total)}`
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }

            G2Rect {
                id: track

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small

                height: Appearance.sizes.sliderHeight
                radius: height / 2
                color: Appearance.colour.fill

                G2Rect {
                    width: drain.value
                    height: parent.height
                    radius: height / 2
                    color: Appearance.colour.text
                    opacity: 0.55
                }
            }

            Follow {
                id: drain

                target: timerCard.fraction * track.width
                speed: Appearance.anim.trackSpeed
            }
        }
    }

    Item {
        id: setter

        width: parent.width
        height: fields.height

        Row {
            id: fields

            anchors.left: parent.left

            spacing: Appearance.padding.small

            ScrubField {
                value: root.setHours
                to: 23
                detent: 1
                onMoved: v => root.setHours = v
            }

            StyledText {
                height: root.scrubHeight
                verticalAlignment: Text.AlignVCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ScrubField {
                value: root.setMinutes
                detent: root.scrubDetent
                onMoved: v => root.setMinutes = v
            }

            StyledText {
                height: root.scrubHeight
                verticalAlignment: Text.AlignVCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ScrubField {
                value: root.setSeconds
                detent: root.scrubDetent
                onMoved: v => root.setSeconds = v
            }
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: fields.verticalCenter

            visible: root.composedSeconds > 0
            text: "Start"
            onClicked: Clock.startTimer(root.composedSeconds, "")
        }
    }

    Item {
        id: presets

        width: parent.width
        height: childrenRect.height

        Repeater {
            model: root.timerPresets

            delegate: Button {
                required property int index
                required property var modelData

                readonly property int count: root.timerPresets.length

                x: count > 1 ? index * (presets.width - width) / (count - 1) : (presets.width - width) / 2
                width: (presets.width - Appearance.padding.small * (count - 1)) / count

                text: `${modelData}m`
                onClicked: Clock.startTimer(modelData * 60, "")
            }
        }
    }

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "ALARM"
    }

    Repeater {
        model: root.alarmRows

        delegate: Card {
            id: alarmCard

            required property var modelData

            readonly property bool open: root.editing === alarmCard.modelData.id

            width: root.width
            rowHeight: head.height + (alarmCard.open ? editor.implicitHeight + Appearance.padding.normal : 0)
            tappable: true

            onTapped: root.editing = alarmCard.open ? "" : alarmCard.modelData.id
            onDismissed: Clock.removeAlarm(alarmCard.modelData.id)

            Item {
                id: head

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                height: Math.max(Appearance.sizes.rowHeight, times.implicitHeight + Appearance.padding.small * 2)

                Column {
                    id: times

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: armed.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: `${Clock.pad2(alarmCard.modelData.hour)}:${Clock.pad2(alarmCard.modelData.minute)}`
                        font.pixelSize: Appearance.font.size.normal
                    }

                    StyledText {
                        width: parent.width
                        text: root.alarmDetail(alarmCard.modelData)
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }

                Toggle {
                    id: armed

                    anchors.right: parent.right
                    anchors.rightMargin: alarmCard.discSpace
                    anchors.verticalCenter: parent.verticalCenter

                    checked: alarmCard.modelData.armed
                    onToggled: Clock.setAlarmArmed(alarmCard.modelData.id, !alarmCard.modelData.armed)
                }
            }

            Column {
                id: editor

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.top: head.bottom
                anchors.topMargin: Appearance.padding.normal

                visible: alarmCard.open
                spacing: Appearance.padding.small

                Row {
                    spacing: Appearance.padding.small

                    ScrubField {
                        value: alarmCard.modelData.hour
                        to: 23
                        detent: 1

                        zeroIsEmpty: false
                        onMoved: v => Clock.setAlarm(alarmCard.modelData.id, {
                                hour: v
                            })
                    }

                    StyledText {
                        height: root.scrubHeight
                        verticalAlignment: Text.AlignVCenter
                        text: ":"
                        font.pixelSize: Appearance.font.size.large
                        color: Appearance.colour.textFaint
                    }

                    ScrubField {
                        value: alarmCard.modelData.minute
                        detent: root.scrubDetent
                        zeroIsEmpty: false
                        onMoved: v => Clock.setAlarm(alarmCard.modelData.id, {
                                minute: v
                            })
                    }
                }

                Item {
                    id: days

                    width: parent.width
                    height: childrenRect.height

                    Repeater {
                        model: 7

                        delegate: Button {
                            required property int index

                            x: index * (days.width - width) / 6
                            width: (days.width - Appearance.padding.small * 6) / 7

                            text: Qt.locale().dayName(index + 1, Locale.NarrowFormat).toUpperCase()
                            checkable: true
                            checked: alarmCard.modelData.days.includes(index)
                            onToggled: {
                                const was = alarmCard.modelData.days;
                                Clock.setAlarm(alarmCard.modelData.id, {
                                    days: was.includes(index) ? was.filter(d => d !== index) : [...was, index]
                                });
                            }
                        }
                    }
                }

                Item {
                    id: modes

                    width: parent.width
                    height: childrenRect.height

                    Repeater {
                        model: [
                            {
                                key: "none",
                                label: "Nothing"
                            },
                            {
                                key: "command",
                                label: "Command"
                            },
                            {
                                key: "cloud",
                                label: "Cloud"
                            }
                        ]

                        delegate: Button {
                            required property int index
                            required property var modelData

                            x: index * (modes.width - width) / 2
                            width: (modes.width - Appearance.padding.small * 2) / 3

                            text: modelData.label
                            checkable: true
                            checked: alarmCard.modelData.mode === modelData.key
                            onToggled: Clock.setAlarm(alarmCard.modelData.id, {
                                mode: modelData.key
                            })
                        }
                    }
                }

                Field {
                    width: parent.width

                    visible: alarmCard.modelData.mode !== "none"

                    autoFocus: false
                    seed: alarmCard.modelData.payload
                    placeholder: alarmCard.modelData.mode === "cloud" ? "what to ask" : "what to run"
                    onCommitted: text => Clock.setAlarm(alarmCard.modelData.id, {
                            payload: text
                        })
                }
            }
        }
    }

    Button {
        width: parent.width
        text: "Add an alarm"
        onClicked: {
            const id = Clock.addAlarm();
            if (id)
                root.editing = id;
        }
    }
}
