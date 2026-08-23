import QtQuick
import QtQuick.Shapes
import qs.config

// KITTY, DRAWN IN OUR COLOURS.
//
// The icon theme ships kitty's real artwork and it is a photograph next to
// everything else in this bar: an orange cat on a black terminal, in a band made
// of one grey and one accent. Tinting it flat (`mono:`) does not work either,
// because the logo IS its parts, and a silhouette of a cat behind a terminal
// window is a blob.
//
// So this is the official mark (kovidgoyal/kitty, logo/kitty.svg), taken apart
// and put back together in the shell's palette: the face carries the ink it is
// handed, the eyes are the theme's accent, and the eye whites are not painted at
// all. They are holes in the path, so what shows through them is whatever the
// mark is standing on, which means the drawing is right on a plain cell, under
// the hover marker and under the accent sheet, without knowing about any of them.
//
// SIMPLIFIED TO THE FACE. The full logo is a cat looking over a terminal window
// with a prompt in it, and at the size a sidebar mark is drawn the prompt is
// three pixels of mush and the face is a smudge above it. Cropped to the head,
// the same 25px is all face: ears, eyes, nose, unmistakably this application. The
// terminal was the half that said "a terminal", and in a column that is already
// a list of applications that was the half worth losing.
//
// The path data is the official file's, untouched. The box below is its own
// bounding box, so this component is `size` wide and as tall as the face
// actually is rather than padded out to a square it does not fill.
Item {
    id: root

    // THE INK, handed in by whatever is drawing the mark, exactly as a status
    // gauge's mark takes its colour from the gauge it sits in. The accent is
    // taken from the theme directly: it is the one part of this that is not the
    // ink and never follows it.
    property color colour: Appearance.colour.text

    property real size: Appearance.font.iconSize

    // THE FACE'S OWN BOX, in the logo's units, measured off the official file:
    // the head path spans x 45.5 to 194.5 and, once the file's own
    // translate(0 -812.362) is undone, y 22.5 to 99.5.
    readonly property real artX: 45.5
    readonly property real artY: 834.862
    readonly property real artW: 149
    readonly property real artH: 77

    implicitWidth: root.size
    implicitHeight: Math.round(root.size * root.artH / root.artW)

    Item {
        anchors.centerIn: parent

        width: root.artW
        height: root.artH
        scale: root.size / root.artW

        Shape {
            // Big enough to hold the path's own coordinates, which live where
            // the file put them; the offset above is what brings the face into
            // this box. Nothing clips, so the size is only the node's bounds.
            width: 240
            height: 240
            x: -root.artX
            y: -root.artY

            preferredRendererType: Shape.CurveRenderer

            // THE FACE, with the eyes as holes: the file draws them as subpaths
            // of the head under an even-odd rule, so they have to be filled the
            // same way here or the cat comes out blind.
            ShapePath {
                fillColor: root.colour
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M193.128 836.886c-4.596-4.85-25.53 1.022-38.295 8.936-9.957-5.106-21.956-8.17-34.721-8.17-13.02 0-25.02 3.064-34.977 8.17-12.765-7.914-33.955-14.042-38.295-8.936-4.595 5.106 3.32 26.296 12.765 38.04-.766 3.064-1.276 6.128-1.276 9.446 0 10.212 4.34 19.659 11.744 27.318h42.124c-1.276-2.553.511-4.085 8.17-4.085 7.659.255 9.19 1.532 8.17 4.085h42.124c7.404-7.66 11.744-17.36 11.744-27.318 0-3.318-.51-6.382-1.276-9.446 8.935-11.744 16.594-33.189 11.999-38.04m-97.015 67.4c-8.935 0-16.339-7.404-16.339-16.34s7.404-16.339 16.34-16.339 16.339 7.404 16.339 16.34-7.404 16.339-16.34 16.339m47.997 0c-8.936 0-16.34-7.404-16.34-16.34s7.404-16.339 16.34-16.339 16.34 7.404 16.34 16.34-7.15 16.339-16.34 16.339"
                }
            }

            // THE EYES. The one saturated thing in the mark, and the reason the
            // face reads as a face at four pixels an eye.
            ShapePath {
                fillColor: Appearance.colour.accent
                strokeColor: "transparent"

                PathSvg {
                    path: "M96.085 898.143c1.881 0 3.386-3.574 3.386-8.17 0-4.595-1.505-8.169-3.386-8.169-1.88 0-3.385 3.574-3.385 8.17 0 4.595 1.504 8.17 3.385 8.17"
                }
            }

            ShapePath {
                fillColor: Appearance.colour.accent
                strokeColor: "transparent"

                PathSvg {
                    path: "M143.542 898.143c1.881 0 3.386-3.574 3.386-8.17 0-4.595-1.505-8.169-3.386-8.169-1.88 0-3.386 3.574-3.386 8.17 0 4.595 1.505 8.17 3.386 8.17"
                }
            }
        }
    }
}
