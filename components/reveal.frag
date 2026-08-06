#version 440

// A WALLPAPER ARRIVING, as a hole opening in the one that was there.
//
// This is a MASK on the incoming picture, not a blend of two of them, and that
// is the whole shape of the thing. The outgoing wallpaper is drawn normally
// underneath; the new one is drawn on top with its alpha eaten away outside a
// growing circle, so what you see through the hole is simply the layer below.
// Nothing has to be captured into a texture, nothing has to be kept live, and a
// video underneath goes on playing through the hole because it is still the
// scene drawing itself rather than a snapshot of it.
//
// WHY NOT A CROSS-FADE. A fade says "these are two pictures and one of them is
// becoming the other", which is a statement about a slideshow. A wallpaper is
// not a slideshow: it is the ground, and a ground is replaced rather than
// dissolved. The circle also has somewhere to come FROM, which a fade never
// does, and that is what makes the change feel caused: it opens out of the card
// you pressed, so the picture you chose is visibly the thing that arrived.
//
// swww does this family of transitions (`grow`, `outer`, `wipe`) and the shape
// is borrowed knowingly. What is not borrowed is the origin: swww grows from a
// point you configure, and this grows from the point you touched.
//
// THE EDGE IS NOT A CUT. A hard circle reads as a stencil sliding over the
// screen; a feathered one reads as the picture arriving. `softness` is that
// feather, in the same normalised units as the radius, so it stays the same
// proportion of the screen whatever the screen is.
//
// Applied through `layer.effect`, so Qt hands the item's own rendering in as
// `source` and expects premultiplied alpha back: the mask multiplies the whole
// vec4 rather than the alpha alone, which is the same thing under premultiply
// and the wrong thing under straight alpha.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // How far open, 0 to 1. At 1 the circle covers the furthest corner from the
    // origin plus the feather, so the incoming picture is whole no matter where
    // the origin sat.
    float progress;

    // Width over height. The circle is measured in x-corrected space so it is a
    // circle on the screen rather than on the unit square, which on a 16:9
    // panel is the difference between a disc and a very obvious ellipse.
    float aspect;

    // The feather, as a fraction of the corrected unit square's diagonal.
    float softness;

    // HOW FAR FROM A CIRCLE, 0 to about 0.4. The radius is modulated by angle,
    // so this is the depth of the lobes: 0 is a disc and anything above it is a
    // blob. See the wobble below.
    float wobble;

    // WHICH BLOB. Every transition gets a different one, because the shape is a
    // sum of sines in the angle and this shifts their phases. A reveal that
    // arrives in the same shape every time stops being a thing that happened
    // and becomes a widget.
    float seed;

    // Where it opens from, 0 to 1 in the item's own coordinates. The centre of
    // the card you pressed; the middle of the screen when the change came from
    // a keybind or the CLI, which have no point to have come from.
    vec2 origin;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0;

    // Corrected so a unit of x is a unit of y on the actual panel.
    vec2 d = vec2((p.x - origin.x) * aspect, p.y - origin.y);

    // NOT A CIRCLE.
    //
    // A disc growing out of a point is the obvious shape and it reads as a
    // mechanism: it is the only outline with no information in it, so the eye
    // has nothing to follow and what it sees is a wipe effect rather than an
    // arrival. What replaces it is the same growth with a RADIUS THAT VARIES
    // WITH ANGLE, which is the cheapest honest way to draw an organic outline:
    // three sines at incommensurate frequencies never repeat over a turn, so
    // the boundary has lobes and bays and no two of them are alike.
    //
    // The frequencies are 3, 5 and 7 and that matters. Whole numbers keep the
    // shape CLOSED, because the modulation has to come back to itself after a
    // full turn or the blob has a seam down one side where the last lobe meets
    // the first. Odd and coprime keeps it from looking symmetrical, which a
    // sum like 2 and 4 would be, and symmetry is the thing that would make it
    // read as a shape somebody chose rather than as a shape that happened.
    //
    // Falling amplitudes, halving each time, because that is what makes it a
    // blob rather than a flower: the first sine gives it a broad lean, the
    // second bends the lean, the third only roughens it.
    float ang = atan(d.y, d.x);
    float lobes = sin(ang * 3.0 + seed) + 0.5 * sin(ang * 5.0 - seed * 1.7) + 0.25 * sin(ang * 7.0 + seed * 0.6);

    // THE BLOB SETTLES AS IT GROWS. At the start it is at its most irregular,
    // which is when it is small and the irregularity is all you can see; by the
    // end the lobes have flattened out, which is what lets it reach every
    // corner of the screen instead of leaving four bays of the old wallpaper in
    // them. It is also simply what a drop of ink spreading does.
    float ease = 1.0 - progress * progress;
    float radius = 1.0 + wobble * lobes * ease;

    // Guarded, because a large wobble and an unlucky phase can sum past 1 and
    // turn the radius negative, which inverts the shape inside out for a frame.
    float dist = length(d) / max(0.35, radius);

    // THE FURTHEST CORNER, computed rather than assumed. A circle grown to a
    // fixed radius leaves a wedge of the old wallpaper in whichever corner the
    // origin was nearest, and that wedge is exactly where the eye is: the
    // origin is where you just touched. Only two corners can be the far one, so
    // the maximum over the x and y extremes is the whole answer.
    float fx = max(origin.x, 1.0 - origin.x) * aspect;
    float fy = max(origin.y, 1.0 - origin.y);
    float far = length(vec2(fx, fy));

    // The feather is spent OUTSIDE the radius, so progress 1 clears the corner
    // with the whole soft edge past it rather than with the edge straddling it.
    //
    // AND NOTHING IS SPENT ON THE WOBBLE, which is the thing to get wrong here
    // and was got wrong once. Padding the radius by the lobe depth looks
    // obviously right (the bays have to clear the corner too) and is obviously
    // wrong the moment you write down what `ease` does: the lobes flatten to
    // NOTHING by the end, so the shape at progress 1 is already a circle and
    // the padding is pure overshoot. It was a third, which meant the screen was
    // covered at about three quarters of the way through, which with a
    // front-loaded easing was a quarter of the DURATION: two thirds of the
    // animation ran after there was nothing left to see, and what showed of the
    // blob was the fast part of it.
    float r = progress * (far + softness);

    // 1 inside the circle, 0 outside, ramped across the feather. Reversed
    // arguments rather than a 1.0 - smoothstep, which is the same curve and one
    // fewer operation.
    float m = smoothstep(r, r - softness, dist);

    fragColor = texture(source, p) * m * qt_Opacity;
}
