// Adapted from wallfx.frag in pocket-dots by Diego Malagrida, GPL-3.0:
// https://github.com/diegoMalagrida/pocket-dots/blob/main/home/.config/quickshell/shaders/wallfx.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;
    float mode;
    float sw;
    float sh;
    float fw;
    float fh;
    float lw;
    float lh;
    float glow;
    float lineW;
    float sdRange;
    float seed;
    float hasUnder;
    vec4 cropMap;
    vec4 ember;
    vec4 ink;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D under;
layout(binding = 3) uniform sampler2D fieldTex;
layout(binding = 4) uniform sampler2D lineTex;

const float PI = 3.14159265;
const float CELL = 4.0;

float escena(float x) { x = clamp(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.17) * 43758.5453); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec2 cam(vec2 uv, float z) { return 0.5 + (uv - 0.5) / z; }
vec3 oldAt(vec2 uv) { return hasUnder > 0.5 ? texture(under, uv).rgb : vec3(0.0); }
vec3 newAt(vec2 uv, float z) { return texture(source, cam(uv, z)).rgb; }
vec2 mapUv(vec2 uv, float z) { return cropMap.xy + cam(uv, z) * cropMap.zw; }

float s16(vec2 texel) {
    texel = clamp(texel, vec2(0.0), vec2(lw, lh) - 1.0);
    vec4 f = texture(lineTex, (texel + 0.5) / vec2(lw, lh));
    return (floor(f.g * 255.0 + 0.5) * 256.0 + floor(f.b * 255.0 + 0.5)) / 65535.0;
}
float surface(vec2 tuv) {
    vec2 p = tuv * vec2(lw, lh) - 0.5;
    vec2 i = floor(p), f = p - i;
    return mix(mix(s16(i), s16(i + vec2(1.0, 0.0)), f.x),
               mix(s16(i + vec2(0.0, 1.0)), s16(i + vec2(1.0, 1.0)), f.x), f.y);
}

float arrivalAt(vec2 c) {
    c = clamp(c, vec2(0.0), vec2(fw, fh) - 1.0);
    vec4 f = texture(fieldTex, (c + 0.5) / vec2(fw, fh));
    return (floor(f.r * 255.0 + 0.5) * 256.0 + floor(f.g * 255.0 + 0.5)) / 65535.0;
}

vec3 contagion(vec2 uv) {
    const float LIFE = 0.05;
    float energy = sin(PI * t);
    float T = escena(t) * (1.0 + LIFE + 0.01) - 0.01;
    float s = surface(uv);
    vec2 cell = floor(uv * vec2(fw, fh));
    float a = arrivalAt(cell);
    float flick = hash(cell);
    vec3 hot = mix(ember.rgb, vec3(1.0), 0.18);
    vec3 c;
    if (a > T) {
        c = oldAt(uv);
        float ahead = a - T;
        if (flick > 0.985 && ahead < 0.02)
            c = mix(c, hot, (1.0 - ahead / 0.02) * 0.8 * glow * step(0.0, T));
    } else {
        c = newAt(uv, 1.0 + 0.025 * (1.0 - escena(t)));
        bool edge = max(max(arrivalAt(cell + vec2(1.0, 0.0)), arrivalAt(cell - vec2(1.0, 0.0))),
                        max(arrivalAt(cell + vec2(0.0, 1.0)), arrivalAt(cell - vec2(0.0, 1.0)))) > T;
        float life = clamp((T - a) / LIFE, 0.0, 1.0);
        float burn = (1.0 - life) * (1.0 - life) * (edge ? 1.0 : 0.55);
        c = mix(c, hot, burn * (0.55 + 0.45 * flick) * 0.85 * glow);
    }
    return c + ember.rgb * 0.22 * glow * energy * exp(-abs(s - T) / 0.006);
}

vec3 outline(vec2 uv) {
    float zCh = 1.0 + 0.03 * (1.0 - escena(t));
    float zBg = 1.0 + 0.015 * (1.0 - escena(t));
    vec4 f = texture(fieldTex, mapUv(uv, zCh));
    float sdPx = (f.b * 2.0 - 1.0) * sdRange * sw * zCh / (fw * cropMap.z);
    float inside = clamp(0.5 - sdPx / max(fwidth(sdPx), 1e-3), 0.0, 1.0);

    float back = escena(t / 0.18);
    vec3 st = oldAt(uv);
    st = mix(st, vec3(luma(st)), 0.25 * back) * (1.0 - 0.2 * back);

    vec2 grid = vec2(sw, sh) / CELL;
    vec2 cuv = (floor(uv * grid) + 0.5) / grid;

    float Ti = escena((t - 0.32) / 0.32) * 1.02 - 0.01;
    vec3 cIn = texture(fieldTex, mapUv(cuv, zCh)).g <= Ti ? newAt(uv, zCh) : st;
    float To = escena((t - 0.45) / 0.50) * 1.02 - 0.01;
    vec3 cOut = surface(mapUv(cuv, zBg)) <= To ? newAt(uv, zBg) : st;
    vec3 c = mix(cOut, cIn, inside);

    float drawP = escena((t - 0.02) / 0.33);
    float lp = texture(lineTex, mapUv(uv, zCh)).r;
    float fade = 1.0 - escena((t - 0.45) / 0.25);
    if (lp > 0.0 && lp <= drawP && fade > 0.0) {
        float d = abs(sdPx) - lineW * 0.5;
        float core = clamp(0.5 - d / max(fwidth(sdPx), 1e-3), 0.0, 1.0);
        c = mix(c, ink.rgb, core * 0.75 * fade);
    }
    return c;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 c = mode < 0.5 ? contagion(uv) : outline(uv);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * qt_Opacity;
}
