pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// ONE THING, PROPERLY.
//
// The list is for finding; this is for looking. That split is why the row is
// allowed to be terse: a row that tried to show enough of a paste to READ would
// be a list of one, and a list of one is a worse list and a worse reader than
// either of these. So the row shows what tells it apart from its neighbours, and
// everything else waits here, one right-arrow away.
//
// It arrives FROM THE RIGHT, because that is the direction that was asked for
// (a right arrow, a rightward swipe) and because the gesture and the motion
// agreeing about which way "into" is the whole reason a direction means
// anything. Left is back, on all three inputs.
//
// It is not a second panel and not a window: it is the same surface, sliding
// over the same rectangle the list occupies. A separate window would have its
// own translucency over the first one's and would double the material exactly
// where the two overlap, which is the failure DESIGN.md section 8 spent a
// rebuild on.
Item {
    id: root

    property var entry: null

    signal back
    signal accepted

    readonly property bool isImage: !!root.entry && root.entry.kind === "image" && !!root.entry.file
    readonly property bool isColour: !!root.entry && root.entry.kind === "colour"
    readonly property bool isFiles: !!root.entry && (root.entry.paths ?? []).length > 0
    readonly property bool isJson: !!root.entry && root.entry.kind === "json"

    // WHAT THE READER IS GIVEN: the formatted text when there is one and it has
    // arrived, the text as copied otherwise.
    //
    // Never a spinner and never an empty page while jq runs. Formatting is a
    // nicety on top of something already perfectly readable, so the raw text is
    // shown immediately and swapped for the tidy one when it lands, usually
    // within a frame or two. A view that withheld the content it already had, in
    // order to wait for a prettier version of it, would be slower at the only
    // job it has.
    readonly property string body: {
        if (!root.entry)
            return "";
        const tidy = Clipboard.formatted(root.entry);
        return tidy ? tidy : (root.entry.text ?? "");
    }

    readonly property string language: root.isJson ? "json" : root.entry?.kind === "code" ? "" : ""

    // Asked for on the way in rather than on a timer or at capture: this is the
    // moment somebody wants to read it, and it is the only moment that is true.
    onEntryChanged: if (root.entry)
        Clipboard.beautify(root.entry)

    // ------------------------------------------------------------------

    Item {
        id: head

        x: Appearance.padding.large
        y: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
        height: Math.max(backOut.height, caption.implicitHeight)

        // THE WAY BACK, as a target and not only as a key. It is the first thing
        // on the page and it is on the left, which is the direction it goes.
        Item {
            id: backOut

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
            height: width

            G2Rect {
                anchors.fill: parent
                radius: height / 2
                color: Appearance.colour.fill
                opacity: backPress.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "chevron_left"
                size: Appearance.font.iconSize
                color: backPress.containsMouse ? Appearance.colour.text : Appearance.colour.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: backPress

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }

            HoverTip {
                text: "Back to the list"
            }
        }

        Column {
            id: caption

            anchors.left: backOut.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: useIt.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                // The one thing this view IS about, so it takes the tier above
                // the body. The only place in this panel that does.
                font.pixelSize: Appearance.font.size.normal
                text: root.entry ? Clipboard.summarise(root.entry).replace(/\s+/g, " ").trim().slice(0, 80) || root.entry.kind : ""
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                color: Appearance.colour.textFaint
                text: {
                    if (!root.entry)
                        return "";
                    const bits = [root.entry.kind];
                    if (root.entry.w > 0)
                        bits.push(`${root.entry.w} × ${root.entry.h}`);
                    const size = Clipboard.size(root.entry.bytes);
                    if (size)
                        bits.push(size);
                    if (!root.isImage && (root.entry.text ?? "").length) {
                        const n = root.body.split("\n").length;
                        bits.push(n === 1 ? "1 line" : `${n} lines`);
                    }
                    bits.push(Clipboard.age(root.entry.recorded));
                    return bits.join("  ·  ");
                }
            }
        }

        // THE POINT OF THE WHOLE PANEL, reachable without going back for it.
        // Enter does the same from anywhere on this page.
        Pill {
            id: useIt

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Copy"
            onClicked: root.accepted()
        }
    }

    Separator {
        id: rule

        anchors.top: head.bottom
        anchors.topMargin: Appearance.padding.normal
        x: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
    }

    Item {
        id: stage

        anchors.top: rule.bottom
        anchors.topMargin: Appearance.padding.normal
        x: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
        height: Math.max(0, parent.height - y - Appearance.padding.large)
        clip: true

        // A PICTURE, WHOLE. Fitted rather than cropped, which is the opposite of
        // the row's choice and for the opposite reason: a row is a thumbnail
        // being told apart from its neighbours, where filling the plate uses
        // every pixel of a small space; this is the picture being looked at, and
        // cropping it here would hide the part somebody came to see.
        G2Image {
            anchors.fill: parent
            visible: root.isImage
            source: root.isImage ? `file://${root.entry.file}` : ""
            radius: Appearance.rounding.normal
            fillMode: Image.PreserveAspectFit
            // The stage is stable and owes nothing to the picture, so the decode
            // may follow it: this is the case G2Image's default is written for.
            // See its note, and ClipRow, which is the case that is not.
            decodeWidth: stage.width
            decodeHeight: stage.height
        }

        // A COLOUR, as the colour. Six characters of hex are not a colour until
        // something is painted in them.
        Item {
            anchors.fill: parent
            visible: root.isColour

            G2Rect {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: Math.min(parent.width, parent.height * 0.6)
                height: Math.max(0, parent.height - swatchLabel.height - Appearance.padding.large)
                radius: Appearance.rounding.large
                color: root.isColour ? root.swatch : "transparent"
                stroke: Appearance.colour.separator
                strokeWidth: Appearance.font.stem
            }

            StyledText {
                id: swatchLabel

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Appearance.font.size.normal
                text: root.entry ? (root.entry.text ?? "").trim() : ""
            }
        }

        // FILES, one line each, saying what each one actually is and whether it
        // is still there. The row could only say "3 files"; this is the answer
        // to the question that raises.
        GlideList {
            anchors.fill: parent
            visible: root.isFiles && !root.isImage
            model: root.entry ? (root.entry.paths ?? []) : []
            clip: true

            delegate: Item {
                required property string modelData
                required property int index

                width: ListView.view.width
                height: Math.max(Appearance.sizes.rowHeight, line.implicitHeight + Appearance.padding.normal)

                readonly property string mime: root.entry ? ((root.entry.mimes ?? [])[index] ?? "") : ""
                readonly property bool gone: mime === ""

                Icon {
                    id: fileMark

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: parent.gone ? "help" : parent.mime.startsWith("image/") ? "image" : parent.mime.startsWith("audio/") ? "graphic_eq" : parent.mime.startsWith("video/") ? "movie" : "draft"
                    size: Appearance.font.iconSize
                    color: parent.gone ? Appearance.colour.textGhost : Appearance.colour.textFaint
                }

                Column {
                    id: line

                    anchors.left: fileMark.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small / 2

                    StyledText {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: modelData
                        color: gone ? Appearance.colour.textFaint : Appearance.colour.text
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Appearance.colour.textFaint
                        text: gone ? "not there any more" : mime
                    }
                }
            }
        }

        // EVERYTHING ELSE: the text, in full, highlighted when it is something
        // this shell can recognise and plainly when it is not.
        //
        // The same component for prose as for code, deliberately. A long paste
        // needs one line per delegate whether or not any of them are coloured,
        // because that is what keeps a sixty-thousand-line paste from building
        // sixty thousand text items; and with no language, nothing is coloured
        // and it is simply a scrollable body of text.
        CodeBlock {
            anchors.fill: parent
            visible: !root.isImage && !root.isColour && !root.isFiles
            text: root.body
            language: root.language
            wrap: root.entry?.kind !== "json" && root.entry?.kind !== "code"
            gutter: root.entry?.kind === "json" || root.entry?.kind === "code"
        }
    }

    // The row's guard, unchanged: the text passed a shape test and not a parse,
    // and an unparseable colour string is a console error plus whatever Qt felt
    // like drawing.
    readonly property color swatch: {
        const t = root.entry ? (root.entry.text ?? "").trim() : "";
        const hex = t.startsWith("#") ? t : `#${t}`;
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : Appearance.colour.textFaint;
    }
}
