.pragma library

// A sine wave as a polyline, fixed at its START.
//
// This is the played part of the media scrubber (modules/media/Scrubber.qml).
// The phase is pinned at x = 0, the left edge of the bar, and `length` only
// says how much of the wave is showing: as the pip moves right it uncovers
// more of the same wave, and nothing already drawn moves. The first cut pinned
// the phase at the pip instead, so the whole pattern slid with the pip as it
// went, and a drag read as the wave being pushed rather than revealed.
// Advancing `phase` moves the crests toward the pip, which is the travelling
// motion.
//
// Pure maths, no QML, so tests/wave.test.js can reach it the way base64's and
// vt's can.

// Points along the wave, as [x, y] pairs with y about the centre line, every
// `step` px from 0 to exactly `length`. The last point always lands on the end
// even when the length is not a multiple of the step, because that end is
// where the pip is and a polyline that stops short of it leaves a gap that
// grows and shrinks as the bar fills.
function points(length, amplitude, wavelength, phase, step) {
    if (!(length > 0))
        return [];
    // A wave with no length is a flat line, and a step of nothing is a loop
    // that never ends; both are answered with the smallest sensible thing.
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
