import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property color color: Appearance.colour.text
    property int pixelSize: Appearance.font.size.small
    property int wrapMode: Text.NoWrap
    property int maximumLineCount: 1
    property int horizontalAlignment: Text.AlignLeft

    property real speed: Appearance.animation.revealSpeed

    property bool flip: false

    implicitWidth: Math.max(a.implicitWidth, b.implicitWidth)
    implicitHeight: (root.flip ? b : a).implicitHeight

    onTextChanged: {
        if ((root.flip ? b : a).text === root.text)
            return;
        root.flip = !root.flip;
        (root.flip ? b : a).text = root.text;
    }

    Component.onCompleted: a.text = root.text

    Follow {
        id: mix

        target: root.flip ? 1 : 0
        speed: root.speed
        epsilon: 0.004
    }

    StyledText {
        id: a

        width: root.width
        color: root.color
        font.pixelSize: root.pixelSize
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        elide: Text.ElideRight
        horizontalAlignment: root.horizontalAlignment
        opacity: 1 - mix.value
        visible: opacity > 0.01
    }

    StyledText {
        id: b

        width: root.width
        color: root.color
        font.pixelSize: root.pixelSize
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        elide: Text.ElideRight
        horizontalAlignment: root.horizontalAlignment
        opacity: mix.value
        visible: opacity > 0.01
    }
}
