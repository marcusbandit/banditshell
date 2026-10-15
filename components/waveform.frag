#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec4 size;

    vec4 colour;

    vec4 motion;

    vec4 shape;

    vec4 edges;
};

layout(binding = 1) uniform sampler2D levels;

float tap(float i) {
    float n = size.z;
    if (i < 0.0 || i > motion.x + 0.5 || i < motion.x - n + 4.0)
        return 0.0;
    float slot = mod(i, n);
    return texture(levels, vec2((slot + 0.5) / n, 0.5)).r;
}

float point(float m) {
    float i = m * edges.z;
    float sum = 0.0;
    for (float j = 0.0; j < 4.0; j += 1.0) {
        if (j >= edges.z)
            break;
        sum += tap(i + j);
    }
    return sum / edges.z;
}

float smoothLevel(float at) {
    float m = at / edges.z;
    float i = floor(m);
    float f = m - i;
    float p0 = point(i - 1.0);
    float p1 = point(i);
    float p2 = point(i + 1.0);
    float p3 = point(i + 2.0);
    float f2 = f * f;
    float f3 = f2 * f;
    float w0 = (1.0 - f) * (1.0 - f) * (1.0 - f);
    float w1 = 3.0 * f3 - 6.0 * f2 + 4.0;
    float w2 = -3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0;
    float w3 = f3;
    return clamp((w0 * p0 + w1 * p1 + w2 * p2 + w3 * p3) / 6.0, 0.0, 1.0);
}

float flowAt(float p) {
    float t = motion.z;
    float wave = 0.30 * sin(6.2831853 * (1.3 * p - t)) + 0.17 * sin(6.2831853 * (2.7 * p + t) + 1.1) + 0.09 * sin(6.2831853 * (4.1 * p - 2.0 * t) + 2.3);
    float swell = 0.46 + 0.10 * sin(6.2831853 * t);
    return clamp((swell + wave) * shape.x, 0.0, 1.0);
}

float caretAt(float p) {
    float at = motion.w;
    float lit = smoothstep(at + 0.02, at, p);
    float head = 1.0 - smoothstep(0.0, 0.035, abs(p - at));
    return max(0.05 + 0.29 * lit, head);
}

void main() {
    vec2 px = qt_TexCoord0 * size.xy;
    float p = qt_TexCoord0.x;
    float mode = motion.y;

    float amount;
    if (mode < 0.5)
        amount = smoothLevel(motion.x - (size.x - px.x) / size.w);
    else if (mode < 1.5)
        amount = flowAt(p);
    else
        amount = caretAt(p);

    float floorHalf = shape.y * 0.5;
    float reach = mix(floorHalf, 0.5, amount) * size.y;
    float d = abs(px.y - size.y * 0.5);
    float aa = 0.75;
    float inside = 1.0 - smoothstep(reach - aa, reach + aa, d);

    float width = max(0.001, edges.x);
    float fade = mix(edges.y, 1.0, smoothstep(0.0, width, p)) * mix(edges.y, 1.0, smoothstep(0.0, width, 1.0 - p));

    fragColor = colour * inside * fade * qt_Opacity;
}
