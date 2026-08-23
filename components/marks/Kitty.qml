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
// and put back together in the shell's palette. THE WHOLE MARK: the cat looking
// over the terminal window, which is what kitty's logo is. Cropping it to the
// face was tried and it was just a cat.
//
// WHAT EACH PART IS MADE OF, and the rule is that only the eyes are a colour:
//
//   the face      the ink it is handed, full strength. It is the part that
//                 identifies the application, so it is the part that reads.
//   the window    the same ink, held back, so the face is in front of it
//                 without either of them needing an outline. This shell does
//                 not draw borders (see Chassis.qml); one plane in front of
//                 another is said with weight.
//   the paws      between the two, because that is where they are.
//   the prompt    NOTHING. The `>` and the `_` are holes in the window's path,
//                 so what shows through them is whatever the mark is standing
//                 on: a plain cell, the hover marker, the accent sheet of the
//                 workspace you are on. The drawing is right on all of them
//                 without knowing about any of them, and it is why the prompt
//                 still reads at 25px where a painted one would have to guess
//                 at the colour behind it.
//   the eyes      the theme's accent, and the whites are holes like the prompt.
//                 Two pixels of it at mark size, which is all a face needs.
//
// THE WHISKERS ARE GONE, and they are the only thing that is. Four sprays of
// hairline strokes come out at a pixel and a half in the sidebar and read as
// dirt around the face rather than as whiskers. Everything else survives the
// size.
//
// The path data is the official file's, untouched. The box below is the drawing's
// own bounding box with the whiskers out of it, so the mark fills the size it is
// given instead of sitting in the middle of the empty margin the file has.
Item {
    id: root

    // THE INK, handed in by whatever is drawing the mark, exactly as a status
    // gauge's mark takes its colour from the gauge it sits in. The accent is
    // taken from the theme directly: it is the one part of this that is not the
    // ink and never follows it.
    property color colour: Appearance.colour.text

    property real size: Appearance.font.iconSize

    // How far back the window and the paws sit from the face, as a fraction of
    // the ink. Two planes and a half, which at this size is the difference
    // between a cat in front of a terminal and a smudge.
    readonly property real behind: 0.7
    readonly property real between: 0.85

    // THE DRAWING'S OWN BOX, in the logo's units, measured off the official file
    // with the whiskers excluded: x 24.75 to 215.25, and y 22.5 to 217.5 once the
    // file's own translate(0 -812.362) is undone.
    readonly property real artX: 24.75
    readonly property real artY: 834.862
    readonly property real artW: 190.5
    readonly property real artH: 195

    implicitWidth: Math.round(root.size * root.artW / root.artH)
    implicitHeight: root.size

    Item {
        anchors.centerIn: parent

        width: root.artW
        height: root.artH
        scale: root.size / root.artH

        Shape {
            // Big enough to hold the path's own coordinates, which live where
            // the file put them; the offset above is what brings the drawing into
            // this box. Nothing clips, so the size is only the node's bounds.
            width: 240
            height: 240
            x: -root.artX
            y: -root.artY

            preferredRendererType: Shape.CurveRenderer

            // THE TERMINAL, with the prompt as holes. Even-odd, because the `>`
            // and the `_` are subpaths inside the window's own outline and this
            // is what makes them holes rather than two more filled shapes.
            ShapePath {
                fillColor: Qt.rgba(root.colour.r, root.colour.g, root.colour.b, root.colour.a * root.behind)
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M67.896 1029.71h104.208a7.065 7.065 0 0 0 7.065-7.066V918.436a7.065 7.065 0 0 0-7.065-7.065H67.896a7.065 7.065 0 0 0-7.065 7.065v104.208a7.065 7.065 0 0 0 7.065 7.065m55.813-38.35h37.444a4.239 4.239 0 0 1 0 8.479H123.71a4.239 4.239 0 0 1 0-8.478m-45.032-45.71a4.239 4.239 0 0 1 5.991-5.99l26.48 26.464a4.24 4.24 0 0 1 0 5.992l-26.48 26.48a4.239 4.239 0 0 1-5.991-5.992l23.484-23.484z"
                }
            }

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

            // THE PAWS, over the window's top edge, which is where a cat looking
            // over something puts them.
            ShapePath {
                fillColor: Qt.rgba(root.colour.r, root.colour.g, root.colour.b, root.colour.a * root.between)
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M52.6 893.563c-6.382 0-11.743 3.32-14.296 8.425h-.766c-6.893 0-12.765 5.106-12.765 11.489 0 8.935 9.19 13.786 17.615 10.722 5.106 7.404 16.084 7.915 20.17 0 6.126-.255 16.083-1.276 17.615-10.722 1.021-6.383-5.617-11.489-12.765-11.489h-.766c-2.042-5.106-7.659-8.425-14.041-8.425m134.8 0c6.382 0 11.743 3.32 14.296 8.425h.766c3.574 0 12.765 5.106 12.765 11.489 0 8.935-9.19 13.786-17.615 10.722-5.107 7.404-16.084 7.915-20.17 0-6.126-.255-16.083-1.276-17.615-10.722-1.021-6.383 9.19-11.489 12.765-11.489h.766c2.042-5.106 7.659-8.425 14.041-8.425"
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
