class_name VoiceSynth
extends RefCounted
## Placeholder voices (Animal Crossing-style babble), generated in code.
## Formant-shaped harmonics per vowel, so it sounds "vocal" without real recordings.

const RATE := 22050
const VOWELS := {
	"a": [800.0, 1200.0],
	"e": [500.0, 1900.0],
	"i": [320.0, 2300.0],
	"o": [500.0, 900.0],
	"u": [350.0, 800.0],
}


static func syllable(base_hz: float, vowel: String, length := 0.11, glide := 0.0) -> AudioStreamWAV:
	var f: Array = VOWELS[vowel]
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var peak := 0.0001
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var hz := base_hz * (1.0 + glide * t / length) * (1.0 + 0.02 * sin(t * 38.0))
		phase += hz / RATE
		var s := 0.0
		for k in range(1, 14):
			var fk := hz * k
			var w := exp(-pow((fk - f[0]) / 180.0, 2.0)) + 0.6 * exp(-pow((fk - f[1]) / 260.0, 2.0)) + 0.03
			s += sin(TAU * phase * k) * w
		var env := minf(t / 0.012, 1.0) * clampf((length - t) / 0.04, 0.0, 1.0)
		buf[i] = s * env
		peak = maxf(peak, absf(buf[i]))
	for i in n:
		data.encode_s16(i * 2, int(buf[i] / peak * 0.8 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## A small bank of syllables for one voice.
static func bank(base_hz: float, length := 0.11) -> Array:
	var out := []
	var vowels := VOWELS.keys()
	for v in vowels:
		out.append(syllable(base_hz, v, length))
		out.append(syllable(base_hz * 1.12, v, length, -0.1))
	return out


## Low thump (neighbour banging on the wall / door knock).
static func thump() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += (60.0 + 40.0 * exp(-t * 30.0)) / RATE
		var v := sin(TAU * phase) * exp(-t * 16.0) + randf_range(-1, 1) * exp(-t * 60.0) * 0.3
		data.encode_s16(i * 2, int(clampf(v, -1, 1) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
