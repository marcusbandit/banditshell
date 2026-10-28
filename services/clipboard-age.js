.pragma library

function age(recorded, now) {
    if (!(recorded > 0) || recorded > now + 60000)
        return "";

    var secs = Math.max(0, (now - recorded) / 1000);
    if (secs < 45)
        return "just now";

    var mins = secs / 60;
    if (mins < 60)
        return Math.round(mins) + "m ago";

    var hours = mins / 60;
    if (hours < 24)
        return Math.round(hours) + "h ago";

    var days = hours / 24;
    if (days < 7)
        return Math.round(days) === 1 ? "yesterday" : Math.round(days) + "d ago";

    var weeks = days / 7;
    return weeks < 5 ? Math.round(weeks) + "w ago" : Math.round(days / 30) + "mo ago";
}
