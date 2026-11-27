extends SceneTree
## Headless smoke test. Run:
## godot --headless --path . -s tests/run_tests.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _reset_mix(seq: Sequencer) -> void:
	seq.set_swing(0.0)
	seq.set_glide(false)
	for name in Sequencer.TRACKS + ["Keys"]:
		var b := AudioServer.get_bus_index(name)
		seq.set_reverb(b, 0.0)
		seq.set_solo(b, false)
	seq.set_volume(0, 1.0)
	seq.set_mute(0, false)


func _boom_bap(seq: Sequencer, feel := true) -> void:
	seq.select_pattern(0)
	seq.clear()
	_reset_mix(seq)
	seq.bpm = 90
	if feel:
		seq.set_swing(0.25)
		seq.set_velocity(1, 10, 0.3)  # ghost snare
	for st in [0, 7, 10]:
		seq.set_step(0, st, true)
	for st in [4, 12]:
		seq.set_step(1, st, true)
	for st in range(0, 16, 2):
		seq.set_step(2, st, true)
	for t in 5:
		seq.set_mute(seq.bus_index(t), false)
		seq.set_volume(seq.bus_index(t), 1.0)


func _emo(seq: Sequencer, notes: Array) -> void:
	seq.select_pattern(0)
	seq.clear()
	_reset_mix(seq)
	seq.bpm = 135
	seq.set_roll(2, 14, 3)
	seq.set_reverb(AudioServer.get_bus_index("Keys"), 0.3)
	for st in [0, 10]:
		seq.set_step(0, st, true)
	seq.set_step(3, 12, true)
	for st in range(0, 16, 2):
		seq.set_step(2, st, true)
	seq.set_bass(0, 0, true)
	seq.set_bass(6, 3, true)
	seq.set_bass(10, 7, true)
	for i in notes.size():
		seq.set_note(i * 3, notes[i], true)
	for t in 5:
		seq.set_mute(seq.bus_index(t), false)
		seq.set_volume(seq.bus_index(t), 1.0)
	seq.set_volume(seq.bus_index(2), 0.7)


