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
    readonly property bool agent: Logic.isAgent(root.backend)
    readonly property var agentInfo: Logic.AGENTS[root.backend] ?? null

    readonly property string script: `${Quickshell.shellDir}/scripts/assistant-request.sh`
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`
    readonly property string terminal: `${Quickshell.shellDir}/scripts/in-terminal.sh`
    readonly property string sessionDir: `${Config.stateDir}/assistant-session`
    readonly property string agentPath: `${Quickshell.env("HOME")}/.local/bin:${Quickshell.env("PATH") ?? ""}`

    property var tools: ({})
    property bool probed: false

    property var signedIn: ({})
    property real signInCheckedAt: 0
    property string agentStep: ""
    property string agentStepFor: ""
    property var codexModels: []

    property var keys: ({})
    readonly property bool keyed: root.backend === "openai"
    readonly property string savedKey: root.keyed ? root.keys[root.backend] ?? "" : ""
    readonly property string environmentKey: root.keyed && Logic.officialOpenai(root.settings.openaiAddress) ? Quickshell.env("OPENAI_API_KEY") ?? "" : ""
    readonly property string key: root.keyed ? root.savedKey || root.environmentKey : ""
    readonly property bool keyless: Logic.keyless(root.backend, root.settings.openaiAddress)
    readonly property bool keyHeld: !!root.key && root.backend === "openai" && !Logic.keySafe(root.settings.openaiAddress)

    function keyPathFor(backend: string): string {
        return `${Config.stateDir}/assistant-key-${backend}`;
    }

    property var models: []
    property bool reachable: false
    property bool listed: false
    property string listedFor: ""
    property real listedAt: 0
    readonly property string listing: `${root.backend}|${root.settings.ollamaAddress}|${root.settings.openaiAddress}|${root.key ? "key" : ""}`

    readonly property string model: Logic.modelFor(root.backend, root.settings.model, root.models)
    readonly property string modelName: root.model ? root.labelOf(root.model) : root.agent ? root.agentInfo.name : ""

    function labelOf(model: string): string {
        return (root.backend === "codex" ? root.codexModels.find(m => m[0] === model)?.[1] : "") || Logic.modelLabel(model);
    }

    property string oneShotModel: ""
    readonly property var otherModels: Logic.chatModels(root.models)
    readonly property string autoNote: root.backend === "claude" && !root.settings.model && root.models.length ? `${root.labelOf(Logic.askModel("claude", "", root.models, "", 0, false))} for short asks, ${root.labelOf(Logic.askModel("claude", "", root.models, "", 4, false))} for long ones` : ""
    property string usedModel: ""
    readonly property string usedModelName: root.usedModel ? root.labelOf(root.usedModel) : root.modelName
    readonly property bool web: !!root.settings.webSearch && root.agent
    property string summary: ""
    property var askContext: null
    property bool watching: false
    property bool checking: false
    property bool checkAfterProbe: false
    property string checkNote: ""

    property string setup: ""
    property string trouble: ""
    property int progress: 0
    property real pulledBytes: 0
    property real pullBytes: 0
    property var pending: null

    readonly property string phase: {
        if (!root.enabled)
            return "off";
        if (root.agent) {
            if (root.agentStep && root.agentStepFor === root.backend)
                return root.agentStep;
            if (!root.probed)
                return "unknown";
            if (!root.tools[root.backend])
                return "missing";
            const signed = root.signedIn[root.backend];
            return signed === undefined ? "unknown" : signed ? "ready" : "signedout";
        }
        if (!root.local)
            return root.key || root.keyless ? "ready" : "nokey";
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
    readonly property string contextNote: root.askContext ? Logic.contextShort(root.askContext.kind) : ""
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
    property QtObject listRun: null
    property int listGeneration: 0
    property QtObject pullRun: null
    property int pullGeneration: 0
    property string origin: ""
    property bool sourceCut: false

    readonly property var action: Logic.actionOf(root.actionId)
    readonly property string answer: root.kind === "rewrite" ? Logic.visibleText(root.raw).trim() : Logic.undash(Logic.visibleText(root.raw))
    readonly property string result: root.kind === "rewrite" ? Logic.tidyRewrite(root.raw, root.source) : root.answer.trim()
    readonly property int answeredTurns: Math.floor(root.turns.length / 2)
    readonly property string refusal: root.kind === "rewrite" ? Logic.typeBackRefusal(root.result, root.source, root.sourceCut) : ""
    readonly property bool typeable: root.canType && !!root.action?.replaces && !root.refusal && !!root.origin

    property string selection: ""
    property string selectionOrigin: ""
    property bool selectionRead: false

    Component.onCompleted: root.refresh()

    onListingChanged: if (root.enabled)
        Qt.callLater(root.list)

    onEnabledChanged: if (root.enabled)
        root.refresh()

    onBackendChanged: if (root.enabled)
        root.refresh()

    function refresh(): void {
        if (!root.enabled)
            return;
        if (!root.probed && !prober.running)
            prober.running = true;
        if (root.agent && root.probed && root.signedIn[root.backend] !== true && Date.now() - root.signInCheckedAt > 3000)
            root.checkSignIn();
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

    function wire(request: var, method: string): var {
        const key = request.auth ? Logic.keyFor(request.url, root.key) : "";
        return {
            command: [root.script, request.url, key ? request.auth : "", method].concat(request.headers),
            environment: {
                BANDITSHELL_ASSISTANT_KEY: key || null
            }
        };
    }

    function checkSignIn(): void {
        if (!root.agent || !root.tools[root.backend] || signInChecker.running)
            return;
        root.signInCheckedAt = Date.now();
        signInChecker.backend = root.backend;
        signInChecker.command = ["timeout", "10"].concat(root.agentInfo.status);
        signInChecker.running = true;
    }

    function signInChecked(backend: string, code: int): void {
        root.setSignedIn(backend, code === 0);
        if (root.checking && backend === root.backend) {
            root.checking = false;
            root.checkNote = code === 0 ? "signed in" : code === 124 ? `${root.agentInfo.name} did not answer in time` : `not signed in to ${root.agentInfo.name}`;
        }
        if (backend !== root.backend)
            Qt.callLater(root.checkSignIn);
        else if (root.ready)
            root.flush();
    }

    function setSignedIn(backend: string, signed: bool): void {
        const next = Object.assign({}, root.signedIn);
        next[backend] = signed;
        root.signedIn = next;
    }

    function forgetSignIn(backend: string): void {
        const next = Object.assign({}, root.signedIn);
        delete next[backend];
        root.signedIn = next;
    }

    function inTerminal(step: string, script: string): void {
        root.agentStep = step;
        root.agentStepFor = root.backend;
        root.trouble = "";
        agentTerminal.command = [root.terminal, `${script} || { echo; printf 'Press Enter to close. '; read _; }`];
        agentTerminal.running = true;
    }

    function terminalClosed(): void {
        root.forgetSignIn(root.agentStepFor);
        root.agentStep = "";
        root.agentStepFor = "";
        codexCache.reload();
        root.probed = false;
        prober.running = true;
    }

    function list(): void {
        if (root.agent) {
            root.models = root.backend === "claude" ? Logic.CLAUDE_MODELS.map(m => m[0]) : root.codexModels.map(m => m[0]);
            root.reachable = true;
            root.listed = true;
            root.listedFor = root.listing;
            root.listedAt = Date.now();
            return;
        }
        if (!root.local && !root.key && !root.keyless) {
            root.models = [];
            root.listed = true;
            root.listedFor = root.listing;
            return;
        }
        if (root.listRun && root.listRun.listing === root.listing)
            return;
        if (root.listRun)
            root.listRun.running = false;
        root.listGeneration += 1;
        const wired = root.wire(Logic.listRequest(root.backend, root.settingsFor("")), "get");
        root.listRun = listingRequest.createObject(root, {
            generation: root.listGeneration,
            listing: root.listing,
            backend: root.backend,
            environment: wired.environment,
            command: wired.command
        });
        root.listRun.running = true;
    }

    function listEnded(generation: int): void {
        if (generation === root.listGeneration)
            root.listRun = null;
    }

    function takeList(text: string, generation: int, listing: string, backend: string): void {
        if (generation !== root.listGeneration || listing !== root.listing) {
            if (root.checking && generation === root.listGeneration) {
                root.checking = false;
                root.checkNote = "the settings changed, press Check again";
            }
            return;
        }
        root.listRun = null;
        const got = Logic.splitStatus(text);
        const names = Logic.readModels(backend, got.body);
        root.reachable = got.status === 200 && names !== null;
        root.models = root.reachable ? names : [];
        root.listed = true;
        root.listedFor = listing;
        root.listedAt = Date.now();
        if (root.checking) {
            root.checking = false;
            root.checkNote = root.reachable ? "connected" : Logic.failureText(got.status, got.body);
        }
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
            if (root.agent)
                root.inTerminal("installing", root.agentInfo.install);
            else
                root.install();
            return;
        case "signedout":
            root.inTerminal("signingin", root.agentInfo.signIn);
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
        case "installing":
        case "signingin":
        case "starting":
        case "pulling":
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
            root.ask(next.question, next.topic, next.context ?? null);
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
        if (root.pullRun)
            return;
        root.setup = "pulling";
        root.progress = 0;
        root.pulledBytes = 0;
        root.pullBytes = Logic.STARTER.bytes;
        root.pullGeneration += 1;
        const request = Logic.pullRequest(root.settingsFor(""), name);
        root.pullRun = pullingRequest.createObject(root, {
            generation: root.pullGeneration,
            body: request.body,
            command: [root.script, request.url, "", "stream"].concat(request.headers)
        });
        root.pullRun.running = true;
    }

    function takePull(line: string, generation: int): void {
        if (generation !== root.pullGeneration || !root.pullRun)
            return;
        const state = Logic.readPull(root.pullRun.got, line);
        root.pullRun.got = state;
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

    function pullEnded(generation: int, got: var): void {
        if (generation !== root.pullGeneration)
            return;
        root.pullRun = null;
        root.setup = "";
        if (!got?.done && !root.trouble)
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
        root.trouble = code === 126 ? "" : code === 3 ? "no Ollama package for this system" : "Ollama did not install";
        root.pending = null;
    }

    function openDownloadPage(): void {
        Quickshell.execDetached(["xdg-open", root.agent ? root.agentInfo.page : "https://ollama.com/download"]);
    }

    function today(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function ask(question: string, topic: string, context: var): void {
        if (!question)
            return;
        if (!root.ready) {
            root.setUp({
                kind: "ask",
                question: question,
                topic: topic,
                context: context ?? null
            });
            return;
        }
        root.stop();
        const before = root.following ? root.turns : [];
        if (!root.following)
            root.summary = "";
        const joined = before.concat([
            {
                role: "user",
                content: Logic.withContext(question, context),
                shown: question
            }
        ]);
        root.turns = Logic.trimTurns(joined, 8, 16000);
        root.summary = Logic.extendSummary(root.summary, Logic.droppedTurns(joined, root.turns));
        root.askContext = context ?? null;
        root.inPlace = false;
        root.actionId = "";
        root.source = "";
        root.usedModel = root.pickModel(question, root.turns.length, !!context);
        root.begin("ask", topic, question, Logic.askPrompt(root.today(), root.summary, root.webFor(root.turns)), root.turns);
    }

    function webFor(turns: var): bool {
        return root.web && !Logic.hasContext(turns);
    }

    function pickModel(text: string, turnCount: int, withContext: bool): string {
        const chosen = root.oneShotModel || root.settings.model;
        root.oneShotModel = "";
        return Logic.askModel(root.backend, chosen, root.models, text, turnCount, withContext);
    }

    function askWith(kind: string, question: string, topic: string): void {
        if (!question)
            return;
        if (kind === "window") {
            const top = Hypr.toplevelFor(Hypr.focusedAddress);
            const text = Logic.windowContext(top?.title, top?.lastIpcObject?.class);
            if (!text) {
                root.notify("web_asset_off", "Nothing to attach", "No window has focus.");
                return;
            }
            root.ask(question, topic, {
                kind: "window",
                text: text
            });
            return;
        }
        const reader = contextRequest.createObject(root, {
            kind: kind,
            question: question,
            topic: topic,
            command: ["sh", "-c", kind === "selection" ? "wl-paste --primary --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint && exit 0; wl-paste --primary --no-newline --type text 2>/dev/null | head -c 60001" : "wl-paste --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint && exit 0; wl-paste --no-newline --type text 2>/dev/null | head -c 60001"]
        });
        reader.running = true;
    }

    function retryWith(model: string): void {
        if (root.kind !== "ask" || root.streaming || root.turns.length < 2)
            return;
        const question = root.question;
        const topic = root.topic;
        const context = root.askContext;
        root.oneShotModel = model;
        root.turns = root.turns.slice(0, -2);
        root.following = root.turns.length > 0;
        root.ask(question, topic, context);
    }

    function cycleModel(): void {
        root.retryWith(Logic.nextModel(root.models, root.usedModel));
    }

    function checkConnection(): void {
        if (!root.enabled)
            return;
        root.checking = true;
        root.checkNote = "checking";
        root.checkAfterProbe = true;
        checkTimeout.restart();
        prober.running = true;
    }

    function continueCheck(): void {
        if (!root.checking)
            return;
        if (root.agent) {
            if (!root.tools[root.backend]) {
                root.checking = false;
                root.checkNote = `${root.agentInfo.name} is not installed`;
                return;
            }
            if (signInChecker.running) {
                root.checking = false;
                root.checkNote = "still checking, try again in a moment";
                return;
            }
            root.checkSignIn();
            return;
        }
        if (!root.local && !root.key && !root.keyless) {
            root.checking = false;
            root.checkNote = "no API key yet";
            return;
        }
        root.listedFor = "";
        root.list();
    }

    function signOut(): void {
        if (!root.agent || signOutRun.running)
            return;
        signOutRun.backend = root.backend;
        signOutRun.command = ["timeout", "10"].concat(root.agentInfo.signOut);
        signOutRun.running = true;
    }

    function signedOutDone(backend: string, code: int): void {
        if (code !== 0) {
            root.checkNote = code === 124 ? `${Logic.AGENTS[backend].name} did not answer in time` : `could not sign out of ${Logic.AGENTS[backend].name}`;
            return;
        }
        root.setSignedIn(backend, false);
        root.checkNote = `signed out of ${Logic.AGENTS[backend].name}`;
    }

    function contextRead(kind: string, text: string, question: string, topic: string): void {
        if (!text.trim()) {
            root.notify("content_paste_off", "Nothing to attach", kind === "selection" ? "Select some text first." : "The clipboard has no text.");
            return;
        }
        root.ask(question, topic, {
            kind: kind,
            text: text
        });
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
        root.stop();
        root.following = false;
        root.inPlace = inPlace;
        root.actionId = actionId;
        root.origin = root.selectionOrigin;
        root.askContext = null;
        root.usedModel = root.model;
        root.sourceCut = text.length > Logic.SELECTION_LIMIT;
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
        if (root.agent) {
            root.talk = talking.createObject(root, {
                generation: root.generation,
                body: Logic.agentPrompt(messages),
                environment: {
                    ANTHROPIC_API_KEY: null,
                    PATH: root.agentPath
                },
                command: ["sh", "-c", "mkdir -p -- \"$1\" && cd -- \"$1\" && shift && exec \"$@\"", "sh", root.sessionDir].concat(Logic.agentCommand(root.backend, root.usedModel || root.model, system, kind === "ask" && root.webFor(messages)))
            });
            root.talk.running = true;
            return;
        }
        const request = Logic.chatRequest(root.backend, root.settingsFor(root.usedModel || root.model), system, messages);
        const wired = root.wire(request, "stream");
        root.talk = talking.createObject(root, {
            generation: root.generation,
            body: request.body,
            environment: wired.environment,
            command: wired.command
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
            if (chunk.block && (root.raw || root.arriving))
                root.arriving += "\n\n";
            root.arriving += chunk.text;
            if (!flusher.running)
                flusher.start();
        }
        if (chunk.done)
            root.complete();
    }

    function takeError(line: string, generation: int): void {
        if (generation === root.generation && root.streaming && root.agent)
            root.leftover += `${line}\n`;
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
            root.error = root.agent ? Logic.agentFailure(root.backend, root.leftover) : Logic.failureText(root.status, root.leftover);
        if (root.agent && Logic.signedOut(root.error))
            root.setSignedIn(root.backend, false);
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
        else if (root.watching <= 0 && root.kind === "ask")
            root.notifyFinished();
    }

    function notifyFinished(): void {
        if (root.error)
            root.notify("error", root.question, root.error);
        else if (root.result)
            root.notify("auto_awesome", root.question, Logic.snippet(root.result, 160));
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

    function launcherClosed(): void {
        if (root.streaming && root.kind === "ask")
            return;
        root.stop();
    }

    function shownFor(text: string): bool {
        return root.kind !== "" && root.topic === text && (root.streaming || root.finished || !!root.error);
    }

    function followUp(): void {
        root.following = root.answeredTurns > 0;
    }

    function newChat(): void {
        root.stop();
        root.summary = "";
        root.askContext = null;
        root.oneShotModel = "";
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

    function copyChat(): void {
        if (root.turns.length)
            Clipboard.copy({
                text: Logic.transcript(root.turns)
            });
    }

    function notify(icon: string, title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", icon, title, body]);
    }

    function copyInstead(text: string, why: string): void {
        Clipboard.copy({
            text: text
        });
        root.notify("content_copy", `${root.question} · copied`, why || Logic.snippet(text, 160));
    }

    function replace(): void {
        if (!root.result)
            return;
        if (!root.typeable) {
            root.copyInstead(root.result, root.refusal || (!root.canType ? "wtype is not installed" : "the window it came from is not known"));
            return;
        }
        typer.text = root.result;
        typer.origin = root.origin;
        typer.restart();
    }

    function typeNow(): void {
        if (!typer.origin || Hypr.focusedAddress !== typer.origin) {
            root.copyInstead(typer.text, "the window changed, so it was not typed");
            return;
        }
        Keystrokes.type(typer.text, []);
    }

    function deliver(): void {
        root.inPlace = false;
        if (root.error) {
            root.notify("error", root.question, root.error);
            return;
        }
        if (root.action?.replaces) {
            root.replace();
            return;
        }
        root.copyInstead(root.result, "");
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
        if (!root.keyed)
            return;
        const next = Object.assign({}, root.keys);
        next[root.backend] = value.trim();
        root.keys = next;
        keySaver.backend = root.backend;
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
        property string origin: ""

        interval: 250
        onTriggered: root.typeNow()
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
            if (!root.listRun)
                root.list();
        }
    }

    Timer {
        id: keySaver

        property string backend: ""

        interval: 600
        onTriggered: {
            const secret = root.keys[keySaver.backend] ?? "";
            keyWriter.running = false;
            keyWriter.secret = secret;
            keyWriter.command = ["sh", "-c", "umask 077 && mkdir -p -- \"$(dirname -- \"$1\")\" && if [ -n \"$2\" ]; then cat > \"$1.new\" && mv -f -- \"$1.new\" \"$1\"; else rm -f -- \"$1\"; fi", "sh", root.keyPathFor(keySaver.backend), secret ? "write" : ""];
            keyWriter.stdinEnabled = true;
            keyWriter.running = true;
            if (root.enabled && root.keyed)
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

            stderr: SplitParser {
                onRead: line => root.takeError(line, run.generation)
            }

            onExited: root.ended(run.generation)

            onRunningChanged: if (!run.running)
                run.destroy(2000)
        }
    }

    Process {
        id: prober

        environment: ({
                PATH: root.agentPath
            })
        command: ["sh", "-c", "for tool in ollama claude codex wtype wl-paste curl; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool\"; done; [ -e /proc/driver/nvidia/version ] && echo nvidia; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                text.split("\n").filter(Boolean).forEach(tool => found[tool] = true);
                root.tools = found;
                root.probed = true;
                if (root.checkAfterProbe) {
                    root.checkAfterProbe = false;
                    root.continueCheck();
                } else
                    root.checkSignIn();
            }
        }
    }

    Component {
        id: listingRequest

        Process {
            id: lister

            property int generation: 0
            property string listing: ""
            property string backend: ""

            stdout: StdioCollector {
                onStreamFinished: root.takeList(text, lister.generation, lister.listing, lister.backend)
            }

            onRunningChanged: if (!lister.running) {
                root.listEnded(lister.generation);
                lister.destroy(2000);
            }
        }
    }

    Component {
        id: pullingRequest

        Process {
            id: puller

            property int generation: 0
            property string body: ""
            property var got: null

            stdinEnabled: true

            onStarted: {
                puller.write(puller.body);
                puller.stdinEnabled = false;
            }

            stdout: SplitParser {
                onRead: line => root.takePull(line, puller.generation)
            }

            onExited: root.pullEnded(puller.generation, puller.got)

            onRunningChanged: if (!puller.running)
                puller.destroy(2000)
        }
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
        id: signInChecker

        property string backend: ""

        environment: ({
                PATH: root.agentPath
            })
        onExited: code => root.signInChecked(signInChecker.backend, code)
    }

    Process {
        id: agentTerminal

        onExited: root.terminalClosed()
    }

    Process {
        id: selectionReader

        property string then: ""

        command: ["sh", "-c", "wl-paste --primary --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint && exit 0; wl-paste --primary --no-newline --type text 2>/dev/null | head -c 60001"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selection = text;
                root.selectionOrigin = Hypr.focusedAddress;
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

    Component {
        id: contextRequest

        Process {
            id: reader

            property string kind: ""
            property string question: ""
            property string topic: ""

            stdout: StdioCollector {
                onStreamFinished: root.contextRead(reader.kind, text, reader.question, reader.topic)
            }

            onRunningChanged: if (!reader.running)
                reader.destroy(2000)
        }
    }

    Timer {
        id: checkTimeout

        interval: 15000
        onTriggered: if (root.checking) {
            root.checking = false;
            root.checkAfterProbe = false;
            root.checkNote = "no answer, try again";
        }
    }

    Process {
        id: signOutRun

        property string backend: ""

        environment: ({
                PATH: root.agentPath
            })
        onExited: code => root.signedOutDone(signOutRun.backend, code)
    }

    Process {
        id: keyWriter

        property string secret: ""

        onStarted: {
            keyWriter.write(keyWriter.secret);
            keyWriter.secret = "";
            keyWriter.stdinEnabled = false;
        }
    }

    function loadedKey(backend: string, text: string): void {
        const next = Object.assign({}, root.keys);
        next[backend] = text.trim();
        root.keys = next;
    }

    FileView {
        id: openaiKey

        path: root.keyPathFor("openai")
        printErrors: false
        onLoaded: root.loadedKey("openai", openaiKey.text())
    }

    FileView {
        id: codexCache

        path: root.backend === "codex" ? `${Quickshell.env("CODEX_HOME") || `${Quickshell.env("HOME")}/.codex`}/models_cache.json` : ""
        printErrors: false
        onLoaded: {
            root.codexModels = Logic.readCodexModels(codexCache.text());
            if (root.backend === "codex")
                root.list();
        }
    }
}
