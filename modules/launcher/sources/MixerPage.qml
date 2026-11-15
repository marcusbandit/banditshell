import QtQuick
import qs.config
import qs.services
import qs.modules.mixer

Item {
    id: root

    property string typed: ""
    property string query: ""
    property string selection: ""
    property var view: null

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)
    signal asks(Item item, var actions, real x, real y)

    implicitHeight: Math.max(Appearance.sizes.rowHeight * 6, mixer.contentHeight + footer.implicitHeight)

    function popOut(): void {
        root.leave(() => Mixer.show());
    }

    function openActions(): void {
        const acts = mixer.actionsForCurrent().concat([
            {
                icon: "open_in_new",
                label: "Open in a window",
                run: () => root.popOut()
            }
        ]);
        root.asks(footer, acts, footer.width / 2, footer.height / 2);
    }

    function claimKey(event: var): bool {
        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            root.openActions();
            return true;
        }
        return mixer.claimKey(event);
    }

    MixerView {
        id: mixer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        filter: root.query

        onAsks: (item, actions, x, y) => root.asks(item, actions, x, y)
    }

    PageFooter {
        id: footer

        anchors.bottom: parent.bottom
        width: root.width
        icon: "tune"
        title: mixer.currentName || "Mixer"
        primary: mixer.currentName ? mixer.currentMuted ? "Unmute" : "Mute" : ""
        onPrimed: mixer.toggle()
        onAsked: root.openActions()
    }
}
