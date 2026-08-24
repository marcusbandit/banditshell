.pragma library

// THE MARK FAMILY: one closed curve, six settings of it.
//
// A secret field draws a mark per character (components/SecretField.qml), and a
// row of identical circles is the thing every password box on earth already
// draws. Material 3 answers the same question with a family of soft shapes, and
// this is that idea in this shell's hand: not their set, and not a table of
// hand-drawn paths, but ONE polar curve with two knobs, enumerated at a handful
// of settings. Adding a seventh shape is a line of numbers, and every one of
// them is the same curve, so they read as a family rather than as a collection.
//
//     r(t) = 1 - depth * cos(lobes * t)
//
// `lobes` is how many times it comes in and out on the way round; `depth` is how
// far. depth = 0 is a circle whatever the lobes are, and that is the first entry
// rather than a special case. Positive depth puts the dents ON the axes and the
// swell on the diagonals, which at four lobes is the soft-cornered square this
// shell rounds everything with; negative depth turns the same shape a
// forty-fifth of a turn and reads as a four-pointed cushion instead.
//
// SMOOTH BY CONSTRUCTION, which is why there is no corner geometry here and no
// call into squircle.js. That file exists because a rounded RECTANGLE is
// straight lines meeting arcs and the join has to be made continuous by hand.
// This curve has no joins: it is one differentiable function of the angle, so
// its curvature is continuous everywhere before anything is drawn. What is
// approximated is only the sampling, and that is bounded below.
//
// THE SHAPE COMES FROM THE POSITION AND NEVER FROM THE CHARACTER. It is worth
// stating outright because the opposite is an easy and catastrophic thing to
// write: a mark whose shape depended on what was typed would put the password on
// the screen in a code anybody could read off a photograph. `shape(i)` takes an
// index and nothing else, and there is no other entry point.

// The vocabulary. A list to read in order, not a set of slots: the marks cycle
// through it, so the seventh character wears the first shape again. That
// repetition is deliberate - a rhythm rather than a scramble - and it is also
// what keeps a long secret from needing an ever-growing table.
//
// CHOSEN AT THE SIZE THEY ARE ACTUALLY DRAWN, which is about twelve pixels, and
// that is the whole of why the table looks the way it does. Rendered large,
// every setting of this curve is a distinct and rather beautiful shape, and a
// family picked by looking at them large is a family of eight-lobed and
// six-lobed curves that are all the same grey smudge in a password field. What
// survives at twelve pixels is a SILHOUETTE with few enough features to count:
// none, three, four, five, six. So the lobe counts stay low and the depths stay
// generous, which is the opposite of what the shapes want at poster size and
// exactly right at the size they live at.
//
// The two four-lobed entries are the same curve at opposite sign, which is worth
// noticing rather than deduplicating: positive puts the swell on the diagonals
// and reads as a soft square, negative puts it on the axes and reads as a
// diamond. One line of table for a shape nobody would guess was already there.
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
    // Floored and wrapped, so a negative or fractional index cannot fall off the
    // end of the table and hand back undefined.
    var n = FAMILY.length;
    var i = ((Math.floor(index) % n) + n) % n;
    return FAMILY[i];
}

// EVERY SHAPE THE SAME WEIGHT, which is not the same as every shape the same
// radius. A lobed curve reaching 1 at its widest is visibly bigger than a circle
// of radius 1, and a row where some marks look fatter than others reads as a
// mistake rather than as a family.
//
// Matched on AREA, in closed form rather than by measuring: the area inside a
// polar curve is half the integral of r squared, and for this curve that is
// pi * (1 + depth^2 / 2), because the cross term integrates to zero over a whole
// turn. So dividing by the square root of that puts every member of the family
// at exactly the area of the unit circle, at any depth, with no constant tuned
// by eye for one shape and quietly wrong for the next.
function weight(depth) {
    return 1 / Math.sqrt(1 + depth * depth / 2);
}

// HOW FINELY IT IS SAMPLED, from the shape rather than fixed. A circle needs
// almost nothing and an eight-lobed curve needs eight times as much, so the cost
// follows the shape instead of every mark paying for the busiest one. Twelve
// points per lobe is far past the eye at any size this is drawn: the segments
// below are cubics through the samples, so the error falls with the fourth power
// of the step.
function samples(lobes) {
    return Math.max(24, 12 * lobes);
}

// The curve, as an SVG path filling a `size` box.
//
// Emitted as cubics through the sample points using the closed Catmull-Rom
// construction: each segment's control points are placed a sixth of the way
// along the chord between its neighbours, which is the spline that passes
// through every sample and matches the tangent the curve actually has there.
// The alternative - a polyline - is exact at the samples and faceted between
// them, and a component that can be asked for any size must not have a size at
// which it starts to look like a stop sign.
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
