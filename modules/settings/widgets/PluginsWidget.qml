pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    property var listed: []
    property var secrets: ({})

    readonly property string folder: `${Config.dir}/plugins`
    readonly property var off: Config.values.launcher.plugins.off
    readonly property var values: Config.values.launcher.plugins.values

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
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", root.folder])
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
