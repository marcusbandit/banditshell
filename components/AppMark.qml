import QtQuick
import QtQuick.Effects
import qs.config
import qs.components

// One window's mark, from a SPEC, which is a string with a scheme on the front.
//
// There are four kinds of thing an application's mark can be, and they are drawn
// by three different mechanisms, so the alternative to a scheme is four
// properties of which three are always empty and every caller has to know which
// combination means what:
//
//   symbol:web            a Material Symbols ligature. The shell's own set.
//   glyph:f2c6            a Nerd Fonts codepoint. Per-application line art,
//                         monochrome by construction, so it takes our colour.
//   mono:/path/x.svg      a file drawn as a silhouette in our colour. For the
//                         monochrome panel and symbolic icons that ship with
//                         most icon themes: they are ONE colour already, so
//                         tinting one is exact rather than a filter over
//                         somebody's artwork.
//   image:/path/x.svg     a file drawn as it is. The application's real icon,
//                         brand palette and all.
//
// An empty spec draws `fallback`, which is how "nothing has been chosen for this
// application yet" reaches the screen as the category glyph rather than as a
// hole.
Item {
    id: root

    property string spec: ""
    property string fallback: "apps"
    property color color: Appearance.colour.text
    property int size: Appearance.font.iconSize

    readonly property int mark: spec.indexOf(":")
    readonly property string kind: mark < 0 ? "" : spec.slice(0, mark)
    readonly property string value: mark < 0 ? "" : spec.slice(mark + 1)

    implicitWidth: size
    implicitHeight: size

    Icon {
        anchors.centerIn: parent
        visible: root.kind === "symbol" || root.kind === "" || root.kind === "glyph"
        size: root.size
        color: root.color
        name: root.kind === "symbol" && root.value ? root.value : root.fallback
        // A Nerd Font addresses a glyph by codepoint, so the spec carries the
        // number and this is where it becomes a character.
        glyph: root.kind === "glyph" && root.value ? String.fromCodePoint(parseInt(root.value, 16)) : ""
    }

    Image {
        id: image

        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        source: root.kind === "image" || root.kind === "mono" ? root.value : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        // The mono path draws through the effect instead, so the source itself
        // must not also be on screen.
        visible: root.kind === "image" && status === Image.Ready
    }

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.kind === "mono" && image.status === Image.Ready
        // A symbolic icon is a single colour with an alpha channel, so replacing
        // that colour outright is the whole operation: there is no luminance to
        // preserve and nothing of the original to lose.
        brightness: 1
        colorization: 1
        colorizationColor: root.color
    }
}