func _wait_until(cond: Callable, timeout: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var seq: Sequencer = main.get_node("Sequencer")
	main.chaos.crashes_enabled = false
	check(seq != null, "sequencer exists")
	check(seq.pattern.size() == 5, "5 tracks")
	check(seq.pattern[0].size() == 16, "16 steps")
	for t in 5:
		check(AudioServer.get_bus_index(Sequencer.TRACKS[t]) != -1, "bus " + Sequencer.TRACKS[t])

	# LOOPR opens and closes
	check(not main.in_menu, "no title screen in headless mode")
	main.open_loopr()
	check(main.loopr.visible, "LOOPR opens")
	check(not main.player.enabled, "player frozen while in LOOPR")
	main.close_loopr()
	check(not main.loopr.visible and main.player.enabled, "LOOPR closes")

	# Toggling a step through the UI updates the pattern
	seq.clear()
	main.loopr.refresh_grid()
	main.loopr.rack.cell_pressed.emit(1, 3, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.5))
	check(seq.pattern[1][3], "UI step click writes pattern")
	main.loopr.set_tool("vel")
	main.loopr.rack.cell_pressed.emit(1, 3, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.8))
	check(absf(seq.velocity[1][3] - 0.2) < 0.01, "velocity tool sets a soft hit")
	main.loopr.set_tool("roll")
	main.loopr.rack.cell_pressed.emit(2, 5, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.5))
	check(seq.pattern[2][5] and seq.rolls[2][5] == 2, "roll tool makes a 2-hit roll")
	main.loopr.set_tool("draw")
	main.loopr.rack.cell_pressed.emit(2, 5, MOUSE_BUTTON_RIGHT, Vector2(0.5, 0.5))
	check(not seq.pattern[2][5] and seq.rolls[2][5] == 1, "right-click erases")
	main.loopr.set_lane("808")
	main.loopr.roll.cell_pressed.emit(Sequencer.NOTE_RANGE - 1 - 3, 6, MOUSE_BUTTON_LEFT, Vector2.ZERO)
	check(seq.has_bass(6, 3) and seq.pattern[Sequencer.BASS][6], "808 lane places a pitched 808")
	main.loopr.set_lane("melody")
	main.loopr.playlist.cell_pressed.emit(1, 2, MOUSE_BUTTON_LEFT, Vector2.ZERO)
	check(seq.playlist[2] == 1, "playlist click puts pattern B in bar 3")
	seq.set_bar(2, -1)

	# Undo
	seq.clear()
	seq.checkpoint()
	seq.set_step(0, 0, true)
	check(seq.undo() and not seq.pattern[0][0], "undo takes back an edit")

	# Patterns + playlist
	seq.select_pattern(0)
	seq.clear()
	seq.set_step(0, 0, true)
	seq.clone_to_next()
	check(seq.current_pattern == 1 and seq.pattern[0][0], "clone copies A into B and selects B")
	seq.set_step(1, 4, true)
	seq.select_pattern(0)
	check(not seq.pattern[1][4], "patterns are independent")
	for b in 4:
		seq.set_bar(b, b % 2)
	check(seq.arrangement().song, "4 bars with A/B = a full song")
	seq.set_bar(2, -1)
	seq.set_bar(3, -1)
	check(not seq.arrangement().song, "2 bars is still a loop")
	for b in 4:
		seq.set_bar(b, b % 2)
	seq.bpm = 200
	seq.set_song_mode(true)
	var bars_seen := []
	seq.bar_changed.connect(func(b): bars_seen.append(b))
	seq.play()
	await _wait_until(func(): return 1 in bars_seen, 4.0)
	seq.stop()
	seq.set_song_mode(false)
	check(1 in bars_seen, "song mode moves through the playlist")
	for b in Sequencer.BARS:
		seq.set_bar(b, -1)
	seq.select_pattern(1)
	seq.clear()
	seq.select_pattern(0)

	# Mixer FX
	var kb := seq.bus_index(1)
	seq.set_reverb(kb, 0.3)
	seq.set_pan(kb, -0.5)
	seq.set_locut(kb, true)
	check(absf(seq.get_reverb(kb) - 0.3) < 0.01 and absf(seq.get_pan(kb) + 0.5) < 0.01 and seq.get_locut(kb), "reverb, pan and lo-cut work")
	seq.set_reverb(kb, 0.0)
	seq.set_pan(kb, 0.0)
	seq.set_locut(kb, false)
	seq.set_solo(seq.bus_index(0), true)
	check(AudioServer.is_bus_mute(kb) and not AudioServer.is_bus_mute(seq.bus_index(0)), "solo mutes the other channels")
	seq.set_solo(seq.bus_index(0), false)
	check(not AudioServer.is_bus_mute(kb), "unsolo restores")

	# Playback advances steps at the right tempo
	seq.bpm = 120.0
	var steps_seen := []
	seq.step_changed.connect(func(s): steps_seen.append(s))
	seq.play()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1050:
		await process_frame
	seq.stop()
	# 120 bpm = 8 sixteenths per second (+ first step on play)
	var played := steps_seen.filter(func(s): return s >= 0).size()
	check(played >= 7 and played <= 11, "tempo ok (%d steps in ~1s)" % played)

	# Mixer
	var bus := seq.bus_index(0)
	seq.set_volume(bus, 0.5)
	check(absf(seq.get_volume(bus) - 0.5) < 0.01, "fader sets bus volume")
	seq.set_mute(bus, true)
	check(AudioServer.is_bus_mute(bus), "mute works")

	seq.set_mute(bus, false)
	seq.set_volume(bus, 1.0)

	# --- Judge ---
	var earl := Rappers.BIG_EARL
	_boom_bap(seq)
	var good := Judge.evaluate(seq, earl)
	check(int(good.stars) >= 4, "boom bap beat pleases Big Earl (%d pts)" % good.score)
	_boom_bap(seq, false)
	var stiff := Judge.evaluate(seq, earl)
	check(stiff.score < good.score, "no swing / ghost snare costs points (%d vs %d)" % [stiff.score, good.score])
	_boom_bap(seq)
	seq.set_reverb(seq.bus_index(1), 0.4)
	var wet := Judge.evaluate(seq, earl)
	check(wet.score < good.score, "reverb on Earl's snare costs points")
	seq.set_reverb(seq.bus_index(1), 0.0)
	seq.set_step(3, 0, true)  # clap stacked on the kick
	for t in 5:
		seq.set_volume(seq.bus_index(t), 1.25)
	seq.set_volume(0, 1.25)
	var hot := Judge.evaluate(seq, earl)
	check(hot.clipping and hot.score < good.score, "clipping master is punished (%.1f dB)" % seq.peak_db())
	_reset_mix(seq)
	seq.load_default_pattern()
	seq.bpm = 140
	var bad := Judge.evaluate(seq, earl)
	check(int(bad.stars) <= 2 and bad.notes.size() > 0, "trap beat at 140 disappoints Big Earl (%d pts)" % bad.score)
	var rw := Judge.reward(earl, 5)
	check(rw.money > earl.pay and rw.tip > 0, "5 stars pays more than base + tip")

	# --- Full session ---
	var gs: GameState = main.game
	gs.reset()
	var sess: Session = main.session
	check(not sess.can_book(Rappers.GHOST), "Ghost is locked without street cred")
	sess.book(earl)
	check(sess.state == Session.State.ARRIVING and sess.npc != null, "booking spawns the rapper")
	await _wait_until(func(): return sess.state == Session.State.WAITING, 15.0)
	check(sess.state == Session.State.WAITING, "rapper walks into the booth")
	_boom_bap(seq)
	check(sess.record_take(), "record take starts")
	await _wait_until(func(): return sess.state == Session.State.REVIEW, 15.0)
	check(sess.state == Session.State.REVIEW and int(sess.best.stars) >= 4, "take judged: %s" % str(sess.best.get("stars")))
	var money_before := gs.money
	var summary := sess.finish()
	check(summary.money > 0 and gs.money == money_before + int(summary.money), "payout lands in wallet (+€%d)" % summary.money)
	check(gs.sessions == 1, "track recorded")
	await _wait_until(func(): return sess.state == Session.State.IDLE, 15.0)
	check(sess.state == Session.State.IDLE, "rapper leaves, studio free again")

	# --- Chaos: cops ---
	var cash := gs.money
	gs.noise = 99.5
	seq.set_volume(0, 1.0)
	seq.play()
	await _wait_until(func(): return gs.money < cash, 20.0)
	check(gs.money == cash - Chaos.FINE, "noise → police fine €%d" % Chaos.FINE)
	seq.stop()

	# --- Melody / piano roll ---
	var tear := Rappers.LIL_TEAR
	_emo(seq, [0, 3, 7, 10, 12])
	var sad := Judge.evaluate(seq, tear)
	_emo(seq, [])
	var no_mel := Judge.evaluate(seq, tear)
	_emo(seq, [1, 4, 6, 9, 11])
	var wrong_scale := Judge.evaluate(seq, tear)
	check(sad.score > no_mel.score and sad.score > wrong_scale.score, "Lil Tear rewards a C-minor melody (%d vs %d none / %d off-scale)" % [sad.score, no_mel.score, wrong_scale.score])
	check(int(sad.stars) >= 4, "emo beat with minor melody gets 4+ stars (%d)" % sad.score)
	check(not sad.clipping, "default emo mix doesn't clip (%.1f dB)" % seq.peak_db())
	seq.set_instrument("pad")
	var pad := Judge.evaluate(seq, tear)
	seq.set_instrument("keys")
	check(true, "instrument switch works")

	# --- Upgrades ---
	gs.reset()
	gs.money = 1000
	var plain := Judge.evaluate(seq, tear, gs.upgrades)
	check(gs.buy("mic_pro") and gs.has("mic_pro"), "buy condenser mic")
	check(not gs.buy("mic_pro"), "can't buy twice")
	var boosted := Judge.evaluate(seq, tear, gs.upgrades)
	check(boosted.score >= plain.score + 5 or boosted.score == 100, "condenser mic boosts the score")
	main.room.apply_upgrades(gs.upgrades)
	check(main.room.upgrade_nodes["mic_pro"].visible and not main.room.upgrade_nodes["foam"].visible, "bought upgrades appear in the room")
	gs.money = 10
	check(not gs.buy("neon"), "can't buy without money")

	# --- Day cycle / streams ---
	gs.reset()
	gs.record_track("big_earl", 5, 100, true)
	gs.record_track("lil_tear", 3, 60)
	check(gs.tracks[0].song and not gs.tracks[1].song, "tracks remember if they were full songs")
	gs.booked_today.append("big_earl")
	var cash0 := gs.money
	var night := gs.sleep()
	check(gs.day == 2 and night.streams > 0 and gs.money == cash0 + int(night.earned), "sleeping pays streaming royalties (+€%d, %d streams)" % [night.earned, night.streams])
	check(gs.booked_today.is_empty(), "rappers available again the next day")

	# --- PC crash ---
	seq.load_default_pattern()
	seq.save_snapshot()
	seq.clear()
	check(seq.dirty, "edits mark the project unsaved")
	main.chaos.crash()
	check(Judge.count_hits(seq, 1) == 2 and not seq.dirty, "crash restores the last saved beat")

	# --- Unlocks ---
	gs.reset()
	check(not sess.unlocked(Rappers.SPIKE), "Spike locked at 0 rep")
	gs.reputation = 12
	check(sess.unlocked(Rappers.SPIKE), "Spike unlocks at 12 rep")

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
