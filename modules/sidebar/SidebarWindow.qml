import Quickshell
import Quickshell.Wayland

// The sidebar's own layer surface.
//
// It needs to be a separate window from EdgeWindow because a Wayland exclusive
// zone is a property of a whole surface anchored to one edge: a full-screen
// surface anchored to all four edges cannot reserve space. So the sidebar gets
// its own left-anchored surface, and EdgeWindow is told to ignore it
// (ExclusionMode.Ignore) so the invisible ring keeps hugging the real screen
// edges instead of being pushed inwards by this.
//
// Declared after EdgeWindow in shell.qml so it stacks above the ring and wins
// the input where the two overlap.
PanelWindow {
    id: win

    anchors {
        left: true
        top: true
        bottom: true
    }

    color: "transparent"

    implicitWidth: sidebar.implicitWidth

    // Push tiled windows aside by exactly the sidebar's width. When the sidebar
    // becomes toggleable this drops to 0 while hidden.
    exclusiveZone: sidebar.implicitWidth

    Sidebar {
        id: sidebar
        anchors.fill: parent
    }
}
