#version 440

// The workspace column, as ONE liquid.
//
// A rail with a bead on it per workspace, drawn as a single signed distance
// field and combined with a SMOOTH minimum, so a bead does not sit ON the rail,
// it grows OUT of it: the join is a fillet the field works out for itself, and
// two beads that come near each other neck together instead of overlapping.
// Same construction as blob.frag at a different scale. There it is the shell's
// body and the menus separating out of it; here it is a column of workspaces and
// the windows on them.
//
// COLOUR IS A PROPERTY OF THE FIELD, not of a shape. The accent is mixed into
// the liquid across exactly the width of the fillet, so where the active bead
// necks into the rail the colour necks with it. NO GLOW: nothing is drawn
// outside the shape, and the fade is the join, not a halo. Depth is layered
// translucency and nothing else, never a bevel, a gradient, or a light bloom.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // How wide the fillet is where two parts of the field meet, in pixels.
    // 0 gives a hard crease and the whole point is lost.
    float smoothing;
    // Multiplier on the antialiased edge width.
    float feather;
    // Superellipse exponent for the corners: 2 is circular. Every bead here is
    // fully rounded, so this only shows on the rail's ends.
    float power;

    float pad0;
    float pad1;
    float pad2;

    // Item size in pixels; the shader works in pixels, not UV.
    vec4 size;

    // The rail every bead grows out of: x, y, w, h.
    vec4 rail;
    // The active bead, which is the only one that moves independently: x is
    // ignored (beads are centred), then y, h, w to match the bead packing below.
    vec4 activeBead;
    // Where the active bead was a moment ago, chasing the same target more
    // slowly. At rest the two coincide and it costs nothing; in motion they are
    // apart, and since they are melted together the bead STRETCHES between where
    // it is going and where it was instead of sliding as a rigid shape. That is
    // the whole trick, and it is why this is a field and not a rectangle.
    vec4 trailBead;

    // The rail, a bead, an occupied bead, and the accent. Premultiplied, as Qt
    // hands colours over. The rail is meant to be DARKER than the surface it is
    // on: a groove the beads sit in, which is the only depth cue here that is
    // not another sheet of the same light.
    vec4 railColour;
    vec4 baseColour;
    vec4 strongColour;
    vec4 accentColour;

    // Beads, packed (y, h, w, occupied). They are centred horizontally, so x is
    // not carried. A width of zero means the slot is unused, which is how a
    // shorter column costs nothing rather than leaving a stub behind. A uniform
    // block cannot hold a variable-length array, so the slots are written out.
    vec4 bead0;
    vec4 bead1;
    vec4 bead2;
    vec4 bead3;
    vec4 bead4;
    vec4 bead5;
    vec4 bead6;
    vec4 bead7;
    vec4 bead8;
    vec4 bead9;
};

