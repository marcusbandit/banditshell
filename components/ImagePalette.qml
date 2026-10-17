import QtQuick
import qs.config

Item {
    id: root

    property string source: ""
    property int most: 4

    property var colours: []

    readonly property int side: 24
    readonly property int rounds: 12
    readonly property real floor: 0.02

    function distance(a: var, b: var): real {
        return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2;
    }

    function nearest(p: var, centres: var): int {
        let best = 0;
        let bestD = Infinity;
        for (let j = 0; j < centres.length; j++) {
            const d = root.distance(p, centres[j]);
            if (d < bestD) {
                bestD = d;
                best = j;
            }
        }
        return best;
    }

    function cluster(px: var): var {
        const bins = {};
        for (const p of px) {
            const key = `${Math.floor(p[0] * 6 / 256)},${Math.floor(p[1] * 6 / 256)},${Math.floor(p[2] * 6 / 256)}`;
            bins[key] = (bins[key] ?? 0) + 1;
        }
        const centres = [];
        for (const key of Object.keys(bins).sort((a, b) => bins[b] - bins[a])) {
            const c = key.split(",").map(k => (Number(k) * 256 + 128) / 6);
            if (centres.every(o => root.distance(c, o) > 60 * 60))
                centres.push(c);
            if (centres.length === root.most)
                break;
        }
        if (centres.length === 0)
            return [];
        for (let round = 0; round < root.rounds; round++) {
            const sums = centres.map(() => [0, 0, 0, 0]);
            for (const p of px) {
                const s = sums[root.nearest(p, centres)];
                s[0] += p[0];
                s[1] += p[1];
                s[2] += p[2];
                s[3] += 1;
            }
            let moved = false;
            sums.forEach((s, i) => {
                if (!s[3])
                    return;
                const c = [s[0] / s[3], s[1] / s[3], s[2] / s[3]];
                if (root.distance(c, centres[i]) > 1)
                    moved = true;
                centres[i] = c;
            });
            if (!moved)
                break;
        }
        const counts = centres.map(() => 0);
        for (const p of px)
            counts[root.nearest(p, centres)] += 1;
        const out = centres.map((c, i) => ({
                    colour: Appearance.rgb(c[0] / 255, c[1] / 255, c[2] / 255),
                    share: counts[i] / px.length
                })).filter(c => c.share > 0).sort((a, b) => b.share - a.share);
        const kept = out.filter(c => c.share >= root.floor);
        return kept.length > 0 ? kept : out.slice(0, 1);
    }

    onSourceChanged: {
        if (!root.source) {
            root.colours = [];
            return;
        }
        if (probe.isImageLoaded(root.source))
            probe.requestPaint();
        else
            probe.loadImage(root.source);
    }

    Canvas {
        id: probe

        width: root.side
        height: root.side
        visible: false
        renderTarget: Canvas.Image

        onImageLoaded: probe.requestPaint()

        onPaint: {
            if (!root.source || !probe.isImageLoaded(root.source))
                return;
            const ctx = probe.getContext("2d");
            ctx.clearRect(0, 0, probe.width, probe.height);
            ctx.drawImage(root.source, 0, 0, probe.width, probe.height);
            const data = ctx.getImageData(0, 0, probe.width, probe.height).data;
            const px = [];
            for (let i = 0; i < data.length; i += 4)
                if (data[i + 3] > 128)
                    px.push([data[i], data[i + 1], data[i + 2]]);
            root.colours = px.length > 0 ? root.cluster(px) : [];
        }
    }
}
