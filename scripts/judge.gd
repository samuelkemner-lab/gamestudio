class_name Judge
extends RefCounted
## Scores a beat against what a rapper wants. 0–100 → 1–5 stars, with readable notes.
## Points: BPM 20 · drum counts 25 · melody 15 · signature groove 15 · feel 10 · mix 15,
## plus gear/kit/instrument bonuses from upgrades (capped at 100).


static func evaluate(seq: Sequencer, rapper: Dictionary, upgrades: Array = []) -> Dictionary:
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
	score += clampf(20.0 - off * 1.3, 0.0, 20.0)

	# --- Hit counts per track (25) ---
	var wants: Dictionary = rapper.wants
	var per := 25.0 / wants.size()
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

	# --- Melody (15) ---
	var mel: Dictionary = rapper.get("melody", {"notes": [0, 16], "scale": []})
	var notes_n := seq.note_count()
	var nmin: int = mel.notes[0]
	var nmax: int = mel.notes[1]
	var mel_score := 15.0
	if notes_n < nmin:
		mel_score -= (nmin - notes_n) * 3.5
		notes.append("Needs a melody (%d notes, wants %d+). Use the Piano Roll." % [notes_n, nmin] if notes_n == 0 else "Melody too thin (%d notes, wants %d+)." % [notes_n, nmin])
	elif notes_n > nmax:
		mel_score -= (notes_n - nmax) * 1.5
		notes.append("Melody too busy (%d notes, max %d)." % [notes_n, nmax])
	if str(mel.scale) == "minor" and notes_n > 0:
		var off_scale := seq.off_scale_notes(Sequencer.MINOR)
		if off_scale > 0:
			mel_score -= off_scale * 3.0
			notes.append("%d note(s) don't fit C minor. Stick to the highlighted rows." % off_scale)
	score += clampf(mel_score, 0.0, 15.0)

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

	# --- Feel (10): swing, ghost notes, rolls, moving 808, glide ---
	var feel: Dictionary = rapper.get("feel", {})
	if feel.is_empty():
		score += 10.0
	else:
		var parts := 0
		var got := 0.0
		if feel.has("swing"):
			parts += 1
			var sw_lo: float = feel.swing[0]
			var sw_hi: float = feel.swing[1]
			if seq.swing >= sw_lo and seq.swing <= sw_hi:
				got += 1.0
			else:
				notes.append("Swing it! Set SWING to %d–%d%%." % [int(sw_lo * 100), int(sw_hi * 100)] if seq.swing < sw_lo else "Too much swing (max %d%%)." % int(sw_hi * 100))
		for track in feel.get("ghost", {}).keys():
			parts += 1
			var need: int = feel.ghost[track]
			var have := seq.ghost_notes(Sequencer.TRACKS.find(track))
			got += minf(float(have) / need, 1.0)
			if have < need:
				notes.append("Add a ghost %s: a soft hit (Velocity tool, drag it low)." % track.to_lower())
		for track in feel.get("rolls", {}).keys():
			parts += 1
			var need_r: int = feel.rolls[track]
			var have_r := seq.roll_count(Sequencer.TRACKS.find(track))
			got += minf(float(have_r) / need_r, 1.0)
			if have_r < need_r:
				notes.append("Needs %d+ %s roll(s). Use the Roll tool." % [need_r, track.to_lower()])
		if feel.has("bass_notes"):
			parts += 1
			var need_b: int = feel.bass_notes
			var have_b := seq.bass_pitches() if Judge.count_hits(seq, Sequencer.BASS) > 0 else 0
			got += minf(float(have_b) / need_b, 1.0)
			if have_b < need_b:
				notes.append("The 808 should move: %d+ different notes (Piano Roll → 808)." % need_b)
		if feel.get("glide", false):
			parts += 1
			if seq.glide:
				got += 1.0
			else:
				notes.append("Turn on 808 GLIDE for those slides.")
		score += 10.0 * got / maxf(parts, 1)

	# --- Mix (15) ---
	var mix: Dictionary = rapper.mix
	var checks := 0
	for track in mix.keys():
		checks += (mix[track] as Array).size() if mix[track] is Array else 1
	var mix_per := 15.0 / maxf(checks, 1)
	for track in mix.keys():
		var bus := AudioServer.get_bus_index(track)
		var vol := 0.0 if AudioServer.is_bus_mute(bus) else seq.get_volume(bus)
		var hits := seq.note_count() if track == "Keys" else count_hits(seq, Sequencer.TRACKS.find(track))
		var verb := seq.get_reverb(bus)
		var wish_list: Array = mix[track] if mix[track] is Array else [mix[track]]
		for wish in wish_list:
			match wish:
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
				"wet":
					if verb >= 0.2:
						score += mix_per
					else:
						notes.append("Put reverb on the %s (Mixer → REVERB 20%%+)." % track)
				"dry":
					if verb <= 0.1:
						score += mix_per
					else:
						notes.append("Too much reverb on the %s. Keep it dry." % track)

	# Clipping: the master goes over 0 dB. Everyone hears it.
	var peak := seq.peak_db()
	var clipping := peak > 0.0
	if clipping:
		score -= 6.0
		notes.append("It's CLIPPING (+%.1f dB). Pull the master or the loudest tracks down." % peak)

	# --- Bonuses: gear, matching kit and instrument ---
	if "mic_pro" in upgrades:
		score += 6.0
	if "monitors" in upgrades:
		score += 3.0
	if seq.kit_id != "default" and seq.kit_id == str(rapper.get("kit", "")):
		score += 8.0
	if notes_n > 0 and seq.instrument == str(mel.get("instrument", "")):
		score += 4.0

	# No melody when they need one: it's just a drum loop, not a song.
	if nmin > 0 and notes_n == 0:
		score *= 0.8

	# A beat at the wrong tempo never feels right, however good the drums are.
	score *= lerpf(1.0, 0.55, clampf(off / 30.0, 0.0, 1.0))
	var final_score := int(round(clampf(score, 0.0, 100.0)))
	var arr := seq.arrangement()
	return {
		"score": final_score,
		"stars": stars_for(final_score),
		"notes": notes,
		"clipping": clipping,
		"song": bool(arr.song),
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
static func reward(rapper: Dictionary, stars: int, upgrades: Array = []) -> Dictionary:
	var money := int(round(rapper.pay * (0.3 + 0.175 * stars)))
	var tip := int(round(rapper.pay * 0.25)) if stars == 5 else 0
	var cred := maxi(stars - 2, 0) * int(rapper.cred_gain)
	if "neon" in upgrades:
		cred += 1
	return {
		"money": money + tip,
		"tip": tip,
		"rep": stars * 2 - 4,
		"cred": cred,
	}
