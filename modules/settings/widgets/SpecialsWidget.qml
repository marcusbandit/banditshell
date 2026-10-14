pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var names: Hypr.specials.map(s => s.label)

    function keyFor(name: string): string {
        const b = HyprConfig.binds.find(x => /togglespecialworkspace|special/.test(x.expr ?? "") && (x.expr ?? "").indexOf(`"${name}"`) >= 0);
        return b ? SettingsKeys.fromChord(b.chord).replace(/ /g, " + ") : "";
    }

    width: parent ? parent.width : 0

    Repeater {
        model: root.names.length ? root.names : ["no special workspaces yet"]

        delegate: StyledText {
            required property string modelData

            x: Appearance.padding.normal
            width: root.width - Appearance.padding.normal * 2
            topPadding: Appearance.padding.small
            bottomPadding: Appearance.padding.normal
            text: root.names.length ? [modelData, root.keyFor(modelData)].filter(Boolean).join(" · ") : modelData
            color: Appearance.colour.textFaint
            wrapMode: Text.WordWrap
        }
    }
}
