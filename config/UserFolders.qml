pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "user-folders.js" as Logic

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? "/home"
    property var folders: Logic.parse("", root.home)
    readonly property var byPath: Logic.byPath(root.folders)

    readonly property string documents: root.folders.Documents
    readonly property string downloads: root.folders.Downloads
    readonly property string pictures: root.folders.Pictures

    function shown(path: string): string {
        return Logic.shown(path, root.home);
    }

    function adopt(text: string): void {
        const next = Logic.parse(text, root.home);
        if (JSON.stringify(next) !== JSON.stringify(root.folders))
            root.folders = next;
    }

    Component.onCompleted: root.adopt(file.text())

    FileView {
        id: file

        path: `${Quickshell.env("XDG_CONFIG_HOME") || `${root.home}/.config`}/user-dirs.dirs`
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onLoaded: root.adopt(file.text())
        onLoadFailed: root.adopt("")
    }
}
