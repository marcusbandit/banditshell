import { execFileSync } from "node:child_process";
import { copyFileSync, cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { card, imageSize, longDate, posts } from "./blog.mjs";
import { escape, inline, render } from "./roadmap.mjs";

const SITE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(SITE, "..");
const DIST = join(SITE, "dist");
const REPO = "https://github.com/marcusbandit/banditshell";
const ORIGIN = "https://banditshell.marcusrosado.com";
const SOURCE = "docs/roadmap.md";
const DRAFTS = process.argv.includes("--drafts");

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
const roadmap = render(read(SOURCE), REPO);
const updated = git("log", "-1", "--format=%cs", "--", SOURCE) || new Date().toLocaleDateString("sv");
const commit = git("rev-parse", "--short", "HEAD");
const vision = roadmap.sections[0]?.blocks.find((block) => block.type === "paragraph")?.text ?? "";

const SCREEN = { width: 1920, height: 1080 };
const OPEN = "launcher";
const states = [
    { state: "rest", label: "At rest", keys: ["Esc"] },
    { state: "launcher", label: "Launcher", keys: ["Super", "Space"], x: 499, y: 349, alt: "The launcher open in the middle of the screen: a search field over a row of six apps" },
    { state: "sum", label: "A sum", typed: "12*7+3", x: 499, y: 349, alt: "The launcher answering 12*7+3 with 87" },
    { state: "session", label: "Session", keys: ["Super", "Esc"], x: 1696, y: 120, alt: "The session menu on the right edge: shut down, restart, log out, lock and sleep" },
    { state: "settings", label: "Settings", keys: ["Super", "I"], x: 290, y: 89, alt: "Settings open on its home page, with shortcuts to colour, wallpaper, widgets, the sidebar, notifications and the lock" },
];
const percent = (value, whole) => `${+((value / whole) * 100).toFixed(3)}%`;
const deck = states
    .map(({ state, label, keys, typed }) => {
        const on = state === OPEN;
        const hint = typed ? `<code class="typed">${escape(typed)}</code>` : `<kbd>${keys.map((key) => `<kbd>${key}</kbd>`).join("")}</kbd>`;
        return `<button type="button" role="radio" data-state="${state}" aria-checked="${on}" tabindex="${on ? 0 : -1}">${hint}${label}</button>`;
    })
    .join("\n");
const layerTags = states
    .filter((layer) => layer.alt)
    .map((layer) => {
        const file = `images/shell-${layer.state}.webp`;
        const size = imageSize(readFileSync(join(SITE, file)));
        if (!size) throw new Error(`${file} is not a readable webp`);
        const on = layer.state === OPEN;
        return (
            `<img class="layer${on ? " on" : ""}" data-layer="${layer.state}" src="/${file}" width="${size.width}" height="${size.height}" ` +
            `style="left:${percent(layer.x, SCREEN.width)};top:${percent(layer.y, SCREEN.height)};width:${percent(size.width, SCREEN.width)}" ` +
            `decoding="async"${on ? "" : ' fetchpriority="low"'} alt="${escape(layer.alt)}" aria-hidden="${!on}">`
        );
    })
    .join("\n");

const articles = posts(join(SITE, "blog"), SITE, REPO, { drafts: DRAFTS });

const hasBlog = articles.length > 0;

const page = (values) => {
    const merged = { roadmapCurrent: "", blogCurrent: "", robots: "", scripts: "", ...values };
    merged.canonical ??= `<link rel="canonical" href="${merged.url}">`;
    return fill(template("layout.html"), {
        repo: REPO,
        origin: ORIGIN,
        commit: commit ? `<a href="${REPO}/commit/${commit}"><code>${commit}</code></a>` : "an uncommitted tree",
        blogNav: hasBlog ? `<a href="/blog/"${merged.blogCurrent}>Blog</a>` : "",
        blogFoot: hasBlog ? '<a href="/blog/">Blog</a>' : "",
        ...merged,
    });
};

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
            repo: REPO,
            deck,
            layers: layerTags,
            vision: inline(vision, REPO),
        }),
        scripts: '<script src="/site.js" defer></script>',
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

const blogLead = "A post for every banditshell release, written for the people who use the shell.";

if (hasBlog) {
    mkdirSync(join(DIST, "blog"), { recursive: true });
    writeFileSync(
        join(DIST, "blog", "index.html"),
        page({
            title: "Blog | banditshell",
            description: blogLead,
            url: `${ORIGIN}/blog/`,
            page: "blog-page",
            blogCurrent: ' aria-current="page"',
            main: fill(template("blog.html"), { posts: articles.map(card).join("\n") }),
        }),
    );
}

for (const entry of articles) {
    mkdirSync(join(DIST, "blog", entry.slug), { recursive: true });
    writeFileSync(
        join(DIST, "blog", entry.slug, "index.html"),
        page({
            title: `${escape(entry.title)} | banditshell`,
            description: escape(entry.summary),
            url: `${ORIGIN}/blog/${entry.slug}/`,
            page: "blog-post",
            blogCurrent: ' aria-current="page"',
            robots: entry.draft ? '<meta name="robots" content="noindex">' : "",
            main: fill(template("post.html"), {
                heading: escape(entry.title),
                byline: `${entry.draft ? '<span class="chip">Draft</span> ' : ""}<time datetime="${entry.date}">${longDate(entry.date)}</time>${
                    entry.release
                        ? entry.draft
                            ? `, written for ${escape(entry.release)}`
                            : `, <a href="${REPO}/releases/tag/${escape(entry.release)}">release ${escape(entry.release)}</a>`
                        : ""
                }`,
                body: entry.html,
            }),
        }),
    );
}

writeFileSync(
    join(DIST, "404.html"),
    page({
        title: "Not here | banditshell",
        description,
        url: `${ORIGIN}/`,
        canonical: "",
        robots: '<meta name="robots" content="noindex">',
        page: "lost",
        main: `<section class="lost"><h1>Not here</h1><p>Nothing lives at this address. ${hasBlog ? 'The <a href="/">front page</a>, the <a href="/roadmap/">roadmap</a> and the <a href="/blog/">blog</a> do.' : 'The <a href="/">front page</a> and the <a href="/roadmap/">roadmap</a> do.'}</p></section>`,
    }),
);

for (const name of ["style.css", "site.js", "favicon.svg"]) copyFileSync(join(SITE, name), join(DIST, name));
cpSync(join(SITE, "fonts"), join(DIST, "fonts"), { recursive: true });
cpSync(join(SITE, "images"), join(DIST, "images"), { recursive: true });

console.log(`built ${DIST} from ${SOURCE}, updated ${updated}${commit ? ` at ${commit}` : ""}, ${articles.length} blog ${articles.length === 1 ? "post" : "posts"}${DRAFTS ? " with drafts" : ""}`);
