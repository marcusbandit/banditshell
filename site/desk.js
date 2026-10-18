const SPEED = 14;
const PULL = 28;
const GOO = 14;

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const lerp = (a, b, t) => a + (b - a) * t;

const VERTEX = `
attribute vec2 corner;
void main() { gl_Position = vec4(corner, 0.0, 1.0); }
`;

const FRAGMENT = `
precision highp float;
uniform vec2 size;
uniform float dpr;
uniform vec4 inner;
uniform float radius;
uniform vec4 boxes[3];
uniform float boxRadius;
uniform vec3 bulge;

float squircle(vec2 p, vec4 r, float k) {
    vec2 h = (r.zw - r.xy) * 0.5;
    k = min(k, min(h.x, h.y));
    vec2 q = abs(p - (r.xy + r.zw) * 0.5) - h + k;
    vec2 m = max(q, 0.0);
    m *= m;
    return sqrt(sqrt(m.x * m.x + m.y * m.y)) + min(max(q.x, q.y), 0.0) - k;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float ridge(float x, float seed) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(vec2(i, seed)), hash(vec2(i + 1.0, seed)), f * f * (3.0 - 2.0 * f));
}

float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

vec3 tone(float i) {
    if (i < 0.5) return vec3(0.059, 0.067, 0.078);
    if (i < 1.5) return vec3(0.094, 0.106, 0.122);
    if (i < 2.5) return vec3(0.149, 0.169, 0.192);
    if (i < 3.5) return vec3(0.200, 0.290, 0.360);
    if (i < 4.5) return vec3(0.357, 0.561, 0.690);
    return vec3(0.498, 0.702, 0.831);
}

vec3 wallpaper(vec2 p) {
    float px = max(2.0, floor(size.x / 260.0));
    vec2 q = floor(p / px);
    vec2 uv = q * px / size;
    float horizon = 0.7;
    float rise = clamp(uv.y / horizon, 0.0, 1.0);
    float sun = 0.7 + 0.3 * exp(-pow((uv.x - 0.62) / 0.3, 2.0));
    float v = pow(rise, 3.2) * 0.9 * sun;
    float far = horizon - 0.07 + 0.08 * ridge(uv.x * 6.0, 3.0) + 0.02 * ridge(uv.x * 29.0, 7.0);
    float near = horizon + 0.08 + 0.07 * ridge(uv.x * 3.5, 11.0) + 0.015 * ridge(uv.x * 37.0, 5.0);
    if (uv.y > far) v = 0.32 - (uv.y - far) * 0.6;
    if (uv.y > near) v = 0.06;
    float level = clamp(floor(v * 5.0 + bayer4(q)), 0.0, 5.0);
    vec3 colour = tone(level);
    float star = step(0.9965, hash(q)) * step(uv.y, horizon - 0.2);
    return mix(colour, vec3(0.933, 0.949, 0.961), star * 0.7);
}

void main() {
    vec2 p = vec2(gl_FragCoord.x, size.y * dpr - gl_FragCoord.y) / dpr;
    float content = squircle(p, inner, radius);
    vec2 d = p - bulge.xy;
    content += bulge.z * 14.0 * exp(-dot(d, d) / 3200.0);
    float s = -content;
    for (int i = 0; i < 3; i++) {
        vec4 b = boxes[i];
        if (b.z > b.x) s = smin(s, squircle(p, b, boxRadius), i == 0 ? 6.0 : ${GOO.toFixed(1)});
    }
    float body = clamp(0.5 - s * dpr, 0.0, 1.0);
    vec3 colour = mix(wallpaper(p), vec3(0.114, 0.129, 0.149), body * 0.96);
    colour += vec3(0.933, 0.949, 0.961) * 0.07 * clamp(1.0 - abs(s + 0.5) * dpr, 0.0, 1.0);
    float screen = squircle(p, vec4(0.0, 0.0, size), radius + inner.y);
    float alpha = clamp(0.5 - screen * dpr, 0.0, 1.0);
    gl_FragColor = vec4(colour * alpha, alpha);
}
`;

