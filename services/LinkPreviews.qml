pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "link-facts.js" as Links

Singleton {
    id: root

    readonly property string dir: `${Config.cacheDir}/links`
    readonly property string agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
    readonly property int most: 3
    readonly property var skipped: ["Video file", "Image file", "PDF", "Download", "Reddit video"]

    property var pages: ({})
    property var waiting: []
    property int busy: 0
    property bool loaded: false
    property var asked: ({})

    function pageOf(url: string): var {
        return root.pages[String(url ?? "").trim()] ?? null;
    }

    function look(url: string): void {
        const u = String(url ?? "").trim();
        const had = root.pages[u];
        if (!u || root.asked[u] || had && (had.title || Date.now() - had.at < 86400000) || !Links.fetchable(u))
            return;
        if (root.skipped.includes(Links.describe(u)?.kind ?? ""))
            return;
        root.asked[u] = true;
        root.waiting = root.waiting.concat([u]);
        if (root.loaded)
            root.pump();
    }

    function start(): void {
        root.loaded = true;
        root.waiting = root.waiting.filter(u => !root.pages[u]?.title);
        root.pump();
    }

    function pump(): void {
        while (root.busy < root.most && root.waiting.length) {
            const url = root.waiting[0];
            root.waiting = root.waiting.slice(1);
            root.busy += 1;
            const key = Links.keyOf(url);
            const embed = Links.oembedOf(url);
            fetcher.createObject(root, {
                url: url,
                key: key,
                command: ["sh", "-c", 'mkdir -p "$2" && curl -sL --compressed --max-time 8 --max-filesize 3000000 -A "$3" -H "Accept-Language: en" -- "$1"', "sh", embed || url, root.dir, root.agent],
                running: true
            });
        }
    }

    function read(url: string, key: string, html: string): void {
        const got = Links.oembedOf(url) ? Links.readEmbed(html) ?? Links.readPage("", url) : Links.readPage(html, url);
        const icon = `${root.dir}/${key}-icon`;
        const image = got.image ? `${root.dir}/${key}-image` : "";
        downloader.createObject(root, {
            url: url,
            page: {
                title: got.title,
                description: got.description,
                icon: icon,
                image: image,
                at: Date.now()
            },
            command: ["sh", "-c", 'curl -sfL --max-time 8 --max-filesize 2000000 -A "$5" -o "$2" -- "$1"; [ -z "$3" ] || curl -sfL --max-time 8 --max-filesize 6000000 -A "$5" -o "$4" -- "$3"; true', "sh", got.icon, icon, got.image, image, root.agent],
            running: true
        });
    }

    function keep(url: string, page: var): void {
        root.pages = Object.assign({}, root.pages, {
            [url]: page
        });
        root.busy = Math.max(0, root.busy - 1);
        save.restart();
        root.pump();
    }

    Component {
        id: fetcher

        Process {
            id: fetch

            property string url: ""
            property string key: ""

            stdout: StdioCollector {
                onStreamFinished: root.read(fetch.url, fetch.key, text)
            }

            onRunningChanged: if (!fetch.running)
                fetch.destroy()
        }
    }

    Component {
        id: downloader

        Process {
            id: download

            property string url: ""
            property var page: null

            onExited: root.keep(download.url, download.page)

            onRunningChanged: if (!download.running)
                download.destroy()
        }
    }

    Timer {
        id: save

        interval: 1500
        onTriggered: store.setText(JSON.stringify(root.pages))
    }

    FileView {
        id: store

        path: `${root.dir}/index.json`
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pages = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (e) {
                root.pages = {};
            }
            root.start();
        }
        onLoadFailed: root.start()
    }
}
