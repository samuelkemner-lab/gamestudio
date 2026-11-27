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
