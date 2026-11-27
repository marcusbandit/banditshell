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
    float weight;
    float reach;
};

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = abs(p - floor(p / pitch + 0.5) * pitch);
    float inner = weight * 0.5;
    float aa = 0.6;
    float across = 1.0 - smoothstep(inner - aa, inner + aa, d.x);
    float down = 1.0 - smoothstep(inner - aa, inner + aa, d.y);
    float line = max(across, down);
    float near = 1.0 - smoothstep(0.0, reach, length(p - centre));
    fragColor = colour * line * near * near * qt_Opacity;
}
