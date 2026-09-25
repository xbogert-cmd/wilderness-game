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
- sfx/bleat_1.wav, bleat_2.wav: a doe bleat for the deer call (a nasal, falling tone with
  a little tremble), what curious deer come to investigate.
- sfx/tree_fall.wav: the trunk giving (stick-slip creak), branches rushing through the air,
  then the crash at 1.7 s, when the falling tree meets the ground (ChoppableTree.FALL_TIME).
- sfx/howl_1.wav, howl_2.wav: a wolf howl: a breathy rise into a long wavering tone that
  sags away at the end, in a lot of valley space (the second has another wolf joining).
- sfx/growl.wav: a low, rough rumble with a rattling flutter, for a wolf closing in.
- sfx/roar.wav: a black bear's warning: two hard huffs, a jaw pop, then a short bellow.
- sfx/caw_1.wav, caw_2.wav: a raven's croak, harsh and nasal, over something dead.
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


def bleat(seed: int) -> list[float]:
    rng = random.Random(200 + seed)
    length = 0.7
    f0, f1 = 470.0 + seed * 25.0, 360.0
    nose = Biquad(760.0, 3.0)
    mouth = Biquad(1650.0, 4.0)
    out = []
    phase = 0.0
    for i in range(int(length * SR)):
        t = i / SR
        f = f0 + (f1 - f0) * min(1.0, t / 0.55) + 6.0 * math.sin(2 * math.pi * 7.5 * t)
        phase += f / SR
        saw = 2.0 * (phase % 1.0) - 1.0 + rng.uniform(-0.05, 0.05)  # reedy source with breath
        e = min(1.0, t / 0.03) * math.exp(-max(0.0, t - 0.35) / 0.12)
        out.append((nose(saw) * 1.4 + mouth(saw) * 0.6) * e)
    return reverb(out, 0.25)


def howl(seed: int) -> list[float]:
    rng = random.Random(300 + seed)
    length = 4.2
    out = []
    phases = [0.0, 0.0]
    voices = [(0.0, 1.0)] + ([(1.3, 1.335)] if seed == 2 else [])  # (start, pitch ratio)
    formant = Biquad(700.0, 1.2)
    formant2 = Biquad(1250.0, 2.0)
    lp = OnePole(2500.0)
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for k, (start, ratio) in enumerate(voices):
            u = t - start
            if u < 0.0 or u > 3.0:
                continue
            rise = min(1.0, u / 0.7)
            f = (330.0 + 230.0 * (1 - (1 - rise) ** 2)) * ratio  # breaks upward into the note
            f -= 110.0 * max(0.0, u - 2.2) / 0.8 * ratio  # and sags away at the end
            f *= 1.0 + 0.012 * math.sin(2 * math.pi * 5.2 * u + seed) * min(1.0, u / 1.0)
            phases[k] += f / SR
            ph = 2 * math.pi * phases[k]
            tone = math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph)
            e = env(u, 0.0, 0.25, 2.3, 0.7) * (0.8 if k else 1.0)
            s += (tone + rng.uniform(-0.25, 0.25) * (1.0 - rise * 0.6)) * e
        out.append(lp(formant(s) * 1.6 + formant2(s) * 0.5 + s * 0.35))
    return reverb(reverb(out, 0.4), 0.3)


def growl() -> list[float]:
    rng = random.Random(41)
    length = 1.4
    body = Biquad(380.0, 1.4)
    chest = OnePole(900.0)
    out = []
    phase = 0.0
    for i in range(int(length * SR)):
        t = i / SR
        f = 92.0 + 10.0 * math.sin(2 * math.pi * 0.9 * t)
        phase += f / SR
        pulse = max(0.0, math.sin(2 * math.pi * phase)) ** 6  # glottal pulses
        flutter = 0.55 + 0.45 * math.sin(2 * math.pi * 23.0 * t + rng.uniform(-0.3, 0.3))
        x = (pulse * 2.0 + rng.uniform(-0.5, 0.5)) * flutter
        e = env(t, 0.0, 0.15, 1.0, 0.35)
        out.append((body(x) * 1.2 + chest(x) * 0.8) * e)
    return reverb(out, 0.2)


def roar() -> list[float]:
    rng = random.Random(57)
    length = 2.0
    huff = Biquad(320.0, 1.1)
    bellow = Biquad(260.0, 1.3)
    low = OnePole(700.0)
    out = []
    phase = 0.0
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for start in (0.0, 0.32):  # two hard huffs of breath
            u = t - start
            if 0.0 <= u < 0.3:
                s += huff(rng.uniform(-1, 1)) * 3.0 * math.exp(-u / 0.08)
        if 0.7 <= t < 0.715:  # jaw pop
            s += math.sin(2 * math.pi * 900 * (t - 0.7)) * 1.4 * (1 - (t - 0.7) / 0.015)
        u = t - 0.85
        if u >= 0.0:
            f = 78.0 + 22.0 * math.sin(math.pi * min(1.0, u / 1.0))
            phase += f / SR
            saw = 2.0 * (phase % 1.0) - 1.0
            rough = 0.6 + 0.4 * math.sin(2 * math.pi * 31.0 * t)
            s += (bellow(saw + rng.uniform(-0.6, 0.6)) * 2.2 + low(saw) * 0.6) * rough * env(u, 0.0, 0.1, 0.75, 0.35)
        out.append(s)
    return reverb(out, 0.25)


def caw(seed: int) -> list[float]:
    rng = random.Random(70 + seed)
    out = []
    nose = Biquad(1300.0, 2.5)
    beak = Biquad(2600.0, 3.0)
    phase = 0.0
    starts = (0.0, 0.42) if seed == 2 else (0.0,)
    length = 0.45 + 0.42 * (len(starts) - 1)
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for st in starts:
            u = t - st
            if 0.0 <= u < 0.4:
                f = 540.0 - 120.0 * u / 0.4 + seed * 15.0
                phase += f / SR
                saw = 2.0 * (phase % 1.0) - 1.0
                rasp = 1.0 + rng.uniform(-0.8, 0.8)  # the harsh croak
                s += (saw * rasp) * env(u, 0.0, 0.02, 0.25, 0.13)
        out.append(nose(s) * 1.3 + beak(s) * 0.8)
    return reverb(reverb(out, 0.35), 0.2)


if __name__ == "__main__":
    write(OUT / "music" / "storm_cue.wav", storm_cue())
    write(OUT / "sfx" / "snort_1.wav", snort(1))
    write(OUT / "sfx" / "snort_2.wav", snort(2))
    for k in range(1, 5):
        write(OUT / "sfx" / f"chop_{k}.wav", chop(k))
    write(OUT / "sfx" / "tree_fall.wav", tree_fall())
    for k in (1, 2):
        write(OUT / "sfx" / f"bleat_{k}.wav", bleat(k))
    for k in (1, 2):
        write(OUT / "sfx" / f"howl_{k}.wav", howl(k))
        write(OUT / "sfx" / f"caw_{k}.wav", caw(k))
    write(OUT / "sfx" / "growl.wav", growl())
    write(OUT / "sfx" / "roar.wav", roar())
