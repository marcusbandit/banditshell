.pragma library

var FAMILY = [
    {
        lobes: 0,
        depth: 0,
        turn: 0
    },
    {
        lobes: 4,
        depth: 0.16,
        turn: 0
    },
    {
        lobes: 3,
        depth: 0.22,
        turn: 90
    },
    {
        lobes: 4,
        depth: -0.16,
        turn: 0
    },
    {
        lobes: 5,
        depth: 0.18,
        turn: -90
    },
    {
        lobes: 6,
        depth: 0.18,
        turn: 0
    }
];

function shape(index) {

    var n = FAMILY.length;
    var i = ((Math.floor(index) % n) + n) % n;
    return FAMILY[i];
}

function weight(depth) {
    return 1 / Math.sqrt(1 + depth * depth / 2);
}

function samples(lobes) {
    return Math.max(24, 12 * lobes);
}

function path(index, size) {
    var s = shape(index);
    var scale = (size / 2) * weight(s.depth);
    var mid = size / 2;
    var count = samples(s.lobes);
    var turn = (s.turn * Math.PI) / 180;

    var points = [];
    for (var i = 0; i < count; i++) {
        var t = (i / count) * Math.PI * 2;
        var r = (1 - s.depth * Math.cos(s.lobes * t)) * scale;
        points.push([mid + r * Math.cos(t + turn), mid + r * Math.sin(t + turn)]);
    }

    function at(i) {
        return points[((i % count) + count) % count];
    }

    var out = "M " + points[0][0] + " " + points[0][1];
    for (var j = 0; j < count; j++) {
        var p0 = at(j - 1);
        var p1 = at(j);
        var p2 = at(j + 1);
        var p3 = at(j + 2);
        out += " C " + (p1[0] + (p2[0] - p0[0]) / 6) + " " + (p1[1] + (p2[1] - p0[1]) / 6) + " " + (p2[0] - (p3[0] - p1[0]) / 6) + " " + (p2[1] - (p3[1] - p1[1]) / 6) + " " + p2[0] + " " + p2[1];
    }
    return out + " Z";
}
