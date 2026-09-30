import QtQuick
import qs.config

Item {
    id: root

    property string full: ""

    property string brief: ""

    property int lines: 3
    property int fullLines: 40

    property bool unfolded: false

    property alias font: label.font
    property alias color: label.color
    property alias topPadding: label.topPadding

    readonly property real advance: ruler.advanceWidth / ruler.text.length
    readonly property int limit: root.lines * Math.max(1, Math.floor(root.width / Math.max(1, root.advance)))

    readonly property string folded: root.shorten(root.brief || root.full, root.limit)

    readonly property bool foldable: root.folded !== root.full

    function shorten(s: string, limit: int): string {
        if (s.length <= limit)
            return s;
        const cut = s.slice(0, limit);
        const space = cut.lastIndexOf(" ");
        return `${(space > limit * 0.6 ? cut.slice(0, space) : cut).replace(/\s+$/, "")}…`;
    }

    implicitWidth: label.implicitWidth
    implicitHeight: grow.value

    clip: true

    Component.onCompleted: grow.snap()

    Follow {
        id: grow

        target: label.implicitHeight
        speed: Appearance.anim.revealSpeed
    }

    StyledText {
        id: label

        width: root.width

        text: root.unfolded ? root.full : root.folded
        wrapMode: Text.Wrap

        maximumLineCount: root.unfolded ? root.fullLines : root.lines
        elide: Text.ElideRight
    }

    TextMetrics {
        id: ruler

        font: label.font
        text: "0123456789"
    }
}
