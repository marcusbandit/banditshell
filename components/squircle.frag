#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float corner;

    float power;

    vec2 extent;

    vec4 crop;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 q = abs((qt_TexCoord0 - 0.5) * extent) - extent * 0.5 + corner;
    vec2 m = max(q, vec2(0.0));
    float n = clamp(power, 2.0, 12.0);
    float d = min(max(q.x, q.y), 0.0) + pow(pow(m.x, n) + pow(m.y, n), 1.0 / n) - corner;

    float cover = clamp(0.5 - d / max(fwidth(d), 0.0001), 0.0, 1.0);

    fragColor = texture(source, crop.xy + qt_TexCoord0 * crop.zw) * cover * qt_Opacity;
}
