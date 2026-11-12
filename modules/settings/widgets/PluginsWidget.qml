pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import qs.modules.controls

Column {
    id: root

    property var row: ({})

    property var listed: []
    property var secrets: ({})
    property bool introKnown: false
    property bool introSeen: false
    property bool introAgain: false

    readonly property bool introShown: root.introKnown && (!root.introSeen || root.introAgain)

    readonly property string folder: `${Config.dir}/plugins`
    readonly property var off: Config.values.launcher.plugins.off
    readonly property var values: Config.values.launcher.plugins.values
    readonly property var commandsOff: Config.values.launcher.plugins.commandsOff

    width: parent ? parent.width : 0

    function valueOf(id: string, pref: var): var {
        const v = root.values[id]?.[pref.key];
        return v === undefined ? pref.fallback : v;
    }

    function setValue(id: string, key: string, value: var): void {
        Config.set("launcher.plugins.values", Object.assign({}, root.values, {
            [id]: Object.assign({}, root.values[id] ?? {}, {
                [key]: value
            })
        }));
    }

    function setSecret(id: string, key: string, value: string): void {
        const mine = Object.assign({}, root.secrets[id] ?? {});
        if (value)
            mine[key] = value;
        else
            delete mine[key];
        root.secrets = Object.assign({}, root.secrets, {
            [id]: mine
        });
        secretFile.save(JSON.stringify(root.secrets));
        SettingsView.drop(value ? "saved where only you can read it" : "removed", "key");
    }

    function setOn(id: string, on: bool): void {
        Config.set("launcher.plugins.off", on ? root.off.filter(o => o !== id) : root.off.concat([id]));
    }

    function commandOn(id: string, word: string): bool {
        return !root.commandsOff.includes(`${id}:${word}`);
    }

    function setCommand(id: string, word: string, on: bool): void {
        const key = `${id}:${word}`;
        Config.set("launcher.plugins.commandsOff", on ? root.commandsOff.filter(o => o !== key) : root.commandsOff.concat([key]));
    }

    function detailOf(p: var): string {
        if (p.error)
            return p.error;
        if (p.crashed)
            return "stopped after crashing three times";
        const words = p.prefix.length ? `type ${p.prefix[0]}` : "";
        return [p.about, words, p.global ? "shows in searches" : ""].filter(Boolean).join(" · ");
    }

    FileView {
        path: `${Config.stateDir}/plugins.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.listed = Array.isArray(data) ? data : [];
            } catch (e) {
                root.listed = [];
            }
        }
    }

    PrivateFile {
        id: secretFile

        path: `${Config.stateDir}/plugin-secrets.json`
        onLoaded: text => {
            try {
                const data = JSON.parse(text);
                root.secrets = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (e) {
                root.secrets = {};
            }
        }
    }

    FileView {
        id: introFile

        path: `${Config.stateDir}/plugins-intro-seen`
        printErrors: false
        onLoaded: {
            root.introSeen = true;
            root.introKnown = true;
        }
        onLoadFailed: root.introKnown = true
    }

    function dismissIntro(): void {
        introFile.setText("seen\n");
        root.introSeen = true;
        root.introAgain = false;
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", root.folder]);
    }

    Column {
        visible: root.introShown
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        spacing: Appearance.padding.normal
        topPadding: Appearance.padding.normal
        bottomPadding: Appearance.padding.large

        StyledText {
            width: parent.width
            text: "Add your own tools to the launcher"
            font.pixelSize: Appearance.font.size.normal
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            text: "A plugin is a small program, in any language, that answers what you type. Its rows come first in your searches and look like every other row, or taller, with a preview:"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
            wrapMode: Text.Wrap
        }

        SquircleRect {
            width: parent.width
            height: sample.height
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            MenuRow {
                id: sample

                width: parent.width
                labelSize: Appearance.font.size.small
                inlineDetail: true
                interactive: false
                icon: "waving_hand"
                label: "Hello, ada"
                detail: "a row from a plugin · Enter copies it"
            }
        }

        StyledText {
            width: parent.width
            text: "It runs as you, so it can read your files and use the network like any program you start. A plugin that draws its own rows runs that part inside the shell. Only add plugins you trust: installing one shows what it runs and draws first."
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            text: "Start one with banditshell plugin new <name>, or try a folder with banditshell plugin dev <folder>."
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }

        Row {
            spacing: Appearance.padding.small

            Button {
                size: 0
                style: "accent"
                text: "Got it"
                onClicked: root.dismissIntro()
            }

            Button {
                size: 0
                text: "Open plugins folder"
                onClicked: root.openFolder()
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.introKnown && !root.introShown
        interactive: false
        icon: "help"
        label: "What plugins can do"
        detail: "the introduction again"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Show"
            onClicked: root.introAgain = true
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.listed.length === 0
        interactive: false
        icon: "extension"
        label: "No plugins yet"
        detail: `a plugin is a folder in ${root.folder.replace(Quickshell.env("HOME"), "~")}`
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Open folder"
            onClicked: root.openFolder()
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.listed
            objectProp: "id"
        }

        delegate: Column {
            id: plugin

            required property var modelData

            readonly property bool on: !plugin.modelData.error && !root.off.includes(plugin.modelData.id)

            width: root.width

            SettingsRowFrame {
                width: root.width
                icon: plugin.modelData.icon?.name || "extension"
                label: plugin.modelData.name
                detail: root.detailOf(plugin.modelData)
                detailColour: plugin.modelData.error || plugin.modelData.crashed ? Appearance.colour.alarm : Appearance.colour.textFaint
                interactive: !plugin.modelData.error
                onActivated: root.setOn(plugin.modelData.id, !plugin.on)
                onPointed: SettingsView.hovered = root.row

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 0
                    visible: !!plugin.modelData.error || !!plugin.modelData.crashed
                    text: "Log"
                    onClicked: System.openWith(plugin.modelData.log)
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !plugin.modelData.error
                    checked: plugin.on
                    onToggled: root.setOn(plugin.modelData.id, !plugin.on)
                }
            }

            Repeater {
                model: plugin.on ? plugin.modelData.commands ?? [] : []

                delegate: SettingsRowFrame {
                    id: command

                    required property var modelData

                    readonly property bool commandOn: root.commandOn(plugin.modelData.id, command.modelData.word)

                    width: root.width
                    icon: command.modelData.icon || "terminal"
                    label: command.modelData.title
                    detail: `type ${command.modelData.word}`
                    onActivated: root.setCommand(plugin.modelData.id, command.modelData.word, !command.commandOn)
                    onPointed: SettingsView.hovered = root.row

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: command.commandOn
                        onToggled: root.setCommand(plugin.modelData.id, command.modelData.word, !command.commandOn)
                    }
                }
            }

            Repeater {
                model: plugin.on ? plugin.modelData.preferences : []

                delegate: SettingsRowFrame {
                    id: pref

                    required property var modelData

                    width: root.width
                    icon: pref.modelData.type === "secret" ? "key" : pref.modelData.type === "toggle" ? "toggle_on" : "edit"
                    label: pref.modelData.title
                    detail: pref.modelData.type === "secret" ? (pref.modelData.required && !root.secrets[plugin.modelData.id]?.[pref.modelData.key] ? "needed, kept where only you can read it" : "kept where only you can read it") : pref.modelData.required && !root.valueOf(plugin.modelData.id, pref.modelData) ? "needed" : ""
                    interactive: pref.modelData.type === "toggle"
                    onActivated: root.setValue(plugin.modelData.id, pref.modelData.key, !root.valueOf(plugin.modelData.id, pref.modelData))
                    onPointed: SettingsView.hovered = root.row

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pref.modelData.type === "toggle"
                        checked: !!root.valueOf(plugin.modelData.id, pref.modelData)
                        onToggled: root.setValue(plugin.modelData.id, pref.modelData.key, !root.valueOf(plugin.modelData.id, pref.modelData))
                    }

                    SettingsField {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pref.modelData.type === "text"
                        text: String(root.valueOf(plugin.modelData.id, pref.modelData) ?? "")
                        placeholder: pref.modelData.placeholder
                        mono: true
                        onCommitted: t => root.setValue(plugin.modelData.id, pref.modelData.key, t)
                    }

                    SettingsSecret {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pref.modelData.type === "secret"
                        text: root.secrets[plugin.modelData.id]?.[pref.modelData.key] ?? ""
                        onAccepted: t => root.setSecret(plugin.modelData.id, pref.modelData.key, t)
                    }
                }
            }
        }
    }
}
