//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import Quickshell
import qs.config
import qs.modules
import qs.modules.sidebar

// Entry point.
//
// Variants instantiates its child once per item in `model`, so plugging in a
// monitor creates the shell surfaces on it and unplugging destroys them, with no
// screen-counting code anywhere.
//
// Three surfaces per screen, and the order they are declared in is their
// stacking order:
//   EdgeWindow    - full-screen, reserves nothing, owns the summon zones
//   SidebarWindow - left-anchored, reserves its width, displaces tiled windows
//   ScreenFrame   - rounds the physical screen corners, above all, no input
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

            LazyLoader {
                active: Appearance.sizes.roundOuter

                ScreenFrame {
                    screen: scope.modelData
                }
            }
        }
    }
}
