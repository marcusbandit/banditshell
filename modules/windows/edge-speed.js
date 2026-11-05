.pragma library

var STILL_AFTER = 100;

function settled(velocity, idle) {
    return idle > STILL_AFTER ? 0 : velocity;
}
