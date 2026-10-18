const ENTITIES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };

export const escape = (text) => text.replace(/[&<>"]/g, (c) => ENTITIES[c]);

export const slug = (text) =>
    text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

export function inline(text, repo) {
    const code = [];
    return escape(text)
        .replace(/`([^`]+)`/g, (_, body) => `\u0000${code.push(`<code>${body}</code>`) - 1}\u0000`)
        .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
        .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>')
        .replace(/(^|[\s(])#(\d+)\b/g, `$1<a href="${repo}/pull/$2">#$2</a>`)
        .replace(/\u0000(\d+)\u0000/g, (_, i) => code[i]);
}

const cells = (line) => line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim());

const patterns = {
    heading: /^(#{1,3})\s+(.*)$/,
    bullet: /^[-*]\s+(.*)$/,
    numbered: /^\d+\.\s+(.*)$/,
    rule: /^-{3,}\s*$/,
    row: /^\|/,
};

const startsBlock = (line) =>
    line.trim() === "" || Object.values(patterns).some((pattern) => pattern.test(line));

export function blocks(markdown) {
    const lines = markdown.replace(/\r/g, "").split("\n");
    const out = [];
    let i = 0;
    while (i < lines.length) {
        const line = lines[i];
        if (line.trim() === "") {
            i++;
        } else if (patterns.heading.test(line)) {
            const [, marks, text] = line.match(patterns.heading);
            out.push({ type: "heading", level: marks.length, text: text.trim() });
            i++;
        } else if (patterns.rule.test(line)) {
            out.push({ type: "rule" });
            i++;
        } else if (patterns.row.test(line)) {
            const rows = [];
            while (i < lines.length && patterns.row.test(lines[i])) rows.push(cells(lines[i++]));
            const [head, , ...body] = rows;
            out.push({ type: "table", head, body });
        } else if (patterns.bullet.test(line) || patterns.numbered.test(line)) {
            const ordered = patterns.numbered.test(line);
            const marker = ordered ? patterns.numbered : patterns.bullet;
            const items = [];
            while (i < lines.length && marker.test(lines[i])) {
                const parts = [lines[i++].match(marker)[1]];
                while (i < lines.length && /^\s+\S/.test(lines[i])) parts.push(lines[i++].trim());
                items.push(parts.join(" "));
            }
            out.push({ type: "list", ordered, items });
        } else {
            const parts = [];
            while (i < lines.length && !(parts.length && startsBlock(lines[i]))) parts.push(lines[i++].trim());
            out.push({ type: "paragraph", text: parts.join(" ") });
        }
    }
    return out;
}

function html(block, repo) {
    const text = (t) => inline(t, repo);
    switch (block.type) {
        case "heading":
            return `<h${block.level}>${text(block.text)}</h${block.level}>`;
        case "rule":
            return "<hr>";
        case "paragraph":
            return `<p>${text(block.text)}</p>`;
        case "list": {
            const tag = block.ordered ? "ol" : "ul";
            return `<${tag}>${block.items.map((item) => `<li>${text(item)}</li>`).join("")}</${tag}>`;
        }
        case "table": {
            const head = block.head.map((cell) => `<th scope="col">${text(cell)}</th>`).join("");
            const body = block.body
                .map((row) => `<tr>${row.map((cell, n) => `<td data-label="${escape(block.head[n] ?? "")}">${text(cell)}</td>`).join("")}</tr>`)
                .join("");
            return `<div class="table"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
        }
    }
}

export function render(markdown, repo) {
    let title = "";
    const intro = [];
    const sections = [];
    for (const block of blocks(markdown)) {
        if (block.type === "heading" && block.level === 1 && !title) {
            title = block.text;
        } else if (block.type === "heading" && block.level === 2) {
            const label = block.text.split(/:| \(/)[0];
            sections.push({ id: slug(label), label, heading: block.text, body: [], blocks: [] });
        } else {
            sections.at(-1)?.blocks.push(block);
            (sections.at(-1)?.body ?? intro).push(html(block, repo));
        }
    }
    return {
        title,
        intro: intro.join("\n"),
        sections: sections.map((section) => ({
            ...section,
            html: `<section id="${section.id}"><h2>${inline(section.heading, repo)}</h2>\n${section.body.join("\n")}</section>`,
        })),
    };
}
