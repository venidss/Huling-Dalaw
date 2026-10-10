#!/usr/bin/env python3
"""Procedural audio generator for DAET: ANG PAMANA.

Uses only the Python stdlib (wave + struct + math + random). Writes 16-bit mono WAVs
suitable for use as Godot AudioStreamWAV resources. Sample rate 22050 is plenty for the
muffled / lo-fi aesthetic the horror game needs and keeps file sizes small — the whole
audio folder stays under ~5MB.
"""
from __future__ import annotations
import math
import os
import random
import struct
import wave

SR = 22050

# ----------------------------------------------------------------------------
# Low-level helpers (no numpy — everything is pure Python arrays of floats).
# ----------------------------------------------------------------------------

def write_wav(path: str, samples: list[float], sr: int = SR, loop: bool = False) -> None:
    """Write a list of floats in [-1, 1] to a 16-bit mono WAV."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Soft clip and convert.
    data = bytearray()
    for s in samples:
        if s > 1.0:
            s = 1.0 - math.exp(-s + 1.0) * 0.1
        elif s < -1.0:
            s = -1.0 + math.exp(s + 1.0) * 0.1
        s = max(-1.0, min(1.0, s))
        data += struct.pack('<h', int(s * 32000))
    with wave.open(path, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(bytes(data))


def mix(*streams: list[float]) -> list[float]:
    """Mix equal-length streams by summing."""
    n = min(len(s) for s in streams)
    out = [0.0] * n
    for s in streams:
        for i in range(n):
            out[i] += s[i]
    return out


def pad(samples: list[float], target_n: int) -> list[float]:
    if len(samples) >= target_n:
        return samples[:target_n]
    return samples + [0.0] * (target_n - len(samples))


def gain(samples: list[float], g: float) -> list[float]:
    return [s * g for s in samples]


def envelope_adsr(n: int, a: float, d: float, s: float, r: float, sustain_level: float = 0.7) -> list[float]:
    """ADSR envelope in seconds. a+d+s+r should <= n/SR; truncates if too long."""
    env = [0.0] * n
    ai = int(a * SR)
    di = int(d * SR)
    ri = int(r * SR)
    si = n - ai - di - ri
    if si < 0:
        si = 0
    i = 0
    while i < ai and i < n:
        env[i] = i / max(1, ai)
        i += 1
    end_d = min(n, i + di)
    while i < end_d:
        t = (i - ai) / max(1, di)
        env[i] = 1.0 - (1.0 - sustain_level) * t
        i += 1
    end_s = min(n, i + si)
    while i < end_s:
        env[i] = sustain_level
        i += 1
    while i < n:
        t = (i - (ai + di + si)) / max(1, ri)
        env[i] = sustain_level * (1.0 - t)
        i += 1
    return env


def apply_env(samples: list[float], env: list[float]) -> list[float]:
    n = min(len(samples), len(env))
    return [samples[i] * env[i] for i in range(n)]


def noise(n: int) -> list[float]:
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def pink_noise(n: int) -> list[float]:
    """Voss-McCartney approximation of pink noise."""
    rows = 7
    row_vals = [random.uniform(-1.0, 1.0) for _ in range(rows)]
    counter = 0
    out = [0.0] * n
    for i in range(n):
        # Which row to update?
        if counter == 0:
            # Update a random row.
            idx = int(random.random() * rows)
            row_vals[idx] = random.uniform(-1.0, 1.0)
        total = sum(row_vals) / rows
        out[i] = total
        counter = (counter + 1) % (1 << rows)
    # Normalize.
    peak = max((abs(v) for v in out), default=1.0)
    if peak > 0:
        out = [v / peak * 0.9 for v in out]
    return out


def low_pass(samples: list[float], cutoff_hz: float, sr: int = SR) -> list[float]:
    """Simple one-pole lowpass filter."""
    if cutoff_hz <= 0:
        return list(samples)
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / sr
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    prev = 0.0
    for i, s in enumerate(samples):
        prev = prev + alpha * (s - prev)
        out[i] = prev
    return out


def high_pass(samples: list[float], cutoff_hz: float, sr: int = SR) -> list[float]:
    """Simple one-pole highpass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / sr
    alpha = rc / (rc + dt)
    out = [0.0] * len(samples)
    prev_in = samples[0] if samples else 0.0
    prev_out = 0.0
    for i, s in enumerate(samples):
        new_out = alpha * (prev_out + s - prev_in)
        out[i] = new_out
        prev_out = new_out
        prev_in = s
    return out


