"""Original synthesized audio for the game (no samples, no licences).

  python3 tools/synth_audio.py      # writes into assets/audio/, then normalise with ffmpeg

- music/storm_cue.wav: a sparse cue for building weather. A low bowed-string drone on D
  swells in, a fifth joins, a minor second rubs against it for unease, distant thunder rolls
  under it, and it all falls away. Deliberately quiet and slow: it should feel like the
  valley holding its breath, not a score.
- sfx/snort_1.wav, snort_2.wav: a mule deer's alarm snort (nasal noise burst through two
  resonances, with a second smaller puff).
- sfx/bleat_1.wav, bleat_2.wav: a doe bleat for the deer call (a nasal, falling tone with
  a little tremble), what curious deer come to investigate.
- sfx/growl.wav: a low, rough rumble with a rattling flutter, for a wolf closing in.
- music/night.wav: a slow, quiet night piece: soft string chords (D minor, B flat, F, C)
  swelling and fading, with a few sparse plucked notes like a guitar across the fire.
- music/dawn.wav: brighter, for the first light: open chords (G, C, D) and a slow, breathy
  flute-like line.
- music/lights.wav: for the lights: a low drone, and high glassy tones a tritone apart
  that beat slowly against each other. Uneasy, not a jump-scare.
- sfx/pika_1..3.wav: a pika's call from the talus: a short, nasal, falling "eeep", one to
  three at a time.
- sfx/thrush_1..3.wav: a varied thrush in the big timber: one long, buzzy whistle on a single
  pitch, fading in and out, as if from far off in the fog.
(Chopping, the tree falling, wolves, the bear's roar and ravens are real recordings now:
tools/process_audio.py.)
Pure stdlib so it runs anywhere.

  python3 tools/synth_audio.py pika thrush    # just those
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


def _pad(freqs: list[float], t: float, seed: float) -> float:
    """A soft chord: a few string-like partials per note (lighter than bowed())."""
    out = 0.0
    vib = 1.0 + 0.002 * math.sin(2 * math.pi * 4.2 * t + seed)
    for k, f in enumerate(freqs):
        for n, amp in ((1, 1.0), (2, 0.35), (3, 0.15)):
            out += amp * math.sin(2 * math.pi * f * n * vib * t + seed * (k + n))
    return out / len(freqs)


def _pluck(f: float, t: float) -> float:
    if t < 0.0 or t > 3.0:
        return 0.0
    return (math.sin(2 * math.pi * f * t) + 0.4 * math.sin(4 * math.pi * f * t)) * math.exp(-t * 2.2) * min(1.0, t / 0.004)


def night() -> list[float]:
    rng = random.Random(81)
    chords = [[146.8, 174.6, 220.0], [116.5, 146.8, 174.6], [174.6, 220.0, 261.6], [130.8, 164.8, 196.0]]  # Dm Bb F C
    seg = 14.0
    length = seg * len(chords) + 6.0
    notes = [293.7, 349.2, 392.0, 440.0, 523.3, 587.3]  # D minor pentatonic-ish
    plucks = [(rng.uniform(2.0, length - 8.0), rng.choice(notes)) for _ in range(14)]
    lp = OnePole(1800.0)
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for c, ch in enumerate(chords):
            e = env(t, c * seg - 2.0, 5.0, c * seg + seg - 3.0, 5.0)
            if e > 0.0:
                s += _pad(ch, t, c * 1.3) * e * 0.5
        for st, f in plucks:
            s += _pluck(f, t - st) * 0.35
        s *= env(t, 0.0, 4.0, length - 6.0, 6.0)
        out.append(lp(s))
    return reverb(reverb(out, 0.4), 0.3)


def dawn() -> list[float]:
    chords = [[196.0, 246.9, 293.7], [130.8, 196.0, 261.6], [146.8, 220.0, 293.7], [196.0, 246.9, 293.7]]  # G C D G
    seg = 10.0
    length = seg * len(chords) + 5.0
    melody = [(3.0, 587.3, 2.5), (6.0, 659.3, 1.5), (8.0, 587.3, 3.0), (13.0, 493.9, 2.5), (16.0, 523.3, 3.5), (22.0, 587.3, 2.0),
              (24.5, 659.3, 2.0), (27.0, 740.0, 3.5), (33.0, 587.3, 4.5)]
    rng = random.Random(9)
    breath = OnePole(3000.0)
    lp = OnePole(2600.0)
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        s = 0.0
        for c, ch in enumerate(chords):
            e = env(t, c * seg - 1.5, 3.5, c * seg + seg - 2.0, 3.5)
            if e > 0.0:
                s += _pad(ch, t, c * 0.7) * e * 0.45
        for st, f, d in melody:  # a breathy flute: a sine with a little noise and vibrato
            u = t - st
            if 0.0 <= u < d + 0.6:
                vib = 1.0 + 0.006 * math.sin(2 * math.pi * 5.0 * u) * min(1.0, u / 0.6)
                s += (math.sin(2 * math.pi * f * vib * u) * 0.8 + breath(rng.uniform(-1, 1)) * 0.25) * env(u, 0.0, 0.25, d, 0.6) * 0.35
        s *= env(t, 0.0, 3.0, length - 5.0, 5.0)
        out.append(lp(s))
    return reverb(reverb(out, 0.35), 0.25)


def lights() -> list[float]:
    length = 26.0
    lp = OnePole(900.0)
    out = []
    for i in range(int(length * SR)):
        t = i / SR
        drone = _pad([73.4, 110.0], t, 0.3) * 0.6
        glass = 0.0
        for f, st in ((880.0, 2.0), (1244.5, 5.0), (932.3, 9.0), (1318.5, 12.0)):  # tritones, drifting
            u = t - st
            if u >= 0.0:
                beat = 0.6 + 0.4 * math.sin(2 * math.pi * 0.23 * u + f)
                glass += math.sin(2 * math.pi * f * u) * beat * env(u, 0.0, 3.5, 9.0, 4.0) * 0.18
        s = (lp(drone) + glass) * env(t, 0.0, 4.0, length - 6.0, 6.0)
        out.append(s)
    return reverb(reverb(out, 0.5), 0.35)


def pika(seed: int) -> list[float]:
    rng = random.Random(seed)
    out = [0.0] * int(SR * 1.2)
    t0 = 0.05
    for k in range(rng.randint(1, 3)):
        f0 = rng.uniform(2300, 2800)
        dur = rng.uniform(0.12, 0.18)
        ph = 0.0
        for i in range(int(dur * SR)):
            t = i / SR
            f = f0 * (1.0 - 0.18 * t / dur) # falls a little
            ph += 2 * math.pi * f / SR
            a = math.sin(math.pi * t / dur) ** 0.6
            v = math.sin(ph) + 0.45 * math.sin(2 * ph) + 0.2 * math.sin(3 * ph) # nasal
            j = int((t0 + t) * SR)
            if j < len(out):
                out[j] += v * a
        t0 += dur + rng.uniform(0.12, 0.25)
    return reverb(out, 0.2)


def thrush(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = rng.uniform(1.3, 1.9)
    f0 = rng.uniform(2600, 4200)
    out = []
    ph = 0.0
    for i in range(int((dur + 1.2) * SR)):
        t = i / SR
        a = env(t, 0.0, 0.35, dur - 0.5, 0.5)
        ph += 2 * math.pi * f0 * (1.0 + 0.004 * math.sin(2 * math.pi * 5 * t)) / SR
        buzz = 0.55 + 0.45 * math.sin(2 * math.pi * 72 * t) # the burr in it
        out.append(math.sin(ph) * a * buzz + 0.15 * math.sin(2 * ph) * a)
    return reverb(out, 0.5)


JOBS = {
    "storm_cue": lambda: write(OUT / "music" / "storm_cue.wav", storm_cue()),
    "snort": lambda: [write(OUT / "sfx" / f"snort_{k}.wav", snort(k)) for k in (1, 2)],
    "bleat": lambda: [write(OUT / "sfx" / f"bleat_{k}.wav", bleat(k)) for k in (1, 2)],
    "growl": lambda: write(OUT / "sfx" / "growl.wav", growl()),
    "night": lambda: write(OUT / "music" / "night.wav", night()),
    "dawn": lambda: write(OUT / "music" / "dawn.wav", dawn()),
    "lights": lambda: write(OUT / "music" / "lights.wav", lights()),
    "pika": lambda: [write(OUT / "sfx" / f"pika_{k}.wav", pika(k)) for k in (1, 2, 3)],
    "thrush": lambda: [write(OUT / "sfx" / f"thrush_{k}.wav", thrush(k)) for k in (1, 2, 3)],
}

if __name__ == "__main__":
    import sys
    for name in sys.argv[1:] or JOBS:
        JOBS[name]()
