.pragma library

var FAMILY = [
    {
        width: 0.8,
        height: 0.8,
        turn: 0
    },
    {
        width: 1,
        height: 0.56,
        turn: 0
    },
    {
        width: 1,
        height: 0.56,
        turn: 45
    },
    {
        width: 0.56,
        height: 1,
        turn: 0
    },
    {
        width: 1,
        height: 0.56,
        turn: -45
    }
];

function shape(index) {
    var n = FAMILY.length;
    var i = ((Math.floor(index) % n) + n) % n;
    return FAMILY[i];
}
