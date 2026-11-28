class_name AmbienceSynth
extends RefCounted
## REALISM R5: procedural ambience loops (all generated in code, no samples):
## rain, city hum, river water, and a tram bell.

const RATE := 22050


static func _wav(data: PackedFloat32Array, loop := true) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


## Rain: filtered noise bed + random droplet ticks. Crossfaded ends so the loop is seamless.
static func rain(seconds := 4.0) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.35
		hp = lp - hp * 0.02
		var v := hp * 0.32
		if rng.randf() < 0.004:
			v += rng.randf_range(-0.6, 0.6)  # droplet
		out[i] = v
	return _wav(_seam(out))


## Distant city: brown-noise rumble with a slow swell (traffic far away).
static func city(seconds := 6.0) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var b := 0.0
	for i in n:
		b = clampf(b + rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		var t := float(i) / RATE
		out[i] = b * (0.5 + 0.25 * sin(t * TAU / seconds))
	return _wav(_seam(out))


## Water lapping against the quay.
static func water(seconds := 5.0) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var swell := pow(0.5 + 0.5 * sin(t * TAU * 0.55), 3.0)
		out[i] = lp * (0.25 + 0.9 * swell)
	return _wav(_seam(out))


## Two-tone tram bell.
static func tram_bell() -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for hit in [0.0, 0.35]:
			if t >= hit:
				var tt: float = t - hit
				v += (sin(TAU * 1320.0 * tt) * 0.5 + sin(TAU * 2650.0 * tt) * 0.25 + sin(TAU * 3960.0 * tt) * 0.12) * exp(-tt * 5.0)
		out[i] = v * 0.5
	return _wav(out, false)


## Footstep for a surface: "wood" (room floor), "stone" (pavement), "wet" (splash in puddles).
static func step(surface: String, variant: int) -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant * 7 + surface.length()
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match surface:
			"wood":
				lp += (w - lp) * 0.08
				v = (sin(TAU * (95.0 + variant * 8.0) * t) * 0.8 + lp * 0.6) * exp(-t * 40.0)
			"wet":
				lp += (w - lp) * 0.5
				v = lp * 0.7 * exp(-t * 18.0) * (0.6 + 0.4 * sin(t * 900.0))
				v += sin(TAU * 70.0 * t) * 0.3 * exp(-t * 50.0)
			_:
				lp += (w - lp) * 0.3
				v = lp * exp(-t * 55.0) + sin(TAU * 140.0 * t) * 0.35 * exp(-t * 60.0)
		out[i] = v * 0.7
	return _wav(out, false)


## Body lands after a jump.
static func land() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.1
		out[i] = (sin(TAU * 60.0 * t) * 0.9 + lp) * exp(-t * 18.0) * 0.8
	return _wav(out, false)


## Small click (flashlight, fist bump, light switch).
static func tick(freq := 2200.0) -> AudioStreamWAV:
	var n := int(RATE * 0.06)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * exp(-t * 90.0) * 0.6
	return _wav(out, false)


## Cans and bottles hitting the ground.
static func clink(bottle: bool) -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var f := 1850.0 if bottle else 980.0
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.7 * t) * 0.25 + sin(TAU * f * 4.1 * t) * 0.12) * exp(-t * (14.0 if bottle else 22.0)) * 0.6
	return _wav(out, false)


## A cat purring: low rumble in a breathing rhythm.
static func purr() -> AudioStreamWAV:
	var n := int(RATE * 2.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
		var pulse := 0.5 + 0.5 * sin(TAU * 26.0 * t)
		var breath := 0.55 + 0.45 * sin(TAU * 0.8 * t)
		out[i] = lp * pulse * breath * 1.6
	return _wav(out, false)


## Wings: a burst of flutter when pigeons take off.
static func flap() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in n:
		var t := float(i) / RATE
		var beat := pow(0.5 + 0.5 * sin(TAU * 14.0 * t), 4.0)
		out[i] = rng.randf_range(-1.0, 1.0) * beat * exp(-t * 3.0) * 0.5
	return _wav(out, false)


## Phone ringtone: two short trills, then silence (loops).
static func ringtone() -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := (t < 0.38) or (t > 0.5 and t < 0.88)
		if on:
			var f := 1320.0 if int(t * 24.0) % 2 == 0 else 1760.0
			out[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.12) * 0.45
	return _wav(out, true)


## Message ping: short two-note blip.
static func ping() -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 988.0 if t < 0.09 else 1480.0
		out[i] = sin(TAU * f * t) * exp(-fmod(t, 0.11) * 30.0) * 0.4
	return _wav(out, false)


## E-step motor whine (loop). Pitch it with the speed.
static func motor() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		# 220 Hz fundamental (exact number of cycles per second = seamless loop) + PWM-ish harmonics
		var v := sin(TAU * 220.0 * t) * 0.35 + sin(TAU * 440.0 * t) * 0.18 + sin(TAU * 660.0 * t) * 0.08
		v += (randf() * 2.0 - 1.0) * 0.04
		out[i] = v * 0.5
	return _wav(out, true)


## Little thumb bell on the handlebar.
static func bell() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var hit := fmod(t, 0.18)
		out[i] = (sin(TAU * 2350.0 * t) + sin(TAU * 3170.0 * t) * 0.5) * exp(-hit * 18.0) * 0.3 * (1.0 if t < 0.36 else 0.0)
	return _wav(out, false)


## Door chime (tram / metro): two soft notes down.
static func chime() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1046.5 if t < 0.32 else 784.0
		var tt := t if t < 0.32 else t - 0.32
		out[i] = (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.15) * exp(-tt * 5.0) * 0.32
	return _wav(out, false)


## Check-in beep at the card reader.
static func beep() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 1975.0 * t) * 0.3 * (1.0 if t < 0.13 else 0.0)
	return _wav(out, false)


## Low electric rumble of a metro train (loop, pitch it with speed).
static func rumble() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lp * 0.97 + (randf() * 2.0 - 1.0) * 0.03
		out[i] = (sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 330.0 * t) * 0.08 + lp * 2.2) * 0.6
	return _wav(out, true)


## Can opening: short hiss.
static func pssht() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (randf() * 2.0 - 1.0) * exp(-t * 9.0) * 0.4 * (1.0 if t > 0.02 else t / 0.02)
	return _wav(out, false)


## Lighter: click + soft flame hiss.
static func lighter() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lp * 0.9 + (randf() * 2.0 - 1.0) * 0.1
		var click := sin(TAU * 3000.0 * t) * exp(-t * 200.0) * 0.5
		out[i] = click + lp * 0.5 * (1.0 if t > 0.08 else 0.0) * exp(-(t - 0.08) * 3.0)
	return _wav(out, false)


## Bottle / gulp: low bubble.
static func gulp() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 180.0 + 120.0 * sin(t * 30.0)
		out[i] = sin(TAU * f * t) * exp(-t * 8.0) * 0.4
	return _wav(out, false)


## Coins / payout jingle.
static func cash() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f: float = [1568.0, 2093.0, 2637.0][mini(int(t / 0.12), 2)]
		out[i] = sin(TAU * f * t) * exp(-fmod(t, 0.12) * 25.0) * 0.35
	return _wav(out, false)


static func _seam(out: PackedFloat32Array) -> PackedFloat32Array:
	var f := int(RATE * 0.25)
	var n := out.size()
	for i in f:
		var a := float(i) / f
		out[i] = out[i] * a + out[n - f + i] * (1.0 - a)
	return out.slice(0, n - f)
