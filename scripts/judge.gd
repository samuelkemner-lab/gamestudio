class_name Judge
extends RefCounted
## Scores a beat against what a rapper wants. 0–100 → 1–5 stars, with readable notes.
## Points: BPM 25 · hit counts 40 · signature groove 15 · mix 20.


static func evaluate(seq: Sequencer, rapper: Dictionary) -> Dictionary:
	var notes: Array[String] = []
	var score := 0.0

	# --- BPM (25) ---
	var lo: float = rapper.bpm[0]
	var hi: float = rapper.bpm[1]
	var off := 0.0
	if seq.bpm < lo:
		off = lo - seq.bpm
		notes.append("Tempo too slow (%d BPM, wants %d–%d)." % [seq.bpm, lo, hi])
	elif seq.bpm > hi:
		off = seq.bpm - hi
		notes.append("Tempo too fast (%d BPM, wants %d–%d)." % [seq.bpm, lo, hi])
	score += clampf(25.0 - off * 1.6, 0.0, 25.0)

	# --- Hit counts per track (40) ---
	var wants: Dictionary = rapper.wants
	var per := 40.0 / wants.size()
	for track in wants.keys():
		var t := Sequencer.TRACKS.find(track)
		var hits := count_hits(seq, t)
		var mn: int = wants[track][0]
		var mx: int = wants[track][1]
		if hits >= mn and hits <= mx:
			score += per
		else:
			var dist := mn - hits if hits < mn else hits - mx
			var harsh := 0.6 if mx == 0 else 0.35
			score += maxf(per - dist * per * harsh, 0.0)
			if mx == 0:
				notes.append("No %s wanted at all." % track)
			elif hits < mn:
				notes.append("Needs more %s (%d, wants %d+)." % [track, hits, mn])
			else:
				notes.append("Too much %s (%d, wants max %d)." % [track, hits, mx])

	# --- Signature groove (15) ---
	var sig: Dictionary = rapper.signature
	var needed := 0
	var found := 0
	for track in sig.keys():
		var t := Sequencer.TRACKS.find(track)
		for step in sig[track]:
			needed += 1
			if seq.pattern[t][step]:
				found += 1
			else:
				notes.append("Missing the %s on step %d." % [track, step + 1])
	score += 15.0 * (float(found) / maxf(needed, 1))

	# --- Mix (20) ---
	var mix: Dictionary = rapper.mix
	var mix_per := 20.0 / maxf(mix.size(), 1)
	for track in mix.keys():
		var t := Sequencer.TRACKS.find(track)
		var bus := seq.bus_index(t)
		var vol := 0.0 if AudioServer.is_bus_mute(bus) else seq.get_volume(bus)
		var hits := count_hits(seq, t)
		match mix[track]:
			"loud":
				if vol >= 0.95 and hits > 0:
					score += mix_per
				else:
					notes.append("%s should be louder in the mix." % track)
			"quiet":
				if vol <= 0.8:
					score += mix_per
				else:
					notes.append("%s is too loud in the mix." % track)
			"off":
				if vol <= 0.15 or hits == 0:
					score += mix_per
				elif not ("No %s wanted at all." % track) in notes:
					notes.append("Get rid of the %s (or mute it)." % track)

	# A beat at the wrong tempo never feels right, however good the drums are.
	score *= lerpf(1.0, 0.55, clampf(off / 30.0, 0.0, 1.0))
	var final_score := int(round(clampf(score, 0.0, 100.0)))
	return {
		"score": final_score,
		"stars": stars_for(final_score),
		"notes": notes,
	}


static func count_hits(seq: Sequencer, track: int) -> int:
	var n := 0
	for on in seq.pattern[track]:
		if on:
			n += 1
	return n


static func stars_for(score: int) -> int:
	if score >= 90:
		return 5
	if score >= 75:
		return 4
	if score >= 55:
		return 3
	if score >= 35:
		return 2
	return 1


## Money, reputation and street cred for a finished session.
static func reward(rapper: Dictionary, stars: int) -> Dictionary:
	var money := int(round(rapper.pay * (0.3 + 0.175 * stars)))
	var tip := int(round(rapper.pay * 0.25)) if stars == 5 else 0
	return {
		"money": money + tip,
		"tip": tip,
		"rep": stars * 2 - 4,
		"cred": maxi(stars - 2, 0) * rapper.cred_gain,
	}
