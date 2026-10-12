function band(strength, steps) {
    const percent = Math.round((strength || 0) * 100);
    return Math.ceil(percent / (100 / steps));
}

function collapse(networks) {
    const best = new Map();
    for (const network of networks) {
        if (!network || !network.name)
            continue;
        const held = best.get(network.name);
        if (!held || (network.connected && !held.connected) || (!held.connected && network.signalStrength > held.signalStrength))
            best.set(network.name, network);
    }
    return Array.from(best.values());
}

function compareNames(a, b) {
    return a.localeCompare(b) || (a < b ? -1 : a > b ? 1 : 0);
}

function arrange(networks, steps) {
    return collapse(networks).map(network => ({
        network: network,
        band: band(network.signalStrength, steps)
    })).sort((a, b) => {
        if (!!a.network.connected !== !!b.network.connected)
            return a.network.connected ? -1 : 1;
        if (!!a.network.known !== !!b.network.known)
            return a.network.known ? -1 : 1;
        if (a.band !== b.band)
            return b.band - a.band;
        return compareNames(a.network.name, b.network.name);
    }).map(entry => entry.network);
}

function same(previous, next) {
    if (!previous || previous.length !== next.length)
        return false;
    for (let i = 0; i < next.length; i++) {
        if (previous[i] !== next[i])
            return false;
    }
    return true;
}

function settle(previous, next) {
    return same(previous, next) ? previous : next;
}

function escapeSecret(secret) {
    let escaped = "";
    for (let i = 0; i < secret.length; i++) {
        const character = secret[i];
        const code = secret.charCodeAt(i);
        if (character === "\\")
            escaped += "\\\\";
        else if (code <= 0x20 || code === 0x7f)
            escaped += "\\" + ("00" + code.toString(8)).slice(-3);
        else
            escaped += character;
    }
    return escaped;
}

function secretLine(property, secret) {
    return `${property}:${escapeSecret(String(secret ?? ""))}\n`;
}
