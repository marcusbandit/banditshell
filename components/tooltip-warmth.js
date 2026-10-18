.pragma library

let open = 0;
let cooledAt = 0;

function opened() {
    open += 1;
}

function closed() {
    open = Math.max(0, open - 1);
    cooledAt = Date.now();
}

function warm(grace) {
    return open > 0 || Date.now() - cooledAt < grace;
}
