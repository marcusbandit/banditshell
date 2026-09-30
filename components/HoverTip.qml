import QtQuick

HoverHandler {
    id: root

    property string text: ""
    property Item host: root.parent

    property bool now: false

    property bool asked: root.hovered

    enabled: !!root.text

    onAskedChanged: {
        if (root.asked)
            Tooltips.request(root.host, root.text, root.now);
        else
            Tooltips.release(root.host);
    }

    onEnabledChanged: if (!root.enabled)
        Tooltips.release(root.host)

    onTextChanged: if (root.asked)
        Tooltips.request(root.host, root.text, root.now)

    Component.onDestruction: Tooltips.release(root.host)
}
