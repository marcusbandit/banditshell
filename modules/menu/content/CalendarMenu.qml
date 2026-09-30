pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Column {
    id: root

    readonly property int columns: 7
    readonly property int rows: 6

    readonly property real cell: Math.max(Appearance.sizes.minTarget, root.width / root.columns)

    readonly property date today: clock.date

    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()

    readonly property bool showingToday: root.shownYear === root.today.getFullYear() && root.shownMonth === root.today.getMonth()

    signal relit

    readonly property var usageTones: [Appearance.colour.fill, Appearance.colour.fillStrong, Appearance.colour.fillStronger]

    property real slide: 0

    readonly property int gestureSign: Appearance.sizes.calendarRightGoesForward ? 1 : -1

    spacing: Appearance.padding.normal

    SystemClock {
        id: clock

        precision: SystemClock.Minutes

        enabled: root.visible
    }

    function page(delta: int): void {
        const to = new Date(root.shownYear, root.shownMonth + delta, 1);
        root.shownYear = to.getFullYear();
        root.shownMonth = to.getMonth();
        root.slide += delta * months.width;
    }

    function glide(): void {
        settle.value = root.slide;
    }

    function home(): void {

        const delta = (root.today.getFullYear() * 12 + root.today.getMonth()) - (root.shownYear * 12 + root.shownMonth);
        if (delta === 0)
            return;
        if (Math.abs(delta) === 1) {
            root.page(delta);
            root.glide();

            root.relit();
            return;
        }
        root.shownYear = root.today.getFullYear();
        root.shownMonth = root.today.getMonth();
        root.slide = 0;
        settle.value = 0;
        root.relit();
    }

    function poke(x: real, y: real): void {

        if (y < 0)
            return;
        const strip = x - root.slide;
        const paneIx = Math.floor(strip / months.width);
        const col = Math.min(root.columns - 1, Math.floor((strip - paneIx * months.width) / root.cell));
        const row = Math.min(root.rows - 1, Math.floor(y / root.cell));
        const first = new Date(root.shownYear, root.shownMonth + paneIx, 1);
        const lead = (first.getDay() + 6) % 7;
        const day = new Date(first.getFullYear(), first.getMonth(), 1 - lead + row * root.columns + col);

        const delta = (day.getFullYear() * 12 + day.getMonth()) - (root.shownYear * 12 + root.shownMonth);
        if (delta === 0)
            return;
        root.page(delta);
        root.glide();
    }

    Item {
        id: heading

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, monthName.implicitHeight)

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            opacity: homeTap.pressed || (homeTap.containsMouse && !todayPill.hovered) ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: homeTap

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.home()
        }

        StyledText {
            id: monthName

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
            font.pixelSize: Appearance.font.size.normal
            font.bold: true
        }

        Button {
            id: todayPill

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.showingToday
            text: "Today"

            onClicked: root.home()
        }
    }

    Item {
        id: initials

        width: parent.width
        height: childrenRect.height

        Repeater {
            model: root.columns

            delegate: StyledText {
                required property int index

                x: index * root.cell
                width: root.cell
                horizontalAlignment: Text.AlignHCenter

                text: Qt.locale().dayName(index + 1, Locale.NarrowFormat).toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }
        }
    }

    Item {
        id: months

        width: parent.width
        height: root.cell * root.rows

        MouseArea {
            id: pager

            property real fromX: 0
            property real fromY: 0
            property real startSlide: 0

            property real originTravel: 0

            property bool paging: false
            property bool spent: false

            property real velocity: 0

            property real lastTravel: 0

            anchors.fill: parent

            anchors.topMargin: -(initials.height + root.spacing * 2)

            preventStealing: true

            cursorShape: pager.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            function begin(): void {
                pager.startSlide = root.slide;
                pager.originTravel = 0;
                pager.lastTravel = 0;
                pager.paging = false;
                pager.spent = false;
                pager.velocity = 0;
            }

            function advance(dx: real, dy: real): void {
                if (pager.spent)
                    return;

                const travel = dx * root.gestureSign;
                const step = travel - pager.lastTravel;
                pager.lastTravel = travel;
                pager.velocity += (step - pager.velocity) * 0.4;

                if (!pager.paging) {

                    if (Math.abs(travel) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                        return;

                    if (Math.abs(dy) > Math.abs(travel)) {
                        pager.spent = true;
                        return;
                    }

                    pager.paging = true;

                    pager.originTravel = travel;
                    pager.startSlide = root.slide;
                    return;
                }

                root.slide = Math.max(-months.width, Math.min(months.width, pager.startSlide + (travel - pager.originTravel)));
            }

            function settle(): void {
                if (pager.paging) {

                    const half = Math.abs(root.slide) > months.width / 2;
                    const onward = root.slide * pager.velocity > 0 && Math.abs(pager.velocity) >= Appearance.sizes.flickVelocity;
                    if (half || onward)
                        root.page(root.slide > 0 ? -1 : 1);
                    root.glide();
                }
                pager.paging = false;
                pager.spent = false;
            }

            onPressed: mouse => {

                scroll.finish();

                pager.fromX = pager.x + mouse.x;
                pager.fromY = pager.y + mouse.y;
                pager.begin();
            }

            onPositionChanged: mouse => {
                if (pager.pressed)
                    pager.advance(pager.x + mouse.x - pager.fromX, pager.y + mouse.y - pager.fromY);
            }

            onReleased: {

                if (!pager.paging && !pager.spent)
                    root.poke(pager.fromX, pager.fromY);

                pager.settle();
            }

            onCanceled: {

                if (pager.paging)
                    root.glide();
                pager.paging = false;
                pager.spent = false;
            }

            onWheel: wheel => {
                if (!scroll.feed(wheel))
                    return;

                wheel.accepted = pager.paging || (!pager.spent && Math.abs(scroll.dx) >= Math.abs(scroll.dy));
            }

            ScrollGesture {
                id: scroll

                armed: !pager.pressed

                onBegan: pager.begin()
                onMoved: (dx, dy) => pager.advance(dx, dy)
                onEnded: pager.settle()
            }
        }

        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            Repeater {
                model: [-1, 0, 1]

                delegate: Item {
                    id: pane

                    required property int modelData

                    readonly property date first: new Date(root.shownYear, root.shownMonth + pane.modelData, 1)

                    readonly property int lead: (pane.first.getDay() + 6) % 7

                    readonly property int todayIndex: pane.first.getFullYear() === root.today.getFullYear() && pane.first.getMonth() === root.today.getMonth() ? pane.lead + root.today.getDate() - 1 : -1

                    property real glow: 1

                    x: pane.modelData * months.width + root.slide
                    width: months.width
                    height: months.height

                    Connections {
                        target: root

                        function onRelit(): void {
                            if (pane.todayIndex >= 0)
                                relight.restart();
                        }
                    }

                    NumberAnimation {
                        id: relight

                        target: pane
                        property: "glow"
                        from: 0
                        to: 1
                        duration: Appearance.anim.slow
                    }

                    Repeater {
                        model: root.columns * root.rows

                        delegate: StyledText {
                            id: cellText

                            required property int index

                            readonly property date day: new Date(pane.first.getFullYear(), pane.first.getMonth(), 1 - pane.lead + cellText.index)
                            readonly property bool inMonth: cellText.day.getMonth() === pane.first.getMonth()
                            readonly property bool onAccent: cellText.index === pane.todayIndex

                            readonly property var usage: cellText.inMonth ? Usage.forDay(cellText.day) : null

                            readonly property real awake: cellText.usage ? Math.min(1, cellText.usage.minutes / (Appearance.sizes.usageCapHours * 60)) : 0

                            readonly property int level: cellText.awake > 0 ? Math.min(root.usageTones.length, Math.ceil(cellText.awake * root.usageTones.length)) : 0

                            x: (cellText.index % root.columns) * root.cell
                            y: Math.floor(cellText.index / root.columns) * root.cell
                            width: root.cell
                            height: root.cell
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: `${cellText.day.getDate()}`
                            font.pixelSize: Appearance.font.size.normal

                            color: cellText.onAccent ? Appearance.colour.accentText : cellText.inMonth ? Appearance.colour.text : Appearance.colour.textFaint

                            Loader {
                                id: tile

                                z: -1
                                active: cellText.onAccent || cellText.level > 0
                                x: (root.cell - tile.width) / 2
                                y: (root.cell - tile.height) / 2
                                width: root.cell - Appearance.padding.small
                                height: tile.width

                                sourceComponent: G2Rect {
                                    radius: Appearance.rounding.normal
                                    color: cellText.onAccent ? Appearance.colour.accent : root.usageTones[cellText.level - 1]

                                    opacity: cellText.onAccent ? pane.glow : 1
                                }
                            }
                        }
                    }
                }
            }
        }

        Follow {
            id: settle

            speed: Appearance.anim.revealSpeed
            target: 0

            onValueChanged: if (!pager.paging)
                root.slide = settle.value
        }
    }
}
