import QtQuick

Item {
    id: root

    required property int index
    required property var deck
    required property string openSpecial

    readonly property var entry: root.deck[root.index] ?? ({
            name: "",
            label: "",
            windows: []
        })

    readonly property bool open: !!root.entry.name && root.openSpecial === root.entry.name
}
