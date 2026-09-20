#!/usr/bin/env python3
"""Generate original alarm tones from oscillators; no sampled audio is used."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100
TONES = {
    "geowake_pulse.wav": [(880, .28, .16), (1100, .28, .16)] * 3,
    "geowake_chime.wav": [(660, .40, .12), (880, .40, .12), (1320, .55, .25)] * 2,
    "geowake_signal.wav": [(740, .18, .10), (740, .18, .10), (1040, .35, .30)] * 3,
}


def generate():
    directory = ROOT / "assets" / "ringtones"
    directory.mkdir(parents=True, exist_ok=True)
    for name, notes in TONES.items():
        samples = bytearray()
        for hz, duration, rest in notes:
            count = round(duration * RATE)
            for i in range(count):
                t = i / RATE
                envelope = min(1.0, t / .012, (count - 1 - i) / (RATE * .06))
                signal = math.sin(2 * math.pi * hz * t)
                signal += .18 * math.sin(2 * math.pi * hz * 2 * t)
                samples.extend(struct.pack("<h", round(14000 * envelope * signal)))
            samples.extend(b"\0\0" * round(rest * RATE))
        with wave.open(str(directory / name), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(samples)


if __name__ == "__main__":
    generate()
