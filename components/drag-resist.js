.pragma library

function resist(delta, commit, give) {
    var m = Math.abs(delta);
    var resisted = m < commit ? m * give : commit * give + (m - commit);
    return delta < 0 ? -resisted : resisted;
}