def tone(freq: float, duration: float, waveform: str = "sine", sr: int = SR) -> list[float]:
    n = int(duration * sr)
    out = [0.0] * n
    for i in range(n):
        t = i / sr
        if waveform == "sine":
            out[i] = math.sin(2 * math.pi * freq * t)
        elif waveform == "triangle":
            frac = (t * freq) - int(t * freq)
            out[i] = 4.0 * abs(frac - 0.5) - 1.0
        elif waveform == "square":
            frac = (t * freq) - int(t * freq)
            out[i] = 1.0 if frac < 0.5 else -1.0
        elif waveform == "saw":
            frac = (t * freq) - int(t * freq)
            out[i] = 2.0 * frac - 1.0
    return out


def tone_sweep(f0: float, f1: float, duration: float, waveform: str = "sine") -> list[float]:
    n = int(duration * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        if waveform == "sine":
            out[i] = math.sin(phase)
        elif waveform == "triangle":
            frac = (phase / (2 * math.pi)) % 1.0
            out[i] = 4.0 * abs(frac - 0.5) - 1.0
        elif waveform == "saw":
            frac = (phase / (2 * math.pi)) % 1.0
            out[i] = 2.0 * frac - 1.0
    return out

# ----------------------------------------------------------------------------
# Individual sounds.
# ----------------------------------------------------------------------------

OUT_SFX = "assets/audio/sfx"
OUT_AMB = "assets/audio/ambience"
OUT_MUS = "assets/audio/music"


def sfx_footstep(path: str) -> None:
    n = int(0.14 * SR)
    nz = low_pass(high_pass(noise(n), 200), 1500)
    env = envelope_adsr(n, 0.005, 0.03, 0.0, 0.1, 0.5)
    out = apply_env(nz, env)
    # Add a soft click.
    click = tone(80, 0.03)
    for i in range(min(len(out), len(click))):
        out[i] += click[i] * 0.3
    write_wav(path, gain(out, 0.6))


def sfx_door_open(path: str) -> None:
    n = int(0.9 * SR)
    base = low_pass(noise(n), 1200)
    base = high_pass(base, 100)
    # Modulate amplitude for a creak sweep.
    out = []
    for i, s in enumerate(base):
        t = i / n
        amp = 0.3 + 0.5 * math.sin(2 * math.pi * (1.5 + 2 * t) * (i / SR))
        amp *= 0.4 + 0.6 * t
        out.append(s * amp)
    env = envelope_adsr(n, 0.05, 0.1, 0.0, 0.6, 0.6)
    out = apply_env(out, env)
    write_wav(path, gain(out, 0.7))


def sfx_door_creak(path: str) -> None:
    n = int(1.6 * SR)
    base = low_pass(noise(n), 900)
    base = high_pass(base, 120)
    out = []
    for i, s in enumerate(base):
        t = i / n
        # Slower modulation for an unsettling creak.
        amp = 0.3 + 0.6 * math.sin(2 * math.pi * (0.8 + 1.3 * t) * (i / SR))
        amp *= 0.3 + 0.7 * (1.0 - abs(2.0 * t - 1.0))
        out.append(s * amp)
    env = envelope_adsr(n, 0.2, 0.1, 0.6, 0.6, 0.7)
    out = apply_env(out, env)
    write_wav(path, gain(out, 0.75))


def sfx_door_close(path: str) -> None:
    n = int(0.45 * SR)
    thud = tone(70, 0.05)
    thud += [0.0] * (n - len(thud))
    env = envelope_adsr(n, 0.001, 0.02, 0.0, 0.3, 0.3)
    out = apply_env(thud, env)
    # Blend with some filtered noise.
    nz = low_pass(noise(n), 400)
    out = mix(out, gain(apply_env(nz, env), 0.4))
    write_wav(path, gain(out, 0.8))


def sfx_door_slam(path: str) -> None:
    n = int(0.6 * SR)
    thump = tone_sweep(140, 50, 0.08)
    thump += [0.0] * (n - len(thump))
    env = envelope_adsr(n, 0.001, 0.03, 0.2, 0.3, 0.4)
    out = apply_env(thump, env)
    # High-frequency impact burst.
    hit = high_pass(noise(int(0.08 * SR)), 1500)
    hit_env = envelope_adsr(len(hit), 0.001, 0.03, 0.0, 0.05, 0.1)
    hit = apply_env(hit, hit_env)
    for i in range(min(len(out), len(hit))):
        out[i] += hit[i] * 0.7
    write_wav(path, gain(out, 0.95))


def sfx_door_locked(path: str) -> None:
    n = int(0.35 * SR)
    out = [0.0] * n
    # A few metallic clicks.
    for off in [0.0, 0.08, 0.16]:
        pos = int(off * SR)
        click = high_pass(noise(int(0.03 * SR)), 2000)
        env = envelope_adsr(len(click), 0.001, 0.015, 0.0, 0.03, 0.3)
        click = apply_env(click, env)
        for i, s in enumerate(click):
            if pos + i < n:
                out[pos + i] += s * 0.7
    write_wav(path, gain(out, 0.7))


def sfx_key_unlock(path: str) -> None:
    n = int(0.55 * SR)
    out = [0.0] * n
    # Metallic turn: three rising clicks.
    for i, off in enumerate([0.0, 0.1, 0.2]):
        pos = int(off * SR)
        clk = high_pass(noise(int(0.04 * SR)), 1500)
        env = envelope_adsr(len(clk), 0.002, 0.02, 0.0, 0.04, 0.3)
        clk = apply_env(clk, env)
        # Add a pitched element.
        t = tone(400 + i * 150, 0.04)
        for j in range(min(len(clk), len(t))):
            clk[j] += t[j] * 0.3
        for j, s in enumerate(clk):
            if pos + j < n:
                out[pos + j] += s * 0.6
    # Final "pop" of a lock giving way.
    pop_pos = int(0.3 * SR)
    pop = tone_sweep(600, 150, 0.15)
    pop_env = envelope_adsr(len(pop), 0.005, 0.03, 0.0, 0.12, 0.4)
    pop = apply_env(pop, pop_env)
    for j, s in enumerate(pop):
        if pop_pos + j < n:
            out[pop_pos + j] += s * 0.5
    write_wav(path, gain(out, 0.85))


def sfx_item_pickup(path: str) -> None:
    n = int(0.4 * SR)
    a = tone(660, 0.1)
    b = tone(880, 0.15)
    out = [0.0] * n
    for i, s in enumerate(a):
        if i < n:
            out[i] += s * 0.5
    pos = int(0.08 * SR)
    for i, s in enumerate(b):
        if pos + i < n:
            out[pos + i] += s * 0.4
    env = envelope_adsr(n, 0.01, 0.08, 0.1, 0.3, 0.3)
    out = apply_env(out, env)
    write_wav(path, gain(out, 0.7))


def sfx_paper_rustle(path: str) -> None:
    n = int(0.5 * SR)
    nz = high_pass(noise(n), 2500)
    env = envelope_adsr(n, 0.01, 0.04, 0.3, 0.4, 0.4)
    out = apply_env(nz, env)
    write_wav(path, gain(out, 0.6))


def sfx_switch_flip(path: str) -> None:
    n = int(0.25 * SR)
    out = [0.0] * n
    for off in [0.0, 0.08]:
        pos = int(off * SR)
        clk = high_pass(noise(int(0.025 * SR)), 1800)
        env = envelope_adsr(len(clk), 0.001, 0.015, 0.0, 0.03, 0.2)
        clk = apply_env(clk, env)
        for i, s in enumerate(clk):
            if pos + i < n:
                out[pos + i] += s * 0.9
    write_wav(path, gain(out, 0.7))


def sfx_switch_broken(path: str) -> None:
    n = int(0.4 * SR)
    buzz = tone(60, 0.4, "square")
    env = envelope_adsr(n, 0.01, 0.05, 0.4, 0.3, 0.4)
    out = apply_env(buzz, env)
    nz = low_pass(noise(n), 300)
    out = mix(out, gain(nz, 0.3))
    write_wav(path, gain(out, 0.55))


def sfx_drawer_slide(path: str) -> None:
    n = int(0.6 * SR)
    nz = low_pass(noise(n), 500)
    nz = high_pass(nz, 60)
    env = envelope_adsr(n, 0.02, 0.1, 0.5, 0.3, 0.5)
    out = apply_env(nz, env)
    # Low rumble.
    r = tone(55, 0.6)
    for i in range(min(n, len(r))):
        out[i] += r[i] * 0.3 * (1.0 - i / n)
    write_wav(path, gain(out, 0.6))


def sfx_ui_click(path: str) -> None:
    n = int(0.08 * SR)
    nz = high_pass(noise(n), 1500)
    env = envelope_adsr(n, 0.001, 0.01, 0.0, 0.05, 0.2)
    out = apply_env(nz, env)
    t = tone(900, 0.03)
    for i in range(min(n, len(t))):
        out[i] += t[i] * 0.3
    write_wav(path, gain(out, 0.4))


def sfx_heartbeat(path: str) -> None:
    n = int(1.3 * SR)
    out = [0.0] * n
    for off, dur, amp in [(0.0, 0.14, 1.0), (0.18, 0.1, 0.6), (0.7, 0.14, 1.0), (0.88, 0.1, 0.6)]:
        thump = tone_sweep(90, 45, dur)
        env = envelope_adsr(len(thump), 0.005, 0.04, 0.0, dur - 0.045, 0.3)
        thump = apply_env(thump, env)
        pos = int(off * SR)
        for i, s in enumerate(thump):
            if pos + i < n:
                out[pos + i] += s * amp
    write_wav(path, gain(out, 0.7))


def sfx_object_fall(path: str) -> None:
    n = int(0.7 * SR)
    out = [0.0] * n
    # Initial impact.
    hit = tone_sweep(220, 60, 0.12)
    env = envelope_adsr(len(hit), 0.001, 0.03, 0.0, 0.1, 0.3)
    hit = apply_env(hit, env)
    for i, s in enumerate(hit):
        if i < n:
            out[i] += s * 0.8
    # Secondary tumble.
    for off in [0.18, 0.32]:
        bump = tone_sweep(180, 90, 0.07)
        benv = envelope_adsr(len(bump), 0.001, 0.02, 0.0, 0.05, 0.2)
        bump = apply_env(bump, benv)
        pos = int(off * SR)
        for i, s in enumerate(bump):
            if pos + i < n:
                out[pos + i] += s * 0.4
    write_wav(path, gain(out, 0.85))


def sfx_whisper(path: str) -> None:
    n = int(2.4 * SR)
    nz = pink_noise(n)
    nz = high_pass(nz, 400)
    nz = low_pass(nz, 2500)
    # Modulate amplitude to feel like syllables.
    for i in range(n):
        t = i / SR
        mod = 0.5 + 0.5 * math.sin(2 * math.pi * 4.0 * t + math.sin(2.5 * t))
        mod *= 0.4 + 0.6 * math.sin(2 * math.pi * 0.6 * t)
        nz[i] *= max(0.0, mod)
    env = envelope_adsr(n, 0.3, 0.2, 1.4, 0.5, 0.6)
    out = apply_env(nz, env)
    write_wav(path, gain(out, 0.55))


def sfx_radio_static(path: str) -> None:
    n = int(2.0 * SR)
    nz = high_pass(noise(n), 400)
    # Occasional dips to feel like tuning.
    for i in range(n):
        t = i / SR
        mod = 0.6 + 0.4 * math.sin(2 * math.pi * 1.3 * t)
        nz[i] *= mod
    # Add an occasional pure tone.
    beep = tone(500, 2.0)
    for i in range(n):
        nz[i] += beep[i] * 0.05 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.3 * i / SR))
    env = envelope_adsr(n, 0.1, 0.05, 1.6, 0.25, 0.7)
    out = apply_env(nz, env)
    write_wav(path, gain(out, 0.55))


