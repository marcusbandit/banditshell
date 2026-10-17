pragma ComponentBehavior: Bound

import Quickshell
import qs.services
import qs.modules
import qs.modules.files
import qs.modules.island
import qs.modules.lock
import qs.modules.pen
import qs.modules.picker
import qs.modules.wallpaper

ShellRoot {
    readonly property var compositorSync: CompositorSync
    readonly property var idle: Idle
    readonly property var screenTimeApps: UsageApps
    readonly property var screenTimeLimits: UsageLimits
    readonly property var battery: Battery
    readonly property var chargeLimit: ChargeLimit
    readonly property var lid: Lid
    readonly property var startupApps: StartupApps
    readonly property var penButtons: PenButtons
    readonly property var currency: Currency
    readonly property var calculator: Calculator
    readonly property var hyprConfig: HyprConfig
    readonly property var modes: Modes
    readonly property var launcherHotkeys: LauncherHotkeys
    readonly property var activities: Activities
    readonly property var levels: Levels

    LockScreen {}

    FilesWindow {}

    PickerState {
        id: picker
    }

    IslandInspector {
        id: islandInspector
    }

    Ipc {
        picker: picker
        inspector: islandInspector
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
