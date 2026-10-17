#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float power;

    float bleed;

    float across;

    float down;

    float rim;

    vec4 radii;

    vec4 colour;

    vec4 line;
};

float share(float own, float other, float length) {
    float total = own + other;
    return total <= 0.0 ? length * 0.5 : length * own / total;
}

void main() {
    vec2 size = vec2(across, down);
    vec2 p = qt_TexCoord0 * (size + 2.0 * bleed) - bleed;

    float tl = radii.x;
    float tr = radii.y;
    float br = radii.z;
    float bl = radii.w;

    bool right = p.x > size.x * 0.5;
    bool lower = p.y > size.y * 0.5;

    float own = lower ? (right ? br : bl) : (right ? tr : tl);
    float acrossOther = lower ? (right ? bl : br) : (right ? tl : tr);
    float downOther = right ? (lower ? tr : br) : (lower ? tl : bl);

    float corner = min(share(own, acrossOther, size.x), share(own, downOther, size.y));
    corner = min(own, corner);

    vec2 q = abs(p - size * 0.5) - size * 0.5 + corner;
    vec2 m = max(q, vec2(0.0));
    float n = clamp(power, 2.0, 12.0);
    float d = min(max(q.x, q.y), 0.0) + pow(pow(m.x, n) + pow(m.y, n), 1.0 / n) - corner;

    float reach = max(length(vec2(dFdx(d), dFdy(d))), 0.0001);
    float cover = clamp(0.5 - d / reach, 0.0, 1.0);
    float inner = clamp(0.5 - (d + rim) / reach, 0.0, 1.0);
    float ring = max(cover - inner, 0.0);
    float filled = clamp(0.5 - (d + rim * 0.5) / reach, 0.0, 1.0);

    vec4 body = colour * filled;
    vec4 edge = line * ring;

    fragColor = (edge + body * (1.0 - edge.a)) * (size.x > 0.0 && size.y > 0.0 ? qt_Opacity : 0.0);
}