def sfx_breath(path: str) -> None:
    n = int(1.6 * SR)
    nz = high_pass(pink_noise(n), 800)
    # Two breaths — in, out.
    env = [0.0] * n
    half = n // 2
    for i in range(half):
        t = i / half
        env[i] = math.sin(math.pi * t) * 0.7
    for i in range(half, n):
        t = (i - half) / (n - half)
        env[i] = math.sin(math.pi * t) * 0.5
    out = [nz[i] * env[i] for i in range(n)]
    write_wav(path, gain(out, 0.5))


def sfx_gentle_bell(path: str) -> None:
    n = int(1.5 * SR)
    out = [0.0] * n
    for freq, amp in [(523.25, 1.0), (659.25, 0.5), (783.99, 0.3)]:
        t = tone(freq, 1.5)
        env = envelope_adsr(len(t), 0.003, 0.1, 1.2, 0.3, 0.5)
        t = apply_env(t, env)
        for i in range(n):
            out[i] += t[i] * amp
    write_wav(path, gain(out, 0.3))


def sfx_deep_rumble(path: str) -> None:
    n = int(3.0 * SR)
    out = [0.0] * n
    for freq, amp in [(40, 1.0), (55, 0.6), (80, 0.3)]:
        t = tone(freq, 3.0)
        for i in range(n):
            out[i] += t[i] * amp
    nz = low_pass(noise(n), 120)
    out = mix(out, gain(nz, 0.3))
    env = envelope_adsr(n, 0.4, 0.3, 1.8, 0.5, 0.6)
    out = apply_env(out, env)
    write_wav(path, gain(out, 0.75))


