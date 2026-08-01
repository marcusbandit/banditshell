import QtQuick
import qs.config

// A hairline.
//
// One device pixel of the palette's light end at about a tenth opacity, which is
// just enough to say "these are different groups" and not enough to be seen as a
// line. It replaced an engraved two-tone groove: that read as a decoration
// pretending to be machined metal, and decoration pretending is what makes an
// interface look cheap. Space does most of the separating here; this only marks
// the one boundary space alone would not carry.
Rectangle {
    implicitHeight: 1
    color: Appearance.colour.separator
}
