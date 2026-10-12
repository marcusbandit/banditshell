import QtQuick
import qs.config
import qs.services

Item {
    id: root

    required property var entries

    readonly property real cap: Appearance.sizes.notificationBadge * 4

    readonly property var waiting: root.entries.find(e => e?.wantsCopy) ?? null

    property NotificationEntry entry: null
    property string claimed: ""

    onWaitingChanged: Qt.callLater(root.begin)
    Component.onCompleted: Qt.callLater(root.begin)

    onEntryChanged: if (!root.entry && root.claimed)
        root.moveOn()

    function begin(): void {
        if (root.claimed)
            return;

        const e = root.waiting;
        if (!e || !e.wantsCopy)
            return;

        root.entry = e;
        root.claimed = e.image;
        e.copying = true;
        picture.source = e.image;
    }

    function finish(): void {
        const e = root.entry;
        const claim = root.claimed;
        const target = e?.copyPathFor(claim) ?? "";
        if (!target)
            return root.moveOn();

        const ok = picture.grabToImage(result => {
            if (root.entry !== e || root.claimed !== claim)
                return;

            if (result.saveToFile(Qt.resolvedUrl(`file://${target}`)))
                e.keep(target);
            else
                console.warn(`Notifications: could not write ${target}; ${e.appName} keeps its picture only until its sender closes it.`);

            root.moveOn();
        });

        if (!ok)
            root.moveOn();
    }

    function moveOn(): void {
        root.claimed = "";
        picture.source = "";
        root.entry = null;
        Qt.callLater(root.begin);
    }

    Component.onDestruction: {
        if (root.entry && root.entry.image === root.claimed)
            root.entry.copying = false;
    }

    Image {
        id: picture

        visible: false
        asynchronous: true
        smooth: true
        cache: false

        readonly property real shrink: Math.min(1, root.cap / Math.max(1, implicitWidth, implicitHeight))

        width: implicitWidth * shrink
        height: implicitHeight * shrink

        onStatusChanged: {
            if (!root.claimed)
                return;
            if (picture.status === Image.Ready)
                root.finish();
            else if (picture.status === Image.Error)
                root.moveOn();
        }
    }
}
