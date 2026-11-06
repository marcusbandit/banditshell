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
    if (buffer.toString("ascii", 0, 4) !== "RIFF" || buffer.toString("ascii", 8, 12) !== "WEBP") return null;
    const kind = buffer.toString("ascii", 12, 16);
    if (kind === "VP8X") return { width: buffer.readUIntLE(24, 3) + 1, height: buffer.readUIntLE(27, 3) + 1 };
    if (kind === "VP8L") {
        const bits = buffer.readUInt32LE(21);
        return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
    }
    if (kind === "VP8 ") return { width: buffer.readUInt16LE(26) & 0x3fff, height: buffer.readUInt16LE(28) & 0x3fff };
    return null;
}

export function post(source, file, site, repo) {
    const { meta, body } = front(source);
    const slug = basename(file, ".md");
    for (const key of ["title", "date", "summary"]) {
        if (!meta[key]) throw new Error(`${file}: front matter needs ${key}`);
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(meta.date)) throw new Error(`${file}: date is YYYY-MM-DD`);
    const parsed = blocks(body);
    for (const block of parsed) {
        if (block.type !== "image") continue;
        try {
            Object.assign(block, webpSize(readFileSync(join(site, block.src.replace(/^\//, "")))) ?? {});
        } catch {
            throw new Error(`${file}: image ${block.src} is not in site/`);
        }
    }
    return {
        slug,
        title: meta.title,
        date: meta.date,
        summary: meta.summary,
        release: meta.release ?? "",
        draft: meta.draft === "true",
        html: parsed.map((block) => html(block, repo)).join("\n"),
        words: parsed.filter((block) => block.type === "paragraph").map((block) => block.text).join(" ").replace(/[*`]/g, "").slice(0, 1600),
    };
}

export function posts(dir, site, repo, { drafts = false } = {}) {
    return readdirSync(dir)
        .filter((name) => name.endsWith(".md"))
        .map((name) => post(readFileSync(join(dir, name), "utf8"), name, site, repo))
        .filter((entry) => drafts || !entry.draft)
        .sort((a, b) => b.date.localeCompare(a.date) || b.slug.localeCompare(a.slug));
}

export const card = (entry) =>
    `<article class="post-card"><p class="meta"><time datetime="${entry.date}">${longDate(entry.date)}</time>${entry.release ? ` · ${escape(entry.release)}` : ""}${entry.draft ? ' · <span class="chip">Draft</span>' : ""}</p>` +
    `<h2><a href="/blog/${entry.slug}/">${escape(entry.title)}</a></h2><p>${escape(entry.summary)}</p></article>`;
