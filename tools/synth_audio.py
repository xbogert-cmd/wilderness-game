"""Original synthesized audio for the game (no samples, no licences).

  python3 tools/synth_audio.py      # writes into assets/audio/, then normalise with ffmpeg

- music/storm_cue.wav: a sparse cue for building weather. A low bowed-string drone on D
  swells in, a fifth joins, a minor second rubs against it for unease, distant thunder rolls
  under it, and it all falls away. Deliberately quiet and slow: it should feel like the
  valley holding its breath, not a score.
- sfx/snort_1.wav, snort_2.wav: a mule deer's alarm snort (nasal noise burst through two
  resonances, with a second smaller puff).
- sfx/chop_1..4.wav: an axe biting wood: a sharp impact, a few damped wood resonances and
  a short splintery crunch, in a little forest space.
- sfx/tree_fall.wav: the trunk giving (stick-slip creak), branches rushing through the air,
  then the crash at 1.7 s, when the falling tree meets the ground (ChoppableTree.FALL_TIME).
Pure stdlib so it runs anywhere.
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def write(path: Path, samples: list[float]) -> None:
    peak = max(1e-9, max(abs(s) for s in samples))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.89 * 32767)) for s in samples))
    print("wrote", path, f"{len(samples) / SR:.1f}s")


def env(t: float, start: float, attack: float, hold_end: float, release: float) -> float:
    """Smooth swell in, hold, swell out (raised-cosine edges)."""
    if t < start or t > hold_end + release:
        return 0.0
    if t < start + attack:
        return 0.5 - 0.5 * math.cos(math.pi * (t - start) / attack)
    if t < hold_end:
        return 1.0
    return 0.5 + 0.5 * math.cos(math.pi * (t - hold_end) / release)


def bowed(freq: float, t: float, seed: float) -> float:
    """String-like tone: falling harmonics, slow vibrato, a detuned second voice."""
    vib = 1.0 + 0.003 * math.sin(2 * math.pi * 4.6 * t + seed) * min(1.0, t / 3.0)
    out = 0.0
    for detune in (0.9985, 1.0015):
        f = freq * vib * detune
        for n in range(1, 11):
            out += math.sin(2 * math.pi * f * n * t + seed * n) / (n ** 1.25)
    return out * 0.5


class OnePole:
    def __init__(self, cutoff: float):
        self.a = math.exp(-2 * math.pi * cutoff / SR)
        self.y = 0.0

    def __call__(self, x: float) -> float:
        self.y = (1 - self.a) * x + self.a * self.y
        return self.y


class Biquad:
    """Band-pass (constant skirt gain), RBJ cookbook."""
    def __init__(self, freq: float, q: float):
        w = 2 * math.pi * freq / SR
        alpha = math.sin(w) / (2 * q)
        a0 = 1 + alpha
        self.b = (alpha / a0, 0.0, -alpha / a0)
        self.a = (-2 * math.cos(w) / a0, (1 - alpha) / a0)
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x: float) -> float:
        y = self.b[0] * x + self.b[1] * self.x1 + self.b[2] * self.x2 - self.a[0] * self.y1 - self.a[1] * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def reverb(dry: list[float], mix: float = 0.35) -> list[float]:
    """Small Schroeder reverb: parallel combs into series all-passes. Adds valley space."""
    combs = [(int(SR * d), g) for d, g in ((0.0297, 0.78), (0.0371, 0.76), (0.0411, 0.74), (0.0437, 0.72))]
    bufs = [[0.0] * d for d, _ in combs]
    idx = [0] * len(combs)
    wet = []
    for x in dry:
        s = 0.0
        for k, (d, g) in enumerate(combs):
            y = bufs[k][idx[k]]
            bufs[k][idx[k]] = x + y * g
            idx[k] = (idx[k] + 1) % d
            s += y
        wet.append(s * 0.25)
    for d, g in ((int(SR * 0.005), 0.7), (int(SR * 0.0017), 0.7)):
        buf = [0.0] * d
        i = 0
        for n, x in enumerate(wet):
            y = buf[i]
            buf[i] = x + y * g
            wet[n] = y - x * g
            i = (i + 1) % d
    return [d * (1 - mix) + w * mix for d, w in zip(dry, wet)]


def storm_cue() -> list[float]:
    length = 16.0
    rng = random.Random(7)
    lp = OnePole(900.0)
    rumble = Biquad(75.0, 0.8) # audible thunder roll on small speakers, not sub-bass
    hp = OnePole(38.0) # high-pass by subtraction: strips sub-bass and DC
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        s += bowed(73.42, t, 0.3) * env(t, 0.0, 4.5, 10.0, 5.5) * 0.9            # D2 drone
        s += bowed(110.0, t, 1.1) * env(t, 3.5, 3.5, 10.5, 5.0) * 0.45           # A2 fifth
        s += bowed(155.56, t, 2.2) * env(t, 6.5, 3.0, 9.5, 4.0) * 0.22           # Eb3: the unease
        s += bowed(146.83, t, 0.7) * env(t, 10.0, 2.5, 11.5, 4.0) * 0.2          # D3: settles, not resolved
        s = lp(s)
        noise = rng.uniform(-1.0, 1.0)
        roll = 0.6 + 0.4 * math.sin(2 * math.pi * 0.7 * t) * math.sin(2 * math.pi * 0.23 * t)
        s += rumble(noise) * 1.6 * env(t, 7.0, 3.0, 11.0, 4.0) * roll  # distant thunder roll
        out.append(s - hp(s))
    return reverb(out, 0.3)


def snort(seed: int) -> list[float]:
    rng = random.Random(seed)
    length = 0.6
    nasal = Biquad(560.0 + seed * 40.0, 3.0)
    breath = Biquad(1450.0, 2.2)
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        e = math.exp(-t / 0.09) * min(1.0, t / 0.006)                              # sharp burst
        e += 0.45 * math.exp(-max(0.0, t - 0.2) / 0.07) * (1.0 if t > 0.2 else 0.0) * min(1.0, max(0.0, t - 0.2) / 0.008)
        n = rng.uniform(-1.0, 1.0)
        out.append((nasal(n) * 1.3 + breath(n) * 0.6) * e)
    return out


def chop(seed: int) -> list[float]:
    rng = random.Random(100 + seed)
    length = 0.45
    modes = [(f * rng.uniform(0.92, 1.08), d, a) for f, d, a in ((190.0, 0.07, 1.0), (520.0, 0.045, 0.7), (960.0, 0.03, 0.45), (1700.0, 0.018, 0.3))]
    crunch = Biquad(900.0 + seed * 60.0, 1.1)
    snap = Biquad(3200.0, 1.5)
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for f, d, a in modes:
            s += a * math.sin(2 * math.pi * f * t) * math.exp(-t / d)
        n = rng.uniform(-1.0, 1.0)
        s += crunch(n) * 2.2 * math.exp(-t / 0.05) * min(1.0, t / 0.002)
        s += snap(n) * 1.5 * math.exp(-t / 0.004)
        out.append(s * min(1.0, t / 0.0008))
    return reverb(out, 0.18)


def tree_fall() -> list[float]:
    rng = random.Random(55)
    length = 3.6
    creak_bp = Biquad(420.0, 4.0)
    creak_bp2 = Biquad(950.0, 5.0)
    rush = Biquad(1400.0, 0.8)
    thump = Biquad(70.0, 0.9)
    body = Biquad(260.0, 1.0)
    crackle = Biquad(2200.0, 1.2)
    hp = OnePole(35.0)
    out = []
    phase = 0.0
    impact = 1.7
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        # Creak: irregular stick-slip pulses, slowing and swelling as the hinge tears.
        rate = 38.0 - 14.0 * min(1.0, t / 1.4) + 6.0 * math.sin(t * 7.3)
        phase += rate / SR
        pulse = 1.0 if phase % 1.0 < 0.08 else 0.0
        ce = env(t, 0.0, 0.25, 1.1, 0.5)
        s += (creak_bp(pulse) * 3.0 + creak_bp2(pulse) * 1.5) * ce
        # Branches rushing through the air in the last half second of the fall.
        n = rng.uniform(-1.0, 1.0)
        s += rush(n) * 0.9 * env(t, 1.05, 0.5, impact, 0.08)
        # The crash: a heavy thump, the trunk's body, and branches snapping.
        if t >= impact:
            k = t - impact
            s += thump(n) * 9.0 * math.exp(-k / 0.28) * min(1.0, k / 0.004)
            s += body(n) * 3.0 * math.exp(-k / 0.18)
            if rng.random() < 0.004 * math.exp(-k / 0.5):
                s += rng.uniform(-6.0, 6.0)
            s += crackle(n) * 1.2 * math.exp(-k / 0.35)
        out.append(s - hp(s))
    return reverb(out, 0.32)


if __name__ == "__main__":
    write(OUT / "music" / "storm_cue.wav", storm_cue())
    write(OUT / "sfx" / "snort_1.wav", snort(1))
    write(OUT / "sfx" / "snort_2.wav", snort(2))
    for k in range(1, 5):
        write(OUT / "sfx" / f"chop_{k}.wav", chop(k))
    write(OUT / "sfx" / "tree_fall.wav", tree_fall())
