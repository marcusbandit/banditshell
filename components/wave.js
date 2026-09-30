.pragma library

function points(length, amplitude, wavelength, phase, step) {
    if (!(length > 0))
        return [];

    const wl = wavelength > 0 ? wavelength : 1;
    const dx = step > 0 ? step : 1;
    const count = Math.ceil(length / dx);
    const out = [];
    for (let i = 0; i <= count; i++) {
        const x = Math.min(length, i * dx);
        out.push([x, amplitude * Math.sin(2 * Math.PI * x / wl - phase)]);
    }
    return out;
}
