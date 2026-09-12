"""Original NEXUS KOMBAT sound design. No samples or external compositions.

Run with Python + NumPy. Output: stereo 16-bit PCM, 22050 Hz, deterministic seed.
Synthesized announcer source WAVs are generated separately with Windows SAPI.
"""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
rng = np.random.default_rng(87192)


def tvec(seconds):
    return np.arange(round(seconds * SR), dtype=np.float64) / SR


def midi(note):
    return 440 * 2 ** ((note - 69) / 12)


def soften(data):
    """Short fades prevent clicks without crushing percussive attacks."""
    data = np.asarray(data, dtype=np.float64).copy()
    edge = min(int(.004 * SR), len(data) // 3)
    data[:edge] *= np.linspace(0, 1, edge)
    data[-edge:] *= np.linspace(1, 0, edge)
    return data


def save(name, data, peak=.76):
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        data = np.column_stack([data, data])
    data = np.nan_to_num(data)
    # Soft saturation preserves punch while avoiding clipped summation.
    data = np.tanh(data * 1.15)
    maximum = max(.00001, np.abs(data).max())
    data = data / maximum * peak
    data -= data.mean(axis=0)
    data = np.clip(data, -.98, .98)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(SR)
        target.writeframes((data * 32767).astype('<i2').tobytes())


def noise(t, decay=12):
    sample = rng.normal(0, 1, len(t))
    return np.convolve(sample, np.ones(5) / 5, mode="same") * np.exp(-t * decay)


def kick(duration=.46, punch=1):
    t = tvec(duration)
    phase = 2 * np.pi * (45 * t + 68 * (.045 * (1 - np.exp(-t/.045))))
    body = np.sin(phase) * np.exp(-t*9)
    attack = noise(t, 95) * .14
    return soften((body + attack) * punch)


def snare(duration=.23):
    t = tvec(duration)
    return soften(noise(t, 20) * .50 + np.sin(2*np.pi*180*t) * np.exp(-t*28) * .2)


def hat(duration=.095, opened=False):
    t = tvec(duration)
    n = rng.normal(0, 1, len(t))
    n = n - np.convolve(n, np.ones(9)/9, mode="same")
    return soften(n * np.exp(-t*(15 if opened else 60)) * .10)


def bass(note, duration=.36):
    t = tvec(duration)
    phase = 2*np.pi*midi(note)*t
    body = np.sin(phase) + .22*np.sin(2*phase) + .08*np.sin(3*phase)
    env = (1-np.exp(-t*140))*np.exp(-t*6)
    return soften(body*env*.36)


def pluck(note, duration=.62, tone=0):
    t = tvec(duration)
    freq = midi(note)
    body = np.sin(2*np.pi*freq*t) + .3*np.sin(2*np.pi*freq*2*t)*np.exp(-t*8)
    body += .16*np.sin(2*np.pi*freq*1.003*t)
    if tone % 3 == 0:
        body += .12*np.sin(2*np.pi*freq*3*t)*np.exp(-t*15)
    return soften(body * (1-np.exp(-t*140)) * np.exp(-t*6) * .22)


def add(track, data, seconds, gain=1, pan=0):
    """Circular rendering keeps delay/reverb tails continuous at loop boundaries."""
    start = int(seconds * SR) % len(track)
    indices = (start + np.arange(len(data))) % len(track)
    left, right = math.sqrt((1-pan)/2), math.sqrt((1+pan)/2)
    np.add.at(track[:, 0], indices, data * gain * left)
    np.add.at(track[:, 1], indices, data * gain * right)


THEMES = [
    # name, tempo, root MIDI, scale, energy, syncopation
    ("menu", 106, 38, [0,2,3,7,10,12,14], .66, 1),
    ("selection", 114, 40, [0,2,3,5,7,10,12], .80, 2),
    ("vs", 122, 35, [0,1,5,7,8,12,13], .95, 0),
    ("arena_00", 124, 38, [0,2,3,7,10,12,14], .90, 0),
    ("arena_01", 126, 40, [0,2,4,7,9,12,14], .86, 1),
    ("arena_02", 118, 41, [0,2,3,5,7,10,12], .78, 2),
    ("arena_03", 130, 36, [0,3,5,7,10,12,15], .90, 3),
    ("arena_04", 116, 34, [0,1,3,6,7,10,12], .78, 0),
    ("arena_05", 128, 38, [0,2,5,7,9,12,14], .88, 2),
    ("arena_06", 122, 37, [0,3,5,7,10,12,15], .94, 1),
    ("arena_07", 132, 35, [0,2,3,5,7,10,12], .94, 3),
    ("arena_08", 120, 39, [0,2,3,7,8,12,14], .82, 1),
    ("arena_09", 134, 33, [0,1,3,5,7,8,12], 1.0, 0),
    ("victory", 108, 38, [0,2,4,7,9,12,14], .63, 2),
]


def music(theme_index, theme):
    name,bpm,root,scale,energy,sync = theme
    beat = 60/bpm
    bars = 8
    duration = 4*bars*beat
    track = np.zeros((round(duration*SR), 2), np.float64)
    progression = [0,0,-3,-3,5,5,-2,-2]
    melody = [0,2,4,2,1,3,2,5, 0,2,6,4,3,1,4,2]
    # Deep pads in four harmonic layers; notes overlap across bar boundaries.
    for bar in range(bars):
        root_note = root + progression[bar]
        pad_t = tvec(beat*4+.65)
        pad_envelope = np.minimum(pad_t/.4,1)*np.minimum((pad_t[-1]-pad_t)/.7,1)
        for part, interval in enumerate([0,7,12,15 if theme_index != 4 else 16]):
            f = midi(root_note+interval)
            pad = (np.sin(2*np.pi*f*pad_t)+.32*np.sin(2*np.pi*f*1.002*pad_t)) * pad_envelope*.075
            add(track,pad,bar*4*beat,pan=(part-1.5)*.35)
        for step in range(16):
            at = (bar*4+step/4)*beat
            if step%4 == 0 or (sync==3 and step==14):
                add(track,kick(),at,gain=.85*energy)
            if step in [4,12]:
                add(track,snare(),at,gain=.65*energy,pan=.08)
            if step%2 == 0:
                add(track,hat(opened=step in [6,14]),at,gain=.52*energy,pan=(-.33 if step%4==0 else .32))
            if step in [1,4,7,8,10,13,15] or (sync==0 and step==2):
                off = 7 if step in [7,15] else 0
                add(track,bass(root_note+off,beat*.65),at,gain=.95)
            # Per-arena melody, register and rhythm differ but share a sonic palette.
            if step in ([0,3,6,10,12,14] if sync%2 else [0,2,5,8,11,14]):
                degree = melody[(step+bar+theme_index)%len(melody)]
                note = root_note+24+scale[degree % len(scale)]
                sound = pluck(note,tone=theme_index)
                pan = math.sin(step*.81+theme_index)*.53
                add(track,sound,at,gain=.55 if name=="menu" else .70,pan=pan)
                add(track,sound,at+beat*.75,gain=.15,pan=-pan)
                add(track,sound,at+beat*1.5,gain=.06,pan=pan)
    # Low, spatial air texture. Periodic modulation wraps cleanly.
    time = np.arange(len(track))/SR
    air = rng.normal(0, .003, len(track)) * (.6+.4*np.sin(2*np.pi*time/duration))
    track[:,0] += air
    track[:,1] += np.roll(air,230)
    # Tiny edge ramp guarantees sample-safe WAV loops at arbitrary note frequencies.
    ramp = np.ones(len(track)); edge=int(.004*SR)
    ramp[:edge]=np.linspace(.03,1,edge); ramp[-edge:]=np.linspace(1,.03,edge)
    track *= ramp[:,None]
    save("music_"+name,track,peak=.64)
    print(f"music_{name}: {duration:.2f}s", flush=True)


def effects():
    t=tvec(.26)
    hit=soften(np.sin(2*np.pi*(90*t+5*(1-np.exp(-t*30))))*np.exp(-t*17)+noise(t,34)*.7)
    save("hit",hit,.73)
    t=tvec(.45)
    heavy=soften(np.sin(2*np.pi*(52*t+4*(1-np.exp(-t*18))))*np.exp(-t*10)+noise(t,24)*.9)
    save("hit_heavy",heavy,.85)
    t=tvec(.3)
    save("block",soften((np.sin(2*np.pi*350*t)+np.sin(2*np.pi*573*t)*.4)*np.exp(-t*24)*.5+noise(t,24)*.6),.64)
    t=tvec(.64)
    save("parry",soften((np.sin(2*np.pi*784*t)+.38*np.sin(2*np.pi*1176*t)+.15*np.sin(2*np.pi*1568*t))*np.exp(-t*8)+noise(t,44)*.8),.75)
    t=tvec(.76)
    save("guard_break",soften(noise(t,7)*1.2+np.sin(2*np.pi*(72*t+12*(1-np.exp(-t*8))))*np.exp(-t*6)),.85)
    t=tvec(.22)
    save("footstep",soften(noise(t,50)*.6+np.sin(2*np.pi*85*t)*np.exp(-t*36)*.35),.30)
    t=tvec(.33)
    save("jump",soften(np.sin(2*np.pi*(125*t+220*t*t))*np.sin(np.pi*t/.33)**2*np.exp(-t*6)+noise(t,13)*.16),.44)
    t=tvec(.35)
    save("whoosh",soften(noise(t,4)*np.sin(np.pi*t/.35)**2+.1*np.sin(2*np.pi*(170*t-90*t*t))*np.exp(-t*8)),.40)
    t=tvec(.68)
    save("projectile",soften((np.sin(2*np.pi*(310*t-125*t*t))+.30*np.sin(2*np.pi*(620*t-250*t*t)))*np.exp(-t*6)+noise(t,9)*.28),.60)
    t=tvec(1.8)
    env=np.minimum(t/.15,1)*np.exp(-t*1.8)
    save("super",soften((np.sin(2*np.pi*(53*t+15*t*t))*.65+np.sin(2*np.pi*(220*t+160*t*t))*.35)*env+noise(t,2.3)*.65),.89)
    t=tvec(1.15)
    save("ko_impact",soften(np.sin(2*np.pi*(38*t+6*(1-np.exp(-t*10))))*np.exp(-t*4)+noise(t,6)*.9),.91)
    for name, notes, duration, volume in [
        ("select",[76],.11,.35), ("confirm",[69,76],.14,.45),
        ("cancel",[64,57],.13,.32), ("victory",[50,57,62,66,69],.22,.64),
        ("ready",[62,69,74],.13,.5), ("counter_hit",[67,74],.1,.65),
    ]:
        sound=np.zeros(round((len(notes)*duration+.65)*SR))
        for index,note in enumerate(notes):
            tone=pluck(note,duration=.62)
            start=int(index*duration*SR)
            sound[start:start+len(tone)] += tone
        save(name,sound,volume)
    print("17 original effects written.",flush=True)


if __name__ == "__main__":
    for i,theme in enumerate(THEMES):
        music(i,theme)
    effects()