def sfx_object_fall_night(path: str) -> None:
    sfx_object_fall(path)


# ----------------------------------------------------------------------------
# Ambience (longer, loopable).
# ----------------------------------------------------------------------------

def amb_night_insects(path: str) -> None:
    n = int(6.0 * SR)
    out = [0.0] * n
    # Multiple cricket-like layers at different pitches, intermittent.
    for layer in range(5):
        base_hz = 3800 + random.random() * 900
        period = 0.08 + random.random() * 0.03
        pattern_period = 1.0 + random.random() * 1.5
        for i in range(n):
            t = i / SR
            # Pulse pattern.
            pulse_phase = (t % period) / period
            pulse = 1.0 if pulse_phase < 0.25 else 0.0
            # Overall pattern on/off.
            pattern = 0.5 + 0.5 * math.sin(2 * math.pi * (0.3 + layer * 0.05) * t)
            if pattern < 0.3:
                pulse = 0.0
            s = math.sin(2 * math.pi * base_hz * t) * pulse * 0.03
            out[i] += s
    # Low rustling leaves.
    rustle = high_pass(pink_noise(n), 1200)
    for i in range(n):
        t = i / SR
        mod = 0.3 + 0.5 * math.sin(2 * math.pi * 0.17 * t)
        out[i] += rustle[i] * 0.1 * mod
    write_wav(path, gain(out, 0.9))