function compile(gl) {
    const shader = (type, source) => {
        const s = gl.createShader(type);
        gl.shaderSource(s, source);
        gl.compileShader(s);
        return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
    };
    const vs = shader(gl.VERTEX_SHADER, VERTEX);
    const fs = shader(gl.FRAGMENT_SHADER, FRAGMENT);
    if (!vs || !fs) return null;
    const program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return null;
    gl.useProgram(program);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const corner = gl.getAttribLocation(program, "corner");
    gl.enableVertexAttribArray(corner);
    gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, 0, 0);
    const names = ["size", "dpr", "inner", "radius", "boxes", "boxRadius", "bulge"];
    return Object.fromEntries(names.map((n) => [n, gl.getUniformLocation(program, n)]));
}

function evaluate(text) {
    const tokens = text.replace(/,/g, ".").match(/\d*\.?\d+|[-+*/%^()]/g);
    if (!tokens || tokens.join("") !== text.replace(/\s|,/g, (c) => (c === "," ? "." : ""))) return null;
    let i = 0;
    const peek = () => tokens[i];
    const take = () => tokens[i++];
    const primary = () => {
        if (peek() === "(") {
            take();
            const v = sum();
            if (take() !== ")") throw 0;
            return v;
        }
        if (peek() === "-") {
            take();
            return -primary();
        }
        const n = Number(take());
        if (Number.isNaN(n)) throw 0;
        return n;
    };
    const power = () => {
        const base = primary();
        if (peek() === "^") {
            take();
            return base ** power();
        }
        return base;
    };
    const product = () => {
        let v = power();
        while (["*", "/", "%"].includes(peek())) {
            const op = take();
            const r = power();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    };
    const sum = () => {
        let v = product();
        while (["+", "-"].includes(peek())) v = take() === "+" ? v + product() : v - product();
        return v;
    };
    try {
        const v = sum();
        return i === tokens.length && Number.isFinite(v) && /[-+*/%^]/.test(text) ? v : null;
    } catch {
        return null;
    }
}

function boot(desk) {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)");
    const canvas = desk.querySelector("canvas");
    const gl = canvas.getContext("webgl", { premultipliedAlpha: true, antialias: false });
    const uniforms = gl && compile(gl);
    if (!uniforms) desk.classList.add("flat");

    const surfaces = {};
    for (const el of desk.querySelectorAll("[data-surface]")) {
        surfaces[el.dataset.surface] = { el, t: 0, target: 0 };
    }
    const buttons = [...document.querySelectorAll("[data-summon]")];
    let geo = null;
    let bulge = { x: 0, y: 0, a: 0, target: 0 };
    let drag = null;
    let frame = 0;
    let last = 0;
    let visible = true;
    let touched = false;
    let outside = null;
    let swallow = false;
    const watch = document.querySelector("[data-watch]");
    const watching = () => desk.classList.contains("watching");

    function measure() {
        const W = desk.clientWidth;
        const H = desk.clientHeight;
        const band = Math.round(clamp(W * 0.01, 6, 10));
        const rail = Math.round(clamp(W * 0.04, 26, 40));
        const gap = band * 2;
        const inner = { x0: rail, y0: band, x1: W - band, y1: H - band };
        const cw = inner.x1 - inner.x0;
        const ch = inner.y1 - inner.y0;
        const cx = (inner.x0 + inner.x1) / 2;
        const calendarHeight = Math.min(250, ch - 2 * gap);
        geo = {
            W, H, band, rail, inner, cx,
            radius: 12,
            island: { w: Math.min(380, cw - 2 * gap), h: 100 },
            launcher: { w: Math.min(580, cw - 2 * gap), h: Math.min(300, ch * 0.64) },
            calendar: { w: Math.min(264, cw - 2 * gap), h: calendarHeight, cy: inner.y1 - gap - calendarHeight / 2 },
        };
        canvas.width = Math.round(W * dpr());
        canvas.height = Math.round(H * dpr());
        desk.style.setProperty("--rail", `${rail}px`);
        desk.style.setProperty("--band", `${band}px`);
        const strips = {
            island: { left: cx - geo.island.w / 2, top: 0, width: geo.island.w, height: inner.y0 + PULL },
            launcher: { left: cx - geo.launcher.w / 2, top: inner.y1 - PULL, width: geo.launcher.w, height: H - inner.y1 + PULL },
            calendar: { left: 0, top: geo.calendar.cy - geo.calendar.h / 2, width: inner.x0 + PULL, height: geo.calendar.h },
        };
        for (const el of desk.querySelectorAll("[data-handle]")) {
            const r = strips[el.dataset.handle];
            Object.assign(el.style, { left: `${r.left}px`, top: `${r.top}px`, width: `${r.width}px`, height: `${r.height}px` });
        }
        for (const name in surfaces) place(name);
        draw();
    }

    const dpr = () => Math.min(2, window.devicePixelRatio || 1);

    function finalRect(name) {
        const { inner, cx } = geo;
        const g = geo[name];
        if (name === "island") return { x0: cx - g.w / 2, y0: inner.y0 + 10, x1: cx + g.w / 2, y1: inner.y0 + 10 + g.h };
        if (name === "launcher") return { x0: cx - g.w / 2, y0: inner.y1 - g.h, x1: cx + g.w / 2, y1: inner.y1 };
        return { x0: inner.x0, y0: g.cy - g.h / 2, x1: inner.x0 + g.w, y1: g.cy + g.h / 2 };
    }

    function rect(name, t) {
        const { inner, cx, H } = geo;
        const g = geo[name];
        if (name === "island") {
            const w = lerp(56, g.w, t);
            const top = inner.y0 + lerp(8, 10, t);
            return { x0: cx - w / 2, y0: top, x1: cx + w / 2, y1: top + lerp(10, g.h, t) };
        }
        if (name === "launcher") {
            const w = g.w * lerp(0.32, 1, t);
            return { x0: cx - w / 2, y0: inner.y1 + GOO - (g.h + GOO) * t, x1: cx + w / 2, y1: H };
        }
        const h = g.h * lerp(0.4, 1, t);
        return { x0: 0, y0: g.cy - h / 2, x1: inner.x0 - GOO + (g.w + GOO) * t, y1: g.cy + h / 2 };
    }

    function place(name) {
        const s = surfaces[name];
        const f = finalRect(name);
        const r = rect(name, s.t);
        const { inner } = geo;
        const dx = name === "calendar" ? Math.min(0, r.x1 - f.x1) : 0;
        const dy = name === "launcher" ? Math.max(0, r.y0 - f.y0) : 0;
        Object.assign(s.el.style, {
            left: `${f.x0}px`,
            top: `${f.y0}px`,
            width: `${f.x1 - f.x0}px`,
            height: `${f.y1 - f.y0}px`,
            transform: dx || dy ? `translate(${dx}px, ${dy}px)` : "",
        });
        const x0 = f.x0 + dx;
        const y0 = f.y0 + dy;
        const top = Math.max(0, r.y0 - y0, inner.y0 - y0);
        const right = Math.max(0, f.x1 + dx - r.x1);
        const bottom = Math.max(0, f.y1 + dy - Math.min(r.y1, inner.y1));
        const left = Math.max(0, r.x0 - x0, inner.x0 - x0);
        s.el.style.clipPath = `inset(${top}px ${right}px ${bottom}px ${left}px round ${geo.radius}px)`;
        s.el.inert = s.target !== 1 && s.t < 0.3;
        s.el.classList.toggle("open", s.target === 1);
        for (const b of buttons) if (b.dataset.summon === name) b.setAttribute("aria-pressed", String(s.target === 1));
    }

    function draw() {
        if (!uniforms) return;
        const { W, H, inner, radius } = geo;
        gl.viewport(0, 0, canvas.width, canvas.height);
        gl.uniform2f(uniforms.size, W, H);
        gl.uniform1f(uniforms.dpr, dpr());
        gl.uniform4f(uniforms.inner, inner.x0, inner.y0, inner.x1, inner.y1);
        gl.uniform1f(uniforms.radius, radius);
        gl.uniform1f(uniforms.boxRadius, radius);
        const flat = [];
        for (const name of ["island", "launcher", "calendar"]) {
            const r = rect(name, surfaces[name].t);
            flat.push(r.x0, r.y0, r.x1, r.y1);
        }
        gl.uniform4fv(uniforms.boxes, flat);
        gl.uniform3f(uniforms.bulge, bulge.x, bulge.y, bulge.a);
        gl.drawArrays(gl.TRIANGLES, 0, 3);
    }

    function tick(now) {
        frame = 0;
        const dt = Math.min(0.05, last ? (now - last) / 1000 : 1 / 60);
        last = now;
        const k = 1 - Math.exp(-SPEED * dt);
        let moving = false;
        for (const name in surfaces) {
            const s = surfaces[name];
            if (drag?.name !== name && s.t !== s.target) {
                s.t += (s.target - s.t) * k;
                if (Math.abs(s.target - s.t) < 0.001) s.t = s.target;
                else moving = true;
            }
            place(name);
        }
        if (bulge.a !== bulge.target) {
            bulge.a += (bulge.target - bulge.a) * (1 - Math.exp(-10 * dt));
            if (Math.abs(bulge.target - bulge.a) < 0.002) bulge.a = bulge.target;
            else moving = true;
        }
        draw();
        if (moving) frame = requestAnimationFrame(tick);
        else last = 0;
    }

    function wake() {
        if (!frame) frame = requestAnimationFrame(tick);
    }

    function set(name, open, instant) {
        const s = surfaces[name];
        s.target = open ? 1 : 0;
        if (instant || reduce.matches) s.t = s.target;
        if (open && name === "launcher") {
            const field = s.el.querySelector("input");
            if (instant) field.focus({ preventScroll: true });
        }
        place(name);
        draw();
        wake();
    }

    const toggle = (name, instant) => set(name, surfaces[name].target !== 1, instant);
    const closeAll = () => {
        for (const name in surfaces) if (surfaces[name].target) set(name, false, true);
    };

    for (const b of buttons) {
        b.addEventListener("click", (e) => {
            touched = true;
            const name = b.dataset.summon;
            const keyboard = e.detail === 0;
            toggle(name, keyboard);
            if (name === "launcher" && surfaces.launcher.target) surfaces.launcher.el.querySelector("input").focus({ preventScroll: true });
        });
    }

    watch?.addEventListener("click", () => {
        const on = !watching();
        closeAll();
        desk.classList.toggle("watching", on);
        watch.setAttribute("aria-pressed", String(on));
        watch.textContent = on ? "Back to the demo" : "Watch the real one";
        for (const b of buttons) b.disabled = on;
    });

    addEventListener("keydown", (e) => {
        if (!visible || watching() || e.ctrlKey || e.metaKey || e.altKey) return;
        const typing = e.target.closest?.("input, textarea, [contenteditable]");
        if (e.key === "Escape") {
            if (Object.values(surfaces).some((s) => s.target)) {
                closeAll();
                if (typing) e.target.blur();
                e.preventDefault();
            }
            return;
        }
        if (typing) return;
        const name = { i: "island", l: "launcher", "/": "launcher", c: "calendar" }[e.key.toLowerCase()];
        if (!name) return;
        e.preventDefault();
        touched = true;
        if (name === "launcher" && e.key === "/") set(name, true, true);
        else toggle(name, true);
        if (surfaces.launcher.target && name === "launcher") surfaces.launcher.el.querySelector("input").focus({ preventScroll: true });
    });

    const local = (e) => {
        const box = desk.getBoundingClientRect();
        return { x: e.clientX - box.left, y: e.clientY - box.top };
    };

    function handleAt(p) {
        const { inner, cx, island, launcher, calendar } = geo;
        if (p.y > inner.y1 - PULL && Math.abs(p.x - cx) < launcher.w / 2) return "launcher";
        if (p.y < inner.y0 + PULL && Math.abs(p.x - cx) < island.w / 2) return "island";
        if (p.x < inner.x0 + PULL && Math.abs(p.y - calendar.cy) < calendar.h / 2) return "calendar";
        return null;
    }

    function surfaceAt(p) {
        for (const name of ["launcher", "calendar", "island"]) {
            const s = surfaces[name];
            if (s.t < 0.05) continue;
            const r = rect(name, s.t);
            if (p.x > r.x0 && p.x < r.x1 && p.y > r.y0 && p.y < r.y1) return name;
        }
        return null;
    }

    const progress = (name, from, p) => {
        const g = geo[name];
        if (name === "launcher") return (from.y - p.y) / g.h;
        if (name === "island") return (p.y - from.y) / g.h;
        return (p.x - from.x) / g.w;
    };

    desk.addEventListener("pointerdown", (e) => {
        if (e.button !== 0 || watching() || e.target.closest("input")) return;
        const p = local(e);
        const home = e.target.closest("[data-home]")?.dataset.home;
        const edge = e.target.closest("[data-handle]")?.dataset.handle ?? handleAt(p);
        const onSurface = surfaceAt(p);
        const interactive = e.target.closest("a, button");
        const name = home ?? (onSurface && e.pointerType !== "touch" ? onSurface : edge);
        if (!name) {
            outside = { x: p.x, y: p.y, id: e.pointerId };
            return;
        }
        touched = true;
        const tap = Boolean(home) || (!interactive && !onSurface && edge === name);
        drag = { name, tap, from: p, start: surfaces[name].t, moved: false, at: e.timeStamp, last: p, velocity: 0, id: e.pointerId };
    });

    desk.addEventListener("pointermove", (e) => {
        const p = local(e);
        if (drag && e.pointerId === drag.id) {
            const travel = Math.hypot(p.x - drag.from.x, p.y - drag.from.y);
            if (!drag.moved && travel > 6) {
                drag.moved = true;
                surfaces[drag.name].target = surfaces[drag.name].t;
                desk.setPointerCapture(e.pointerId);
                desk.classList.add("dragging");
            }
            if (drag.moved) {
                const s = surfaces[drag.name];
                const dt = Math.max(1, e.timeStamp - drag.at);
                drag.velocity = (progress(drag.name, drag.last, p) * 1000) / dt;
                drag.at = e.timeStamp;
                drag.last = p;
                s.t = clamp(drag.start + progress(drag.name, drag.from, p), 0, 1);
                s.target = s.t;
                place(drag.name);
                draw();
            }
        }
        if (e.pointerType === "mouse" && !reduce.matches && geo) {
            const { inner } = geo;
            const edge = Math.min(p.x - inner.x0, inner.x1 - p.x, p.y - inner.y0, inner.y1 - p.y);
            bulge.x = p.x;
            bulge.y = p.y;
            bulge.target = clamp(1 - edge / 70, 0, 1);
            wake();
        }
    });

    const release = (e) => {
        if (outside && e.pointerId === outside.id) {
            const p = local(e);
            if (e.type === "pointerup" && Math.hypot(p.x - outside.x, p.y - outside.y) < 6) {
                for (const name in surfaces) if (surfaces[name].target) set(name, false, false);
            }
            outside = null;
        }
        if (!drag || e.pointerId !== drag.id) return;
        const { name, moved, velocity, tap } = drag;
        const s = surfaces[name];
        drag = null;
        desk.classList.remove("dragging");
        if (!moved) {
            if (tap && e.type === "pointerup") toggle(name, false);
        } else {
            swallow = true;
            setTimeout(() => (swallow = false), 0);
            s.target = Math.abs(velocity) > 0.8 ? (velocity > 0 ? 1 : 0) : s.t > 0.4 ? 1 : 0;
            if (reduce.matches) s.t = s.target;
        }
        if (name === "launcher" && s.target === 1 && e.pointerType !== "touch") s.el.querySelector("input").focus({ preventScroll: true });
        place(name);
        wake();
    };
    desk.addEventListener("pointerup", release);
    desk.addEventListener("pointercancel", release);
    desk.addEventListener("pointerleave", () => {
        bulge.target = 0;
        wake();
    });
    desk.addEventListener("click", (e) => {
        if (swallow) {
            e.preventDefault();
            e.stopPropagation();
        }
    }, true);

    launcher(surfaces.launcher.el, (name) => set(name, false, true));
    calendar(desk.querySelector("[data-calendar]"));
    clock(desk.querySelector("[data-clock]"));

    new ResizeObserver(measure).observe(desk);
    new IntersectionObserver(([entry]) => {
        visible = entry.isIntersecting;
    }, { threshold: 0.25 }).observe(desk);

    if (!reduce.matches) {
        setTimeout(() => {
            if (touched || !visible) return;
            set("island", true, false);
            setTimeout(() => {
                if (!touched && !surfaces.island.el.matches(":hover")) set("island", false, false);
            }, 5200);
        }, 1100);
    }
}

