#!/usr/bin/env python3
"""C12 SFX baker (docs/specs/readability-feel.md section 3) -- stdlib only.

Ports the mockup's WebAudio recipes (design/readability-feel.html, HALF A) to offline
44100 Hz mono 16-bit WAVs in audio/. The synthesis surface is exactly the mockup's
THREE primitives:

  tone(t0, p)        one oscillator, optional exponential freq sweep, optional
                     lowpass, AD gain envelope.
  noise_burst(t0, p) the shared SEEDED noise buffer (mulberry32 0xC12A, same bits as
                     the page) through one biquad filter (optional freq sweep),
                     AD gain envelope.
  adsr(...)          linear attack `a` to `gain`, exponential decay to ~0 at `dur`.

The page's master chain ends in a soft compressor; offline, each file is peak-limited
to 0.95 instead (only the cues whose stacked voices exceed full scale get pulled
down -- same safety net, zero pumping). Run: python tools/gen_sfx.py
"""

import math
import os
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# ── the seeded noise buffer (bit-identical to the mockup's mulberry32 0xC12A) ──────

def _imul(a, b):
    # JS Math.imul: 32-bit two's-complement multiply; the mask keeps the low 32 bits,
    # which is all mulberry32's XOR/ADD pipeline ever reads.
    return (a * b) & 0xFFFFFFFF


def mulberry32(seed):
    a = seed & 0xFFFFFFFF

    def rand():
        nonlocal a
        a = (a + 0x6D2B79F5) & 0xFFFFFFFF
        t = _imul(a ^ (a >> 15), a | 1)
        t = ((t + _imul(t ^ (t >> 7), t | 61)) ^ t) & 0xFFFFFFFF
        return (t ^ (t >> 14)) / 4294967296.0
    return rand


_NOISE_LEN = int(SR * 1.5)
_RNG = mulberry32(0xC12A)
NOISE = [_RNG() * 2.0 - 1.0 for _ in range(_NOISE_LEN)]
_noise_phase = 0.0  # module-global stepping offset, exactly like the page


# ── the three primitives ───────────────────────────────────────────────────────────

def adsr_gain(t, a, gain, dur):
    """Envelope value at time t (relative to voice start): linear attack a -> gain,
    exponential decay -> 0.0001 at dur, silence after."""
    if t < 0.0 or t >= dur:
        return 0.0
    if t < a:
        return 0.0001 + (gain - 0.0001) * (t / a)
    if dur <= a:
        return gain
    k = (t - a) / (dur - a)
    return gain * math.pow(0.0001 / gain, k)


def _osc(wave_name, phase):
    p = phase % 1.0
    if wave_name == "sine":
        return math.sin(2.0 * math.pi * p)
    if wave_name == "square":
        return 1.0 if p < 0.5 else -1.0
    if wave_name == "sawtooth":
        return 2.0 * p - 1.0
    if wave_name == "triangle":
        return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p
    raise ValueError(wave_name)


class Biquad:
    """RBJ biquad. WebAudio quirk the page inherits: for LOWPASS the Q value is in dB
    (default 1 -> Q_linear ~= 1.122); for BANDPASS it is linear."""

    def __init__(self, ftype, q):
        self.ftype = ftype
        self.q = 10.0 ** (q / 20.0) if ftype == "lowpass" else q
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self._freq = -1.0
        self.b0 = self.b1 = self.b2 = self.a1 = self.a2 = 0.0

    def set_freq(self, freq):
        if freq == self._freq:
            return
        self._freq = freq
        w0 = 2.0 * math.pi * min(max(freq, 1.0), SR * 0.49) / SR
        cw, sw = math.cos(w0), math.sin(w0)
        alpha = sw / (2.0 * self.q)
        if self.ftype == "lowpass":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        else:  # bandpass (constant skirt matches WebAudio's peak-gain=Q variant closely enough at these Qs)
            b0, b1, b2 = alpha, 0.0, -alpha
        a0 = 1 + alpha
        self.b0, self.b1, self.b2 = b0 / a0, b1 / a0, b2 / a0
        self.a1, self.a2 = (-2 * cw) / a0, (1 - alpha) / a0

    def process(self, x):
        y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x1, self.x2 = x, self.x1
        self.y1, self.y2 = y, self.y1
        return y


