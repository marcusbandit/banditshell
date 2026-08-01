//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import Quickshell
import qs.modules

// Entry point.
//
// Variants instantiates its child once per item in `model`, so plugging in a
// monitor creates the shell surfaces on it and unplugging destroys them, with no
// screen-counting code anywhere.
//
// Two surfaces per screen, and they have completely separate jobs:
//   ShellWindow     - everything visible, and all the input. One shape, one
//                     mask, no stacking.
//   FrameExclusions - invisible, reserves the room the chassis occupies.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            ShellWindow {
                screen: scope.modelData
            }

            FrameExclusions {
                screen: scope.modelData
            }
        }
    }
}
