import Quickshell
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

Scope {
    id: root

    required property var picker
    required property var inspector

    ActivityIpc {}
    AudioIpc {}
    CalculatorIpc {}
    ClipboardIpc {}
    ClockIpc {}
    CompositorIpc {}
    CoreIpc {}
    DisplayIpc {}
    FilesIpc {}
    HostIpc {
        picker: root.picker
    }
    HotkeysIpc {}
    InspectIpc {
        inspector: root.inspector
    }
    IslandIpc {}
    KeyboardIpc {}
    LauncherIpc {}
    MediaIpc {}
    MenuIpc {}
    ModeIpc {}
    NotificationsIpc {}
    PasswordIpc {}
    PenIpc {}
    PickerIpc {
        picker: root.picker
    }
    QuickControlsIpc {}
    SessionIpc {}
    SettingsIpc {}
    SidebarIpc {}
    StreamIpc {}
    WallpaperIpc {}
}
