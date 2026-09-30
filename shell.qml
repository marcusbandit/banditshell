pragma ComponentBehavior: Bound

import Quickshell
import qs.modules
import qs.modules.files
import qs.modules.lock
import qs.modules.pen
import qs.modules.picker
import qs.modules.settings

ShellRoot {

    FilesWindow {}

    PickerState {
        id: picker
    }

    Ipc {
        picker: picker
    }

    LockScreen {}

    SettingsFloat {}

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
