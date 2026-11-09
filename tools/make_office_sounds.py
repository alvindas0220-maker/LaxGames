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


# Tema original de "novela de oficina". Nota MIDI y duración en corcheas; -1 es silencio.
# Melodía propia: toma el ambiente de los dramas de oficina, no el tema de ninguna serie.
SUSPENSE = [
    [(69, 1), (-1, 1), (69, 1), (72, 1), (71, 3), (-1, 1)], [(68, 1), (-1, 1), (68, 1), (71, 1), (69, 3), (-1, 1)],
    [(65, 1), (-1, 1), (65, 1), (69, 1), (68, 3), (-1, 1)], [(64, 2), (68, 2), (71, 2), (76, 2)],
]
VERSE = [
    [(-1, 2), (69, 1), (71, 1), (72, 3), (71, 1)], [(69, 2), (65, 2), (69, 3), (72, 1)],
    [(74, 3), (72, 1), (71, 2), (67, 2)], [(72, 6), (-1, 2)],
    [(-1, 1), (72, 1), (74, 1), (76, 1), (77, 3), (76, 1)], [(74, 2), (72, 2), (74, 2), (77, 2)],
]
CHORUS = [
    [(79, 3), (76, 1), (72, 2), (76, 2)], [(74, 3), (79, 1), (83, 2), (79, 2)],
    [(81, 3), (79, 1), (76, 2), (72, 2)], [(71, 4), (67, 2), (71, 2)],
    [(77, 3), (76, 1), (74, 2), (72, 2)], [(76, 3), (74, 1), (72, 2), (67, 2)],
]
BRIDGE = [
    [(77, 4), (76, 2), (74, 2)], [(76, 6), (-1, 2)], [(74, 4), (72, 2), (71, 2)], [(72, 6), (-1, 2)],
    [(70, 4), (69, 2), (70, 2)], [(69, 3), (68, 1), (69, 4)], [(76, 2), (80, 2), (83, 2), (88, 2)], [(88, 6), (-1, 2)],
]
MELODY = (
    SUSPENSE
    + VERSE + [[(76, 3), (74, 1), (71, 2), (68, 2)], [(69, 6), (-1, 2)]]
    + VERSE + [[(76, 2), (80, 2), (83, 3), (80, 1)], [(81, 6), (-1, 2)]]
    + CHORUS + [[(69, 2), (72, 2), (77, 2), (81, 2)], [(80, 6), (-1, 2)]]
    + BRIDGE
    + CHORUS + [[(77, 2), (76, 2), (74, 2), (71, 2)], [(68, 4), (71, 2), (74, 2)]]
)
AM, DM, G, C, F, E7, EM, BB, GS = (45, (0, 3, 7)), (38, (0, 3, 7)), (43, (0, 4, 7)), (36, (0, 4, 7)), (41, (0, 4, 7)), (40, (0, 4, 10)), (40, (0, 3, 7)), (46, (0, 4, 7)), (44, (0, 3, 6))
SUSPENSE_CHORDS = [AM, GS, F, E7]
VERSE_CHORDS = [AM, DM, G, C, F, DM, E7, AM]
CHORUS_CHORDS = [C, G, AM, EM, F, C, DM, E7]
BRIDGE_CHORDS = [DM, AM, DM, AM, BB, F, E7, E7]
HARMONY = SUSPENSE_CHORDS + VERSE_CHORDS * 2 + CHORUS_CHORDS + BRIDGE_CHORDS + CHORUS_CHORDS
# Bajo de bolero: 3+3+2 corcheas.
BASS_STEPS = [(0, 0), (3, 7), (6, 12)]
# Clave de 3-2 en corcheas de dos compases.
CLAVE = [0, 3, 6, 10, 12]


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def chiptune():
    """Bucle en La menor: entrada de suspenso, estrofa, estribillo, puente tenso y vuelta.

    Solista de dos pulsos desafinados con vibrato y eco, bajo de bolero, metales a
    contratiempo, arpegio tenue, clave y percusión con conga aguda.
    """
    assert len(MELODY) == len(HARMONY)
    bpm = 116
    eighth = int(RATE * 60 / bpm / 2)
    total = eighth * 8 * len(MELODY)
    out = [0.0] * total
    rng = random.Random(11)
    suspense_bars = len(SUSPENSE)
    bridge_start = suspense_bars + 16 + 8
    bridge_end = bridge_start + 8

    def voice(start, length, note, volume, duty, vibrato=False, target=out, detune=1.0, sweep=0.0):
        freq = midi_hz(note) * detune
        phase = 0.0
        for i in range(length):
            wobble = 1 + 0.007 * math.sin(2 * math.pi * 5.2 * i / RATE) if vibrato and i > 2600 else 1
            phase = (phase + freq * wobble / RATE) % 1.0
            width = duty + sweep * math.sin(2 * math.pi * 0.9 * i / RATE)
            sample = 4 * abs(phase - 0.5) - 1 if duty == 0 else (1.0 if phase < width else -1.0)
            attack = min(1.0, i / 90)
            decay = 0.72 + 0.28 * max(0.0, 1 - i / 7000)
            release = min(1.0, (length - i) / 420)
            target[(start + i) % total] += sample * volume * attack * decay * release

    def noise(start, length, volume):
        for i in range(length):
            out[(start + i) % total] += rng.uniform(-1, 1) * volume * (1 - i / length)

    def conga(start, note, volume):
        length = 2600
        phase = 0.0
        freq = midi_hz(note)
        for i in range(length):
            phase = (phase + freq * (1 + 0.5 * (1 - i / length) ** 6) / RATE) % 1.0
            out[(start + i) % total] += math.sin(2 * math.pi * phase) * volume * (1 - i / length) ** 2

    lead = [0.0] * total
    for bar, notes in enumerate(MELODY):
        tense = bar < suspense_bars or bridge_start <= bar < bridge_end
        position = bar * 8 * eighth
        for note, eighths in notes:
            length = eighths * eighth
            if note >= 0:
                voice(position, int(length * 0.95), note, 0.09, 0.25, True, lead, sweep=0.06)
                voice(position, int(length * 0.95), note, 0.065, 0.125, True, lead, 1.004)
            position += length
        root, chord = HARMONY[bar]
        start = bar * 8 * eighth
        if tense:
            # Pedal nervioso de suspenso: el bajo repite corcheas.
            for step in range(8):
                voice(start + step * eighth, int(eighth * 0.7), root - 12 if root > 40 else root, 0.2, 0)
            for step in (0, 4):
                for interval in chord:
                    voice(start + step * eighth, int(eighth * 3.2), root + 24 + interval, 0.03, 0.5, sweep=0.1)
        else:
            for step, offset in BASS_STEPS:
                voice(start + step * eighth, int(eighth * 2.4), root + offset - 12 if root > 40 else root + offset, 0.22, 0)
            # Metales a contratiempo, el golpe dramático del tema.
            for step in (2, 5, 7):
                for interval in chord:
                    voice(start + step * eighth, int(eighth * 0.8), root + 24 + interval, 0.033, 0.5, sweep=0.08)
            for step in range(8):
                voice(start + step * eighth, int(eighth * 0.5), root + 36 + chord[step % 3], 0.024, 0.125)
        for step in range(8):
            noise(start + step * eighth, 240, 0.025)
        for hit in CLAVE:
            if hit // 8 == bar % 2:
                voice(start + (hit % 8) * eighth, 480, 88, 0.045, 0.5)
        if not tense:
            conga(start + 3 * eighth, 64, 0.08)
            conga(start + 7 * eighth, 69, 0.07)
        noise(start, 900, 0.085)
        noise(start + 4 * eighth, 900, 0.065)
    # Eco del solista: da aire nostálgico y envuelve el final hacia el principio.
    delay = eighth * 3
    for i, sample in enumerate(lead):
        out[i] += sample + lead[(i - delay) % total] * 0.34 + lead[(i - delay * 2) % total] * 0.14
    peak = max(abs(v) for v in out)
    return [v / peak * 0.74 for v in out]


def stinger():
    """Golpe dramático de telenovela para las revelaciones."""
    seconds = 1.5
    size = int(RATE * seconds)
    out = [0.0] * size
    for note, weight in ((33, 0.3), (57, 0.16), (60, 0.16), (63, 0.16), (66, 0.16), (81, 0.08)):
        freq = midi_hz(note)
        for i in range(size):
            t = i / RATE
            bend = 1 - 0.03 * min(t, 1.0)
            wave_value = 1.0 if (freq * bend * t) % 1.0 < 0.4 else -1.0
            out[i] += wave_value * weight * math.exp(-2.2 * t)
    return fade(out, 6)


if __name__ == "__main__":
    save("blip.wav", fade(tone(900, 0.02, 0.25), 2))
    save("keyboard.wav", keyboard())
    save("phone.wav", phone())
    save("stamp.wav", stamp())
    save("alarm.wav", alarm())
    save("office_ambience.wav", ambience())
    save("office_theme.wav", theme())
    save("office_chiptune.wav", chiptune())
    save("stinger.wav", stinger())
    print("sonidos generados:", len(list(OUT.glob("*.wav"))))
