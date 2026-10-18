import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property color color: Appearance.colour.text
    property int pixelSize: Appearance.font.size.small
    property bool running: true
    property int pause: 2000
    property real speed: Appearance.font.size.small * 2.5

    readonly property real fade: Math.round(root.pixelSize * 1.4)
    readonly property real gap: Math.round(root.pixelSize * 2.5)
    readonly property real span: line.shownWidth + root.gap
    readonly property bool overflows: line.shownWidth > root.width + 0.5

    property real offset: 0

    implicitWidth: line.shownWidth
    implicitHeight: line.implicitHeight
    baselineOffset: line.baselineOffset
    clip: true

    onTextChanged: {
        root.offset = 0;
        if (marquee.running)
            marquee.restart();
    }

    SequentialAnimation {
        id: marquee

        running: root.running && root.overflows && root.visible && !Appearance.lessMotion
        loops: Animation.Infinite

        PauseAnimation {
            duration: root.pause
        }

        NumberAnimation {
            target: root
            property: "offset"
            from: 0
            to: -root.span
            duration: Math.max(1, root.span / Math.max(1, root.speed) * 1000)
            easing.type: Easing.InOutSine
        }

        PropertyAction {
            target: root
            property: "offset"
            value: 0
        }

        onRunningChanged: if (!marquee.running)
            root.offset = 0
    }

    Item {
        anchors.fill: parent

        layer.enabled: root.overflows
        layer.effect: ShaderEffect {
            readonly property vector4d fades: Qt.vector4d(Math.min(root.fade, -root.offset, root.span + root.offset), root.fade, width, 0)

            fragmentShader: Qt.resolvedUrl("edgefade.frag.qsb")
        }

        CrossfadeText {
            id: line

            x: root.offset
            width: line.shownWidth
            text: root.text
            color: root.color
            pixelSize: root.pixelSize
            elide: Text.ElideNone
        }

        CrossfadeText {
            x: root.offset + root.span
            width: line.shownWidth
            visible: root.overflows
            text: root.text
            color: root.color
            pixelSize: root.pixelSize
            elide: Text.ElideNone
        }
    }
}
