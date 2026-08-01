#version 440

// The chassis, as a signed distance field.
//
// The shell's body is not a set of shapes that touch. It is ONE field, and the
// pieces are combined with a SMOOTH minimum instead of a plain one. A plain
// union of two rounded boxes meets at a crease; a smooth union bulges into the
// join and fillets it, and the fillet grows and shrinks on its own as the pieces
// move. That is what makes a menu look like it is separating out of the bar
// rather than being parked next to it.
//
// Everything here is evaluated per pixel, so nothing has to know the outline.
// There is no path to keep consistent, no seam where two translucent shapes
// abut, and no joint geometry to hand-place: the melt is a property of the
// field, not a decoration added afterwards.
//
// EVERY EDGE IN THE CHASSIS COMES FROM ONE CURVE.
//
// There is a single shape here: the window's own outline, at the compositor's
// radius and the compositor's superellipse exponent. Everything else is that
// curve OFFSET outwards, which in a distance field is one subtraction:
//
//     the window          d
//     the content area    d - gap          the chassis's inner edge
//     the screen's edge   d - gap - band   where the black corners begin
//
// This is the reason it has to be a field. An offset curve is at a CONSTANT
// distance; a larger radius is not. Growing a superellipse's radius by the gap
// instead overshoots by 19% along the 45 degree diagonal at these values, which
// on screen is a wedge of wallpaper opening up at every corner while the
// straight edges stay perfectly correct. Circles are the one family where
// radius+gap and offset coincide, which is why the mistake is easy to make and
// hard to see.
//
// The technique is what caelestia's compiled Blobs plugin does. This is the same
// idea in a fragment shader, so banditshell owns it end to end.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // How wide the melt is, in pixels. 0 gives a hard crease.
    float smoothing;
    // Multiplier on the antialiased edge width.
    float feather;

    // The superellipse exponent for corners: |x|^n + |y|^n = r^n.
    //
    // 2 is a circular arc. Hyprland draws its window corners with this same
    // parameter (`rounding_power`), so matching it is what makes the chassis and
    // the windows it frames the SAME CURVE, not merely the same radius.
    //
    // Figma-style corner smoothing, which the vector primitive uses, cannot do
    // this: it extends the transition along the edge and leaves the distance
    // from the curve to the corner vertex unchanged at every smoothing value.
    // At r=15 a circular corner clears the vertex by 6.21px and Hyprland's n=4
    // clears it by 3.38px, and no amount of smoothing closes that. They are
    // orthogonal operations on different curve families.
    float power;

    // The two distances every other edge is derived from.
    float gap;
    float band;
    // 0 hides the black screen-corner frame.
    float frameOn;
    float pad0;

    // Item size in pixels; the shader works in pixels, not UV.
    vec4 size;

    // The content area: x, y, w, h. The base curve is this inset by `gap`.
    vec4 content;
    // Corner radii OF THE BASE CURVE, i.e. the window's own, packed the way
    // sdBox wants them.
    vec4 baseRadius;

    // Panels. Each is x, y, w, h; a width of zero means the slot is unused.
    // A uniform block cannot hold a variable-length array, so the slots are
    // written out. Eight is the ceiling: the chassis, a menu, the notch, and up
    // to five notification popups.
    vec4 blob0;
    vec4 blob1;
    vec4 blob2;
    vec4 blob3;
    vec4 blob4;
    vec4 blob5;
    vec4 blob6;
    vec4 blob7;
    // Corner radius per panel, four to a vec4, in the same order.
    vec4 blobRadius;
    vec4 blobRadius2;

    vec4 colour;
    vec4 frameColour;

    // An outline ON the content boundary, for things that must show exactly
    // where an edge is rather than melt across it.
    vec4 outlineColour;
    float outlineWidth;
    float pad1;
    float pad2;
    float pad3;
};

// Rounded box with a different radius per corner (iq). Negative inside.
//
// Qt's y runs DOWNWARD, so "p.y > 0" means below the centre. That makes the
// packing (bottomRight, topRight, bottomLeft, topLeft). Getting this order wrong
// is invisible until a corner is asymmetric, so it is written down rather than
// worked out again.
//
// Radii are clamped to half the box, or a box narrower than its own corners
// would bulge outward instead of shrinking. That matters here because a panel
// animates its width up from zero.
float sdBox(vec2 p, vec2 halfSize, vec4 r) {
    float limit = min(halfSize.x, halfSize.y);
    r = min(r, vec4(limit));

    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - halfSize + r.x;

    // The corner is the p-NORM of the outside part, not its length. length() is
    // the 2-norm and gives a circle; any higher exponent gives a superellipse,
    // which is the family Hyprland rounds windows with.
    vec2 m = max(q, vec2(0.0));
    float n = max(2.0, power);
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r.x;
}

