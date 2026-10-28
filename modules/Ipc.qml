import QtQml
import Quickshell
import Quickshell.Hyprland
import qs.modules.calculator
import qs.modules.cheatsheet
import qs.modules.clipboard
import qs.modules.files
import qs.modules.ipc
import qs.modules.island
import qs.modules.keyboard
import qs.modules.launcher
import qs.modules.media
import qs.modules.menu
import qs.modules.password
import qs.modules.pen
import qs.modules.picker
import qs.modules.quickcontrols
import qs.modules.session
import qs.modules.settings
import qs.modules.sidebar
import qs.modules.stream
import qs.modules.wallpaper
import "ipc/bind-shortcuts.js" as BindShortcuts

Scope {
    id: root

    required property var picker
    required property var inspector

    ActivityIpc {}
    AudioIpc {}
    CalculatorIpc {
        id: calculatorIpc
    }
    ClipboardIpc {
        id: clipboardIpc
    }
    ClockIpc {}
    CompositorIpc {}
    CoreIpc {}
    DisplayIpc {}
    FilesIpc {
        id: filesIpc
    }
    HostIpc {
        id: hostIpc

        picker: root.picker
    }
    HotkeysIpc {
        id: hotkeysIpc
    }
    InspectIpc {
        inspector: root.inspector
    }
    IslandIpc {
        id: islandIpc
    }
    KeyboardIpc {
        id: keyboardIpc
    }
    LauncherIpc {
        id: launcherIpc
    }
    MediaIpc {
        id: mediaIpc
    }
    MenuIpc {
        id: menuIpc
    }
    ModeIpc {}
    NotificationsIpc {
        id: notificationsIpc
    }
    PasswordIpc {}
    PenIpc {
        id: penIpc
    }
    PickerIpc {
        picker: root.picker
    }
    QuickControlsIpc {
        id: quickControlsIpc
    }
    SessionIpc {
        id: sessionIpc
    }
    SettingsIpc {}
    SidebarIpc {}
    StreamIpc {}
    TraceIpc {}
    WallpaperIpc {
        id: wallpaperIpc
    }

    function runShortcut(name: string): void {
        const handlers = {
            launcher: launcherIpc.handler,
            panels: hostIpc.panels,
            files: filesIpc,
            penmap: penIpc.handler,
            session: sessionIpc,
            clipboard: clipboardIpc,
            media: mediaIpc,
            calculator: calculatorIpc,
            quickcontrols: quickControlsIpc,
            keyboard: keyboardIpc,
            notifications: notificationsIpc.handler,
            island: islandIpc,
            hotkeys: hotkeysIpc,
            wallpapers: wallpaperIpc.handler,
            menu: menuIpc
        };
        for (const call of BindShortcuts.callsFor(name))
            handlers[call[0]][call[1]](...call.slice(2));
    }

    Instantiator {
        model: BindShortcuts.names()

        delegate: GlobalShortcut {
            required property string modelData

            appid: "banditshell"
            name: modelData
            description: BindShortcuts.describe(modelData)

            onPressed: root.runShortcut(modelData)
        }
    }
}
