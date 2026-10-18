.pragma library

const limit = 400;
let boxes = new Map();

function known(source) {
    return boxes.get(source) ?? null;
}

function remember(source, box) {
    if (boxes.size >= limit)
        boxes = new Map();
    boxes.set(source, box);
}
