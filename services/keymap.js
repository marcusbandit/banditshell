.pragma library

function keyboard(text) {
    var keyboards = [];
    try {
        var data = JSON.parse(text);
        keyboards = data && Array.isArray(data.keyboards) ? data.keyboards : [];
    } catch (e) {
        return null;
    }
    var main = keyboards.filter(function (k) {
        return k && k.main;
    })[0] || keyboards[0];
    if (!main)
        return null;
    var layouts = String(main.layout || "").split(",");
    var variants = String(main.variant || "").split(",");
    var pairs = [];
    layouts.forEach(function (l, i) {
        if (l.trim())
            pairs.push({
                layout: l.trim(),
                variant: (variants[i] || "").trim()
            });
    });
    return {
        name: String(main.active_keymap || ""),
        layouts: pairs.map(function (p) {
            return p.layout;
        }),
        variants: pairs.map(function (p) {
            return p.variant;
        }),
        index: main.active_layout_index || 0,
        capsLock: !!main.capsLock
    };
}

function shared(layouts, index) {
    var code = String(layouts[index] || "").toUpperCase();
    return !!code && layouts.filter(function (l) {
        return String(l).toUpperCase() === code;
    }).length > 1;
}

function codes(layouts, variants, joiner) {
    var join = joiner === undefined ? "-" : joiner;
    return layouts.map(function (layout, i) {
        var code = String(layout).toUpperCase();
        var variant = String(variants[i] || "");
        if (!variant || !shared(layouts, i))
            return code;
        var others = variants.filter(function (v, j) {
            return j !== i && v && String(layouts[j]).toUpperCase() === code;
        });
        for (var n = 1; n < variant.length; n++) {
            var tag = variant.slice(0, n);
            if (!others.some(function (o) {
                return o.slice(0, n) === tag;
            }))
                return code + join + tag.toUpperCase();
        }
        return code + join + variant.toUpperCase();
    });
}
