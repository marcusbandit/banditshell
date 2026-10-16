#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float smoothing;

    float feather;

    float power;

    float edge;

    float neck;

    vec4 size;

    vec4 pill;

    vec4 bud0;

    vec4 bud1;

    vec4 bud2;

    vec4 bud3;

    vec4 reaches;

    vec4 radii;

    vec4 colour;

    vec4 sheenColour;

    vec4 bandColour;
};

layout(binding = 1) uniform sampler2D source;

float sdBox(vec2 p, vec2 halfSize, float radius, float n) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;

    vec2 m = max(q, vec2(0.0));
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float bubble(float d, vec2 p, vec4 b, float k) {
    if (b.z <= 0.0 || b.w <= 0.0)
        return d;
    vec2 reach = b.zw * 0.5;
    return smin(d, sdBox(p - (b.xy + reach), reach, min(reach.x, reach.y), 2.0), k);
}

float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    float d = 100000.0;
    if (pill.z > 0.0 && pill.w > 0.0)
        d = sdBox(p - (pill.xy + pill.zw * 0.5), pill.zw * 0.5, radii.x, max(2.0, power));
    d = bubble(d, p, bud0, reaches.x > 0.0 ? reaches.x : smoothing);
    d = bubble(d, p, bud1, reaches.y > 0.0 ? reaches.y : smoothing);
    d = bubble(d, p, bud2, reaches.z > 0.0 ? reaches.z : smoothing);
    d = bubble(d, p, bud3, reaches.w > 0.0 ? reaches.w : smoothing);

    float below = inside(edge - p.y);

    float band = p.y - edge;
    float joined = neck > 0.0 ? smin(d, band, neck) : d;
    float own = neck > 0.0 ? clamp(0.5 + 0.5 * (band - d) / neck, 0.0, 1.0) : 1.0;

    float shape = inside(joined) * below;
    vec4 body = mix(bandColour, colour, own) * shape;

    if (radii.z > 0.0) {
        float ring = inside(abs(joined + radii.z * 0.5) - radii.z * 0.5) * below;
        vec4 sheen = sheenColour * ring;
        body = sheen + body * (1.0 - sheen.a);
    }

    vec4 ink = texture(source, qt_TexCoord0) * inside(d) * below;

    fragColor = (ink + body * (1.0 - ink.a)) * qt_Opacity;
}
