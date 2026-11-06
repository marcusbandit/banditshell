.pragma library

function rows(carry, pixelY, angleY, cellHeight) {
    var notches = pixelY !== 0 ? pixelY / cellHeight : angleY / 40;
    var total = carry + notches;
    var step = total < 0 ? Math.ceil(total) : Math.floor(total);
    return {step: step, carry: total - step};
}