def amb_night_wind(path: str) -> None:
    n = int(6.0 * SR)
    nz = low_pass(pink_noise(n), 400)
    nz = high_pass(nz, 60)
    for i in range(n):
        t = i / SR
        mod = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.13 * t))
        mod *= 0.6 + 0.4 * math.sin(2 * math.pi * 0.07 * t + 1.2)
        nz[i] *= mod
    write_wav(path, gain(nz, 0.9))


def amb_rain(path: str) -> None:
    n = int(5.0 * SR)
    nz = high_pass(pink_noise(n), 400)
    # Overall shimmer.
    for i in range(n):
        t = i / SR
        mod = 0.5 + 0.3 * math.sin(2 * math.pi * 0.08 * t)
        nz[i] *= mod
    # Add occasional "drip" pops.
    for off in range(0, n, int(0.5 * SR)):
        if random.random() > 0.6:
            dur = int(0.03 * SR)
            for j in range(dur):
                if off + j < n:
                    nz[off + j] += math.sin(2 * math.pi * (900 + random.random() * 400) * j / SR) * 0.15 * (1.0 - j / dur)
    write_wav(path, gain(nz, 0.7))


# ----------------------------------------------------------------------------
# Music (looping drones with sparse melody notes).
# ----------------------------------------------------------------------------

