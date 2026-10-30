pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "obs.js" as ObsProtocol
import "../components/base64.js" as Base64

Singleton {
    id: root

    readonly property bool wanted: StreamState.enabled

    readonly property bool installed: !ToolInstaller.probed || ToolInstaller.has("obs")

    readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/obs-studio/plugin_config/obs-websocket/config.json`

    property var server: null

    readonly property string passwordPath: `${Config.stateDir}/obs-password`
    property string ownPassword: ""
    readonly property string legacyPassword: Config.ready ? (Config.values.obs?.password ?? "") : ""

    readonly property var endpoint: ObsProtocol.endpoint(ObsProtocol.withPassword(Config.values.obs, root.ownPassword || root.legacyPassword), root.server)
    readonly property string url: root.endpoint.url
    readonly property string password: root.endpoint.password

    readonly property bool canConnect: root.wanted && (root.endpoint.remote || (root.server?.server_enabled ?? false))

    property string link: "closed"

    property QtObject socket: null

    property bool linkTried: false

    readonly property string phase: !root.wanted ? "idle" : !root.socket && root.linkTried && (root.installed || root.endpoint.remote) ? "missing" : !root.canConnect ? "unset" : root.link

    property bool identifying: false

    property bool live: false
    property string streamState: ""
    property bool reconnecting: false
    property real liveMs: 0
    property var health: null

    property bool recording: false
    property bool recordPaused: false
    property real recordMs: 0

    property var scenes: []
    property string scene: ""
    property var items: []
    property var audio: []

    readonly property var cameras: root.items.filter(i => i.role === "camera")
    readonly property bool cameraShown: root.cameras.some(i => i.enabled)
    readonly property var captures: root.items.filter(i => i.role === "screen")
    readonly property bool screenShown: root.captures.some(i => i.enabled)
    readonly property var mics: root.audio.filter(i => i.role === "mic")
    readonly property bool micMuted: root.mics.length > 0 && root.mics.every(i => i.muted)
    readonly property var desktops: root.audio.filter(i => i.role === "desktop")
    readonly property bool desktopMuted: root.desktops.length > 0 && root.desktops.every(i => i.muted)

    readonly property string liveClock: ObsProtocol.duration(root.liveMs)
    readonly property string recordClock: ObsProtocol.duration(root.recordMs)
    readonly property string healthLabel: !root.health ? "" : root.health.skipped === 0 ? `${ObsProtocol.rate(root.health.kbps)}, no dropped frames` : `${ObsProtocol.rate(root.health.kbps)}, ${root.health.skipped} dropped (${(root.health.dropped * 100).toFixed(1)}%)`
    readonly property bool struggling: root.reconnecting || (root.health?.dropped ?? 0) > 0.01 || (root.health?.congestion ?? 0) > 0.5

    property int serial: 0
    property var waiting: ({})

    onCanConnectChanged: root.sync()
    onServerChanged: root.sync()
    onUrlChanged: root.sync()
    onPasswordChanged: root.sync()

    function sync(): void {
        if (!root.socket)
            return;
        root.socket.active = false;
        root.forget();
        if (root.canConnect)
            root.socket.active = true;
    }

    function forget(): void {
        root.link = "closed";
        root.identifying = false;
        root.waiting = {};
        root.live = false;
        root.streamState = "";
        root.reconnecting = false;
        root.liveMs = 0;
        root.health = null;
        root.recording = false;
        root.recordPaused = false;
        root.recordMs = 0;
        if (root.scenes.length)
            root.scenes = [];
        root.scene = "";
        if (root.items.length)
            root.items = [];
        if (root.audio.length)
            root.audio = [];
    }

    function call(type: string, data: var, then: var): void {
        if (root.link !== "ready")
            return;
        const id = `${++root.serial}`;
        if (then)
            root.waiting[id] = then;
        root.socket.sendTextMessage(JSON.stringify(ObsProtocol.request(type, id, data)));
    }

    function handle(text: string): void {
        let message;
        try {
            message = JSON.parse(text);
        } catch (e) {
            return;
        }
        const d = message.d ?? {};
        if (message.op === 0) {
            root.identifying = true;
            root.socket.sendTextMessage(JSON.stringify(ObsProtocol.identify(d, root.password, Base64)));
        } else if (message.op === 2) {
            root.identifying = false;
            root.link = "ready";
            root.refresh();
        } else if (message.op === 5) {
            root.event(d.eventType, d.eventData ?? {});
        } else if (message.op === 7) {
            const then = root.waiting[d.requestId];
            delete root.waiting[d.requestId];
            if (then && d.requestStatus?.result)
                then(d.responseData ?? {});
        }
    }

    function refresh(): void {
        root.call("GetStreamStatus", {}, d => root.takeStream(d));
        root.call("GetRecordStatus", {}, d => root.takeRecord(d));
        root.call("GetSceneList", {}, d => {
            root.scenes = ObsProtocol.sceneNames(d.scenes);
            root.scene = d.currentProgramSceneName ?? "";
            root.loadItems();
        });
        root.loadInputs();
    }

    function loadItems(): void {
        const scene = root.scene;
        root.call("GetSceneItemList", {
            sceneName: scene
        }, d => {
            if (scene === root.scene)
                root.items = (d.sceneItems ?? []).map(i => ({
                            id: i.sceneItemId,
                            name: i.sourceName,
                            role: ObsProtocol.role(i.inputKind),
                            enabled: i.sceneItemEnabled
                        }));
        });
    }

    function loadInputs(): void {
        root.call("GetInputList", {}, d => {
            root.audio = (d.inputs ?? []).map(i => ({
                        name: i.inputName,
                        role: ObsProtocol.role(i.unversionedInputKind ?? i.inputKind),
                        muted: false
                    })).filter(i => i.role === "mic" || i.role === "desktop");
            for (const input of root.audio)
                root.call("GetInputMute", {
                    inputName: input.name
                }, m => root.markMuted(input.name, m.inputMuted));
        });
    }

    function markMuted(name: string, muted: bool): void {
        root.audio = root.audio.map(i => i.name === name ? Object.assign({}, i, {
                    muted: muted
                }) : i);
    }

    function takeStream(d: var): void {
        root.live = !!d.outputActive;
        root.reconnecting = !!d.outputReconnecting;
        root.liveMs = d.outputDuration ?? 0;
        root.health = root.live ? ObsProtocol.health(root.health, d, Date.now()) : null;
    }

    function takeRecord(d: var): void {
        root.recording = !!d.outputActive;
        root.recordPaused = !!d.outputPaused;
        root.recordMs = d.outputDuration ?? 0;
    }

    function stateOf(d: var): string {
        return String(d.outputState ?? "").replace("OBS_WEBSOCKET_OUTPUT_", "").toLowerCase();
    }

    function event(type: string, d: var): void {
        switch (type) {
        case "StreamStateChanged":
            root.streamState = root.stateOf(d);
            root.live = !!d.outputActive;
            root.reconnecting = root.streamState === "reconnecting";
            if (root.live)
                root.call("GetStreamStatus", {}, s => root.takeStream(s));
            else {
                root.liveMs = 0;
                root.health = null;
            }
            break;
        case "RecordStateChanged":
            root.recording = !!d.outputActive;
            root.recordPaused = root.stateOf(d) === "paused";
            if (!root.recording)
                root.recordMs = 0;
            break;
        case "CurrentProgramSceneChanged":
            root.scene = d.sceneName ?? "";
            root.loadItems();
            break;
        case "SceneListChanged":
            root.scenes = ObsProtocol.sceneNames(d.scenes);
            break;
        case "SceneNameChanged":
            if (d.oldSceneName === root.scene)
                root.scene = d.sceneName;
            break;
        case "SceneItemEnableStateChanged":
            if (d.sceneName === root.scene)
                root.items = root.items.map(i => i.id === d.sceneItemId ? Object.assign({}, i, {
                            enabled: d.sceneItemEnabled
                        }) : i);
            break;
        case "SceneItemCreated":
        case "SceneItemRemoved":
        case "SceneItemListReindexed":
            if (d.sceneName === root.scene)
                root.loadItems();
            break;
        case "InputMuteStateChanged":
            root.markMuted(d.inputName, d.inputMuted);
            break;
        case "InputCreated":
        case "InputRemoved":
        case "InputNameChanged":
            root.loadInputs();
            break;
        }
    }

    function startStream(): void {
        root.call("StartStream", {}, null);
    }

    function stopStream(): void {
        root.call("StopStream", {}, null);
    }

    function toggleRecord(): void {
        root.call(root.recording ? "StopRecord" : "StartRecord", {}, null);
    }

    function showScene(name: string): void {
        root.call("SetCurrentProgramScene", {
            sceneName: name
        }, null);
    }

    function setShown(role: string, shown: bool): void {
        for (const item of root.items.filter(i => i.role === role))
            root.call("SetSceneItemEnabled", {
                sceneName: root.scene,
                sceneItemId: item.id,
                sceneItemEnabled: shown
            }, null);
    }

    function setMuted(role: string, muted: bool): void {
        for (const input of root.audio.filter(i => i.role === role))
            root.call("SetInputMute", {
                inputName: input.name,
                inputMuted: muted
            }, null);
    }

    function setAddress(text: string): bool {
        const parsed = ObsProtocol.address(text);
        if (!parsed)
            return false;
        Config.setMany([["obs.host", parsed.host], ["obs.port", parsed.port]]);
        return true;
    }

    function setPassword(text: string): void {
        root.keep(text, false);
    }

    property var queuedKeep: null

    function keep(text: string, migrating: bool): void {
        if (keeper.running) {
            root.queuedKeep = { text, migrating };
            return;
        }
        keeper.password = text;
        keeper.migrating = migrating;
        keeper.command = ObsProtocol.savePasswordCommand(root.passwordPath, text);
        keeper.running = true;
    }

    function migrate(): void {
        if (root.legacyPassword !== "")
            root.keep(root.legacyPassword, true);
    }

    function reach(): void {
        if (root.socket || root.linkTried || !root.wanted)
            return;
        root.linkTried = true;
        const link = Qt.createComponent(Qt.resolvedUrl("ObsLink.qml"));
        if (link.status !== Component.Ready) {
            console.warn("OBS stays out of reach until qt6-websockets is installed:", link.errorString().trim());
            return;
        }
        root.socket = link.createObject(root);
        root.socket.url = Qt.binding(() => root.url);
        root.sync();
    }

    onWantedChanged: root.reach()
    onLegacyPasswordChanged: root.migrate()
    Component.onCompleted: {
        root.migrate();
        root.reach();
    }

    Process {
        id: keeper

        property string password: ""
        property bool migrating: false

        stdinEnabled: true

        onStarted: {
            if (keeper.password !== "")
                keeper.write(keeper.password);
            keeper.stdinEnabled = false;
        }

        onExited: code => {
            if (code === 0) {
                root.ownPassword = keeper.password;
                if (keeper.migrating)
                    Config.set("obs.password", "");
            } else {
                console.warn(`Obs: could not keep the websocket password in ${root.passwordPath}`);
            }
            keeper.stdinEnabled = true;
            const next = root.queuedKeep;
            root.queuedKeep = null;
            if (next)
                root.keep(next.text, next.migrating);
        }
    }

    FileView {
        path: root.passwordPath
        printErrors: false

        onLoaded: root.ownPassword = text()
        onLoadFailed: root.ownPassword = ""
    }

    function launch(): void {
        if (!root.installed)
            return;
        Quickshell.execDetached(["obs"]);
        redial.reset();
    }

    FileView {
        path: root.wanted ? root.configPath : ""
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            try {
                root.server = JSON.parse(text());
            } catch (e) {
                root.server = null;
            }
        }

        onLoadFailed: root.server = null
    }

    Connections {
        target: root.socket

        function onDropped(): void {
            const refused = root.identifying;
            root.forget();
            root.link = refused ? "refused" : "closed";
        }

        function onTextMessageReceived(message: string): void {
            root.handle(message);
        }
    }

    Backoff {
        id: redial

        base: 3000
        cap: 30000
        running: !!root.socket && root.canConnect && root.link === "closed"

        onDue: {
            root.socket.active = false;
            root.socket.active = true;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.link === "ready" && (root.live || root.recording)

        onTriggered: {
            if (root.live)
                root.call("GetStreamStatus", {}, d => root.takeStream(d));
            if (root.recording)
                root.call("GetRecordStatus", {}, d => root.takeRecord(d));
        }
    }
}
