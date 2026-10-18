export default {
    async fetch(request, env) {
        if (originalScheme(request) === "http") {
            const url = new URL(request.url);
            url.protocol = "https:";
            return Response.redirect(url.toString(), 301);
        }
        return env.ASSETS.fetch(request);
    },
};

function originalScheme(request) {
    const forwarded = request.headers.get("x-forwarded-proto");
    if (forwarded) return forwarded.split(",")[0].trim().toLowerCase();

    const visitor = request.headers.get("cf-visitor");
    if (visitor) {
        try {
            const scheme = JSON.parse(visitor).scheme;
            if (typeof scheme === "string") return scheme.toLowerCase();
        } catch {}
    }

    return new URL(request.url).protocol.replace(":", "").toLowerCase();
}