function launcher(panel, close) {
    const field = panel.querySelector("input");
    const list = panel.querySelector("[data-results]");
    const entries = JSON.parse(panel.querySelector("[data-entries]").textContent);
    let rows = [];
    let chosen = 0;

    function show() {
        const query = field.value.trim();
        const sum = evaluate(query);
        if (sum !== null) {
            const value = String(Math.round(sum * 1e9) / 1e9);
            rows = [{ label: value, hint: "Copy", copy: value }];
        } else {
            const q = query.toLowerCase();
            rows = entries.filter((e) => !q || e.label.toLowerCase().includes(q) || e.words?.toLowerCase().includes(q)).slice(0, 6);
            if (!rows.length) rows = [{ label: `Search GitHub for "${query}"`, hint: "Web", href: `https://github.com/marcusbandit/banditshell/search?q=${encodeURIComponent(query)}` }];
        }
        chosen = clamp(chosen, 0, rows.length - 1);
        list.replaceChildren(...rows.map((row, n) => {
            const item = document.createElement(row.copy ? "button" : "a");
            item.className = "row";
            if (row.href) item.href = row.href;
            if (n === chosen) item.setAttribute("aria-current", "true");
            const label = document.createElement("span");
            label.textContent = row.label;
            const hint = document.createElement("span");
            hint.className = "hint";
            hint.textContent = row.hint;
            item.append(label, hint);
            item.addEventListener("click", (e) => activate(row, e));
            return item;
        }));
    }

    function activate(row, e) {
        if (row.copy) {
            e?.preventDefault();
            navigator.clipboard?.writeText(row.copy);
            list.querySelector(".hint").textContent = "Copied";
            return;
        }
        if (!e) location.href = row.href;
        if (row.href.startsWith("#")) close("launcher");
    }

    field.addEventListener("input", () => {
        chosen = 0;
        show();
    });
    field.addEventListener("keydown", (e) => {
        if (e.key === "ArrowDown" || e.key === "ArrowUp") {
            chosen = clamp(chosen + (e.key === "ArrowDown" ? 1 : -1), 0, rows.length - 1);
            show();
            e.preventDefault();
        } else if (e.key === "Enter" && rows[chosen]) {
            activate(rows[chosen]);
            e.preventDefault();
        }
    });
    show();
}