def _sweep_freq(t, f0, f1, sweep_t):
    """Exponential ramp f0 -> f1 over sweep_t, held at f1 after (WebAudio ramp)."""
    if f1 is None:
        return f0
    if t >= sweep_t:
        return max(f1, 1.0)
    return f0 * math.pow(max(f1, 1.0) / f0, t / sweep_t)


def tone(buf, t0, p):
    """tone(t0, {wave, f0, f1?, sweepT?, lp?, a, gain, dur}) -- oscillator voice."""
    a, gain, dur = p.get("a", 0.005), p.get("gain", 0.5), p["dur"]
    sweep_t = p.get("sweepT", dur)
    lp = Biquad("lowpass", 1.0) if "lp" in p else None
    if lp:
        lp.set_freq(p["lp"])
    n0, n1 = int(t0 * SR), min(int((t0 + dur) * SR), len(buf))
    phase = 0.0
    for n in range(n0, n1):
        t = n / SR - t0
        phase += _sweep_freq(t, p["f0"], p.get("f1"), sweep_t) / SR
        s = _osc(p.get("wave", "sine"), phase)
        if lp:
            s = lp.process(s)
        buf[n] += s * adsr_gain(t, a, gain, dur)


def noise_burst(buf, t0, p):
    """noiseBurst(t0, {type, freq, f1?, sweepT?, q?, a, gain, dur}) -- filtered-noise voice."""
    global _noise_phase
    _noise_phase = (_noise_phase + 0.617) % 1.0   # deterministic read offset, same step as the page
    offset = int(_noise_phase * 1.4 * SR)
    a, gain, dur = p.get("a", 0.005), p.get("gain", 0.5), p["dur"]
    sweep_t = p.get("sweepT", dur)
    filt = Biquad(p.get("type", "bandpass"), p.get("q", 1.0))
    n0, n1 = int(t0 * SR), min(int((t0 + dur) * SR), len(buf))
    for n in range(n0, n1):
        t = n / SR - t0
        filt.set_freq(_sweep_freq(t, p["freq"], p.get("f1"), sweep_t))
        s = filt.process(NOISE[(offset + n - n0) % _NOISE_LEN])
        buf[n] += s * adsr_gain(t, a, gain, dur)


# ── the recipes (param blocks lifted verbatim from the mockup's fx functions) ──────

def fx_mb16(buf, t):        # MB16 FIRE -- deep muzzle thump, ~0.5 s
    tone(buf, t, {"wave": "sine", "f0": 90, "f1": 45, "sweepT": 0.30, "dur": 0.50, "a": 0.006, "gain": 0.95})
    noise_burst(buf, t, {"type": "bandpass", "freq": 750, "q": 1.0, "dur": 0.07, "a": 0.002, "gain": 0.40})
    noise_burst(buf, t, {"type": "lowpass", "freq": 200, "dur": 0.35, "a": 0.010, "gain": 0.35})


def fx_dp5(buf, t):         # DP5 FIRE -- sharper mid crack, ~0.25 s
    tone(buf, t, {"wave": "triangle", "f0": 260, "f1": 110, "sweepT": 0.10, "dur": 0.22, "a": 0.003, "gain": 0.60})
    noise_burst(buf, t, {"type": "bandpass", "freq": 1600, "q": 1.2, "dur": 0.05, "a": 0.001, "gain": 0.45})


