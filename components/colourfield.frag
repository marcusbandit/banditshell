#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec4 size;

    vec4 c0;

    vec4 c1;

    vec4 c2;

    vec4 c3;

    vec4 shares;

    vec4 look;
};

float corner(vec2 p, vec2 halfSize, float radius, float n) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;
    vec2 m = max(q, vec2(0.0));
    return min(max(q.x, q.y), 0.0) + pow(pow(m.x, n) + pow(m.y, n), 1.0 / n) - r;
}

float blob(vec2 uv, vec2 at, float share) {
    vec2 d = uv - at;
    d.x *= size.x / max(1.0, size.y) * 0.5;
    return (0.15 + share) * exp(-dot(d, d) / 0.32);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = size.z * 6.2831853;

    vec2 p0 = vec2(0.30, 0.35) + 0.10 * vec2(sin(t), cos(t * 0.8));
    vec2 p1 = vec2(0.82, 0.22) + 0.10 * vec2(cos(t * 1.3 + 1.0), sin(t * 0.9 + 2.0));
    vec2 p2 = vec2(0.72, 0.85) + 0.10 * vec2(sin(t * 0.7 + 3.0), cos(t * 1.1 + 1.0));
    vec2 p3 = vec2(0.15, 0.88) + 0.10 * vec2(cos(t * 1.1 + 4.0), sin(t * 1.4 + 2.5));

    float w0 = blob(uv, p0, shares.x);
    float w1 = shares.y > 0.0 ? blob(uv, p1, shares.y) : 0.0;
    float w2 = shares.z > 0.0 ? blob(uv, p2, shares.z) : 0.0;
    float w3 = shares.w > 0.0 ? blob(uv, p3, shares.w) : 0.0;
    float total = max(1e-4, w0 + w1 + w2 + w3);
    vec3 colour = (c0.rgb * w0 + c1.rgb * w1 + c2.rgb * w2 + c3.rgb * w3) / total;

    vec2 px = uv * size.xy;
    float d = corner(px - size.xy * 0.5, size.xy * 0.5, size.w, max(2.0, look.x));
    float aa = max(fwidth(d), 0.0001);
    float inside = size.w > 0.0 ? 1.0 - smoothstep(-aa, aa, d) : 1.0;

    fragColor = vec4(colour, 1.0) * inside * qt_Opacity;
}
