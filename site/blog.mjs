import { readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";
import { blocks, escape, html } from "./roadmap.mjs";

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

export const longDate = (iso) => {
    const [year, month, day] = iso.split("-").map(Number);
    return `${day} ${MONTHS[month - 1]} ${year}`;
};

export function front(source) {
    const match = source.replace(/\r/g, "").match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
    if (!match) throw new Error("a post starts with a --- front matter block");
    const meta = {};
    for (const line of match[1].split("\n")) {
        const [, key, value] = line.match(/^(\w+):\s*(.*)$/) ?? [];
        if (key) meta[key] = value.replace(/^"(.*)"$/, "$1");
    }
    return { meta, body: match[2] };
}

export function webpSize(buffer) {
    if (buffer.length < 30 || buffer.toString("ascii", 0, 4) !== "RIFF" || buffer.toString("ascii", 8, 12) !== "WEBP") return null;
    const kind = buffer.toString("ascii", 12, 16);
    if (kind === "VP8X") return { width: buffer.readUIntLE(24, 3) + 1, height: buffer.readUIntLE(27, 3) + 1 };
    if (kind === "VP8L") {
        const bits = buffer.readUInt32LE(21);
        return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
    }
    if (kind === "VP8 ") return { width: buffer.readUInt16LE(26) & 0x3fff, height: buffer.readUInt16LE(28) & 0x3fff };
    return null;
}

export function pngSize(buffer) {
    if (buffer.length < 24 || buffer.toString("latin1", 1, 4) !== "PNG" || buffer.toString("ascii", 12, 16) !== "IHDR") return null;
    return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

export function jpegSize(buffer) {
    if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8) return null;
    let at = 2;
    while (at + 9 < buffer.length) {
        if (buffer[at] !== 0xff) return null;
        const marker = buffer[at + 1];
        if (marker === 0xff) {
            at += 1;
            continue;
        }
        if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
            return { width: buffer.readUInt16BE(at + 7), height: buffer.readUInt16BE(at + 5) };
        }
        at += 2 + buffer.readUInt16BE(at + 2);
    }
    return null;
}

export const imageSize = (buffer) => webpSize(buffer) ?? pngSize(buffer) ?? jpegSize(buffer);

const IMAGE_SRC = /^\/images\/[\w.-]+\.(?:webp|png|jpe?g)$/i;

export function flag(value, file) {
    if (value === undefined) return false;
    const text = value.replace(/\s+#.*$/, "").replace(/^(["'])(.*)\1$/, "$2").trim().toLowerCase();
    if (text === "true") return true;
    if (text === "false") return false;
    throw new Error(`${file}: draft is true or false`);
}

const realDate = (iso) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) return false;
    const date = new Date(`${iso}T00:00:00Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === iso;
};

const releaseKey = (release) => (release.match(/^v?(\d+)\.(\d+)\.(\d+)/) ?? []).slice(1).map(Number);

const byRelease = (a, b) => {
    const left = releaseKey(a.release);
    const right = releaseKey(b.release);
    for (let i = 0; i < 3; i++) {
        const delta = (right[i] ?? 0) - (left[i] ?? 0);
        if (delta) return delta;
    }
    return 0;
};

export function post(source, file, site, repo) {
    const { meta, body } = front(source);
    const slug = basename(file, ".md");
    for (const key of ["title", "date", "summary"]) {
        if (!meta[key]) throw new Error(`${file}: front matter needs ${key}`);
    }
    if (!realDate(meta.date)) throw new Error(`${file}: date is a real day as YYYY-MM-DD`);
    const draft = flag(meta.draft, file);
    const parsed = blocks(body);
    for (const block of parsed) {
        if (block.type !== "image") continue;
        if (!IMAGE_SRC.test(block.src)) throw new Error(`${file}: image ${block.src} must be /images/<name>.webp, .png or .jpg`);
        let buffer;
        try {
            buffer = readFileSync(join(site, block.src.slice(1)));
        } catch {
            throw new Error(`${file}: image ${block.src} is not in site/`);
        }
        const size = imageSize(buffer);
        if (!size) throw new Error(`${file}: image ${block.src} is not a readable webp, png or jpg`);
        Object.assign(block, size);
    }
    return {
        slug,
        title: meta.title,
        date: meta.date,
        summary: meta.summary,
        release: meta.release ?? "",
        draft,
        html: parsed.map((block) => html(block, repo)).join("\n"),
        words: parsed
            .filter((block) => block.type === "paragraph")
            .map((block) => block.text)
            .join(" ")
            .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
            .replace(/[*`]/g, "")
            .slice(0, 1600),
    };
}

export function posts(dir, site, repo, { drafts = false } = {}) {
    return readdirSync(dir)
        .filter((name) => name.endsWith(".md"))
        .map((name) => ({ name, source: readFileSync(join(dir, name), "utf8") }))
        .filter(({ name, source }) => drafts || !flag(front(source).meta.draft, name))
        .map(({ name, source }) => post(source, name, site, repo))
        .sort((a, b) => b.date.localeCompare(a.date) || byRelease(a, b));
}

export const card = (entry) =>
    `<article class="post-card"><p class="meta"><time datetime="${entry.date}">${longDate(entry.date)}</time>${entry.release ? `, ${escape(entry.release)}` : ""}${entry.draft ? ' <span class="chip">Draft</span>' : ""}</p>` +
    `<h2><a href="/blog/${entry.slug}/">${escape(entry.title)}</a></h2><p>${escape(entry.summary)}</p></article>`;
