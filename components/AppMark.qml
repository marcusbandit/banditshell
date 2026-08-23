import QtQuick
import qs.config
import qs.components
import qs.components.marks

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
//   draw:Kitty            a mark this shell draws ITSELF, as vectors, in the
//                         theme's colours: components/marks/Kitty.qml, named in
//                         the table below. For the
//                         handful of applications whose own artwork is a
//                         photograph next to a bar made of one grey and one
//                         accent, and whose silhouette is a blob. It takes
//                         `colour` off this mark exactly as a status gauge's
//                         mark takes it off the gauge.
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

    // A MARK THE SHELL DRAWS ITSELF, from components/marks, by the name the spec
    // carries. Its ink is handed down the same way every other kind's is.
    //
    // A COMPONENT PER MARK rather than a URL built from the name, which is what
    // this was and which cost an hour: a file reached only through a string at
    // runtime is not part of the module graph, so Quickshell does not watch it,
    // and editing one changes nothing until the shell is restarted while every
    // other file in the project hot-reloads. Named as a type, it reloads like
    // everything else. The price is a line in the table below per drawn mark,
    // which is the price of the file being real.
    readonly property var drawnMarks: ({
            Kitty: kittyMark
        })

    Loader {
        id: drawn

        anchors.centerIn: parent
        active: root.kind === "draw" && !!root.value
        sourceComponent: drawn.active ? root.drawnMarks[root.value] ?? null : null

        onLoaded: {
            drawn.item.colour = Qt.binding(() => root.color);
            drawn.item.size = Qt.binding(() => root.size);
        }
    }

    Component {
        id: kittyMark

        Kitty {}
    }

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

    // FITTED, not merely scaled: icon files disagree about how much of their own
    // canvas they use, and a row of them at the same box size comes out at three
    // different sizes. See FittedImage.
    FittedImage {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: root.kind === "image" || root.kind === "mono"
        source: visible ? root.value : ""
        tint: root.kind === "mono"
        colour: root.color
    }
}