def music_menu_theme(path: str) -> None:
    n = int(16.0 * SR)
    out = [0.0] * n
    # Drone bed at A minor (A3=220).
    for freq, amp in [(55, 0.5), (110, 0.4), (220, 0.3), (330, 0.1)]:
        t = tone(freq, 16.0)
        for i in range(n):
            out[i] += t[i] * amp
    # Slow pad with LFO.
    for i in range(n):
        tt = i / SR
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * tt)
        out[i] *= 0.3 + 0.3 * lfo
    # Sparse single piano-ish notes using cos-shaped envelopes on sine tones.
    melody = [(1.5, 523.25), (4.0, 659.25), (6.5, 659.25), (9.0, 440.0), (12.0, 523.25)]
    for off, f in melody:
        pos = int(off * SR)
        dur = int(1.8 * SR)
        env = envelope_adsr(dur, 0.02, 0.3, 1.0, 0.5, 0.5)
        note = tone(f, 1.8)
        # Add a quiet octave above.
        note2 = tone(f * 2, 1.8)
        for i in range(dur):
            note[i] = note[i] * 0.6 + note2[i] * 0.2
        note = apply_env(note, env)
        for i, s in enumerate(note):
            if pos + i < n:
                out[pos + i] += s * 0.25
    # Soft noise bed.
    nz = low_pass(pink_noise(n), 200)
    for i in range(n):
        out[i] += nz[i] * 0.15
    # Fade at ends for seamless loop.
    fade = int(0.3 * SR)
    for i in range(fade):
        f = i / fade
        out[i] *= f
        out[n - 1 - i] *= f
    write_wav(path, gain(out, 0.55))


def music_ambient_drone(path: str) -> None:
    n = int(14.0 * SR)
    out = [0.0] * n
    for freq, amp in [(45, 0.5), (90, 0.3), (135, 0.15)]:
        t = tone(freq, 14.0)
        for i in range(n):
            out[i] += t[i] * amp
    # Slow modulation.
    for i in range(n):
        tt = i / SR
        out[i] *= 0.4 + 0.3 * math.sin(2 * math.pi * 0.03 * tt)
    # Thin high shimmer.
    sh = high_pass(pink_noise(n), 2500)
    for i in range(n):
        out[i] += sh[i] * 0.05
    fade = int(0.4 * SR)
    for i in range(fade):
        f = i / fade
        out[i] *= f
        out[n - 1 - i] *= f
    write_wav(path, gain(out, 0.5))


