import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "../catalogue.js" as Catalogue

SceneGauge {
    id: root

    readonly property var mode: Catalogue.MODES.find(m => m.id === SettingsState.v("mode")) ?? Catalogue.MODES[0]
    readonly property var keys: Object.keys(root.mode.set)

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.mode.icon
        size: 96
        fill: 1
        color: Appearance.colour.accent
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.mode.name === "none" ? "no mode" : `${root.mode.name} mode`
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.keys.length ? root.keys.map(k => (Catalogue.labelOf(Catalogue.ROW_BY_KEY[k] ?? {}) || k).toLowerCase()).join(" · ") : "everything as set"
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }
}
