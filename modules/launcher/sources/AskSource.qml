import QtQuick
import Quickshell
import qs.services
import "../../../services/assistant.js" as Logic
import "../prefixes.js" as Prefixes

QtObject {
    id: root

    required property var search

    readonly property var asked: Prefixes.asked(root.search.text) ? null : Logic.askOf(root.search.text)
    readonly property bool explicit: root.asked !== null && Assistant.enabled
    readonly property bool questionLike: !root.explicit && Assistant.ready && root.search.text.length > 8 && Logic.looksLikeQuestion(root.search.text)
    readonly property string question: root.explicit ? root.asked : root.questionLike ? root.search.text : ""

    readonly property bool intent: root.explicit

    readonly property var kinds: ["ask", "assistantsetup"]

    property Connections opening: Connections {
        target: root.search

        function onStartedChanged(): void {
            if (root.search.started)
                Assistant.refresh();
        }
    }

    onExplicitChanged: if (root.explicit) {
        Assistant.refresh();
        Assistant.warm();
    }

    readonly property var prefixes: !Assistant.enabled ? [] : [
            {
                section: "Ask and look up",
                word: "ask",
                example: "ask why is the sky blue",
                about: "Ask the assistant",
                icon: "auto_awesome",
                also: []
            }
        ]

    readonly property var groups: [
        {
            key: "ask",
            title: "Ask",
            items: root.rows
        }
    ]

    readonly property string backendName: (Logic.BACKENDS.find(b => b[0] === Assistant.backend) ?? ["", ""])[1]

    readonly property var setupRow: {
        const base = {
            key: "assistantsetup",
            kind: "assistantsetup",
            detail: Assistant.trouble,
            icon: "auto_awesome",
            score: Infinity
        };
        switch (Assistant.phase) {
        case "missing":
            return Object.assign(base, {
                label: "Install Ollama"
            });
        case "installing":
            return Object.assign(base, {
                label: "Installing Ollama",
                detail: ""
            });
        case "stopped":
            return Object.assign(base, {
                label: "Start Ollama"
            });
        case "starting":
            return Object.assign(base, {
                label: "Starting Ollama",
                detail: ""
            });
        case "empty":
            return Object.assign(base, {
                label: `Download ${Logic.STARTER.label}`,
                detail: Assistant.trouble || Logic.sizeText(Logic.STARTER.bytes)
            });
        case "pulling":
            return Object.assign(base, {
                label: `Downloading ${Logic.STARTER.label}`,
                detail: `${Assistant.progress}% · ${Logic.sizeText(Assistant.pulledBytes)} of ${Logic.sizeText(Assistant.pullBytes)}`,
                icon: "download"
            });
        case "nokey":
            return Object.assign(base, {
                label: "Add an API key",
                detail: root.backendName,
                icon: "key"
            });
        case "unreachable":
            return Object.assign(base, {
                label: "Ollama is not answering",
                detail: Assistant.settings.ollamaAddress
            });
        }
        return null;
    }

    readonly property var rows: {
        if (!root.explicit && !root.questionLike)
            return [];
        if (!Assistant.ready)
            return root.explicit && root.setupRow ? [root.setupRow] : [];
        if (!root.question || Assistant.kind === "ask" && !Assistant.error && Assistant.shownFor(root.search.text))
            return [];
        return [
            {
                key: "ask:question",
                kind: "ask",
                question: root.question,
                label: root.question,
                detail: Assistant.following && root.explicit ? `${Assistant.modelName} · follow-up` : Assistant.modelName,
                icon: "auto_awesome",
                tab: !root.explicit,
                score: root.explicit ? Infinity : 0.6
            }
        ];
    }

    readonly property var commands: [
        {
            id: "assistantsetup",
            icon: "auto_awesome",
            label: "Set up AI answers",
            words: "ai assistant ollama llm local model set up download start",
            detail: Assistant.phase === "pulling" ? `${Assistant.progress}%` : "",
            hidden: !Assistant.enabled || !Assistant.local || Assistant.ready || Assistant.phase === "unknown",
            stay: true,
            run: () => Assistant.setUp(null)
        },
        {
            id: "assistantnewchat",
            icon: "restart_alt",
            label: "New AI chat",
            words: "ai chat new forget conversation clear",
            hidden: !Assistant.answeredTurns,
            stay: true,
            run: () => Assistant.newChat()
        }
    ]

    function pendingAsk(): var {
        return root.question ? {
            kind: "ask",
            question: root.question,
            topic: root.search.text
        } : null;
    }

    function openSettings(): void {
        const screen = root.search.screenName;
        root.search.leave(() => Settings.openAt(screen, "launcher", "aiKey"));
    }

    function activate(row: var): void {
        if (row.kind === "ask") {
            if (Assistant.streaming && Assistant.topic === root.search.text)
                return;
            Assistant.ask(row.question, root.search.text);
            return;
        }
        if (Assistant.phase === "nokey" || Assistant.phase === "unreachable") {
            root.openSettings();
            return;
        }
        Assistant.setUp(root.pendingAsk());
    }

    function complete(row: var): bool {
        if (row?.kind !== "ask")
            return false;
        root.activate(row);
        return true;
    }

    function actionsFor(row: var): var {
        if (row.kind === "ask")
            return [
                {
                    icon: "auto_awesome",
                    label: "Ask",
                    run: () => root.activate(row)
                }
            ];
        const apiKey = {
            icon: "key",
            label: "Use an API key",
            short: "API key",
            run: () => root.openSettings()
        };
        switch (Assistant.phase) {
        case "missing":
            return [
                {
                    icon: "download",
                    label: "Install",
                    run: () => root.activate(row)
                },
                {
                    icon: "open_in_new",
                    label: "Get Ollama",
                    run: () => root.search.leave(() => Assistant.openDownloadPage())
                },
                apiKey
            ];
        case "stopped":
            return [
                {
                    icon: "play_arrow",
                    label: "Start",
                    run: () => root.activate(row)
                },
                apiKey
            ];
        case "empty":
            return [
                {
                    icon: "download",
                    label: "Download",
                    run: () => root.activate(row)
                },
                apiKey
            ];
        case "nokey":
        case "unreachable":
            return [
                {
                    icon: "tune",
                    label: "Open settings",
                    run: () => root.openSettings()
                }
            ];
        }
        return [];
    }
}
