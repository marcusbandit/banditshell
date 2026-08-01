//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import Quickshell
import qs.modules
import qs.modules.sidebar

// Entry point.
//
// Variants instantiates its child once per item in `model`, so plugging in a
// monitor creates the shell surfaces on it and unplugging destroys them, with no
// screen-counting code anywhere.
//
// Two surfaces per screen:
//   EdgeWindow    - full-screen, reserves nothing, owns the summon zones
//   SidebarWindow - left-anchored, reserves its width, displaces tiled windows
// Order matters: the sidebar is declared second so it stacks above the ring.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            EdgeWindow {
                screen: scope.modelData
            }

            SidebarWindow {
                screen: scope.modelData
            }
        }
    }
}
