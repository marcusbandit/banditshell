#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec4 area;
    vec2 view;
    float bleed;
    float radius;
    float power;
    float bezel;
    float bend;
    float frosting;
    float spread;
    float ceiling;
    float sheen;
    float shade;
    float lift;
    float saturation;
};

layout(binding = 1) uniform sampler2D soft;
layout(binding = 2) uniform sampler2D frost;

float shape(vec2 p, vec2 size) {
    float corner = min(radius, min(size.x, size.y) * 0.5);
    vec2 q = abs(p - size * 0.5) - size * 0.5 + corner;
    vec2 m = max(q, vec2(0.0));
    float n = clamp(power, 2.0, 12.0);
    return min(max(q.x, q.y), 0.0) + pow(pow(m.x, n) + pow(m.y, n), 1.0 / n) - corner;
}

vec3 seen(vec2 at) {
    vec2 uv = clamp(at / view, vec2(0.0), vec2(1.0));
    return mix(texture(soft, uv).rgb, texture(frost, uv).rgb, frosting);
}

void main() {
    vec2 size = area.zw;
    vec2 p = qt_TexCoord0 * (size + 2.0 * bleed) - bleed;
    float d = shape(p, size);

    float reach = max(fwidth(d), 0.0001);
    float cover = clamp(0.5 - d / reach, 0.0, 1.0);
    if (cover <= 0.0 || size.x <= 0.0 || size.y <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    const float e = 0.75;
    vec2 normal = vec2(shape(p + vec2(e, 0.0), size) - shape(p - vec2(e, 0.0), size), shape(p + vec2(0.0, e), size) - shape(p - vec2(0.0, e), size));
    normal = length(normal) > 0.0 ? normalize(normal) : vec2(0.0);

    float rim = max(bezel, 1.0);
    float x = clamp(-d / rim, 0.0, 1.0);
    vec2 shift = vec2(0.0);
    if (x < 1.0) {
        float s = 1.0 - max(x, 0.002);
        float slope = s * s * s * pow(max(1.0 - s * s * s * s, 0.0001), -0.75);
        vec3 face = normalize(vec3(normal * slope, 1.0));
        vec3 ray = refract(vec3(0.0, 0.0, -1.0), face, 1.0 / 1.5);
        shift = ray.xy / max(-ray.z, 0.05) * bend;
    }

    vec2 at = area.xy + p;
    vec3 colour;
    if (spread > 0.0 && x < 1.0) {
        colour = vec3(seen(at + shift * (1.0 - spread)).r, seen(at + shift).g, seen(at + shift * (1.0 + spread)).b);
    } else {
        colour = seen(at + shift);
    }

    const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    float light = dot(colour, luma);
    float broad = dot(texture(frost, clamp(at / view, vec2(0.0), vec2(1.0))).rgb, luma);
    colour = mix(vec3(light), colour, saturation);
    colour *= min(1.0, ceiling / max(broad, 0.0001));
    colour = colour * shade + lift;

    float facing = dot(normal, normalize(vec2(-0.55, -0.85)));
    float lit = facing > 0.0 ? pow(facing, 1.5) : 0.6 * pow(-facing, 1.5);
    float edge = clamp(1.0 + d / 1.25, 0.0, 1.0);
    float inner = (1.0 - x) * (1.0 - x);
    colour += sheen * (edge * (0.3 + 0.7 * lit) + inner * 0.22 * lit);

    fragColor = vec4(colour, 1.0) * cover * qt_Opacity;
}
