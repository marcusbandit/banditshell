#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 pixel = texture(tex, v_texcoord);
    float grey = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(grey), pixel.a);
}