function calendar(root) {
    const today = new Date();
    const first = new Date(today.getFullYear(), today.getMonth(), 1);
    const offset = (first.getDay() + 6) % 7;
    const cells = [];
    for (let n = 0; n < 42; n++) {
        const day = new Date(first.getFullYear(), first.getMonth(), n - offset + 1);
        const cell = document.createElement("span");
        cell.textContent = day.getDate();
        if (day.getMonth() !== first.getMonth()) cell.className = "other";
        if (day.toDateString() === today.toDateString()) cell.className = "today";
        cells.push(cell);
    }
    root.querySelector("[data-day]").textContent = today.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" });
    root.querySelector("[data-month]").textContent = today.toLocaleDateString("en-GB", { month: "long", year: "numeric" });
    root.querySelector("[data-days]").replaceChildren(...cells);
}

function clock(root) {
    const tick = () => {
        const now = new Date();
        const pad = (n) => String(n).padStart(2, "0");
        root.querySelector("[data-hours]").textContent = pad(now.getHours());
        root.querySelector("[data-minutes]").textContent = pad(now.getMinutes());
        root.querySelector("[data-date]").textContent = `${now.getDate()} ${now.toLocaleDateString("en-GB", { month: "short" }).slice(0, 3)}`;
    };
    tick();
    setInterval(tick, 20000);
}

const desk = document.querySelector("[data-desk]");
if (desk) boot(desk);
