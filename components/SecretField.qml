import QtQuick
import QtQuick.Shapes
import qs.config
import "lobes.js" as Lobes

Item {
    id: root

    property string placeholder: ""

    property bool busy: false

    property bool alarm: false

    property bool claims: false

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

        speed: Appearance.anim.revealSpeed
        target: field.activeFocus ? 1 : 0
        epsilon: 0.005
    }

    SquircleRect {
        anchors.fill: parent

        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        stroke: root.alarm ? Appearance.colour.alarm : field.activeFocus ? Appearance.colour.accent : Appearance.colour.seam

        strokeWidth: Appearance.sizes.seam * (1 + focusIn.value)
        opacity: root.busy ? 0.5 : 1
    }

    TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large

        enabled: !root.busy
        echoMode: TextInput.NoEcho
        cursorDelegate: Item {}
        activeFocusOnTab: true

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: "transparent"

        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancelled()

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
    Component.onCompleted: root.land()
    Component.onDestruction: Prompts.release(root)

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter

        text: root.placeholder
        color: Appearance.colour.textGhost

        opacity: root.empty ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
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

        speed: Appearance.anim.scrollSpeed
        target: root.offset
    }

    Component {
        id: markShape

        Shape {
            id: mark

            property int index: 0

            readonly property bool standing: mark.index < root.count

            property bool ready: false

            Component.onCompleted: Qt.callLater(() => mark.ready = true)

            x: root.lead + mark.index * root.pitch
            y: (strip.height - height) / 2
            width: root.markSize
            height: root.markSize

            preferredRendererType: Shape.CurveRenderer

            visible: mark.opacity > 0.004

            opacity: mark.ready && mark.standing ? 1 : 0
            scale: mark.ready && mark.standing ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.normal

                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }

            ShapePath {

                fillColor: root.alarm ? Appearance.colour.alarm : Appearance.colour.spectrum[mark.index % Appearance.colour.spectrum.length]
                strokeWidth: 0
                strokeColor: "transparent"

                PathSvg {

                    path: Lobes.path(mark.index, root.markSize)
                }
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
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        clip: true

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
            radius: width / 2
            color: root.alarm ? Appearance.colour.alarm : Appearance.colour.accent
            visible: field.activeFocus && !root.empty
        }
    }
}
