import { execFileSync } from "node:child_process";
import { copyFileSync, cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { escape, inline, render } from "./roadmap.mjs";

const SITE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(SITE, "..");
const DIST = join(SITE, "dist");
const REPO = "https://github.com/marcusbandit/banditshell";
const ORIGIN = "https://banditshell.marcusrosado.com";
const SOURCE = "docs/roadmap.md";

const git = (...args) => {
    try {
        return execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();
    } catch {
        return "";
    }
};

const read = (path) => readFileSync(join(ROOT, path), "utf8");
const template = (name) => readFileSync(join(SITE, name), "utf8");
const fill = (text, values) => text.replace(/\{\{(\w+)\}\}/g, (_, key) => values[key] ?? "");
const plain = (html) =>
    html.replace(/<[^>]+>/g, " ").replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();

const roadmap = render(read(SOURCE), REPO);
const updated = git("log", "-1", "--format=%cs", "--", SOURCE) || new Date().toLocaleDateString("sv");
const commit = git("rev-parse", "--short", "HEAD");
const vision = roadmap.sections[0]?.blocks.find((block) => block.type === "paragraph")?.text ?? "";

const now = roadmap.sections.find((section) => section.id === "now")?.blocks ?? [];
const after = now.findIndex((block) => block.type === "paragraph" && /being built/i.test(block.text));
const building = now.slice(after + 1).find((block) => block.type === "list") ?? now.find((block) => block.type === "list");
const notes = (building?.items ?? []).slice(0, 4).map((item) => {
    const [, title = item, body = ""] = item.match(/^\*\*(.+?)\.?\*\*\s*(.*)$/) ?? [];
    return `<article class="note"><span class="note-icon" aria-hidden="true"></span><span class="note-text"><strong>${inline(title, REPO)}</strong><span>${inline(body, REPO)}</span></span></article>`;
});

const entries = [
    { label: "Install banditshell", hint: "Install", href: "#install" },
    { label: "What's in it", hint: "Features", href: "#features" },
    { label: "Read the roadmap", hint: "Roadmap", href: "/roadmap/" },
    ...roadmap.sections.map((section) => ({
        label: section.label,
        hint: "Roadmap",
        href: `/roadmap/#${section.id}`,
        words: plain(section.html).slice(0, 1600),
    })),
    { label: "Source on GitHub", hint: "GitHub", href: REPO },
    { label: "Report a bug", hint: "GitHub", href: `${REPO}/issues` },
    { label: "Buy me a coffee", hint: "Ko-fi", href: "https://ko-fi.com/marcusbandit" },
];

const page = (values) =>
    fill(template("layout.html"), {
        repo: REPO,
        commit: commit ? `<a href="${REPO}/commit/${commit}"><code>${commit}</code></a>` : "an uncommitted tree",
        roadmapCurrent: "",
        scripts: "",
        ...values,
    });

rmSync(DIST, { recursive: true, force: true });
mkdirSync(join(DIST, "roadmap"), { recursive: true });

const description = "A desktop shell for Hyprland, written from scratch in Quickshell. Nothing sits on screen until you reach for it.";

writeFileSync(
    join(DIST, "index.html"),
    page({
        title: "banditshell, a desktop shell for Hyprland",
        description,
        url: `${ORIGIN}/`,
        page: "home",
        main: fill(template("home.html"), {
            entries: JSON.stringify(entries).replace(/</g, "\\u003c"),
            vision: inline(vision, REPO),
            now: notes.join("\n"),
        }),
        scripts: '<script type="module" src="/desk.js"></script>',
    }),
);

writeFileSync(
    join(DIST, "roadmap", "index.html"),
    page({
        title: escape(roadmap.title),
        description: escape(vision),
        url: `${ORIGIN}/roadmap/`,
        page: "roadmap-page",
        roadmapCurrent: ' aria-current="page"',
        main: fill(template("roadmap.html"), {
            heading: escape(roadmap.title),
            updated,
            source: `${REPO}/blob/main/${SOURCE}`,
            nav: roadmap.sections.map((section) => `<a href="#${section.id}">${escape(section.label)}</a>`).join("\n"),
            sections: roadmap.sections.map((section) => section.html).join("\n"),
        }),
    }),
);

writeFileSync(
    join(DIST, "404.html"),
    page({
        title: "Not here | banditshell",
        description,
        url: `${ORIGIN}/`,
        page: "lost",
        main: `<section class="band lost"><h1>Not here</h1><p class="measure">Nothing lives at this address. The <a href="/">front page</a> and the <a href="/roadmap/">roadmap</a> do.</p></section>`,
    }),
);

const wordmark = read("docs/readme/wordmark.svg");
const between = (from, to) => wordmark.slice(wordmark.indexOf(from), wordmark.indexOf(to, wordmark.indexOf(from)) + to.length);
writeFileSync(
    join(DIST, "wordmark-word.svg"),
    [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="50 92 800 150" width="800" height="150" role="img" aria-label="banditshell">',
        "<defs>",
        between("<clipPath", "</clipPath>"),
        between('<linearGradient id="ink"', "</linearGradient>"),
        "</defs>",
        between('<g fill="#1D2126">', "</g>"),
        '<rect x="54" y="96" width="726" height="77" fill="url(#ink)" clip-path="url(#word)"/>',
        '<rect x="791" y="96" width="55" height="77" fill="#D8C48C"/>',
        between('<g fill="#78838F">', "</g>"),
        "</svg>",
        "",
    ].join("\n"),
);

const word = between("<clipPath", "</clipPath>");
const letter = [...word.matchAll(/<rect x="(\d+)" y="(\d+)" width="11" height="11"\/>/g)]
    .filter(([, x]) => Number(x) < 110)
    .map(([rect]) => rect)
    .join("");
writeFileSync(
    join(DIST, "favicon.svg"),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="31.5 84.5 100 100"><rect x="31.5" y="84.5" width="100" height="100" rx="22" fill="#1D2126"/><g fill="#B8DCF0">${letter}</g></svg>\n`,
);

for (const name of ["style.css", "site.js", "desk.js"]) copyFileSync(join(SITE, name), join(DIST, name));
cpSync(join(SITE, "fonts"), join(DIST, "fonts"), { recursive: true });
cpSync(join(SITE, "images"), join(DIST, "images"), { recursive: true });
copyFileSync(join(ROOT, "docs/readme/hero.webp"), join(DIST, "hero.webp"));

console.log(`built ${DIST} from ${SOURCE}, updated ${updated}${commit ? ` at ${commit}` : ""}`);
