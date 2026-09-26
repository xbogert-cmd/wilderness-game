"""Turns the CC0 recordings in assets/audio/src/ into the game's loops and one-shots.

  python3 tools/process_audio.py env [file...]   # loudness envelope, to pick windows
  python3 tools/process_audio.py build           # writes assets/audio/amb/*.wav and sfx/*.wav

Loops: mono, 44.1 kHz, loudness-normalised to -20 LUFS, the seam crossfaded so they loop
without a click (the .import files set loop_mode=2). One-shots: cut at the given windows,
faded in and out, normalised to -18 LUFS (peaks capped). Needs ffmpeg. Pure stdlib otherwise.
Sources and licences: assets/ASSET_MANIFEST.md.
"""
import array
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "audio" / "src"
OUT = ROOT / "assets" / "audio"
SR = 44100

# name: (source, start s, length s)  -> amb/<name>.wav, a seamless loop
LOOPS = {
    "marsh_day": ("bsb/0691.ogg", 20.0, 60.0),
    "marsh_night": ("bsb/0998.ogg", 10.0, 60.0),
    "frogs_close": ("fs/569543.ogg", 2.0, 55.0),
    "desert_day": ("bsb/1779.ogg", 1.0, 40.0),
    "cicadas": ("bsb/2397.ogg", 5.0, 55.0),
    "wind_strong": ("bsb/0146.ogg", 5.0, 60.0),
    "wind_whistle": ("bsb/0147.ogg", 10.0, 60.0),
    "wind_grass": ("bsb/0908.ogg", 5.0, 60.0),
    "wind_creak": ("bsb/1051.ogg", 20.0, 60.0),
    "wind_storm": ("bsb/1450.ogg", 10.0, 60.0),
    "wind_cottonwood": ("fs/579250.ogg", 20.0, 60.0),
    "wind_aspen": ("fs/637993.ogg", 10.0, 60.0),
    "oldgrowth_day": ("fs/563571.ogg", 20.0, 60.0),
    "drips": ("bsb/1386.ogg", 1.0, 19.0),
    "oldgrowth_night": ("bsb/0555.ogg", 1.0, 26.0),
    "meadow_day": ("bsb/0097.ogg", 10.0, 60.0),
    "prairie": ("fs/351609.ogg", 1.0, 55.0),
    "field_crickets": ("bsb/1020.ogg", 1.0, 33.0),
    "foothills_day": ("bsb/2749.ogg", 30.0, 60.0),
    "alpine_day": ("bsb/3204.ogg", 10.0, 60.0),
    "sage_day": ("fs/176786.ogg", 20.0, 60.0),
    "nighthawks": ("fs/245393.ogg", 2.0, 48.0),
    "toads": ("fs/519590.ogg", 2.0, 55.0),
}

# name: (source, [(start, length), ...])  -> sfx/<name>_<n>.wav
SHOTS: dict[str, tuple[str, list[tuple[float, float]]]] = {
    "axe": ("bsb/0536.ogg", [(2.41, 0.8), (9.07, 0.8), (11.22, 0.8), (13.42, 0.8), (15.59, 0.8), (17.62, 0.8)]),
    "axe_far": ("fs/410768.ogg", [(3.82, 0.75), (6.49, 0.75), (17.85, 0.75), (29.26, 0.75), (74.62, 0.75), (79.52, 0.75)]),
    "split": ("fs/519567.ogg", [(2.32, 1.2), (18.48, 1.2), (33.01, 1.2)]),
    "treefall": ("fs/494071.ogg", [(2.5, 5.4)]),
    "wolves": ("fs/519592.ogg", [(1.0, 12.0), (18.0, 14.0)]),
    "grizzly": ("fs/519599.ogg", [(8.5, 5.0), (23.5, 6.0), (46.0, 4.5)]),
    "coyotes": ("fs/640060.ogg", [(0.0, 12.0), (20.0, 12.0), (36.0, 11.5)]),
    "coyote": ("fs/833774.ogg", [(2.3, 2.2), (8.8, 3.2)]),
    "marmot": ("fs/822939.ogg", [(0.0, 2.6), (6.3, 2.4), (0.0, 8.7)]),
    "squirrel": ("fs/111393.ogg", [(0.0, 6.0), (12.0, 6.0), (30.0, 6.0)]),
    "flicker": ("fs/568807.ogg", [(0.7, 1.6), (4.8, 1.6), (8.3, 1.6), (12.0, 1.6)]),
    "woodpecker": ("fs/518573.ogg", [(0.3, 4.0), (5.0, 4.0), (32.0, 4.0), (40.0, 4.0)]),
    "canyon_wren": ("fs/351649.ogg", [(0.7, 6.3)]),
    "hawk": ("fs/683743.ogg", [(10.5, 3.5), (17.0, 3.5), (26.0, 3.5)]),
    "owl_gh": ("fs/157870.ogg", [(2.5, 3.8)]),
    "elk": ("fs/263489.ogg", [(2.3, 7.5)]),
    "geese": ("fs/204337.ogg", [(0.0, 12.5), (4.0, 5.0)]),
    "jay": ("fs/736257.ogg", [(1.5, 3.0), (8.0, 3.0), (24.0, 3.0)]),
    "raven": ("fs/519591.ogg", [(3.3, 2.5), (6.2, 2.8), (9.3, 2.8)]),
    "ducks": ("bsb/0276.ogg", [(0.0, 5.0), (15.5, 5.0)]),
    "bats": ("bsb/0458.ogg", [(0.0, 13.9)]),
    "rockfall": ("bsb/1022.ogg", [(1.70, 1.2), (11.68, 1.2), (13.22, 1.2), (16.53, 1.3), (18.61, 1.2)]),
    "ice": ("bsb/2205.ogg", [(0.0, 1.9)]),
    "ice2": ("bsb/2206.ogg", [(0.0, 1.29)]),
    "thunder_near": ("bsb/3180.ogg", [(0.0, 12.0)]),
    "thunder_near2": ("bsb/2718.ogg", [(0.0, 14.0)]),
    "thunder_near3": ("bsb/3179.ogg", [(0.0, 12.0)]),
    "thunder_near4": ("bsb/3115.ogg", [(0.0, 13.0)]),
    "thunder_far": ("bsb/3116.ogg", [(0.0, 14.0)]),
    "thunder_far2": ("bsb/3114.ogg", [(0.0, 11.0)]),
    "thunder_far3": ("bsb/3184.ogg", [(8.0, 14.0)]),
    "thunder_far4": ("bsb/3182.ogg", [(0.0, 14.0)]),
}
LOWPASS = {"thunder_far": 420} ## name prefix: cutoff Hz (distance takes the crack off thunder)

