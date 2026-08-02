import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// An icon file drawn at the SIZE IT LOOKS, not the size of its canvas.
//
// Icon files disagree about padding. A symbolic icon is drawn edge to edge, an
// application icon leaves a tenth of itself empty on every side, and a logo
// exported from a design tool can be a small mark in the middle of a square. Put
// them in a row at the same box size and they come out at three different sizes,
// which reads as sloppy and is: the boxes match and the drawings do not.
//
// So the drawing is measured, once, and the box is fitted to IT. The alpha
// channel is scanned in a Canvas to find what the file actually covers, the
// result is cached against the file's path (a file does not change shape), and
// the image is scaled and offset so its content fills this item whatever its
// canvas was doing.
//
// The measurement is capped: an icon that covers a tenth of its canvas is more
// likely to be a mistake than a design, and blowing it up twelvefold would make
// one row in a list enormous.
Item {
    id: root

    property string source: ""
    property color colour: Appearance.colour.text
    // Draw it as a silhouette in `colour` rather than as it is. Right for the
    // symbolic and panel icons that are one colour already, and a choice for
    // everything else: a bar of five different brand palettes stops reading as
    // one interface.
    property bool tint: true

    readonly property bool ready: image.status === Image.Ready

    // What the file covers, normalised to its own square, plus how much of that
    // box is actually opaque. Whole until measured, so an unmeasured icon draws
    // the way it always would.
    property var box: AppIcons.fitFor(source) ?? [0, 0, 1, 1, 0]

    readonly property real span: Math.max(box[2], box[3], 0.05)

    // FITTED TO A GLYPH, not to the box. A Material Symbol covers about six
    // sevenths of the square it is drawn in, and a file scaled to fill the whole
    // square next to one is visibly the bigger of the two even though the boxes
    // match. This is what makes a row of mixed marks read as one size.
    readonly property real optical: 0.86
    readonly property real factor: Math.min(optical / span, 2.5)

    // A SILHOUETTE OF A SOLID SHAPE IS A SOLID SHAPE. Plenty of application
    // icons are a mark inside a filled disc or rounded square, and flattening
    // one to a single colour produces a disc: not wrong, exactly, but no longer
    // an icon of anything. When the measurement says the file is nearly solid,
    // the tint is dropped and it keeps its own colours, because that is the only
    // version of it that says which application it is.
    readonly property bool solid: box.length > 4 && box[4] > 0.82
    readonly property bool tinted: tint && !solid

    implicitWidth: Appearance.font.iconSize
    implicitHeight: implicitWidth

    onSourceChanged: {
        root.box = AppIcons.fitFor(source) ?? [0, 0, 1, 1, 0];
        if (source && !AppIcons.fitFor(source))
            probe.measure();
    }

    Image {
        id: image

        // Scaled so the CONTENT fills the item, then shifted so the content's
        // centre is the item's centre.
        width: root.width * root.factor
        height: root.height * root.factor
        x: root.width / 2 - (root.box[0] + root.box[2] / 2) * width
        y: root.height / 2 - (root.box[1] + root.box[3] / 2) * height

        source: root.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: !root.tinted && root.ready

        onStatusChanged: if (status === Image.Ready && root.source && !AppIcons.fitFor(root.source))
            probe.measure()
    }

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.tinted && root.ready
        // A flat silhouette in one colour. For a symbolic icon this is exactly
        // what it already was; for anything else it is a deliberate trade, which
        // is why the picker offers the shapes that survive it.
        brightness: 1
        colorization: 1
        colorizationColor: root.colour
    }

    // THE MEASUREMENT. A Canvas is the only thing in QML that can look at
    // pixels, so the file is drawn into an offscreen one at a coarse size and
    // its alpha channel is scanned for the bounding box of anything visible.
    // Coarse on purpose: this is deciding a scale factor, not cutting a mask,
    // and 64 by 64 is nine times less work than 192.
    Canvas {
        id: probe

        width: 64
        height: 64
        visible: false
        renderTarget: Canvas.Image

        function measure(): void {
            if (!root.source)
                return;
            if (isImageLoaded(root.source))
                requestPaint();
            else
                loadImage(root.source);
        }

        onImageLoaded: requestPaint()

        onPaint: {
            if (!isImageLoaded(root.source))
                return;

            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(root.source, 0, 0, width, height);

            const data = ctx.getImageData(0, 0, width, height).data;
            let x0 = width, y0 = height, x1 = -1, y1 = -1, opaque = 0;
            for (let y = 0; y < height; y++)
                for (let x = 0; x < width; x++) {
                    if (data[(y * width + x) * 4 + 3] > 200)
                        opaque++;
                    // A THRESHOLD, not "any alpha at all": an antialiased edge
                    // and a soft shadow both leave a haze several pixels out, and
                    // measuring that measures the shadow.
                    if (data[(y * width + x) * 4 + 3] > 24) {
                        if (x < x0)
                            x0 = x;
                        if (x > x1)
                            x1 = x;
                        if (y < y0)
                            y0 = y;
                        if (y > y1)
                            y1 = y;
                    }
                }

            if (x1 < x0 || y1 < y0)
                return;

            const w = x1 - x0 + 1;
            const h = y1 - y0 + 1;
            const measured = [x0 / width, y0 / height, w / width, h / height, opaque / (w * h)];
            root.box = measured;
            AppIcons.recordFit(root.source, measured);
        }
    }
}
