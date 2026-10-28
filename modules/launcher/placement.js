.pragma library

function searchAt(value) {
    return Math.max(0, Math.min(1, value));
}

function restTop(height, value, barOffset, margin, tallest) {
    var top = height * searchAt(value) - barOffset;
    return Math.max(margin, Math.min(height - margin - tallest, top));
}
