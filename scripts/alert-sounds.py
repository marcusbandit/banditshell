#!/usr/bin/env python3
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
TARGET_RMS = 0.11
PEAK_CEILING = 0.85
EDGE_SECONDS = 0.02
LONGEST_SECONDS = 0.55

OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"

NOTE = {
    "B3": 246.94, "C4": 261.63, "E4": 329.63, "G4": 392.00, "A3": 220.00,
    "A4": 440.00, "C5": 523.25, "E5": 659.25, "G5": 783.99, "B5": 987.77,
    "C6": 1046.50, "F4": 349.23, "D5": 587.33, "A5": 880.00,
}


def blank(seconds):
    return [0.0] * int(RATE * seconds)


def add(track, start, voice):
    first = int(RATE * start)
    for i, value in enumerate(voice):
        if first + i < len(track):
            track[first + i] += value


def tone(frequency, seconds, partials, attack, decay):
    count = int(RATE * seconds)
    voice = []
    for i in range(count):
        t = i / RATE
        envelope = min(1.0, t / attack) * math.exp(-t * decay)
        value = 0.0
        for ratio, level, partial_decay in partials:
            value += level * math.sin(2 * math.pi * frequency * ratio * t) * math.exp(-t * partial_decay)
        voice.append(value * envelope)
    return voice


def knock(frequency, seconds, seed):
    rng = random.Random(seed)
    count = int(RATE * seconds)
    voice = []
    previous = 0.0
    for i in range(count):
        t = i / RATE
        body = math.sin(2 * math.pi * frequency * t) * math.exp(-t * 30)
        overtone = 0.25 * math.sin(2 * math.pi * frequency * 3.9 * t) * math.exp(-t * 70)
        previous = previous * 0.7 + rng.uniform(-1, 1) * 0.3
        tick = 0.18 * previous * math.exp(-t * 600)
        voice.append(min(1.0, t / 0.002) * (body + overtone + tick))
    return voice


SOFT = [(1.0, 1.0, 0.0), (2.0, 0.12, 6.0)]
BELL = [(1.0, 1.0, 0.0), (2.0, 0.5, 3.0), (3.01, 0.25, 6.0), (4.17, 0.15, 10.0), (5.4, 0.08, 14.0)]


def soft_notification():
    track = blank(0.5)
    add(track, 0.0, tone(NOTE["E5"], 0.3, SOFT, 0.012, 9))
    add(track, 0.13, tone(NOTE["B5"], 0.34, SOFT, 0.012, 9))
    return track


def soft_battery():
    track = blank(0.55)
    add(track, 0.0, tone(NOTE["A4"], 0.3, SOFT, 0.015, 8))
    add(track, 0.17, tone(NOTE["E4"], 0.36, SOFT, 0.015, 8))
    return track


def soft_error():
    track = blank(0.5)
    add(track, 0.0, tone(NOTE["E4"], 0.28, SOFT, 0.012, 10))
    add(track, 0.14, tone(NOTE["B3"], 0.34, SOFT, 0.012, 10))
    return track


def clear_notification():
    track = blank(0.55)
    add(track, 0.0, tone(NOTE["G5"], 0.4, BELL, 0.003, 7))
    add(track, 0.12, tone(NOTE["C6"], 0.43, BELL, 0.003, 7))
    return track


def clear_battery():
    track = blank(0.55)
    add(track, 0.0, tone(NOTE["C5"], 0.4, BELL, 0.003, 7))
    add(track, 0.17, tone(NOTE["G4"], 0.38, BELL, 0.003, 7))
    return track


def clear_error():
    track = blank(0.55)
    add(track, 0.0, tone(NOTE["F4"], 0.4, BELL, 0.003, 8))
    add(track, 0.15, tone(NOTE["C4"], 0.4, BELL, 0.003, 8))
    return track


def wood_notification():
    track = blank(0.4)
    add(track, 0.0, knock(NOTE["C5"], 0.25, 1))
    add(track, 0.1, knock(NOTE["E5"], 0.28, 2))
    return track


def wood_battery():
    track = blank(0.5)
    add(track, 0.0, knock(NOTE["G4"], 0.25, 3))
    add(track, 0.13, knock(NOTE["E4"], 0.25, 4))
    add(track, 0.26, knock(NOTE["C4"], 0.24, 5))
    return track


def wood_error():
    track = blank(0.4)
    add(track, 0.0, knock(NOTE["A3"], 0.25, 6))
    add(track, 0.13, knock(NOTE["A3"], 0.26, 7))
    return track


SETS = {
    "soft": {"notification": soft_notification, "battery": soft_battery, "error": soft_error},
    "clear": {"notification": clear_notification, "battery": clear_battery, "error": clear_error},
    "wood": {"notification": wood_notification, "battery": wood_battery, "error": wood_error},
}


def finish(track):
    edge = int(RATE * EDGE_SECONDS)
    for i in range(min(edge, len(track))):
        track[-1 - i] *= i / edge
    rms = math.sqrt(sum(x * x for x in track) / len(track))
    peak = max(abs(x) for x in track)
    gain = min(TARGET_RMS / rms, PEAK_CEILING / peak)
    return [x * gain for x in track]


def write(path, track):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(round(max(-1.0, min(1.0, x)) * 32767))) for x in track))


def main():
    for name, voices in SETS.items():
        for kind, make in voices.items():
            track = finish(make())
            seconds = len(track) / RATE
            if seconds > LONGEST_SECONDS:
                sys.exit(f"{name}/{kind} runs {seconds:.2f} s, longer than {LONGEST_SECONDS} s")
            write(OUTPUT / name / f"{kind}.wav", track)
            print(f"{name}/{kind}.wav  {seconds:.2f} s  peak {max(abs(x) for x in track):.2f}")


if __name__ == "__main__":
    main()
