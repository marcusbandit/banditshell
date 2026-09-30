#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float smoothing;

    float feather;

    float power;

    float gap;
    float band;

    float frameOn;

    float screenRadius;

    vec4 size;

    vec4 content;

    vec4 baseRadius;

    vec4 blob0;
    vec4 blob1;
    vec4 blob2;
    vec4 blob3;
    vec4 blob4;
    vec4 blob5;
    vec4 blob6;
    vec4 blob7;
    vec4 blob8;
    vec4 blob9;
    vec4 blob10;
    vec4 blob11;

    vec4 blobRadius;
    vec4 blobRadius2;
    vec4 blobRadius3;

    vec4 blobSmooth;
    vec4 blobSmooth2;
    vec4 blobSmooth3;

    vec4 colour;
    vec4 frameColour;

    vec4 outlineColour;
    float outlineWidth;

    float sheenWidth;
    float pad2;
    float pad3;

    vec4 sheenColour;
};

float sdBox(vec2 p, vec2 halfSize, vec4 r) {
    float limit = min(halfSize.x, halfSize.y);
    r = min(r, vec4(limit));

    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - halfSize + r.x;

    vec2 m = max(q, vec2(0.0));
    float n = max(2.0, power);
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r.x;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float meltPanel(float shell, vec2 p, vec4 rect, float radius, float k) {
    if (rect.z <= 0.0 || rect.w <= 0.0)
        return shell;
    return smin(shell, sdBox(p - (rect.xy + rect.zw * 0.5), rect.zw * 0.5, vec4(radius)), k);
}

float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    vec2 centre = content.xy + content.zw * 0.5;
    float window = sdBox(p - centre, max(content.zw * 0.5 - gap, vec2(0.0)), baseRadius);

    float toContent = window - gap;

    float reach = gap + band;
    vec2 halfScreen = size.xy * 0.5;
    float toScreen = sdBox(p - halfScreen, max(halfScreen - reach, vec2(0.0)), vec4(screenRadius)) - reach;

    float shell = -toContent;

    float d = shell;
    d = min(d, meltPanel(shell, p, blob0, blobRadius.x, blobSmooth.x));
    d = min(d, meltPanel(shell, p, blob1, blobRadius.y, blobSmooth.y));
    d = min(d, meltPanel(shell, p, blob2, blobRadius.z, blobSmooth.z));
    d = min(d, meltPanel(shell, p, blob3, blobRadius.w, blobSmooth.w));
    d = min(d, meltPanel(shell, p, blob4, blobRadius2.x, blobSmooth2.x));
    d = min(d, meltPanel(shell, p, blob5, blobRadius2.y, blobSmooth2.y));
    d = min(d, meltPanel(shell, p, blob6, blobRadius2.z, blobSmooth2.z));
    d = min(d, meltPanel(shell, p, blob7, blobRadius2.w, blobSmooth2.w));
    d = min(d, meltPanel(shell, p, blob8, blobRadius3.x, blobSmooth3.x));
    d = min(d, meltPanel(shell, p, blob9, blobRadius3.y, blobSmooth3.y));
    d = min(d, meltPanel(shell, p, blob10, blobRadius3.z, blobSmooth3.z));
    d = min(d, meltPanel(shell, p, blob11, blobRadius3.w, blobSmooth3.w));

    if (frameOn > 0.5)
        d = max(d, toScreen);

    vec4 body = colour * inside(d);

    float outside = frameOn > 0.5 ? 1.0 - inside(toScreen) : 0.0;

    vec4 result = frameColour * outside + body * (1.0 - outside);
    if (outlineWidth > 0.0) {
        float ring = inside(abs(toContent) - outlineWidth * 0.5);
        result = outlineColour * ring + result * (1.0 - ring);
    }

    if (sheenWidth > 0.0) {

        float ring = inside(abs(d + sheenWidth * 0.5) - sheenWidth * 0.5);

        vec4 edge = sheenColour * ring;
        result = edge + result * (1.0 - edge.a);
    }

    fragColor = result * qt_Opacity;
}
