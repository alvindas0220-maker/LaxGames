"""Sintetiza los efectos de sonido de oficina en assets/audio/ (WAV de 16 bits).

Uso: python tools/make_office_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets/audio"


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def tone(freq, seconds, volume=0.4):
    return [volume * (1 if math.sin(2 * math.pi * freq * i / RATE) > 0 else -1) for i in range(int(seconds * RATE))]


def fade(samples, ms=4):
    n = min(int(RATE * ms / 1000), len(samples) // 2)
    out = list(samples)
    for i in range(n):
        out[i] *= i / n
        out[-1 - i] *= i / n
    return out


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def keyboard():
    rng = random.Random(7)
    out = []
    for _ in range(9):
        click = [rng.uniform(-0.5, 0.5) * (1 - i / 260) for i in range(260)]
        out += click + silence(rng.uniform(0.05, 0.13))
    return out


def phone():
    ring = []
    for i in range(int(0.5 * RATE)):
        t = i / RATE
        ring.append(0.2 * (math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)) * (1 if math.sin(2 * math.pi * 20 * t) > 0 else 0.3))
    return fade(ring) + silence(0.2) + fade(ring)


def stamp():
    rng = random.Random(3)
    return [(0.7 * math.sin(2 * math.pi * 90 * i / RATE) + rng.uniform(-0.25, 0.25)) * (1 - i / 3500) for i in range(3500)]


def alarm():
    out = []
    for _ in range(3):
        out += fade(tone(880, 0.22, 0.3)) + fade(tone(660, 0.22, 0.3))
    return out


def ambience():
    """Zumbido suave de equipos; empieza y acaba igual para poder repetirse."""
    length = RATE * 2
    return [0.1 * math.sin(2 * math.pi * 60 * i / RATE) + 0.05 * math.sin(2 * math.pi * 120 * i / RATE) for i in range(length)]


def theme():
    """Música ambiental suave en bucle: acordes tenues y arpegio lento."""
    chords = [(220.0, 261.6, 329.6), (174.6, 220.0, 261.6), (196.0, 246.9, 293.7), (164.8, 207.7, 246.9)]
    bar = int(RATE * 3)
    out = []
    for chord in chords:
        for i in range(bar):
            t = i / RATE
            pad = sum(math.sin(2 * math.pi * f * t) for f in chord) / 3
            note = chord[int(t * 2) % 3] * 2
            pluck = math.sin(2 * math.pi * note * t) * math.exp(-((t * 2) % 1) * 4)
            edge = min(1.0, i / 2000, (bar - i) / 2000)
            out.append((0.14 * pad + 0.09 * pluck) * edge)
    return out


if __name__ == "__main__":
    save("blip.wav", fade(tone(900, 0.02, 0.25), 2))
    save("keyboard.wav", keyboard())
    save("phone.wav", phone())
    save("stamp.wav", stamp())
    save("alarm.wav", alarm())
    save("office_ambience.wav", ambience())
    save("office_theme.wav", theme())
    print("sonidos generados:", len(list(OUT.glob("*.wav"))))
