pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "shell-actions.js" as Logic

Singleton {
    id: root

    property string table: ""
    property string commands: ""

    readonly property var rows: Logic.parseTable(root.table, Logic.panelNames(root.commands))

    FileView {
        path: Quickshell.shellPath("api/actions.tsv")
        blockLoading: true
        watchChanges: false
        printErrors: false

        onLoaded: root.table = text()
    }

    FileView {
        path: Quickshell.shellPath("cli/commands.tsv")
        blockLoading: true
        watchChanges: false
        printErrors: false

        onLoaded: root.commands = text()
    }
}
