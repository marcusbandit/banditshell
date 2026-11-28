#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float smoothing;

    float feather;

    float power;

    float edge;

    float neck;

    vec4 size;

    vec4 pill;

    vec4 bud0;

    vec4 bud1;

    vec4 bud2;

    vec4 bud3;

    vec4 reaches;

    vec4 radii;

    vec4 colour;

    vec4 sheenColour;

    vec4 bandColour;

    vec2 view;
    vec2 origin;
    float glass;
    float bezel;
    float bend;
    float spread;
    float raised;
    float bandRaised;
    float daylight;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D soft;
layout(binding = 3) uniform sampler2D frost;

float sdBox(vec2 p, vec2 halfSize, float radius, float n) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;

    vec2 m = max(q, vec2(0.0));
    float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);

    return min(max(q.x, q.y), 0.0) + corner - r;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float bubble(float d, vec2 p, vec4 b, float k) {
    if (b.z <= 0.0 || b.w <= 0.0)
        return d;
    vec2 reach = b.zw * 0.5;
    return smin(d, sdBox(p - (b.xy + reach), reach, min(reach.x, reach.y), 2.0), k);
}

float inside(float d) {
    float aa = max(fwidth(d), 0.0001) * feather;
    return 1.0 - smoothstep(-aa, aa, d);
}

float shapeOf(vec2 p) {
    float d = 100000.0;
    if (pill.z > 0.0 && pill.w > 0.0)
        d = sdBox(p - (pill.xy + pill.zw * 0.5), pill.zw * 0.5, radii.x, max(2.0, power));
    d = bubble(d, p, bud0, reaches.x > 0.0 ? reaches.x : smoothing);
    d = bubble(d, p, bud1, reaches.y > 0.0 ? reaches.y : smoothing);
    d = bubble(d, p, bud2, reaches.z > 0.0 ? reaches.z : smoothing);
    d = bubble(d, p, bud3, reaches.w > 0.0 ? reaches.w : smoothing);
    return d;
}

float joinOf(vec2 p, float d) {
    return neck > 0.0 ? smin(d, p.y - edge, neck) : d;
}

float fieldAt(vec2 p) {
    return joinOf(p, shapeOf(p));
}

float litFrom(vec2 normal) {
    float facing = dot(normal, normalize(vec2(-0.55, -0.85)));
    return facing > 0.0 ? pow(facing, 1.5) : 0.6 * pow(-facing, 1.5);
}

vec3 seen(vec2 at, float frosting) {
    vec2 uv = clamp(at / view, vec2(0.0), vec2(1.0));
    return mix(texture(soft, uv).rgb, texture(frost, uv).rgb, frosting);
}

vec4 glassBody(vec2 p, float joined, float own, float cover) {
    float rim = max(bezel, 1.0);
    float x = clamp(-joined / rim, 0.0, 1.0);

    vec2 normal = vec2(0.0);
    vec2 shift = vec2(0.0);
    if (x < 1.0) {
        const float e = 0.75;
        normal = vec2(fieldAt(p + vec2(e, 0.0)) - fieldAt(p - vec2(e, 0.0)), fieldAt(p + vec2(0.0, e)) - fieldAt(p - vec2(0.0, e)));
        normal = length(normal) > 0.0 ? normalize(normal) : vec2(0.0);
        float s = 1.0 - max(x, 0.002);
        float slope = s * s * s * pow(max(1.0 - s * s * s * s, 0.0001), -0.75);
        vec3 face = normalize(vec3(normal * slope, 1.0));
        vec3 ray = refract(vec3(0.0, 0.0, -1.0), face, 1.0 / 1.5);
        shift = ray.xy / max(-ray.z, 0.05) * bend;
    }

    float r = mix(bandRaised, raised, own);
    float frosting = r;
    float ceiling = 0.32 - 0.12 * r;
    float saturation = 0.9 - 0.2 * r;
    float lift = 0.025 + 0.035 * r;
    float sheen = 0.14 + 0.1 * r;

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
    if (daylight > 0.5) {
        float floorLevel = 0.55 + 0.15 * r;
        colour = floorLevel + colour * (1.0 - floorLevel);
    } else {
        colour *= min(1.0, ceiling / max(broad, 0.0001));
        colour = colour + lift;
    }

    float lit = litFrom(normal);
    float rimLine = clamp(1.0 + joined / 1.25, 0.0, 1.0);
    float inner = (1.0 - x) * (1.0 - x);
    colour += sheen * (rimLine * (0.3 + 0.7 * lit) + inner * 0.22 * lit);

    return vec4(colour, 1.0) * cover;
}

void main() {
    vec2 p = qt_TexCoord0 * size.xy;

    float d = shapeOf(p);

    float below = inside(edge - p.y);

    float band = p.y - edge;
    float joined = joinOf(p, d);
    float own = neck > 0.0 ? clamp(0.5 + 0.5 * (band - d) / neck, 0.0, 1.0) : 1.0;

    float shape = inside(joined) * below;
    vec4 ink = texture(source, qt_TexCoord0) * inside(d) * below;

    if (glass > 0.5) {
        vec4 clear = shape > 0.0 ? glassBody(p, joined, own, shape) : vec4(0.0);
        fragColor = (ink + clear * (1.0 - ink.a)) * qt_Opacity;
        return;
    }

    vec4 body = mix(bandColour, colour, own) * shape;

    if (radii.z > 0.0) {
        float ring = inside(abs(joined + radii.z * 0.5) - radii.z * 0.5) * below;

        vec2 across = vec2(dFdx(p.x), dFdy(p.y));
        vec2 slope = vec2(dFdx(joined) / (abs(across.x) > 0.0 ? across.x : 1.0), dFdy(joined) / (abs(across.y) > 0.0 ? across.y : 1.0));
        vec2 normal = length(slope) > 0.0 ? normalize(slope) : vec2(0.0);
        float lit = litFrom(normal);

        vec4 sheen = sheenColour * ring * (0.35 + 0.65 * lit);
        body = sheen + body * (1.0 - sheen.a);
    }

    fragColor = (ink + body * (1.0 - ink.a)) * qt_Opacity;
}
