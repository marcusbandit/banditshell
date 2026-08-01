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

    // The compositor blurs this surface by name. Without that the panel is just
    // a flat translucent wash; with it, it is a material. See the myshell
    // layerrules in ~/.config/hypr/hyprland/rules.conf.
    WlrLayershell.namespace: "myshell-sidebar"

    // Wider than the panel: the concave corners flare past `bodyWidth` and need
    // somewhere to be drawn.
    implicitWidth: sidebar.implicitWidth

    // Push tiled windows aside by the panel proper, not by the flare. When the
    // sidebar becomes toggleable this drops to 0 while hidden.
    exclusiveZone: sidebar.bodyWidth

    // Only the panel proper takes input. The flare is decoration over whatever
    // window is behind it, so clicks there must fall through.
    mask: Region {
        width: sidebar.bodyWidth
        height: win.height
    }

    Sidebar {
        id: sidebar
        anchors.fill: parent
    }
}
