pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "marks.js" as Marks

Item {
    id: root

    required property string fileClass

    property string path: ""
    property string name: ""

    property bool link: false
    property bool broken: false
    property real size: Appearance.font.iconSize

    property bool readable: true
    property bool writable: true
    property bool owned: true
    property bool rooted: false
    property bool worldWritable: false

    implicitWidth: size
    implicitHeight: size

    readonly property var classes: [
        {name: "directory", icon: "folder"},
        {name: "image", icon: "image"},
        {name: "video", icon: "movie"},
        {name: "audio", icon: "music_note"},
        {name: "code", icon: "code"},
        {name: "text", icon: "description"},
        {name: "pdf", icon: "picture_as_pdf"},
        {name: "document", icon: "article"},
        {name: "archive", icon: "folder_zip"},
        {name: "font", icon: "text_fields"},
        {name: "program", icon: "terminal"},
        {name: "binary", icon: "memory"},
        {name: "unknown", icon: "draft"}
    ]

    readonly property int index: {
        for (let i = 0; i < root.classes.length; i++)
            if (root.classes[i].name === root.fileClass)
                return i;
        return root.classes.length - 1;
    }

    readonly property string classIcon: root.classes[root.index].icon

    readonly property string special: root.path ? Marks.iconFor(root.path, root.name, root.fileClass === "directory", Files.home) : ""

    readonly property string icon: root.special || root.classIcon

    readonly property bool foldered: root.fileClass === "directory" && root.special !== "" && root.special !== "folder"

    readonly property real baseHue: Appearance.colour.accent.hslHue < 0 ? 0 : Appearance.colour.accent.hslHue

    readonly property color permissionHue: {
        if (!root.readable || root.broken)
            return Appearance.colour.alarm;
        if (root.worldWritable)
            return Appearance.blend(Appearance.colour.alarm, Appearance.colour.accent, 0.5);
        if (root.rooted)
            return Appearance.rampAt(6, 1);
        if (!root.writable)
            return Appearance.colour.textFaint;
        return "transparent";
    }

    readonly property bool marked: root.permissionHue.a > 0

    readonly property color hue: {

        if (root.marked && (root.fileClass === "directory" || !root.readable))
            return root.permissionHue;

        if (root.fileClass === "unknown")
            return Appearance.colour.textFaint;

        const turn = (root.baseHue + root.index / root.classes.length) % 1;
        const accent = Appearance.colour.accent;

        return Qt.hsla(turn, accent.hslSaturation * 0.62, Math.max(0.62, accent.hslLightness), 1);
    }

    Icon {
        id: glyph

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: glyph.inkOffsetX
        anchors.verticalCenterOffset: glyph.inkOffsetY

        name: root.icon
        size: root.size
        color: root.broken ? Appearance.colour.alarm : root.hue

        fill: root.fileClass === "directory" && !root.foldered ? 1 : 0
        opacity: root.broken ? 0.7 : 1
    }

    Icon {
        visible: root.foldered

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: -root.size * 0.12
        anchors.bottomMargin: -root.size * 0.08

        name: "folder"
        fill: 1
        size: root.size * 0.42
        color: root.hue
        opacity: 0.75
    }

    readonly property string state: {
        if (root.broken)
            return "link_off";
        if (!root.readable)
            return "block";
        if (root.link)
            return "link";
        if (!root.writable)
            return "lock";
        return "";
    }

    Icon {
        visible: root.state !== ""

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -root.size * 0.1
        anchors.bottomMargin: -root.size * 0.08

        name: root.state
        size: root.size * 0.42
        color: root.broken || !root.readable ? Appearance.colour.alarm : root.rooted ? Appearance.rampAt(6, 1) : Appearance.colour.textFaint
    }
}
