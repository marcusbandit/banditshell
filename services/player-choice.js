.pragma library

function shown(players, chosen, recent, rank) {
    if (chosen && players.includes(chosen))
        return chosen;
    const playing = players.filter(p => p.isPlaying && rank(p) > 1);
    if (playing.length > 0)
        return playing.includes(recent) ? recent : playing[0];
    return recent && players.includes(recent) && rank(recent) > 1 ? recent : null;
}
