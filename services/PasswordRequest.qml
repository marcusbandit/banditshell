pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    property int asked: 0
    property string screenName: ""

    readonly property string kind: "password"

    property string title: ""
    property string message: ""
    property string placeholder: "password"
    property string warning: ""
    property string continueLabel: ""

    property string secret: ""
    property var facts: []
    property string hint: ""

    readonly property bool choiceChosen: false
    readonly property string cancelLabel: "cancel"
    readonly property bool busy: false

    property var taker: null
    property var dropper: null

    function ask(request: var): void {
        root.title = request.title ?? "";
        root.message = request.message ?? "";
        root.placeholder = request.placeholder ?? "password";
        root.warning = request.warning ?? "";
        root.continueLabel = request.continueLabel ?? "continue";
        root.secret = request.secret ?? "";
        root.facts = request.facts ?? [];
        root.hint = request.hint ?? "";
        root.taker = request.take ?? null;
        root.dropper = request.cancel ?? null;
        const names = Quickshell.screens.map(screen => screen.name);
        root.screenName = names.includes(request.screenName) ? request.screenName : names.includes(Focus.offStageScreen) ? Focus.offStageScreen : names[0] ?? "";
        root.asked += 1;
        root.active = true;
    }

    function submit(secret: string): void {
        if (!root.active)
            return;
        const take = root.taker;
        root.close();
        if (take)
            take(secret);
    }

    function refuse(): void {
        if (!root.active)
            return;
        const drop = root.dropper;
        root.close();
        if (drop)
            drop();
    }

    function close(): void {
        root.active = false;
        root.taker = null;
        root.dropper = null;
        root.warning = "";
    }

    function scene(name: string): bool {
        if (name !== "wifi")
            return false;
        root.ask({
            title: "Join Cafe Corner",
            message: "WPA2 network",
            placeholder: "Password",
            secret: "Wi-Fi password",
            facts: [["Network", "Cafe Corner"], ["Security", "WPA2"]],
            hint: "The network's own password, often printed on the router.",
            continueLabel: "join",
            screenName: Focus.offStageScreen
        });
        return true;
    }

    function confirm(): void {
    }

    function choose(on: bool): void {
    }
}
