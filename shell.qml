//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import Quickshell
import qs.modules
import qs.modules.picker

// banditshell.
//
// Variants instantiates its child once per item in `model`, so plugging in a
// monitor creates the shell surfaces on it and unplugging destroys them, with no
// screen-counting code anywhere.
//
// Three surfaces per screen, with completely separate jobs:
//   WallpaperWindow - the background layer, below every window.
//   ShellWindow     - everything the shell draws, and all the input. One field,
//                     one mask, no stacking.
//   FrameExclusions - invisible; reserves the room the chassis occupies.
//
// Ipc is shell-wide rather than per-screen: it finds windows through the
// registry they put themselves in, so nothing has to be wired up here.
ShellRoot {
    // The picker's state is shell-wide; its surfaces are per screen.
    PickerState {
        id: picker
    }

    Ipc {
        picker: picker
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            WallpaperWindow {
                screen: scope.modelData
            }

            ShellWindow {
                screen: scope.modelData
            }

            FrameExclusions {
                screen: scope.modelData
            }

            PickerWindow {
                screen: scope.modelData
                state: picker
            }
        }
    }
}
