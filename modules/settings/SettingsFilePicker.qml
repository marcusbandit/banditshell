pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "../../services/update.js" as Words

Column {
    id: root

    property var row: ({})
    property string title: "Open"
    property string pattern: "*.json"
    property string kind: "files"
    property var check: null
    property int most: 6

    signal picked(string path)

    property var found: []
    property bool looked: false

    width: parent ? parent.width : 0

    function look(): void {
        root.looked = false;
        scan.running = false;
        scan.running = true;
    }

    function browse(): void {
        chooser.open(root.title, root.pattern);
    }

    function read(text: string): void {
        const out = [];
        for (const record of text.split("\x1e")) {
            const head = record.indexOf("\n");
            const tab = record.indexOf("\t");
            if (head < 0 || tab < 0 || tab > head)
                continue;
            const path = record.slice(tab + 1, head);
            const said = root.check ? root.check(record.slice(head + 1)) : "";
            if (said === null || said === undefined)
                continue;
            out.push({
                path: path,
                name: path.slice(path.lastIndexOf("/") + 1),
                said: said,
                when: parseFloat(record.slice(0, tab)) * 1000
            });
        }
        out.sort((a, b) => b.when - a.when);
        root.found = out.slice(0, root.most);
        root.looked = true;
    }

    Process {
        id: scan

        command: ["sh", "-c", "find \"$2\" -maxdepth 2 -type f -iname \"$1\" -size -512k -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 40 | while IFS= read -r line; do printf '\\036%s\\n' \"$line\"; cat -- \"${line#*\t}\" 2>/dev/null; done; true", "sh", root.pattern, UserFolders.downloads]

        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
    }

    FileChooser {
        id: chooser

        onPicked: path => root.picked(path)
        onMissing: SettingsView.drop("no file chooser here · move the file to Downloads", "error")
    }

    Repeater {
        model: root.found

        delegate: SettingsRowFrame {
            id: file

            required property var modelData

            width: root.width
            icon: "data_object"
            label: file.modelData.name
            detail: [file.modelData.said, Words.ago(file.modelData.when, Date.now())].filter(s => s).join(" · ")
            onPointed: SettingsView.hovered = root.row
            onActivated: root.picked(file.modelData.path)
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        visible: root.looked && root.found.length === 0
        off: true
        icon: "search_off"
        label: `No ${root.kind} in Downloads`
        onPointed: SettingsView.hovered = root.row
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "folder_open"
        label: "Another file"
        detail: chooser.available ? "" : "browsing needs a file chooser such as zenity · move the file to Downloads instead"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: chooser.available
            size: 0
            text: "Browse"
            onClicked: root.browse()
        }
    }
}
