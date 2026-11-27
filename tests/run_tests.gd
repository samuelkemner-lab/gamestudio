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


func _boom_bap(seq: Sequencer) -> void:
	seq.clear()
	seq.bpm = 90
	for st in [0, 7, 10]:
		seq.set_step(0, st, true)
	for st in [4, 12]:
		seq.set_step(1, st, true)
	for st in range(0, 16, 2):
		seq.set_step(2, st, true)
	for t in 5:
		seq.set_mute(seq.bus_index(t), false)
		seq.set_volume(seq.bus_index(t), 1.0)


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
	main.loopr.step_buttons[1][3].button_pressed = true
	check(seq.pattern[1][3], "UI step toggle writes pattern")

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

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