def music_ending_theme(path: str) -> None:
    n = int(12.0 * SR)
    out = [0.0] * n
    # Warmer major third chord with slow movement.
    for freq, amp in [(130.81, 0.5), (261.63, 0.4), (329.63, 0.25), (392.0, 0.15)]:
        t = tone(freq, 12.0)
        for i in range(n):
            out[i] += t[i] * amp
    for i in range(n):
        tt = i / SR
        out[i] *= 0.4 + 0.3 * math.sin(2 * math.pi * 0.04 * tt)
    # Soft bell at the end.
    for off, f, g in [(2.0, 523.25, 0.3), (5.0, 659.25, 0.25), (8.0, 783.99, 0.2)]:
        pos = int(off * SR)
        dur = int(2.5 * SR)
        note = tone(f, 2.5)
        env = envelope_adsr(dur, 0.005, 0.4, 1.5, 0.6, 0.4)
        note = apply_env(note, env)
        for i, s in enumerate(note):
            if pos + i < n:
                out[pos + i] += s * g
    fade = int(0.4 * SR)
    for i in range(fade):
        f = i / fade
        out[i] *= f
        out[n - 1 - i] *= f
    write_wav(path, gain(out, 0.5))


def music_final_theme(path: str) -> None:
    n = int(10.0 * SR)
    out = [0.0] * n
    # Darker minor cluster with building intensity.
    for freq, amp in [(55, 0.4), (110, 0.4), (165, 0.3), (220, 0.2), (277, 0.15)]:
        t = tone(freq, 10.0)
        for i in range(n):
            out[i] += t[i] * amp
    for i in range(n):
        tt = i / SR
        intensity = min(1.0, tt / 6.0 + 0.2)
        out[i] *= intensity * (0.4 + 0.4 * math.sin(2 * math.pi * 0.1 * tt))
    # Rising noise.
    nz = high_pass(pink_noise(n), 300)
    for i in range(n):
        tt = i / SR
        intensity = min(1.0, tt / 8.0)
        out[i] += nz[i] * 0.3 * intensity
    fade = int(0.3 * SR)
    for i in range(fade):
        f = i / fade
        out[i] *= f
        out[n - 1 - i] *= f
    write_wav(path, gain(out, 0.6))


# ----------------------------------------------------------------------------
# Entry point.
# ----------------------------------------------------------------------------

def main() -> None:
    random.seed(1973)   # deterministic — same sounds every build.
    os.makedirs(OUT_SFX, exist_ok=True)
    os.makedirs(OUT_AMB, exist_ok=True)
    os.makedirs(OUT_MUS, exist_ok=True)

    sfx_table = [
        ("footstep.wav", sfx_footstep),
        ("door_open.wav", sfx_door_open),
        ("door_creak.wav", sfx_door_creak),
        ("door_close.wav", sfx_door_close),
        ("door_slam.wav", sfx_door_slam),
        ("door_locked.wav", sfx_door_locked),
        ("key_unlock.wav", sfx_key_unlock),
        ("item_pickup.wav", sfx_item_pickup),
        ("paper_rustle.wav", sfx_paper_rustle),
        ("switch_flip.wav", sfx_switch_flip),
        ("switch_broken.wav", sfx_switch_broken),
        ("drawer_slide.wav", sfx_drawer_slide),
        ("ui_click.wav", sfx_ui_click),
        ("heartbeat.wav", sfx_heartbeat),
        ("object_fall.wav", sfx_object_fall),
        ("whisper.wav", sfx_whisper),
        ("radio_static.wav", sfx_radio_static),
        ("breath.wav", sfx_breath),
        ("gentle_bell.wav", sfx_gentle_bell),
        ("deep_rumble.wav", sfx_deep_rumble),
    ]
    for name, fn in sfx_table:
        fn(os.path.join(OUT_SFX, name))
        print("sfx:", name)

    amb_table = [
        ("night_insects.wav", amb_night_insects),
        ("night_wind.wav", amb_night_wind),
        ("rain.wav", amb_rain),
    ]
    for name, fn in amb_table:
        fn(os.path.join(OUT_AMB, name))
        print("amb:", name)

    mus_table = [
        ("menu_theme.wav", music_menu_theme),
        ("ambient_drone.wav", music_ambient_drone),
        ("ending_theme.wav", music_ending_theme),
        ("final_theme.wav", music_final_theme),
    ]
    for name, fn in mus_table:
        fn(os.path.join(OUT_MUS, name))
        print("mus:", name)


if __name__ == "__main__":
    main()