// Polynomial smooth minimum. The whole point of the file: where two fields are
// within `k` of each other, this blends rather than picking one, which is
// exactly a fillet whose size follows how close they are.
float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Melt ONE panel into the SHELL, and return that result on its own.
//
// Deliberately not chained. Folding each panel into the running total in turn
// melts the panels into each OTHER as well as into the shell, and between peers
// that is destructive: a stack of notification cards fuses into one lumpy mass
// with pinches where the boundaries should be. Each panel is blended with the
// shell alone, and the results are combined with a plain min, so every panel
// joins the shell smoothly and panels meet each other with a clean edge.
//
// The empty case RETURNS EARLY. It used to answer "very far" (1e9) and let smin
// discard it, which is wrong in a way that is invisible in the algebra and
// obvious on screen: at k=1 smin reduces to mix(1e9, d, 1), and compiled as the
// usual x + a*(y - x) that is 1e9 + (d - 1e9), where d is far below the ulp of
// 1e9 and is simply lost. The field came back off by tens of pixels, so the body
// bled well past its own edge and every boundary went soft. Never feed a huge
// sentinel into arithmetic that has to preserve small differences.
float meltPanel(float shell, vec2 p, vec4 rect, float radius, float k) {
    if (rect.z <= 0.0 || rect.w <= 0.0)
        return shell;
    return smin(shell, sdBox(p - (rect.xy + rect.zw * 0.5), rect.zw * 0.5, vec4(radius)), k);
}

// Antialias in screen space rather than with a fixed edge width, so the edge
// stays one pixel wide whatever the field's gradient is doing near a joint.
float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    // The one curve: the window's own outline. The content area is that grown by
    // the gap, so the base shape is the content area shrunk by it.
    vec2 centre = content.xy + content.zw * 0.5;
    float window = sdBox(p - centre, max(content.zw * 0.5 - gap, vec2(0.0)), baseRadius);

    // Offsets, not radii.
    float toContent = window - gap;
    float toScreen = window - gap - band;

    // The chassis is everything outside the content area, so its field is the
    // content's negated.
    float shell = -toContent;

    // Each panel melted into the shell separately, then unioned plainly. See
    // meltPanel: this is what keeps siblings from fusing into each other.
    float d = shell;
    d = min(d, meltPanel(shell, p, blob0, blobRadius.x, smoothing));
    d = min(d, meltPanel(shell, p, blob1, blobRadius.y, smoothing));
    d = min(d, meltPanel(shell, p, blob2, blobRadius.z, smoothing));
    d = min(d, meltPanel(shell, p, blob3, blobRadius.w, smoothing));
    d = min(d, meltPanel(shell, p, blob4, blobRadius2.x, smoothing));
    d = min(d, meltPanel(shell, p, blob5, blobRadius2.y, smoothing));
    d = min(d, meltPanel(shell, p, blob6, blobRadius2.z, smoothing));
    d = min(d, meltPanel(shell, p, blob7, blobRadius2.w, smoothing));

    // Clipped to the screen's own edge, so the body cannot spill into the
    // rounded-off corners of the display.
    if (frameOn > 0.5)
        d = max(d, toScreen);

    // Qt hands a QColor uniform over ALREADY PREMULTIPLIED, so the whole vec4
    // just scales by coverage. Multiplying rgb by alpha again here is an easy
    // mistake and looks like the surface has quietly lost its colour: the tint
    // goes dark and desaturated while still being obviously "there".
    vec4 body = colour * inside(d);

    // The black beyond the screen's rounded edge, which is what makes a
    // rectangular display read as a rounded one. Composited here rather than
    // drawn as four separate items, so it is the same curve by construction
    // instead of by four numbers agreeing.
    float outside = frameOn > 0.5 ? 1.0 - inside(toScreen) : 0.0;

    // The outline straddles the content edge. Drawn last, over everything, so a
    // selection edge is unambiguous.
    vec4 result = frameColour * outside + body * (1.0 - outside);
    if (outlineWidth > 0.0) {
        float ring = inside(abs(toContent) - outlineWidth * 0.5);
        result = outlineColour * ring + result * (1.0 - ring);
    }

    fragColor = result * qt_Opacity;
}
