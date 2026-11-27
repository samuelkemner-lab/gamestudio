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


static func _seam(out: PackedFloat32Array) -> PackedFloat32Array:
	var f := int(RATE * 0.25)
	var n := out.size()
	for i in f:
		var a := float(i) / f
		out[i] = out[i] * a + out[n - f + i] * (1.0 - a)
	return out.slice(0, n - f)