def fx_mg(buf, t):          # MG BURST -- the crewed guns, 10 ticks at 12/s, ~0.9 s
    for k in range(10):
        tk = t + k / 12.0
        noise_burst(buf, tk, {"type": "bandpass", "freq": 1500 + (k % 3) * 140, "q": 2.2, "dur": 0.035, "a": 0.001, "gain": 0.34})
        noise_burst(buf, tk, {"type": "lowpass", "freq": 420, "dur": 0.030, "a": 0.001, "gain": 0.22})


def fx_splash(buf, t):      # SPLASH COLUMN -- big water plume, ~0.8 s
    noise_burst(buf, t, {"type": "bandpass", "freq": 850, "f1": 380, "sweepT": 0.6, "q": 0.9, "dur": 0.80, "a": 0.100, "gain": 0.60})
    tone(buf, t, {"wave": "sine", "f0": 80, "f1": 50, "sweepT": 0.2, "dur": 0.28, "a": 0.008, "gain": 0.50})


def fx_gunsplash(buf, t):   # GUNSPLASH STITCH -- one watery tick, ~0.12 s
    # ONE stitch (mid-walk 1150 Hz): in-game each `gunsplash` event is a single round
    # slapping the sea; the mockup's 5-tick line emerges from repeats at the 0.08 s gap.
    noise_burst(buf, t, {"type": "bandpass", "freq": 1150, "q": 1.6, "dur": 0.12, "a": 0.010, "gain": 0.32})


def fx_klaxon(buf, t):      # TORPEDO KLAXON -- two-tone horn LO-HI-LO-HI, ~1.1 s
    for i, f in enumerate([349, 466, 349, 466]):
        for det in (0.996, 1.004):
            tone(buf, t + i * 0.28, {"wave": "sawtooth", "f0": f * det, "dur": 0.26, "a": 0.020, "gain": 0.16, "lp": 950})


def fx_sonar(buf, t):       # SONAR CONTACT -- classic ping + echo tail, ~0.9 s
    tone(buf, t, {"wave": "sine", "f0": 1150, "f1": 1050, "sweepT": 0.7, "dur": 0.85, "a": 0.004, "gain": 0.50})
    tone(buf, t + 0.28, {"wave": "sine", "f0": 1120, "f1": 1040, "sweepT": 0.5, "dur": 0.60, "a": 0.004, "gain": 0.15})


def fx_dc_volley(buf, t):   # DC VOLLEY -- the rack rolls, clunk-clunk, ~0.4 s
    for d in (0.0, 0.18):
        noise_burst(buf, t + d, {"type": "lowpass", "freq": 300, "dur": 0.05, "a": 0.001, "gain": 0.55})
        tone(buf, t + d, {"wave": "square", "f0": 95, "f1": 70, "sweepT": 0.05, "dur": 0.07, "a": 0.001, "gain": 0.30, "lp": 400})


def fx_dc_blast(buf, t):    # DC BLAST -- deep underwater whump, ~1.0 s
    tone(buf, t, {"wave": "sine", "f0": 62, "f1": 28, "sweepT": 0.55, "dur": 1.00, "a": 0.010, "gain": 1.00})
    noise_burst(buf, t, {"type": "lowpass", "freq": 240, "f1": 90, "sweepT": 0.8, "dur": 0.95, "a": 0.030, "gain": 0.55})


def fx_ship_hit(buf, t):    # SHIP HIT -- dull armor clang + alarm blip, ~0.6 s
    for f, dur, gn in ((320, 0.30, 0.34), (487, 0.24, 0.22), (733, 0.18, 0.15)):
        tone(buf, t, {"wave": "triangle", "f0": f, "dur": dur, "a": 0.002, "gain": gn})
    noise_burst(buf, t, {"type": "bandpass", "freq": 350, "q": 0.8, "dur": 0.09, "a": 0.001, "gain": 0.35})
    tone(buf, t + 0.32, {"wave": "square", "f0": 880, "dur": 0.12, "a": 0.005, "gain": 0.10, "lp": 2200})


