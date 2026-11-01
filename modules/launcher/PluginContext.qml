import QtQuick

QtObject {
    property var owner: null
    property var item: null
    property bool selected: false
    property bool preview: false

    readonly property var props: item?.props ?? ({})

    function act(action: var): void {
        owner?.act(item, action);
    }

    function copy(text: var): void {
        owner?.copyOut(text);
    }

    function open(target: var): void {
        owner?.openOut(target);
    }

    function fill(text: var): void {
        owner?.fillOut(text);
    }

    function close(): void {
        owner?.closeOut();
    }
}
