"""Generate every sound effect in the game, from nothing but the standard library.

Same bargain as the art pipeline (pixel.py, generate_characters.py): no
dependencies, everything reproducible from source, and the *definition* of a
sound is the code rather than a binary somebody has to open an editor to change.
Retune a number here, re-run, and the game has a new sound.

    python assets/tools/generate_sfx.py

Writes 16-bit mono WAVs to assets/sfx/. Godot imports .wav as AudioStreamWAV
with no import settings needed.

Design rules, so the set stays coherent as it grows:
  * Short. The longest cue here is under half a second; this is a game about
    reading a crowded screen and a sound that outlives its event is noise.
  * One idea per cue. A pitch direction, or a texture, not both.
  * The stomp is the loudest thing in the game and everything else leaves it
    room, because the stomp is the only event that changes the score.
"""

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "sfx"
RATE = 22050

# Seeded so a re-run produces byte-identical files: noise that changed every
# build would make every rebuild a diff.
RNG = random.Random(0x57031)


def _frames(seconds: float) -> int:
    return int(RATE * seconds)


def silence(seconds: float) -> list[float]:
    return [0.0] * _frames(seconds)


def env(n: int, attack: float = 0.01, decay: float = 1.0, power: float = 2.0) -> list[float]:
    """Attack-then-decay shape. `power` above 1 makes the tail snappier."""
    a = max(1, int(n * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append(max(0.0, (1.0 - t) ** power) * decay)
    return out


def tone(seconds: float, f0: float, f1: float | None = None, wave_kind: str = "sine",
         attack: float = 0.01, power: float = 2.0) -> list[float]:
    """A pitch sweep from f0 to f1. Phase is integrated rather than computed per
    sample from a fixed frequency, or a sweep clicks every time the pitch moves.
    """
    n = _frames(seconds)
    f1 = f0 if f1 is None else f1
    shape = env(n, attack, power=power)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        freq = f0 + (f1 - f0) * t
        phase += 2.0 * math.pi * freq / RATE
        if wave_kind == "square":
            v = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif wave_kind == "saw":
            v = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
        elif wave_kind == "tri":
            v = 2.0 * abs(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0) - 1.0
        else:
            v = math.sin(phase)
        out.append(v * shape[i])
    return out


def noise(seconds: float, attack: float = 0.005, power: float = 3.0,
          lowpass: float = 1.0) -> list[float]:
    """White noise through a one-pole lowpass. `lowpass` of 1 is untouched;
    smaller values get duller, which is the difference between a crack and a thud.
    """
    n = _frames(seconds)
    shape = env(n, attack, power=power)
    out = []
    prev = 0.0
    for i in range(n):
        v = RNG.uniform(-1.0, 1.0)
        prev += (v - prev) * lowpass
        out.append(prev * shape[i])
    return out


def mix(*layers: list[float], gain: float = 1.0) -> list[float]:
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return [v * gain for v in out]


def save(name: str, samples: list[float], peak: float = 0.85) -> None:
    """Normalise to `peak` and write. Normalising per cue means the mix is set by
    the peak argument here rather than by whatever the synthesis happened to add
    up to, so relative loudness is a decision instead of an accident.
    """
    high = max((abs(v) for v in samples), default=1.0) or 1.0
    scale = peak / high
    data = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(v * scale * 32767))))
        for v in samples
    )
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)


def build() -> None:
    # --- movement -----------------------------------------------------------
    # Quiet, because these fire constantly. A jump you hear on every single hop
    # stops being information within a minute.
    save("jump", tone(0.10, 380, 620, "square", power=2.5), peak=0.34)
    save("land", mix(tone(0.09, 150, 90, "sine", power=3.0),
                     noise(0.06, power=4.0, lowpass=0.12)), peak=0.30)
    save("dash", mix(noise(0.13, power=2.0, lowpass=0.55),
                     tone(0.13, 700, 240, "saw", power=2.5)), peak=0.42)
    # The perfect-window chime: b-hop, perfect wall jump, and landing into a
    # slide all share it, because to the player they are one skill.
    save("perfect", mix(tone(0.16, 880, 1320, "sine", power=2.0),
                        tone(0.16, 1320, 1760, "sine", power=2.5)), peak=0.40)
    save("wall_jump", tone(0.11, 300, 520, "square", power=2.2), peak=0.36)
    save("pole_grab", mix(tone(0.14, 1200, 1000, "tri", power=3.0),
                          noise(0.03, power=5.0, lowpass=0.9)), peak=0.34)

    # --- the stomp ----------------------------------------------------------
    # The loudest cue in the game, and deliberately three layers: a crack you
    # hear first, a body-weight thump under it, and a short downward tail so it
    # reads as an impact rather than a hit.
    save("stomp", mix(noise(0.10, attack=0.001, power=2.5, lowpass=0.8),
                      tone(0.22, 220, 60, "sine", power=1.6),
                      tone(0.18, 90, 40, "square", power=2.0), gain=0.8), peak=1.0)
    save("bounce", tone(0.12, 260, 460, "tri", power=2.2), peak=0.40)
    save("stun", tone(0.26, 150, 110, "square", power=1.2), peak=0.42)

    # --- match events -------------------------------------------------------
    save("life_lost", tone(0.34, 520, 180, "tri", power=1.4), peak=0.55)
    save("hero_out", mix(tone(0.42, 440, 110, "saw", power=1.2),
                         tone(0.42, 220, 55, "sine", power=1.2)), peak=0.65)
    save("swap", tone(0.09, 520, 780, "sine", power=2.5), peak=0.34)
    save("ability", tone(0.12, 480, 700, "tri", power=2.2), peak=0.40)
    # Ultimates get a swell rather than a blip: two per round, and the other
    # team needs to hear one land.
    save("ultimate", mix(tone(0.40, 220, 660, "saw", power=1.2),
                         tone(0.40, 330, 990, "sine", power=1.4)), peak=0.80)

    # --- terrain ------------------------------------------------------------
    save("spring", tone(0.18, 240, 900, "tri", power=1.8), peak=0.50)
    save("portal", mix(tone(0.22, 700, 1400, "sine", power=1.6),
                       tone(0.22, 710, 1380, "sine", power=1.6)), peak=0.45)

    # --- round / match ------------------------------------------------------
    fanfare: list[float] = []
    for freq in (523.25, 659.25, 783.99):     # C-E-G
        fanfare += tone(0.11, freq, freq, "square", attack=0.02, power=1.5)
    save("round_won", fanfare, peak=0.70)
    win: list[float] = []
    for freq in (523.25, 659.25, 783.99, 1046.50):
        win += tone(0.13, freq, freq, "tri", attack=0.02, power=1.2)
    save("match_won", win, peak=0.80)

    print(f"Wrote {len(list(OUT.glob('*.wav')))} cues to {OUT}")


if __name__ == "__main__":
    build()
