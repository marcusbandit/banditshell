.pragma library

const DISTROS = [
    ["endeavour", 0xf322],
    ["garuda", 0xf337],
    ["manjaro", 0xf312],
    ["artix", 0xf31f],
    ["archcraft", 0xf345],
    ["arcolinux", 0xf346],
    ["arch", 0xf303],
    ["nixos", 0xf313],
    ["fedora", 0xf30a],
    ["nobara", 0xf380],
    ["kubuntu", 0xf333],
    ["pop!_os", 0xf32a],
    ["pop_os", 0xf32a],
    ["ubuntu", 0xf31b],
    ["mint", 0xf30e],
    ["debian", 0xf306],
    ["tumbleweed", 0xf37d],
    ["opensuse", 0xf314],
    ["gentoo", 0xf30d],
    ["void", 0xf32e],
    ["alpine", 0xf300],
    ["centos", 0xf304],
    ["rocky", 0xf32b],
    ["alma", 0xf31d],
    ["red hat", 0xf316],
    ["elementary", 0xf309],
    ["zorin", 0xf32f],
    ["kali", 0xf327],
    ["solus", 0xf32d],
    ["slackware", 0xf318]
];

function distroGlyph(name) {
    const lower = String(name || "").toLowerCase();
    const hit = DISTROS.find(d => lower.includes(d[0]));
    return String.fromCodePoint(hit ? hit[1] : 0xf31a);
}

function greeting(hour) {
    if (hour >= 5 && hour < 12)
        return "Good morning";
    if (hour >= 12 && hour < 18)
        return "Good afternoon";
    return "Good evening";
}

function uptimeText(seconds) {
    const minutes = Math.floor(Math.max(0, seconds) / 60);
    const days = Math.floor(minutes / 1440);
    const hours = Math.floor(minutes % 1440 / 60);
    const rest = minutes % 60;
    if (days > 0)
        return `Up ${days} d ${hours} h`;
    if (hours > 0)
        return `Up ${hours} h ${rest} min`;
    return `Up ${rest} min`;
}
