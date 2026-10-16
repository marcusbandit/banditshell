pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "assistant.js" as Logic

Singleton {
    id: root

    readonly property var settings: Config.values.launcher.ai
    readonly property bool enabled: !!root.settings.enabled
    readonly property string backend: root.settings.backend
    readonly property bool local: root.backend === "ollama"

    readonly property string script: `${Quickshell.shellDir}/scripts/assistant-request.sh`
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    property var tools: ({})
    property bool probed: false

    property string savedKey: ""
    readonly property string key: root.local ? "" : root.savedKey || Quickshell.env(root.backend === "anthropic" ? "ANTHROPIC_API_KEY" : "OPENAI_API_KEY") || ""
    readonly property string keyPath: `${Config.stateDir}/assistant-key`

    property var models: []
    property bool reachable: false
    property bool listed: false
    property string listedFor: ""
    property real listedAt: 0
    readonly property string listing: `${root.backend}|${root.settings.ollamaAddress}|${root.settings.openaiAddress}|${root.key ? "key" : ""}`

    readonly property string model: Logic.modelFor(root.backend, root.settings.model, root.models)
    readonly property string modelName: Logic.modelLabel(root.model)

    function labelOf(model: string): string {
        return Logic.modelLabel(model);
    }

    property string setup: ""
    property string trouble: ""
    property int progress: 0
    property real pulledBytes: 0
    property real pullBytes: 0
    property var pending: null

    readonly property string phase: {
        if (!root.enabled)
            return "off";
        if (!root.local)
            return root.key ? "ready" : "nokey";
        if (root.setup)
            return root.setup;
        if (root.listed && root.reachable)
            return root.models.length ? "ready" : "empty";
        if (!root.probed || !root.listed)
            return "unknown";
        if (!Logic.isLocal(root.settings.ollamaAddress))
            return "unreachable";
        return root.tools.ollama ? "stopped" : "missing";
    }
    readonly property bool ready: root.phase === "ready"

    readonly property bool canType: !!root.tools.wtype
    readonly property bool canReadSelection: !!root.tools["wl-paste"]

    property var turns: []
    property string topic: ""
    property string question: ""
    property string kind: ""
    property string actionId: ""
    property string source: ""
    property string raw: ""
    property string arriving: ""
    property bool streaming: false
    property bool finished: false
    property string error: ""
    property bool following: false
    property bool inPlace: false
    property real startedAt: 0
    property int generation: 0
    property int status: 0
    property string leftover: ""
    property QtObject talk: null

    readonly property var action: Logic.actionOf(root.actionId)
    readonly property string answer: root.kind === "rewrite" ? Logic.visibleText(root.raw).trim() : Logic.undash(Logic.visibleText(root.raw))
    readonly property string result: root.kind === "rewrite" ? Logic.tidyRewrite(root.raw, root.source) : root.answer.trim()
    readonly property int answeredTurns: Math.floor(root.turns.length / 2)

    property string selection: ""
    property bool selectionRead: false

    Component.onCompleted: root.refresh()

    onListingChanged: if (root.enabled)
        Qt.callLater(root.list)

    onEnabledChanged: if (root.enabled)
        root.refresh()

    function refresh(): void {
        if (!root.enabled)
            return;
        if (!root.probed && !prober.running)
            prober.running = true;
        if (root.listedFor !== root.listing || root.local && Date.now() - root.listedAt > 4000)
            root.list();
    }

    function settingsFor(model: string): var {
        return {
            model: model,
            ollamaAddress: root.settings.ollamaAddress,
            openaiAddress: root.settings.openaiAddress
        };
    }

    function list(): void {
        if (!root.local && !root.key) {
            root.models = [];
            root.listed = true;
            root.listedFor = root.listing;
            return;
        }
        const request = Logic.listRequest(root.backend, root.settingsFor(""));
        lister.running = false;
        lister.listing = root.listing;
        lister.backend = root.backend;
        lister.environment = {
            BANDITSHELL_ASSISTANT_KEY: request.auth ? root.key : null
        };
        lister.command = [root.script, request.url, request.auth, "get"].concat(request.headers);
        lister.running = true;
    }

    function takeList(text: string): void {
        if (lister.listing !== root.listing)
            return;
        const got = Logic.splitStatus(text);
        const names = Logic.readModels(lister.backend, got.body);
        root.reachable = got.status === 200 && names !== null;
        root.models = root.reachable ? names : [];
        root.listed = true;
        root.listedFor = lister.listing;
        root.listedAt = Date.now();
        if (root.setup === "starting" && root.reachable) {
            waitForServer.stop();
            root.setup = "";
            if (!root.models.length)
                root.download(Logic.STARTER.name);
        }
        if (root.ready)
            root.flush();
    }

    function setUp(then: var): void {
        if (then)
            root.pending = then;
        root.trouble = "";
        switch (root.phase) {
        case "missing":
            root.install();
            return;
        case "stopped":
            root.start();
            return;
        case "empty":
            root.download(Logic.STARTER.name);
            return;
        case "ready":
            root.flush();
            return;
        case "unknown":
            return;
        }
        root.pending = null;
    }

    function flush(): void {
        const next = root.pending;
        root.pending = null;
        if (!next)
            return;
        if (next.kind === "ask")
            root.ask(next.question, next.topic);
        else if (next.kind === "rewrite")
            root.rewrite(next.actionId, next.text, next.topic, next.inPlace);
    }

    function hostOf(address: string): string {
        return address.replace(/^https?:\/\//, "").replace(/\/+$/, "");
    }

    function start(): void {
        root.setup = "starting";
        Quickshell.execDetached(["env", `OLLAMA_HOST=${root.hostOf(root.settings.ollamaAddress)}`, "ollama", "serve"]);
        waitForServer.tries = 0;
        waitForServer.restart();
    }

    function download(name: string): void {
        root.setup = "pulling";
        root.progress = 0;
        root.pulledBytes = 0;
        root.pullBytes = Logic.STARTER.bytes;
        puller.got = null;
        const request = Logic.pullRequest(root.settingsFor(""), name);
        puller.running = false;
        puller.body = request.body;
        puller.stdinEnabled = true;
        puller.command = [root.script, request.url, "", "stream"].concat(request.headers);
        puller.running = true;
    }

    function takePull(line: string): void {
        const state = Logic.readPull(puller.got, line);
        puller.got = state;
        if (state.error) {
            root.trouble = state.error;
            return;
        }
        const totals = Logic.pullTotals(state);
        const percent = Math.floor(totals.fraction * 100);
        if (percent !== root.progress)
            root.progress = percent;
        if (totals.total > 0 && Math.abs(totals.completed - root.pulledBytes) > 25e6) {
            root.pulledBytes = totals.completed;
            root.pullBytes = totals.total;
        }
    }

    function pullEnded(): void {
        root.setup = "";
        if (!puller.got?.done && !root.trouble)
            root.trouble = "the download stopped";
        if (root.trouble)
            root.pending = null;
        root.list();
    }

    readonly property var ollamaPackages: root.tools.nvidia ? ["pacman:ollama-cuda", "dnf:ollama", "zypper:ollama", "xbps:ollama", "apk:ollama"] : ["pacman:ollama", "dnf:ollama", "zypper:ollama", "xbps:ollama", "apk:ollama"]

    function install(): void {
        root.setup = "installing";
        Polkit.expect("Install Ollama", "");
        installing.running = true;
    }

    function installEnded(code: int): void {
        Polkit.forget();
        if (code === 0) {
            root.setup = "";
            root.probed = false;
            prober.running = true;
            return;
        }
        if (code === 3) {
            root.setup = "";
            root.trouble = "no package for this system";
            return;
        }
        if (code === 4 || code === 127) {
            installInTerminal.running = true;
            return;
        }
        root.setup = "";
        root.trouble = code === 126 ? "" : "Ollama did not install";
        root.pending = null;
    }

    function openDownloadPage(): void {
        Quickshell.execDetached(["xdg-open", "https://ollama.com/download"]);
    }

    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function ask(question: string, topic: string): void {
        if (!question)
            return;
        if (!root.ready) {
            root.setUp({
                kind: "ask",
                question: question,
                topic: topic
            });
            return;
        }
        const before = root.following ? root.turns : [];
        root.turns = Logic.trimTurns(before.concat([
            {
                role: "user",
                content: question
            }
        ]), 8, 16000);
        root.inPlace = false;
        root.actionId = "";
        root.source = "";
        root.begin("ask", topic, question, Logic.askPrompt(root.today()), root.turns);
    }

    function rewrite(actionId: string, text: string, topic: string, inPlace: bool): void {
        const action = Logic.actionOf(actionId);
        if (!action || !text.trim())
            return;
        if (!root.ready) {
            root.setUp({
                kind: "rewrite",
                actionId: actionId,
                text: text,
                topic: topic,
                inPlace: inPlace
            });
            return;
        }
        root.following = false;
        root.inPlace = inPlace;
        root.actionId = actionId;
        root.source = text.slice(0, Logic.SELECTION_LIMIT);
        root.begin("rewrite", topic, action.label, Logic.rewritePrompt(action), [Logic.rewriteMessage(root.source)]);
    }

    function rewriteSelection(actionId: string): void {
        selectionReader.then = actionId;
        if (!selectionReader.running)
            selectionReader.running = true;
    }

    function begin(kind: string, topic: string, question: string, system: string, messages: var): void {
        root.stop();
        root.kind = kind;
        root.topic = topic;
        root.question = question;
        root.raw = "";
        root.arriving = "";
        root.error = "";
        root.status = 0;
        root.leftover = "";
        root.finished = false;
        root.streaming = true;
        root.startedAt = Date.now();
        const request = Logic.chatRequest(root.backend, root.settingsFor(root.model), system, messages);
        root.talk = talking.createObject(root, {
            generation: root.generation,
            body: request.body,
            environment: {
                BANDITSHELL_ASSISTANT_KEY: request.auth ? root.key : null
            },
            command: [root.script, request.url, request.auth, "stream"].concat(request.headers)
        });
        root.talk.running = true;
    }

    function take(line: string, generation: int): void {
        if (generation !== root.generation || !root.streaming)
            return;
        const chunk = Logic.readChunk(root.backend, line);
        if (chunk.status) {
            root.status = chunk.status;
            return;
        }
        if (chunk.other)
            root.leftover += `${chunk.other}\n`;
        if (chunk.error)
            root.error = chunk.error;
        if (chunk.text) {
            root.arriving += chunk.text;
            if (!flusher.running)
                flusher.start();
        }
        if (chunk.done)
            root.complete();
    }

    function settle(): void {
        if (!root.arriving)
            return;
        root.raw += root.arriving;
        root.arriving = "";
    }

    function complete(): void {
        if (!root.streaming)
            return;
        root.settle();
        flusher.stop();
        root.streaming = false;
        if (!root.raw.trim() && !root.error)
            root.error = Logic.failureText(root.status, root.leftover);
        root.finished = !root.error;
        if (root.kind === "ask" && root.finished)
            root.turns = root.turns.concat([
                {
                    role: "assistant",
                    content: root.answer.trim()
                }
            ]);
        if (root.inPlace)
            root.deliver();
    }

    function ended(generation: int): void {
        if (generation === root.generation)
            root.complete();
    }

    function stop(): void {
        root.generation += 1;
        if (root.talk) {
            root.talk.running = false;
            root.talk = null;
        }
        if (root.streaming) {
            root.settle();
            flusher.stop();
            root.streaming = false;
            root.finished = !!root.raw.trim();
            if (root.kind === "ask" && root.finished)
                root.turns = root.turns.concat([
                    {
                        role: "assistant",
                        content: root.answer.trim()
                    }
                ]);
        }
    }

    function shownFor(text: string): bool {
        return root.kind !== "" && root.topic === text && (root.streaming || root.finished || !!root.error);
    }

    function followUp(): void {
        root.following = root.answeredTurns > 0;
    }

    function newChat(): void {
        root.stop();
        root.following = false;
        root.turns = [];
        root.kind = "";
        root.topic = "";
        root.raw = "";
        root.error = "";
        root.finished = false;
    }

    function copy(): void {
        if (root.result)
            Clipboard.copy({
                text: root.result
            });
    }

    function typeBack(text: string): void {
        if (!text || !root.canType)
            return;
        typer.text = text;
        typer.restart();
    }

    function replace(): void {
        root.typeBack(root.result);
    }

    function deliver(): void {
        root.inPlace = false;
        if (root.error) {
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "error", root.question, root.error]);
            return;
        }
        if (root.action?.replaces && root.canType) {
            root.typeBack(root.result);
            return;
        }
        root.copy();
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "content_copy", `${root.question} · copied`, Logic.snippet(root.result, 160)]);
    }

    function warm(): void {
        if (!root.local || !root.ready || Date.now() - warming.at < 240000)
            return;
        warming.at = Date.now();
        const request = Logic.warmRequest(root.settingsFor(root.model));
        Quickshell.execDetached(["curl", "-s", "-o", "/dev/null", "--max-time", "300", request.url, "-d", request.body]);
    }

    function readSelection(): void {
        if (root.probed && !root.canReadSelection || selectionReader.running)
            return;
        selectionReader.running = true;
    }

    function setKey(value: string): void {
        root.savedKey = value.trim();
        keySaver.restart();
    }

    QtObject {
        id: warming

        property real at: 0
    }

    Timer {
        id: flusher

        interval: 50
        repeat: true
        onTriggered: {
            root.settle();
            if (!root.streaming)
                flusher.stop();
        }
    }

    Timer {
        id: typer

        property string text: ""

        interval: 250
        onTriggered: Keystrokes.type(typer.text, [])
    }

    Timer {
        id: waitForServer

        property int tries: 0

        interval: 700
        repeat: true
        onTriggered: {
            if (++waitForServer.tries > 40) {
                waitForServer.stop();
                root.setup = "";
                root.trouble = "Ollama did not start";
                root.pending = null;
                return;
            }
            root.list();
        }
    }

    Timer {
        id: keySaver

        interval: 600
        onTriggered: {
            keyWriter.running = false;
            keyWriter.secret = root.savedKey;
            keyWriter.stdinEnabled = true;
            keyWriter.running = true;
            if (root.enabled && !root.local)
                root.list();
        }
    }

    Component {
        id: talking

        Process {
            id: run

            property int generation: 0
            property string body: ""

            stdinEnabled: true

            onStarted: {
                run.write(run.body);
                run.stdinEnabled = false;
            }

            stdout: SplitParser {
                onRead: line => root.take(line, run.generation)
            }

            onExited: root.ended(run.generation)

            onRunningChanged: if (!run.running)
                run.destroy(2000)
        }
    }

    Process {
        id: prober

        command: ["sh", "-c", "for tool in ollama wtype wl-paste curl; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool\"; done; [ -e /proc/driver/nvidia/version ] && echo nvidia; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                text.split("\n").filter(Boolean).forEach(tool => found[tool] = true);
                root.tools = found;
                root.probed = true;
            }
        }
    }

    Process {
        id: lister

        property string listing: ""
        property string backend: ""

        stdout: StdioCollector {
            onStreamFinished: root.takeList(text)
        }
    }

    Process {
        id: puller

        property string body: ""
        property var got: null

        onStarted: {
            puller.write(puller.body);
            puller.stdinEnabled = false;
        }

        stdout: SplitParser {
            onRead: line => root.takePull(line)
        }

        onExited: root.pullEnded()
    }

    Process {
        id: installing

        command: [root.installer, "--polkit"].concat(root.ollamaPackages)
        onExited: code => root.installEnded(code)
    }

    Process {
        id: installInTerminal

        command: [`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.ollamaPackages.join(" ")}`]
        onExited: {
            root.setup = "";
            root.probed = false;
            prober.running = true;
            root.list();
        }
    }

    Process {
        id: selectionReader

        property string then: ""

        command: ["sh", "-c", "wl-paste --primary --no-newline --type text 2>/dev/null | head -c 48000"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selection = text.slice(0, Logic.SELECTION_LIMIT);
                root.selectionRead = true;
                const then = selectionReader.then;
                selectionReader.then = "";
                if (then && root.selection.trim())
                    root.rewrite(then, root.selection, "", true);
                else if (then)
                    Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "text_select_start", "Nothing selected", "Select some text first."]);
            }
        }
    }

    Process {
        id: keyWriter

        property string secret: ""

        command: ["sh", "-c", "umask 077 && mkdir -p -- \"$(dirname -- \"$1\")\" && if [ -n \"$2\" ]; then cat > \"$1.new\" && mv -f -- \"$1.new\" \"$1\"; else rm -f -- \"$1\"; fi", "sh", root.keyPath, root.savedKey ? "write" : ""]

        onStarted: {
            keyWriter.write(keyWriter.secret);
            keyWriter.secret = "";
            keyWriter.stdinEnabled = false;
        }
    }

    FileView {
        id: keyFile

        path: root.keyPath
        printErrors: false
        onLoaded: root.savedKey = keyFile.text().trim()
    }
}
