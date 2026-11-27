class_name DrumSynth
extends RefCounted
## Placeholder drum sounds, generated in code.
## Replaced later by Sam's own (licensed) drum kits.

const RATE := 44100


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out


static func kick() -> AudioStreamWAV:
	var out := _buffer(0.45)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 45.0 + 110.0 * exp(-t * 35.0)
		phase += TAU * f / RATE
		out[i] = sin(phase) * exp(-t * 7.0) * 0.95
	return _make(out)


static func snare() -> AudioStreamWAV:
	var out := _buffer(0.25)
	for i in out.size():
		var t := float(i) / RATE
		var noise := randf_range(-1.0, 1.0) * exp(-t * 20.0) * 0.55
		var tone := sin(TAU * 185.0 * t) * exp(-t * 30.0) * 0.45
		out[i] = noise + tone
	return _make(out)


static func hihat() -> AudioStreamWAV:
	var out := _buffer(0.08)
	var prev := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		out[i] = (n - prev) * exp(-t * 60.0) * 0.35
		prev = n
	return _make(out)


static func clap() -> AudioStreamWAV:
	var out := _buffer(0.3)
	for i in out.size():
		var t := float(i) / RATE
		var env := 0.0
		for k in 3:
			var start := k * 0.011
			if t >= start:
				env += exp(-(t - start) * 160.0)
		env += exp(-t * 18.0) * 0.5
		out[i] = randf_range(-1.0, 1.0) * env * 0.4
	return _make(out)


static func bass808() -> AudioStreamWAV:
	var out := _buffer(1.2)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 52.0 + 45.0 * exp(-t * 25.0)
		phase += TAU * f / RATE
		out[i] = tanh(sin(phase) * 1.6) * exp(-t * 1.8) * 0.8
	return _make(out)


# ---------- Drum kits (bought in the shop) ----------

## Returns [kick, snare, hihat, clap, 808] for a kit id: "default", "dusty", "drill".
static func kit(id: String) -> Array:
	match id:
		"dusty":
			return [_dusty_kick(), _dusty_snare(), _dusty_hat(), clap(), bass808()]
		"drill":
			return [kick(), _drill_snare(), _drill_hat(), clap(), _drill_808()]
	return [kick(), snare(), hihat(), clap(), bass808()]


static func _crackle(out: PackedFloat32Array, amount: float) -> void:
	for i in out.size():
		if randf() < 0.002:
			out[i] += randf_range(-1.0, 1.0) * amount


static func _dusty_kick() -> AudioStreamWAV:
	var out := _buffer(0.4)
	var phase := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (48.0 + 70.0 * exp(-t * 28.0)) / RATE
		var v := sin(phase) * exp(-t * 8.5) + randf_range(-1, 1) * exp(-t * 90.0) * 0.25
		lp += (v - lp) * 0.35
		out[i] = tanh(lp * 1.6) * 0.85
	_crackle(out, 0.15)
	return _make(out)


static func _dusty_snare() -> AudioStreamWAV:
	var out := _buffer(0.32)
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.45
		out[i] = lp * exp(-t * 13.0) * 0.8 + sin(TAU * 200.0 * t) * exp(-t * 25.0) * 0.4
	_crackle(out, 0.2)
	return _make(out)


static func _dusty_hat() -> AudioStreamWAV:
	var out := _buffer(0.07)
	var prev := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		var hp := n - prev
		prev = n
		lp += (hp - lp) * 0.5
		out[i] = lp * exp(-t * 70.0) * 0.35
	return _make(out)


static func _drill_snare() -> AudioStreamWAV:
	var out := _buffer(0.22)
	var prev := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		out[i] = (n - prev * 0.5) * exp(-t * 24.0) * 0.7 + sin(TAU * 240.0 * t) * exp(-t * 40.0) * 0.35
		prev = n
	return _make(out)


static func _drill_hat() -> AudioStreamWAV:
	var out := _buffer(0.045)
	var prev := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		out[i] = (n - prev) * exp(-t * 110.0) * 0.4
		prev = n
	return _make(out)


## Drill 808: longer tail with the signature downward slide.
static func _drill_808() -> AudioStreamWAV:
	var out := _buffer(1.4)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 46.0 + 30.0 * exp(-t * 3.5) + 40.0 * exp(-t * 30.0)
		phase += TAU * f / RATE
		out[i] = tanh(sin(phase) * 2.2) * exp(-t * 1.3) * 0.8
	return _make(out)


# ---------- Melodic instruments (one sample at C4, pitched per note) ----------

const C4 := 261.63


static func instrument(id: String) -> AudioStreamWAV:
	match id:
		"pluck":
			return _pluck()
		"bell":
			return _bell()
		"pad":
			return _pad()
	return _keys()


static func _keys() -> AudioStreamWAV:
	var out := _buffer(1.2)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(t / 0.005, 1.0) * exp(-t * 2.6)
		var v := sin(TAU * C4 * t) + 0.35 * sin(TAU * C4 * 2.0 * t) * exp(-t * 6.0) + 0.12 * sin(TAU * C4 * 3.0 * t) * exp(-t * 9.0)
		out[i] = v * env * 0.45
	return _make(out)


static func _pluck() -> AudioStreamWAV:
	var out := _buffer(0.6)
	var phase := 0.0
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase = fmod(phase + C4 / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		var cutoff := 0.04 + 0.5 * exp(-t * 14.0)
		lp += (saw - lp) * cutoff
		out[i] = lp * exp(-t * 5.5) * 0.6
	return _make(out)


static func _bell() -> AudioStreamWAV:
	var out := _buffer(1.8)
	for i in out.size():
		var t := float(i) / RATE
		var mod := sin(TAU * C4 * 3.5 * t) * 2.2 * exp(-t * 3.0)
		out[i] = sin(TAU * C4 * t + mod) * exp(-t * 1.6) * 0.45
	return _make(out)


static func _pad() -> AudioStreamWAV:
	var out := _buffer(1.6)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(t / 0.35, 1.0) * clampf((1.6 - t) / 0.5, 0.0, 1.0)
		var v := sin(TAU * C4 * t) + sin(TAU * C4 * 1.005 * t) * 0.8 + sin(TAU * C4 * 2.0 * t) * 0.25
		out[i] = v * env * 0.3
	return _make(out)
