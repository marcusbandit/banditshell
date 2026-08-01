import QtQuick
import qs.config
import qs.components

// The left panel.
//
// Flush against the screen edge, square where it meets it. The two corners on
// the right are CONCAVE: instead of the panel curling away from the top and
// bottom screen edges and leaving a notch, its right edge sweeps outward as it
// approaches them and arrives tangent to the edge. The panel reads as growing
// out of the screen border rather than floating in front of it.
//
// That flare lives outside `bodyWidth`, so the item is wider than the panel
// proper. `bodyWidth` is the real panel: content sits in it, and it is what the
// window reserves.
//
// Always visible for now; it will become summonable later.
G2Rect {
    id: root

    readonly property int bodyWidth: Appearance.sizes.sidebarWidth
    readonly property real flare: cornerExtent(Appearance.sizes.sidebarFlare)

    implicitWidth: bodyWidth + flare

    topLeftRadius: 0
    bottomLeftRadius: 0
    topRightRadius: -Appearance.sizes.sidebarFlare
    bottomRightRadius: -Appearance.sizes.sidebarFlare

    // A lit face, not a flat fill: brighter at the top, with a hairline down the
    // free edge where the light catches it. The left edge is off-screen, so the
    // stroke only ever shows where it should.
    color: Appearance.colour.surfaceTop
    colorBottom: Appearance.colour.surface
    borderColor: Appearance.colour.bevel
    borderWidth: Appearance.depth.bevelWidth

    Item {
        id: body

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.bodyWidth

        Workspaces {
            anchors.centerIn: parent
        }

        Column {
            id: bottom

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.padding.large
            anchors.horizontalCenter: parent.horizontalCenter

            width: parent.width - Appearance.padding.normal * 2
            spacing: Appearance.padding.normal

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Groove {
                width: parent.width
            }

            StatusIcons {
                width: parent.width
            }
        }
    }
}
