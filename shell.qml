pragma ComponentBehavior: Bound

import Quickshell
import qs.services
import qs.modules
import qs.modules.files
import qs.modules.lock
import qs.modules.pen
import qs.modules.picker

ShellRoot {
    readonly property var compositorSync: CompositorSync
    readonly property var penButtons: PenButtons

    LockScreen {}

    FilesWindow {}

    PickerState {
        id: picker
    }

    Cli {
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

            PenOverlay {
                screen: scope.modelData
            }
        }
    }
}
