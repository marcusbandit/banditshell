#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;
    vec2 pitch;
    vec2 centre;
    vec4 colour;
    float dot;
    float reach;
};

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 nearest = floor(p / pitch + 0.5) * pitch;
    float d = length(p - nearest);
    float aa = 0.75;
    float mark = 1.0 - smoothstep(dot - aa, dot + aa, d);
    float fade = 1.0 - smoothstep(reach * 0.5, reach, length(p - centre));
    fragColor = colour * mark * fade * qt_Opacity;
}
