import QtQuick
import qs.config
import qs.components
import qs.services
import "secret-marks.js" as SecretMarks

Item {
    id: root

    property string placeholder: ""

    property bool busy: false

    property bool alarm: false

    property bool claims: false

    property bool framed: true

    readonly property real inset: root.framed ? Appearance.padding.large : 0

    property real textSize: Appearance.font.size.small

    property real markSize: Appearance.font.size.small

    readonly property int count: field.length

    readonly property bool empty: root.count === 0

    signal accepted(string secret)
    signal cancelled

    function clear(): void {
        field.text = "";
        if (root.visible)
            field.forceActiveFocus();
    }

    function cancel(): void {
        field.text = "";
        root.cancelled();
    }

    function submit(): void {
        if (root.busy || !field.length)
            return;
        const secret = field.text;
        field.text = "";
        root.accepted(secret);
    }

    implicitHeight: Math.round(em.height * 3)
    implicitWidth: Appearance.sizes.lockDot * 12

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "M"
    }

    readonly property real spacing: Math.round(root.markSize / 2.5)

    readonly property real pitch: root.markSize + root.spacing

    property int maxMarks: 64

    readonly property int shown: Math.min(root.count, root.maxMarks)

    readonly property real lead: root.spacing

    readonly property real content: root.lead + root.shown * root.pitch

    Follow {
        id: focusIn

        speed: Appearance.animation.revealSpeed
        target: field.activeFocus ? 1 : 0
        epsilon: 0.005
    }

    SquircleRect {
        anchors.fill: parent
        visible: root.framed

        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        stroke: root.alarm ? Appearance.colour.alarm : field.activeFocus ? Appearance.colour.accent : Appearance.colour.seam

        strokeWidth: Appearance.stroke.ring * (1 + focusIn.value)
        opacity: root.busy ? Appearance.opacity.disabled : 1
    }

    TextInput {
        id: field

        readonly property bool typable: true

        anchors.fill: parent
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset

        enabled: !root.busy
        echoMode: TextInput.NoEcho
        cursorDelegate: Item {}
        activeFocusOnTab: true

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: "transparent"

        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancel()

        onCursorPositionChanged: root.reveal()

        readonly property bool surfaceActive: field.Window.active
        onSurfaceActiveChanged: if (field.surfaceActive && root.visible)
            field.forceActiveFocus()
    }

    function stake(): void {
        if (root.claims && root.visible) {
            Prompts.request(root);
            field.forceActiveFocus();
        } else {
            Prompts.release(root);
        }
    }

    function land(): void {
        root.stake();
        if (root.visible)
            field.forceActiveFocus();
    }

    onVisibleChanged: root.land()
    onClaimsChanged: root.land()
    onBusyChanged: if (!root.busy)
        root.land()
    Component.onCompleted: root.land()
    Component.onDestruction: Prompts.release(root)

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter

        text: root.placeholder
        font.pixelSize: root.textSize
        color: Appearance.colour.textFaint

        opacity: placeholderFade.value

        Follow {
            id: placeholderFade

            target: root.empty ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    property real offset: 0

    function caretAt(position: int): real {
        return root.lead + Math.min(position, root.maxMarks) * root.pitch - root.spacing / 2;
    }

    function reveal(): void {
        const view = marks.width;
        if (view <= 0 || root.content <= view) {
            root.offset = 0;
            return;
        }

        const caret = root.caretAt(field.cursorPosition);

        let want = Math.max(root.offset, caret + root.pitch - view);
        want = Math.min(want, caret - root.lead);
        root.offset = Math.max(0, Math.min(want, root.content - view));
    }

    onCountChanged: root.reveal()
    onWidthChanged: root.reveal()

    Follow {
        id: pan

        speed: Appearance.animation.scrollSpeed
        target: root.offset
    }

    Component {
        id: markShape

        Item {
            id: mark

            property int index: 0

            readonly property bool standing: mark.index < root.count

            readonly property var form: SecretMarks.shape(mark.index)

            property bool ready: false

            Component.onCompleted: Qt.callLater(() => mark.ready = true)

            x: root.lead + mark.index * root.pitch
            y: (strip.height - height) / 2
            width: root.markSize
            height: root.markSize

            visible: markFade.value > 0.004

            opacity: markFade.value
            scale: markGrow.value

            Follow {
                id: markFade

                target: mark.ready && mark.standing ? 1 : 0
                speed: Appearance.animation.trackSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            Follow {
                id: markGrow

                target: mark.ready && mark.standing ? 1 : 0
                speed: Appearance.animation.trackSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            SquircleRect {
                anchors.centerIn: parent
                width: root.markSize * mark.form.width
                height: root.markSize * mark.form.height
                rotation: mark.form.turn
                pill: "object"
                color: root.alarm ? Appearance.colour.alarm : Appearance.colour.spectrum[mark.index % Appearance.colour.spectrum.length]
            }
        }
    }

    property var made: []

    function grow(): void {
        while (root.made.length < root.shown && root.made.length < root.maxMarks)
            root.made.push(markShape.createObject(strip, {
                index: root.made.length
            }));
    }

    onShownChanged: root.grow()

    Item {
        id: marks

        anchors.fill: parent
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        clip: true
        opacity: !root.framed && root.busy ? Appearance.opacity.disabled : 1

        Item {
            id: strip

            x: -pan.value
            y: 0
            width: parent.width
            height: parent.height
        }

        SquircleRect {
            x: strip.x + root.caretAt(field.cursorPosition) - width / 2
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(2, Math.round(root.markSize / 6))
            height: root.markSize
            pill: "object"
            color: root.alarm ? Appearance.colour.alarm : Appearance.colour.accent
            visible: field.activeFocus && !root.empty
        }
    }
}
