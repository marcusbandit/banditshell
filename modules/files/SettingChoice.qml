import QtQuick
import qs.components

Segments {
    id: root

    property var choices: []
    property var chosen

    signal chose(var value)

    options: root.choices.map(c => c.label)
    current: root.choices.findIndex(c => c.value === root.chosen)
    onPicked: index => root.chose(root.choices[index].value)
}
