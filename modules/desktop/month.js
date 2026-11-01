.pragma library

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function cells(year, month) {
    const first = new Date(year, month, 1);
    const lead = (first.getDay() + 6) % 7;
    const out = [];
    for (let i = 0; i < 42; i++) {
        const at = new Date(year, month, 1 - lead + i);
        out.push({
            day: at.getDate(),
            inMonth: at.getMonth() === month,
            key: at.getFullYear() * 10000 + at.getMonth() * 100 + at.getDate()
        });
    }
    return out;
}

function keyOf(date) {
    return date.getFullYear() * 10000 + date.getMonth() * 100 + date.getDate();
}

function title(year, month) {
    return `${MONTHS[month]} ${year}`;
}

function shifted(year, month, by) {
    const at = new Date(year, month + by, 1);
    return { year: at.getFullYear(), month: at.getMonth() };
}