// Rounded box, one radius, superellipse corners (iq). Negative inside.
float sdRect(vec2 p, vec2 halfSize, float r) {
    r = min(r, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;

    // The corner is the p-NORM of the outside part, not its length: length() is
    // the 2-norm and gives a circle, a higher exponent gives a superellipse.
    vec2 m = max(q, vec2(0.0));
    float n = max(2.0, power);
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r;
}

// Polynomial smooth minimum. Where two fields are within `k` of each other this
// blends rather than picking one, which is exactly a fillet whose size follows
// how close they are.
float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// A bead's own field. Fully rounded: the radius is half its short side, so a
// one-window bead is a disc and a four-window bead is a capsule.
float beadField(vec2 p, vec4 b) {
    vec2 halfSize = vec2(b.z, b.y) * 0.5;
    vec2 centre = vec2(size.x * 0.5, b.x + halfSize.y);
    return sdRect(p - centre, halfSize, min(halfSize.x, halfSize.y));
}

// Melt a bead into the running field. Empty slots RETURN EARLY rather than
// answering "very far": a huge sentinel fed into smin is lost to floating point
// (see the same note in blob.frag) and the whole field comes back wrong.
float melt(float d, vec2 p, vec4 b) {
    if (b.z <= 0.0 || b.y <= 0.0)
        return d;
    return smin(d, beadField(p, b), smoothing);
}

// The same, for a layer that starts with NOTHING in it. `acc` carries
// (distance, has-anything): until something is added there is nothing to blend
// WITH, so the first bead is taken whole rather than blended against a sentinel.
vec2 meltAny(vec2 acc, vec2 p, vec4 b) {
    if (b.z <= 0.0 || b.y <= 0.0)
        return acc;
    float d = beadField(p, b);
    return vec2(acc.y > 0.5 ? smin(acc.x, d, smoothing) : d, 1.0);
}

// Only the beads that have windows on them.
vec2 meltOccupied(vec2 acc, vec2 p, vec4 b) {
    return b.w < 0.5 ? acc : meltAny(acc, p, b);
}

// Antialias in screen space rather than at a fixed width, so the edge stays one
// pixel wide whatever the field's gradient is doing near a joint.
float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    // The beads alone, so they can be a different material from the rail they
    // sit in. Melted into each other, not into the rail: this is the field that
    // says "raised", and the rail is what is left of the silhouette.
    vec2 raised = vec2(1.0e4, 0.0);
    raised = meltAny(raised, p, bead0);
    raised = meltAny(raised, p, bead1);
    raised = meltAny(raised, p, bead2);
    raised = meltAny(raised, p, bead3);
    raised = meltAny(raised, p, bead4);
    raised = meltAny(raised, p, bead5);
    raised = meltAny(raised, p, bead6);
    raised = meltAny(raised, p, bead7);
    raised = meltAny(raised, p, bead8);
    raised = meltAny(raised, p, bead9);

    // The active bead and its trail, kept as their own field as well: together
    // they are both a part of the silhouette and the source the colour falls off
    // from, so the stretch is coloured along its whole length.
    float act = activeBead.z > 0.0 ? beadField(p, activeBead) : 1.0e4;
    if (trailBead.z > 0.0)
        act = activeBead.z > 0.0 ? smin(act, beadField(p, trailBead), smoothing) : beadField(p, trailBead);
    raised = meltAny(raised, p, activeBead);
    raised = meltAny(raised, p, trailBead);

    // The whole silhouette: the groove, with every bead grown out of it.
    float groove = sdRect(p - (rail.xy + rail.zw * 0.5), rail.zw * 0.5, min(rail.z, rail.w) * 0.5);
    float all = raised.y > 0.5 ? smin(groove, raised.x, smoothing) : groove;

    // Occupied beads only, so "there are windows here" is a weight of its own
    // rather than another shape.
    vec2 occ = vec2(1.0e4, 0.0);
    occ = meltOccupied(occ, p, bead0);
    occ = meltOccupied(occ, p, bead1);
    occ = meltOccupied(occ, p, bead2);
    occ = meltOccupied(occ, p, bead3);
    occ = meltOccupied(occ, p, bead4);
    occ = meltOccupied(occ, p, bead5);
    occ = meltOccupied(occ, p, bead6);
    occ = meltOccupied(occ, p, bead7);
    occ = meltOccupied(occ, p, bead8);
    occ = meltOccupied(occ, p, bead9);

    float aAll = inside(all);
    float aRaised = inside(raised.x) * raised.y;
    float aOcc = inside(occ.x) * occ.y;

    // How much accent this pixel has: all of it inside the active bead, none of
    // it one fillet away. The SAME distance the shapes blend over, so the colour
    // and the geometry neck together and there is no seam running through the
    // middle of one body. Not a glow: it stops where the fillet stops.
    float tint = 1.0 - smoothstep(0.0, max(smoothing, 0.001), max(act, 0.0));

    // Dark groove, then the beads raised out of it, then weight for the ones
    // holding windows, then the colour for the one you are on. Qt hands colours
    // over PREMULTIPLIED, so mixing them is a straight lerp and multiplying by
    // coverage is the only scaling needed.
    vec4 fill = mix(railColour, baseColour, aRaised);
    fill = mix(fill, strongColour, aOcc);
    fill = mix(fill, accentColour, tint);

    fragColor = fill * aAll * qt_Opacity;
}
