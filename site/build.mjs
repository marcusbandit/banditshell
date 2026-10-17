import { execFileSync } from "node:child_process";
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { escape, render } from "./roadmap.mjs";

const SITE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(SITE, "..");
const DIST = join(SITE, "dist");
const REPO = "https://github.com/marcusbandit/banditshell";
const SOURCE = "docs/roadmap.md";

const git = (...args) => {
    try {
        return execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();
    } catch {
        return "";
    }
};

const read = (path) => readFileSync(join(ROOT, path), "utf8");
const fill = (template, values) => template.replace(/\{\{(\w+)\}\}/g, (_, key) => values[key] ?? "");

const roadmap = render(read(SOURCE), REPO);
const updated = git("log", "-1", "--format=%cs", "--", SOURCE) || new Date().toLocaleDateString("sv");
const commit = git("rev-parse", "--short", "HEAD");
const lead = roadmap.sections[0]?.html.match(/<p>(.*?)<\/p>/)?.[1].replace(/<[^>]+>/g, "") ?? "";

const nav = roadmap.sections
    .map((section) => `<a href="#${section.id}">${escape(section.label)}</a>`)
    .join("\n");

const hero = `<figure class="hero">
<picture>
<source media="(prefers-reduced-motion: reduce)" srcset="hero-still.webp">
<img src="hero.webp" width="1280" height="720" decoding="async" alt="The shell at rest, then the island, the launcher and a panel coming out of the frame and going back">
</picture>
</figure>`;

const sections = roadmap.sections.map((section, n) => (n === 0 ? section.html + "\n" + hero : section.html)).join("\n");

rmSync(DIST, { recursive: true, force: true });
mkdirSync(DIST, { recursive: true });

writeFileSync(
    join(DIST, "index.html"),
    fill(readFileSync(join(SITE, "page.html"), "utf8"), {
        title: escape(roadmap.title),
        description: escape(lead),
        css: readFileSync(join(SITE, "style.css"), "utf8").trim(),
        intro: roadmap.intro,
        nav,
        sections,
        updated,
        commit: commit ? `<a href="${REPO}/commit/${commit}"><code>${commit}</code></a>` : "",
        source: `${REPO}/blob/main/${SOURCE}`,
        repo: REPO,
    }),
);

const wordmark = read("docs/readme/wordmark.svg");
writeFileSync(join(DIST, "wordmark.svg"), wordmark);
writeFileSync(join(DIST, "wordmark-still.svg"), wordmark.replace(/<animate(Transform)?\b[^>]*\/>/g, ""));

const word = wordmark.slice(wordmark.indexOf("<clipPath"), wordmark.indexOf("</clipPath>"));
const letter = [...word.matchAll(/<rect x="(\d+)" y="(\d+)" width="11" height="11"\/>/g)]
    .filter(([, x]) => Number(x) < 110)
    .map(([rect]) => rect)
    .join("");
writeFileSync(
    join(DIST, "favicon.svg"),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="31.5 84.5 100 100"><rect x="31.5" y="84.5" width="100" height="100" rx="22" fill="#0F1114"/><g fill="#B8DCF0">${letter}</g></svg>\n`,
);

copyFileSync(join(ROOT, "docs/readme/hero.webp"), join(DIST, "hero.webp"));
copyFileSync(join(SITE, "hero-still.webp"), join(DIST, "hero-still.webp"));

console.log(`built ${DIST} from ${SOURCE}, updated ${updated}${commit ? ` at ${commit}` : ""}`);
