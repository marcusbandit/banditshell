pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// WHAT KIND OF THING THIS IS, as one glyph in one colour.
//
// The colour is the whole argument of this file, so it is worth stating plainly:
// a file browser has to be colourful, because colour is what lets you find the
// picture among the forty text files without reading a single name, and this
// shell rations colour to state that has earned it (DESIGN.md section 8). Both
// of those are right. The way they live together is that the colour goes on the
// GLYPH and never on the tile: the material stays the shell's, hover and
// selection stay the shell's fills, and what is coloured is a mark the size of a
// word.
//
// AND THE HUES ARE COMPUTED, not listed. A table of twelve hex values would be
// twelve decisions that stop agreeing with the theme the moment the accent
// moves, and would be wrong by exactly one entry the first time a class was
// added. Instead each class takes the accent's hue turned by its own share of
// the wheel - position i of n, the same arithmetic as any other distribution in
// this shell (~/.claude/rules/math-over-hardcoding.md) - at a saturation pulled
// well below the accent's. So the set rotates with the palette, stays one
// family, and a new class costs one line and no colour picking.
Item {
    id: root

    required property string fileClass
    property bool link: false
    property bool broken: false
    property real size: Appearance.font.iconSize

    // WHAT MAY BE DONE WITH IT, from src/bs-ls.c. Absent (all defaults) for the
    // callers that only have a class to hand, which read as "ordinary".
    property bool readable: true
    property bool writable: true
    property bool owned: true
    property bool rooted: false
    property bool worldWritable: false

    implicitWidth: size
    implicitHeight: size

    // The vocabulary, in order. The ORDER is load-bearing: it is what decides
    // each class's share of the colour wheel, so adding to the end leaves every
    // existing colour where it was and inserting in the middle moves them all.
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

    readonly property string icon: root.classes[root.index].icon

    // The accent, turned. An achromatic accent has no hue to turn (Qt reports
    // -1), so the wheel starts at red rather than at nothing.
    readonly property real baseHue: Appearance.colour.accent.hslHue < 0 ? 0 : Appearance.colour.accent.hslHue

    // PERMISSION BEATS TYPE, when there is something to say.
    //
    // A folder's class is always "directory", so a folder's colour is a hue
    // spent saying something you can already see from the shape of the icon.
    // Permission is the thing about a directory that is invisible and that
    // matters: whether you can go in, whether you can write there, whose it is.
    // So that is what the colour carries.
    //
    // The order is by consequence, not by severity: unreadable stops you dead,
    // world-writable is a thing to be suspicious of, root-owned means look but
    // do not touch, and merely not-yours is worth a shade rather than a colour.
    // A file you own and may write is ordinary and takes its class hue, which is
    // what makes the marked ones stand out at all.
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
        // PERMISSION FIRST for a directory, always, and for anything with
        // something worth saying about it.
        if (root.marked && (root.fileClass === "directory" || !root.readable))
            return root.permissionHue;

        // UNKNOWN IS NOT A COLOUR. The last class is the one that means "we do
        // not know what this is", and giving it a confident hue of its own would
        // be the browser stating something it does not know. It wears the shell's
        // own dimmed text instead, which is also what makes everything that IS
        // known stand out of a directory full of it.
        if (root.fileClass === "unknown")
            return Appearance.colour.textFaint;

        const turn = (root.baseHue + root.index / root.classes.length) % 1;
        const accent = Appearance.colour.accent;
        // Saturation pulled to a bit over half the accent's, and lightness lifted
        // toward the label tier: this is a mark on a translucent panel, not a
        // sticker, and a fully saturated hue at icon size over a blurred
        // wallpaper is the "distractingly colourful" the brief ruled out.
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
        // A directory is FILLED and a file is not. The one distinction worth
        // spending the Material Symbols fill axis on: it separates "a place" from
        // "a thing" at a glance and across the whole grid, without a second
        // colour or a second shape.
        fill: root.fileClass === "directory" ? 1 : 0
        opacity: root.broken ? 0.7 : 1
    }

    // A SYMLINK SAYS SO, in the corner, at the weight of a footnote. It is drawn
    // as what it points AT (see src/bs-ls.c) because that is what you want to
    // open, so this badge is the only thing left that says it is not the thing
    // itself.
    Icon {
        visible: root.link

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -root.size * 0.1
        anchors.bottomMargin: -root.size * 0.1

        name: root.broken ? "link_off" : "link"
        size: root.size * 0.45
        color: root.broken ? Appearance.colour.alarm : Appearance.colour.textFaint
    }

    // A LOCK, when the thing cannot be written.
    //
    // The colour says it as well, and the colour is not enough on its own: it is
    // one hue among a dozen the grid already uses for types, and "which of these
    // greys means read-only" is not a question anybody should have to answer
    // from memory. The badge is unambiguous and costs a corner.
    Icon {
        visible: !root.writable && root.readable && !root.link

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -root.size * 0.1
        anchors.bottomMargin: -root.size * 0.1

        name: "lock"
        size: root.size * 0.42
        color: root.rooted ? Appearance.rampAt(6, 1) : Appearance.colour.textFaint
    }
}
