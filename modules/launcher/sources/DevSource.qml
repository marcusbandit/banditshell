import QtQuick
import qs.services
import "../../../services/dev-utilities.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["developer"]

    readonly property var ask: Logic.devAsk(root.search.text)
    readonly property bool intent: !!root.ask?.explicit
    readonly property string drawKey: Logic.drawKey(root.ask, DevUtilities.passwordLength)
    readonly property bool needsClipboard: !!root.ask?.explicit && !root.drawKey && root.ask.input === null

    onDrawKeyChanged: if (root.drawKey)
        DevUtilities.want(root.drawKey)

    onNeedsClipboardChanged: if (root.needsClipboard)
        DevUtilities.readClipboard()

    readonly property bool started: root.search.started

    onStartedChanged: if (!root.started)
        DevUtilities.forget()

    readonly property var drawn: root.drawKey ? DevUtilities.drawn[root.drawKey] : undefined
    readonly property string input: root.needsClipboard ? DevUtilities.clipboardText : ""
    readonly property bool secretClipboard: root.needsClipboard && !DevUtilities.fromHistory && DevUtilities.clipboardSecret
    readonly property bool copyBlocked: DevUtilities.sensitiveProbed && !DevUtilities.sensitiveCopy

    readonly property var icons: ({
            uuid: "fingerprint",
            password: "password",
            random: "casino",
            dice: "casino",
            coin: "toll",
            base64: "data_array",
            url: "percent",
            html: "code",
            hash: "tag",
            json: "data_object",
            jwt: "key",
            case: "text_fields",
            epoch: "schedule",
            now: "schedule",
            count: "format_list_numbered"
        })

    readonly property var againLabels: ({
            uuid: "Another",
            password: "Another",
            random: "Again",
            dice: "Roll again",
            coin: "Flip again"
        })

    function stamp(answer: var): string {
        const moment = new Date(answer.when);
        const text = `${TimeFormat.dateText(moment, "year")} ${TimeFormat.time(moment, true)}`;
        return answer.prefix ? `${answer.prefix} ${text}` : text;
    }

    function row(answer: var): var {
        const dated = answer.when !== undefined;
        const hidden = answer.secret && DevUtilities.revealed !== root.drawKey;
        const label = dated ? root.stamp(answer) : hidden ? "•".repeat(12) : answer.label;
        return {
            key: `developer:${answer.id}`,
            kind: "developer",
            answer: answer,
            tool: root.ask.tool,
            copyText: answer.copy === null ? (dated ? label : "") : answer.copy,
            label: label,
            detail: answer.secret && root.copyBlocked ? `${answer.detail} · copy off, wl-copy lacks --sensitive` : answer.detail,
            icon: answer.expired ? "timer_off" : root.icons[root.ask.tool] ?? "terminal",
            peekText: hidden ? "" : answer.peek || "",
            score: root.ask.explicit ? Infinity : 0.4
        };
    }

    readonly property var rows: !root.ask ? [] : root.secretClipboard ? [root.row(Logic.secretClipboard())] : Logic.answers(root.ask, root.input, root.drawn, Date.now()).map(answer => root.row(answer))

    readonly property var prefixes: [
        {
            section: "Text and numbers",
            word: "random",
            example: "random 1 to 6",
            about: "Random number",
            icon: "casino",
            also: ["roll"]
        },
        {
            section: "Text and numbers",
            word: "password",
            example: "password 24",
            about: "Make a password",
            icon: "password",
            also: ["passwd", "pin"]
        },
        {
            section: "Text and numbers",
            word: "uuid",
            example: "uuid 3",
            about: "Make a UUID",
            icon: "fingerprint",
            also: ["guid"]
        },
        {
            section: "Text and numbers",
            word: "wc",
            example: "wc words hello there",
            about: "Count words or characters",
            icon: "format_list_numbered",
            also: ["count"]
        },
        {
            section: "Text and numbers",
            word: "b64",
            example: "b64 decode aGk=",
            about: "Base64 encode or decode",
            icon: "code",
            also: ["base64"]
        },
        {
            section: "Text and numbers",
            word: "json",
            example: "json pretty {\"a\":1}",
            about: "Format or check JSON",
            icon: "data_object",
            also: []
        },
        {
            section: "Text and numbers",
            word: "jwt",
            example: "jwt eyJhbGciOi...",
            about: "Decode a token",
            icon: "key",
            also: []
        },
        {
            section: "Text and numbers",
            word: "sha256",
            example: "sha256 hello",
            about: "Hash text",
            icon: "tag",
            also: ["md5", "hash", "checksum"]
        },
        {
            section: "Text and numbers",
            word: "epoch",
            example: "epoch 1700000000",
            about: "Unix time to a date",
            icon: "schedule",
            also: ["unix", "timestamp"]
        }
    ]

    readonly property var groups: [
        {
            key: "developer",
            title: "Developer",
            items: root.rows
        }
    ]

    readonly property var caps: ({
            developer: 20
        })

    readonly property var phrases: Logic.PHRASES

    function copy(text: string, secret: bool): void {
        if (!text)
            return;
        if (secret)
            root.search.leave(() => DevUtilities.copySecret(text));
        else
            root.search.leave(() => Clipboard.copy({
                    text: text
                }));
    }

    function type(text: string): void {
        const address = root.search.windowTarget();
        root.search.leave(() => Typist.type(text, 0, address));
    }

    function activate(row: var): void {
        if (row.answer.failed)
            return;
        if (row.answer.secret && root.copyBlocked)
            DevUtilities.reveal(root.drawKey);
        else
            root.copy(row.copyText, !!row.answer.secret);
    }

    function actionsFor(row: var): var {
        const answer = row.answer;
        if (answer.failed)
            return [];
        const acts = answer.secret && root.copyBlocked ? [] : [
            {
                icon: "content_copy",
                label: "Copy",
                button: true,
                run: () => root.activate(row)
            }
        ];
        if (answer.secret) {
            const key = root.drawKey;
            const shown = DevUtilities.revealed === key;
            acts.push({
                icon: shown ? "visibility_off" : "visibility",
                label: shown ? "Hide" : "Show",
                button: true,
                run: () => DevUtilities.reveal(key)
            });
        }
        else if (Typist.found)
            acts.push({
                icon: "keyboard",
                label: "Type",
                run: () => root.type(row.copyText)
            });
        if (answer.redraw) {
            const key = root.drawKey;
            acts.push({
                icon: "refresh",
                label: root.againLabels[row.tool] ?? "Again",
                run: () => DevUtilities.redraw(key)
            });
        }
        if (answer.alternate)
            acts.push({
                icon: "content_copy",
                label: answer.alternateLabel,
                short: answer.alternateShort,
                run: () => root.copy(answer.alternate, false)
            });
        return acts;
    }
}
