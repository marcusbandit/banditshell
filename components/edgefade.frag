#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec4 fades;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float x = (fades.w > 0.5 ? qt_TexCoord0.y : qt_TexCoord0.x) * fades.z;
    float left = fades.x > 0.0 ? smoothstep(0.0, fades.x, x) : 1.0;
    float right = fades.y > 0.0 ? smoothstep(0.0, fades.y, fades.z - x) : 1.0;
    fragColor = texture(source, qt_TexCoord0) * left * right * qt_Opacity;
}