SEAM = 3.0


def ff(*args: str) -> None:
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", *args], check=True)


def decode(path: Path, start: float = 0.0, length: float = -1.0, rate: int = SR) -> array.array:
    cmd = ["ffmpeg", "-nostdin", "-loglevel", "error", "-ss", str(start)]
    if length > 0:
        cmd += ["-t", str(length)]
    cmd += ["-i", str(path), "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    a = array.array("h")
    a.frombytes(raw)
    return a


def write(path: Path, a: array.array) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(a.tobytes())


def normalise(path: Path, lufs: float) -> None:
    tmp = path.with_suffix(".tmp.wav")
    ff("-i", str(path), "-af", f"loudnorm=I={lufs}:TP=-2:LRA=11", "-ar", str(SR), "-ac", "1", str(tmp))
    tmp.replace(path)


def loop(name: str, src: str, start: float, length: float) -> None:
    a = decode(SRC / src, start, length + SEAM)
    n = int(length * SR)
    s = int(SEAM * SR)
    out = array.array("h", a[:n])
    for i in range(min(s, len(a) - n)): # the tail fades into the head: the end runs on into the start
        t = i / s
        out[i] = int(a[i] * t + a[n + i] * (1.0 - t))
    p = OUT / "amb" / f"{name}.wav"
    write(p, out)
    normalise(p, -20.0)


def shot(name: str, src: str, start: float, length: float) -> None:
    a = decode(SRC / src, start, length)
    f = int(0.02 * SR)
    g = int(min(0.3, length * 0.3) * SR)
    for i in range(min(f, len(a))):
        a[i] = int(a[i] * i / f)
    for i in range(min(g, len(a))):
        a[len(a) - 1 - i] = int(a[len(a) - 1 - i] * i / g)
    p = OUT / "sfx" / f"{name}.wav"
    write(p, a)
    for k, hz in LOWPASS.items():
        if name.startswith(k):
            tmp = p.with_suffix(".lp.wav")
            ff("-i", str(p), "-af", f"lowpass=f={hz},lowpass=f={hz}", str(tmp))
            tmp.replace(p)
    normalise(p, -18.0)


def env(path: Path) -> None:
    """Loudness per 0.25 s as a strip of digits 0-9 (each ~6 dB), and the loudest moments."""
    a = decode(path, rate=8000)
    step = 2000
    import math
    levels = []
    for i in range(0, len(a) - step, step):
        seg = a[i:i + step]
        rms = math.sqrt(sum(x * x for x in seg) / len(seg)) + 1.0
        levels.append(20.0 * math.log10(rms / 32768.0))
    top = max(levels) if levels else 0.0
    strip = "".join(str(max(0, min(9, int(9 + (l - top) / 6.0)))) for l in levels)
    print(f"{path.name}  peak {top:.0f} dBFS  ({len(levels) / 4:.0f} s)")
    for k in range(0, len(strip), 120):
        print(f"  {k / 4:6.1f}s  {strip[k:k + 120]}")


def onsets(path: Path, start: float, length: float) -> None:
    """Where sharp hits start (a jump of 15 dB within 20 ms), with how loud they peak."""
    import math
    a = decode(path, start, length, rate=8000)
    step = 80 # 10 ms
    lv = []
    for i in range(0, len(a) - step, step):
        seg = a[i:i + step]
        lv.append(20.0 * math.log10(math.sqrt(sum(x * x for x in seg) / len(seg)) + 1.0) - 90.3)
    out = []
    last = -99
    for i in range(3, len(lv)):
        if lv[i] - min(lv[i - 3:i]) > 15.0 and i - last > 25:
            out.append(f"{start + i * 0.01:.2f}({max(lv[i:i + 10]):.0f})")
            last = i
    print(path.name, " ".join(out))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "onsets":
        onsets(Path(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]))
    elif len(sys.argv) > 1 and sys.argv[1] == "env":
        files = [Path(f) for f in sys.argv[2:]] or sorted(SRC.glob("*/*.ogg"))
        for f in files:
            env(f)
    else: # build [names...]: all of them, or just these
        only = sys.argv[2:]
        for k, v in LOOPS.items():
            if only and k not in only:
                continue
            loop(k, *v)
            print("loop", k)
        for k, (src, cuts) in SHOTS.items():
            if only and k not in only:
                continue
            for i, (st, ln) in enumerate(cuts):
                shot(f"{k}_{i + 1}", src, st, ln)
            print("shots", k, len(cuts))
