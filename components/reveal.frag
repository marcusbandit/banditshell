#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float progress;

    float aspect;

    float softness;

    float wobble;

    float seed;

    vec2 origin;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0;

    vec2 d = vec2((p.x - origin.x) * aspect, p.y - origin.y);

    float ang = atan(d.y, d.x);
    float lobes = sin(ang * 3.0 + seed) + 0.5 * sin(ang * 5.0 - seed * 1.7) + 0.25 * sin(ang * 7.0 + seed * 0.6);

    float ease = 1.0 - progress * progress;
    float radius = 1.0 + wobble * lobes * ease;

    float dist = length(d) / max(0.35, radius);

    float fx = max(origin.x, 1.0 - origin.x) * aspect;
    float fy = max(origin.y, 1.0 - origin.y);
    float far = length(vec2(fx, fy));

    float r = progress * (far + softness);

    float m = smoothstep(r, r - softness, dist);

    fragColor = texture(source, p) * m * qt_Opacity;
}
