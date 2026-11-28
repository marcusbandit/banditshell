#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float smoothing;

    float feather;

    float power;

    float gap;
    float band;

    float frameOn;

    float screenRadius;

    vec4 size;

    vec4 content;

    vec4 baseRadius;

    vec4 blob0;
    vec4 blob1;
    vec4 blob2;
    vec4 blob3;
    vec4 blob4;
    vec4 blob5;
    vec4 blob6;
    vec4 blob7;
    vec4 blob8;
    vec4 blob9;
    vec4 blob10;
    vec4 blob11;

    vec4 blobRadius;
    vec4 blobRadius2;
    vec4 blobRadius3;

    vec4 blobSmooth;
    vec4 blobSmooth2;
    vec4 blobSmooth3;

    vec4 colour;
    vec4 frameColour;

    vec4 outlineColour;
    float outlineWidth;

    float sheenWidth;
    float pad2;
    float pad3;

    vec4 sheenColour;

    vec2 view;
    vec2 origin;
    float glass;
    float bezel;
    float bend;
    float spread;
    float restRaise;
    float openRaise;
    float openReach;
    float shade;
};

layout(binding = 1) uniform sampler2D soft;
layout(binding = 2) uniform sampler2D frost;

float sdBox(vec2 p, vec2 halfSize, vec4 r) {
    float limit = min(halfSize.x, halfSize.y);
    r = min(r, vec4(limit));

    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - halfSize + r.x;

    vec2 m = max(q, vec2(0.0));
    float n = max(2.0, power);
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r.x;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float meltPanel(float shell, vec2 p, vec4 rect, float radius, float k) {
    if (rect.z <= 0.0 || rect.w <= 0.0)
        return shell;
    return smin(shell, sdBox(p - (rect.xy + rect.zw * 0.5), rect.zw * 0.5, vec4(radius)), k);
}

float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

float field(vec2 p, out float shell) {
    vec2 centre = content.xy + content.zw * 0.5;
    float window = sdBox(p - centre, max(content.zw * 0.5 - gap, vec2(0.0)), baseRadius);
    shell = -(window - gap);

    float d = shell;
    d = min(d, meltPanel(shell, p, blob0, blobRadius.x, blobSmooth.x));
    d = min(d, meltPanel(shell, p, blob1, blobRadius.y, blobSmooth.y));
    d = min(d, meltPanel(shell, p, blob2, blobRadius.z, blobSmooth.z));
    d = min(d, meltPanel(shell, p, blob3, blobRadius.w, blobSmooth.w));
    d = min(d, meltPanel(shell, p, blob4, blobRadius2.x, blobSmooth2.x));
    d = min(d, meltPanel(shell, p, blob5, blobRadius2.y, blobSmooth2.y));
    d = min(d, meltPanel(shell, p, blob6, blobRadius2.z, blobSmooth2.z));
    d = min(d, meltPanel(shell, p, blob7, blobRadius2.w, blobSmooth2.w));
    d = min(d, meltPanel(shell, p, blob8, blobRadius3.x, blobSmooth3.x));
    d = min(d, meltPanel(shell, p, blob9, blobRadius3.y, blobSmooth3.y));
    d = min(d, meltPanel(shell, p, blob10, blobRadius3.z, blobSmooth3.z));
    d = min(d, meltPanel(shell, p, blob11, blobRadius3.w, blobSmooth3.w));
    return d;
}

float litFrom(vec2 normal) {
    float facing = dot(normal, normalize(vec2(-0.55, -0.85)));
    return facing > 0.0 ? pow(facing, 1.5) : 0.6 * pow(-facing, 1.5);
}

vec3 seen(vec2 at, float frosting) {
    vec2 uv = clamp(at / view, vec2(0.0), vec2(1.0));
    return mix(texture(soft, uv).rgb, texture(frost, uv).rgb, frosting);
}

vec4 glassBody(vec2 p, float d, float shell, float cover) {
    float rim = max(bezel, 1.0);
    float x = clamp(-d / rim, 0.0, 1.0);

    vec2 normal = vec2(0.0);
    vec2 shift = vec2(0.0);
    if (x < 1.0) {
        const float e = 0.75;
        float ignored;
        normal = vec2(field(p + vec2(e, 0.0), ignored) - field(p - vec2(e, 0.0), ignored), field(p + vec2(0.0, e), ignored) - field(p - vec2(0.0, e), ignored));
        normal = length(normal) > 0.0 ? normalize(normal) : vec2(0.0);
        float s = 1.0 - max(x, 0.002);
        float slope = s * s * s * pow(max(1.0 - s * s * s * s, 0.0001), -0.75);
        vec3 face = normalize(vec3(normal * slope, 1.0));
        vec3 ray = refract(vec3(0.0, 0.0, -1.0), face, 1.0 / 1.5);
        shift = ray.xy / max(-ray.z, 0.05) * bend;
    }

    float raised = mix(restRaise, openRaise, smoothstep(0.0, max(openReach, 1.0), shell));
    float frosting = 0.85 * raised;
    float ceiling = 0.5 - 0.15 * raised;
    float saturation = 0.9 - 0.2 * raised;
    float lift = 0.025 + 0.035 * raised;
    float sheen = 0.14 + 0.1 * raised;

    vec2 at = origin + p;
    vec3 colour;
    if (spread > 0.0 && x < 1.0)
        colour = vec3(seen(at + shift * (1.0 - spread), frosting).r, seen(at + shift, frosting).g, seen(at + shift * (1.0 + spread), frosting).b);
    else
        colour = seen(at + shift, frosting);

    const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    float light = dot(colour, luma);
    float broad = dot(texture(frost, clamp(at / view, vec2(0.0), vec2(1.0))).rgb, luma);
    colour = mix(vec3(light), colour, saturation);
    colour *= min(1.0, ceiling / max(broad, 0.0001));
    colour = colour * shade + lift;

    float lit = litFrom(normal);
    float edge = clamp(1.0 + d / 1.25, 0.0, 1.0);
    float inner = (1.0 - x) * (1.0 - x);
    colour += sheen * (edge * (0.3 + 0.7 * lit) + inner * 0.22 * lit);

    return vec4(colour, 1.0) * cover;
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    float shell;
    float d = field(p, shell);
    float toContent = -shell;

    float reach = gap + band;
    vec2 halfScreen = size.xy * 0.5;
    float toScreen = sdBox(p - halfScreen, max(halfScreen - reach, vec2(0.0)), vec4(screenRadius)) - reach;

    float clipped = frameOn > 0.5 ? max(d, toScreen) : d;
    float cover = inside(clipped);
    float outside = frameOn > 0.5 ? 1.0 - inside(toScreen) : 0.0;

    if (glass > 0.5) {
        vec4 body = cover > 0.0 ? glassBody(p, d, shell, cover) : vec4(0.0);
        fragColor = (frameColour * outside + body * (1.0 - outside)) * qt_Opacity;
        return;
    }

    vec4 body = colour * cover;

    vec4 result = frameColour * outside + body * (1.0 - outside);
    if (outlineWidth > 0.0) {
        float ring = inside(abs(toContent) - outlineWidth * 0.5);
        result = outlineColour * ring + result * (1.0 - ring);
    }

    if (sheenWidth > 0.0) {

        float ring = inside(abs(clipped + sheenWidth * 0.5) - sheenWidth * 0.5);

        vec2 across = vec2(dFdx(p.x), dFdy(p.y));
        vec2 slope = vec2(dFdx(clipped) / (abs(across.x) > 0.0 ? across.x : 1.0), dFdy(clipped) / (abs(across.y) > 0.0 ? across.y : 1.0));
        vec2 normal = length(slope) > 0.0 ? normalize(slope) : vec2(0.0);
        float lit = litFrom(normal);

        vec4 edge = sheenColour * ring * (0.35 + 0.65 * lit);
        result = edge + result * (1.0 - edge.a);
    }

    fragColor = result * qt_Opacity;
}