def fx_wave_clear(buf, t):  # WAVE CLEAR -- dry two-note sting, ~1.0 s
    tone(buf, t, {"wave": "sawtooth", "f0": 196.0, "dur": 0.42, "a": 0.020, "gain": 0.26, "lp": 1400})
    tone(buf, t + 0.34, {"wave": "sawtooth", "f0": 261.6, "dur": 0.62, "a": 0.020, "gain": 0.26, "lp": 1400})
    tone(buf, t + 0.34, {"wave": "sawtooth", "f0": 130.8, "dur": 0.62, "a": 0.020, "gain": 0.12, "lp": 900})


def fx_machine(buf, t):     # MACHINE ON SCOPE -- low boss-arrival swell, ~1.5 s
    for det in (1.0, 1.006):
        tone(buf, t, {"wave": "sawtooth", "f0": 55 * det, "dur": 1.50, "a": 0.850, "gain": 0.22, "lp": 520})
    noise_burst(buf, t, {"type": "lowpass", "freq": 130, "dur": 1.50, "a": 0.900, "gain": 0.30})


def fx_radio(buf, t):       # RADIO CHIME -- soft two-tone comms blip (UI cue on incoming traffic), ~0.18 s
    # a gentle high sine squelch: two quick blips, low gain, lowpassed so it reads as a friendly
    # net chirp, never an alarm. Not a sim effect -- Main plays it directly via SfxPlayer.play_ui.
    tone(buf, t,         {"wave": "sine", "f0": 1660, "dur": 0.07, "a": 0.004, "gain": 0.17, "lp": 3200})
    tone(buf, t + 0.075, {"wave": "sine", "f0": 2200, "dur": 0.09, "a": 0.004, "gain": 0.15, "lp": 3600})


def fx_ship_lost(buf, t):   # SHIP LOST -- descending settle, ~2 s
    tone(buf, t, {"wave": "sine", "f0": 220, "f1": 46, "sweepT": 1.7, "dur": 2.00, "a": 0.050, "gain": 0.50})
    tone(buf, t, {"wave": "sine", "f0": 110, "f1": 24, "sweepT": 1.8, "dur": 2.00, "a": 0.080, "gain": 0.30})
    noise_burst(buf, t, {"type": "lowpass", "freq": 320, "f1": 90, "sweepT": 1.6, "dur": 1.90, "a": 0.150, "gain": 0.25})


SOUNDS = [
    ("mb16_fire",     0.55, fx_mb16),
    ("dp5_fire",      0.28, fx_dp5),
    ("mg_burst",      0.90, fx_mg),
    ("splash_column", 0.85, fx_splash),
    ("gunsplash",     0.15, fx_gunsplash),
    ("torp_klaxon",   1.15, fx_klaxon),
    ("contact_ping",  0.92, fx_sonar),
    ("dc_volley",     0.30, fx_dc_volley),
    ("dc_blast",      1.05, fx_dc_blast),
    ("ship_hit",      0.60, fx_ship_hit),
    ("wave_clear",    1.00, fx_wave_clear),
    ("machine_swell", 1.55, fx_machine),
    ("ship_lost",     2.05, fx_ship_lost),
    ("radio",         0.18, fx_radio),
]


def write_wav(path, buf):
    peak = max(1e-9, max(abs(s) for s in buf))
    scale = min(1.0, 0.95 / peak)   # the compressor's offline stand-in (see module docstring)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in buf)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, dur, fn in SOUNDS:
        buf = [0.0] * int((dur + 0.05) * SR)   # 50 ms tail so decays never truncate
        fn(buf, 0.0)
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, buf)
        print("%-14s %5.2fs  %7d bytes" % (name + ".wav", dur + 0.05, os.path.getsize(path)))
    print("%d WAVs -> %s" % (len(SOUNDS), os.path.normpath(OUT_DIR)))


if __name__ == "__main__":
    main()
